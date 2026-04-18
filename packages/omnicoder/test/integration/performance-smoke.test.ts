/**
 * Integration: performance smoke benchmarks.
 *
 * Lightweight regression guards — not a stress suite. Thresholds:
 *   - Router cold over 100 skills: < 50 ms
 *   - Router warm (cached index): < 30 ms (v5 alpha target; v4 baseline 19 ms
 *     per ADR-004, relaxed for alpha)
 *   - Security guard 1000 calls: < 500 ms total
 *   - Memory loader cached hit: < 1 ms (measured via the plugin hook; first
 *     call warms the 30 s cache)
 */
import { afterEach, beforeEach, describe, expect, test } from "bun:test"
import { promises as fs } from "node:fs"
import * as os from "node:os"
import * as path from "node:path"
import { makeFakePluginInput, seedHomeFromFixtures } from "./fixtures/mock-plugin-input.ts"

type Hooks = Record<string, (...args: unknown[]) => Promise<unknown>>

async function bootPlugin(): Promise<Hooks> {
  const mod = (await import(`../../src/index.ts?r=${Math.random()}`)) as {
    OmnicoderPlugin: (input: unknown) => Promise<Hooks>
  }
  return mod.OmnicoderPlugin(makeFakePluginInput() as never)
}

async function seedManyFakeSkills(home: string, count: number): Promise<void> {
  const skillsDir = path.join(home, ".omnicoder", "skills")
  const bodyTemplate = (n: number) =>
    `---
name: skill-${n}
---

# Skill ${n}

Covers domain-${n % 7} topics including performance, testing, security,
optimization, frontend, backend, api, database, cache, queue, worker,
pipeline, schema, sitemap, auth, auth0, jwt, oauth, rbac, acl.
`
  await Promise.all(
    Array.from({ length: count }, async (_, i) => {
      const dir = path.join(skillsDir, `skill-${i}`)
      await fs.mkdir(dir, { recursive: true })
      await fs.writeFile(path.join(dir, "SKILL.md"), bodyTemplate(i))
    }),
  )
}

describe("integration: performance smoke", () => {
  let home = ""
  let prevHome: string | undefined

  beforeEach(async () => {
    home = await fs.mkdtemp(path.join(os.tmpdir(), "omni-perf-"))
    await fs.mkdir(path.join(home, ".omnicoder"), { recursive: true })
    prevHome = process.env.HOME
    process.env.HOME = home
  })

  afterEach(async () => {
    if (prevHome === undefined) delete process.env.HOME
    else process.env.HOME = prevHome
    await fs.rm(home, { recursive: true, force: true }).catch(() => {})
  })

  test("router over 100 skills: cold <50ms, warm <30ms", async () => {
    await seedManyFakeSkills(home, 100)
    const hooks = await bootPlugin()
    const transform = hooks["experimental.chat.system.transform"] as (
      i: { prompt?: string },
      o: { system: string[] },
    ) => Promise<void>

    const prompt =
      "please optimize my authentication and auth0 jwt oauth rbac performance for the backend api pipeline"

    const coldStart = performance.now()
    await transform({ prompt }, { system: [] })
    const coldMs = performance.now() - coldStart
    expect(coldMs).toBeLessThan(50)

    const warmStart = performance.now()
    await transform({ prompt }, { system: [] })
    const warmMs = performance.now() - warmStart
    expect(warmMs).toBeLessThan(30)
  })

  test("security guard: 1000 bash checks under 500ms total", async () => {
    const hooks = await bootPlugin()
    const before = hooks["tool.execute.before"] as (
      i: { tool: string },
      o: { args: unknown },
    ) => Promise<void>

    const start = performance.now()
    for (let i = 0; i < 1000; i++) {
      await before({ tool: "bash" }, { args: { command: `echo iteration-${i}` } })
    }
    const total = performance.now() - start
    expect(total).toBeLessThan(500)
  })

  test("memory loader cached hit: <1ms amortized on 50 calls", async () => {
    await seedHomeFromFixtures(home, { memory: true })
    const hooks = await bootPlugin()
    const transform = hooks["experimental.chat.system.transform"] as (
      i: { prompt?: string },
      o: { system: string[] },
    ) => Promise<void>

    // Warm the 30-second cache with a first call.
    await transform({ prompt: "warmup" }, { system: [] })

    const iters = 50
    const start = performance.now()
    for (let i = 0; i < iters; i++) {
      await transform({ prompt: "warmup" }, { system: [] })
    }
    const avgMs = (performance.now() - start) / iters
    // 1 ms per call amortized is the v5 alpha target; cached hit is a Map
    // lookup so real-world numbers are well under this threshold.
    expect(avgMs).toBeLessThan(1)
  })
})
