# @nicolas2601/omnicoder

OmniCoder — fork de [opencode](https://github.com/sst/opencode) con:

- 170+ agents especializados pre-configurados
- Skill router BM25 + bigramas (router warm ~1ms)
- Per-phase routing (plan/build/general) con 7 presets
- Memory layer (`patterns.md` + `feedback.md` inyectados al system prompt)
- Tema morado "omnicoder"
- Compatible Linux, macOS, Windows

## Instalación

```bash
npm install -g @nicolas2601/omnicoder
```

## Uso

```bash
# Launch TUI
omnicoder

# Per-phase routing
omnicoder-routing list
omnicoder-routing apply balanced    # Sonnet 4.6 plan, Haiku 4.5 build
omnicoder-routing apply quality     # Opus 4.7 plan, Sonnet 4.6 build
omnicoder-routing apply nim-free    # NVIDIA NIM MiniMax M2.7 (free)
omnicoder-routing off               # reset to default

# Otros
omnicoder doctor
omnicoder --version
```

## Providers soportados

- Anthropic (Opus 4.7, Sonnet 4.6, Haiku 4.5)
- OpenAI (GPT-4o, o1, etc)
- NVIDIA NIM (free tier: MiniMax M2.7)
- MiniMax (API directo)
- OpenRouter, DeepSeek, Groq, Mistral, LM Studio
- Ollama (local)

Configurar via env vars:
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export NVIDIA_API_KEY="nvapi-..."
# etc.
```

## Lo que hace post-install

En tu primera ejecución (o via `npm install -g`):
- Copia ~170 agents → `~/.config/opencode/agent/`
- Copia ~30 commands → `~/.config/opencode/command/`
- Copia tema morado → `~/.config/opencode/theme/omnicoder.json`
- Crea `~/.omnicoder/memory/{patterns,feedback}.md` para memoria persistente
- Crea `~/.omnicoder/routing-presets.json` con los 7 presets

**Nunca sobreescribe** tus agents/commands existentes.

## Licencia

MIT. Fork de opencode (SST, MIT).

## Repo

https://github.com/nicolas2601/omnicoder
