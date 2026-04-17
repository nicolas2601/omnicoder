# Contribuir a OmniCoder

Gracias por tu interes en OmniCoder. Este documento explica como reportar
problemas, proponer mejoras y enviar cambios de codigo. Todas las
contribuciones deben respetar nuestro [Codigo de Conducta](CODE_OF_CONDUCT.md).

El idioma principal del proyecto es **espanol**. Los commits, issues y PRs
pueden escribirse en espanol o en ingles.

---

## Como reportar bugs

Antes de abrir un issue, revisa si el problema ya fue reportado en la
[lista de issues](https://github.com/nicolas2601/omnicoder/issues).

Si es nuevo, abre uno usando la plantilla de bug report:
[Reportar bug](https://github.com/nicolas2601/omnicoder/issues/new?template=bug_report.md).

Incluye siempre:

- Version de OmniCoder (`omnicoder --version` o contenido de `config/settings.json`).
- Sistema operativo y version (Linux, macOS, Windows).
- Version de `qwen-code` CLI y de las dependencias clave (`jq --version`, `bash --version`).
- Pasos exactos para reproducir, salida observada y salida esperada.
- Log relevante (`~/.qwen/logs/` o la salida del hook afectado).

Si el bug afecta a seguridad, **no abras issue publico**. Sigue el
procedimiento descrito en [SECURITY.md](SECURITY.md).

## Como proponer features

Abre un issue con la plantilla de feature request:
[Proponer feature](https://github.com/nicolas2601/omnicoder/issues/new?template=feature_request.md).

Explica:

1. Problema concreto que resuelve.
2. Propuesta de solucion (aunque sea de alto nivel).
3. Alternativas consideradas.
4. Impacto en hooks, skills, agentes o comandos existentes.

Para cambios grandes (nuevo sistema, ruptura de API interna, nuevo
provider), abre primero una **discusion** antes de escribir codigo.

---

## Setup local

```bash
# 1. Clonar el repo
git clone https://github.com/nicolas2601/omnicoder.git
cd omnicoder

# 2. Instalar (Linux / macOS)
./scripts/install-linux.sh --force

# 3. Instalar (Windows PowerShell)
./scripts/install-windows.ps1 -Force
```

Despues de ejecutar el instalador, los hooks quedan registrados en:

- **Linux / macOS**: `~/.qwen/hooks/` con un `settings.json` apuntando a la copia del repo.
- **Windows**: `%USERPROFILE%\.qwen\hooks\` con el mismo esquema.

El flag `--force` sobrescribe una instalacion previa. Usa `--dry-run` si
solo quieres ver que archivos cambiarian.

Verifica la instalacion con:

```bash
./scripts/doctor.sh
```

## Estructura del proyecto

Vista rapida (detalles en [`docs/architecture.md`](docs/architecture.md)):

```
omnicoder/
├── agents/          # 168 agentes (.md con frontmatter YAML)
├── skills/          # 193 skills (cada una en su carpeta con SKILL.md)
├── hooks/           # 18 hooks bash (PreToolUse, PostToolUse, UserPromptSubmit, ...)
├── commands/        # 21 slash commands
├── config/          # settings.json base + plantillas
├── docs/            # Documentacion, arquitectura, ADRs
├── scripts/         # Instaladores, doctor, build-skill-index, patch-branding
└── examples/        # Configuraciones de ejemplo
```

---

## Estilo de codigo bash

Todos los hooks y scripts deben cumplir:

- Shebang `#!/usr/bin/env bash` en la primera linea.
- Prologo estricto:
  ```bash
  set -euo pipefail
  trap 'echo "{}"; exit 0' ERR
  ```
  El `trap` garantiza que un fallo del hook nunca bloquee al CLI: se emite un
  JSON vacio y se sale con codigo 0.
- **Shellcheck** sin errores (`shellcheck hooks/*.sh scripts/*.sh`). Los
  warnings deben justificarse con un comentario `# shellcheck disable=SCxxxx`.
- Parseo y generacion de JSON **solo con `jq`**, nunca con `sed`, `grep` ni
  concatenacion manual.
- Indentacion de **4 espacios** (nada de tabs).
- Nombres de funciones en `snake_case`; constantes en `UPPER_SNAKE_CASE`.
- Variables locales declaradas con `local` dentro de funciones.
- Rutas absolutas siempre que se dependa del `cwd`.
- Mensajes a usuario en espanol, mensajes a logs en ingles (para grep).

## Anadir un nuevo hook

1. Crea `hooks/mi-hook.sh` con este patron minimo:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   trap 'echo "{}"; exit 0' ERR

   input="$(cat)"
   # Ejemplo: leer el nombre de la herramienta invocada
   tool_name="$(jq -r '.tool_name // empty' <<<"$input")"

   # ... logica ...

   # Devuelve siempre un JSON valido
   jq -n --arg msg "ok" '{message: $msg}'
   ```

2. Registra el hook en `config/settings.json` bajo el evento correspondiente
   (`PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `Stop`, ...):

   ```json
   {
     "hooks": {
       "PostToolUse": [
         { "matcher": "*", "command": "~/.qwen/hooks/mi-hook.sh" }
       ]
     }
   }
   ```

3. Pruebalo localmente simulando el stdin JSON que recibira:

   ```bash
   echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' \
     | ./hooks/mi-hook.sh
   ```

4. Anade shellcheck al pre-commit y un caso a `tests/hooks/mi-hook.test.sh`.

## Anadir un agente o skill

**Agentes**: crea el archivo en `agents/{categoria}-{nombre}.md` con
frontmatter YAML obligatorio:

```markdown
---
name: categoria-nombre
description: Descripcion corta en una linea
tools: Read, Write, Edit, Grep, Glob, Bash
model: sonnet
---

# Rol

... prompt completo del agente ...
```

**Skills**: crea `skills/{nombre}/SKILL.md`:

```markdown
---
name: nombre
description: Cuando debe invocarse esta skill
version: 1.0.0
---

# Instrucciones

... contenido de la skill ...
```

Despues de anadir cualquiera de los dos, regenera el indice del router:

```bash
./scripts/build-skill-index.sh
```

Si omites este paso, el router no vera la nueva skill o agente hasta el
proximo rebuild automatico (24 h).

---

## Commits

Usamos [Conventional Commits](https://www.conventionalcommits.org/es/v1.0.0/).
Prefijos aceptados:

| Prefijo     | Uso                                                      |
|-------------|----------------------------------------------------------|
| `feat:`     | Nueva funcionalidad visible al usuario                   |
| `fix:`      | Correccion de bug                                         |
| `docs:`     | Solo documentacion                                        |
| `chore:`    | Tareas de mantenimiento, sin cambio en comportamiento    |
| `refactor:` | Cambio interno sin nuevo comportamiento ni fix           |
| `perf:`     | Mejora de rendimiento                                     |
| `test:`     | Anade o ajusta tests                                      |

Ejemplos:

```
feat(router): cache stale-while-revalidate para npx skills find
fix(provider-failover): leer payload correcto para detectar HTTP 429
docs(contributing): anadir guia de hooks
perf(hooks): consolidar 6 PostToolUse en post-tool-dispatcher
```

## Pull Requests

Checklist antes de abrir un PR:

- [ ] `shellcheck hooks/*.sh scripts/*.sh` sin errores.
- [ ] Tests locales pasan: `./scripts/test.sh`.
- [ ] `CHANGELOG.md` actualizado en la seccion `## [Unreleased]` con una
      entrada en la categoria correcta (Added / Changed / Fixed / Removed /
      Deprecated / Security).
- [ ] Commits siguen Conventional Commits.
- [ ] No se incluyen secretos, API keys ni archivos `.env`.
- [ ] Si anades skill o agente, corriste `scripts/build-skill-index.sh`.
- [ ] Descripcion del PR explica el **por que**, no solo el **que**.

Enlaza el issue que cierra con `Closes #123`.

---

## Release process

Solo el mantenedor principal ejecuta releases, pero la documentacion del
flujo es:

1. `git checkout main && git pull --ff-only`.
2. Mover entradas de `## [Unreleased]` a `## [X.Y.Z] - YYYY-MM-DD` en
   `CHANGELOG.md` y anadir el link de comparacion al final.
3. Bump de version en `config/settings.json`, `VERSION` y cualquier
   referencia en `README.md`.
4. Commit: `chore(release): v{X.Y.Z}`.
5. Tag: `git tag -a vX.Y.Z -m "v{X.Y.Z}"`.
6. Push: `git push origin main --follow-tags`.
7. GitHub Actions se encarga del resto (build, publish, release notes).

---

## Codigo de Conducta

Al participar, aceptas respetar el
[Codigo de Conducta](CODE_OF_CONDUCT.md). Reportes de violaciones:
`agenciacreativalab@gmail.com`.
