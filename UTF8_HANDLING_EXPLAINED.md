# UTF-8 Handling in Your Configuration

## Your Configuration

```gitattributes
# Default attributes if not otherwise stated specified
*   zos-working-tree-encoding=ibm-1047
```

## What Happens

### Scenario 1: Your Current Setup (IBM-1047) ✅

```gitattributes
*   zos-working-tree-encoding=ibm-1047
```

**Result:**
- Files are checked out and **tagged as IBM-1047** ✅
- **WORKS PERFECTLY!**
- This is your default and it works great!

### Scenario 2: If You Use UTF-8 ⚠️

```gitattributes
*   zos-working-tree-encoding=UTF-8
```

**Result:**
- Files are checked out and **tagged as ISO8859-1** ❌
- **This is the BUG!**
- Should be UTF-8, but Git incorrectly tags as ISO8859-1

## Detailed Explanation

### What Git Does When Checking Out

```
Repository (Git)           Working Tree (z/OS)
─────────────────          ───────────────────

UTF-8 (always)      ────▶  zos-working-tree-encoding
                   convert
                   
                   then tag file with CCSID
```

### With IBM-1047 (YOUR CASE) ✅

```
Step 1: Read from repo     → UTF-8 blob
Step 2: Convert            → UTF-8 to IBM-1047 
Step 3: Write to disk      → EBCDIC bytes
Step 4: Tag file           → chtag IBM-1047 ✓ CORRECT!

Result: Perfect! ✅
```

### With UTF-8 (PROBLEMATIC CASE) ⚠️

```
Step 1: Read from repo     → UTF-8 blob
Step 2: Convert            → UTF-8 to UTF-8 (no conversion needed)
Step 3: Write to disk      → UTF-8 bytes
Step 4: Tag file           → chtag ISO8859-1 ❌ WRONG!
                              Should be: UTF-8

Result: Wrong tag, but ASCII works! ⚠️
```

## Impact on Your Configuration

### Your Default (`ibm-1047`)

**Status:** ✅ **WORKS PERFECTLY!**

```gitattributes
*   zos-working-tree-encoding=ibm-1047
```

All files will be:
- ✅ Checked out as EBCDIC (IBM-1047)
- ✅ Tagged correctly as IBM-1047
- ✅ No issues at all!

### If You Need UTF-8 Files

**Problem:** Files get tagged as ISO8859-1 instead of UTF-8

**Impact:**

#### For ASCII Files (Most Common) ✅
```
Content: "Hello World\n"
Tagged as: ISO8859-1 (wrong, but...)
Result: WORKS FINE!

Why? ASCII (0x00-0x7F) is identical in both:
  'H' = 0x48 in ISO8859-1 = 0x48 in UTF-8
  'e' = 0x65 in ISO8859-1 = 0x65 in UTF-8
```

#### For Unicode Files (Rare) ⚠️
```
Content: "Café\n" (with é = U+00E9)
Tagged as: ISO8859-1 (wrong!)
Result: MIGHT CORRUPT!

Why? Different encodings:
  é = 0xE9 in ISO8859-1 (1 byte)
  é = 0xC3 0xA9 in UTF-8 (2 bytes)
  
When Git reads back:
  Reads as ISO8859-1 → Gets wrong character!
```

## Recommendations

### Option 1: Keep Your Current Setup (RECOMMENDED) ✅

```gitattributes
*   zos-working-tree-encoding=ibm-1047
```

**Advantages:**
- ✅ Works perfectly
- ✅ Correct for EBCDIC mainframe files
- ✅ No bugs
- ✅ Standard z/OS practice

**Use when:** Most of your files are EBCDIC

### Option 2: Mixed Setup (Advanced)

```gitattributes
# Default to EBCDIC
*                   zos-working-tree-encoding=ibm-1047

# But some files are UTF-8
*.md                zos-working-tree-encoding=UTF-8
*.json              zos-working-tree-encoding=UTF-8
docs/**             zos-working-tree-encoding=UTF-8
```

**Impact:**
- ✅ Most files (IBM-1047): Work perfectly
- ⚠️ UTF-8 files: Tagged as ISO8859-1 (bug)
  - ASCII content: Works fine
  - Unicode content: Might corrupt

**Workaround for UTF-8 files:**
If they're ASCII-only, use ISO8859-1 instead:

```gitattributes
*.md                zos-working-tree-encoding=ISO8859-1
*.json              zos-working-tree-encoding=ISO8859-1
```

### Option 3: All UTF-8 (Not Typical for z/OS)

```gitattributes
*   zos-working-tree-encoding=UTF-8
```

**Impact:**
- ⚠️ All files tagged as ISO8859-1 (bug)
- ✅ ASCII files: Work fine
- ⚠️ Unicode files: Might corrupt

**Not recommended for z/OS!** Use IBM-1047 for mainframe files.

## What Should You Do?

### For Your Case (Default ibm-1047)

**Answer: NOTHING! You're already correct!** ✅

Your configuration:
```gitattributes
*   zos-working-tree-encoding=ibm-1047
```

This is **perfect** for z/OS! No issues, no bugs, works great!

### If You Need Some UTF-8 Files

**Two options:**

#### Option A: ASCII-only UTF-8 files (SAFE)
```gitattributes
*                   zos-working-tree-encoding=ibm-1047
*.md                zos-working-tree-encoding=ISO8859-1  # ASCII docs
*.json              zos-working-tree-encoding=ISO8859-1  # ASCII data
```
Works perfectly for ASCII content! ✅

#### Option B: Real UTF-8 with Unicode (RISKY)
```gitattributes
*                   zos-working-tree-encoding=ibm-1047
*.md                zos-working-tree-encoding=UTF-8  # Has Unicode!
```
Files tagged as ISO8859-1 instead of UTF-8 ⚠️
- ASCII parts: Work fine
- Unicode parts: Might corrupt

## Testing Your Setup

Test if a file works correctly:

```bash
# 1. Create test file
echo "Test content" > test.txt

# 2. Add and commit
git add test.txt
git commit -m "Test"

# 3. Check out and verify tag
rm test.txt
git checkout test.txt
chtag -p test.txt

# Expected with your config:
#   t IBM-1047    T=on  test.txt  ✓ CORRECT!
```

## Summary

| Configuration | File Tag | Works? | Notes |
|---------------|----------|--------|-------|
| **ibm-1047** (yours) | IBM-1047 | ✅ YES | **Perfect! Use this!** |
| UTF-8 | ISO8859-1 ❌ | ⚠️ Partial | Bug: wrong tag, ASCII works |
| ISO8859-1 | ISO8859-1 | ✅ YES | Good for ASCII files |
| (none) | ISO8859-1 | ✅ YES | Default behavior |

## Final Answer for Your Case

**You're using IBM-1047, which works perfectly!** ✅

The UTF-8 bug **doesn't affect you** because you're using IBM-1047 as your default.

The bug only happens if someone explicitly sets `zos-working-tree-encoding=UTF-8`, which you're not doing.

**Your configuration is great! Keep it!** 🎉

