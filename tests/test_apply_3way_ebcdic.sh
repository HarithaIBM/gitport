#!/usr/bin/env bash
# ==============================================================================
# Test git apply --3way with EBCDIC/IBM-1047 files
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -x "$REPO_ROOT/git/git" ]; then
    GIT_BIN="$REPO_ROOT/git/git"
else
    GIT_BIN="$(which git)"
fi

TEST_ROOT="$(pwd)/test_tmp_$$"
mkdir -p "$TEST_ROOT"
trap 'rm -rf "$TEST_ROOT"' EXIT

echo "========================================================================"
echo "      TEST: git apply --3way with EBCDIC Files                         "
echo "========================================================================"
echo "Git: $("$GIT_BIN" --version) ($GIT_BIN)"
echo "Test: $TEST_ROOT"
echo ""

PASSED=0
TOTAL=2

cd "$TEST_ROOT"

# ==============================================================================
# Test 1: Simple apply --3way with IBM-1047
# ==============================================================================
echo "[Test 1/2] git apply --3way with IBM-1047 file..."

mkdir t1 && cd t1
"$GIT_BIN" init -q 2>/dev/null
"$GIT_BIN" config user.name "Test"
"$GIT_BIN" config user.email "test@test.com"
"$GIT_BIN" config core.ignorefiletags false

echo "*.txt zos-working-tree-encoding=IBM-1047" > .gitattributes
"$GIT_BIN" add .gitattributes
"$GIT_BIN" commit -q -m "Attrs" 2>/dev/null

# Create properly tagged file
cat > file.txt << 'TXT'
line1
line2
line3
TXT
chtag -t -c IBM-1047 file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Base" 2>/dev/null

"$GIT_BIN" checkout -f file.txt 2>/dev/null

# Create patch via git
cat > file.txt << 'TXT'
line1
line2-modified
line3
TXT
chtag -t -c IBM-1047 file.txt
"$GIT_BIN" diff > patch.diff

# Reset and apply
"$GIT_BIN" checkout -f file.txt 2>/dev/null

if "$GIT_BIN" apply --3way patch.diff 2>&1 | grep -qv "^error:"; then
    if grep -q "line2-modified" file.txt; then
        echo "  ✓ PASS: Patch applied successfully"
        PASSED=$((PASSED + 1))
    else
        echo "  ✗ FAIL: Patch didn't apply"
    fi
else
    echo "  ✗ FAIL: git apply --3way failed"
fi

cd ..

# ==============================================================================
# Test 2: Verify proper encoding with special characters
# ==============================================================================
echo ""
echo "[Test 2/2] git apply --3way with special characters..."

mkdir t2 && cd t2
"$GIT_BIN" init -q 2>/dev/null
"$GIT_BIN" config user.name "Test"
"$GIT_BIN" config user.email "test@test.com"
"$GIT_BIN" config core.ignorefiletags false

echo "*.txt zos-working-tree-encoding=IBM-1047" > .gitattributes
"$GIT_BIN" add .gitattributes
"$GIT_BIN" commit -q -m "Attrs" 2>/dev/null

# Create file with special chars
cat > file.txt << 'TXT'
Content with chars: $@#
TXT
chtag -t -c IBM-1047 file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Base" 2>/dev/null

"$GIT_BIN" checkout -f file.txt 2>/dev/null

# Modify and create patch
cat > file.txt << 'TXT'
Content with chars: $@# - MODIFIED
TXT
chtag -t -c IBM-1047 file.txt
"$GIT_BIN" diff > patch.diff

# Reset and apply
"$GIT_BIN" checkout -f file.txt 2>/dev/null

if "$GIT_BIN" apply --3way patch.diff 2>&1 | grep -qv "^error:"; then
    if grep -q "MODIFIED" file.txt; then
        echo "  ✓ PASS: Special characters handled correctly"
        PASSED=$((PASSED + 1))
    else
        echo "  ✗ FAIL: Patch didn't apply"
    fi
else
    echo "  ✗ FAIL: apply failed"
fi

cd ..

# ==============================================================================
# Summary
# ==============================================================================
echo ""
echo "========================================================================"
echo "  SUMMARY: $PASSED / $TOTAL TESTS PASSED"
echo "========================================================================"

if [ $PASSED -eq $TOTAL ]; then
    echo "  ✓ ALL TESTS PASSED - git apply --3way works with EBCDIC!"
    exit 0
else
    echo "  ✗ SOME TESTS FAILED"
    exit 1
fi
