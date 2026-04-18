# 04 · Skills y agentes

OmniCoder v5 trae **193 skills** y **167 agents** portados desde v4 y
adaptados al formato de Opencode.

---

## Dónde viven

| | Repo (source of truth) | Runtime del usuario |
|---|---|---|
| Skills | `.opencode/skills/` | `~/.omnicoder/skills/` |
| Agents | `.opencode/agent/` | `~/.omnicoder/agents/` |

Cuando corrés `omnicoder`, el plugin prioriza primero `~/.omnicoder/` (tus
edits locales) y cae a `.opencode/` (del repo).

---

## Formato

### Skills (`SKILL.md`)

Cada skill es un directorio con un `SKILL.md` en la raíz:

```markdown
---
name: mi-skill
description: Qué hace este skill (se usa para ranking BM25)
tags: [typescript, testing, backend]
---

# Mi skill

Instrucciones / prompt que se inyectan cuando el router decide usarlo.
```

El **skill-router** (en `packages/omnicoder/src/router/`) hace BM25 +
bigramas sobre `name + description + tags` contra el mensaje del usuario
y elige los top-N. Default N=3, configurable en `opencode.jsonc → omnicoder.router.topN`.

### Agents (`*.md` con frontmatter)

```markdown
---
name: backend-architect
description: Diseña arquitecturas backend escalables
primary: false
model: minimax-m2.7
tools: [bash, read, write, grep]
---

# Backend Architect

System prompt del agente…
```

El agente promovido a `primary: true` es el que arranca por default al
iniciar `omnicoder`. En v5 es `agents-orchestrator` — delega a los otros
166 bajo demanda.

---

## Reinstalar skills/agents desde el repo

```bash
omnicoder install-skills
# o manual:
cp -r .opencode/skills/* ~/.omnicoder/skills/
cp -r .opencode/agent/* ~/.omnicoder/agents/
```

Con este comando *sí* se pisan tus edits locales si pasás `--force`.

---

## Crear un skill nuevo

```bash
mkdir -p ~/.omnicoder/skills/mi-skill
cat > ~/.omnicoder/skills/mi-skill/SKILL.md <<'EOF'
---
name: mi-skill
description: Genera tests de integración para APIs REST usando supertest + Jest
tags: [testing, rest, supertest, integration]
---
Prompt del skill…
EOF
```

El router lo detecta al próximo arranque (rebuild-index se dispara con
`needs_rebuild` memoizado 60 s).

Si querés que el skill viaje con el repo, colocalo en
`.opencode/skills/mi-skill/` y abrí PR.

---

## Crear un agent nuevo

```bash
mkdir -p ~/.omnicoder/agents
cat > ~/.omnicoder/agents/mi-agente.md <<'EOF'
---
name: mi-agente
description: Descripción corta para el orchestrator
primary: false
model: minimax-m2.7
tools: [bash, read, write]
---
# Mi Agente

System prompt…
EOF
```

Se activa automáticamente. Para que el orchestrator lo delegue bien,
poné `description:` clara y específica.

---

## Agents y skills destacados (portados de v4)

Categorías completas (v4):

- **Engineering** (27) · **Design** (8) · **Marketing** (27) · **Testing** (8)
- **Paid Media** (7) · **Product** (4) · **Sales** (8) · **Game Dev** (20)
- **Project Management** (6) · **Academic** (5) · **Specialized** (30+)
- **Support** (6) · **Spatial Computing** (6)

El listado completo vive en `.opencode/agent/` — usá `omnicoder` y pedile
"lista los agentes disponibles" o explorá el filesystem.

---

## Deshabilitar un skill/agent

```bash
# mover fuera del directorio escaneado
mv ~/.omnicoder/skills/skill-aburrido ~/.omnicoder/skills/.disabled-skill-aburrido
```

El router ignora directorios con prefijo `.`. Para reactivarlo, renombrá
quitando el punto.

---

## Métricas y debugging del router

```bash
# Tiempo de resolución en el último arranque
cat ~/.omnicoder/logs/router-timing.jsonl | tail -5

# Top skills inyectados en las últimas 100 sesiones
jq '.skills[]' ~/.omnicoder/logs/router-timing.jsonl | sort | uniq -c | sort -rn | head
```

---

## Testing

Los tests del router viven en `packages/omnicoder/test/router-*.test.ts`:

```bash
bun run --cwd packages/omnicoder test -- --grep router
```
