#!/usr/bin/env node
// postinstall — runs once after npm install. Seeds user config.
// Fails silently (exit 0) to not break global installs.

import { createRequire } from "node:module"
const require = createRequire(import.meta.url)

try {
  const seed = require("./seed-config.cjs")
  seed({ quiet: false })
  console.log(
    "[omnicoder] post-install complete. Run:  omnicoder  (or: omnicoder doctor)",
  )
} catch (err) {
  console.error("[omnicoder] post-install warning:", err?.message ?? err)
  console.error("[omnicoder] You can still launch with `omnicoder` — seed runs on first launch.")
}
