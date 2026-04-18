/**
 * Router benchmark — measures `createSkillRouter().inject()` over 193 real
 * SKILL.md documents.
 *
 *  - cold: each iteration invalidates the 60s index cache, forcing an index
 *          rebuild (buildIndex walks ~/.omnicoder/{skills,agents}).
 *  - warm: cache stays hot; measures only BM25 scoring + tokenisation.
 *
 * 1000 iterations per mode. Deterministic prompts seeded from a fixed rng.
 */
import { createSkillRouter } from "../src/router/index.ts"
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

const PROMPTS = [
  "necesito ayuda para optimizar el rendimiento de mi aplicacion react con hooks y memoization en produccion",
  "build a ci pipeline with github actions that runs bun tests and deploys to vercel on merge",
  "audit my website for seo issues and core web vitals with structured data validation",
  "help me design a brutalism landing page with bento grid and dark mode in tailwind shadcn",
  "write a django rest framework viewset with authentication and throttling for a products api",
  "review the smart contract for reentrancy attacks and optimize gas consumption across all paths",
  "design a mobile app flow with react native and expo router using fast list for large datasets",
  "analyze the swarm coordination topology and recommend hierarchical vs mesh based on latency",
  "create a programmatic seo strategy for a marketplace that generates location pages at scale",
  "refactor this legacy javascript to typescript with strict mode and proper generics everywhere",
  "debug why my animation is janky in gsap when scrolling on mobile safari at 60fps",
  "set up prompt caching in anthropic sdk for claude opus with tools and system messages",
  "integrate postgres with prisma and write migrations that do not lock the table on large tables",
  "build a nextjs app router page with parallel routes and streaming suspense boundaries",
  "design an accessibility audit plan for a saas dashboard following wcag aa requirements",
  "profile memory leaks in node process using clinic doctor and heap snapshots on production",
  "plan a sprint for the team focusing on onboarding experience and reducing time to value",
  "write an incident response runbook for database primary failover with slo rollback criteria",
  "implement a byzantine fault tolerant consensus protocol with practical view change logic",
  "generate hero images for a fintech landing page with glassmorphism and vibrant gradients",
]

// Cold rebuild walks 193 skills + 168 agents ≈ ~180ms/iter on a hot FS,
// so we cap cold at 50 iterations (still well above the typical cold-hit
// rate in production: once every 60s per the CACHE_TTL_MS).
// Warm is the common path → 1000 iter per spec.
const ITER_WARM = 1000
const ITER_COLD = 50

async function runMode(
  mode: "cold" | "warm",
  router: Awaited<ReturnType<typeof createSkillRouter>>,
): Promise<BenchReport> {
  const rng = seeded(mode === "cold" ? 0xc01d : 0x7a6b)
  const iter = mode === "cold" ? ITER_COLD : ITER_WARM
  const samples: number[] = new Array<number>(iter)
  const t0 = ns()

  // Warm cache once so "warm" truly measures a hot path.
  if (mode === "warm") {
    await router.inject({ prompt: PROMPTS[0] }, { system: [] })
  }

  for (let i = 0; i < iter; i++) {
    const prompt = pickSeeded(rng, PROMPTS)
    const out: { system: string[] } = { system: [] }
    if (mode === "cold") router._debug.invalidate()
    const start = ns()
    await router.inject({ prompt }, out)
    samples[i] = ns() - start
  }
  const totalMs = (ns() - t0) / 1_000_000
  return {
    name: `router.${mode}`,
    iterations: iter,
    totalMs,
    stats: percentiles(samples),
  }
}

export async function runRouterBench(): Promise<{
  cold: BenchReport
  warm: BenchReport
  skillCount: number
  agentCount: number
}> {
  const { home, restore, skillCount, agentCount } = await mkBenchHome()
  try {
    const router = await createSkillRouter(fakePluginInput as never)
    router._debug.invalidate()
    // Ensure the index is built at least once so first "warm" sample is hot.
    await router.inject({ prompt: PROMPTS[0] }, { system: [] })

    const cold = await runMode("cold", router)
    const warm = await runMode("warm", router)
    return { cold, warm, skillCount, agentCount }
  } finally {
    restore()
    await rmBenchHome(home)
  }
}

if (import.meta.main) {
  const r = await runRouterBench()
  console.log(`router: ${r.skillCount} skills + ${r.agentCount} agents indexed`)
  printReport(r.cold)
  printReport(r.warm)
}
