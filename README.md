# Qwen Con Poderes

**168 agentes especializados + 193 skills** para [Qwen Code CLI](https://github.com/QwenLM/qwen-code) — convierte tu terminal en un ejército de expertos en IA.

> Qwen Code es un agente de IA open-source para terminal, optimizado para los modelos Qwen de Alibaba. Con este repo le agregas **superpoderes**: 168 agentes especializados y 193 skills que cubren desarrollo, diseño, marketing, ventas, testing, gaming, y mucho más.

---

## Instalación rápida

### Requisitos previos

- **Node.js v20+** — [descargar](https://nodejs.org)
- **Git** — [descargar](https://git-scm.com)

### Linux / macOS

```bash
# 1. Clonar el repo
git clone https://github.com/nicolas2601/qwen-con-poderes-.git
cd qwen-con-poderes-

# 2. Ejecutar instalador (instala Qwen CLI + agentes + skills)
chmod +x scripts/install-linux.sh
./scripts/install-linux.sh
```

### Windows (CMD)

```cmd
REM 1. Clonar el repo
git clone https://github.com/nicolas2601/qwen-con-poderes-.git
cd qwen-con-poderes-

REM 2. Ejecutar instalador
scripts\install-windows.bat
```

### Windows (PowerShell)

```powershell
# 1. Clonar el repo
git clone https://github.com/nicolas2601/qwen-con-poderes-.git
cd qwen-con-poderes-

# 2. Ejecutar instalador
.\scripts\install-windows.ps1
```

---

## Qué se instala

| Componente | Cantidad | Ubicación |
|---|---|---|
| Qwen Code CLI | 1 | Global (npm) |
| SubAgentes | 168 | `~/.qwen/agents/` |
| Skills | 193 | `~/.qwen/skills/` |
| Config global | 1 | `~/.qwen/QWEN.md` |

---

## Cómo usar

### Iniciar Qwen Code

```bash
qwen
```

La primera vez te pedirá autenticarte con `/auth`. Puedes usar:
- **Qwen OAuth** (1,000 requests/día gratis)
- **API key** de Alibaba Cloud ModelStudio
- Cualquier API compatible con OpenAI/Anthropic/Gemini

### Ver y usar agentes

```bash
# Dentro de Qwen Code:
/agents manage          # Ver todos los agentes disponibles
/agents create          # Crear uno nuevo

# Usar agente en una conversación:
> Usa el agente engineering-backend-architect para diseñar mi API
```

### Ver y usar skills

```bash
# Dentro de Qwen Code:
/skills engineering-backend-architect    # Invocar skill directamente

# O simplemente pregunta — Qwen selecciona la skill automáticamente:
> Diseña la arquitectura de mi aplicación mobile
# → Activa automáticamente engineering-mobile-app-builder
```

---

## Catálogo de agentes (168)

### Academic (5)
| Agente | Descripción |
|---|---|
| `academic-anthropologist` | Antropólogo cultural |
| `academic-geographer` | Geógrafo físico y humano |
| `academic-historian` | Historiador y analista |
| `academic-narratologist` | Teoría narrativa y estructura |
| `academic-psychologist` | Comportamiento humano y cognitivo |

### Design (8)
| Agente | Descripción |
|---|---|
| `design-brand-guardian` | Estrategia y guardianismo de marca |
| `design-image-prompt-engineer` | Prompts de fotografía e imagen |
| `design-inclusive-visuals-specialist` | Representación inclusiva |
| `design-ui-designer` | Diseño UI, sistemas de componentes |
| `design-ux-architect` | Arquitectura UX y CSS systems |
| `design-ux-researcher` | Investigación UX y usabilidad |
| `design-visual-storyteller` | Narrativa visual |
| `design-whimsy-injector` | Personalidad y delight en UI |

### Engineering (27)
| Agente | Descripción |
|---|---|
| `engineering-ai-engineer` | ML/AI models y deployment |
| `engineering-backend-architect` | Arquitectura backend escalable |
| `engineering-cms-developer` | Drupal/WordPress |
| `engineering-code-reviewer` | Code review constructivo |
| `engineering-data-engineer` | Data pipelines y lakehouse |
| `engineering-database-optimizer` | Schema, queries, indexing |
| `engineering-devops-automator` | Infrastructure y CI/CD |
| `engineering-embedded-firmware-engineer` | ESP32, PlatformIO, RTOS |
| `engineering-frontend-developer` | React/Vue/Angular |
| `engineering-git-workflow-master` | Git workflows y branching |
| `engineering-incident-response-commander` | Gestión de incidentes |
| `engineering-mobile-app-builder` | iOS/Android nativo y cross-platform |
| `engineering-rapid-prototyper` | MVPs ultra-rápidos |
| `engineering-security-engineer` | AppSec, threat modeling |
| `engineering-senior-developer` | Laravel/Livewire/Three.js |
| `engineering-software-architect` | DDD, system design |
| `engineering-solidity-smart-contract-engineer` | Smart contracts EVM |
| `engineering-sre` | SRE, SLOs, observabilidad |
| `engineering-technical-writer` | Documentación técnica |
| ...y más |

### Game Development (20)
| Agente | Descripción |
|---|---|
| `blender-addon-engineer` | Blender Python add-ons |
| `game-designer` | Mecánicas, GDD, player psychology |
| `godot-gameplay-scripter` | GDScript 2.0, C# en Godot |
| `unity-architect` | ScriptableObjects, DI en Unity |
| `unreal-systems-engineer` | C++/Blueprint en UE |
| `narrative-designer` | Narrativa y diálogos |
| `level-designer` | Level design y pacing |
| ...y más (Roblox, shaders, multiplayer, VFX) |

### Marketing (29)
| Agente | Descripción |
|---|---|
| `marketing-content-creator` | Contenido multi-plataforma |
| `marketing-growth-hacker` | Growth hacking |
| `marketing-seo-specialist` | SEO técnico y contenido |
| `marketing-tiktok-strategist` | TikTok viral content |
| `marketing-instagram-curator` | Instagram marketing |
| `marketing-linkedin-content-creator` | LinkedIn thought leadership |
| `marketing-twitter-engager` | Twitter engagement |
| `marketing-reddit-community-builder` | Reddit engagement |
| ...y más (YouTube, Douyin, Xiaohongshu, WeChat, etc.) |

### Paid Media (7)
`paid-media-auditor`, `paid-media-creative-strategist`, `paid-media-ppc-strategist`, `paid-media-programmatic-buyer`, `paid-media-tracking-specialist`, ...

### Product (5)
`product-manager`, `product-feedback-synthesizer`, `product-sprint-prioritizer`, `product-trend-researcher`, `product-behavioral-nudge-engine`

### Project Management (6)
`project-manager-senior`, `project-management-jira-workflow-steward`, `project-management-project-shepherd`, ...

### Sales (8)
`sales-coach`, `sales-deal-strategist`, `sales-discovery-coach`, `sales-engineer`, `sales-outbound-strategist`, `sales-pipeline-analyst`, `sales-proposal-strategist`, `sales-account-strategist`

### Spatial Computing (6)
`visionos-spatial-engineer`, `xr-immersive-developer`, `xr-interface-architect`, `macos-spatial-metal-engineer`, ...

### Specialized (30)
`blockchain-security-auditor`, `compliance-auditor`, `recruitment-specialist`, `specialized-civil-engineer`, `specialized-mcp-builder`, `specialized-salesforce-architect`, `supply-chain-strategist`, ...

### Support (6)
`support-analytics-reporter`, `support-finance-tracker`, `support-legal-compliance-checker`, `support-support-responder`, ...

### Testing (8)
`testing-accessibility-auditor`, `testing-api-tester`, `testing-performance-benchmarker`, `testing-reality-checker`, `testing-workflow-optimizer`, ...

---

## Estructura del repo

```
qwen-con-poderes/
├── README.md                    # Este archivo
├── QWEN.md                     # Config global (se copia a ~/.qwen/)
├── .gitignore
├── agents/                      # 168 archivos .md de subagentes
│   ├── engineering-backend-architect.md
│   ├── design-ui-designer.md
│   ├── marketing-tiktok-strategist.md
│   └── ...
├── skills/                      # 193 carpetas de skills
│   ├── engineering-backend-architect/
│   │   └── SKILL.md
│   ├── code-review/
│   │   └── SKILL.md
│   └── ...
└── scripts/
    ├── install-linux.sh         # Instalador Linux/macOS
    ├── install-windows.bat      # Instalador Windows (CMD)
    ├── install-windows.ps1      # Instalador Windows (PowerShell)
    └── uninstall-linux.sh       # Desinstalador
```

---

## Instalación manual (sin scripts)

Si prefieres instalar manualmente:

```bash
# 1. Instalar Qwen Code CLI
npm install -g @qwen-code/qwen-code@latest

# 2. Copiar agentes
mkdir -p ~/.qwen/agents
cp agents/*.md ~/.qwen/agents/

# 3. Copiar skills
mkdir -p ~/.qwen/skills
cp -r skills/* ~/.qwen/skills/

# 4. Copiar configuración global
cp QWEN.md ~/.qwen/QWEN.md

# 5. Iniciar Qwen
qwen
```

---

## Desinstalar

### Linux/macOS
```bash
./scripts/uninstall-linux.sh
```

### Manual
```bash
rm -rf ~/.qwen/agents ~/.qwen/skills ~/.qwen/QWEN.md
# Para desinstalar Qwen Code CLI:
npm uninstall -g @qwen-code/qwen-code
```

---

## Crear tus propios agentes

Los agentes son archivos `.md` con frontmatter YAML:

```markdown
---
name: mi-agente-custom
description: "Descripción de lo que hace el agente"
color: blue
---

# Mi Agente Custom

Eres un experto en [dominio]. Tu misión es...

## Instrucciones
1. Siempre haz X
2. Nunca hagas Y
3. Prioriza Z
```

Guarda el archivo en `~/.qwen/agents/mi-agente-custom.md` y reinicia Qwen.

---

## Crear tus propias skills

Las skills son carpetas con un `SKILL.md`:

```bash
mkdir -p ~/.qwen/skills/mi-skill
```

```markdown
---
name: mi-skill
description: "Mi skill personalizada para [tarea]"
---

# Mi Skill

## Instrucciones
...
```

---

## FAQ

**¿Necesito Claude Code para usar esto?**
No. Este repo funciona 100% con Qwen Code CLI, sin necesidad de Claude Code ni cuenta de Anthropic.

**¿Es gratis?**
Sí. Qwen Code ofrece 1,000 requests/día gratis con OAuth. Los agentes y skills son archivos de texto locales.

**¿Puedo usar otros modelos?**
Sí. Qwen Code soporta APIs compatibles con OpenAI, Anthropic y Gemini. Configura tu API key en `/auth`.

**¿Cómo actualizo los agentes?**
```bash
cd qwen-con-poderes-
git pull
./scripts/install-linux.sh  # Re-ejecutar instalador
```

---

## Créditos

- [Qwen Code](https://github.com/QwenLM/qwen-code) — El CLI base de Alibaba/Qwen
- [Agency Agents](https://github.com/your-repo) — Los 179 agentes especializados originales
- Creado por [@nicolas2601](https://github.com/nicolas2601)

---

## Licencia

MIT
