#!/usr/bin/env bash
# ==============================================================================
# Test for git rerere encoding issue
# Tests that rerere-resolved files get correct encoding tags
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Find git binary
if [ -x "$REPO_ROOT/git/git" ]; then
    GIT_BIN="$REPO_ROOT/git/git"
else
    GIT_BIN="$(which git)"
fi

TEST_ROOT="$(pwd)/test_tmp_$$"
mkdir -p "$TEST_ROOT"
trap 'rm -rf "$TEST_ROOT"' EXIT

echo "========================================================================"
echo "               GIT RERERE ENCODING TEST                                "
echo "========================================================================"
echo "Git binary: $("$GIT_BIN" --version) ($GIT_BIN)"
echo "Test root:  $TEST_ROOT"
echo ""

PASSED=0
TOTAL=2

cd "$TEST_ROOT"

# ==============================================================================
# Test 1: Rerere with IBM-1047 files
# ==============================================================================
echo "[Test 1/2] git rerere with IBM-1047 encoded files..."

mkdir test1 && cd test1
"$GIT_BIN" init -q
"$GIT_BIN" config user.name "Test User"
"$GIT_BIN" config user.email "test@example.com"
"$GIT_BIN" config core.ignorefiletags false
"$GIT_BIN" config rerere.enabled true

# Create .gitattributes with IBM-1047
cat > .gitattributes << 'EOF'
*.txt zos-working-tree-encoding=IBM-1047
