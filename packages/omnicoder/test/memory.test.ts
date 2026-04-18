import { afterEach, beforeEach, describe, expect, test } from "bun:test"
import { promises as fs } from "node:fs"
import * as path from "node:path"
import { createMemoryLoader } from "../src/memory/index.ts"
import { cleanupHome, fakePluginInput, makeHome, withHome } from "./_helpers.ts"

describe("memory loader", () => {
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

  test("happy path: injects patterns + feedback", async () => {
    const mem = path.join(home, ".omnicoder", "memory")
    await fs.mkdir(mem, { recursive: true })
    await fs.writeFile(path.join(mem, "patterns.md"), "- Pattern A\n- Pattern B\n")
    await fs.writeFile(path.join(mem, "feedback.md"), "- User likes terse output\n")
    const loader = await createMemoryLoader(fakePluginInput as never)
    loader._debug.invalidate()
    const output = { system: [] as string[] }
    await loader.inject({}, output)
    expect(output.system.length).toBe(1)
    expect(output.system[0]).toContain("[OMNICODER-MEM]")
    expect(output.system[0]).toContain("Pattern A")
    expect(output.system[0]).toContain("User likes terse output")
  })

  test("edge case: empty memory files inject nothing", async () => {
    const mem = path.join(home, ".omnicoder", "memory")
    await fs.mkdir(mem, { recursive: true })
    await fs.writeFile(path.join(mem, "patterns.md"), "")
    const loader = await createMemoryLoader(fakePluginInput as never)
    loader._debug.invalidate()
    const output = { system: [] as string[] }
    await loader.inject({}, output)
    expect(output.system.length).toBe(0)
  })

  test("error handling: missing memory dir yields no output and does not throw", async () => {
    const loader = await createMemoryLoader(fakePluginInput as never)
    loader._debug.invalidate()
    const output = { system: [] as string[] }
    await loader.inject({}, output)
    expect(output.system.length).toBe(0)
  })

  test("byte cap: combined payload is capped near 1200 bytes", async () => {
    const mem = path.join(home, ".omnicoder", "memory")
    await fs.mkdir(mem, { recursive: true })
    await fs.writeFile(path.join(mem, "patterns.md"), "x".repeat(5000))
    await fs.writeFile(path.join(mem, "feedback.md"), "y".repeat(5000))
    const loader = await createMemoryLoader(fakePluginInput as never)
    loader._debug.invalidate()
    const output = { system: [] as string[] }
    await loader.inject({}, output)
    expect(output.system.length).toBe(1)
    expect(output.system[0]!.length).toBeLessThan(1400)
  })
})
