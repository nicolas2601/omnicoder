#!/usr/bin/env bash
# ============================================================
# Qwen Con Poderes - Skill Router (UserPromptSubmit)
# Auto-detecta intent del usuario y sugiere skills relevantes
# ============================================================
set -euo pipefail

INPUT=$(cat)

PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // ""' 2>/dev/null || echo "")
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

SUGGESTION=""

# Patrones de routing por dominio
if echo "$PROMPT_LOWER" | grep -qE '(review|revisa|code review|pr review)'; then
    SUGGESTION="Tip: Usa /skills code-review o /skills comprehensive-review para un review estructurado P0-P3"
elif echo "$PROMPT_LOWER" | grep -qE '(test|testing|prueba|coverage)'; then
    SUGGESTION="Tip: Agentes disponibles: testing-api-tester, testing-performance-benchmarker, testing-accessibility-auditor"
elif echo "$PROMPT_LOWER" | grep -qE '(seo|posicionamiento|search engine)'; then
    SUGGESTION="Tip: Usa /skills audit-website o /skills marketing-seo-specialist para SEO completo"
elif echo "$PROMPT_LOWER" | grep -qE '(deploy|ci.?cd|pipeline|github action)'; then
    SUGGESTION="Tip: Usa /skills github-actions-templates o agente engineering-devops-automator"
elif echo "$PROMPT_LOWER" | grep -qE '(ui|ux|diseno|interfaz|componente|frontend)'; then
    SUGGESTION="Tip: Usa /skills ui-ux-pro-max o agentes design-ui-designer, design-ux-architect"
elif echo "$PROMPT_LOWER" | grep -qE '(mobile|react native|expo|ios|android)'; then
    SUGGESTION="Tip: Usa /skills react-native-best-practices o agente engineering-mobile-app-builder"
elif echo "$PROMPT_LOWER" | grep -qE '(security|seguridad|vulnerab|audit)'; then
    SUGGESTION="Tip: Agentes: engineering-security-engineer, blockchain-security-auditor, compliance-auditor"
elif echo "$PROMPT_LOWER" | grep -qE '(performance|rendimiento|optimiz|lento|slow)'; then
    SUGGESTION="Tip: Agentes: testing-performance-benchmarker, engineering-database-optimizer"
elif echo "$PROMPT_LOWER" | grep -qE '(api|backend|servidor|microservic)'; then
    SUGGESTION="Tip: Usa agente engineering-backend-architect o engineering-software-architect"
elif echo "$PROMPT_LOWER" | grep -qE '(game|juego|unity|unreal|godot)'; then
    SUGGESTION="Tip: Agentes disponibles: unity-architect, unreal-systems-engineer, godot-gameplay-scripter, game-designer"
elif echo "$PROMPT_LOWER" | grep -qE '(marketing|content|redes social|tiktok|instagram|linkedin)'; then
    SUGGESTION="Tip: Agentes de marketing: marketing-content-creator, marketing-growth-hacker, marketing-tiktok-strategist"
elif echo "$PROMPT_LOWER" | grep -qE '(venta|sales|propuesta|rfp|pipeline)'; then
    SUGGESTION="Tip: Agentes: sales-engineer, sales-deal-strategist, sales-proposal-strategist"
fi

if [[ -n "$SUGGESTION" ]]; then
    jq -n --arg suggestion "$SUGGESTION" '{
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": $suggestion
        }
    }'
else
    echo '{}'
fi
