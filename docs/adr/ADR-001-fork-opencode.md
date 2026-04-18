# ADR-001: Base change — Qwen Code CLI → Opencode fork

**Status**: Accepted (2026-04-18)
**Supersedes**: implicit v4 decision to use `@qwen-code/qwen-code@0.14.5` as runtime base.

## Context

OmniCoder v4.3.1 layers bash hooks, skills and agents *on top of* Qwen Code CLI. That means every upstream change can break our hooks, and we have no leverage over the tool-call loop, streaming, MCP plumbing or telemetry. "We change from outside, never from inside."

Requirements for the base:
- MIT or equivalent permissive license (commercial distribution, rebrand, derivative works)
- Native plugin / hook system so our logic is first-class, not a shell wrapper
- Sub-agents with per-agent model routing (v4 already mixes MiniMax + NVIDIA + Qwen)
- Active maintenance (≥ weekly commits, responsive issues)
- Provider-agnostic (not locked to Anthropic / OpenAI)
- MCP client built-in for Engram and future servers
- LSP integration for code intelligence

## Decision

**Fork `sst/opencode`** (TypeScript / Bun, MIT, 145K stars, v1.4.11 as of fork date) to `nicolas2601/omnicoder`.

Rejected alternatives:

| Candidate | Rejected because |
|---|---|
| Continue `qwen-code` wrapper | Root cause of the v4 pain — upstream drift, no hook ownership. |
| Fork `charmbracelet/crush` | License is **FSL-1.1-MIT** (not MIT), restricts competitive use for 2 years. Legal risk for public distribution. Go binary was attractive but not worth the licence cost. |
| Build from scratch in Go | 4–6 weeks minimum for MVP. Tool-use + streaming + MCP client are non-trivial. Deferred to v6.0. |
| `opencode` from Charmbracelet | Does not exist under that name — there was name-collision rumour, confirmed false. |

## Consequences

**Positive**
- Typed plugin system (`@opencode-ai/plugin`) with 15+ events (`tool.execute.before`, `chat.params`, `experimental.chat.system.transform`, …). All v4 bash hooks map 1:1.
- Native MCP client, 4 transports (stdio, http, sse, remote). Engram integration is a 6-line config block.
- Native sub-agent delegation via `TaskTool`; subagent can override provider+model (v4 had to fake this with env swaps).
- Provider-custom via `@ai-sdk/openai-compatible` = any OpenAI-compat endpoint works (MiniMax, NVIDIA NIM, DashScope).
- `~/.config/opencode/` plus `.claude` / `.agents` skill-discovery = existing ecosystem skills work without copying.

**Negative**
- Node/Bun runtime dep; we lose the "single static binary" of the Go rewrite plan. Scheduled for v6.0 (see roadmap).
- Upstream moves fast (v1.4.11 shipped the day we forked). Merge strategy must be disciplined.
- Effect.ts in the core is unfamiliar. Our plugin stays `async/await` to minimise cognitive cost.

## Merge strategy with upstream

1. `origin` = our fork; `upstream` = `sst/opencode`.
2. OmniCoder-owned code lives **only** under `packages/omnicoder/` and `.omnicoder/`. Never edit files outside that tree.
3. Where a core patch is unavoidable, tag the change with `// OMNICODER:` so `grep` locates them on rebase.
4. Weekly `git fetch upstream && git merge upstream/dev` on the `v5-migration` branch.
5. If a merge requires changes in 3+ core files, write an ADR.

## Validation

- `gh api repos/sst/opencode` confirmed: `archived=false`, `license=MIT`, `pushed=2026-04-18T17:37Z`, `stars=145470`.
- `gh api repos/charmbracelet/crush/contents/LICENSE.md` confirmed FSL-1.1-MIT.
- Local clone diffed: 19 workspace packages, 42 subdirs in `packages/opencode/src/`, plugin schema explicitly supports all hooks we need.
