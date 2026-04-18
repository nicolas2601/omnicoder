/**
 * `bun run bench/run-all.ts`
 *
 * Runs all OmniCoder v5 micro-benchmarks with a 60s budget each, then writes
 * `bench/results-v5.0.0-alpha.0.json` with v4 baseline comparison.
 *
 * v4.3.1 baselines (from project_omnicoder.md):
 *   - 50 tool-calls pipeline:  2000 ms  (2.0s)
 *   - Router warm:               19 ms
 *   - Router tech cold:          46 ms
 *   - security-guard (Read):    6.5 ms  (we benchmark bash, but fast-path is
 *                                        similar — included for context)
 *   - memory inject payload:   ~2.2 KB
 */
import { promises as fs } from "node:fs"
import * as path from "node:path"
import { runFullPipelineBench } from "./full-pipeline.bench.ts"
import { runMemoryBench } from "./memory.bench.ts"
import { runRouterBench } from "./router.bench.ts"
import { runSecurityBench } from "./security.bench.ts"
import { formatNs, nsToMs } from "./_bench-util.ts"

const TIMEOUT_MS = 60_000

type Baselines = {
  pipeline50_ms: number
  router_warm_ms: number
  router_cold_ms: number
  security_read_ms: number
  memory_bytes: number
}

const V4_BASELINES: Baselines = {
  pipeline50_ms: 2000,
  router_warm_ms: 19,
  router_cold_ms: 46,
  security_read_ms: 6.5,
  memory_bytes: 2200,
}

async function withTimeout<T>(label: string, p: Promise<T>): Promise<T> {
  let timer: Timer | undefined
  const timeout = new Promise<never>((_, rej) => {
    timer = setTimeout(() => rej(new Error(`[bench] ${label} timed out > ${TIMEOUT_MS}ms`)), TIMEOUT_MS)
  })
  try {
    const res = await Promise.race([p, timeout])
    return res
  } finally {
    if (timer) clearTimeout(timer)
  }
}

function pctDelta(v5: number, v4: number): { deltaPct: number; regressed: boolean } {
  if (v4 === 0) return { deltaPct: 0, regressed: false }
  const d = ((v5 - v4) / v4) * 100
  return { deltaPct: d, regressed: d > 10 }
}

