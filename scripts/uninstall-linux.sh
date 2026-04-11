#!/usr/bin/env bash
# ============================================================
# Qwen Con Poderes - Desinstalador para Linux/macOS
# Elimina agentes y skills (NO desinstala Qwen Code CLI)
# ============================================================
set -euo pipefail

echo ""
echo "=== Qwen Con Poderes - Desinstalador ==="
echo ""
echo "Esto eliminará:"
echo "  - Todos los agentes custom de ~/.qwen/agents/"
echo "  - Todas las skills custom de ~/.qwen/skills/"
echo "  - El archivo QWEN.md de ~/.qwen/"
echo ""
echo "NO desinstalará Qwen Code CLI."
echo ""
read -p "¿Continuar? (s/n): " confirm

if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
    echo "Cancelado."
    exit 0
fi

# Eliminar agentes
if [[ -d "$HOME/.qwen/agents" ]]; then
    rm -rf "$HOME/.qwen/agents"
    echo "  ✓ Agentes eliminados"
fi

# Eliminar skills
if [[ -d "$HOME/.qwen/skills" ]]; then
    rm -rf "$HOME/.qwen/skills"
    echo "  ✓ Skills eliminadas"
fi

# Eliminar QWEN.md
if [[ -f "$HOME/.qwen/QWEN.md" ]]; then
    rm "$HOME/.qwen/QWEN.md"
    echo "  ✓ QWEN.md eliminado"
fi

echo ""
echo "Desinstalación completada."
echo "Para desinstalar Qwen Code CLI: npm uninstall -g @qwen-code/qwen-code"
