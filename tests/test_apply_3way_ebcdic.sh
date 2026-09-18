#!/usr/bin/env bash
# ==============================================================================
# Git Apply 3-Way Merge with IBM-1047 Verification Test
# Tests that git apply --3way works correctly with EBCDIC files
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
echo "       GIT APPLY --3WAY WITH IBM-1047 VERIFICATION TEST               "
echo "========================================================================"
echo "Git binary: $("$GIT_BIN" --version) ($GIT_BIN)"
echo "Test root:  $TEST_ROOT"
echo ""

PASSED=0
TOTAL=4

cd "$TEST_ROOT"

# ------------------------------------------------------------------------------
# Test 1: git apply --3way works with unmodified IBM-1047 file
# ------------------------------------------------------------------------------
echo "[Test 1/4] git apply --3way with unmodified IBM-1047 file..."

mkdir test1 && cd test1
"$GIT_BIN" init -q
"$GIT_BIN" config core.ignorefiletags false

echo "file.txt zos-working-tree-encoding=IBM-1047" > .gitattributes
"$GIT_BIN" add .gitattributes
"$GIT_BIN" commit -q -m "Add attributes"

# Create base file
printf "line1\nline2\nline3\n" > file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Base commit"

# Create a patch that modifies line2
cat > patch.diff << 'EOF'
diff --git a/file.txt b/file.txt
index 1234567..abcdefg 100644
--- a/file.txt
+++ b/file.txt
@@ -1,3 +1,3 @@
 line1
-line2
+line2-modified
 line3
EOF

# Apply with --3way
if "$GIT_BIN" apply --3way patch.diff 2>&1 | grep -qv "error\|fatal"; then
    if grep -q "line2-modified" file.txt; then
        echo "  ✓ Patch applied successfully to IBM-1047 file"
        PASSED=$((PASSED + 1))
    else
        echo "  ✗ FAIL: Patch didn't apply correctly"
        cat file.txt
    fi
else
    echo "  ✗ FAIL: git apply --3way failed"
fi

cd ..

# ------------------------------------------------------------------------------
# Test 2: git apply --3way detects modifications correctly
# ------------------------------------------------------------------------------
echo ""
echo "[Test 2/4] git apply --3way detects local modifications..."

mkdir test2 && cd test2
"$GIT_BIN" init -q
"$GIT_BIN" config core.ignorefiletags false

echo "file.txt zos-working-tree-encoding=IBM-1047" > .gitattributes
"$GIT_BIN" add .gitattributes
"$GIT_BIN" commit -q -m "Add attributes"

printf "line1\nline2\nline3\n" > file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Base commit"

# Modify file locally
printf "line1-MODIFIED\nline2\nline3\n" > file.txt

# Create patch modifying line3
cat > patch.diff << 'EOF'
diff --git a/file.txt b/file.txt
--- a/file.txt
+++ b/file.txt
@@ -1,3 +1,3 @@
 line1
 line2
-line3
+line3-patched
EOF

# Apply with --3way should do 3-way merge
"$GIT_BIN" apply --3way patch.diff 2>&1 | grep -v "detached HEAD" || true

# Check that both modifications are present (3-way merge worked)
if grep -q "line1-MODIFIED" file.txt && grep -q "line3-patched" file.txt; then
    echo "  ✓ 3-way merge correctly merged local change and patch"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: 3-way merge didn't preserve both changes"
    cat file.txt
fi

cd ..

# ------------------------------------------------------------------------------
# Test 3: git apply (non-3way) still checks modifications
# ------------------------------------------------------------------------------
echo ""
echo "[Test 3/4] git apply without --3way still validates file..."

mkdir test3 && cd test3
"$GIT_BIN" init -q
"$GIT_BIN" config core.ignorefiletags false

echo "file.txt zos-working-tree-encoding=IBM-1047" > .gitattributes
"$GIT_BIN" add .gitattributes
"$GIT_BIN" commit -q -m "Add attributes"

printf "line1\nline2\nline3\n" > file.txt
"$GIT_BIN" add file.txt  
"$GIT_BIN" commit -q -m "Base commit"

# Modify file so it doesn't match index
printf "TOTALLY\nDIFFERENT\nCONTENT\n" > file.txt

# Create simple patch
cat > patch.diff << 'EOF'
diff --git a/file.txt b/file.txt
--- a/file.txt
+++ b/file.txt
@@ -1,3 +1,3 @@
 line1
-line2
+line2-modified
 line3
EOF

# Non-3way apply should fail because file doesn't match
if "$GIT_BIN" apply patch.diff 2>&1 | grep -q "error\|does not match"; then
    echo "  ✓ Non-3way apply correctly detected file mismatch"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ FAIL: Non-3way apply should have failed but didn't"
fi

cd ..

# ------------------------------------------------------------------------------
# Test 4: Verify EBCDIC file size difference doesn't break 3-way
# ------------------------------------------------------------------------------
echo ""
echo "[Test 4/4] 3-way merge handles EBCDIC/UTF-8 size differences..."

mkdir test4 && cd test4
"$GIT_BIN" init -q
"$GIT_BIN" config core.ignorefiletags false

echo "file.txt zos-working-tree-encoding=IBM-1047" > .gitattributes
"$GIT_BIN" add .gitattributes
"$GIT_BIN" commit -q -m "Add attributes"

# Create file with characters that have different sizes in EBCDIC vs UTF-8
printf "Content with special chars: \$@#\n" > file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Base with special chars"

# The file on disk (EBCDIC) will have different byte size than index (UTF-8)
# But 3-way merge should still work

cat > patch.diff << 'EOF'
diff --git a/file.txt b/file.txt
--- a/file.txt  
+++ b/file.txt
@@ -1 +1 @@
-Content with special chars: $@#
+Content with special chars: $@# - MODIFIED
EOF

if "$GIT_BIN" apply --3way patch.diff 2>&1 | grep -qv "error\|fatal"; then
    if grep -q "MODIFIED" file.txt; then
        echo "  ✓ 3-way merge succeeded despite size differences"
        PASSED=$((PASSED + 1))
    else
        echo "  ✗ FAIL: Patch didn't apply"
    fi
else
    echo "  ✗ FAIL: 3-way merge failed on size difference"
fi

cd ..

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo ""
echo "========================================================================"
echo "  SUMMARY: $PASSED / $TOTAL TESTS PASSED"
if [ $PASSED -eq $TOTAL ]; then
    echo "  ✓ ALL TESTS PASSED - git apply --3way works correctly!"
else
    echo "  ✗ SOME TESTS FAILED"
    exit 1
fi
echo "========================================================================"

exit 0
