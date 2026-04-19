import { describe, it, expect, beforeEach, afterEach } from "bun:test"
import { mkdirSync, writeFileSync, rmSync, existsSync } from "node:fs"
import * as path from "node:path"
import * as os from "node:os"
import { createPersonalityLoader, preambleFor } from "../src/personality/index.js"

const HOME_ORIG = process.env.HOME
let tmpHome: string

beforeEach(() => {
  tmpHome = path.join(os.tmpdir(), "omni-personality-" + Date.now() + "-" + Math.random().toString(36).slice(2))
  mkdirSync(tmpHome, { recursive: true })
  process.env.HOME = tmpHome
})

afterEach(() => {
  if (existsSync(tmpHome)) rmSync(tmpHome, { recursive: true, force: true })
  if (HOME_ORIG) process.env.HOME = HOME_ORIG
})

describe("personality loader", () => {
  it("returns null preamble when file missing (off)", async () => {
    const loader = createPersonalityLoader()
    const o = { system: [] as string[] }
    await loader.inject({}, o)
    expect(o.system.length).toBe(0)
  })

  it("returns null preamble when id = off", async () => {
    const dir = path.join(tmpHome, ".omnicoder")
    mkdirSync(dir, { recursive: true })
    writeFileSync(path.join(dir, "personality.json"), JSON.stringify({ id: "off" }))
    const loader = createPersonalityLoader()
    const o = { system: [] as string[] }
    await loader.inject({}, o)
    expect(o.system.length).toBe(0)
  })

  it("injects preamble for omni-man", async () => {
    const dir = path.join(tmpHome, ".omnicoder")
    mkdirSync(dir, { recursive: true })
    writeFileSync(path.join(dir, "personality.json"), JSON.stringify({ id: "omni-man" }))
    const loader = createPersonalityLoader()
    const o = { system: [] as string[] }
    await loader.inject({}, o)
    expect(o.system.length).toBe(1)
    expect(o.system[0]).toContain("Omni-Man")
    expect(o.system[0]).toContain("NOLAN")
    expect(o.system[0]).toContain("PERSONA-OVERRIDE")
  })

  it("ignores unknown ids (falls back to off)", async () => {
    const dir = path.join(tmpHome, ".omnicoder")
    mkdirSync(dir, { recursive: true })
    writeFileSync(path.join(dir, "personality.json"), JSON.stringify({ id: "darkseid" }))
    const loader = createPersonalityLoader()
    const o = { system: [] as string[] }
    await loader.inject({}, o)
    expect(o.system.length).toBe(0)
  })

  it("has preambles for all non-off ids", () => {
    const ids = ["omni-man", "conquest", "thragg", "anissa", "cecil", "immortal"] as const
    for (const id of ids) {
      expect(preambleFor(id)).toBeTruthy()
      expect(preambleFor(id)!.length).toBeGreaterThan(30)
    }
    expect(preambleFor("off")).toBeNull()
  })

  it("onCommand writes personality when /personality is executed", async () => {
    const loader = createPersonalityLoader()
    await loader.onCommand({
      type: "command.executed",
      properties: { name: "personality", arguments: "omni-man" },
    })
    const { readFileSync, existsSync } = await import("node:fs")
    const file = path.join(tmpHome, ".omnicoder", "personality.json")
    expect(existsSync(file)).toBe(true)
    const j = JSON.parse(readFileSync(file, "utf8"))
    expect(j.id).toBe("omni-man")
  })

  it("onCommand accepts common aliases", async () => {
    const loader = createPersonalityLoader()
    for (const alias of ["omniman", "NOLAN", "emperor", "none"]) {
      await loader.onCommand({
        type: "command.executed",
        properties: { name: "personality", arguments: alias },
      })
    }
    const { readFileSync } = await import("node:fs")
    const file = path.join(tmpHome, ".omnicoder", "personality.json")
    const j = JSON.parse(readFileSync(file, "utf8"))
    // last call was "none" → off
    expect(j.id).toBe("off")
  })

  it("onCommand ignores unknown personas", async () => {
    const loader = createPersonalityLoader()
    await loader.onCommand({
      type: "command.executed",
      properties: { name: "personality", arguments: "darkseid" },
    })
    const { existsSync } = await import("node:fs")
    const file = path.join(tmpHome, ".omnicoder", "personality.json")
    expect(existsSync(file)).toBe(false)
  })

  it("onCommand ignores other command events", async () => {
    const loader = createPersonalityLoader()
    await loader.onCommand({
      type: "command.executed",
      properties: { name: "ship", arguments: "omni-man" },
    })
    const { existsSync } = await import("node:fs")
    const file = path.join(tmpHome, ".omnicoder", "personality.json")
    expect(existsSync(file)).toBe(false)
  })

  it("caches within TTL", async () => {
    const dir = path.join(tmpHome, ".omnicoder")
    mkdirSync(dir, { recursive: true })
    writeFileSync(path.join(dir, "personality.json"), JSON.stringify({ id: "thragg" }))
    const loader = createPersonalityLoader()
    const o1 = { system: [] as string[] }
    await loader.inject({}, o1)
    // overwrite file to 'off' — cache should still serve thragg
    writeFileSync(path.join(dir, "personality.json"), JSON.stringify({ id: "off" }))
    const o2 = { system: [] as string[] }
    await loader.inject({}, o2)
    expect(o2.system[0]).toContain("Thragg")
    // manual invalidate
    loader._debug.invalidate()
    const o3 = { system: [] as string[] }
    await loader.inject({}, o3)
    expect(o3.system.length).toBe(0)
  })
})
