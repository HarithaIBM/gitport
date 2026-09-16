# Fix for unpack-trees Parallel Checkout Timing Issue

## The Problem

When `git pull` or `git checkout` changes `.gitattributes`, files were being tagged with the **OLD** encoding instead of the **NEW** encoding from the updated `.gitattributes`.

### Why It Happened

The original two-pass approach had a race condition with parallel checkout:

```c
// Pass 1: Checkout .gitattributes files
for (i = 0; i < index->cache_nr; i++) {
    if (is_gitattributes(ce)) {
        checkout_entry(ce, &state, ...);  // ← QUEUES file, doesn't write yet!
        gitattributes_updated = 1;
    }
}

// Invalidate cache (but .gitattributes still queued!)
if (gitattributes_updated) {
    git_attr_set_direction(GIT_ATTR_INDEX);      // ← File not on disk yet!
    git_attr_set_direction(GIT_ATTR_CHECKOUT);   // ← Still using OLD attributes!
}

// Pass 2: Checkout other files (uses OLD attributes!)
for (i = 0; i < index->cache_nr; i++) {
    if (!is_gitattributes(ce)) {
        checkout_entry(ce, &state, ...);  // ← Tagged with OLD encoding!
    }
}

// NOW the queue is flushed (too late!)
run_parallel_checkout(&state, ...);
```

### Timeline of the Bug

```
T1: .gitattributes queued (not written)
T2: Cache invalidated (reads from disk - gets OLD file!)
T3: Other files tagged (using OLD attributes)
T4: Parallel checkout flushes queue
T5: .gitattributes finally written (too late!)
```

## The Fix

Add a `run_parallel_checkout()` call **BETWEEN** the two passes:

```c
// Pass 1: Checkout .gitattributes files
for (i = 0; i < index->cache_nr; i++) {
    if (is_gitattributes(ce)) {
        checkout_entry(ce, &state, ...);  // ← Queues file
        gitattributes_updated = 1;
    }
}

// FLUSH THE QUEUE - write .gitattributes NOW!
if (gitattributes_updated && pc_workers > 1) {
    run_parallel_checkout(&state, pc_workers, pc_threshold, progress, &cnt);
}

// NOW invalidate cache (file is on disk!)
if (gitattributes_updated) {
    git_attr_set_direction(GIT_ATTR_INDEX);      // ← Reads NEW file!
    git_attr_set_direction(GIT_ATTR_CHECKOUT);   // ← Uses NEW attributes!
}

// Pass 2: Checkout other files (uses NEW attributes!)
for (i = 0; i < index->cache_nr; i++) {
    if (!is_gitattributes(ce)) {
        checkout_entry(ce, &state, ...);  // ← Tagged with NEW encoding! ✓
    }
}
```

### Timeline of the Fix

```
T1: .gitattributes queued
T2: Queue flushed - .gitattributes written to disk ✓
T3: Cache invalidated (reads NEW file) ✓
T4: Other files tagged (using NEW attributes) ✓
```

## Test Results

Before fix:
```bash
$ ./tests/test_pull_encoding_tag_fix.sh
FAIL: file.txt has wrong tag after checkout
Expected: IBM-1047, Got: ISO8859-1
```

After fix:
```bash
$ ./tests/test_pull_encoding_tag_fix.sh
✓ All tests passed
```

## Code Changed

**File:** `stable-patches/unpack-trees.c.patch`

**Change:** Added flush between passes:

```diff
+	/*
+	 * Flush parallel checkout queue to ensure .gitattributes files
+	 * are actually written to disk before we invalidate the cache.
+	 */
+	if (gitattributes_updated && pc_workers > 1) {
+		errs |= run_parallel_checkout(&state, pc_workers, pc_threshold,
+					      progress, &cnt);
+	}
+
 	/*
 	 * Invalidate attribute cache NOW, after .gitattributes are checked out
```

## Why This Works

1. **Queued files are flushed** - `run_parallel_checkout()` writes all queued files to disk
2. **Cache reads from disk** - When invalidated, it reads the NEW .gitattributes  
3. **Other files use new cache** - Second pass tags files with correct encoding

## Edge Cases Handled

- ✅ Single-threaded checkout (no queue, works as before)
- ✅ Parallel checkout enabled (queue flushed at right time)
- ✅ Multiple .gitattributes files (all flushed before cache invalidation)
- ✅ No .gitattributes changes (no flush, no overhead)

## Related Issues

This fix resolves:
- Copilot comment: "unpack-trees.c.patch:40" - parallel checkout timing
- Test failure: `test_pull_encoding_tag_fix.sh`
- Regression: Files tagged with wrong encoding after pull

