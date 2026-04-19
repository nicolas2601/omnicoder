#!/usr/bin/env node
// OmniCoder launcher — spawns opencode-ai with OmniCoder assets resolved into
// ~/.config/opencode/ (agents, commands, theme, config) and our routing CLI
// exposed on PATH. Pass through all argv transparently.

import { spawnSync } from "node:child_process"
import { existsSync } from "node:fs"
import { createRequire } from "node:module"
import path from "node:path"
import { fileURLToPath } from "node:url"

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const require = createRequire(import.meta.url)

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

const opencodeBin = resolveOpencodeBin()
if (!opencodeBin || !existsSync(opencodeBin)) {
  console.error("[omnicoder] ERROR: opencode-ai binary not found.")
  console.error("[omnicoder] Reinstall with: npm install -g @nicolas2601/omnicoder --force")
  process.exit(1)
}

// Ensure first-run: copy our assets to ~/.config/opencode/ if missing.
try {
  const seed = require("../scripts/seed-config.cjs")
  seed({ quiet: true })
} catch (err) {
  // Non-fatal — user may still run TUI without our agents.
  if (process.env.OMNICODER_DEBUG) console.error("[omnicoder] seed failed:", err?.message ?? err)
}

const env = {
  ...process.env,
  OMNICODER: "1",
  OMNICODER_VERSION: "5.0.0-alpha.7",
}

const result = spawnSync(opencodeBin, process.argv.slice(2), {
  stdio: "inherit",
  env,
  shell: false,
})

if (result.error) {
  console.error("[omnicoder] failed to spawn opencode:", result.error.message)
  process.exit(1)
}
process.exit(result.status ?? 0)
