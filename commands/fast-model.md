---
name: fast-model
description: "Configura un modelo rapido como modelo secundario para tareas simples. Reduce latencia en operaciones basicas."
---

# Fast Model Setup

Guia para configurar un modelo rapido como secundario.

## Instrucciones

Explica al usuario como configurar un modelo rapido:

### Opcion 1: Modelo fast de Qwen (si tiene Coding Plan)
```bash
/model --fast qwen3-coder-flash
```
Esto usa un modelo mas ligero para sugerencias de prompts y tareas simples.

### Opcion 2: Modelo local con Ollama (gratis, ultra-rapido)
```bash
# Instalar Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Descargar modelo rapido
ollama pull qwen2.5-coder:7b
```

Agregar a `~/.qwen/settings.json`:
```json
{
  "modelProviders": {
    "openai": [
      {
        "id": "qwen2.5-coder:7b",
        "name": "Qwen 2.5 Coder 7B (Local - Ultra Rapido)",
        "envKey": "OLLAMA_KEY",
        "baseUrl": "http://localhost:11434/v1",
        "generationConfig": {
          "timeout": 30000,
          "samplingParams": {
            "temperature": 0.3,
            "max_tokens": 4096
          }
        }
      }
    ]
  },
  "env": {
    "OLLAMA_KEY": "ollama"
  }
}
```

Luego cambiar con `/model` dentro de Qwen Code.

### Opcion 3: OpenRouter (muchos modelos, paga por uso)
```json
{
  "modelProviders": {
    "openai": [
      {
        "id": "qwen/qwen-2.5-coder-32b-instruct",
        "name": "Qwen 2.5 Coder 32B (OpenRouter)",
        "envKey": "OPENROUTER_KEY",
        "baseUrl": "https://openrouter.ai/api/v1",
        "generationConfig": {
          "timeout": 60000,
          "samplingParams": { "temperature": 0.3 }
        }
      }
    ]
  }
}
```

### Tips de velocidad
- Modelo local (Ollama) = 0 latencia de red, respuestas en 1-3 segundos
- Para tareas simples, usa modelo 7B local. Para complejas, vuelve al modelo cloud
- `/model` para cambiar entre modelos en cualquier momento
