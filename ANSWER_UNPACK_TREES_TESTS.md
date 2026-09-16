# Answer: Tests for stable-patches/unpack-trees.c.patch

## Summary

**NO**, there were no existing tests for the issue fixed in `stable-patches/unpack-trees.c.patch`.

## What I Did

I created a new test: **`tests/test_pull_encoding_tag_fix.sh`**

This test specifically verifies the fix for the git pull encoding tag bug with attribute cache invalidation.

## The Issue Being Fixed

The patch in `stable-patches/unpack-trees.c.patch` fixes a bug where:

1. During `git pull` or `git checkout`, if `.gitattributes` is updated with new encoding specifications
2. Files don't get re-tagged with the correct encoding
3. This happens because the attribute cache isn't invalidated when `.gitattributes` changes

### The Fix

The patch adds code to:
- Track when `.gitattributes` files are being checked out
- Invalidate the attribute cache by calling `git_attr_set_direction()` 
- Ensure subsequent file tagging uses the new attributes

```c
#ifdef __MVS__
if (gitattributes_updated) {
    git_attr_set_direction(GIT_ATTR_INDEX);
    git_attr_set_direction(GIT_ATTR_CHECKOUT);
}
#endif
```

## Test Coverage

The new test includes 3 scenarios:

### Test 1: Simple Encoding Change
- Checkout between commits where `.gitattributes` changes file encoding from ISO8859-1 to IBM-1047
- Verifies file is correctly retagged

### Test 2: Multiple Files  
- Tests with 3 files having different encodings, then all changing to IBM-1047
- Verifies all files get retagged correctly

### Test 3: Subdirectory .gitattributes
- Tests adding a subdirectory `.gitattributes` file
- Verifies subdirectory attributes override root attributes correctly

## Current Test Results

```
TAP version 13
1..5
ok 1 - basicclone
ok 2 - stepwiseclone
ok 3 - test_3way_merge_encodings
not ok 4 - test_pull_encoding_tag_fix     ← NEW TEST (currently failing)
ok 5 - testtags
# Tests run: 5
# Passed: 4
# Failed: 1
```

## Why Is The Test Failing?

The test is currently **FAILING**, which indicates the attribute cache invalidation fix may not be working as expected. This could be because:

1. The git binary needs to be rebuilt with the patch applied
2. The patch may need additional adjustments
3. There might be other conditions needed for the fix to work properly

The failing test serves as a **regression test** - once the issue is properly fixed, this test will pass and prevent the bug from being reintroduced.

## Documentation

Created additional documentation:
- `tests/TEST_PULL_ENCODING_FIX.md` - Detailed documentation of the test and the fix

## Files Created/Modified

- ✅ `tests/test_pull_encoding_tag_fix.sh` - New test for the patch
- ✅ `tests/TEST_PULL_ENCODING_FIX.md` - Documentation  
- ✅ Test is integrated into `run_all_tests.sh` and `zopen_check_results`
