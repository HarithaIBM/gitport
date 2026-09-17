#!/bin/bash
# Script to check iconv_translit configuration

echo "=========================================="
echo "  Git iconv_translit Configuration Check"
echo "=========================================="
echo ""

echo "1. Environment Variable:"
echo "   GIT_ICONV_TRANSLIT = ${GIT_ICONV_TRANSLIT:-<not set>}"
echo ""

echo "2. Git Config (repository):"
CONFIG_REPO=$(git config --local --get core.iconvtranslit 2>/dev/null)
echo "   core.iconvtranslit = ${CONFIG_REPO:-<not set>}"
echo ""

echo "3. Git Config (global):"
CONFIG_GLOBAL=$(git config --global --get core.iconvtranslit 2>/dev/null)
echo "   core.iconvtranslit = ${CONFIG_GLOBAL:-<not set>}"
echo ""

echo "4. Git Config (system):"
CONFIG_SYSTEM=$(git config --system --get core.iconvtranslit 2>/dev/null)
echo "   core.iconvtranslit = ${CONFIG_SYSTEM:-<not set>}"
echo ""

echo "5. Effective Value (what Git will use):"
if [ -n "$GIT_ICONV_TRANSLIT" ]; then
    echo "   Environment variable takes precedence: $GIT_ICONV_TRANSLIT"
elif [ -n "$CONFIG_REPO" ]; then
    echo "   Repository config: $CONFIG_REPO"
elif [ -n "$CONFIG_GLOBAL" ]; then
    echo "   Global config: $CONFIG_GLOBAL"
elif [ -n "$CONFIG_SYSTEM" ]; then
    echo "   System config: $CONFIG_SYSTEM"
else
    echo "   <not set - defaults to disabled>"
fi
echo ""

echo "6. All iconv-related configs:"
git config --list 2>/dev/null | grep -i iconv || echo "   <none found>"
echo ""

echo "=========================================="
echo "To enable iconv translit:"
echo "  export GIT_ICONV_TRANSLIT=1"
echo "  or"
echo "  git config --global core.iconvtranslit true"
echo "=========================================="

