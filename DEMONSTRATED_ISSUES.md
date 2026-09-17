# Demonstrated File Tagging Issues - Live Results

## Test Execution Results

**Date:** 2024
**System:** z/OS USS
**Git Version:** 2.55.0

---

## Results Summary

| Command | Expected Tag | Actual Tag | Status |
|---------|--------------|------------|--------|
| git merge-file | IBM-1047 | ISO8859-1 | ❌ **FAILS** |
| git diff --output | IBM-1047 | ISO8859-1 | ❌ **FAILS** |
| git apply | IBM-1047 | - | ⚠️ Apply failed (test issue) |
| git rebase | IBM-1047 | IBM-1047 | ✅ **WORKS** |

---

## Test 1: git merge-file ❌ CONFIRMED BUG

### Command Used:
```bash
echo "base content" > base.txt
echo "our content" > ours.txt
echo "their content" > theirs.txt
git merge-file ours.txt base.txt theirs.txt
chtag -p ours.txt
```

### Result:
```
t ISO8859-1   T=on  ours.txt
```

### Issue:
- **Expected:** IBM-1047 (per .gitattributes)
- **Actual:** ISO8859-1
- **Impact:** Files incorrectly tagged, may cause encoding issues

### Root Cause:
- Code uses `fopen()` / `fwrite()` directly
- No z/OS tagging applied
- Located in: `builtin/merge-file.c`

### Severity: HIGH
User-facing command that directly creates files.

---

## Test 2: git diff --output ❌ CONFIRMED BUG

### Command Used:
```bash
echo "version 1" > file.txt
git add file.txt && git commit -m "V1"
echo "version 2" > file.txt
git add file.txt && git commit -m "V2"
git diff HEAD~1 HEAD --output=my.diff
chtag -p my.diff
```

### Result:
```
t ISO8859-1   T=on  my.diff
```

### Issue:
- **Expected:** IBM-1047 (per .gitattributes: *.diff)
- **Actual:** ISO8859-1
- **Impact:** Diff files incorrectly tagged

### Root Cause:
- Code uses `xfopen()` / writes directly
- No z/OS tagging applied
- Located in: `diff.c` line ~5848

### Severity: MEDIUM
Less commonly used, but affects diff file storage.

---

## Test 3: git apply ⚠️ TEST ISSUE

### Command Used:
```bash
echo "original line 1" > test.txt
echo "original line 2" >> test.txt
git add test.txt && git commit -m "Original"
echo "modified line 1" > test.txt
echo "original line 2" >> test.txt
git diff > /tmp/test.patch
git checkout test.txt
git apply /tmp/test.patch
```

### Result:
```
✗ Apply failed (may be test issue)
```

### Analysis:
- Apply failed due to patch format issue
- **Likely works correctly** when patch is valid
- Uses apply mechanism (same as `git am` which works)
- **Needs better test to confirm**

### Severity: UNKNOWN
Likely not an issue, needs verification.

---

## Test 4: git rebase ✅ WORKS CORRECTLY

### Command Used:
```bash
echo "base content" > file.txt
git add file.txt && git commit -m "Base"
git checkout -b feature
echo "feature content" > file.txt
git add file.txt && git commit -m "Feature"
git checkout master
echo "other content" > other.txt
git add other.txt && git commit -m "Other"
git checkout feature
git rebase master
chtag -p file.txt
```

### Result:
```
t IBM-1047    T=on  file.txt
✓ PASS: Correctly tagged as IBM-1047
```

### Analysis:
- **Works correctly!** ✅
- Uses checkout mechanism internally
- Checkout mechanism already has z/OS tagging
- No fix needed

### Severity: NONE
Command works as expected.

---

## Confirmed Issues

### Issues Needing Fixes: 2

1. **git merge-file** ❌
   - Severity: HIGH
   - Status: Confirmed bug
   - Fix needed: Add z/OS tagging after write

2. **git diff --output** ❌
   - Severity: MEDIUM
   - Status: Confirmed bug
   - Fix needed: Add z/OS tagging after write

### Issues Working Correctly: 1

1. **git rebase** ✅
   - Status: Works correctly
   - No fix needed

### Issues Uncertain: 1

1. **git apply** ⚠️
   - Status: Test failed (likely works)
   - Needs: Better test to verify

---

## Pattern Analysis

### Commands That Fail:
Both use **direct file I/O**:

```c
// builtin/merge-file.c
FILE *f = fopen(filename, "w");
fwrite(result.ptr, result.size, 1, f);
fclose(f);
// ❌ No tagging!
```

```c
// diff.c
options->file = xfopen(path, "w");
// ... write data ...
// ❌ No tagging!
```

### Commands That Work:
Use **Git's standard paths**:

```c
// via checkout mechanism
checkout_entry(...);  // Has tagging ✓
```

---

## Fix Approach

Both issues can be fixed the same way we fixed `rerere`:

```c
#ifdef __MVS__
    int fd = fileno(f);
    if (fd >= 0) {
        __setfdbinary(fd);
        __disableautocvt(fd);
    }
#endif

// ... write data ...

#ifdef __MVS__
    if (fd >= 0)
        tag_file_as_working_tree_encoding(istate, path, fd, 1);
#endif
```

---

## Recommendations

### Priority 1: Fix git merge-file
- **Impact:** HIGH - User-facing command
- **Effort:** LOW - Same pattern as rerere fix
- **Risk:** LOW - Isolated change

### Priority 2: Fix git diff --output
- **Impact:** MEDIUM - Less common, but useful
- **Effort:** LOW - Same pattern as rerere fix
- **Risk:** LOW - Isolated change

### Priority 3: Verify git apply
- **Impact:** LOW - Likely already works
- **Effort:** LOW - Just need better test
- **Risk:** NONE - Just verification

---

## Next Steps

1. ✅ **Done:** Demonstrated and confirmed issues
2. ⏭️ **Next:** Fix git merge-file
3. ⏭️ **Next:** Fix git diff --output
4. ⏭️ **Next:** Create better test for git apply
5. ⏭️ **Next:** Update patches and test suite

---

## Documentation

This demonstration confirms:
- ✅ 2 real bugs (merge-file, diff --output)
- ✅ 1 working command (rebase)
- ⚠️ 1 uncertain (apply - likely works)

Both confirmed bugs follow the same pattern and can be fixed similarly.

