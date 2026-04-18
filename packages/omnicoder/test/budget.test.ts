import { afterEach, beforeEach, describe, expect, test } from "bun:test"
import { promises as fs } from "node:fs"
import { createTokenBudget } from "../src/budget/index.ts"
import { cleanupHome, fakePluginInput, makeHome, withHome } from "./_helpers.ts"

describe("token budget", () => {
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

  test("happy path: appends completed session tokens to the log", async () => {
    const budget = await createTokenBudget(fakePluginInput as never)
    await budget.onEvent({ type: "session.completed", properties: { total_tokens: 2500 } })
    const log = await fs.readFile(budget._debug.logPath, "utf8")
    const parsed = JSON.parse(log.trim().split("\n")[0]!) as { tokens: number }
    expect(parsed.tokens).toBe(2500)
    const stats = await budget.getStats()
    expect(stats.entries).toBe(1)
    expect(stats.avg).toBe(2500)
    expect(stats.overThreshold).toBe(false)
  })

  test("edge case: non-session events are ignored and unknown shapes do not throw", async () => {
    const budget = await createTokenBudget(fakePluginInput as never)
    await budget.onEvent({ type: "message.delta", properties: { tokens: 999 } })
    await budget.onEvent({} as never)
    await budget.onEvent({ type: "session.completed" }) // no token payload
    const stats = await budget.getStats()
    expect(stats.entries).toBe(0)
  })

  test("threshold: >15000 rolling avg marks overThreshold", async () => {
    const budget = await createTokenBudget(fakePluginInput as never)
    for (let i = 0; i < 3; i++) {
      await budget.onEvent({ type: "session.completed", properties: { total_tokens: 20000 } })
    }
    const stats = await budget.getStats()
    expect(stats.avg).toBe(20000)
    expect(stats.overThreshold).toBe(true)
  })
})
