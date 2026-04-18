/**
 * routing-preset.test.ts
 *
 * Exercises the JSONC-aware agent-block replacer in a throwaway temp dir so
 * we don't need a full JSONC parser. Each test provides a minimal config
 * fragment to confirm the editor preserves comments, handles missing keys,
 * and reports unknown presets clearly.
 */
import { afterEach, beforeEach, describe, expect, test } from "bun:test"
import { promises as fs } from "node:fs"
import * as os from "node:os"
import * as path from "node:path"
import { applyPreset, getCurrent, listPresets } from "../src/routing/preset.ts"

let tmpHome = ""
const origHome = process.env.HOME
const origXdg = process.env.XDG_CONFIG_HOME
const origAppData = process.env.APPDATA

async function seedPresets(home: string): Promise<void> {
  const dir = path.join(home, ".omnicoder")
  await fs.mkdir(dir, { recursive: true })
  await fs.writeFile(
    path.join(dir, "routing-presets.json"),
    JSON.stringify({
      presets: {
        default: { description: "no overrides", agent: {} },
        cheap: {
          description: "haiku everywhere",
          agent: { build: { model: "anthropic/claude-haiku-4-5-20251001" } },
        },
      },
    }),
  )
}

async function seedConfig(content: string): Promise<string> {
  const cfgDir = path.join(tmpHome, ".config", "opencode")
  await fs.mkdir(cfgDir, { recursive: true })
  const cfgPath = path.join(cfgDir, "opencode.jsonc")
  await fs.writeFile(cfgPath, content)
  return cfgPath
}

beforeEach(async () => {
  tmpHome = await fs.mkdtemp(path.join(os.tmpdir(), "omni-routing-"))
  process.env.HOME = tmpHome
  process.env.XDG_CONFIG_HOME = path.join(tmpHome, ".config")
  // Windows path also honours APPDATA; align it to the fake home just in case
  // the test ever runs on win32.
  process.env.APPDATA = path.join(tmpHome, "AppData", "Roaming")
  await seedPresets(tmpHome)
})

afterEach(async () => {
  if (tmpHome) await fs.rm(tmpHome, { recursive: true, force: true })
  if (origHome === undefined) delete process.env.HOME
  else process.env.HOME = origHome
  if (origXdg === undefined) delete process.env.XDG_CONFIG_HOME
  else process.env.XDG_CONFIG_HOME = origXdg
  if (origAppData === undefined) delete process.env.APPDATA
  else process.env.APPDATA = origAppData
})

describe("routing preset editor", () => {
  test("listPresets enumerates every preset from the user file", async () => {
    const out = await listPresets()
    expect(out).toContain("default")
    expect(out).toContain("cheap")
    expect(out).toContain("haiku everywhere")
  })

  test("applyPreset replaces an existing agent block and keeps comments", async () => {
    const cfg = await seedConfig(`{
  // keep this line
  "mcp": {},
  "agent": {
    "build": { "model": "nvidia-nim/nope" }
  },
  /* trailing block comment */
}
`)
    const r = await applyPreset("cheap")
    expect(r.changed).toBe(true)
    expect(r.path).toBe(cfg)
    const written = await fs.readFile(cfg, "utf8")
    expect(written).toContain("// keep this line")
    expect(written).toContain("trailing block comment")
    expect(written).toContain("anthropic/claude-haiku-4-5-20251001")
    expect(written).not.toContain("nvidia-nim/nope")
    // Backup was taken.
    const bak = await fs.readFile(cfg + ".bak", "utf8")
    expect(bak).toContain("nvidia-nim/nope")
  })

  test("applyPreset splices a fresh agent block when one is missing", async () => {
    const cfg = await seedConfig(`{
  "mcp": {}
}
`)
    const r = await applyPreset("cheap")
    expect(r.changed).toBe(true)
    const written = await fs.readFile(cfg, "utf8")
    expect(written).toMatch(/"agent"\s*:\s*\{/)
    expect(written).toContain("haiku")
  })

  test("applyPreset('default') clears the block back to {}", async () => {
    await seedConfig(`{
  "agent": { "build": { "model": "nvidia-nim/x" } }
}
`)
    await applyPreset("cheap")
    const r = await applyPreset("default")
    expect(r.changed).toBe(true)
    const current = await getCurrent()
    expect(current).toMatch(/\{\}/)
  })

  test("unknown preset throws with the available names listed", async () => {
    await seedConfig(`{}`)
    expect(applyPreset("does-not-exist")).rejects.toThrow(/available:.*default.*cheap/)
  })
})
