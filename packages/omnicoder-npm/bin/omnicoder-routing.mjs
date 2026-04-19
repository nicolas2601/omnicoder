#!/usr/bin/env node
// omnicoder-routing — per-phase routing preset manager.
// Delegates to the routing preset module shipped in assets/.

import { pathToFileURL } from "node:url"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { existsSync } from "node:fs"

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const cliPath = path.join(__dirname, "..", "assets", "routing-cli.mjs")
if (!existsSync(cliPath)) {
  console.error("[omnicoder-routing] assets/routing-cli.mjs missing — reinstall package.")
  process.exit(1)
}

await import(pathToFileURL(cliPath).href)
