// seed-config — idempotently copies OmniCoder assets into user opencode dirs.
// Called by bin/omnicoder.mjs on every launch (cheap: skips if already present).

const fs = require("node:fs")
const path = require("node:path")
const os = require("node:os")

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
  const home = os.homedir()
  const assetsRoot = path.join(__dirname, "..", "assets")
  const flagFile = path.join(home, ".omnicoder", ".seeded-alpha7")

  if (!force && fs.existsSync(flagFile)) return { skipped: true }

  const opencodeConfigDir = path.join(home, ".config", "opencode")
  const omnicoderHome = path.join(home, ".omnicoder")

  fs.mkdirSync(opencodeConfigDir, { recursive: true })
  fs.mkdirSync(omnicoderHome, { recursive: true })
  fs.mkdirSync(path.join(omnicoderHome, "memory"), { recursive: true })

  // Agents + commands (never overwrite — respect user edits)
  const a = copyDirMerge(
    path.join(assetsRoot, "agent"),
    path.join(opencodeConfigDir, "agent"),
    { overwrite: false },
  )
  const c = copyDirMerge(
    path.join(assetsRoot, "command"),
    path.join(opencodeConfigDir, "command"),
    { overwrite: false },
  )

  // Theme always refreshed (it's small + ours)
  const themeSrc = path.join(assetsRoot, "theme", "omnicoder.json")
  const themeDst = path.join(opencodeConfigDir, "theme", "omnicoder.json")
  if (fs.existsSync(themeSrc)) {
    fs.mkdirSync(path.dirname(themeDst), { recursive: true })
    fs.copyFileSync(themeSrc, themeDst)
  }

  // Routing presets (refresh — small JSON)
  const presetsSrc = path.join(assetsRoot, "routing-presets.json")
  const presetsDst = path.join(omnicoderHome, "routing-presets.json")
  if (fs.existsSync(presetsSrc)) fs.copyFileSync(presetsSrc, presetsDst)

  // Default config.jsonc if user has none
  const configSrc = path.join(assetsRoot, "opencode.jsonc")
  const configDst = path.join(opencodeConfigDir, "opencode.jsonc")
  if (fs.existsSync(configSrc) && !fs.existsSync(configDst)) {
    fs.copyFileSync(configSrc, configDst)
  }

  // Seed memory files if missing
  for (const f of ["patterns.md", "feedback.md"]) {
    const dst = path.join(omnicoderHome, "memory", f)
    if (!fs.existsSync(dst)) fs.writeFileSync(dst, `# OmniCoder ${f}\n\n`, "utf8")
  }

  fs.writeFileSync(flagFile, new Date().toISOString(), "utf8")

  if (!quiet) {
    console.log(`[omnicoder] seeded ${a} agents + ${c} commands → ~/.config/opencode/`)
  }
  return { agents: a, commands: c }
}

module.exports = seed

if (require.main === module) {
  const force = process.argv.includes("--force")
  const r = seed({ force })
  if (r.skipped) console.log("[omnicoder] already seeded (use --force to re-seed)")
}
