# 05 · Hooks del plugin `@omnicoder/core`

Seis hooks TypeScript registrados en `packages/omnicoder/src/index.ts`.
Todos son tuyos, editables, tipados y testeados.

---

## Mapa

| Hook | Archivo | Trigger | Propósito |
|---|---|---|---|
| `skill-router` | `src/router/index.ts` | `experimental.chat.system.transform` | Inyecta top-N skills relevantes al system prompt |
| `security-guard` | `src/security/index.ts` | `tool.execute.before` | Bloquea comandos bash peligrosos + secrets en args |
| `memory-loader` | `src/memory/index.ts` | `experimental.chat.system.transform` | Inyecta `patterns.md` + `feedback.md` de `~/.omnicoder/memory/` (si no hay Engram) |
| `token-budget` | `src/budget/index.ts` | `event` | Log JSONL + alerta promedio móvil >15k/session |
| `tool-dispatcher` | `src/hooks/tool-dispatcher.ts` | `tool.execute.after` + `event` | Log estructurado de cada tool-use |
| `provider-failover` | `src/hooks/provider-failover.ts` | `chat.params` | Cool-down 60 s + selección de provider |

---

## Orden de ejecución

```
user message
     ↓
[experimental.chat.system.transform]
     ├─ memory-loader.inject()     ← inserta primero (layer inferior)
     └─ skill-router.inject()      ← inserta al final (layer superior)
     ↓
[chat.params]
     └─ provider-failover.tune()   ← decide provider antes del call
     ↓
   LLM call
     ↓
[tool.execute.before]
     └─ security-guard.check()     ← puede abortar aquí
     ↓
   tool runs
     ↓
[tool.execute.after]
     └─ tool-dispatcher.onComplete()  ← log JSONL
     ↓
[event]
     ├─ token-budget.onEvent()
     └─ tool-dispatcher.onEvent()
```

---

## `skill-router` en detalle

- **Scoring**: BM25 (k1=1.2, b=0.75) sobre tokens de `name + description + tags`.
- **Boost** de `+0.4` por bigram match en la query.
- **Memoize** `needs_rebuild` durante 60 s (no re-escanea 360+ archivos
  en cada prompt).
- **Paralelo**: `collect()` escanea skills y agents en paralelo con
  `Promise.all`.
- **Output**: inyecta los top-N (default 3) como bloques `<skill>…</skill>`
  en el system prompt.

Config en `opencode.jsonc`:

```jsonc
{
  "omnicoder": {
    "router": {
      "topN": 3,
      "minScore": 0.15,
      "debug": false
    }
  }
}
```

---

## `security-guard` en detalle

- **19 patrones peligrosos**: `rm -rf /`, `dd if=`, `:(){ :|:& };:`, `chmod -R 777`, etc.
- **3 patrones de secrets**: API keys en texto plano, tokens JWT, cookies largas.
- **Separator-aware (SEC-01)**: detecta el bypass con `&&`, `;`, `|`, `$(…)`
  y backticks. Ejemplo: `echo ok && rm -rf /` dispara el guard aunque
  "echo ok" esté en la whitelist.
- **Permission denylist**: lee paths prohibidos de `opencode.jsonc →
  permission.deny[]`.

Whitelist personalizable:

```jsonc
{
  "omnicoder": {
    "security": {
      "allowCommands": ["git", "bun", "npm", "ls", "grep"],
      "denyPaths": [".ssh/", ".aws/", ".gcp/", ".azure/", ".kube/config"]
    }
  }
}
```

---

## `memory-loader` en detalle

- Lee `~/.omnicoder/memory/patterns.md` + `feedback.md`.
- **Cap**: 1200 bytes total (evita inflar system prompt).
- **Skip si Engram activo**: si hay `mcp.engram` en config, cede el
  control a Engram (que maneja memoria con vector DB).
- **Fallback**: si Engram falla, vuelve a Markdown.

---

## `token-budget` en detalle

- Append-only JSONL en `~/.omnicoder/logs/token-budget.jsonl`.
- Al final de cada sesión calcula `avg(last 10 sessions)`.
- Si > 15 000 tokens promedio → imprime warn al siguiente arranque.
- Útil para detectar **memory bloat** o prompts runaway.

Thresholds:

```jsonc
{
  "omnicoder": {
    "budget": {
      "windowSize": 10,
      "warnThreshold": 15000,
      "errorThreshold": 25000
    }
  }
}
```

---

## `tool-dispatcher` en detalle

- Loggea cada `tool.execute.after` a JSONL.
- Campos: `ts`, `tool`, `duration_ms`, `ok`, `error?`, `args_hash`.
- **Nunca tira excepciones** — si el disk log falla, se ignora.
- Los JSONL se rotan diariamente por `~/.omnicoder/logs/tool-*.jsonl`.

---

## `provider-failover` en detalle

Ver [`03-providers.md`](03-providers.md#cómo-funciona-el-failover).

---

## Escribir un hook propio

```ts
// packages/omnicoder/src/hooks/mi-hook.ts
import type { PluginInput } from "@opencode-ai/plugin"

export const createMiHook = (input: PluginInput) => ({
  async onEvent(event: { type: string; [k: string]: unknown }) {
    if (event.type === "session.start") {
      console.log("[mi-hook] session started at", new Date().toISOString())
    }
  },
})
```

Registrar en `packages/omnicoder/src/index.ts`:

```ts
import { createMiHook } from "./hooks/mi-hook.js"

// dentro de OmnicoderPlugin:
const miHook = await createMiHook(input)

return {
  // … hooks existentes …
  async event({ event }: { event: any }) {
    await budget.onEvent(event)
    await dispatcher.onEvent(event)
    await miHook.onEvent(event)       // ← nuevo
  },
}
```

Test mínimo:

```ts
// packages/omnicoder/test/mi-hook.test.ts
import { test, expect } from "bun:test"
import { createMiHook } from "../src/hooks/mi-hook.ts"

test("mi-hook ignora eventos no-session", async () => {
  const h = createMiHook({} as any)
  await h.onEvent({ type: "other" })  // no throw
  expect(true).toBe(true)
})
```

---

## Benchmarks

Los hooks tienen micro-benchmarks en `packages/omnicoder/bench/`:

```bash
bun run --cwd packages/omnicoder bench/run-all.ts
```

Baseline alpha.0 en `bench/results-v5.0.0-alpha.0.json`. Ver
[`06-benchmarks.md`](06-benchmarks.md).
