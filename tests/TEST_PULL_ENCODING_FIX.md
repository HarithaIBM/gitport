# Test for stable-patches/unpack-trees.c.patch

## Purpose

This test (`test_pull_encoding_tag_fix.sh`) verifies the fix in `stable-patches/unpack-trees.c.patch` which addresses the git pull encoding tag bug with attribute cache invalidation.

## The Bug

**Problem:** When checking out or pulling commits that update `.gitattributes` with new encoding specifications, files don't get re-tagged with the correct encoding because the attribute cache isn't invalidated.

**Scenario:**
1. Commit A has `.gitattributes` specifying `file.txt` as ISO8859-1
2. Commit B changes `.gitattributes` to specify `file.txt` as IBM-1047
3. When checking out from A to B, `file.txt` should be retagged from ISO8859-1 to IBM-1047
4. **Without the fix:** The file keeps the old ISO8859-1 tag
5. **With the fix:** The file gets the new IBM-1047 tag

## The Fix

The patch in `stable-patches/unpack-trees.c.patch` adds code to:
1. Track when `.gitattributes` files are being checked out
2. Invalidate the attribute cache by toggling the direction after checkout
3. Ensure subsequent file tagging operations use the new attributes

```c
#ifdef __MVS__
if (gitattributes_updated) {
    git_attr_set_direction(GIT_ATTR_INDEX);
    git_attr_set_direction(GIT_ATTR_CHECKOUT);
}
#endif
```

## Test Coverage

The test creates three scenarios:

### Test 1: Simple encoding change
- Commit 1: file.txt with ISO8859-1
- Commit 2: file.txt with IBM-1047  
- Verifies file is correctly retagged when checking out between commits

### Test 2: Multiple files with different encodings
- Commit 1: file1=ISO8859-1, file2=UTF-8, file3=IBM-1047
- Commit 2: all files=IBM-1047
- Verifies all files are correctly retagged

### Test 3: Subdirectory .gitattributes
- Commit 1: root .gitattributes (ISO8859-1)
- Commit 2: adds subdir/.gitattributes (IBM-1047)
- Verifies subdirectory attributes are properly applied

## Running the Test

```bash
cd tests
./test_pull_encoding_tag_fix.sh
```

## Expected Results

**With the patch applied and git rebuilt:**
- All 3 tests should PASS
- Files get correctly retagged according to .gitattributes changes

**Without the patch:**
- Tests will FAIL
- Files keep old encoding tags even when .gitattributes changes

## Current Status

❓ **Test Status: FAILING**

The test is currently failing, which could indicate:
1. The git binary needs to be rebuilt with the patch
2. The patch might need adjustments
3. There may be additional conditions required for the fix to work

**Output:**
```
After checkout commit1: tag=IBM-1047
✗ FAIL: Expected ISO8859-1, got IBM-1047
```

This shows the file is getting IBM-1047 tag even at commit1 which specifies ISO8859-1, suggesting the attribute cache issue.

## Integration

This test has been added to the tests/ directory and will be automatically run by `run_all_tests.sh` and integrated into `zopen_check_results`.

## Related Files

- `stable-patches/unpack-trees.c.patch` - The fix being tested
- `tests/test_pull_encoding_tag_fix.sh` - This test
- `git/unpack-trees.c` - Where the patch is applied (after build)
