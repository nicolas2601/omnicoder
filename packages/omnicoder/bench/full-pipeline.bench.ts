/**
 * Full-pipeline benchmark — 50 simulated tool calls that exercise the 6
 * OmniCoder hooks in sequence (same order as `src/index.ts`):
 *
 *   1. memory.inject           (experimental.chat.system.transform)
 *   2. router.inject           (experimental.chat.system.transform)
 *   3. security.check          (tool.execute.before)
 *   4. dispatcher.onComplete   (tool.execute.after)
 *   5. failover.tune           (chat.params)
 *   6. budget.onEvent          (event)
 *
 * Baseline v4.3.1 for 50 tool calls end-to-end: **2.0s**.
 * We measure wall-clock for the 50-call loop and expose per-stage p50 so
 * regressions are attributable.
 */
import { createMemoryLoader } from "../src/memory/index.ts"
import { createProviderFailover } from "../src/hooks/provider-failover.ts"
import { createSecurityGuard, SecurityError } from "../src/security/index.ts"
import { createSkillRouter } from "../src/router/index.ts"
import { createTokenBudget } from "../src/budget/index.ts"
import { createToolDispatcher } from "../src/hooks/tool-dispatcher.ts"
import {
  type BenchReport,
  fakePluginInput,
  mkBenchHome,
  ns,
  percentiles,
  pickSeeded,
  printReport,
  rmBenchHome,
  seeded,
} from "./_bench-util.ts"

const TOOL_CALLS = 50

const PROMPT =
  "necesito ayuda para optimizar el rendimiento de mi aplicacion react con hooks y memoization en produccion"

const SAFE_CMDS = [
  "git status",
  "ls -la",
  "cat package.json",
  "bun test --timeout 30000",
  "grep -r TODO src",
  "git log --oneline -20",
]

type StageStats = {
  memory: number[]
  router: number[]
  security: number[]
  dispatcher: number[]
  failover: number[]
  budget: number[]
}

export async function runFullPipelineBench(): Promise<{
  wallClockMs: number
  perCallP50Ns: number
  perCallP95Ns: number
  perCallMaxNs: number
  stages: Record<keyof StageStats, { p50: number; p95: number; mean: number }>
  iterations: number
  reports: BenchReport[]
}> {
  const { home, restore } = await mkBenchHome()
  try {
    const memory = await createMemoryLoader(fakePluginInput as never)
    const router = await createSkillRouter(fakePluginInput as never)
    const security = await createSecurityGuard(fakePluginInput as never)
    const dispatcher = await createToolDispatcher(fakePluginInput as never)
    const failover = await createProviderFailover(fakePluginInput as never)
    const budget = await createTokenBudget(fakePluginInput as never)

    // Warm both caches once so the benchmark is a fair representative of
    // steady-state (the v4 baseline also excludes first-ever rebuilds).
    await router.inject({ prompt: PROMPT }, { system: [] })
    await memory.inject({}, { system: [] })

    const stages: StageStats = {
      memory: [],
      router: [],
      security: [],
      dispatcher: [],
      failover: [],
      budget: [],
    }
    const perCall: number[] = []

    const rng = seeded(0xface)
    const t0 = ns()
    for (let i = 0; i < TOOL_CALLS; i++) {
      const callStart = ns()

      // 1 — memory
      let s = ns()
      const sys: string[] = []
      await memory.inject({}, { system: sys })
      stages.memory.push(ns() - s)

      // 2 — router
      s = ns()
      await router.inject({ prompt: PROMPT }, { system: sys })
      stages.router.push(ns() - s)

      // 3 — security (all safe here; dangerous is tested elsewhere)
      const cmd = pickSeeded(rng, SAFE_CMDS)
      s = ns()
      try {
        await security.check(
          { tool: "bash", sessionID: `sess${i}`, callID: `c${i}` },
          { args: { command: cmd } },
        )
      } catch (e) {
        if (!(e instanceof SecurityError)) throw e
      }
      stages.security.push(ns() - s)

      // 4 — dispatcher (post tool execute)
      s = ns()
      await dispatcher.onComplete(
        { tool: "bash", sessionID: `sess${i}`, callID: `c${i}`, args: { command: cmd } },
        { title: "bash", output: "ok".repeat(64), metadata: {} },
      )
      stages.dispatcher.push(ns() - s)

      // 5 — failover.tune
      s = ns()
      await failover.tune(
        { sessionID: `sess${i}`, agent: "coder", provider: { info: { id: "anthropic" } } },
        {},
      )
      stages.failover.push(ns() - s)

      // 6 — budget.onEvent (intermediate progress event, not session.completed,
      //     so it short-circuits — representative of the common case during
      //     a run. A session.completed event would trigger file IO, which v4
      //     also amortised over many tool calls).
      s = ns()
      await budget.onEvent({ type: "tool.call.completed", properties: { tokens: 120 } })
      stages.budget.push(ns() - s)

      perCall.push(ns() - callStart)
    }
    const wallClockNs = ns() - t0

    const summarize = (arr: number[]): { p50: number; p95: number; mean: number } => {
      const p = percentiles(arr)
      return { p50: p.p50, p95: p.p95, mean: p.mean }
    }

    const stageSummary = {
      memory: summarize(stages.memory),
      router: summarize(stages.router),
      security: summarize(stages.security),
      dispatcher: summarize(stages.dispatcher),
      failover: summarize(stages.failover),
      budget: summarize(stages.budget),
    }

    const perCallStats = percentiles(perCall)

    const reports: BenchReport[] = [
      {
        name: "pipeline.per-call",
        iterations: TOOL_CALLS,
        totalMs: wallClockNs / 1_000_000,
        stats: perCallStats,
      },
      ...(Object.entries(stages) as [keyof StageStats, number[]][]).map(([k, arr]) => ({
        name: `pipeline.${k}`,
        iterations: arr.length,
        totalMs: arr.reduce((a, b) => a + b, 0) / 1_000_000,
        stats: percentiles(arr),
      })),
    ]

    return {
      wallClockMs: wallClockNs / 1_000_000,
      perCallP50Ns: perCallStats.p50,
      perCallP95Ns: perCallStats.p95,
      perCallMaxNs: perCallStats.max,
      stages: stageSummary,
      iterations: TOOL_CALLS,
      reports,
    }
  } finally {
    restore()
    await rmBenchHome(home)
  }
}

if (import.meta.main) {
  const r = await runFullPipelineBench()
  for (const rep of r.reports) printReport(rep)
  console.log(`  wall-clock: ${r.wallClockMs.toFixed(1)}ms for ${r.iterations} tool calls`)
}
