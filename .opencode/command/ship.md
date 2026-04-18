---
name: ship
description: "Pre-flight check completo antes de hacer push: tests, lint, review, commit y push. Todo en un solo comando."
---

# Ship - Pre-flight & Deploy

Ejecuta el pipeline completo de ship:

## Pipeline (ejecutar en orden)

### 1. Verificar estado limpio
```bash
git status
git diff --stat
```

### 2. Ejecutar tests
Busca y ejecuta el comando de test del proyecto:
- `npm test` / `pnpm test` / `bun test` (Node.js)
- `pytest` / `python -m pytest` (Python)
- `cargo test` (Rust)
- `go test ./...` (Go)

Si los tests fallan, DETENTE y reporta los errores. No continuar.

### 3. Ejecutar linter (si existe)
- `npm run lint` / `pnpm lint` (Node.js)
- `ruff check .` / `flake8` (Python)
- `cargo clippy` (Rust)

### 4. Review rapido del diff
Ejecuta un review express P0-P1 del diff. Si hay issues P0, DETENTE.

### 5. Commit
- Analiza los cambios para generar un mensaje descriptivo
- Usa commits convencionales: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`
- Incluye scope si aplica: `feat(auth): add JWT refresh token`

### 6. Push
```bash
git push origin HEAD
```

### 7. Reporte final
```
## Ship Report
- Tests: PASS/FAIL
- Lint: PASS/FAIL/SKIP
- Review: PASS (0 P0, 0 P1)
- Commit: [hash] [mensaje]
- Push: OK -> origin/[branch]
```
