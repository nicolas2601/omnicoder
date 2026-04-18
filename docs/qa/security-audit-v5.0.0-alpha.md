# OmniCoder v5.0.0-alpha — Security Audit

**Auditor**: security-auditor (Claude Opus 4.7)
**Fecha**: 2026-04-18
**Scope**: `packages/omnicoder/src/**`, `.omnicoder/opencode.jsonc`, `docs/adr/**`, `install`, `package.json`, `bun.lock`, `.gitignore`, LICENSE, git history
**Branch**: `v5-migration` (HEAD `f11d0a8`)
**Severidad**: CRITICAL / HIGH / MEDIUM / LOW / INFO

---

## Resumen ejecutivo

OmniCoder v5 está en **estado alpha muy temprano** (scaffold funcional del plugin, sin `bun install`). No se detectaron secretos hardcoded ni credenciales en el repositorio, y el uso del patrón `{env:VAR}` en `opencode.jsonc` es correcto. Sin embargo, la **capa de seguridad tiene defectos lógicos severos** (bypass del whitelist), la **permission config de opencode.jsonc deja descubiertos paths críticos** (`.ssh`, `.aws`, `.git/config`), y **falta por completo la verificación de supply chain de Engram** (binario externo Go sin install script, sin pinning, sin checksum). La **atribución MIT a SST está ausente** (riesgo de compliance).

## Tabla de hallazgos

