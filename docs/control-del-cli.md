# Control del CLI — cómo tocar cualquier parte del fork

OmniCoder v5 es un **fork directo** de `sst/opencode`. Eso significa que
tenés el código completo y podés modificar cualquier pieza sin depender
de wrappers externos. Este documento es tu mapa.

---

## 1 · Arquitectura del repo

```
omnicoder-v5/
├── bin/                          ← wrappers CLI POSIX/Windows (tuyos)
│   ├── omnicoder                 sh (Linux/macOS)
│   ├── omnicoder.cmd             cmd (Windows)
│   └── omnicoder.ps1             PowerShell (la lógica real en Windows)
│
├── packages/
│   ├── opencode/                 ← base upstream (sst/opencode) — MIT
│   │   ├── src/                  código del CLI + TUI + server
│   │   └── bin/opencode          binary entrypoint del core
│   │
│   └── omnicoder/                ← TU plugin TypeScript (MIT)
│       ├── src/
│       │   ├── router/           skill router (BM25 + bigramas)
│       │   ├── security/         guard de bash + secrets
│       │   ├── memory/           lector de ~/.omnicoder/memory/
│       │   ├── budget/           JSONL + rolling alert
│       │   ├── hooks/            tool-dispatcher, provider-failover
│       │   └── index.ts          registro de hooks en Opencode
│       ├── bench/                micro-benchmarks (router/security/full)
│       └── test/                 45 tests (21 unit + 24 integration)
│
├── .opencode/
│   ├── agent/                    167 agentes (ported de v4)
│   └── skills/                   193 skills (ported de v4)
│
├── docs/
│   ├── adr/ADR-001..005          architectural decisions
│   ├── MIGRATION.md              v4 → v5 guide
│   ├── hackathon-quickstart.md   5-min onboarding
│   ├── control-del-cli.md        este archivo
│   └── qa/                       QA reports
│
├── scripts/
│   ├── install.sh                installer Linux/macOS con SEC-05
│   ├── install-windows.ps1       idem Windows
│   ├── port-v4-assets.ts         script one-shot de migración v4
│   └── …
│
├── .github/workflows/
│   ├── omnicoder-ci.yml          3-OS test + typecheck + bun install
│   ├── omnicoder-release.yml     tag v*.*.* → release artifact
│   └── omnicoder-pr.yml          PR gate (CHANGELOG obligatorio)
│
└── specs/ , flake.nix , sst.config.ts , turbo.json , etc.
```

Marker convention: cada patch al código upstream lleva `// OMNICODER:` en
la línea antes del cambio, para que `git merge upstream/dev` los detecte
de inmediato.

---

## 2 · Cambiar el nombre del comando

El binario del fork se llama `omnicoder`. El core sigue llamándose
`opencode` (para minimizar merge conflicts con upstream). Si querés
renombrar el core también:

```bash
# 1. renombra el binary entry
mv packages/opencode/bin/opencode packages/opencode/bin/omnicoder-core

# 2. actualiza package.json
# packages/opencode/package.json → bin: { "omnicoder-core": "./bin/omnicoder-core" }

# 3. en bin/omnicoder (sh) reemplazá las llamadas a `opencode` con `omnicoder-core`
sed -i 's/opencode/omnicoder-core/g' bin/omnicoder bin/omnicoder.ps1

# 4. reinstalá
bun install
bash scripts/install.sh --yes
```

Vas a tener que resolver el merge cuando sinques con upstream — por eso
lo dejamos sin renombrar por default.

---

## 3 · Agregar un subcomando propio

Ejemplo: `omnicoder deploy` que empaqueta y sube tus skills a tu bucket.

**Paso 1 — lógica en TypeScript**

```ts
// packages/omnicoder/src/cli/deploy.ts
export async function runDeploy(args: string[]) {
  const bucket = process.env.OMNI_S3_BUCKET ?? "omnicoder-team"
  // … tu lógica con @aws-sdk/client-s3 o similar
  console.log(`deployed ${args.length} skills to s3://${bucket}`)
}
```

**Paso 2 — registrar en el wrapper shell**

```sh
# bin/omnicoder, después del `case` de doctor:
deploy)
  shift
  exec bun run \
    --cwd "$(omnicoder_script_dir)/../packages/omnicoder" \
    src/cli/deploy.ts "$@"
  ;;
