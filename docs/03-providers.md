# 03 · Providers y failover

OmniCoder v5 soporta cinco providers LLM, seleccionados por orden de
preferencia y con failover automático con cool-down de 60 s.

---

## Matriz

| Provider | Env var | Endpoint | Caso de uso | Costo | Notas |
|---|---|---|---|---|---|
| **NVIDIA NIM** | `NVIDIA_API_KEY` | `https://integrate.api.nvidia.com/v1` | Desarrollo free-tier | $0 (40 RPM) | Accede a MiniMax M2.7 y Qwen3 Coder gratis |
| **MiniMax direct** | `MINIMAX_API_KEY` | `https://api.minimax.io/anthropic` | Producción con prompt caching | $0.0002/1k in | Anthropic-compat, cache 90% off |
| **DashScope** | `DASHSCOPE_API_KEY` | `https://dashscope-intl.aliyuncs.com/compatible-mode/v1` | Qwen Max enterprise | pago-por-uso | Mejor para chino/inglés |
| **Anthropic** | `ANTHROPIC_API_KEY` | `https://api.anthropic.com` | Reasoning top-tier | $$$$ | Claude Opus 4.7 / Sonnet 4.6 |
| **OpenAI** | `OPENAI_API_KEY` | `https://api.openai.com/v1` | Compat / legacy | $$$ | GPT-4/5 family |

El orden por default en `opencode.jsonc`:

```
nvidia-nim → minimax → dashscope → anthropic → openai
```

Podés reordenarlo editando `~/.config/opencode/opencode.jsonc` (Linux)
o `%APPDATA%\opencode\opencode.jsonc` (Windows).

---

## Per-phase routing (alpha.3+)

Cada agente built-in de opencode (`plan`, `build`, `general`) puede usar un
modelo distinto — útil cuando querés Opus solo en `plan` (donde vale) y
Haiku en `build` (donde pagás volumen). OmniCoder ships un catálogo:

```bash
/routing list            # lista los 7 presets
/routing apply balanced  # Sonnet plan+general, Haiku build
/routing apply quality   # Opus plan, Sonnet build+general
/routing apply cheap     # Haiku en todo excepto plan=Sonnet
/routing apply nim-free  # NVIDIA NIM MiniMax M2.7 en todas las fases
/routing apply mixed-nim-anthropic   # Opus plan, NIM build (mejor valor)
/routing off             # quita overrides → la TUI /models vuelve a mandar
/routing get             # muestra lo aplicado ahora
```

Detrás: `omnicoder-routing` edita solo el bloque `"agent"` del
`opencode.jsonc` del user, preservando comments, MCP servers y plugins.
Cada apply deja un `.bak` al lado por si querés revertir. Hay que
reiniciar la TUI para que tome el cambio.

Podés editar los presets en `~/.omnicoder/routing-presets.json` o
agregar nuevos — el archivo es JSON puro.

---

## Cómo funciona el failover

El hook `provider-failover` (en `packages/omnicoder/src/hooks/provider-failover.ts`):

1. Escucha `chat.params` — antes de cada request, decide qué provider
   usar.
2. Mantiene un estado en memoria con el último error 429 / 5xx por
   provider.
3. Si el provider preferido está en cool-down (<60 s desde el último
   fallo), pasa al siguiente de la lista.
4. Cuando un provider vuelve a responder 200, se "recupera" para siguientes
   calls.

> **Pendiente v5.1**: failover mid-session (si un call en curso falla,
> reintentar con el siguiente provider automáticamente). Upstream issue
> [#7602](https://github.com/sst/opencode/issues/7602) — alpha.1 solo
> logea el fallo.

---

## Verificar qué provider está activo

```bash
omnicoder doctor
# …
# Providers:
#   [ok]   NVIDIA_API_KEY        set
#   [ok]   MINIMAX_API_KEY       set
#   [--]   DASHSCOPE_API_KEY     unset
#   [--]   ANTHROPIC_API_KEY     unset
#   [--]   OPENAI_API_KEY        unset
```

El primer `[ok]` de arriba-abajo es el provider principal. Dentro del
TUI: `/provider` muestra el estado runtime.

---

## Agregar un provider custom

Ver [`05-hooks.md`](05-hooks.md#custom-provider) para el patrón completo.
Resumen:

1. Crear `packages/omnicoder/src/router/providers/miprovider.ts`.
2. Registrarlo en el hook `chat.params`.
3. Declararlo en `opencode.jsonc` bajo `provider:`.
4. Test en `packages/omnicoder/test/providers-miprovider.test.ts`.

---

## Troubleshooting

| Síntoma | Causa probable | Fix |
|---|---|---|
| `429` en loop | Rate limit del provider | Agregar otro API key de fallback, o bajar concurrencia en `opencode.jsonc` |
| Timeout 30 s | Provider lento o región mala | Cambiar endpoint regional (DashScope tiene `-intl`) |
| `401 unauthorized` | Key inválida o expirada | Rotate key; el doctor detecta formato pero no validez |
| Responde pero raro | Modelo default del provider no es el esperado | Forzar modelo en `opencode.jsonc → model:` |