| ID | Severidad | Categoría | Archivo:línea | Descripción | Recomendación | Status |
|----|-----------|-----------|---------------|-------------|---------------|--------|
| SEC-01 | CRITICAL | Security logic bypass | `packages/omnicoder/src/security/index.ts:37-44, 73-75` | WHITELIST se evalúa **antes** que DANGEROUS/SECRETS y sólo matchea el prefijo del comando. `git pull && rm -rf /`, `ls; dd if=/dev/zero of=/dev/sda`, `cat file; sudo rm -rf /etc` todos pasan porque el prefijo (`git `, `ls `, `cat `) abre un bypass total para el resto de la línea. Comentario en código: "sudo rm never passes because sudo isn't in list" — FALSO. | Invertir orden: evaluar DANGEROUS/SECRETS **primero**, WHITELIST sólo como override explícito. Además, tokenizar con shell-quote y chequear cada comando separado por `;`, `&&`, `\|\|`, `\|`. | OPEN |
| SEC-02 | HIGH | Command injection / regex robustness | `packages/omnicoder/src/security/index.ts:9-35` | Las regex son case-sensitive selectivas y no cubren variantes triviales: `/bin/rm -rf /`, `\rm -rf /` (alias bypass), `RM -RF /` (solo algunos patrones tienen `/i`), `$(rm -rf /)`, backticks `` `rm -rf /` ``, `eval "rm -rf /"`, variables `CMD="rm -rf /"; $CMD`, IFS hacks, brace expansion `rm -rf /{etc,usr}`. El regex `/\bsudo\b/i` es bueno pero lo blockea el whitelist antes. | Añadir denylist de substrings (no regex): `rm -rf`, `mkfs`, `dd if=`, `> /dev/sd`, `chmod 777`, `curl \| sh`. Normalizar comando (strip backticks, `$()`, expandir aliases comunes). | OPEN |
| SEC-03 | HIGH | Permission coverage gap | `.omnicoder/opencode.jsonc:82-95` | `permission.edit` deniega `/etc/**`, `**/.env*`, `**/*.pem`, `**/*.key` pero **no cubre**: `**/.ssh/**`, `**/.aws/**`, `**/.config/gh/**`, `**/.git/config`, `**/.gitconfig`, `**/.npmrc`, `**/.netrc`, `**/*.p12`, `**/*.pfx`, `**/*.crt`, `**/id_rsa*`, `**/id_ed25519*`, `**/.docker/config.json`, `**/.kube/config`. | Ampliar glob denylist. Considerar denylist por default y allowlist explícito para `src/**`, `tests/**`, `docs/**`. | OPEN |
| SEC-04 | HIGH | Privilege escalation policy | `.omnicoder/opencode.jsonc:91` | `"sudo *": "ask"` permite al usuario aceptar sudo interactivamente — pero el plugin de security (SEC-01) bloquea `sudo` por regex. Inconsistencia: el config dice "ask", el plugin dice "deny". Si se arregla SEC-01, el user verá prompt que el security guard va a abortar igual. | Alinear: `"sudo *": "deny"` en config, mantener regex en guard. Si algún flujo legítimo necesita sudo, documentarlo y whitelist explícito por comando. | OPEN |
| SEC-05 | HIGH | Supply chain (Engram) | `docs/adr/ADR-002-engram-memory.md` vs repo | ADR-002 afirma que Engram es un binario Go externo instalado en `$PATH`. **No existe install script, ni verificación de checksum/signature, ni pinning de versión** en el repo. `opencode.jsonc` ejecuta `["engram", "mcp"]` confiando en PATH resolution — un atacante local que plante `engram` antes en PATH, o upstream de gentleman-programming/gentle-ai comprometido, ejecuta arbitrary code con los datos de memoria. | Agregar `scripts/install-engram.sh` que: (1) pin a versión exacta (ej. v1.12.0), (2) descarga release GitHub, (3) verifica SHA-256 hardcoded o firma sigstore, (4) instala en path versionado (`~/.omnicoder/bin/engram-v1.12.0`), (5) `opencode.jsonc` usa path absoluto con versión. | OPEN |
| SEC-06 | HIGH | License compliance — attribution missing | `LICENSE` | LICENSE mantiene `Copyright (c) 2025 opencode` y `packages/opencode` (fork upstream). No hay `NOTICE` ni párrafo de atribución a `sst/opencode` en el README principal / CONTRIBUTING. MIT requiere preservar el copyright notice en "all copies or substantial portions". Si publicamos `@omnicoder/core` en npm, debe llevar también el texto MIT y attribution. | Agregar al README un párrafo "Based on sst/opencode (MIT, Copyright (c) 2025 opencode)". Incluir `LICENSE` de upstream en `packages/omnicoder/LICENSE` y `packages/omnicoder/NOTICE` con attribution. | OPEN |
| SEC-07 | MEDIUM | Dependency integrity | `package.json` + `bun.lock` | `bun install` **no se ha ejecutado** (no existe `node_modules/`). Sin `bun audit` ni reproducción local del árbol no puedo cruzar con NVD. `bun.lock` existe (7181 líneas) y usa `catalog:` para pinning centralizado (bueno). Deps con versión floating `semver: ^7.6.0` / `^7.6.3` en workspaces — aceptable pero revisar drift. `marked: catalog: (17.0.1)` no tiene CVEs conocidas en 17.x; `@aws-sdk/client-s3 3.933.0` ok; `dompurify 3.3.1` ok; `hono 4.10.7` ok; `cross-spawn 7.0.6` sin CVEs activos; `zod 4.1.8` no tiene CVEs. **Ninguna CVE evidente**, pero no validado con audit. | Correr `bun install && bun audit --audit-level=moderate` antes de release. Fijar todas las versiones floating (`^`) a exactas para alpha. Agregar `bun audit` al CI. | OPEN |
| SEC-08 | MEDIUM | Peer deps / version drift | `packages/omnicoder/package.json:35-38` | `peerDependencies`: `@opencode-ai/plugin: "*"` y `@opencode-ai/sdk: "*"` — wildcard es peligroso; cualquier major upstream romperá compatibilidad silenciosamente. Correcto que sean peer (no regular), pero versión debe ser acotada. Package **no está listado en `workspaces` del root `package.json`** (grep `packages/omnicoder` en `bun.lock` = 0 matches). | Cambiar a `"@opencode-ai/plugin": "workspace:*"` o a rango semver acotado (`"^1.0.0"`). Añadir `packages/omnicoder` a workspaces del root. | OPEN |
| SEC-09 | MEDIUM | Memory loader path injection (teórico) | `packages/omnicoder/src/memory/index.ts:52-56, 28-47` | Memory loader lee paths hardcoded relativos a `os.homedir()` → `~/.omnicoder/memory/patterns.md` y `feedback.md`. No hay path traversal explotable desde el plugin actual (no acepta input del agente). **Pero** el ADR-002 menciona `mem_save` / `mem_update` expuesto vía Engram MCP — el plugin NO implementa esas tools (las expone Engram directamente), así que la superficie de ataque de path traversal vive en Engram, fuera del scope auditado. | Verificar en auditoría separada que Engram valida paths de `mem_save`. Documentar que el plugin nunca ejecuta operaciones de filesystem con input controlado por el modelo. | INFO-ONLY |
| SEC-10 | MEDIUM | Prototype pollution | todos los módulos del plugin | Grep por `Object.assign`, `__proto__`, `constructor[`, `prototype[` = 0 matches. Config merge se delega a Opencode core. Sin embargo, `memory/index.ts:39` usa `Object.prototype.hasOwnProperty.call(parsed.mcp, "engram")` — patrón defensivo correcto. `JSON.parse(raw)` en configs sin validación de schema. | Bajo riesgo actual. Añadir schema validation con Zod cuando se lean configs externas. | LOW-RISK |
| SEC-11 | MEDIUM | Logging info disclosure | `packages/omnicoder/src/hooks/tool-dispatcher.ts:48-55` | `tool-usage.jsonl` loguea `sessionID`, `tool`, `durationMs`, `outputLen` — **no loguea args ni output**, lo cual es bueno. Pero `token-log.jsonl` se escribe en `~/.omnicoder/logs/` sin rotación ni TTL; puede crecer indefinidamente y exponer metadatos de sesión si el $HOME se comparte. | Agregar rotación (máx 10 MB, 5 archivos) y documentar que los logs contienen metadatos de sesión. | OPEN |
| SEC-12 | LOW | `curl * \| sh` glob en opencode.jsonc | `.omnicoder/opencode.jsonc:92-93` | El valor `"curl * \| sh": "deny"` probablemente se interpreta como glob (pattern matching), no como regex. `curl example.com\|sh` (sin espacios) puede no matchear. El security guard sí cubre el caso vía regex `/curl\s+[^\|]*\|\s*(ba)?sh\b/i`. | Verificar en docs de Opencode cómo se parsean los `bash` patterns. Si es glob, cambiar por entradas más específicas o confiar 100% en el plugin de security. | OPEN |
| SEC-13 | LOW | Regex path traversal limitada | `packages/omnicoder/src/security/index.ts:27` | `/(^\|\s)\.\.\/(\.\.\/){2,}/` requiere ≥3 niveles consecutivos. `../../` (2 niveles) pasa. `../etc/passwd` (1 nivel) pasa. | Reducir umbral o permitir 1+ niveles cuando el comando toca `/etc`, `~/.ssh`, `~/.aws`. | OPEN |
| SEC-14 | LOW | Error leaks stacktrace/filepath | `packages/omnicoder/src/memory/index.ts:98`, `router/index.ts:149`, etc. | Errores se logean a `console.error` con `(err as Error).message`. No se loguea stack. Bueno. Pero en producción, si hay un error de `fs.readFile`, la ruta completa del archivo puede ir al stderr del proceso host (opencode CLI). | Sanitizar paths en mensajes de error (strip `os.homedir()`). Bajo impacto. | OPEN |
| SEC-15 | INFO | Git history limpio | `git log --all --full-history` | No hay archivos `.env`, `.pem`, `.key`, `*secret*` commiteados en history. Solo `packages/slack/.env.example` (placeholder template, sin secretos reales). `infra/secret.ts` usa `sst.Secret("...", "unknown")` — placeholder SST, OK. Commented test fixture `apiKey: "glpat-internal-token"` en `packages/opencode/test/provider/gitlab-duo.test.ts:157` no es secreto real. | Sin acción. | CLEAN |
| SEC-16 | INFO | `.gitignore` adecuado | `.gitignore` | `.env`, `.direnv/`, `logs/`, `dist`, `node_modules` correctamente ignorados. `.codex`, `.serena` también. | Sin acción. | CLEAN |
| SEC-17 | INFO | Patrón `{env:VAR}` consistente | `.omnicoder/opencode.jsonc:16, 28, 40, 56` | Todas las API keys usan indirection `{env:NVIDIA_API_KEY}`, `{env:MINIMAX_API_KEY}`, `{env:DASHSCOPE_API_KEY}`, `{env:ENGRAM_PROJECT}`. Ningún valor hardcoded. | Sin acción. | CLEAN |
| SEC-18 | INFO | Tests de security incluidos | `packages/omnicoder/test/security.test.ts` | Existe test suite (56 líneas) que cubre happy path, malformed args, y destructive cases. **Pero no cubre el bypass SEC-01** (`git pull && rm -rf /`, `cat foo; rm -rf /`). | Agregar test cases de bypass. | OPEN |
| SEC-19 | LOW | Hook error-swallow | `packages/omnicoder/src/hooks/tool-dispatcher.ts:32-34`, `budget/index.ts:91-93`, etc. | Casi todos los hooks hacen `catch(err) { console.error(...) }` sin propagar. Documentado como política explícita ("strict no-op on errors"). Garantiza que el plugin no rompa el pipeline, pero **puede enmascarar fallas de seguridad** (ej. security guard nunca silencia por design — correcto; pero si alguien agrega un try/catch ahí, se rompe el contrato). | Añadir comentario `// NEVER wrap in try/catch — must throw` en `security/index.ts::check()`. Añadir lint rule. | OPEN |
| SEC-20 | LOW | SPDX / file headers ausentes | todos los `.ts` del plugin | Ningún archivo tiene header SPDX (`// SPDX-License-Identifier: MIT`). No obligatorio para MIT, pero recomendado cuando se distribuye en npm. | Añadir header SPDX a cada archivo fuente de `@omnicoder/core`. | OPEN |

