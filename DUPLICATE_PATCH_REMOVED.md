# Duplicate Patch Removed

## Issue
Build was failing because TWO patches were trying to modify convert.c:
1. `convert.c.patch` (newer, correct)
2. `convert_c_no_tag_on_error.patch` (older, superseded)

## Analysis

### convert.c.patch (KEPT) ✅
- **Timestamp:** Sep 28 06:04
- **Size:** 17,824 bytes
- **Contains:**
  - ✅ Parallel checkout race fix (uses ca->attr_action)
  - ✅ Platform-specific encode_to_git (#ifdef __MVS__)
  - ✅ Fixed UTF-8 arrows (-> not →)
  - ✅ No trailing whitespace
  - ✅ Updated hunk headers (+7 adjustment)

### convert_c_no_tag_on_error.patch (DELETED) ❌
- **Timestamp:** Sep 28 01:32 (older)
- **Size:** 17,926 bytes
- **Status:** UNTRACKED (never committed to git)
- **Problems:**
  - ❌ Used #if 0 (global disable, not platform-specific)
  - ❌ Old hunk headers (not adjusted)
  - ❌ Had trailing whitespace
  - ❌ Not referenced anywhere in the project

## Verification

All fixes are present in `convert.c.patch`:

```bash
✅ Fix 1: Parallel checkout race
   - Line 468: Uses ca->attr_action
   - No git_check_attr() call

✅ Fix 2: Platform-specific encode_to_git
   - Line 328-341: #ifdef __MVS__ / #else / #endif

✅ Fix 3: UTF-8 arrows fixed
   - Line 333: Uses "->" not "→"

✅ Fix 4: No trailing whitespace
   - All + lines clean

✅ Fix 5: Hunk headers updated
   - All headers adjusted for +7 line change
```

## Action Taken

```bash
rm stable-patches/convert_c_no_tag_on_error.patch
```

## Result

Only one convert.c patch remains:
- `stable-patches/convert.c.patch` (17,824 bytes)
- `stable-patches/convert.h.patch` (631 bytes)

Build should now succeed without patch conflicts.
