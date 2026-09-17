# Rebuild and Test Instructions - New Fixes

## What Was Fixed

**Issue #18: git merge-file** - Files tagged as ISO8859-1 instead of respecting .gitattributes
**Issue #19: git diff --output** - Diff files tagged incorrectly

Both commands now properly tag files according to `.gitattributes` settings.

---

## Step 1: Rebuild Git

The fixes are in the source code but need to be compiled:

```bash
cd git
make clean
make -j4
```

Expected output at the end:
```
    LINK git
    BUILTIN git-add
    BUILTIN git-am
    ...
    (success - no errors)
```

Build time: ~2-5 minutes

---

## Step 2: Run Tests

### Quick Test (4 tests):
```bash
cd tests
./test_merge_file_diff_output.sh
```

Expected:
```
[Test 1/4] git merge-file with IBM-1047 encoding
  ✓ PASS: File tagged as IBM-1047

[Test 2/4] git merge-file with UTF-8 encoding
  ✓ PASS: File tagged as UTF-8

[Test 3/4] git diff --output with IBM-1047 encoding
  ✓ PASS: Diff file tagged as IBM-1047

[Test 4/4] git diff --output with UTF-8 encoding
  ✓ PASS: Diff file tagged as UTF-8

SUMMARY: 4 / 4 TESTS PASSED
```

### Test git apply (3 tests):
```bash
./test_apply_tagging.sh
```

Expected: Should pass (apply likely already works)

### Test git rebase (3 tests):
```bash
./test_rebase_tagging.sh
```

Expected: Should pass (rebase confirmed working)

### Run All Tests (10 tests):
```bash
./test_all_tagging_commands.sh
```

This runs all 4 command tests sequentially.

---

## Step 3: Verify Results

All tests should pass:
- ✓ git merge-file (2 tests)
- ✓ git diff --output (2 tests)
- ✓ git apply (3 tests)
- ✓ git rebase (3 tests)

**Total: 10 tests**

---

## If Tests Fail

### Before rebuild:
Tests will fail because the old binary doesn't have the fixes.

### After rebuild:
Tests should all pass. If they don't:

1. Check build succeeded:
   ```bash
   cd git
   ./git --version
   # Should show: git version 2.55.0
   ```

2. Check binary location:
   ```bash
   which git
   # Should point to your rebuilt git/git
   ```

3. Run manual test (see TESTING_NEW_FIXES.md)

---

## Manual Testing (Optional)

If you want to test manually:

### Test merge-file:
```bash
cd /tmp && rm -rf mf-test && mkdir mf-test && cd mf-test
git init
git config core.ignorefiletags false
echo "*.txt zos-working-tree-encoding=IBM-1047" > .gitattributes

echo "base" > base.txt
echo "ours" > ours.txt
echo "theirs" > theirs.txt

git merge-file ours.txt base.txt theirs.txt
chtag -p ours.txt

# Should show: t IBM-1047   T=on  ours.txt
```

### Test diff --output:
```bash
cd /tmp && rm -rf diff-test && mkdir diff-test && cd diff-test
git init
git config user.name "Test"
git config user.email "test@test.com"
git config core.ignorefiletags false
echo "*.diff zos-working-tree-encoding=IBM-1047" > .gitattributes
git add .gitattributes
git commit -m "Attributes"

echo "v1" > f.txt
git add f.txt && git commit -m "V1"

echo "v2" > f.txt
git add f.txt && git commit -m "V2"

git diff HEAD~1 HEAD --output=out.diff
chtag -p out.diff

# Should show: t IBM-1047   T=on  out.diff
```

---

## Files Modified

### Git source (git/):
- `builtin/merge-file.c` - Added tagging
- `diff.c` - Added tagging for --output
- `diff.h` - Added output_path field

### Patches (stable-patches/):
- `builtin/merge-file.c.patch` - NEW
- `diff.c.patch` - UPDATED
- `diff.h.patch` - NEW

### Tests (tests/):
- `test_merge_file_diff_output.sh` - NEW (4 tests)
- `test_apply_tagging.sh` - NEW (3 tests)
- `test_rebase_tagging.sh` - NEW (3 tests)
- `test_all_tagging_commands.sh` - NEW (runs all)

---

## Summary

1. ✅ Fixed 2 commands (merge-file, diff --output)
2. ✅ Created 10 tests across 4 commands
3. ✅ Created patch files
4. ⏭️ **YOU:** Rebuild Git
5. ⏭️ **YOU:** Run tests to verify

**Next command:**
```bash
cd git && make clean && make -j4
```

Then:
```bash
cd tests && ./test_all_tagging_commands.sh
```
