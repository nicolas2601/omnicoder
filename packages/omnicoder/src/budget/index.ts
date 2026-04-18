/**
 * Token budget tracker — ports `token-budget.sh`.
 *
 * Appends one JSON line per completed session to
 * ~/.omnicoder/logs/token-log.jsonl and reports a warning on stderr when the
 * rolling 10-session average exceeds 15 000 tokens.
 */
import type { PluginInput } from "@opencode-ai/plugin"
import { promises as fs } from "node:fs"
import * as os from "node:os"
import * as path from "node:path"

function resolveHome(): string {
  return process.env.HOME ?? os.homedir()
}

const WARN_THRESHOLD = 15_000
const ROLLING_WINDOW = 10

type BudgetEvent = { type?: string; properties?: Record<string, unknown> } | Record<string, unknown>

function extractTokens(ev: BudgetEvent): number {
  const probe = (obj: unknown, keys: string[]): number => {
    if (!obj || typeof obj !== "object") return 0
    const o = obj as Record<string, unknown>
    for (const k of keys) {
      const v = o[k]
      if (typeof v === "number" && Number.isFinite(v)) return Math.max(0, Math.floor(v))
      if (typeof v === "string" && /^\d+$/.test(v)) return parseInt(v, 10)
    }
    return 0
  }
  const keys = ["total_tokens", "tokens", "tokens_total", "tokens_input", "input_tokens"]
  return probe(ev, keys) || probe((ev as { properties?: unknown }).properties, keys)
}

function isSessionCompleted(ev: BudgetEvent): boolean {
  const t = (ev as { type?: unknown }).type
  return typeof t === "string" && /session\.(completed|ended|end)/.test(t)
}

export type BudgetStats = {
  entries: number
  avg: number
  last: number
  overThreshold: boolean
}

export async function createTokenBudget(_input: PluginInput): Promise<{
  onEvent: (event: BudgetEvent) => Promise<void>
  getStats: () => Promise<BudgetStats>
  _debug: { logPath: string }
}> {
  // Resolve lazily per-op so tests can swap $HOME between sessions.
  const getPaths = () => {
    const home = resolveHome()
    const logDir = path.join(home, ".omnicoder", "logs")
    return { logDir, logPath: path.join(logDir, "token-log.jsonl") }
  }

  async function readTail(n: number): Promise<number[]> {
    try {
      const raw = await fs.readFile(getPaths().logPath, "utf8")
      const lines = raw.split("\n").filter(Boolean).slice(-n)
      return lines
        .map((l) => {
          try {
            const parsed = JSON.parse(l) as { tokens?: unknown }
            const t = parsed.tokens
            return typeof t === "number" ? t : 0
          } catch {
            return 0
          }
        })
        .filter((n) => n > 0)
    } catch {
      return []
    }
  }

  async function onEvent(event: BudgetEvent): Promise<void> {
    try {
      if (!isSessionCompleted(event)) return
      const tokens = extractTokens(event)
      if (!tokens) return
      const { logDir, logPath } = getPaths()
      await fs.mkdir(logDir, { recursive: true })
      const line = JSON.stringify({ ts: new Date().toISOString(), tokens }) + "\n"
      await fs.appendFile(logPath, line, "utf8")

      const recent = await readTail(ROLLING_WINDOW)
      if (recent.length === 0) return
      const avg = Math.floor(recent.reduce((a, b) => a + b, 0) / recent.length)
      if (avg > WARN_THRESHOLD) {
        console.error(
          `[omnicoder:budget] avg ${avg} tokens over last ${recent.length} sessions exceeds threshold ${WARN_THRESHOLD}`,
        )
      }
    } catch (err) {
      console.error("[omnicoder:budget]", (err as Error).message)
    }
  }

  async function getStats(): Promise<BudgetStats> {
    const recent = await readTail(ROLLING_WINDOW)
    const avg = recent.length ? Math.floor(recent.reduce((a, b) => a + b, 0) / recent.length) : 0
    const last = recent.length ? (recent[recent.length - 1] ?? 0) : 0
    return { entries: recent.length, avg, last, overThreshold: avg > WARN_THRESHOLD }
  }

  return {
    onEvent,
    getStats,
    _debug: {
      get logPath() {
        return getPaths().logPath
      },
    },
  }
}
