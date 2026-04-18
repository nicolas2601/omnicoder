/**
 * Tool dispatcher — ports the logging slice of `post-tool-dispatcher.sh`.
 *
 * Logs every tool completion to ~/.omnicoder/logs/tool-usage.jsonl. The hook
 * is a strict no-op on errors (never throws) so it cannot disrupt the agent
 * pipeline.
 */
import type { PluginInput } from "@opencode-ai/plugin"
import { promises as fs } from "node:fs"
import * as os from "node:os"
import * as path from "node:path"

function resolveHome(): string {
  return process.env.HOME ?? os.homedir()
}

type Event = { type?: string; properties?: Record<string, unknown> } | Record<string, unknown>

export async function createToolDispatcher(_input: PluginInput): Promise<{
  onComplete: (
    i: { tool: string; sessionID?: string; callID?: string; args?: unknown },
    o: { title?: string; output?: string; metadata?: unknown },
  ) => Promise<void>
  onEvent: (event: Event) => Promise<void>
  _debug: { logPath: string }
}> {
  const startTimes = new Map<string, number>()

  const getPaths = () => {
    const home = resolveHome()
    const logDir = path.join(home, ".omnicoder", "logs")
    return { logDir, toolLog: path.join(logDir, "tool-usage.jsonl") }
  }

  async function safeAppend(file: string, line: string): Promise<void> {
    try {
      await fs.mkdir(getPaths().logDir, { recursive: true })
      await fs.appendFile(file, line, "utf8")
    } catch (err) {
      console.error("[omnicoder:tool-dispatcher]", (err as Error).message)
    }
  }

  async function onComplete(
    i: { tool: string; sessionID?: string; callID?: string; args?: unknown },
    o: { title?: string; output?: string; metadata?: unknown },
  ): Promise<void> {
    try {
      const now = Date.now()
      const key = `${i.sessionID ?? "unknown"}:${i.callID ?? "unknown"}`
      const start = startTimes.get(key)
      startTimes.delete(key)
      const durationMs = start ? now - start : 0
      const outputLen = typeof o.output === "string" ? o.output.length : 0
      const entry = {
        ts: new Date(now).toISOString(),
        tool: i.tool ?? "unknown",
        sessionID: i.sessionID ?? "unknown",
        durationMs,
        outputLen,
      }
      await safeAppend(getPaths().toolLog, JSON.stringify(entry) + "\n")
    } catch (err) {
      console.error("[omnicoder:tool-dispatcher]", (err as Error).message)
    }
  }

  async function onEvent(event: Event): Promise<void> {
    try {
      const type = typeof event.type === "string" ? event.type : ""
      if (!type) return
      if (/session\.(started|start)/.test(type)) {
        const props = (event.properties ?? {}) as Record<string, unknown>
        const sid = typeof props.sessionID === "string" ? props.sessionID : "unknown"
        startTimes.set(`${sid}:session`, Date.now())
      } else if (/session\.(completed|ended|end)/.test(type)) {
        // leave cleanup to natural GC — map keys are per-call
      }
    } catch (err) {
      console.error("[omnicoder:tool-dispatcher]", (err as Error).message)
    }
  }

  return {
    onComplete,
    onEvent,
    _debug: {
      get logPath() {
        return getPaths().toolLog
      },
    },
  }
}
