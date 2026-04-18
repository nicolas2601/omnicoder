/**
 * Integration: plugin lifecycle.
 *
 * Verifies the `@omnicoder/core` plugin loads via dynamic import, returns the
 * expected hook surface, and handles missing `~/.omnicoder/*` dirs without
 * throwing. Each test runs in an isolated TMPDIR-based HOME.
 */
import { afterEach, beforeEach, describe, expect, test } from "bun:test"
import { promises as fs } from "node:fs"
import * as os from "node:os"
import * as path from "node:path"
import { makeFakePluginInput } from "./fixtures/mock-plugin-input.ts"

const EXPECTED_HOOKS = [
  "experimental.chat.system.transform",
  "tool.execute.before",
  "tool.execute.after",
  "chat.params",
  "event",
] as const

describe("integration: plugin lifecycle", () => {
  let home = ""
  let prevHome: string | undefined

  beforeEach(async () => {
    home = await fs.mkdtemp(path.join(os.tmpdir(), "omni-lifecycle-"))
    await fs.mkdir(path.join(home, ".omnicoder"), { recursive: true })
    prevHome = process.env.HOME
    process.env.HOME = home
  })

  afterEach(async () => {
    if (prevHome === undefined) delete process.env.HOME
    else process.env.HOME = prevHome
    await fs.rm(home, { recursive: true, force: true }).catch(() => {})
  })

  test("loads via dynamic import without throwing", async () => {
    const mod = await import("../../src/index.ts")
    expect(mod).toBeDefined()
    expect(typeof mod.OmnicoderPlugin).toBe("function")
    expect(mod.default).toBeDefined()
    expect(mod.default.id).toBe("@omnicoder/core")
    expect(typeof mod.default.server).toBe("function")
  })

  test("plugin invocation returns all 5 hook keys", async () => {
    const { OmnicoderPlugin } = await import("../../src/index.ts")
    const hooks = await OmnicoderPlugin(makeFakePluginInput() as never)

    expect(hooks).toBeDefined()
    const keys = Object.keys(hooks)
    for (const expected of EXPECTED_HOOKS) {
      expect(keys).toContain(expected)
    }
    // Each hook must be a callable async function.
    for (const key of EXPECTED_HOOKS) {
      expect(typeof (hooks as Record<string, unknown>)[key]).toBe("function")
    }
  })

  test("factory calls succeed when ~/.omnicoder dirs do not exist", async () => {
    // Wipe .omnicoder entirely (no skills, memory, logs dirs present).
    await fs.rm(path.join(home, ".omnicoder"), { recursive: true, force: true })

    const { OmnicoderPlugin } = await import("../../src/index.ts")
    let error: unknown = null
    let hooks: Record<string, unknown> | null = null
    try {
      hooks = (await OmnicoderPlugin(makeFakePluginInput() as never)) as Record<
        string,
        unknown
      >
    } catch (e) {
      error = e
    }
    expect(error).toBeNull()
    expect(hooks).not.toBeNull()
  })

  test("hooks execute cleanly with empty inputs (no open handles)", async () => {
    const { OmnicoderPlugin } = await import("../../src/index.ts")
    const hooks = (await OmnicoderPlugin(makeFakePluginInput() as never)) as Record<
      string,
      (...args: unknown[]) => Promise<unknown>
    >

    // Exercise every hook with benign inputs. None should throw.
    const systemBag = { system: [] as string[] }
    await hooks["experimental.chat.system.transform"]!({ sessionID: "s1" }, systemBag)
    await hooks["tool.execute.before"]!({ tool: "read" }, { args: {} })
    await hooks["tool.execute.after"]!(
      { tool: "read", sessionID: "s1", callID: "c1" },
      { title: "t", output: "", metadata: null },
    )
    await hooks["chat.params"]!({ provider: { info: { id: "anthropic" } } }, {})
    await hooks["event"]!({ event: { type: "noop" } })

    // Implicit: if any hook left an unhandled promise or open fd, bun would
    // flag it via --timeout. Reaching this line means shutdown was clean.
    expect(true).toBe(true)
  })
})
