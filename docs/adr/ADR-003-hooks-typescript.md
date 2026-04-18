# ADR-003: Hooks — TypeScript plugin, not bash

**Status**: Accepted (2026-04-18)

## Context

v4 had 20 bash hooks under `hooks/`. They were fast to write but: no types, no unit tests, shell injection risks, jq/flock/bash-4 dependencies that fail on Windows Git-Bash and macOS default bash-3.2. Diagnosis files like `feedback_ci_windows_bat.md` exist because of this.

Opencode exposes plugin hooks with typed `(input, output) => Promise<void>` signatures over 15+ events.

## Decision

Rewrite all P0 hooks as a single TypeScript plugin package **`@omnicoder/core`**. Each v4 hook becomes one module under `packages/omnicoder/src/`:

| v4 bash hook | v5 module | Opencode hook |
|---|---|---|
| `skill-router-lite.sh` | `router/index.ts` | `experimental.chat.system.transform` |
| `security-guard.sh` | `security/index.ts` | `tool.execute.before` (when `tool=="bash"`) |
| `memory-loader.sh` | `memory/index.ts` | `experimental.chat.system.transform` |
| `token-budget.sh` | `budget/index.ts` | `event` (session.completed) |
| `post-tool-dispatcher.sh` | `hooks/tool-dispatcher.ts` | `tool.execute.after` |
| `provider-failover.sh` | `hooks/provider-failover.ts` | `chat.params` |

Rules:

- Plugin code is `async/await`, no Effect.ts. Effect lives in the Opencode core; our plugin stays at the SDK boundary.
- No npm deps beyond `@opencode-ai/plugin` and `@opencode-ai/sdk` (peer). Only Node/Bun built-ins.
- Each module ≤ 150 LOC, ≥ 3 unit tests with `bun test`.
- Security hook *may* throw (that's how Opencode cancels a tool call); every other hook MUST NOT throw — errors to `console.error` with prefix `[omnicoder:<module>]`.

## Consequences

**Positive**
- End of bash-portability tax. Single code path on Linux/macOS/Windows because Bun runs identical TS everywhere.
- Types enforce hook-event contracts (compiler catches missing `output.system[]` mutations etc.).
- Tests run in ~10 ms vs bash scripts that spawn subprocesses per case.

**Negative**
- Bash was trivially editable; TS has a compile step (tsgo in dev, no bundle for users because Opencode consumes source).
- Losing the `OMNICODER.md` → inline-bash "hackability". Mitigation: user-level overrides via `~/.config/opencode/plugins/*.ts`.

## Bash survives where

- `install.sh` / `install-windows.bat` — one-shot bootstrapping, out of runtime hot path.
- `scripts/migrate-memory-v4-to-engram.ts` — runs once, `.ts` executed via `bun run`.
- Not in hooks. Period.
