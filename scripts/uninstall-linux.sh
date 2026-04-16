#!/usr/bin/env bash
# ============================================================
# OmniCoder v4.2 - Desinstalador para Linux/macOS
# ============================================================
set -euo pipefail

echo ""
echo "=== OmniCoder v4.2 - Desinstalador ==="
echo ""
echo "Esto eliminara:"
echo "  - Todos los agentes de ~/.omnicoder/agents/"
echo "  - Todas las skills de ~/.omnicoder/skills/"
echo "  - Todos los hooks de ~/.omnicoder/hooks/"
echo "  - Todos los commands de ~/.omnicoder/commands/"
echo "  - El archivo OMNICODER.md de ~/.omnicoder/"
echo "  - Los logs de ~/.omnicoder/logs/"
echo ""
echo "NO eliminara:"
echo "  - Qwen Code CLI"
echo "  - settings.json (tiene tu configuracion personal)"
echo "  - Tus handoff documents"
echo ""
read -p "Continuar? (s/n): " confirm

if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
    echo "Cancelado."
    exit 0
fi

[[ -d "$HOME/.omnicoder/agents" ]] && rm -rf "$HOME/.omnicoder/agents" && echo "  OK Agentes eliminados"
[[ -d "$HOME/.omnicoder/skills" ]] && rm -rf "$HOME/.omnicoder/skills" && echo "  OK Skills eliminadas"
[[ -d "$HOME/.omnicoder/hooks" ]] && rm -rf "$HOME/.omnicoder/hooks" && echo "  OK Hooks eliminados"
[[ -d "$HOME/.omnicoder/commands" ]] && rm -rf "$HOME/.omnicoder/commands" && echo "  OK Commands eliminados"
[[ -f "$HOME/.omnicoder/OMNICODER.md" ]] && rm "$HOME/.omnicoder/OMNICODER.md" && echo "  OK OMNICODER.md eliminado"
[[ -d "$HOME/.omnicoder/logs" ]] && rm -rf "$HOME/.omnicoder/logs" && echo "  OK Logs eliminados"

# Limpiar hooks de settings.json si jq disponible
if command -v jq &>/dev/null && [[ -f "$HOME/.omnicoder/settings.json" ]]; then
    if jq 'del(.hooks)' "$HOME/.omnicoder/settings.json" > "$HOME/.omnicoder/settings.json.tmp" 2>/dev/null; then
        mv "$HOME/.omnicoder/settings.json.tmp" "$HOME/.omnicoder/settings.json"
        echo "  OK Hooks removidos de settings.json"
    fi
fi

echo ""
echo "Desinstalacion completada."
echo "Para desinstalar OmniCoder CLI: npm uninstall -g @qwen-code/qwen-code"
