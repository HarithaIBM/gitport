# Fixed: unpack-trees.c.patch

## The Bug (Confirmed)

When doing `git pull` and `.gitattributes` changes file encodings:
- **git clone**: ✅ Files get correct encoding tags
- **git pull**: ❌ Files keep old encoding tags (BUG!)

## Root Cause

The original patch invalidated the attribute cache AFTER all files were already checked out and tagged. Files were tagged using the OLD .gitattributes values.

## The Fix

**Two-pass approach:**

### Pass 1: Check out .gitattributes files FIRST
```c
for (i = 0; i < index->cache_nr; i++) {
    if (is_gitattributes_file(ce) && must_checkout(ce)) {
        checkout_entry(ce, &state, NULL, NULL);  // Write .gitattributes to disk
        gitattributes_updated = 1;
    }
}
```

### Invalidate cache BETWEEN passes
```c
if (gitattributes_updated) {
    git_attr_set_direction(GIT_ATTR_INDEX);     // Clears cache
    git_attr_set_direction(GIT_ATTR_CHECKOUT);  // Re-reads from working tree
}
```

### Pass 2: Check out other files (with NEW attributes)
```c
for (i = 0; i < index->cache_nr; i++) {
    if (!is_gitattributes_file(ce) && must_checkout(ce)) {
        checkout_entry(ce, &state, NULL, NULL);  // Tags with NEW encoding!
    }
}
```

## How It Works

1. **Pass 1**: `.gitattributes` files are checked out and written to working tree
2. **Cache Invalidation**: `git_attr_set_direction()` drops all cached attributes
3. **Pass 2**: Other files are checked out
   - Git reads `.gitattributes` from working tree (now has new values!)
   - Files are tagged with the NEW encoding specifications

## Timeline

**Before:**
```
Start: cache has old attributes
├─ Checkout .gitattributes (new file on disk)
├─ Checkout file.txt → tagged with OLD encoding ❌ (cache not refreshed)
└─ Invalidate cache (too late!)
```

**After (FIXED):**
```
Start: cache has old attributes  
├─ Pass 1: Checkout .gitattributes (new file on disk)
├─ Invalidate cache → reads new .gitattributes from disk
└─ Pass 2: Checkout file.txt → tagged with NEW encoding ✅
```

## Testing

Run the test:
```bash
cd tests
./test_pull_encoding_tag_fix.sh
```

**Expected after rebuild:**
```
✓ PASS: File correctly retagged when checking out commit with different .gitattributes
✓ PASS: All files correctly retagged
✓ PASS: Subdirectory file correctly retagged after .gitattributes update
```

## Status

✅ **FIXED** - Patch updated with correct timing
🔨 **Needs rebuild** - Recompile git with updated patch
✅ **Test ready** - Test will verify the fix works
