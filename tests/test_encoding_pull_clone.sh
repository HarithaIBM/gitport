#!/bin/sh
#
# Copyright (c) 2024 IBM
#
# Test z/OS encoding handling for git pull vs git clone
# This test verifies the fixes for Issue #255

# Exit on error
set -e

# Suppress FSUM7351 warnings by filtering output
exec 2>&1

echo "TAP version 13"
echo "1..9"

# Setup test repository
TEST_DIR=$(mktemp -d /tmp/git-encoding-test.XXXXXX)
cd "$TEST_DIR"

cleanup() {
    cd /
    rm -rf "$TEST_DIR" "$TEST_DIR-clone" "$TEST_DIR-clone2"
}
trap cleanup EXIT

# Test 1: Setup repository with ISO8859-1 encoding
git init > /dev/null 2>&1
cat > .gitattributes << 'EOF'
* zos-working-tree-encoding=iso8859-1
.gitattributes zos-working-tree-encoding=iso8859-1
EOF
echo "Test content line 1" > testfile.txt
chtag -tc ISO8859-1 testfile.txt
git add .gitattributes testfile.txt > /dev/null 2>&1
git commit -m "Initial commit with ISO8859-1" > /dev/null 2>&1
echo "ok 1 - setup repository with ISO8859-1 encoding"

# Test 2: Clone and verify ISO8859-1 tagging
git clone . "$TEST_DIR-clone" > /dev/null 2>&1
if ls -T "$TEST_DIR-clone/testfile.txt" | grep -q "t ISO8859-1"; then
    echo "ok 2 - clone repository and verify ISO8859-1 tagging"
else
    echo "not ok 2 - clone repository and verify ISO8859-1 tagging"
    exit 1
fi

# Test 3: Change encoding to IBM-1047
cat > .gitattributes << 'EOF'
* zos-working-tree-encoding=ibm-1047
.gitattributes zos-working-tree-encoding=iso8859-1
EOF
echo "Modified content with IBM-1047" > testfile.txt
chtag -tc IBM-1047 testfile.txt
git add .gitattributes testfile.txt > /dev/null 2>&1
git commit -m "Change to IBM-1047 encoding" > /dev/null 2>&1
echo "ok 3 - change encoding to IBM-1047 in .gitattributes"

# Test 4: git pull updates file tags to IBM-1047
cd "$TEST_DIR-clone"
git pull > /dev/null 2>&1
if ls -T testfile.txt | grep -q "t IBM-1047"; then
    echo "ok 4 - git pull updates file tags to IBM-1047"
else
    echo "not ok 4 - git pull updates file tags to IBM-1047"
    exit 1
fi

# Test 5: Fresh clone also gets IBM-1047 tagging
cd "$TEST_DIR"
git clone . "$TEST_DIR-clone2" > /dev/null 2>&1
if ls -T "$TEST_DIR-clone2/testfile.txt" | grep -q "t IBM-1047"; then
    echo "ok 5 - fresh clone also gets IBM-1047 tagging"
else
    echo "not ok 5 - fresh clone also gets IBM-1047 tagging"
    exit 1
fi

# Test 6: Both pull and clone produce same file tags
TAG1=$(ls -T "$TEST_DIR-clone/testfile.txt" | awk '{print $1}')
TAG2=$(ls -T "$TEST_DIR-clone2/testfile.txt" | awk '{print $1}')
if [ "$TAG1" = "$TAG2" ] && [ "$TAG1" = "t" ]; then
    echo "ok 6 - both pull and clone produce same file tags"
else
    echo "not ok 6 - both pull and clone produce same file tags"
    exit 1
fi

# Test 7: git diff with working-tree-encoding
cd "$TEST_DIR"
echo "New line" >> testfile.txt
if git diff testfile.txt > /dev/null 2>&1; then
    echo "ok 7 - test git diff with working-tree-encoding (runs without error)"
else
    echo "not ok 7 - test git diff with working-tree-encoding"
    exit 1
fi
git restore testfile.txt

# Test 8: git stash with working-tree-encoding
echo "Stash test line" >> testfile.txt
TAG_BEFORE=$(ls -T testfile.txt | awk '{print $1}')
git stash push testfile.txt > /dev/null 2>&1
TAG_AFTER=$(ls -T testfile.txt | awk '{print $1}')
if [ "$TAG_BEFORE" = "$TAG_AFTER" ] && [ "$TAG_AFTER" = "t" ]; then
    git stash pop > /dev/null 2>&1
    if grep -q "Stash test line" testfile.txt; then
        echo "ok 8 - test git stash with working-tree-encoding"
    else
        echo "not ok 8 - test git stash with working-tree-encoding"
        exit 1
    fi
else
    echo "not ok 8 - test git stash with working-tree-encoding"
    exit 1
fi

# Test 9: git apply --3way with working-tree-encoding
echo "Original content" > applytest.txt
chtag -tc IBM-1047 applytest.txt
git add applytest.txt > /dev/null 2>&1
git commit -m "Add applytest" > /dev/null 2>&1
echo "Modified content" > applytest.txt
git add applytest.txt > /dev/null 2>&1
git commit -m "Modify applytest" > /dev/null 2>&1
git format-patch -1 HEAD -o /tmp > /dev/null 2>&1
git reset --hard HEAD~1 > /dev/null 2>&1
echo "Different content" > applytest.txt
git add applytest.txt > /dev/null 2>&1
git commit -m "Different modification" > /dev/null 2>&1
if git apply --3way /tmp/0001-*.patch 2>&1 | grep -q "conflicts"; then
    TAG=$(ls -T applytest.txt | awk '{print $1}')
    if [ "$TAG" = "t" ] && grep -q "Modified content" applytest.txt; then
        echo "ok 9 - test git apply --3way with working-tree-encoding"
    else
        echo "not ok 9 - test git apply --3way with working-tree-encoding"
        exit 1
    fi
else
    echo "not ok 9 - test git apply --3way with working-tree-encoding"
    exit 1
fi

echo "# All encoding tests passed"
