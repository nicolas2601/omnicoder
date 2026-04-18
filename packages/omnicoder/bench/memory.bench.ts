/**
 * Memory loader benchmark:
 *   - initial load: first `inject()` call (reads + caches patterns/feedback).
 *   - 100 cache hits: subsequent calls within the 30s TTL window.
 *
 * Measures both latencies and injected byte size.
 */
import { createMemoryLoader } from "../src/memory/index.ts"
import {
  type BenchReport,
  fakePluginInput,
  mkBenchHome,
  ns,
  percentiles,
  printReport,
  rmBenchHome,
} from "./_bench-util.ts"

const HIT_ITER = 100

export async function runMemoryBench(): Promise<{
  cold: BenchReport<{ bytes: number }>
  hot: BenchReport<{ bytes: number }>
}> {
  const { home, restore } = await mkBenchHome({ memoryBytes: 2200 })
  try {
    const mem = await createMemoryLoader(fakePluginInput as never)
    mem._debug.invalidate()

    // Cold load
    const out0: { system: string[] } = { system: [] }
    const s0 = ns()
    await mem.inject({}, out0)
    const coldDuration = ns() - s0
    const bytes = out0.system[0] ? Buffer.byteLength(out0.system[0], "utf8") : 0

    // Warm hits
    const samples: number[] = new Array<number>(HIT_ITER)
    const t0 = ns()
    for (let i = 0; i < HIT_ITER; i++) {
      const o: { system: string[] } = { system: [] }
      const s = ns()
      await mem.inject({}, o)
      samples[i] = ns() - s
    }
    const totalMs = (ns() - t0) / 1_000_000

    return {
      cold: {
        name: "memory.cold",
        iterations: 1,
        totalMs: coldDuration / 1_000_000,
        stats: percentiles([coldDuration]),
        extra: { bytes },
      },
      hot: {
        name: "memory.hot",
        iterations: HIT_ITER,
        totalMs,
        stats: percentiles(samples),
        extra: { bytes },
      },
    }
  } finally {
    restore()
    await rmBenchHome(home)
  }
}

if (import.meta.main) {
  const r = await runMemoryBench()
  printReport(r.cold)
  printReport(r.hot)
  console.log(`  injected ~${r.hot.extra?.bytes ?? 0} bytes of memory payload`)
}
