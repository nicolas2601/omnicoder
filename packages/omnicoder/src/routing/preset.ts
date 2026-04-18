/**
 * routing/preset.ts — applies a per-phase routing preset to the user's
 * opencode.jsonc.
 *
 * `chat.params` in opencode lets a plugin read `input.agent` but not mutate
 * `input.model`, so per-phase model routing has to happen at config layer.
 * This module reads `.omnicoder/routing-presets.json`, looks up the named
 * preset, and patches just the `agent: { ... }` block in the user's config
 * without disturbing comments, MCP servers, plugins, or permissions.
 *
 * Strategy for editing JSONC without a full parser:
 *   - Find the top-level `"agent"` key with a small state machine that
 *     tracks string literals and brace depth (lets us match the balanced
 *     block even when the user has `agent` strings inside other values).
 *   - Replace the value. If no `agent` key exists, splice one in before
 *     the final closing brace.
 *   - Line-comments (`// …`) and block-comments (`/* … *\/`) are preserved
 *     because we only touch the agent block and the rest of the file is
 *     copied verbatim.
 *
 * Import shape is deliberately tiny so this can be called from a thin
 * shell wrapper (`scripts/routing.sh` / `routing.ps1`) or directly via
 * `bun packages/omnicoder/src/routing/preset.ts <cmd> [args]`.
 */
import { promises as fs } from "node:fs"
import * as os from "node:os"
import * as path from "node:path"

export type AgentOverride = Record<string, { model?: string }>
export type Preset = {
  description: string
  requires?: string[]
  agent: AgentOverride
}
export type PresetsFile = {
  description?: string
  presets: Record<string, Preset>
}

// ---- config path resolution ------------------------------------------------
// Prefer $HOME over os.homedir() so tests can relocate the whole lookup
// to a tmp dir via `process.env.HOME = …`. os.homedir() is cached by Node
// on first access and would otherwise leak into the test environment.
function resolveHome(): string {
  return process.env.HOME ?? os.homedir()
}

export function userConfigPath(): string {
  if (process.platform === "win32") {
    const appdata = process.env.APPDATA ?? path.join(resolveHome(), "AppData", "Roaming")
    return path.join(appdata, "opencode", "opencode.jsonc")
  }
  const xdg = process.env.XDG_CONFIG_HOME ?? path.join(resolveHome(), ".config")
  return path.join(xdg, "opencode", "opencode.jsonc")
}

function presetsPath(): string {
  // User-level copy wins over the repo-shipped defaults so personal presets
  // survive package reinstalls.
  return path.join(resolveHome(), ".omnicoder", "routing-presets.json")
}

async function repoPresetsPath(): Promise<string | null> {
  // Walk up from __dirname to find the repo's .omnicoder dir. Used as a
  // fallback when the user never copied the file.
  let dir = path.dirname(new URL(import.meta.url).pathname)
  for (let i = 0; i < 6; i++) {
    const candidate = path.join(dir, ".omnicoder", "routing-presets.json")
    try { await fs.access(candidate); return candidate } catch {}
    const parent = path.dirname(dir)
    if (parent === dir) break
    dir = parent
  }
  return null
}

export async function loadPresets(): Promise<PresetsFile> {
  for (const candidate of [presetsPath(), await repoPresetsPath()]) {
    if (!candidate) continue
    try {
      const raw = await fs.readFile(candidate, "utf8")
      return JSON.parse(raw) as PresetsFile
    } catch {
      continue
    }
  }
  throw new Error("routing-presets.json not found in ~/.omnicoder/ or repo")
}

// ---- JSONC editor ----------------------------------------------------------
// Find the top-level `"agent"` key and return [valueStart, valueEnd, keyStart]
// where valueStart is the `{` and valueEnd is the matching `}` (inclusive).
// Returns null when the key is absent. Ignores occurrences inside strings
// and nested objects.
function findAgentBlock(src: string): { keyStart: number; valueStart: number; valueEnd: number } | null {
  let i = 0
  let depth = 0
  let inString = false
  let inLineComment = false
  let inBlockComment = false
  // Track "where the last top-level key started" so when we hit a top-level
  // string "agent" we can confirm it's a key (followed by `:`), not a value.
  const keyRegex = /"agent"\s*:/y

  while (i < src.length) {
    const c = src[i]
    const next = src[i + 1]
    if (inLineComment) {
      if (c === "\n") inLineComment = false
      i++
      continue
    }
    if (inBlockComment) {
      if (c === "*" && next === "/") { inBlockComment = false; i += 2; continue }
      i++
      continue
    }
    if (inString) {
      if (c === "\\") { i += 2; continue }
      if (c === "\"") inString = false
      i++
      continue
    }
    if (c === "/" && next === "/") { inLineComment = true; i += 2; continue }
    if (c === "/" && next === "*") { inBlockComment = true; i += 2; continue }
    if (c === "\"") {
      // At depth 1 (inside the top-level object), check for "agent" key.
      if (depth === 1) {
        keyRegex.lastIndex = i
        const m = keyRegex.exec(src)
        if (m && m.index === i) {
          const keyStart = i
          // Skip the key and colon, then find the opening `{` / value start.
          let j = keyRegex.lastIndex
          while (j < src.length && /\s/.test(src[j])) j++
          if (src[j] !== "{") return null
          const valueStart = j
          // Scan balanced braces starting at valueStart.
          let d = 0, k = valueStart, s = false, lc = false, bc = false
          while (k < src.length) {
            const cc = src[k], nn = src[k + 1]
            if (lc) { if (cc === "\n") lc = false; k++; continue }
            if (bc) { if (cc === "*" && nn === "/") { bc = false; k += 2; continue } k++; continue }
            if (s) { if (cc === "\\") { k += 2; continue } if (cc === "\"") s = false; k++; continue }
            if (cc === "/" && nn === "/") { lc = true; k += 2; continue }
            if (cc === "/" && nn === "*") { bc = true; k += 2; continue }
            if (cc === "\"") { s = true; k++; continue }
            if (cc === "{") d++
            else if (cc === "}") { d--; if (d === 0) return { keyStart, valueStart, valueEnd: k } }
            k++
          }
          return null
        }
      }
      inString = true
      i++
      continue
    }
    if (c === "{") depth++
    else if (c === "}") depth--
    i++
  }
  return null
}

