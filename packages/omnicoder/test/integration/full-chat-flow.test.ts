/**
 * Integration: end-to-end mock of a chat session.
 *
 * Simulates the Opencode host calling each hook in the canonical order:
 *   1. experimental.chat.system.transform  (memory + router inject)
 *   2. chat.params                         (provider-failover tune)
 *   3. tool.execute.before                 (security guard passes `bash`)
 *   4. tool.execute.after                  (dispatcher logs)
 *   5. event (session.completed)           (budget tallies + dispatcher cleans)
 *
 * Verifies hook order via a manual spy wrapper, then confirms log files are
 * written to `$HOME/.omnicoder/logs/` (which we map to a TMPDIR).
 */
import { afterEach, beforeEach, describe, expect, test } from "bun:test"
import { promises as fs } from "node:fs"
import * as os from "node:os"
import * as path from "node:path"
import { makeFakePluginInput, seedHomeFromFixtures } from "./fixtures/mock-plugin-input.ts"

type Hooks = Record<string, (...args: unknown[]) => Promise<unknown>>

describe("integration: full chat flow", () => {
  let home = ""
  let prevHome: string | undefined

  beforeEach(async () => {
    home = await fs.mkdtemp(path.join(os.tmpdir(), "omni-flow-"))
    await fs.mkdir(path.join(home, ".omnicoder"), { recursive: true })
    prevHome = process.env.HOME
    process.env.HOME = home
    await seedHomeFromFixtures(home, { skills: ["seo", "react"], memory: true })
  })

  afterEach(async () => {
    if (prevHome === undefined) delete process.env.HOME
    else process.env.HOME = prevHome
    await fs.rm(home, { recursive: true, force: true }).catch(() => {})
  })

  test("all 5 hooks fire in canonical order and logs land in $HOME/.omnicoder/logs", async () => {
    const mod = (await import(`../../src/index.ts?r=${Math.random()}`)) as {
      OmnicoderPlugin: (input: unknown) => Promise<Hooks>
    }
    const hooks = await mod.OmnicoderPlugin(makeFakePluginInput() as never)

    const callOrder: string[] = []
    const trace = <K extends keyof Hooks & string>(k: K) => {
      const original = hooks[k]!.bind(hooks)
      return async (...args: unknown[]) => {
        callOrder.push(k)
        return original(...args)
      }
    }

    const transform = trace("experimental.chat.system.transform")
    const params = trace("chat.params")
    const before = trace("tool.execute.before")
    const after = trace("tool.execute.after")
    const event = trace("event")

    // 1. System transform (memory + router).
    const systemBag = { system: [] as string[] }
    await transform(
      {
        sessionID: "flow-1",
        prompt:
          "please help me improve SEO and react performance for the landing page with schema markup and memoization",
      },
      systemBag,
    )
    expect(systemBag.system.length).toBeGreaterThan(0)

    // 2. chat.params (provider failover tune, no-op for a healthy provider).
    await params({ sessionID: "flow-1", provider: { info: { id: "anthropic" } } }, {})

    // 3. tool.execute.before — a safe bash command must pass.
    await before(
      { tool: "bash", sessionID: "flow-1", callID: "call-1" },
      { args: { command: "git status" } },
    )

    // 4. tool.execute.after — dispatcher logs the completion.
    await after(
      { tool: "bash", sessionID: "flow-1", callID: "call-1", args: {} },
      { title: "ok", output: "on branch main", metadata: null },
    )

    // 5. event — session.completed triggers budget logging.
    await event({
      event: {
        type: "session.completed",
        properties: { sessionID: "flow-1", total_tokens: 4321 },
      },
    })

    // Order assertion.
    expect(callOrder).toEqual([
      "experimental.chat.system.transform",
      "chat.params",
      "tool.execute.before",
      "tool.execute.after",
      "event",
    ])

    // Log files land under the sandboxed HOME.
    const logDir = path.join(home, ".omnicoder", "logs")
    const tokenLog = await fs.readFile(path.join(logDir, "token-log.jsonl"), "utf8")
    expect(tokenLog).toContain("4321")

    const toolLog = await fs.readFile(path.join(logDir, "tool-usage.jsonl"), "utf8")
    const parsed = JSON.parse(toolLog.trim().split("\n")[0]!) as Record<string, unknown>
    expect(parsed.tool).toBe("bash")
    expect(parsed.sessionID).toBe("flow-1")
  })

  test("dangerous bash aborts the flow before dispatcher logs", async () => {
    const mod = (await import(`../../src/index.ts?r=${Math.random()}`)) as {
      OmnicoderPlugin: (input: unknown) => Promise<Hooks>
    }
    const hooks = await mod.OmnicoderPlugin(makeFakePluginInput() as never)

    let err: unknown = null
    try {
      await hooks["tool.execute.before"]!(
        { tool: "bash", sessionID: "flow-2", callID: "call-evil" },
        { args: { command: "rm -rf /" } },
      )
    } catch (e) {
      err = e
    }
    expect(err).not.toBeNull()

    // tool.execute.after should never be called for a blocked command; the
    // dispatcher log therefore must not exist (or must not contain call-evil).
    const toolLogPath = path.join(home, ".omnicoder", "logs", "tool-usage.jsonl")
    let raw = ""
    try {
      raw = await fs.readFile(toolLogPath, "utf8")
    } catch {
      raw = ""
    }
    expect(raw).not.toContain("call-evil")
  })
})