async function main(): Promise<void> {
  console.log(`OmniCoder v5 performance benchmark`)
  console.log(`${new Date().toISOString()}`)
  console.log(`Bun ${typeof Bun !== "undefined" ? Bun.version : "n/a"}`)
  console.log("")

  console.log("[1/4] router bench (1000 iter × 2 modes, 193 skills + 168 agents)")
  const router = await withTimeout("router", runRouterBench())
  const routerColdP50Ms = nsToMs(router.cold.stats.p50)
  const routerWarmP50Ms = nsToMs(router.warm.stats.p50)
  const routerWarmP95Ms = nsToMs(router.warm.stats.p95)
  const routerColdP95Ms = nsToMs(router.cold.stats.p95)
  console.log(
    `  cold p50=${formatNs(router.cold.stats.p50)} p95=${formatNs(router.cold.stats.p95)} max=${formatNs(router.cold.stats.max)}`,
  )
  console.log(
    `  warm p50=${formatNs(router.warm.stats.p50)} p95=${formatNs(router.warm.stats.p95)} max=${formatNs(router.warm.stats.max)}`,
  )

  console.log("[2/4] security bench (1000 iter, 70/30 safe/dangerous)")
  const security = await withTimeout("security", runSecurityBench())
  const secP50Ms = nsToMs(security.all.stats.p50)
  const secP95Ms = nsToMs(security.all.stats.p95)
  const secOps = security.all.iterations / (security.all.totalMs / 1000)
  console.log(
    `  p50=${formatNs(security.all.stats.p50)} p95=${formatNs(security.all.stats.p95)} ` +
      `max=${formatNs(security.all.stats.max)} throughput=${secOps.toFixed(0)} ops/s ` +
      `blocked=${security.all.extra?.blocked}`,
  )

  console.log("[3/4] memory bench (1 cold + 100 hits)")
  const memory = await withTimeout("memory", runMemoryBench())
  const memColdMs = nsToMs(memory.cold.stats.p50)
  const memHotP50Ms = nsToMs(memory.hot.stats.p50)
  const memBytes = memory.hot.extra?.bytes ?? 0
  console.log(
    `  cold=${formatNs(memory.cold.stats.p50)} hot p50=${formatNs(memory.hot.stats.p50)} ` +
      `p95=${formatNs(memory.hot.stats.p95)} bytes=${memBytes}`,
  )

  console.log("[4/4] full-pipeline bench (50 tool calls × 6 hooks)")
  const pipeline = await withTimeout("pipeline", runFullPipelineBench())
  console.log(`  wall-clock: ${pipeline.wallClockMs.toFixed(1)}ms (v4 baseline: 2000ms)`)
  console.log(
    `  per-call p50=${formatNs(pipeline.perCallP50Ns)} p95=${formatNs(pipeline.perCallP95Ns)} ` +
      `max=${formatNs(pipeline.perCallMaxNs)}`,
  )
  for (const [k, v] of Object.entries(pipeline.stages)) {
    console.log(`    ${k.padEnd(12)} p50=${formatNs(v.p50)} p95=${formatNs(v.p95)} mean=${formatNs(v.mean)}`)
  }

  // Build JSON with v4 deltas
  const deltas = {
    pipeline50: pctDelta(pipeline.wallClockMs, V4_BASELINES.pipeline50_ms),
    router_warm: pctDelta(routerWarmP50Ms, V4_BASELINES.router_warm_ms),
    router_cold: pctDelta(routerColdP50Ms, V4_BASELINES.router_cold_ms),
    security: pctDelta(secP50Ms, V4_BASELINES.security_read_ms),
    memory_bytes: pctDelta(memBytes, V4_BASELINES.memory_bytes),
  }

  const results = {
    version: "5.0.0-alpha.0",
    generatedAt: new Date().toISOString(),
    bun: typeof Bun !== "undefined" ? Bun.version : null,
    node: process.version,
    platform: `${process.platform}-${process.arch}`,
    baselines_v4: V4_BASELINES,
    metrics: {
      pipeline_50_tool_calls: {
        wall_clock_ms: pipeline.wallClockMs,
        per_call_p50_ms: nsToMs(pipeline.perCallP50Ns),
        per_call_p95_ms: nsToMs(pipeline.perCallP95Ns),
        per_call_max_ms: nsToMs(pipeline.perCallMaxNs),
        stages_ns: pipeline.stages,
        iterations: pipeline.iterations,
      },
      router: {
        cold_p50_ms: routerColdP50Ms,
        cold_p95_ms: routerColdP95Ms,
        cold_max_ms: nsToMs(router.cold.stats.max),
        warm_p50_ms: routerWarmP50Ms,
        warm_p95_ms: routerWarmP95Ms,
        warm_max_ms: nsToMs(router.warm.stats.max),
        warm_mean_ms: nsToMs(router.warm.stats.mean),
        skill_count: router.skillCount,
        agent_count: router.agentCount,
        iterations: router.warm.iterations,
      },
      security: {
        p50_ms: secP50Ms,
        p95_ms: secP95Ms,
        max_ms: nsToMs(security.all.stats.max),
        mean_ms: nsToMs(security.all.stats.mean),
        throughput_ops_sec: secOps,
        blocked: security.all.extra?.blocked ?? 0,
        safe: security.all.extra?.safe ?? 0,
        iterations: security.all.iterations,
      },
      memory: {
        cold_ms: memColdMs,
        hot_p50_ms: memHotP50Ms,
        hot_p95_ms: nsToMs(memory.hot.stats.p95),
        hot_max_ms: nsToMs(memory.hot.stats.max),
        bytes_injected: memBytes,
        iterations: memory.hot.iterations,
      },
    },
    deltas_vs_v4: deltas,
    verdict: buildVerdict(deltas),
  }

  const outFile = path.resolve(import.meta.dir, "results-v5.0.0-alpha.0.json")
  await fs.writeFile(outFile, JSON.stringify(results, null, 2) + "\n", "utf8")
  console.log("")
  console.log(`Results written to ${outFile}`)
  console.log("")
  console.log("v4 → v5 deltas:")
  for (const [k, v] of Object.entries(deltas)) {
    const arrow = v.regressed ? "REGRESSION" : "ok"
    console.log(`  ${k.padEnd(16)} ${v.deltaPct.toFixed(1).padStart(7)}%  ${arrow}`)
  }
  console.log("")
  console.log(`Verdict: ${results.verdict.label} — ${results.verdict.summary}`)
}

function buildVerdict(deltas: Record<string, { deltaPct: number; regressed: boolean }>): {
  label: "ship-ready" | "optimize-first"
  summary: string
  regressions: string[]
} {
  const regressed = Object.entries(deltas)
    .filter(([, v]) => v.regressed)
    .map(([k]) => k)
  if (regressed.length === 0) {
    return {
      label: "ship-ready",
      summary: "All metrics within ±10% of v4.3.1 baselines (or improved).",
      regressions: [],
    }
  }
  return {
    label: "optimize-first",
    summary: `Regressions >10% detected in: ${regressed.join(", ")}.`,
    regressions: regressed,
  }
}

main().catch((err) => {
  console.error("[bench] fatal:", err)
  process.exit(1)
})
