import { afterEach, beforeEach, describe, expect, test } from "bun:test"
import { promises as fs } from "node:fs"
import { createToolDispatcher } from "../src/hooks/tool-dispatcher.ts"
import { cleanupHome, fakePluginInput, makeHome, withHome } from "./_helpers.ts"

describe("tool dispatcher", () => {
  let home = ""
  let restore: () => void = () => {}

  beforeEach(async () => {
    home = await makeHome()
    restore = withHome(home)
  })

  afterEach(async () => {
    restore()
    await cleanupHome(home)
  })

  test("happy path: onComplete appends a JSONL entry", async () => {
    const d = await createToolDispatcher(fakePluginInput as never)
    await d.onComplete(
      { tool: "edit", sessionID: "s1", callID: "c1", args: {} },
      { title: "ok", output: "hello world", metadata: null },
    )
    const raw = await fs.readFile(d._debug.logPath, "utf8")
    const row = JSON.parse(raw.trim()) as Record<string, unknown>
    expect(row.tool).toBe("edit")
    expect(row.sessionID).toBe("s1")
    expect(row.outputLen).toBe(11)
    expect(typeof row.ts).toBe("string")
  })

  test("edge case: missing output/session fields use safe defaults", async () => {
    const d = await createToolDispatcher(fakePluginInput as never)
    await d.onComplete(
      { tool: "bash" } as never,
      {} as never,
    )
    const raw = await fs.readFile(d._debug.logPath, "utf8")
    const row = JSON.parse(raw.trim()) as Record<string, unknown>
    expect(row.sessionID).toBe("unknown")
    expect(row.outputLen).toBe(0)
  })

  test("error handling: onComplete is a no-op when log path is unwritable", async () => {
    const d = await createToolDispatcher(fakePluginInput as never)
    // simulate an unwritable target by making the logs path a file
    await fs.mkdir(`${home}/.omnicoder`, { recursive: true })
    await fs.writeFile(`${home}/.omnicoder/logs`, "blocking-file")
    // must not throw
    await d.onComplete(
      { tool: "grep", sessionID: "s", callID: "c", args: {} },
      { title: "t", output: "x", metadata: null },
    )
    expect(true).toBe(true)
  })

  test("onEvent records session start without throwing", async () => {
    const d = await createToolDispatcher(fakePluginInput as never)
    await d.onEvent({ type: "session.started", properties: { sessionID: "s2" } })
    await d.onEvent({ type: "something.else" })
    await d.onEvent({} as never)
    expect(true).toBe(true)
  })
})
