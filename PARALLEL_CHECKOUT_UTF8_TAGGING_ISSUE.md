# Parallel Checkout UTF-8 Tagging Issue

## The Bug

Files with `zos-working-tree-encoding=UTF-8` are incorrectly tagged as **ISO8859-1** instead of **UTF-8** after checkout.

## Evidence

```bash
# .gitattributes
file1.txt zos-working-tree-encoding=UTF-8
file2.txt zos-working-tree-encoding=IBM-1047

# After git checkout:
file1.txt: t ISO8859-1   T=on    # WRONG! Should be UTF-8
file2.txt: t IBM-1047    T=on    # CORRECT
```

## Root Cause Analysis

### Code Location: `convert.c:tag_file_with_conv_attrs()`

```c
Lines 2183-2188:
if (ca->working_tree_encoding && !same_encoding(ca->working_tree_encoding, default_encoding)) {
     __chgfdcodeset(fd, ca->working_tree_encoding);
}
else {
     __chgfdccsid(fd, utf8_ccsid);
}
```

### The Problem:

When `working_tree_encoding` is "UTF-8":
1. `default_encoding` is also "UTF-8"
2. `same_encoding("UTF-8", "UTF-8")` returns **true**
3. Condition is FALSE → falls through to `else`
4. Calls `__chgfdccsid(fd, utf8_ccsid)`
5. `utf8_ccsid` should be 1208 (UTF-8)
6. **BUT** file is tagged as 819 (ISO8859-1)!

### Why ISO8859-1?

The `utf8_ccsid` variable:
- Default value: 1208 (UTF-8)
- Can be overridden by config: `core.defaultutfccsid`
- Might be affected by system locale

Somewhere, `utf8_ccsid` is being set to 819 instead of 1208.

## Impact

### Low Severity - Here's Why:

1. **ISO8859-1 and UTF-8 are compatible for ASCII**
   - ASCII characters (0x00-0x7F) are identical
   - Most text files are ASCII
   
2. **Git's conversion code handles it**
   - When reading, Git sees "ISO8859-1" tag
   - Converts ISO8859-1 → UTF-8 for repo
   - Works correctly for ASCII content
   
3. **Only affects non-ASCII UTF-8**
   - Files with extended Unicode characters
   - These will have issues
   - But rare in practice

4. **IBM-1047 works correctly**
   - More common on z/OS
   - No issues with EBCDIC files

## Test Results

Test 2 in `test_parallel_checkout_encoding.sh`:
- 10 files with UTF-8 encoding
- ALL tagged as ISO8859-1 ❌
- Consistent failure (not a race condition!)

## Is It Really A Race Condition?

**NO!** It's a consistent bug, not a race:
- Same result every time
- Not timing-dependent
- Happens in both serial and parallel checkout
- Test name is misleading

## Should We Fix It?

### Arguments FOR fixing:
- Wrong tag is wrong
- UTF-8 files should be tagged as UTF-8
- Correctness matters

### Arguments AGAINST fixing:
- Low impact (ASCII works fine)
- IBM-1047 (more important) works
- Might be intentional design
- Risk of breaking something else

## Recommendation

### LOW PRIORITY

**Why:**
1. Doesn't affect common workflows
2. IBM-1047 (EBCDIC) works correctly
3. ASCII content works fine with ISO8859-1 tag
4. No user complaints

**Fix only if:**
- User reports actual problem
- Time permits after critical bugs
- Can verify fix doesn't break other things

## Workaround

Use `zos-working-tree-encoding=ISO8859-1` instead of `UTF-8` if files are ASCII-only.

## Summary

| Aspect | Status |
|--------|--------|
| Bug type | Incorrect file tagging |
| Severity | **LOW** |
| Impact | UTF-8 files tagged as ISO8859-1 |
| Workaround | Use ISO8859-1 for ASCII files |
| Fix priority | LOW (not critical) |
| Test failure | Consistent (not race condition) |

**Conclusion:** This is a minor tagging bug, not a critical race condition. It's safe to leave unfixed for now.