---

## Análisis complementario

### Secretos y credenciales — LIMPIO

- Regex de API keys, AWS, OpenAI, GitHub, private keys sobre todo el tree: **0 matches reales**.
- `.env` tracked: **0**.
- `opencode.jsonc` tiene todos los secrets vía `{env:VAR}` indirection.
- Un solo hit "sospechoso": `packages/opencode/test/provider/gitlab-duo.test.ts:157` comentado (`// apiKey: "glpat-internal-token"`), es fixture de test upstream. **No es un secret real.**

### OWASP Top-10 quick map

- **A01 Broken Access Control**: SEC-01, SEC-03, SEC-04 (HIGH combinado).
- **A02 Crypto Failures**: N/A (plugin no hace criptografía directa).
- **A03 Injection**: SEC-02 (regex escape), SEC-09 (path injection teórico).
- **A04 Insecure Design**: SEC-05 (no integrity check en Engram).
- **A05 Misconfig**: SEC-03, SEC-04, SEC-12.
- **A06 Vulnerable Components**: SEC-07, SEC-08.
- **A08 Integrity Failures**: SEC-05.
- **A09 Logging Failures**: SEC-11.

### CVEs conocidas en top-level deps

Spot check contra NVD (manual, 2026-04-18):
- `dompurify 3.3.1` — sin CVE activo.
- `marked 17.0.1` — sin CVE activo (CVE-2022-21680/21681 eran en <4.0.10).
- `@aws-sdk/client-s3 3.933.0` — sin CVE activo.
- `cross-spawn 7.0.6` — sin CVE (CVE-2024-21538 fue en <7.0.5; estamos en 7.0.6, safe).
- `semver ^7.6.0` — CVE-2022-25883 fue en <7.5.2; safe.
- `hono 4.10.7` — sin CVE activo.
- `zod 4.1.8`, `effect 4.0.0-beta.48`, `remeda 2.26.0` — sin CVE activo.
- `node-pty` / `@lydell/node-pty` 1.2.0-beta.10 — beta; sin CVE reportado pero vigilar.

