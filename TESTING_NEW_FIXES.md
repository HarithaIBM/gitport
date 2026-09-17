# Testing New Fixes - Issues #18 and #19

## Overview

Fixed two commands that were writing files without proper z/OS tagging:
- **Issue #18:** `git merge-file` - Tags files as ISO8859-1 instead of respecting .gitattributes
- **Issue #19:** `git diff --output` - Tags diff output files as ISO8859-1

## Quick Test

After rebuilding Git, run:

```bash
cd tests
./test_merge_file_diff_output.sh
```

Expected output:
```
========================================================================
      TEST: git merge-file and git diff --output Tagging              
========================================================================

[Test 1/4] git merge-file with IBM-1047 encoding
  ✓ PASS: File tagged as IBM-1047

[Test 2/4] git merge-file with UTF-8 encoding
  ✓ PASS: File tagged as UTF-8

[Test 3/4] git diff --output with IBM-1047 encoding
  ✓ PASS: Diff file tagged as IBM-1047

[Test 4/4] git diff --output with UTF-8 encoding
  ✓ PASS: Diff file tagged as UTF-8

========================================================================
  SUMMARY: 4 / 4 TESTS PASSED
========================================================================
```

## Also Test apply and rebase

### Test git apply:
```bash
cd tests
./test_apply_tagging.sh
```

Expected: Should PASS (apply likely already works correctly)

### Test git rebase:
```bash
cd tests
./test_rebase_tagging.sh
```

Expected: Should PASS (rebase confirmed working)

## Run All Tagging Tests

```bash
cd tests
./test_all_tagging_commands.sh
```

This runs all 4 command tests in sequence.

## Manual Testing

### Test merge-file:
```bash
cd /tmp && rm -rf test-mf && mkdir test-mf && cd test-mf
git init
git config user.name "Test"
git config user.email "test@test.com"
git config core.ignorefiletags false

echo "*.txt zos-working-tree-encoding=IBM-1047" > .gitattributes
git add .gitattributes
git commit -m "Attributes"

echo "base" > base.txt
echo "ours" > ours.txt
echo "theirs" > theirs.txt

git merge-file ours.txt base.txt theirs.txt
chtag -p ours.txt

# Should show: t IBM-1047   T=on  ours.txt
```

### Test diff --output:
```bash
cd /tmp && rm -rf test-diff && mkdir test-diff && cd test-diff
git init
git config user.name "Test"
git config user.email "test@test.com"
git config core.ignorefiletags false

echo "*.diff zos-working-tree-encoding=IBM-1047" > .gitattributes
git add .gitattributes
git commit -m "Attributes"

echo "v1" > f.txt
git add f.txt
git commit -m "V1"

echo "v2" > f.txt
git add f.txt
git commit -m "V2"

git diff HEAD~1 HEAD --output=out.diff
chtag -p out.diff

# Should show: t IBM-1047   T=on  out.diff
```

## Rebuild Instructions

```bash
cd git
make clean
make -j4
```

After successful build, the fixes will be active.

## What Was Fixed

### builtin/merge-file.c
Added z/OS file tagging:
1. Disable auto-conversion after fopen()
2. Tag file according to .gitattributes before fclose()

### diff.c + diff.h
Added z/OS file tagging for --output option:
1. Disable auto-conversion when opening file
2. Save output path in diff_options struct
3. Tag file before closing in diff_free_file()

Both follow same pattern as rerere fix (Issue #17).

## Files Modified

### Source files (in git/):
- `builtin/merge-file.c` - Added tagging
- `diff.c` - Added tagging for --output
- `diff.h` - Added output_path field

### Patch files (in stable-patches/):
- `builtin/merge-file.c.patch` - NEW
- `diff.c.patch` - NEW
- `diff.h.patch` - NEW

### Test files (in tests/):
- `test_merge_file_diff_output.sh` - 4 tests for both commands
- `test_apply_tagging.sh` - 3 tests for git apply
- `test_rebase_tagging.sh` - 3 tests for git rebase
- `test_all_tagging_commands.sh` - Runs all above tests

## Success Criteria

All tests should pass:
- ✓ merge-file with IBM-1047
- ✓ merge-file with UTF-8
- ✓ diff --output with IBM-1047
- ✓ diff --output with UTF-8
- ✓ apply (likely already works)
- ✓ rebase (confirmed works)

Total: 10+ tests across 4 commands
