// seed-config — idempotently copies OmniCoder assets into the user's opencode
// config directory, matching exactly what opencode expects per-platform.
// Opencode uses xdg-basedir:
//   - linux:   $XDG_CONFIG_HOME || ~/.config
//   - macOS:   ~/.config  (xdg-basedir default, not ~/Library/Preferences)
//   - windows: %APPDATA%  (or ~/AppData/Roaming as fallback)
// Called by bin/omnicoder.mjs on every launch (cheap: skips if already present).

const fs = require("node:fs")
const path = require("node:path")
const os = require("node:os")

function xdgConfigHome() {
  if (process.env.XDG_CONFIG_HOME) return process.env.XDG_CONFIG_HOME
  if (process.platform === "win32") {
    return (
      process.env.APPDATA || path.join(os.homedir(), "AppData", "Roaming")
    )
  }
  // linux + darwin default (xdg-basedir library behavior)
  return path.join(os.homedir(), ".config")
}

function opencodeConfigDir() {
  return path.join(xdgConfigHome(), "opencode")
}

function omnicoderHome() {
  // Stays in ~/.omnicoder on every platform — matches the v4 legacy path
  // and is fully under the user's control.
  return path.join(os.homedir(), ".omnicoder")
}

function copyDirMerge(src, dst, { overwrite = false } = {}) {
  if (!fs.existsSync(src)) return 0
  fs.mkdirSync(dst, { recursive: true })
  let copied = 0
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, entry.name)
    const d = path.join(dst, entry.name)
    if (entry.isDirectory()) {
      copied += copyDirMerge(s, d, { overwrite })
    } else if (entry.isFile()) {
      if (overwrite || !fs.existsSync(d)) {
        fs.copyFileSync(s, d)
        copied++
      }
    }
  }
  return copied
}

function seed({ quiet = false, force = false } = {}) {
  const assetsRoot = path.join(__dirname, "..", "assets")
  const configDir = opencodeConfigDir()
  const ocHome = omnicoderHome()
  const flagFile = path.join(ocHome, ".seeded-alpha10")

  if (!force && fs.existsSync(flagFile)) return { skipped: true }

  fs.mkdirSync(configDir, { recursive: true })
  fs.mkdirSync(ocHome, { recursive: true })
  fs.mkdirSync(path.join(ocHome, "memory"), { recursive: true })

  // Agents + commands (never overwrite — respect user edits)
  const a = copyDirMerge(
    path.join(assetsRoot, "agent"),
    path.join(configDir, "agent"),
    { overwrite: false },
  )
  const c = copyDirMerge(
    path.join(assetsRoot, "command"),
    path.join(configDir, "command"),
    { overwrite: false },
  )

  // Theme always refreshed (it's small + ours)
  const themeSrc = path.join(assetsRoot, "theme", "omnicoder.json")
  const themeDst = path.join(configDir, "theme", "omnicoder.json")
  if (fs.existsSync(themeSrc)) {
    fs.mkdirSync(path.dirname(themeDst), { recursive: true })
    fs.copyFileSync(themeSrc, themeDst)
  }

  // Routing presets (refresh — small JSON)
  const presetsSrc = path.join(assetsRoot, "routing-presets.json")
  const presetsDst = path.join(ocHome, "routing-presets.json")
  if (fs.existsSync(presetsSrc)) fs.copyFileSync(presetsSrc, presetsDst)

  // Default opencode.jsonc if user has none
  const configSrc = path.join(assetsRoot, "opencode.jsonc")
  const configDst = path.join(configDir, "opencode.jsonc")
  if (fs.existsSync(configSrc) && !fs.existsSync(configDst)) {
    fs.copyFileSync(configSrc, configDst)
  }

  // Seed memory files if missing
  for (const f of ["patterns.md", "feedback.md"]) {
    const dst = path.join(ocHome, "memory", f)
    if (!fs.existsSync(dst)) {
      fs.writeFileSync(dst, `# OmniCoder ${f}\n\n`, "utf8")
    }
  }

  // Remove older seed flags so upgrades re-seed once.
  for (const old of [".seeded-alpha7", ".seeded-alpha8", ".seeded-alpha9"]) {
    const f = path.join(ocHome, old)
    if (fs.existsSync(f)) fs.unlinkSync(f)
  }

  // Deprecated commands that must be removed on upgrade — they're replaced
  // by native TUI dialogs that write their own state files, and leaving the
  // markdown shim around makes the orchestrator echo the old prompt instead
  // of opening the picker.
  const DEPRECATED_COMMANDS = ["personality.md"]
  for (const name of DEPRECATED_COMMANDS) {
    for (const dir of [
      path.join(configDir, "command"),
      path.join(configDir, "commands"),
    ]) {
      const f = path.join(dir, name)
      if (fs.existsSync(f)) {
        try {
          fs.unlinkSync(f)
        } catch {
          /* ignore permissions errors */
        }
      }
    }
  }

  fs.writeFileSync(flagFile, new Date().toISOString(), "utf8")

  if (!quiet) {
    console.log(
      `[omnicoder] seeded ${a} agents + ${c} commands → ${configDir}`,
    )
  }
  return { agents: a, commands: c, configDir }
}

module.exports = seed
module.exports.xdgConfigHome = xdgConfigHome
module.exports.opencodeConfigDir = opencodeConfigDir
module.exports.omnicoderHome = omnicoderHome

if (require.main === module) {
  const force = process.argv.includes("--force")
  const r = seed({ force })
  if (r.skipped) {
    console.log("[omnicoder] already seeded (use --force to re-seed)")
  }
}
