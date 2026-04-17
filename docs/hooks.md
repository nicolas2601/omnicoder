# Hooks

OmniCoder registra 19 hooks en `settings.json` distribuidos por evento del ciclo de vida del CLI. La mayoría son livianos (<50ms). La v4.3 introduce `post-tool-dispatcher.sh`, un dispatcher consolidado que reemplaza 6 hooks PostToolUse separados y baja la latencia por tool-call de ~340ms a ~50ms.

## Tabla completa

Ubicación de todos los scripts: `~/.omnicoder/hooks/` (tras instalar) o `/home/nicolas/omnicoder/hooks/` (repo).

| Hook | Evento | Propósito | Modo |
|------|--------|-----------|------|
| `security-guard.sh` | PreToolUse (Bash) | Bloquea `rm -rf /`, fork bombs, `curl \| sh`, acceso a `.ssh/` | sync |
| `pre-edit-guard.sh` | PreToolUse (Edit/Write) | Impide editar `.env`, `credentials.json`, keys SSH. Detecta API keys en contenido | sync |
| `subagent-inject.sh` | PreToolUse (Task) | Inyecta contrato `<verification>` + reglas anti-400 al subagent antes de spawnear | sync |
| `post-tool-dispatcher.sh` | PostToolUse (all) | **v4.3** — Consolida 6 hooks: logger, error-learner, success-learner, skill-usage-tracker, causal-learner, token-tracker. Parsea input una vez, dispatcha a funciones internas en background | sync+async |
| `post-tool-logger.sh` | PostToolUse (all) | Log legacy (sigue disponible standalone si desactivas el dispatcher) | async |
| `error-learner.sh` | PostToolUse (all) | Registra fallas en `learned.md` con dedup md5 (disponible standalone) | async |
| `success-learner.sh` | PostToolUse (all) | Captura `tests-pass`, `build-ok`, `lint-clean`, `commit` → `trajectories.md` | async |
| `skill-usage-tracker.sh` | PostToolUse (all) | Detecta si ignoraste la sugerencia del router, incrementa contador → eleva enforcement | async |
| `causal-learner.sh` | PostToolUse (all) | Buffer de 2 comandos. Si prev falló y curr tuvo éxito → genera causal edge | async |
| `token-tracker.sh` | PostToolUse (all) | Estima tokens por tool-call, acumula por sesión | async |
| `provider-failover.sh` | PostToolUse (all) | Detecta 429, 503, timeout. Sugiere switch de provider. Separado por emitir `additionalContext` crítico | sync |
| `subagent-verify.sh` | PostToolUse (Task) | Parsea `<verification>`, valida mtime, evidencia de tests. Emite `[VERIFICACION-FALLIDA]` si falta algo | sync |
| `subagent-error-recover.sh` | PostToolUse (Task) | Detecta 4 patrones de error 400 del modelo coder. Emite `[SUBAGENT-400-DETECTADO]` con plan (acortar prompt, quitar code-fences, Edit directo, secuencial vs paralelo) | sync |
| `skill-router.sh` | UserPromptSubmit | **v4.2** — Hybrid BM25 + bigramas + memoria feedback. Emite HARD/SOFT/HINT | sync |
| `session-init.sh` | SessionStart | Detecta handoff previo, stack del proyecto, branch actual | sync |
| `memory-loader.sh` | SessionStart | Carga `patterns.md + feedback.md + learned.md` como contexto inicial | sync |
| `auto-handoff.sh` | Stop | Si la sesión fue productiva (5+ operaciones), propone crear handoff document | sync |
| `reflection.sh` | Stop | Auto-reflexión: cuenta errores/éxitos/ignorados, escribe lección en `reflections.md`. Cada 5 destila a `patterns.md` | sync |
| `notify-desktop.sh` | Notification | Envía notificaciones nativas (`notify-send` en Linux, `osascript` en macOS) | async |

## post-tool-dispatcher (novedad v4.3)

```
Reemplaza 6 hooks separados (post-tool-logger, error-learner,
success-learner, skill-usage-tracker, causal-learner, token-tracker)
con un solo proceso que parsea el INPUT una sola vez y dispatcha
a funciones internas. Reduce latencia por tool-call de ~340ms a ~50ms.

Filosofía:
  - Logging/learning NUNCA deben bloquear el siguiente LLM call
  - Los aprendizajes se ejecutan en background (&) después del exit
  - Solo provider-failover queda separado (emite additionalContext crítico)
```

El dispatcher parsea `tool_name`, `tool_input`, `tool_response`, `exit_code`, `session_id`, `cwd` una sola vez y llama a las funciones internas correspondientes. Los aprendizajes pesados corren con `&` en background.

## Hooks por evento

| Evento | Hooks |
|--------|-------|
| **PreToolUse** | security-guard, pre-edit-guard, subagent-inject |
| **PostToolUse** | post-tool-dispatcher, provider-failover, subagent-verify, subagent-error-recover |
| **UserPromptSubmit** | skill-router |
| **SessionStart** | session-init, memory-loader |
| **Stop** | auto-handoff, reflection |
| **Notification** | notify-desktop |

## Contexto emitido (síncrono vs asíncrono)

- **Sync emite al stdout** (line-count: 1–5 líneas) y ese contexto se inyecta al LLM antes del siguiente turn.
- **Async corre en background** (`&` o `nohup`) y escribe sólo a memoria. No bloquea.

El router, verificadores y failover son los únicos que deben bloquear: su output cambia el comportamiento del modelo en el turno inmediato.

## Crear un hook custom

1. Escribe un script bash en `~/.omnicoder/hooks/mi-hook.sh`.
2. Debe leer `$INPUT` (stdin JSON) y emitir JSON por stdout (mínimo `{}`).
3. Regístralo en `~/.omnicoder/settings.json` bajo el evento correspondiente:

```json
{
  "hooks": {
    "PostToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "~/.omnicoder/hooks/mi-hook.sh" }] }
    ]
  }
}
```

4. `chmod +x ~/.omnicoder/hooks/mi-hook.sh`.
5. Prueba con `echo '{"tool_name":"Bash"}' | ~/.omnicoder/hooks/mi-hook.sh`.

Revisa el código de `post-tool-dispatcher.sh` como referencia: parseo con `jq`, `set -euo pipefail`, `trap 'echo "{}"; exit 0' ERR`.
