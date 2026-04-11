#!/usr/bin/env bash
# ============================================================
# Qwen Con Poderes v2 - Desinstalador para Linux/macOS
# ============================================================
set -euo pipefail

echo ""
echo "=== Qwen Con Poderes v2 - Desinstalador ==="
echo ""
echo "Esto eliminara:"
echo "  - Todos los agentes de ~/.qwen/agents/"
echo "  - Todas las skills de ~/.qwen/skills/"
echo "  - Todos los hooks de ~/.qwen/hooks/"
echo "  - Todos los commands de ~/.qwen/commands/"
echo "  - El archivo QWEN.md de ~/.qwen/"
echo "  - Los logs de ~/.qwen/logs/"
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

[[ -d "$HOME/.qwen/agents" ]] && rm -rf "$HOME/.qwen/agents" && echo "  OK Agentes eliminados"
[[ -d "$HOME/.qwen/skills" ]] && rm -rf "$HOME/.qwen/skills" && echo "  OK Skills eliminadas"
[[ -d "$HOME/.qwen/hooks" ]] && rm -rf "$HOME/.qwen/hooks" && echo "  OK Hooks eliminados"
[[ -d "$HOME/.qwen/commands" ]] && rm -rf "$HOME/.qwen/commands" && echo "  OK Commands eliminados"
[[ -f "$HOME/.qwen/QWEN.md" ]] && rm "$HOME/.qwen/QWEN.md" && echo "  OK QWEN.md eliminado"
[[ -d "$HOME/.qwen/logs" ]] && rm -rf "$HOME/.qwen/logs" && echo "  OK Logs eliminados"

# Limpiar hooks de settings.json si jq disponible
if command -v jq &>/dev/null && [[ -f "$HOME/.qwen/settings.json" ]]; then
    if jq 'del(.hooks)' "$HOME/.qwen/settings.json" > "$HOME/.qwen/settings.json.tmp" 2>/dev/null; then
        mv "$HOME/.qwen/settings.json.tmp" "$HOME/.qwen/settings.json"
        echo "  OK Hooks removidos de settings.json"
    fi
fi

echo ""
echo "Desinstalacion completada."
echo "Para desinstalar Qwen Code CLI: npm uninstall -g @qwen-code/qwen-code"
