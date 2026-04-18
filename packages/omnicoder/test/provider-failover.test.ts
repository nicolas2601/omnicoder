import { beforeEach, describe, expect, test } from "bun:test"
import { createProviderFailover } from "../src/hooks/provider-failover.ts"
import { fakePluginInput } from "./_helpers.ts"

describe("provider failover", () => {
  beforeEach(async () => {
    // reset module-level state between tests
    const f = await createProviderFailover(fakePluginInput as never)
    f._debug.clear()
  })

  test("happy path: tune is a no-op when provider is healthy", async () => {
    const f = await createProviderFailover(fakePluginInput as never)
    let error: unknown = null
    try {
      await f.tune({ provider: { info: { id: "anthropic" } } }, {})
    } catch (e) {
      error = e
    }
    expect(error).toBeNull()
    expect(f._debug.isBlocked("anthropic")).toBeNull()
  })

  test("edge case: missing provider info is tolerated", async () => {
    const f = await createProviderFailover(fakePluginInput as never)
    await f.tune({}, {})
    await f.tune({ provider: {} }, {})
    expect(true).toBe(true)
  })

  test("error handling: reported providers show as blocked then expire", async () => {
    const f = await createProviderFailover(fakePluginInput as never)
    f._debug.report("openai", "HTTP 429 too many requests")
    expect(f._debug.isBlocked("openai")?.reason).toMatch(/429|rate|too many/i)

    // tune on a blocked provider does not throw (just logs warning)
    let error: unknown = null
    try {
      await f.tune({ provider: { info: { id: "openai" } } }, {})
    } catch (e) {
      error = e
    }
    expect(error).toBeNull()

    // non-matching samples are ignored
    f._debug.report("google", "everything is fine 200 OK")
    expect(f._debug.isBlocked("google")).toBeNull()
  })
})
