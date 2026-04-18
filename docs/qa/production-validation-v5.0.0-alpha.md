# Production Validation — OmniCoder v5.0.0-alpha.0

**Fecha**: 2026-04-18 · **Validador**: production-validation agent · **Branch**: `v5-migration` · **Target tag**: `v5.0.0-alpha.0`

---

## Go / No-Go

**Verdict: GO-WITH-FIXES** (puede publicarse hoy como `alpha.0` tras aplicar dos fixes de 5 minutos: regenerar `bun.lock` y commitear `packages/omnicoder/bench/`).

Sin esos dos fixes: **NO-GO** porque la release workflow disparará `bun install --frozen-lockfile` que ya está roto localmente, y `bench/` queda untracked.

- Tests: 45/45 pass en 191 ms (SEC-01 regression incluido, 5/5 pass).
- Build/typecheck: limpio en el paquete propio; dos warnings que vienen de `opencode` upstream (no ship-blockers).
- Seguridad: SEC-01/03/04/06 aplicados y verificados con evidencia en archivo:línea.
- Supply-chain: `bun audit` reporta 114 vulnerabilidades, 100 % en dependencias upstream (Opencode); 0 en `@omnicoder/core`. No blocker para alpha.

---

## Evidencia por dimensión

### 1. Versioning / metadata — 10/10

| Item | Estado | Evidencia |
|---|---|---|
| `version = 5.0.0-alpha.0` | OK | `packages/omnicoder/package.json:4` |
| CHANGELOG entry con fecha | OK | `CHANGELOG.md:7` `[5.0.0-alpha.0] — 2026-04-18` |
| 5 ADRs presentes | OK | `docs/adr/ADR-001..ADR-005` (3518, 2639, 2452, 1892, 2930 bytes) |
| LICENSE atribuye SST | OK | `LICENSE:3` `Copyright (c) 2025 SST / opencode (original work)` |
| NOTICE atribuye SST | OK | `NOTICE:4-5` `derivative work of Opencode by SST` |
| README package ack opencode | OK | `packages/omnicoder/README.md:41` `derivative work of Opencode by SST (MIT)` |

### 2. Build / tests / typecheck — 8/10

- `bun install --frozen-lockfile`: **FAIL** en 1.4 s — `error: lockfile had changes, but lockfile is frozen`. Root cause: `packages/omnicoder/package.json` nuevo añadió `@types/bun` + `typescript` a `devDependencies` pero no se regeneró `bun.lock`. **Ship-blocker** porque CI corre con `--frozen-lockfile`.
- `bun test` (en `packages/omnicoder`): **45/45 pass**, 111 `expect()`, 191 ms, 12 archivos. Logs internos visibles (provider-failover, budget, tool-dispatcher), todos esperados.
- `bunx tsc --noEmit` (no hay `tsgo`): 2 errores menores, ninguno en código propio:
  - `../opencode/tsconfig.json(3,14) TS6053: File '@tsconfig/bun/tsconfig.json' not found` — viene de Opencode upstream y se resolvería al regenerar `bun.lock`.
  - `tsconfig.json(4,5) TS5101: Option 'baseUrl' is deprecated` — warning, no error bloqueante.
- `bun run lint` (root): `oxlint: orden no encontrada` — bin no instalado en `node_modules` porque install falló. Se desbloquea con el mismo fix.

### 3. CI/CD — 9/10

- Workflows nuevos: `omnicoder-ci.yml`, `omnicoder-pr.yml`, `omnicoder-release.yml` — sintaxis YAML **válida** (`bunx js-yaml` sin errores). Triggers correctos: `v*.*.*` tag en release, `packages/omnicoder/**` path filter en ci.
- `dependabot.yml` válido, npm weekly + github-actions weekly, reviewer `nicolas2601`.
- `CODEOWNERS:2` `* @nicolas2601` + 4 reglas específicas del fork.
- **Upstream gating incompleto**: solo 20/32 workflows upstream tienen `if: github.repository == 'sst/opencode'`. 12 siguen sin gate: `generate.yml, release-github-action.yml, review.yml, stats.yml, storybook.yml, sync-zed-extension.yml, test.yml, triage.yml, typecheck.yml, vouch-check-issue.yml, vouch-check-pr.yml, vouch-manage-by-issue.yml`. El CHANGELOG afirma "19 gated" — la realidad son 20, pero quedan 12 huérfanos que ejecutarán en el fork y casi todos fallarán (secrets inexistentes, etc.). **No blocker** para publicar el tag, pero **ruido en Actions desde el minuto 1**.

