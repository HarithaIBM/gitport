# How to Test git rerere Encoding Issue

## The Problem

When `git rerere` (reuse recorded resolution) auto-resolves conflicts, the resolved files are not tagged with the correct encoding specified in `.gitattributes`.

**Expected:** Files should be tagged as `IBM-1047` (per `.gitattributes`)  
**Actual:** Files are tagged as `ISO8859-1`

---

## Quick Manual Test

### Prerequisites
```bash
# Make sure rerere is enabled
git config rerere.enabled true

# Use the built git
cd ~/code/bazel-7.2.0/git_255_iconv_translit_3waymerge/gitport/git
```

### Test Steps

```bash
# 1. Create test repo
cd /tmp
mkdir rerere-test && cd rerere-test
git init
git config user.name "Test"
git config user.email "test@test.com"
git config rerere.enabled true
git config core.ignorefiletags false

# 2. Create .gitattributes with IBM-1047
cat > .gitattributes << 'ATTR'
*.txt zos-working-tree-encoding=IBM-1047
ATTR

git add .gitattributes
git commit -m "Add attributes"

# 3. Create base file
cat > test.txt << 'TXT'
Line 1
Line 2
Line 3
TXT

git add test.txt
git commit -m "Base"

# 4. Create branch with change
git checkout -b feature
cat > test.txt << 'TXT'
Line 1
Line 2 - feature change
Line 3
TXT

git add test.txt
git commit -m "Feature"
FEATURE_COMMIT=$(git rev-parse HEAD)

# 5. Go back and make conflicting change
git checkout main
cat > test.txt << 'TXT'
Line 1
Line 2 - main change
Line 3
TXT

git add test.txt
git commit -m "Main"

# 6. Cherry-pick (will conflict)
git cherry-pick $FEATURE_COMMIT
# You'll see conflict

# 7. Resolve manually
cat > test.txt << 'TXT'
Line 1
Line 2 - resolved
Line 3
TXT

git add test.txt
git cherry-pick --continue

# 8. Check tag (should be IBM-1047)
chtag -p test.txt
# ✓ Should show: IBM-1047

# 9. Reset and create same conflict
git reset --hard HEAD~2

cat > test.txt << 'TXT'
Line 1
Line 2 - main change
Line 3
TXT

git add test.txt
git commit -m "Main again"

# 10. Cherry-pick again - rerere should auto-resolve
git cherry-pick $FEATURE_COMMIT

# 11. Check tag NOW
chtag -p test.txt
# ✗ BUG: Shows ISO8859-1 instead of IBM-1047!
```

### Expected vs Actual

**Expected:**
```
t IBM-1047   T=on  test.txt
```

**Actual (BUG):**
```
t ISO8859-1  T=on  test.txt
```

---

## Automated Test

We've created an automated test:

```bash
cd ~/code/bazel-7.2.0/git_255_iconv_translit_3waymerge/gitport
bash tests/test_rerere_encoding.sh
```

**Current Result:** Test fails, confirming the bug.

---

## Where the Bug Likely Is

`git rerere` stores conflict resolutions in `.git/rr-cache/` and replays them. When replaying, it probably:

1. Reads the resolved content from cache
2. Writes it to the working tree
3. **BUT** doesn't call the proper tagging functions

**Files to check:**
- `git/rerere.c` - rerere implementation
- `git/rerere.h` - rerere interface

The fix likely needs to:
- Call `checkout_entry()` or similar with proper attributes
- Or explicitly tag files after writing from rerere cache

---

## Workaround

Until fixed, after `git cherry-pick` or `git merge` with rerere:

```bash
# Manually retag files
find . -name "*.txt" -type f -exec chtag -t -c IBM-1047 {} \;

# Or use git to re-checkout
git checkout HEAD -- .
```

---

## Next Steps

1. Confirm the bug with manual test
2. Investigate `rerere.c` for where it writes files
3. Add proper encoding/tagging support
4. Update automated test to verify fix

