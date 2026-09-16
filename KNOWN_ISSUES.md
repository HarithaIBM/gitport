# Known Issues - Status

## 1. git stash push <file> - Wrong Encoding Tag

**Status:** ✅ **FIXED** (commit 15184c8)

**Original Symptom:**
```bash
git stash push path/to/file.txt
# File was restored with wrong encoding tag
# Content correct (IBM-1047) but tag said ISO8859-1
```

**Root Cause:**
`apply.c` was using `GIT_ATTR_CHECKIN` direction instead of `GIT_ATTR_CHECKOUT`.

- `GIT_ATTR_CHECKIN` = reading FROM working tree (for git add)
- `GIT_ATTR_CHECKOUT` = writing TO working tree (for git apply, git checkout)

When `git stash push <file>` internally calls `git apply --index -R`, it needs
CHECKOUT direction to properly read `.gitattributes` and tag files correctly.

**The Fix:**
Changed `git_attr_set_direction(GIT_ATTR_CHECKIN)` to `GIT_ATTR_CHECKOUT` in
`apply.c`.

**Files Changed:**
- `stable-patches/apply.c.patch`
- `git/apply.c`

**Impact:**
✅ `git stash push <file>` now correctly tags files per `.gitattributes`
✅ `git apply` operations now use correct attribute direction
✅ File encoding tags are correct

**Testing:**
```bash
# Should now work correctly
git stash push path/to/file.txt
chtag -p path/to/file.txt
# Should show IBM-1047 (not ISO8859-1)
```

---

## Summary

All known issues have been fixed! ✅

Total fixes: **15 critical issues**
- 14 from original review
- 1 additional (git stash push)

