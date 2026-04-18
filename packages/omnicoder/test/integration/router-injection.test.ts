/**
 * Integration: router injection through the full plugin surface.
 *
 * Drives the `experimental.chat.system.transform` hook end-to-end against a
 * seeded skills directory, asserting that prompts matching a skill get top-3
 * suggestions while short/greeting prompts hit the fast-path.
 */
import { afterEach, beforeEach, describe, expect, test } from "bun:test"
import { promises as fs } from "node:fs"
import * as os from "node:os"
import * as path from "node:path"
import { makeFakePluginInput, seedHomeFromFixtures } from "./fixtures/mock-plugin-input.ts"

type TransformHook = (
  i: { sessionID?: string; model?: unknown; prompt?: string },
  o: { system: string[] },
) => Promise<void>

async function freshPlugin(): Promise<{ transform: TransformHook }> {
  // Bust both the ESM module cache and the in-memory router index so each
  // test sees a clean slate. Bun's import cache keys by resolved path, so
  // appending a query string forces re-evaluation.
  const mod = (await import(`../../src/index.ts?r=${Math.random()}`)) as {
    OmnicoderPlugin: (input: unknown) => Promise<Record<string, unknown>>
  }
  const hooks = await mod.OmnicoderPlugin(makeFakePluginInput() as never)
  const transform = hooks["experimental.chat.system.transform"] as TransformHook
  return { transform }
}

describe("integration: router injection", () => {
  let home = ""
  let prevHome: string | undefined

  beforeEach(async () => {
    home = await fs.mkdtemp(path.join(os.tmpdir(), "omni-router-"))
    prevHome = process.env.HOME
    process.env.HOME = home
    await seedHomeFromFixtures(home, {
      skills: ["seo", "expo", "react"],
    })
  })

  afterEach(async () => {
    if (prevHome === undefined) delete process.env.HOME
    else process.env.HOME = prevHome
    await fs.rm(home, { recursive: true, force: true }).catch(() => {})
  })

  test("SEO prompt surfaces the seo skill", async () => {
    const { transform } = await freshPlugin()
    const output = { system: [] as string[] }
    await transform(
      {
        sessionID: "t1",
        prompt:
          "help me with SEO analysis for my ecommerce site including schema markup meta tags and technical audit",
      },
      output,
    )
    // Memory loader may also inject, so we filter for the router line.
    const routerLine = output.system.find((s) => s.includes("[OMNICODER] Sugeridos:"))
    expect(routerLine).toBeDefined()
    expect(routerLine!.toLowerCase()).toContain("seo")
  })

  test("short greeting prompt yields no router injection", async () => {
    const { transform } = await freshPlugin()
    const output = { system: [] as string[] }
    await transform({ sessionID: "t2", prompt: "hola" }, output)
    const routerLine = output.system.find((s) => s.includes("[OMNICODER] Sugeridos:"))
    expect(routerLine).toBeUndefined()
  })

  test("short non-greeting prompt also skips (under 10 words)", async () => {
    const { transform } = await freshPlugin()
    const output = { system: [] as string[] }
    await transform({ sessionID: "t2b", prompt: "fix bug" }, output)
    const routerLine = output.system.find((s) => s.includes("[OMNICODER] Sugeridos:"))
    expect(routerLine).toBeUndefined()
  })

  test("ambiguous long prompt returns top-3 unique skills", async () => {
    const { transform } = await freshPlugin()
    const output = { system: [] as string[] }
    await transform(
      {
        sessionID: "t3",
        prompt:
          "work on my react native expo application performance for SEO and mobile optimization with schema markup meta tags server components memoization",
      },
      output,
    )
    const routerLine = output.system.find((s) => s.includes("[OMNICODER] Sugeridos:"))
    expect(routerLine).toBeDefined()

    // Extract the comma-separated suggestions after the prefix.
    const match = routerLine!.match(/Sugeridos:\s*(.+)$/)
    expect(match).not.toBeNull()
    const names = match![1]!.split(",").map((s) => s.trim()).filter(Boolean)

    // At most 3 suggestions, no duplicates, capped at 500 chars.
    expect(names.length).toBeGreaterThan(0)
    expect(names.length).toBeLessThanOrEqual(3)
    expect(new Set(names).size).toBe(names.length)
    expect(routerLine!.length).toBeLessThanOrEqual(500)
  })
})