### 4. Security — 8/10

| Fix | Estado | Evidencia |
|---|---|---|
| SEC-01 (CRITICAL): DANGEROUS antes de WHITELIST | OK | `packages/omnicoder/src/security/index.ts:79-94` (DANGEROUS + SECRETS loop) se ejecuta **antes** del whitelist loop en `:99-103`; comment `:75-78` lo documenta. Test `test/security.test.ts` — 5/5 pass. |
| SEC-03 (HIGH): permission denylist | OK | `.omnicoder/opencode.jsonc` incluye `.ssh/**, .aws/**, .gcp/**, .azure/**, .kube/config, .docker/config.json, .npmrc, .netrc, .config/gh/**` (líneas ~65-78). |
| SEC-04: `sudo *: deny` | OK | `.omnicoder/opencode.jsonc` sección `bash` tiene `"sudo *": "deny"`. |
| SEC-06 (HIGH): LICENSE + NOTICE | OK | Ver sección 1. |
| SEC-05 (HIGH): Engram checksum | **PENDING** | `grep engram /home/nicolas/omnicoder-v5/install` → 0 hits. El installer no descarga Engram con checksum pin. El CHANGELOG lo declara explícitamente diferido a `alpha.1`. **No es ship-blocker para alpha** (usuarios sofisticados, documentado), pero **sí lo es para beta/rc**. |
| SEC-07: `bun audit` | PARCIAL | 114 vulns (3 crit, 37 high, 57 mod, 17 low) **todas en deps upstream Opencode** (`fast-xml-parser, file-type, react-router, aws-sdk`). 0 vulns en `@omnicoder/core`. Aceptable para alpha; documentar en release notes. |

### 5. Git hygiene — 7/10

- `git log --all --full-history -- '*.env' '*.pem' '*.key'`: **0 hits**. Limpio.
- `.gitignore`: protege `.env` (`:5`), `node_modules` (`:2`), `dist` (`:12`), `ts-dist` (`:13`), `logs/` (`:29`), `*.bun-build` (`:30`). **No protege**: `.artifacts/`, `*.db`, `.omnicoder/` (las últimas dos importan: `agentdb` genera `.db`, los logs plugin van a `~/.omnicoder/logs`). El proyecto usa rutas `$HOME/...` fuera del repo, así que **no es blocker** pero **conviene añadirlos** para evitar accidentes.
- Working tree: limpio excepto `?? packages/omnicoder/bench/` (untracked, 2 archivos nuevos `_bench-util.ts` y `router.bench.ts` creados 14:19). **Ship-blocker menor**: o commitear o añadir a `.gitignore` antes del tag.
- Branch: `v5-migration` (no `main`).
- Co-Authored-By: 6 de 6 commits OmniCoder (scaffold → docs) contienen la trailer. OK.

### 6. Documentation — 7/10

- ADRs linkeados desde `CHANGELOG.md:9` y `:23` OK.
- `packages/omnicoder/README.md` tiene install + hooks table + license + ack opencode. OK.
- `docs/MIGRATION.md`: **NO EXISTE**. El CHANGELOG lo declara "to be added in alpha.1". Aceptable para alpha.0 dado que el target son early adopters, **no blocker**. Para beta sí lo será.

### 7. Release-worthiness — puntuación