**Bloqueante**: no se ha corrido `bun install` ni `bun audit`. Obligatorio antes de go-live.

---

## Score de seguridad

**Puntaje global: 5.5 / 10** (alpha temprano, base sólida, fallas críticas subsanables).

Desglose:
- Secret hygiene: 9/10 (CLEAN)
- Security guard (code): 4/10 (bypass SEC-01 es crítico)
- Permission config: 5/10 (cobertura parcial)
- Supply chain: 3/10 (sin verificación Engram, sin audit corrido)
- Dependency hygiene: 6/10 (pinning OK, audit pendiente)
- Compliance (license/SPDX): 5/10 (falta attribution)
- Test coverage de seguridad: 6/10 (existe, no cubre bypass)

## Recomendación go/no-go

**NO-GO para release v5.0.0-alpha.0 al público** hasta resolver CRITICAL y HIGH.

Mínimo bloqueante antes de publicar:

1. **SEC-01** (bypass whitelist) — fix obligatorio, trivial.
2. **SEC-05** (Engram install script con checksum) — obligatorio si se documenta Engram como default.
3. **SEC-06** (attribution SST/opencode) — obligatorio para evitar conflicto MIT.
4. **SEC-07** (`bun install && bun audit`) — obligatorio para confirmar que el árbol resuelto no tiene CVEs.
5. **SEC-03** (permission coverage) — obligatorio, 10 minutos de trabajo.

**GO para alpha interno / dogfood** una vez aplicados los 5 anteriores + extended tests para SEC-01. Los otros 15 hallazgos (MEDIUM/LOW/INFO) pueden quedar como debt rastreado en issues para v5.0.0-beta.

Próxima auditoría recomendada: después de aplicar los fixes críticos, antes de primer tag público.

---

**Fin del reporte.** ~1450 palabras.
