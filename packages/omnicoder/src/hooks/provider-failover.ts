/**
 * Provider failover hint — ports `provider-failover.sh` and the failover
 * block of `post-tool-dispatcher.sh`.
 *
 * Tracks providers that recently emitted rate-limit or unavailable errors.
 * When a blocked provider is about to be reused, it logs a warning. Plugin
 * hooks cannot currently mutate the provider selection on `chat.params`, so
 * the structure here is a skeleton for the future failover implementation.
 */
import type { PluginInput } from "@opencode-ai/plugin"

const BLOCK_TTL_MS = 60_000

const FAILOVER_RE =
  /\b(429|rate.?limit|too many requests|503|service.?unavailable|timed?\s*out|ETIMEDOUT|ECONNREFUSED|ECONNRESET|401|unauthorized|invalid.*key)\b/i

type Blocked = { providerId: string; until: number; reason: string }
const blocked = new Map<string, Blocked>()

export function reportProviderError(providerId: string, sample: string): void {
  const m = sample.match(FAILOVER_RE)
  if (!m) return
  blocked.set(providerId, {
    providerId,
    until: Date.now() + BLOCK_TTL_MS,
    reason: m[0],
  })
}

function isBlocked(providerId: string): Blocked | null {
  const b = blocked.get(providerId)
  if (!b) return null
  if (Date.now() > b.until) {
    blocked.delete(providerId)
    return null
  }
  return b
}

export async function createProviderFailover(_input: PluginInput): Promise<{
  tune: (
    i: { sessionID?: string; agent?: string; provider?: { info?: { id?: string } } },
    o: Record<string, unknown>,
  ) => Promise<void>
  _debug: {
    report: (providerId: string, sample: string) => void
    clear: () => void
    isBlocked: (providerId: string) => Blocked | null
  }
}> {
  async function tune(
    i: { sessionID?: string; agent?: string; provider?: { info?: { id?: string } } },
    _o: Record<string, unknown>,
  ): Promise<void> {
    try {
      const id = i.provider?.info?.id
      if (!id) return
      const b = isBlocked(id)
      if (b) {
        console.error(
          `[omnicoder:provider-failover] provider "${id}" flagged (${b.reason}); ` +
            `consider switching until ${new Date(b.until).toISOString()}`,
        )
      }
    } catch (err) {
      console.error("[omnicoder:provider-failover]", (err as Error).message)
    }
  }

  return {
    tune,
    _debug: {
      report: reportProviderError,
      clear: () => blocked.clear(),
      isBlocked,
    },
  }
}
