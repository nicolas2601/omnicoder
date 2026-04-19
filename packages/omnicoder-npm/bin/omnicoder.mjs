#!/usr/bin/env node
// OmniCoder launcher — spawns opencode-ai with assets seeded into the user's
// opencode config directory (cross-platform via xdg-basedir-style resolution).
// Also exposes a few top-level subcommands that don't require the TUI.

import { spawnSync } from "node:child_process"
import { existsSync, readFileSync, writeFileSync, mkdirSync } from "node:fs"
import { createRequire } from "node:module"
import path from "node:path"
import os from "node:os"
import { fileURLToPath } from "node:url"

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const require = createRequire(import.meta.url)

const PKG = require("../package.json")
const OMNICODER_VERSION = PKG.version
const UPDATE_CHECK_TTL_MS = 24 * 60 * 60 * 1000

function resolveOpencodeBin() {
  try {
    const pkgPath = require.resolve("opencode-ai/package.json")
    const pkg = require(pkgPath)
    const binRel = typeof pkg.bin === "string" ? pkg.bin : pkg.bin?.opencode
    if (!binRel) return null
    return path.join(path.dirname(pkgPath), binRel)
  } catch {
    return null
  }
}

function omnicoderHome() {
  return path.join(os.homedir(), ".omnicoder")
}

function seedIfNeeded({ force = false, quiet = true } = {}) {
  try {
    const seed = require("../scripts/seed-config.cjs")
    return seed({ quiet, force })
  } catch (err) {
    if (process.env.OMNICODER_DEBUG) {
      console.error("[omnicoder] seed failed:", err?.message ?? err)
    }
    return { error: true }
  }
}

// ---------------------------------------------------------------------------
// Subcommand: update
// ---------------------------------------------------------------------------
function cmdUpdate() {
  console.log("[omnicoder] checking npm registry for latest @alpha release…")
  const r = spawnSync("npm", ["install", "-g", "@nicolas2601/omnicoder@alpha"], {
    stdio: "inherit",
    shell: process.platform === "win32",
  })
  if (r.status !== 0) {
    console.error("[omnicoder] update failed (exit code " + r.status + ")")
    console.error("[omnicoder] Try:  npm install -g @nicolas2601/omnicoder@alpha --force")
    process.exit(r.status ?? 1)
  }
  seedIfNeeded({ force: true, quiet: false })
  console.log("[omnicoder] update complete ✓")
  process.exit(0)
}

// ---------------------------------------------------------------------------
// Subcommand: version (short — delegates to opencode for --version)
// ---------------------------------------------------------------------------
function cmdVersion() {
  const opencodeBin = resolveOpencodeBin()
  let opencodeVersion = "unknown"
  try {
    const pkgPath = require.resolve("opencode-ai/package.json")
    opencodeVersion = require(pkgPath).version
  } catch {}
  console.log("omnicoder " + OMNICODER_VERSION)
  console.log("  runtime: opencode-ai " + opencodeVersion)
  console.log("  node:    " + process.version)
  console.log("  platform:" + " " + process.platform + " " + process.arch)
  if (opencodeBin) console.log("  binary:  " + opencodeBin)
  process.exit(0)
}

// ---------------------------------------------------------------------------
// Background update check — non-blocking hint shown when a newer @alpha exists.
// Cached 24h so we don't spam the registry.
// ---------------------------------------------------------------------------
async function maybePrintUpdateHint() {
  if (process.env.OMNICODER_NO_UPDATE_CHECK) return
  if (!process.stdout.isTTY) return
  const cacheDir = omnicoderHome()
  const cacheFile = path.join(cacheDir, ".update-check.json")
  try {
    mkdirSync(cacheDir, { recursive: true })
    if (existsSync(cacheFile)) {
      const cache = JSON.parse(readFileSync(cacheFile, "utf8"))
      if (Date.now() - (cache.checkedAt || 0) < UPDATE_CHECK_TTL_MS) {
        if (cache.latest && cache.latest !== OMNICODER_VERSION) {
          printUpdateHint(cache.latest)
        }
        return
      }
    }
  } catch {}

  try {
    const res = await fetch(
      "https://registry.npmjs.org/@nicolas2601/omnicoder",
      { headers: { accept: "application/vnd.npm.install-v1+json" } },
    )
    if (!res.ok) return
    const body = await res.json()
    const latest = body?.["dist-tags"]?.alpha || body?.["dist-tags"]?.latest
    if (latest) {
      writeFileSync(
        cacheFile,
        JSON.stringify({ checkedAt: Date.now(), latest }),
        "utf8",
      )
      if (latest !== OMNICODER_VERSION) printUpdateHint(latest)
    }
  } catch {
    // network silently ignored
  }
}

function printUpdateHint(latest) {
  const line = "→ omnicoder " + latest + " available (current: " + OMNICODER_VERSION + ")"
  const cmd = "  run:  omnicoder update"
  process.stderr.write("\x1b[35m" + line + "\x1b[0m\n")
  process.stderr.write("\x1b[2m" + cmd + "\x1b[0m\n")
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
const argv = process.argv.slice(2)
const firstArg = argv[0]

if (firstArg === "update" || firstArg === "upgrade") cmdUpdate()
if (firstArg === "--version" && argv.length === 1) cmdVersion()
if (firstArg === "-v" && argv.length === 1) cmdVersion()

if (firstArg === "seed") {
  const force = argv.includes("--force") || argv.includes("-f")
  const r = seedIfNeeded({ force, quiet: false })
  if (r?.skipped) console.log("[omnicoder] already seeded (use --force)")
  process.exit(0)
}

const opencodeBin = resolveOpencodeBin()
if (!opencodeBin || !existsSync(opencodeBin)) {
  console.error("[omnicoder] ERROR: opencode-ai binary not found.")
  console.error("[omnicoder] Reinstall with:  npm install -g @nicolas2601/omnicoder --force")
  process.exit(1)
}

// Seed on every launch (idempotent).
seedIfNeeded({ quiet: true })

// Best-effort background update check (fire and forget; 200ms budget).
maybePrintUpdateHint().catch(() => {})

const env = {
  ...process.env,
  OMNICODER: "1",
  OMNICODER_VERSION,
}

const result = spawnSync(opencodeBin, argv, {
  stdio: "inherit",
  env,
  shell: false,
})

if (result.error) {
  console.error("[omnicoder] failed to spawn opencode:", result.error.message)
  process.exit(1)
}
process.exit(result.status ?? 0)
