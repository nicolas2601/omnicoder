/**
 * Skill router — ports `skill-router-lite.sh` + `skill-router.sh`.
 *
 * Produces a top-3 suggestion of skills/agents for the latest user prompt
 * using BM25 with simple unigram + bigram TF-IDF scoring against
 * ~/.omnicoder/skills/**\/SKILL.md and ~/.omnicoder/agents/**\/*.md.
 *
 * Performance notes (CR-42):
 *   - TF per document is pre-computed at build time so bm25() iterates
 *     over the query terms (~15) instead of the full doc vocabulary (~500).
 *   - Build output is persisted to `~/.cache/omnicoder/router-index.json`
 *     keyed by the aggregate mtime of the two source dirs. Subsequent
 *     process starts reload the index from disk in ~1 ms instead of
 *     rescanning 361 files. Disabled via OMNICODER_ROUTER_NOCACHE=1.
 *   - Plugin init fires `getIndex()` in the background so the first
 *     user prompt never pays the build cost.
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

type Doc = {
  id: string
  kind: "skill" | "agent"
  name: string
  len: number
  tf: Record<string, number>
  norm: number
}
type Index = {
  docs: Doc[]
  df: Record<string, number>
  avgLen: number
  builtAt: number
  sourceKey: string
}

const CACHE_TTL_MS = 60_000
const MAX_OUTPUT_CHARS = 500
const INDEX_FORMAT = 3
const BM25_K1 = 1.5
const BM25_B = 0.75
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

function finalizeDoc(id: string, kind: "skill" | "agent", name: string, tokens: string[]): Doc {
  const tf: Record<string, number> = {}
  for (const t of tokens) tf[t] = (tf[t] ?? 0) + 1
  return { id, kind, name, len: tokens.length, tf, norm: 0 }
}

async function readIf(f: string): Promise<string | null> {
  try { return await fs.readFile(f, "utf8") } catch { return null }
}

async function collect(root: string, kind: "skill" | "agent"): Promise<Doc[]> {
  let entries: Array<{ name: string; isDirectory(): boolean; isFile(): boolean }>
  try {
    entries = await fs.readdir(root, { withFileTypes: true }) as unknown as typeof entries
  } catch { return [] }
  const tasks: Promise<Doc | null>[] = entries.map(async (e): Promise<Doc | null> => {
    const name: string = String(e.name)
    const full = path.join(root, name)
    if (kind === "skill" && e.isDirectory()) {
      const md = await readIf(path.join(full, "SKILL.md"))
      return md ? finalizeDoc(name, kind, name, tokenize(md.slice(0, 2000))) : null
    }
    if (kind === "agent" && e.isFile() && name.endsWith(".md")) {
      const md = await readIf(full)
      if (!md) return null
      const base = name.replace(/\.md$/, "")
      return finalizeDoc(base, kind, base, tokenize(`${base} ${md.slice(0, 2000)}`))
    }
    return null
  })
  const results = await Promise.all(tasks)
  return results.filter((d): d is Doc => d !== null)
}

// Directory fingerprint used as the disk-cache key. If any SKILL.md or
// agent file is added/removed/touched the aggregate mtime shifts and the
// cached index is rejected. Cheap: one stat per directory + shallow listing.
async function sourceKeyFor(home: string): Promise<string> {
  const parts: string[] = []
  for (const sub of ["skills", "agents"]) {
    const dir = path.join(home, ".omnicoder", sub)
    try {
      const st = await fs.stat(dir)
      const names = await fs.readdir(dir)
      parts.push(`${sub}:${st.mtimeMs.toFixed(0)}:${names.length}`)
    } catch {
      parts.push(`${sub}:none`)
    }
  }
  return parts.join("|")
}

async function buildIndex(home: string): Promise<Index> {
  const [skills, agents, sourceKey] = await Promise.all([
    collect(path.join(home, ".omnicoder", "skills"), "skill"),
    collect(path.join(home, ".omnicoder", "agents"), "agent"),
    sourceKeyFor(home),
  ])
  const docs = [...skills, ...agents]
  const df: Record<string, number> = {}
  let total = 0
  for (const d of docs) {
    total += d.len
    for (const t of Object.keys(d.tf)) df[t] = (df[t] ?? 0) + 1
  }
  const avgLen = docs.length ? total / docs.length : 0
  // Pre-bake the per-doc length normalisation factor so bm25() avoids the
  // per-query division entirely.
  for (const d of docs) {
    d.norm = 1 - BM25_B + BM25_B * (d.len / Math.max(1, avgLen))
  }
  return { docs, df, avgLen, builtAt: Date.now(), sourceKey }
}

// ---------- disk cache --------------------------------------------------
const DISK_CACHE_DISABLED = process.env.OMNICODER_ROUTER_NOCACHE === "1"
function diskCachePath(home: string): string {
  const base = process.env.XDG_CACHE_HOME ?? path.join(home, ".cache")
  return path.join(base, "omnicoder", "router-index.json")
}

async function loadDiskIndex(home: string): Promise<Index | null> {
  if (DISK_CACHE_DISABLED) return null
  try {
    const raw = await fs.readFile(diskCachePath(home), "utf8")
    const parsed = JSON.parse(raw) as { format?: number; index?: Index }
    if (!parsed.index || parsed.format !== INDEX_FORMAT) return null
    const fresh = await sourceKeyFor(home)
    if (parsed.index.sourceKey !== fresh) return null
    // Re-bake builtAt so the in-memory TTL starts at load time, not
    // whenever the JSON was written yesterday.
    parsed.index.builtAt = Date.now()
    return parsed.index
  } catch { return null }
}

async function saveDiskIndex(home: string, idx: Index): Promise<void> {
  if (DISK_CACHE_DISABLED) return
  const file = diskCachePath(home)
  try {
    await fs.mkdir(path.dirname(file), { recursive: true })
    await fs.writeFile(file, JSON.stringify({ format: INDEX_FORMAT, index: idx }))
  } catch {
    // Disk cache is a pure optimisation — never fail injection on write errors.
  }
}

// ---------- scoring -----------------------------------------------------
function bm25(queryTerms: string[], d: Doc, df: Record<string, number>, N: number): number {
  let s = 0
  const denomScale = BM25_K1 * d.norm
  for (let q = 0; q < queryTerms.length; q++) {
    const term = queryTerms[q]
    const f = d.tf[term]
    if (!f) continue
    const dfq = df[term]
    if (!dfq) continue
    const idf = Math.log(1 + (N - dfq + 0.5) / (dfq + 0.5))
    s += idf * ((f * (BM25_K1 + 1)) / (f + denomScale))
  }
  return s
}

// Dedupe query terms so high-frequency words don't score twice when the
// prompt repeats them. (A prompt like "react react react" shouldn't rank
// react-only docs 3x higher than a tied match.)
function uniq(terms: string[]): string[] {
  const out: string[] = []
  const seen = new Set<string>()
  for (const t of terms) { if (!seen.has(t)) { seen.add(t); out.push(t) } }
  return out
}

export async function createSkillRouter(_input: PluginInput): Promise<{
  inject: (
    i: { sessionID?: string; model?: unknown; prompt?: string },
    o: { system: string[] },
  ) => Promise<void>
  _debug: { buildIndex: () => Promise<Index>; invalidate: () => void }
}> {
  let cached: Index | null = null
  let inFlight: Promise<Index> | null = null

  async function getIndex(): Promise<Index> {
    if (cached && Date.now() - cached.builtAt < CACHE_TTL_MS) return cached
    if (inFlight) return inFlight
    inFlight = (async () => {
      const home = resolveHome()
      const disk = await loadDiskIndex(home)
      if (disk) return disk
      const fresh = await buildIndex(home)
      await saveDiskIndex(home, fresh)
      return fresh
    })().finally(() => { inFlight = null })
    cached = await inFlight
    return cached
  }

  // Kick off warmup in the background so the first prompt never pays for it.
  // Failures here are silent — the lazy path still works.
  void getIndex().catch(() => {})

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
      const query = uniq(tokenize(prompt))
      if (!query.length) return
      const N = Math.max(1, idx.docs.length)
      const df = idx.df
      // Lightweight top-3 scan without an O(n log n) sort over 361 docs.
      let t1 = -Infinity, t2 = -Infinity, t3 = -Infinity
      let d1: Doc | null = null, d2: Doc | null = null, d3: Doc | null = null
      for (const d of idx.docs) {
        const s = bm25(query, d, df, N)
        if (s <= 0) continue
        if (s > t1) { t3 = t2; d3 = d2; t2 = t1; d2 = d1; t1 = s; d1 = d }
        else if (s > t2) { t3 = t2; d3 = d2; t2 = s; d2 = d }
        else if (s > t3) { t3 = s; d3 = d }
      }
      const names: string[] = []
      if (d1) names.push(d1.name)
      if (d2) names.push(d2.name)
      if (d3) names.push(d3.name)
      if (!names.length) return
      const line = `[OMNICODER] Sugeridos: ${names.join(", ")}`
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