function renderAgentBlock(agent: AgentOverride, indent = "  "): string {
  const keys = Object.keys(agent)
  if (!keys.length) return "{}"
  const lines = keys.map((k) => {
    const cfg = agent[k]
    const model = cfg.model ? ` "model": ${JSON.stringify(cfg.model)} ` : " "
    return `${indent}${indent}${JSON.stringify(k)}: {${model}}`
  })
  return `{\n${lines.join(",\n")}\n${indent}}`
}

export async function applyPreset(name: string): Promise<{ path: string; changed: boolean }> {
  const presets = await loadPresets()
  const p = presets.presets[name]
  if (!p) {
    const available = Object.keys(presets.presets).join(", ")
    throw new Error(`unknown preset "${name}" (available: ${available})`)
  }
  if (p.requires && p.requires.length) {
    const missing = p.requires.filter((v) => !process.env[v])
    if (missing.length) {
      console.warn(
        `[routing] preset "${name}" wants ${missing.join(", ")} to be set, ` +
        `but that env var is not exported yet. Applying anyway.`,
      )
    }
  }
  const cfgPath = userConfigPath()
  let src: string
  try {
    src = await fs.readFile(cfgPath, "utf8")
  } catch {
    throw new Error(`opencode.jsonc not found at ${cfgPath} — run omnicoder install first`)
  }
  const block = findAgentBlock(src)
  const newValue = renderAgentBlock(p.agent)
  let next: string
  if (block) {
    next = src.slice(0, block.valueStart) + newValue + src.slice(block.valueEnd + 1)
  } else {
    // Insert just before the final closing `}` of the config object.
    const lastBrace = src.lastIndexOf("}")
    if (lastBrace < 0) throw new Error("opencode.jsonc has no closing brace")
    const pre = src.slice(0, lastBrace).replace(/,?\s*$/, "")
    const post = src.slice(lastBrace)
    next = `${pre},\n  "agent": ${newValue}\n${post}`
  }
  if (next === src) return { path: cfgPath, changed: false }
  // Back up the original once per apply so the user can revert if they hate
  // the preset they just picked.
  try { await fs.copyFile(cfgPath, cfgPath + ".bak") } catch {}
  await fs.writeFile(cfgPath, next)
  return { path: cfgPath, changed: true }
}

export async function listPresets(): Promise<string> {
  const presets = await loadPresets()
  const names = Object.keys(presets.presets)
  const rows = names.map((n) => {
    const p = presets.presets[n]
    const req = p.requires?.length ? ` (needs ${p.requires.join(", ")})` : ""
    return `  ${n.padEnd(20)} ${p.description}${req}`
  })
  return ["Available routing presets:", ...rows, "", "Use: omnicoder-routing apply <name>"].join("\n")
}

export async function getCurrent(): Promise<string> {
  const cfgPath = userConfigPath()
  let src: string
  try { src = await fs.readFile(cfgPath, "utf8") } catch { return "no opencode.jsonc found" }
  const block = findAgentBlock(src)
  if (!block) return `no "agent" block in ${cfgPath} — using TUI default for all phases`
  const value = src.slice(block.valueStart, block.valueEnd + 1)
  return `Current agent routing in ${cfgPath}:\n${value}`
}

// ---- CLI entry -------------------------------------------------------------
if (import.meta.main) {
  const [cmd, arg] = process.argv.slice(2)
  try {
    if (!cmd || cmd === "list") {
      console.log(await listPresets())
    } else if (cmd === "get" || cmd === "status") {
      console.log(await getCurrent())
    } else if (cmd === "apply" || cmd === "set") {
      if (!arg) throw new Error("usage: omnicoder-routing apply <preset>")
      const r = await applyPreset(arg)
      console.log(
        r.changed
          ? `Applied preset "${arg}" to ${r.path} (backup at ${r.path}.bak). Restart the TUI to pick up the change.`
          : `No change — preset "${arg}" matches current config at ${r.path}.`,
      )
    } else if (cmd === "off" || cmd === "reset") {
      const r = await applyPreset("default")
      console.log(
        r.changed
          ? `Reset routing — TUI /models selection now wins. Restart the TUI.`
          : `No change — routing was already default.`,
      )
    } else {
      throw new Error(`unknown command "${cmd}". Try: list | get | apply <name> | off`)
    }
  } catch (err) {
    console.error(`[routing] ${(err as Error).message}`)
    process.exit(1)
  }
}
