# ADR-005: Provider chain — MiniMax primary, Qwen fallback, Anthropic premium

**Status**: Accepted (2026-04-18)

## Context

Currently running on NVIDIA NIM's MiniMax M2.7 free tier (40 RPM, finite credits). MiniMax Anthropic-compat endpoint (`https://api.minimax.io/anthropic`) offers prompt caching at ~90% discount when we buy credits. Qwen 3.6-35B on DashScope is cheap and fast for coder-style subagents. Anthropic Opus 4.7 / Sonnet 4.6 are the gold standard for security-architect and tricky reasoning, but pay-as-you-go.

## Decision

Default routing in `@omnicoder/core`:

| Agent role | Provider | Model | Rationale |
|---|---|---|---|
| Primary `build` | `nvidia-nim` | `minimax/minimax-m2` | Free tier, 128k context, tool use works. |
| Primary `plan` | `nvidia-nim` | `minimax/minimax-m2` | Same. |
| Subagent `coder` | `dashscope` | `qwen-max` | Cheap, fast, coder-tuned. |
| Subagent `reviewer` | `minimax` | `minimax-m2` (Anthropic-compat) | Enable prompt cache when user has key. |
| Subagent `security-architect` | `anthropic` | `claude-sonnet-4-6` | Low-volume, high-stakes; pay here. |
| Subagent `researcher` | `dashscope` | `qwen-max` | Tool-heavy, cheap. |

Failover: **opencode mainline does not support inter-provider failover** (upstream issue #7602). The `chat.params` hook cannot intercept streaming errors; the only working approach today is the `zortos293/opencode-combined-models` session-processor patch.

Our stance in v5.0:
- `hooks/provider-failover.ts` **logs** rate-limit / 5xx events and marks a cool-down window in `~/.omnicoder/state/provider-health.json` so the **next session** picks a healthy provider.
- Real mid-session failover is **deferred to v5.1** and requires either (a) upstreaming the combined-models patch or (b) implementing failover at the MCP gateway layer.
- Users can manually switch provider via `opencode` TUI (`/model` command) when a provider is down; v5.0 documents this in MIGRATION.md.

## Install-time provider detection

```bash
detect_providers() {
  [ -n "$NVIDIA_API_KEY" ]   && available+=("nvidia-nim")
  [ -n "$MINIMAX_API_KEY" ]  && available+=("minimax")
  [ -n "$DASHSCOPE_API_KEY" ] && available+=("dashscope")
  [ -n "$ANTHROPIC_API_KEY" ] && available+=("anthropic")
  [ -n "$OPENAI_API_KEY" ]   && available+=("openai")
}
```

`install.sh` writes a tailored `opencode.jsonc` containing only providers the user has keys for, with role-to-provider map using the best available.

## Consequences

**Positive**
- Zero-cost path works out of the box (NVIDIA free tier).
- Upgrade path: buying $10 of MiniMax credits unlocks prompt cache → ~3–5× additional cost reduction on repeated context.
- Anthropic optional, never required.

**Negative**
- Five providers to keep healthy. Mitigation: the failover hook + a weekly `omnicoder doctor` check.
- DashScope latency from Latin America is variable — we may need regional endpoint selection later.
