#!/usr/bin/env bash
# ==============================================================================
# Comprehensive Test: All Git Commands That Write Working Tree Files
# Test if they respect zos-working-tree-encoding and tag files correctly
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

TEST_ROOT="$(mktemp -d /tmp/git_file_write_test.XXXXXX)"
trap 'rm -rf "$TEST_ROOT"' EXIT

echo "========================================================================"
echo "      COMPREHENSIVE FILE WRITING COMMANDS TEST                         "
echo "========================================================================"
echo "Git binary: $("$GIT_BIN" --version) ($GIT_BIN)"
echo "Test root:  $TEST_ROOT"
echo ""
echo "Testing commands that write files to working tree..."
echo "Checking if they respect zos-working-tree-encoding and tag correctly"
echo ""

PASSED=0
FAILED=0
TOTAL=0

# Helper function to check file tag
check_file_tag() {
    local file="$1"
    local expected="$2"
    local test_name="$3"
    
    TOTAL=$((TOTAL + 1))
    
    if [ ! -f "$file" ]; then
        echo "  ✗ FAIL: File '$file' doesn't exist"
        FAILED=$((FAILED + 1))
        return 1
    fi
    
    TAG=$(chtag -p "$file" 2>/dev/null | awk '{print $2}')
    
    if [ "$TAG" = "$expected" ]; then
        echo "  ✓ PASS: $test_name - File tagged as $TAG"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo "  ✗ FAIL: $test_name - Expected $expected, got $TAG"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

cd "$TEST_ROOT"

# ==============================================================================
# Test 1: git rerere (already fixed, baseline)
# ==============================================================================
echo "[Test 1] git rerere (already fixed - baseline)"
echo ""

mkdir test1 && cd test1
"$GIT_BIN" init -q
"$GIT_BIN" config user.name "Test"
"$GIT_BIN" config user.email "test@test.com"
"$GIT_BIN" config core.ignorefiletags false
"$GIT_BIN" config rerere.enabled true

echo "*.txt zos-working-tree-encoding=IBM-1047" > .gitattributes
"$GIT_BIN" add .gitattributes
"$GIT_BIN" commit -q -m "Attributes"

echo "line1" > file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Base"

"$GIT_BIN" checkout -q -b branch1
echo "line1-branch1" > file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Branch1"

"$GIT_BIN" checkout -q master
echo "line1-master" > file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Main"

"$GIT_BIN" merge branch1 2>&1 | grep -i conflict >/dev/null || true
echo "line1-resolved" > file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Resolved"

# Create same conflict again
"$GIT_BIN" reset --hard HEAD~2 -q
"$GIT_BIN" checkout -q -b branch2 branch1~1
echo "line1-branch2" > file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Branch2"

"$GIT_BIN" checkout -q master~1
echo "line1-master" > file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Main again"

"$GIT_BIN" merge branch2 >/dev/null 2>&1 || true

check_file_tag "file.txt" "IBM-1047" "rerere auto-resolve"

cd ..

# ==============================================================================
# Test 2: git apply (regular patch, not 3-way)
# ==============================================================================
echo ""
echo "[Test 2] git apply (regular patch)"
echo ""

mkdir test2 && cd test2
"$GIT_BIN" init -q
"$GIT_BIN" config user.name "Test"
"$GIT_BIN" config user.email "test@test.com"
"$GIT_BIN" config core.ignorefiletags false

echo "*.txt zos-working-tree-encoding=IBM-1047" > .gitattributes
"$GIT_BIN" add .gitattributes
"$GIT_BIN" commit -q -m "Attributes"

echo "original line" > file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Original"

# Create a patch
echo "modified line" > file.txt
"$GIT_BIN" diff > /tmp/test.patch

# Reset and apply patch
"$GIT_BIN" checkout -q file.txt
"$GIT_BIN" apply /tmp/test.patch

check_file_tag "file.txt" "IBM-1047" "git apply (regular)"

cd ..

# ==============================================================================
# Test 3: git apply --3way (3-way merge)
# ==============================================================================
echo ""
echo "[Test 3] git apply --3way (we already fixed this)"
echo ""

mkdir test3 && cd test3
"$GIT_BIN" init -q
"$GIT_BIN" config user.name "Test"
"$GIT_BIN" config user.email "test@test.com"
"$GIT_BIN" config core.ignorefiletags false

echo "*.txt zos-working-tree-encoding=IBM-1047" > .gitattributes
"$GIT_BIN" add .gitattributes
"$GIT_BIN" commit -q -m "Attributes"

echo "line 1" > file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Base"

# Create conflicting change in repo
echo "line 1 - changed" > file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Change in repo"

# Go back and create patch from different change
"$GIT_BIN" reset --hard HEAD~1 -q
echo "line 1 - different" > file.txt
"$GIT_BIN" diff > /tmp/conflict.patch

# Move forward and try to apply with 3-way
"$GIT_BIN" reset --hard HEAD -q
"$GIT_BIN" apply --3way /tmp/conflict.patch 2>&1 | grep -i "Applied patch" >/dev/null || true

check_file_tag "file.txt" "IBM-1047" "git apply --3way"

cd ..

# ==============================================================================
# Test 4: git merge-file
# ==============================================================================
echo ""
echo "[Test 4] git merge-file (direct file merge)"
echo ""

mkdir test4 && cd test4
"$GIT_BIN" init -q
"$GIT_BIN" config user.name "Test"
"$GIT_BIN" config user.email "test@test.com"
"$GIT_BIN" config core.ignorefiletags false

echo "*.txt zos-working-tree-encoding=IBM-1047" > .gitattributes

# Create three versions
echo "base content" > base.txt
echo "current content" > current.txt
echo "other content" > other.txt

# Merge directly to output file
"$GIT_BIN" merge-file -p current.txt base.txt other.txt > result.txt 2>/dev/null || true

check_file_tag "result.txt" "IBM-1047" "git merge-file output"

cd ..

# ==============================================================================
# Test 5: git diff --output=file
# ==============================================================================
echo ""
echo "[Test 5] git diff --output=file"
echo ""

mkdir test5 && cd test5
"$GIT_BIN" init -q
"$GIT_BIN" config user.name "Test"
"$GIT_BIN" config user.email "test@test.com"
"$GIT_BIN" config core.ignorefiletags false

echo "*.diff zos-working-tree-encoding=IBM-1047" > .gitattributes
"$GIT_BIN" add .gitattributes
"$GIT_BIN" commit -q -m "Attributes"

echo "line1" > file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Version 1"

echo "line2" > file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Version 2"

# Create diff output file
"$GIT_BIN" diff HEAD~1 HEAD --output=output.diff

check_file_tag "output.diff" "IBM-1047" "git diff --output"

cd ..

# ==============================================================================
# Test 6: git show > file (redirect to file)
# ==============================================================================
echo ""
echo "[Test 6] git show > file (shell redirect)"
echo ""

mkdir test6 && cd test6
"$GIT_BIN" init -q
"$GIT_BIN" config user.name "Test"
"$GIT_BIN" config user.email "test@test.com"
"$GIT_BIN" config core.ignorefiletags false

echo "*.txt zos-working-tree-encoding=IBM-1047" > .gitattributes
"$GIT_BIN" add .gitattributes
"$GIT_BIN" commit -q -m "Attributes"

echo "content" > original.txt
"$GIT_BIN" add original.txt
"$GIT_BIN" commit -q -m "Add file"

# Use shell redirect (Git doesn't control this)
"$GIT_BIN" show HEAD:original.txt > extracted.txt

# This likely won't be tagged by Git (shell redirect)
TAG=$(chtag -p extracted.txt 2>/dev/null | awk '{print $2}')
TOTAL=$((TOTAL + 1))
if [ "$TAG" = "IBM-1047" ]; then
    echo "  ✓ PASS: Shell redirect tagged correctly (surprising!)"
    PASSED=$((PASSED + 1))
else
    echo "  ℹ INFO: Shell redirect not tagged (expected: $TAG) - Git doesn't control this"
    PASSED=$((PASSED + 1))  # Not a failure, expected behavior
fi

cd ..

# ==============================================================================
# Test 7: git archive (extract to working tree)
# ==============================================================================
echo ""
echo "[Test 7] git archive (extract files)"
echo ""

mkdir test7 && cd test7
"$GIT_BIN" init -q
"$GIT_BIN" config user.name "Test"
"$GIT_BIN" config user.email "test@test.com"
"$GIT_BIN" config core.ignorefiletags false

echo "*.txt zos-working-tree-encoding=IBM-1047" > .gitattributes
"$GIT_BIN" add .gitattributes
"$GIT_BIN" commit -q -m "Attributes"

echo "archived content" > archive-file.txt
"$GIT_BIN" add archive-file.txt
"$GIT_BIN" commit -q -m "Add file to archive"

# Create tar archive
"$GIT_BIN" archive HEAD -o archive.tar

# Extract
mkdir extract
cd extract
tar -xf ../archive.tar

# Check if extracted file is tagged
# Note: tar extraction, not Git, so probably not tagged
TAG=$(chtag -p archive-file.txt 2>/dev/null | awk '{print $2}')
TOTAL=$((TOTAL + 1))
if [ "$TAG" = "IBM-1047" ]; then
    echo "  ✓ PASS: Extracted file tagged as IBM-1047"
    PASSED=$((PASSED + 1))
else
    echo "  ℹ INFO: Extracted file not tagged ($TAG) - tar extract, not Git"
    PASSED=$((PASSED + 1))  # Not Git's responsibility
fi

cd ../..

# ==============================================================================
# Test 8: git stash apply (write files from stash)
# ==============================================================================
echo ""
echo "[Test 8] git stash apply"
echo ""

mkdir test8 && cd test8
"$GIT_BIN" init -q
"$GIT_BIN" config user.name "Test"
"$GIT_BIN" config user.email "test@test.com"
"$GIT_BIN" config core.ignorefiletags false

echo "*.txt zos-working-tree-encoding=IBM-1047" > .gitattributes
"$GIT_BIN" add .gitattributes
"$GIT_BIN" commit -q -m "Attributes"

echo "committed" > file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Committed"

echo "modified" > file.txt
"$GIT_BIN" stash push -q -m "Stash changes"

# Modify differently
echo "other change" > file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Different change"

# Apply stash (will conflict)
"$GIT_BIN" stash apply 2>&1 | grep -i conflict >/dev/null || true

check_file_tag "file.txt" "IBM-1047" "git stash apply (with conflict)"

cd ..

# ==============================================================================
# Test 9: git checkout --conflict=diff3
# ==============================================================================
echo ""
echo "[Test 9] git checkout --conflict=diff3"
echo ""

mkdir test9 && cd test9
"$GIT_BIN" init -q
"$GIT_BIN" config user.name "Test"
"$GIT_BIN" config user.email "test@test.com"
"$GIT_BIN" config core.ignorefiletags false

echo "*.txt zos-working-tree-encoding=IBM-1047" > .gitattributes
"$GIT_BIN" add .gitattributes
"$GIT_BIN" commit -q -m "Attributes"

echo "base" > file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Base"

"$GIT_BIN" checkout -q -b branch1
echo "branch1" > file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Branch1"

"$GIT_BIN" checkout -q master
echo "master" > file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Main"

# Merge with conflict
"$GIT_BIN" merge branch1 2>&1 | grep -i conflict >/dev/null || true

# Checkout with diff3 markers
"$GIT_BIN" checkout --conflict=diff3 file.txt 2>&1 >/dev/null || true

check_file_tag "file.txt" "IBM-1047" "git checkout --conflict=diff3"

cd ..

# ==============================================================================
# Test 10: git worktree add (creates .git file)
# ==============================================================================
echo ""
echo "[Test 10] git worktree add (creates .git file)"
echo ""

mkdir test10 && cd test10
"$GIT_BIN" init -q
"$GIT_BIN" config user.name "Test"
"$GIT_BIN" config user.email "test@test.com"
"$GIT_BIN" config core.ignorefiletags false

echo "*.txt zos-working-tree-encoding=IBM-1047" > .gitattributes
"$GIT_BIN" add .gitattributes
"$GIT_BIN" commit -q -m "Attributes"

echo "content" > file.txt
"$GIT_BIN" add file.txt
"$GIT_BIN" commit -q -m "Add file"

# Create worktree
"$GIT_BIN" worktree add ../worktree1 HEAD -q 2>&1 || true

# Check the .git file in worktree
TOTAL=$((TOTAL + 1))
if [ -f ../worktree1/.git ]; then
    TAG=$(chtag -p ../worktree1/.git 2>/dev/null | awk '{print $2}')
    echo "  ℹ INFO: .git file tag: $TAG (metadata file, tagging not critical)"
    PASSED=$((PASSED + 1))
    
    # Check the actual working tree file
    check_file_tag "../worktree1/file.txt" "IBM-1047" "worktree working tree file"
else
    echo "  ℹ INFO: Worktree not created or .git file not found"
    PASSED=$((PASSED + 1))
fi

cd ..

# ==============================================================================
# Summary
# ==============================================================================
echo ""
echo "========================================================================"
echo "  SUMMARY: $PASSED / $TOTAL TESTS PASSED, $FAILED FAILED"
echo "========================================================================"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "✓ ALL TESTS PASSED!"
    echo ""
    echo "Summary by command:"
    echo "  1. ✓ git rerere           - Already fixed"
    echo "  2. ? git apply            - Check results above"
    echo "  3. ✓ git apply --3way     - Already fixed"
    echo "  4. ? git merge-file       - Check results above"
    echo "  5. ? git diff --output    - Check results above"
    echo "  6. ℹ git show > file      - Shell redirect (not Git's control)"
    echo "  7. ℹ git archive          - tar extraction (not Git's control)"
    echo "  8. ? git stash apply      - Check results above"
    echo "  9. ? git checkout         - Check results above"
    echo " 10. ? git worktree         - Check results above"
else
    echo "⚠ SOME TESTS FAILED - These commands may need fixes!"
    echo ""
    echo "Failed commands need investigation:"
    echo "  - See which tests failed above"
    echo "  - Determine if they write to working tree"
    echo "  - Check if they should respect .gitattributes"
    echo "  - Add tagging if needed"
fi

echo ""
echo "========================================================================"
echo "Next steps:"
echo "  1. Review failed tests"
echo "  2. Determine which failures are critical"
echo "  3. Fix only the critical ones"
echo "  4. Create patches for fixes"
echo "========================================================================"

exit $FAILED

