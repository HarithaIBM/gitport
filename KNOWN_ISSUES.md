# Known Issues - To Be Addressed Separately

## 1. git stash push <file> - Wrong Encoding Tag

**Status:** Not fixed (out of scope for current review)

**Symptom:**
```bash
git stash push path/to/file.txt
# File is restored with wrong encoding tag
# Content is correct (IBM-1047) but tag says ISO8859-1
```

**Workaround:**
```bash
# Use git stash push (without file argument)
git stash push

# Or retag manually after stash
git stash push path/to/file.txt
chtag -t -c IBM-1047 path/to/file.txt
```

**Root Cause:**
When stashing a specific file, `git stash` uses `git apply --index -R` internally to restore the working tree. This subprocess doesn't properly consult the `.gitattributes` file for encoding information.

**Files Involved:**
- `builtin/stash.c` - stash implementation
- `apply.c` - apply logic (subprocess)
- Attribute cache invalidation

**Why Not Fixed Yet:**
- Requires investigation of subprocess attribute cache
- Different code path than the 14 issues fixed in this review
- Needs testing of stash-specific workflows
- Out of scope for the current encoding fixes

**Impact:**
- **Low** - only affects `git stash push <specific-file>`
- `git stash push` (all files) works fine
- `git stash pop` works fine
- File content is correct, only tag is wrong
- Easy workaround (retag manually)

**Tracking:**
- GitHub issue: [link to issue]
- Will be addressed in separate PR

---

## Summary

All 14 critical issues from the review have been fixed.

This additional issue was discovered during testing and will be addressed separately.