```

**Paso 3 — idem Windows**

```powershell
# bin/omnicoder.ps1
'deploy' {
  & bun run --cwd "$RepoRoot\packages\omnicoder" `
    src\cli\deploy.ts @RemainingArgs
  exit $LASTEXITCODE
}
```

**Paso 4 — tests**

```ts
// packages/omnicoder/test/cli-deploy.test.ts
import { test, expect } from "bun:test"
import { runDeploy } from "../src/cli/deploy.ts"

test("deploy uses default bucket when env missing", async () => {
  // …
})
```

---

## 4 · Modificar el comportamiento del core Opencode

Tres enfoques, de menor a mayor riesgo:

### 4.1 · Plugin hook (preferido)

El API de `@opencode-ai/plugin` expone eventos que podés interceptar sin
tocar código upstream:

```ts
// packages/omnicoder/src/hooks/mi-hook.ts
export const createMiHook = (input: PluginInput) => ({
  async onChatMessage(msg) {
    // tu lógica
  }
})
```

Registralo en `packages/omnicoder/src/index.ts`.

### 4.2 · Monkey-patch con marker

Si el plugin API no expone lo que necesitás, editá el código upstream y
marcá el cambio:

```ts
// packages/opencode/src/cli/run.ts
// OMNICODER: custom greeting
console.log(process.env.OMNICODER ? "OmniCoder v5" : "opencode")
```

Cuando hagas `omnicoder sync-upstream`, los conflictos sobre estas líneas
son inmediatos.

### 4.3 · Fork divergente

Si renombrás el binary, cambiás la config schema o rompés API — aceptá
que la rama `dev` deja de ser mergeable. Mantené una rama `upstream-sync`
separada que traiga cambios quirúrgicos a mano.

---

## 5 · Cambiar branding (banner, colores, mensaje de bienvenida)

```sh
# bin/omnicoder — busca maybe_show_banner()
maybe_show_banner() {
  if [ -f "$OMNICODER_BANNER_FLAG" ]; then return 0; fi
  cat <<'EOF'
   ____                  _ _____          _
  / __ \____ ___  ____ (_)_   _|__  ___ ( )___ _ _ __
 / / / / __ `__ \/ __ \/ / | |/ -_)/ _ \|// -_) '_/
/ /_/ / / / / / / / / / /  |_|\__\\___/  \__/_|
\____/_/ /_/ /_/_/ /_/_/       OmniCoder v5
EOF
  mkdir -p "$OMNICODER_HOME"
  touch "$OMNICODER_BANNER_FLAG"
}
```

El banner en Windows vive en `bin/omnicoder.ps1` bajo `Show-Banner`.

---

## 6 · Agregar un provider nuevo

Los providers se declaran en `opencode.jsonc`. Para integrar un provider
que no está en el schema upstream, agregalo en
`packages/omnicoder/src/router/providers/<mi-provider>.ts` y registralo
en el hook `chat.params`. Ver `packages/omnicoder/src/hooks/provider-failover.ts`
para el patrón completo.

---

## 7 · Sincronizar con upstream sin romper tu trabajo

```bash
# Actualizar la rama `dev` que trackea sst/opencode
git checkout dev
git fetch upstream
git merge upstream/dev

# Traer cambios a `main` (tu rama)
git checkout main
git merge dev
# resolver conflictos (buscá líneas con `// OMNICODER:`)

# Correr tests
bun install --frozen-lockfile
bun run --cwd packages/omnicoder typecheck
bun run --cwd packages/omnicoder test

# Subir
git push origin main
```

Alternativa: `omnicoder sync-upstream` automatiza estos pasos y te muestra
los conflictos en un resumen.

---

## 8 · Lanzar una nueva versión

```bash
# 1. editá CHANGELOG.md
# 2. bump manual de packages/omnicoder/package.json → "version"
# 3. tag
git tag -a v5.0.0-beta.0 -m "beta.0 — motivo"
git push origin v5.0.0-beta.0
# 4. el workflow omnicoder-release.yml publica el release
```

---

## 9 · Contribuciones de terceros

Ver `CONTRIBUTING.md`. Política:

- PR contra `main`. Nunca contra `dev` (esa es nuestra mirror con
  upstream).
- **CHANGELOG obligatorio** — el workflow `omnicoder-pr.yml` lo gatea.
- 1 review + CI verde + sin secrets = merge.

---

## 10 · Cuándo NO tocar el código upstream

Si la funcionalidad cabe como plugin, no la hardcodees. Los tres casos
donde SÍ hay que tocar upstream:

1. Strings de branding visibles al usuario (tres o cuatro líneas).
2. Flags CLI que no son agregables vía plugin (muy raro).
3. Permisos que querés denegar by default a nivel runtime (ver
   `packages/opencode/src/permission/`).

Todo lo demás (routing, memoria, seguridad, providers, telemetría) vive
en `packages/omnicoder/` y no toca una línea de upstream.
