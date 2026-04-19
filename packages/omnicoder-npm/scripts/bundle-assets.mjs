#!/usr/bin/env node
// bundle-assets — called by `npm pack` / `prepack`.
// Snapshots the repo's .opencode/{agent,command} + .omnicoder/ + theme
// + routing-presets.json into packages/omnicoder-npm/assets/ so the published
// tarball is self-contained.

import { cp, mkdir, rm, readFile, writeFile } from "node:fs/promises"
import { existsSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const pkgDir = path.resolve(__dirname, "..")
const repoRoot = path.resolve(pkgDir, "..", "..")
const assetsDir = path.join(pkgDir, "assets")

async function copyTree(src, dst) {
  if (!existsSync(src)) {
    console.warn(`[bundle-assets] skip missing: ${src}`)
    return 0
  }
  await mkdir(path.dirname(dst), { recursive: true })
  await cp(src, dst, { recursive: true })
  return 1
}

console.log(`[bundle-assets] repo root: ${repoRoot}`)
console.log(`[bundle-assets] target: ${assetsDir}`)

await rm(assetsDir, { recursive: true, force: true })
await mkdir(assetsDir, { recursive: true })

// 1. Agents and commands from .opencode/
await copyTree(
  path.join(repoRoot, ".opencode", "agent"),
  path.join(assetsDir, "agent"),
)
await copyTree(
  path.join(repoRoot, ".opencode", "command"),
  path.join(assetsDir, "command"),
)

// 2. Theme
const themeSrc = path.join(
  repoRoot,
  "packages",
  "opencode",
  "src",
  "cli",
  "cmd",
  "tui",
  "context",
  "theme",
  "omnicoder.json",
)
if (existsSync(themeSrc)) {
  await mkdir(path.join(assetsDir, "theme"), { recursive: true })
  await cp(themeSrc, path.join(assetsDir, "theme", "omnicoder.json"))
  console.log("[bundle-assets] theme omnicoder.json ✓")
}

// 3. Routing presets
const presetsSrc = path.join(repoRoot, ".omnicoder", "routing-presets.json")
if (existsSync(presetsSrc)) {
  await cp(presetsSrc, path.join(assetsDir, "routing-presets.json"))
  console.log("[bundle-assets] routing-presets.json ✓")
}

// 4. Default opencode.jsonc template (user gets it on first install if none)
const templateSrc = path.join(repoRoot, ".omnicoder", "opencode.jsonc")
if (existsSync(templateSrc)) {
  await cp(templateSrc, path.join(assetsDir, "opencode.jsonc"))
  console.log("[bundle-assets] opencode.jsonc template ✓")
}

// 5. Routing CLI (thin wrapper around the preset module — standalone JS for npm)
const routingCliPath = path.join(assetsDir, "routing-cli.mjs")
await writeFile(
  routingCliPath,
  `#!/usr/bin/env node
// OmniCoder routing CLI (standalone, shipped in npm asset).
// Usage: omnicoder-routing <list|get|apply <name>|off>

import { readFileSync, writeFileSync, existsSync, copyFileSync } from "node:fs"
import path from "node:path"
import os from "node:os"

function xdgConfigHome() {
  if (process.env.XDG_CONFIG_HOME) return process.env.XDG_CONFIG_HOME
  if (process.platform === "win32") {
    return process.env.APPDATA || path.join(os.homedir(), "AppData", "Roaming")
  }
  return path.join(os.homedir(), ".config")
}

const CONFIG = path.join(xdgConfigHome(), "opencode", "opencode.jsonc")
const PRESETS = path.join(os.homedir(), ".omnicoder", "routing-presets.json")

function stripJsonc(text) {
  return text
    .replace(/\\/\\*[\\s\\S]*?\\*\\//g, "")
    .replace(/(^|[^:])\\/\\/.*$/gm, "$1")
}

function loadPresets() {
  if (!existsSync(PRESETS)) {
    console.error("[omnicoder-routing] presets missing at", PRESETS)
    process.exit(2)
  }
  return JSON.parse(stripJsonc(readFileSync(PRESETS, "utf8")))
}

function loadConfig() {
  if (!existsSync(CONFIG)) {
    console.error("[omnicoder-routing] config missing at", CONFIG)
    console.error("[omnicoder-routing] run 'omnicoder' once to seed it.")
    process.exit(2)
  }
  return readFileSync(CONFIG, "utf8")
}

function apply(name) {
  const presets = loadPresets()
  if (!presets[name]) {
    console.error("[omnicoder-routing] unknown preset:", name)
    console.error("[omnicoder-routing] available:", Object.keys(presets).join(", "))
    process.exit(1)
  }
  const agent = presets[name].agent ?? {}
  const src = loadConfig()
  copyFileSync(CONFIG, CONFIG + ".bak")
  // Very small JSONC editor: replace or insert "agent": {...}
  const agentJson = JSON.stringify(agent, null, 2).replace(/^/gm, "  ")
  const re = /"agent"\\s*:\\s*\\{[\\s\\S]*?\\n\\s*\\}/
  let out
  if (re.test(src)) {
    out = src.replace(re, '"agent": ' + agentJson.trim())
  } else {
    out = src.replace(/\\{\\n/, '{\\n  "agent": ' + agentJson.trim() + ",\\n")
  }
  writeFileSync(CONFIG, out, "utf8")
  console.log("[omnicoder-routing] applied preset '" + name + "' → " + CONFIG)
}

const [cmd, arg] = process.argv.slice(2)
switch (cmd) {
  case "list": {
    const p = loadPresets()
    for (const [n, v] of Object.entries(p)) {
      const desc = v.description || ""
      console.log(n.padEnd(22) + desc)
    }
    break
  }
  case "get": {
    console.log(loadConfig())
    break
  }
  case "apply": {
    if (!arg) { console.error("usage: omnicoder-routing apply <preset>"); process.exit(1) }
    apply(arg)
    break
  }
  case "off": {
    apply("default")
    break
  }
  default:
    console.log("OmniCoder routing CLI")
    console.log("")
    console.log("  omnicoder-routing list           list presets")
    console.log("  omnicoder-routing get            print current config")
    console.log("  omnicoder-routing apply <name>   apply preset")
    console.log("  omnicoder-routing off            reset to 'default'")
}
`,
  "utf8",
)
console.log("[bundle-assets] routing-cli.mjs ✓")

// 6. Count summary
import { readdir } from "node:fs/promises"
const agentCount = existsSync(path.join(assetsDir, "agent"))
  ? (await readdir(path.join(assetsDir, "agent"))).length
  : 0
const cmdCount = existsSync(path.join(assetsDir, "command"))
  ? (await readdir(path.join(assetsDir, "command"))).length
  : 0
console.log(
  `[bundle-assets] done: ${agentCount} agents, ${cmdCount} commands`,
)
