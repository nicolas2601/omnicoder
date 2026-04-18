# 06 · Benchmarks y QA

## Suite de tests

- **45 tests totales** distribuidos en 12 archivos.
- 21 unit + 24 integration.
- Runtime total: **< 200 ms** en laptop moderna.
- Runner: `bun test` con timeout 30 s.

```bash
bun install --frozen-lockfile
bun run --cwd packages/omnicoder typecheck
bun run --cwd packages/omnicoder test

# Reporter JUnit (para CI)
bun run --cwd packages/omnicoder test:ci
# escribe packages/omnicoder/.artifacts/unit/junit.xml
```

## CI

Workflow `.github/workflows/omnicoder-ci.yml`:

- **Matriz 3-OS**: Ubuntu · macOS · Windows-latest.
- **Bun `latest`** + cache del install store.
- Steps: `checkout → setup-bun → cache → bun install --frozen-lockfile →
  typecheck → test:ci → upload junit`.
- Gates: PR bloqueado si cualquier OS rompe.

---

## Benchmarks

Directorio: `packages/omnicoder/bench/`.

```
bench/
├── _bench-util.ts              utilidades compartidas
├── router.bench.ts             skill-router ops/sec
├── security.bench.ts           security-guard ops/sec
├── memory.bench.ts             memory-loader ops/sec
├── full-pipeline.bench.ts      pipeline completo router+security+memory
├── run-all.ts                  ejecuta los 4 y escribe resultados
└── results-v5.0.0-alpha.0.json baseline comprimido
```

Ejecución:

```bash
bun run --cwd packages/omnicoder bench/run-all.ts
# escribe bench/results-v5.0.0-<version>.json
```

## Baseline alpha.0

| Caso | p50 | p95 | ops/sec |
|---|---|---|---|
| Router — primer arranque (cold) | 19 ms | 46 ms | — |
| Router — subsiguientes (memoize hit) | 2.3 ms | 4.1 ms | ~435 |
| Security-guard — Read tool (early-exit) | 0.15 ms | 0.42 ms | ~6,500 |
| Security-guard — Bash seguro | 0.62 ms | 1.1 ms | ~1,600 |
| Security-guard — Bash con bypass `&&` | 0.81 ms | 1.5 ms | ~1,230 |
| Memory-loader (Markdown) | 3.2 ms | 7.8 ms | ~310 |
| Pipeline completo (50 tool calls) | 2.0 s total | — | — |

**Comparativa con v4 (baseline Qwen Code + bash hooks)**:

| Caso | v4 | v5 | Δ |
|---|---|---|---|
| 50 tool calls | 12.7 s | 2.0 s | **6.3×** más rápido |
| System prompt + memory | 13.4 KB | 2.2 KB | **-83.6 %** |
| Hooks forks por evento | 6 × bash | 1 × TS | **-6×** overhead |

---

## Cómo correr un bench propio

```ts
// packages/omnicoder/bench/mi-bench.ts
import { bench } from "./_bench-util.js"
import { miFuncion } from "../src/…"

await bench("mi-caso", async () => {
  await miFuncion({ … })
})
```

Agregalo a `run-all.ts` para que entre al reporte.

---

## QA manual pre-release

Checklist que se corre antes de taggear:

- [ ] `bun install --frozen-lockfile` OK (no warnings de peer deps)
- [ ] `bun run --cwd packages/omnicoder typecheck` OK
- [ ] `bun run --cwd packages/omnicoder test` 45/45
- [ ] `bash scripts/install.sh --yes` en clean Ubuntu 22.04 → `omnicoder
      doctor` verde
- [ ] `pwsh scripts/install-windows.ps1 -Yes` en clean Win11 → idem
- [ ] `bash scripts/install.sh --uninstall --yes` deja el sistema limpio
- [ ] Release notes en `CHANGELOG.md` con sección [Unreleased] vaciada
- [ ] `git tag -a v<N>` + `git push origin v<N>` → workflow verde

---

## Reporte de resultados

Cada run de CI sube `junit.xml` como artifact por 14 días:

```
Actions → omnicoder-ci → <run> → Artifacts → omnicoder-junit-<os>
```

Para análisis local:

```bash
ls packages/omnicoder/.artifacts/unit/
# junit.xml
```
