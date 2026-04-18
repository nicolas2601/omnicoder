/**
 * Shared benchmark utilities.
 *
 * - Uses `Bun.nanoseconds()` for sub-ms resolution.
 * - Provides helpers to build a deterministic, isolated $HOME that mirrors
 *   `~/.omnicoder/` by *symlinking* `.opencode/skills` (193 real SKILL.md)
 *   and copying synthetic `patterns.md`/`feedback.md` inputs.
 * - Percentile helpers (p50/p95/max) are inline and allocation-free.
 */
import { promises as fs } from "node:fs"
import * as os from "node:os"
import * as path from "node:path"

export type NsFn = () => number
export const ns: NsFn =
  typeof (globalThis as { Bun?: { nanoseconds?: NsFn } }).Bun?.nanoseconds === "function"
    ? (globalThis as { Bun: { nanoseconds: NsFn } }).Bun.nanoseconds
    : () => Number(process.hrtime.bigint())

export function nsToMs(n: number): number {
  return n / 1_000_000
}

/** In-place descending sort then percentile pick. */
export function percentiles(samplesNs: number[]): {
  p50: number
  p95: number
  p99: number
  max: number
  mean: number
  n: number
} {
  if (samplesNs.length === 0) return { p50: 0, p95: 0, p99: 0, max: 0, mean: 0, n: 0 }
  const sorted = [...samplesNs].sort((a, b) => a - b)
  const pick = (p: number): number => {
    const idx = Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1))
    return sorted[idx] ?? 0
  }
  const sum = sorted.reduce((a, b) => a + b, 0)
  return {
    p50: pick(50),
    p95: pick(95),
    p99: pick(99),
    max: sorted[sorted.length - 1] ?? 0,
    mean: sum / sorted.length,
    n: sorted.length,
  }
}

export function formatNs(n: number): string {
  const ms = nsToMs(n)
  if (ms >= 1) return `${ms.toFixed(2)}ms`
  const us = n / 1000
  if (us >= 1) return `${us.toFixed(1)}µs`
  return `${n}ns`
}

/**
 * Build an isolated $HOME for benchmarks. Links the repo's `.opencode/skills`
 * and `.opencode/agent` (if present) into `$HOME/.omnicoder/` so the router
 * indexes 193 real SKILL.md docs without copying MB of files.
 */
export async function mkBenchHome(opts?: {
  repoRoot?: string
  memoryBytes?: number
}): Promise<{ home: string; restore: () => void; skillCount: number; agentCount: number }> {
  const repoRoot = opts?.repoRoot ?? path.resolve(import.meta.dir, "..", "..", "..")
  const home = await fs.mkdtemp(path.join(os.tmpdir(), "omni-bench-"))
  const omni = path.join(home, ".omnicoder")
  await fs.mkdir(omni, { recursive: true })

  // Symlink skills: tiny, deterministic.
  const repoSkills = path.join(repoRoot, ".opencode", "skills")
  const repoAgents = path.join(repoRoot, ".opencode", "agent")
  let skillCount = 0
  let agentCount = 0
  try {
    await fs.symlink(repoSkills, path.join(omni, "skills"))
    skillCount = (await fs.readdir(repoSkills)).length
  } catch {
    skillCount = 0
  }
  try {
    // The router expects `.md` files directly under `agents/`.
    // `.opencode/agent/` also stores `.md` files.  Safe to link.
    await fs.symlink(repoAgents, path.join(omni, "agents"))
    const names = await fs.readdir(repoAgents).catch(() => [] as string[])
    agentCount = names.filter((n) => n.endsWith(".md")).length
  } catch {
    agentCount = 0
  }

  // Seed memory (patterns.md + feedback.md) ~2.2 KB total to match baseline.
  const memDir = path.join(omni, "memory")
  await fs.mkdir(memDir, { recursive: true })
  const totalBytes = opts?.memoryBytes ?? 2200
  const half = Math.floor(totalBytes / 2)
  await fs.writeFile(
    path.join(memDir, "patterns.md"),
    "# patterns\n" + "use-effect-cleanup: always return teardown.\n".repeat(Math.max(1, Math.floor(half / 40))),
  )
  await fs.writeFile(
    path.join(memDir, "feedback.md"),
    "# feedback\n" + "prefer batch tool calls for parallel ops.\n".repeat(Math.max(1, Math.floor(half / 40))),
  )

  const prev = process.env.HOME
  process.env.HOME = home
  const restore = (): void => {
    if (prev === undefined) delete process.env.HOME
    else process.env.HOME = prev
  }

  return { home, restore, skillCount, agentCount }
}

export async function rmBenchHome(home: string): Promise<void> {
  try {
    // Remove symlinks first so `rm -r` does not traverse repo content.
    const omni = path.join(home, ".omnicoder")
    for (const name of ["skills", "agents"]) {
      const p = path.join(omni, name)
      try {
        const st = await fs.lstat(p)
        if (st.isSymbolicLink()) await fs.unlink(p)
      } catch {
        /* ignore */
      }
    }
    await fs.rm(home, { recursive: true, force: true })
  } catch {
    /* best-effort */
  }
}

/** Deterministic PRNG (mulberry32). */
export function seeded(seed: number): () => number {
  let s = seed >>> 0
  return () => {
    s = (s + 0x6d2b79f5) >>> 0
    let t = s
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

export function pickSeeded<T>(rng: () => number, arr: readonly T[]): T {
  const i = Math.min(arr.length - 1, Math.floor(rng() * arr.length))
  return arr[i] as T
}

export type BenchReport<T = Record<string, unknown>> = {
  name: string
  iterations: number
  totalMs: number
  stats: ReturnType<typeof percentiles>
  extra?: T
}

/** Minimal console-friendly summary (printed by run-all). */
export function printReport(r: BenchReport): void {
  const { p50, p95, p99, max, mean, n } = r.stats
  console.log(
    `  ${r.name.padEnd(28)} n=${n.toString().padStart(4)}  p50=${formatNs(p50).padStart(9)}  ` +
      `p95=${formatNs(p95).padStart(9)}  p99=${formatNs(p99).padStart(9)}  ` +
      `max=${formatNs(max).padStart(9)}  mean=${formatNs(mean).padStart(9)}  ` +
      `total=${r.totalMs.toFixed(1)}ms`,
  )
}

export const fakePluginInput = {
  client: null,
  project: { id: "bench" },
  directory: process.cwd(),
  worktree: process.cwd(),
  experimental_workspace: { register: () => {} },
  serverUrl: new URL("http://localhost/"),
  $: null,
} as unknown
