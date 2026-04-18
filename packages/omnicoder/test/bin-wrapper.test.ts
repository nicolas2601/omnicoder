/**
 * bin-wrapper.test.ts
 *
 * Validates the POSIX `bin/omnicoder` shim end-to-end by executing the
 * script in a subprocess with an isolated HOME. Covers:
 *   1. `--omnicoder-version` prints the package version from
 *      packages/omnicoder/package.json.
 *   2. `omnicoder doctor` reports provider status for each known env var.
 *   3. Missing opencode binary produces a useful error (non-zero rc).
 *
 * We deliberately shell out rather than source — the shim is POSIX sh and the
 * whole point is that it Just Works in a real shell.
 */
import { afterEach, beforeEach, describe, expect, test } from "bun:test"
import { spawnSync } from "node:child_process"
import { promises as fs } from "node:fs"
import * as path from "node:path"
import { cleanupHome, makeHome } from "./_helpers.ts"

const REPO_ROOT = path.resolve(import.meta.dir, "..", "..", "..")
const SHIM = path.join(REPO_ROOT, "bin", "omnicoder")
const PKG_JSON = path.join(REPO_ROOT, "packages", "omnicoder", "package.json")

async function readPackageVersion(): Promise<string> {
  const raw = await fs.readFile(PKG_JSON, "utf8")
  return (JSON.parse(raw) as { version: string }).version
}

/**
 * Build an env object with the provided overrides, scrubbed of provider keys
 * so the test is deterministic no matter what the developer has exported.
 */
function cleanEnv(home: string, extras: Record<string, string> = {}): NodeJS.ProcessEnv {
  const clean: NodeJS.ProcessEnv = { ...process.env }
  for (const k of [
    "NVIDIA_API_KEY",
    "MINIMAX_API_KEY",
    "DASHSCOPE_API_KEY",
    "ANTHROPIC_API_KEY",
    "OPENAI_API_KEY",
  ]) {
    delete clean[k]
  }
  clean.HOME = home
  clean.OMNICODER_HOME = path.join(home, ".omnicoder")
  clean.NO_COLOR = "1"
  // Keep PATH so /bin/sh resolves. opencode is optional — doctor handles both.
  return { ...clean, ...extras }
}

describe("bin/omnicoder wrapper", () => {
  let home = ""

  beforeEach(async () => {
    home = await makeHome("omni-bin-")
  })

  afterEach(async () => {
    await cleanupHome(home)
  })

  test("--omnicoder-version prints the package version", async () => {
    const version = await readPackageVersion()
    const result = spawnSync(SHIM, ["--omnicoder-version"], {
      env: cleanEnv(home),
      encoding: "utf8",
    })
    expect(result.status).toBe(0)
    expect(result.stdout).toContain(`omnicoder ${version}`)
    // The second line covers the opencode core — either a real version or
    // the fallback string when opencode is not installed on the runner.
    expect(result.stdout).toMatch(/opencode\s+\S+/)
  })

  test("doctor reports provider status for each supported key", async () => {
    const result = spawnSync(SHIM, ["doctor"], {
      env: cleanEnv(home, { NVIDIA_API_KEY: "sk-test-nvidia" }),
      encoding: "utf8",
    })
    // Doctor can legitimately exit 1 when opencode is missing on the runner
    // (feedback_ci_windows_bat.md #8). Both exit paths are acceptable; we
    // only require the output contract.
    expect([0, 1]).toContain(result.status ?? -1)
    expect(result.stdout).toContain("NVIDIA_API_KEY")
    expect(result.stdout).toContain("MINIMAX_API_KEY")
    expect(result.stdout).toContain("DASHSCOPE_API_KEY")
    expect(result.stdout).toContain("ANTHROPIC_API_KEY")
    expect(result.stdout).toContain("OPENAI_API_KEY")
    // At least one provider is set, so the "no keys" warning must not appear.
    expect(result.stdout).not.toContain("no provider API keys detected")
    // The row for the set key should read "set", all others "unset".
    expect(result.stdout).toMatch(/NVIDIA_API_KEY\s+set/)
    expect(result.stdout).toMatch(/MINIMAX_API_KEY\s+unset/)
  })

  test("launching without opencode in PATH fails with a helpful message", async () => {
    // Point PATH at an empty dir so `command -v opencode` returns nothing.
    const emptyBin = path.join(home, "empty-bin")
    await fs.mkdir(emptyBin, { recursive: true })
    const env = cleanEnv(home, { PATH: emptyBin })
    const result = spawnSync(SHIM, [], { env, encoding: "utf8" })
    expect(result.status).toBe(127)
    expect(result.stderr).toContain("opencode is not installed")
  })
})
