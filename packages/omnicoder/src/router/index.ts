/**
 * Skill router — ports `skill-router-lite.sh` + `skill-router.sh`.
 *
 * Produces a top-3 suggestion of skills/agents for the latest user prompt
 * using BM25 with simple unigram + bigram TF-IDF scoring against
 * ~/.omnicoder/skills/**\/SKILL.md and ~/.omnicoder/agents/**\/*.md.
 *
 * - Fast-path: prompts under 10 words or greetings inject nothing.
 * - Output capped at 500 chars.
 * - In-memory cache with 60 s TTL over the index.
 */
import type { PluginInput } from "@opencode-ai/plugin"
import { promises as fs } from "node:fs"
import * as os from "node:os"
import * as path from "node:path"

// Bun caches os.homedir at first call; prefer $HOME so tests can override.
const resolveHome = (): string => process.env.HOME ?? os.homedir()

type Doc = { id: string; kind: "skill" | "agent"; name: string; tokens: string[] }
type Index = { docs: Doc[]; df: Map<string, number>; avgLen: number; builtAt: number }

const CACHE_TTL_MS = 60_000
const MAX_OUTPUT_CHARS = 500
const STOP = new Set([
  "the", "a", "an", "and", "or", "of", "to", "in", "on", "for", "with", "is", "are", "be",
  "la", "el", "los", "las", "de", "en", "un", "una", "y", "o", "que", "por", "con", "para",
])
const GREETINGS =
  /^(hola|holi|holis|ok|okay|listo|gracias|genial|perfecto|sigue|continua|si|no|dale|vale|bien|mal|buen(os|as)?\s|como\s+(estas|vas))/i

function tokenize(text: string): string[] {
  const lower = text.toLowerCase().normalize("NFKD").replace(/[\u0300-\u036f]/g, "")
  const words = lower.split(/[^a-z0-9]+/).filter((w) => w.length >= 2 && !STOP.has(w))
  const out: string[] = [...words]
  for (let i = 0; i + 1 < words.length; i++) out.push(`${words[i]}_${words[i + 1]}`)
  return out
}

async function readIf(f: string): Promise<string | null> {
  try { return await fs.readFile(f, "utf8") } catch { return null }
}

async function collect(root: string, kind: "skill" | "agent"): Promise<Doc[]> {
  const out: Doc[] = []
  let entries: Awaited<ReturnType<typeof fs.readdir>>
  try { entries = await fs.readdir(root, { withFileTypes: true }) } catch { return out }
  for (const e of entries) {
    const full = path.join(root, e.name)
    if (kind === "skill" && e.isDirectory()) {
      const md = await readIf(path.join(full, "SKILL.md"))
      if (md) out.push({ id: e.name, kind, name: e.name, tokens: tokenize(md.slice(0, 2000)) })
    } else if (kind === "agent" && e.isFile() && e.name.endsWith(".md")) {
      const md = await readIf(full)
      if (md) {
        const name = e.name.replace(/\.md$/, "")
        out.push({ id: name, kind, name, tokens: tokenize(`${name} ${md.slice(0, 2000)}`) })
      }
    }
  }
  return out
}

async function buildIndex(home: string): Promise<Index> {
  const [skills, agents] = await Promise.all([
    collect(path.join(home, ".omnicoder", "skills"), "skill"),
    collect(path.join(home, ".omnicoder", "agents"), "agent"),
  ])
  const docs = [...skills, ...agents]
  const df = new Map<string, number>()
  let total = 0
  for (const d of docs) {
    total += d.tokens.length
    for (const t of new Set(d.tokens)) df.set(t, (df.get(t) ?? 0) + 1)
  }
  return { docs, df, avgLen: docs.length ? total / docs.length : 0, builtAt: Date.now() }
}

function bm25(q: string[], d: Doc, idx: Index, k1 = 1.5, b = 0.75): number {
  const N = Math.max(1, idx.docs.length)
  const tf = new Map<string, number>()
  for (const t of d.tokens) tf.set(t, (tf.get(t) ?? 0) + 1)
  let s = 0
  for (const term of q) {
    const f = tf.get(term); if (!f) continue
    const dfq = idx.df.get(term) ?? 0; if (!dfq) continue
    const idf = Math.log(1 + (N - dfq + 0.5) / (dfq + 0.5))
    const norm = 1 - b + b * (d.tokens.length / Math.max(1, idx.avgLen))
    s += idf * ((f * (k1 + 1)) / (f + k1 * norm))
  }
  return s
}

export async function createSkillRouter(_input: PluginInput): Promise<{
  inject: (
    i: { sessionID?: string; model?: unknown; prompt?: string },
    o: { system: string[] },
  ) => Promise<void>
  _debug: { buildIndex: () => Promise<Index>; invalidate: () => void }
}> {
  let cached: Index | null = null
  // CR-03: dedupe in-flight rebuilds so two concurrent inject() misses don't
  // both scan the filesystem (duplicated work + torn cache).
  let inFlight: Promise<Index> | null = null

  async function getIndex(): Promise<Index> {
    if (cached && Date.now() - cached.builtAt < CACHE_TTL_MS) return cached
    if (inFlight) return inFlight
    inFlight = buildIndex(resolveHome()).finally(() => { inFlight = null })
    cached = await inFlight
    return cached
  }

  async function inject(
    i: { sessionID?: string; model?: unknown; prompt?: string },
    o: { system: string[] },
  ): Promise<void> {
    try {
      const prompt = (i.prompt ?? "").trim()
      if (!prompt) return
      if (prompt.split(/\s+/).filter(Boolean).length < 10) return
      if (GREETINGS.test(prompt)) return
      const idx = await getIndex()
      if (!idx.docs.length) return
      const query = tokenize(prompt)
      if (!query.length) return
      const top = idx.docs
        .map((d) => ({ d, s: bm25(query, d, idx) }))
        .filter((x) => x.s > 0)
        .sort((a, b) => b.s - a.s)
        .slice(0, 3)
      if (!top.length) return
      const line = `[OMNICODER] Sugeridos: ${top.map((x) => x.d.name).join(", ")}`
      o.system.push(line.length > MAX_OUTPUT_CHARS ? line.slice(0, MAX_OUTPUT_CHARS) : line)
    } catch (err) {
      console.error("[omnicoder:router]", (err as Error).message)
    }
  }

  return {
    inject,
    _debug: {
      buildIndex: () => buildIndex(resolveHome()),
      invalidate: () => { cached = null },
    },
  }
}
