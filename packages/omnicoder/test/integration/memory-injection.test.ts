/**
 * Integration: memory loader injection.
 *
 * Drives the `experimental.chat.system.transform` hook and verifies:
 *   - Without Engram MCP configured, markdown under ~/.omnicoder/memory is
 *     injected into the system prompt array.
 *   - With Engram configured, the loader skips file injection entirely.
 *   - Byte cap of 1200 is enforced on oversized inputs.
 *   - Repeat calls within 30 s are served from the cache.
 */
import { afterEach, beforeEach, describe, expect, test } from "bun:test"
import { promises as fs } from "node:fs"
import * as os from "node:os"
import * as path from "node:path"
import {
  makeFakePluginInput,
  seedEngramConfig,
  seedHomeFromFixtures,
} from "./fixtures/mock-plugin-input.ts"

type TransformHook = (
  i: { sessionID?: string; model?: unknown; prompt?: string },
  o: { system: string[] },
) => Promise<void>

async function freshPlugin(): Promise<TransformHook> {
  const mod = (await import(`../../src/index.ts?r=${Math.random()}`)) as {
    OmnicoderPlugin: (input: unknown) => Promise<Record<string, unknown>>
  }
  const hooks = await mod.OmnicoderPlugin(makeFakePluginInput() as never)
  return hooks["experimental.chat.system.transform"] as TransformHook
}

describe("integration: memory injection", () => {
  let home = ""
  let prevHome: string | undefined

  beforeEach(async () => {
    home = await fs.mkdtemp(path.join(os.tmpdir(), "omni-memory-"))
    await fs.mkdir(path.join(home, ".omnicoder"), { recursive: true })
    prevHome = process.env.HOME
    process.env.HOME = home
  })

  afterEach(async () => {
    if (prevHome === undefined) delete process.env.HOME
    else process.env.HOME = prevHome
    await fs.rm(home, { recursive: true, force: true }).catch(() => {})
  })

  test("reads ~/.omnicoder/memory when Engram MCP not configured", async () => {
    await seedHomeFromFixtures(home, { memory: true })
    const transform = await freshPlugin()
    const output = { system: [] as string[] }
    await transform({ sessionID: "m1" }, output)

    const memLine = output.system.find((s) => s.includes("[OMNICODER-MEM]"))
    expect(memLine).toBeDefined()
    // Contents from fixtures should be present.
    expect(memLine).toContain("Prefer explicit types")
    expect(memLine).toContain("User prefers terse")
  })

  test("skips markdown injection when Engram MCP is configured", async () => {
    await seedHomeFromFixtures(home, { memory: true })
    await seedEngramConfig(home)
    const transform = await freshPlugin()
    const output = { system: [] as string[] }
    await transform({ sessionID: "m2" }, output)

    const memLine = output.system.find((s) => s.includes("[OMNICODER-MEM]"))
    expect(memLine).toBeUndefined()
    // Explicitly assert no markdown content leaked.
    expect(output.system.some((s) => s.includes("Prefer explicit types"))).toBe(false)
    expect(output.system.some((s) => s.includes("User prefers terse"))).toBe(false)
  })

  test("cache hit: second call within 30s does not re-read disk", async () => {
    await seedHomeFromFixtures(home, { memory: true })
    const transform = await freshPlugin()

    const o1 = { system: [] as string[] }
    await transform({ sessionID: "m3a" }, o1)
    const first = o1.system.find((s) => s.includes("[OMNICODER-MEM]"))
    expect(first).toBeDefined()

    // Delete the source files; a cold reader would now find nothing.
    await fs.rm(path.join(home, ".omnicoder", "memory"), { recursive: true, force: true })

    const o2 = { system: [] as string[] }
    await transform({ sessionID: "m3b" }, o2)
    const second = o2.system.find((s) => s.includes("[OMNICODER-MEM]"))

    // Cache TTL is 30 s — second read must come from the cached value.
    expect(second).toBeDefined()
    expect(second).toBe(first)
  })

  test("truncates combined memory payload to ~1200 bytes", async () => {
    const memDir = path.join(home, ".omnicoder", "memory")
    await fs.mkdir(memDir, { recursive: true })
    await fs.writeFile(path.join(memDir, "patterns.md"), "a".repeat(4000))
    await fs.writeFile(path.join(memDir, "feedback.md"), "b".repeat(4000))

    const transform = await freshPlugin()
    const output = { system: [] as string[] }
    await transform({ sessionID: "m4" }, output)

    const memLine = output.system.find((s) => s.includes("[OMNICODER-MEM]"))
    expect(memLine).toBeDefined()
    // Byte budget: 1200 + prefix/suffix and trailing "…" marker. 1400 is a
    // conservative upper bound that still catches any uncapped output.
    expect(Buffer.byteLength(memLine!, "utf8")).toBeLessThan(1400)
  })
})
