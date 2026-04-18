/**
 * Memory loader — ports `memory-loader.sh`.
 *
 * Appends the contents of ~/.omnicoder/memory/patterns.md and feedback.md
 * to the system prompt, capped at 1200 bytes combined, cached for 30 s.
 * Skipped when the `engram` MCP server is configured (its memories are
 * already surfaced by the MCP layer).
 */
import type { PluginInput } from "@opencode-ai/plugin"
import { promises as fs } from "node:fs"
import * as os from "node:os"
import * as path from "node:path"

function resolveHome(): string {
  return process.env.HOME ?? os.homedir()
}

const CACHE_TTL_MS = 30_000
const MAX_BYTES = 1200

type CacheEntry = { text: string | null; builtAt: number }

async function readIf(file: string): Promise<string | null> {
  try {
    return await fs.readFile(file, "utf8")
  } catch {
    return null
  }
}

async function isEngramConfigured(home: string): Promise<boolean> {
  const candidates = [
    path.join(home, ".omnicoder", "config.json"),
    path.join(home, ".config", "opencode", "opencode.json"),
    path.join(home, ".opencode", "config.json"),
  ]
  for (const f of candidates) {
    const raw = await readIf(f)
    if (!raw) continue
    try {
      const parsed = JSON.parse(raw) as { mcp?: Record<string, unknown> }
      if (parsed.mcp && Object.prototype.hasOwnProperty.call(parsed.mcp, "engram")) {
        return true
      }
    } catch {
      /* ignore */
    }
  }
  return false
}

async function loadMemory(home: string): Promise<string | null> {
  if (await isEngramConfigured(home)) return null

  const memDir = path.join(home, ".omnicoder", "memory")
  const [patterns, feedback] = await Promise.all([
    readIf(path.join(memDir, "patterns.md")),
    readIf(path.join(memDir, "feedback.md")),
  ])

  const parts: string[] = []
  if (patterns?.trim()) parts.push(`## [PAT] patterns.md\n${patterns.trim()}`)
  if (feedback?.trim()) parts.push(`## [FB] feedback.md\n${feedback.trim()}`)
  if (parts.length === 0) return null

  let combined = parts.join("\n\n")
  if (Buffer.byteLength(combined, "utf8") > MAX_BYTES) {
    // trim by characters until under limit (conservative upper bound)
    while (Buffer.byteLength(combined, "utf8") > MAX_BYTES && combined.length > 0) {
      combined = combined.slice(0, combined.length - 64)
    }
    combined += "\n…"
  }
  return `[OMNICODER-MEM]\n${combined}`
}

export async function createMemoryLoader(_input: PluginInput): Promise<{
  inject: (
    i: { sessionID?: string; model?: unknown },
    o: { system: string[] },
  ) => Promise<void>
  _debug: { load: () => Promise<string | null>; invalidate: () => void }
}> {
  let cache: CacheEntry | null = null

  async function getCached(): Promise<string | null> {
    if (cache && Date.now() - cache.builtAt < CACHE_TTL_MS) return cache.text
    const text = await loadMemory(resolveHome())
    cache = { text, builtAt: Date.now() }
    return text
  }

  async function inject(
    _i: { sessionID?: string; model?: unknown },
    o: { system: string[] },
  ): Promise<void> {
    try {
      const text = await getCached()
      if (text) o.system.push(text)
    } catch (err) {
      console.error("[omnicoder:memory]", (err as Error).message)
    }
  }

  return {
    inject,
    _debug: {
      load: () => loadMemory(resolveHome()),
      invalidate: () => {
        cache = null
      },
    },
  }
}