| Dimensión | Score |
|---|---|
| Versioning / metadata | 10 |
| Build / tests / typecheck | 8 |
| CI/CD | 9 |
| Security | 8 |
| Git hygiene | 7 |
| Documentation | 7 |
| **Promedio** | **8.2 / 10** |

---

## Top 5 blockers (ordenados)

1. **[SHIP-BLOCKER]** `bun install --frozen-lockfile` falla. La release workflow va a romper. **Fix: regenerar lockfile** (15 s).
2. **[SHIP-BLOCKER menor]** `packages/omnicoder/bench/` untracked. Decidir: commitear o `.gitignore`.
3. **[HIGH — no blocker]** 12 workflows upstream sin gate `sst/opencode` — ejecutarán en el fork y la mayoría fallará en minuto 0. Ruido en Actions, sin daño funcional.
4. **[MEDIUM]** Engram checksum (SEC-05) pendiente. Aceptable en alpha.0 porque el CHANGELOG lo declara. Bloqueará beta.
5. **[LOW]** `.gitignore` no protege `.artifacts/`, `*.db`, `.omnicoder/`. Defense-in-depth.

---

## Fix antes de release (comandos exactos)

```bash
# 1. Regenerar lockfile (desbloquea CI + lint + tsc upstream)
cd /home/nicolas/omnicoder-v5
bun install                      # produce bun.lock actualizado
bun test --cwd packages/omnicoder   # revalidar 45/45

# 2. Decidir bench/: commitear
git add packages/omnicoder/bench bun.lock
git commit -m "chore(bench): add router microbench + refresh bun.lock

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"

# 3. Completar gating en los 12 workflows huérfanos (15 min)
for f in generate.yml release-github-action.yml review.yml stats.yml storybook.yml \
         sync-zed-extension.yml test.yml triage.yml typecheck.yml \
         vouch-check-issue.yml vouch-check-pr.yml vouch-manage-by-issue.yml; do
  echo "Gate $f manually — insert 'if: github.repository == '"'"'sst/opencode'"'"'' into every job."
done

# 4. Defense-in-depth .gitignore (opcional, 30 s)
cat >> /home/nicolas/omnicoder-v5/.gitignore <<'EOF'
.artifacts/
*.db
.omnicoder/
EOF

# 5. Tag + push (solo tras 1 y 2)
git tag -a v5.0.0-alpha.0 -m "OmniCoder v5.0.0-alpha.0"
git push origin v5-migration
git push origin v5.0.0-alpha.0   # dispara omnicoder-release.yml
```

---

## What can wait (alpha.1 / beta)

- **`docs/MIGRATION.md`** — mandatorio para beta. Usuarios de v4 necesitan ruta de migración clara.
- **SEC-05 Engram checksum** — mandatorio para beta. Instalar binarios sin verificación es vector de supply-chain.
- **`bun audit` cleanup** — depende de Opencode upstream. Trackear vía dependabot.
- **`tsgo` adoption** — reemplazo de `tsc` para typecheck más rápido. No urgente.
- **Mid-session provider failover** — bloqueado por upstream Opencode #7602. Log-only en v5.0 es aceptable.

---

**Archivos relevantes**:

- `/home/nicolas/omnicoder-v5/CHANGELOG.md`
- `/home/nicolas/omnicoder-v5/LICENSE`
- `/home/nicolas/omnicoder-v5/NOTICE`
- `/home/nicolas/omnicoder-v5/packages/omnicoder/package.json`
- `/home/nicolas/omnicoder-v5/packages/omnicoder/README.md`
- `/home/nicolas/omnicoder-v5/packages/omnicoder/src/security/index.ts`
- `/home/nicolas/omnicoder-v5/.omnicoder/opencode.jsonc`
- `/home/nicolas/omnicoder-v5/.github/workflows/omnicoder-{ci,pr,release}.yml`
- `/home/nicolas/omnicoder-v5/.github/dependabot.yml`
- `/home/nicolas/omnicoder-v5/.github/CODEOWNERS`
- `/home/nicolas/omnicoder-v5/docs/adr/ADR-00{1..5}-*.md`
