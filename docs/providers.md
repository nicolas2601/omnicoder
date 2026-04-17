# Providers

OmniCoder v4 es model-agnostic: funciona con cualquier API compatible con OpenAI. El CLI base (Qwen Code) acepta `OPENAI_API_KEY` + `OPENAI_BASE_URL` y ruta todas las llamadas ahí.

## Tabla comparativa

| Provider | Modelo destacado | Free tier | Precio pagado | Latencia | Prompt cache | Notas |
|----------|------------------|-----------|---------------|----------|--------------|-------|
| **NVIDIA NIM** | MiniMax-M2.7 | Sí (40 RPM, créditos finitos) | N/A | Baja | No | Créditos cloud caducan; después "cloud credits expired" |
| **Google Gemini** | gemini-2.5-flash, gemini-2.5-pro | Sí (1500 req/día flash) | Pay-as-you-go | Media | Sí (implícito) | Contexto enorme (1M–2M tokens) |
| **MiniMax** | MiniMax-M2.7 | Limitado | $10/mes plan | Media | No confirmado | Mejor calidad/precio para coding en 2026 |
| **DeepSeek** | deepseek-coder-v2, deepseek-v3.2 | Limitado | Más barato del mercado | Media | Sí | Especializado en código |
| **OpenRouter** | 300+ modelos (agregador) | Por modelo | Varía | Varía | Depende del upstream | Útil para A/B testing de modelos |
| **Ollama** | qwen2.5-coder:7b, codellama | Gratis (local) | N/A | Ultra baja | No aplica | Sin internet, máxima privacidad |
| **Groq** | llama-3.1-70b | Sí | N/A | Ultra baja | No | **No sirve** para OmniCoder: TPM bajo, bloquea en cuanto lanzas 3+ tools |

## Setup

### Script automático

```bash
./scripts/setup-provider.sh
```

Pregunta por provider, API key y modelo. Escribe a `~/.qwen/settings.json` y `~/.omnicoder/.provider-current`.

### Manual

Edita `~/.qwen/settings.json`:

```json
{
  "contentGenerator": {
    "authType": "openai-compat",
    "baseUrl": "https://integrate.api.nvidia.com/v1",
    "apiKey": "nvapi-...",
    "model": "qwen/qwen3-coder-480b-a35b-instruct",
    "timeout": 180000
  }
}
```

> `timeout: 180000` (3 min) evita el error "Streaming request timeout after 45s".

## Switch en caliente

```bash
./scripts/switch-provider.sh
```

Lista los providers configurados y cambia sin reiniciar. Útil cuando NVIDIA te da "cloud credits expired" y necesitas fallback a Gemini.

## Endpoints verificados

| Provider | baseUrl | authType |
|----------|---------|----------|
| NVIDIA NIM | `https://integrate.api.nvidia.com/v1` | `openai-compat` |
| Google Gemini | `https://generativelanguage.googleapis.com/v1beta/openai/` | `openai-compat` |
| MiniMax | `https://api.minimax.io/v1` | `openai-compat` |
| DeepSeek | `https://api.deepseek.com/v1` | `openai-compat` |
| OpenRouter | `https://openrouter.ai/api/v1` | `openai-compat` |
| Ollama local | `http://localhost:11434/v1` | `openai-compat` |

## Failover automático

`provider-failover.sh` (PostToolUse hook) detecta 429, 503 y timeout del provider activo. Cuando dispara 3+ errores, emite `additionalContext` sugiriendo:

1. `./scripts/switch-provider.sh` a un provider alternativo.
2. Activar `/turbo on` para reducir carga.
3. Bajar a un modelo más pequeño del mismo provider.

## Claude Code con MiniMax (Anthropic-compat)

Si prefieres Claude Code sobre Qwen Code CLI, MiniMax expone un endpoint Anthropic-compat:

```bash
export ANTHROPIC_BASE_URL="https://api.minimax.io/anthropic"
export ANTHROPIC_AUTH_TOKEN="<tu-minimax-key>"
export ANTHROPIC_MODEL="MiniMax-M2.7"

claude
```

Esto permite correr Claude Code pagando MiniMax ($10/mes) en vez de Anthropic directo. Compatibilidad con tools: buena. Compatibilidad con prompt caching: no garantizada.

## Prompt caching

| Provider | Soporta caching | Implementación |
|----------|-----------------|----------------|
| Anthropic directo | Sí | `cache_control: ephemeral` explícito |
| Gemini | Sí (implícito) | Cache automático por prefijo |
| DeepSeek | Sí | Implícito, facturado a mitad de precio |
| MiniMax (Anthropic-compat) | Dudoso | Probar antes de confiar |
| NVIDIA NIM | No | Cada request es fresh |
| OpenAI-compat genérico | No estándar | Depende del upstream |

Para OmniCoder con hooks cognitivos, el caching de Gemini y DeepSeek es el más efectivo: reutilizan el prefijo de `OMNICODER.md + memoria cargada` entre calls.

## Recomendación 2026

1. **Principal**: NVIDIA NIM (M2.7 FREE 40 RPM) hasta que caduquen créditos.
2. **Secundario**: Gemini AI Studio 2.5-flash (1500/día free).
3. **Premium**: MiniMax $10/mes cuando los gratuitos no alcancen.
4. **Local fallback**: Ollama con qwen2.5-coder:7b.

Evita Groq para OmniCoder: su TPM bajo bloquea en cuanto el agente lanza paralelismo.
