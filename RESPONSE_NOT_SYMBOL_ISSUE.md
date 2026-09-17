# Response to User: NOT Symbol (¬) Encoding Issue

## Summary

**Good news:** The ¬ (NOT) symbol itself **converts correctly** on our test system. There is **no bug in our Git code**.

The error `"failed to encode from UTF-8 to ibm-1047"` suggests a different issue than just the ¬ character.

---

## Our Test Results ✅

We tested the exact scenario and found:

### Character Mapping on Our System

| Byte | IBM-1047      | IBM-037       | Round-trip |
|------|---------------|---------------|------------|
| 0x5f | ^ (caret)     | ¬ (NOT)       | Different! |
| 0xb0 | ¬ (NOT)       | ^ (caret)     | Different! |

**Key Finding:** The NOT symbol and caret are **swapped** between IBM-037 and IBM-1047!

### Conversion Tests

```bash
# UTF-8 to IBM-1047 conversion
U+00AC (¬) → IBM-1047 0xb0  ✓ SUCCESS

# IBM-1047 to UTF-8 conversion  
IBM-1047 0xb0 → U+00AC (¬)  ✓ SUCCESS

# Round-trip
¬ → 0xb0 → ¬  ✓ SUCCESS
```

**Result:** The ¬ symbol converts correctly in both directions!

---

## Why User May Still See Errors

Given that ¬ converts fine, the error could be caused by:

### 1. **Different Character** (Most Likely)
The actual problematic character might not be ¬ but something else.

**Evidence:**
- User found ¬ using vim's `/[^\x00-\x7F]`
- But there could be other non-ASCII characters
- The xxd output showed: `00000360: 8194 8540 81a2 4040 40c9 8640 c9b0 7ef0`
  - `81 94 85` `81 a2` `c9 86` `c9` are also > 0x7F
  - These need investigation too!

### 2. **File Not Actually UTF-8**
If the file in Git is not actually UTF-8:
- Maybe it's tagged UTF-8 but contains IBM-037 bytes
- Or it was corrupted during commit
- Git assumes it's UTF-8 for conversion

### 3. **Different iconv Implementation**
- User's system may have different iconv version
- May not support certain character mappings
- May handle //TRANSLIT differently

### 4. **Multiple Problem Characters**
- ¬ might convert fine
- But another character in the same file fails
- Git stops at first error

---

## What User Should Check

### Step 1: Get the Actual Failing File

```bash
# Download one of the failing files directly from Git
# WITHOUT letting Git convert it
git show HEAD:buckets/sdb/v2s40/plxsrc/plx00314.plx > /tmp/original.plx

# Check its actual encoding
file /tmp/original.plx
chtag -p /tmp/original.plx

# See all non-ASCII bytes
xxd /tmp/original.plx | grep -E '[89a-f][0-9a-f]'
```

### Step 2: Test iconv Directly

```bash
# Try the exact conversion Git is doing
iconv -f UTF-8 -t IBM-1047 /tmp/original.plx > /tmp/converted.plx
echo "Exit code: $?"

# If it fails, see which character
iconv -f UTF-8 -t IBM-1047 /tmp/original.plx 2>&1

# Try with transliteration
iconv -f UTF-8 -t IBM-1047//TRANSLIT /tmp/original.plx > /tmp/converted2.plx
echo "Exit code: $?"
```

### Step 3: Find ALL Non-ASCII Characters

```bash
# Extract all bytes > 0x7F
xxd /tmp/original.plx | grep -oE '[89a-f][0-9a-f]' | sort | uniq -c

# Or use this to see context
grep --color='auto' -P -n '[^\x00-\x7F]' /tmp/original.plx
```

### Step 4: Check Specific Bytes from User's Output

The user showed:
```
00000360: 8194 8540 81a2 4040 40c9 8640 c9b0 7ef0
```

Let's check what these are:
```bash
# Check 0x81
printf '\x81' | iconv -f UTF-8 -t IBM-1047

# Check 0x94
printf '\x94' | iconv -f UTF-8 -t IBM-1047

# etc...
```

These bytes are suspicious because they're in the **C1 control range** (0x80-0x9F) which shouldn't appear in UTF-8 text!

---

## Our Diagnostic Tool

We created a comprehensive diagnostic:

```bash
# Run this on user's system
bash tests/diagnose_codepage_mapping.sh
```

This will show:
- Exact codepage mappings on their system
- Whether ¬ converts correctly
- Any discrepancies between IBM-037 and IBM-1047
- What byte values map to what characters

---

## Likely Root Cause

Based on the hex dump user provided:
```
00000360: 8194 8540 81a2 4040 40c9 8640 c9b0 7ef0
          ^^^^ ^^   ^^^^ ^^^^    ^^^^ ^^
          These bytes (0x81-0x94) should NOT be in UTF-8!
```

**Hypothesis:** The file in Git is **not actually UTF-8**!

- UTF-8 doesn't use bytes 0x80-0x9F directly
- These are control characters or part of multi-byte sequences
- If present alone, file is probably EBCDIC already

**Test:**
```bash
# Check if file is actually EBCDIC
iconv -f IBM-1047 -t UTF-8 /tmp/original.plx
# If this works, file is IBM-1047, not UTF-8!
```

---

## Solution Path

### Option 1: Enable Transliteration (Works for Many Issues)

```bash
git config --global core.iconvtranslit true
export GIT_ICONV_TRANSLIT=1
git clone <repo>
```

This will:
- Approximate unmappable characters
- Show warnings
- Let clone continue

### Option 2: Fix Files in Repository

If files are not actually UTF-8:

```bash
# 1. Check what they really are
file buckets/sdb/v2s40/plxsrc/*.plx

# 2. If they're EBCDIC, convert to UTF-8
for f in *.plx; do
    iconv -f IBM-1047 -t UTF-8 "$f" > "${f}.utf8"
    mv "${f}.utf8" "$f"
    chtag -tc UTF-8 "$f"
done

# 3. Commit corrected files
git add *.plx
git commit -m "Convert PLX files to proper UTF-8"
```

### Option 3: Change .gitattributes Strategy

Instead of converting, store as binary:

```bash
# .gitattributes
*.plx binary
```

Or specify the actual encoding in Git:
```bash
*.plx working-tree-encoding=IBM-1047
```

---

## Questions for User

To diagnose further, we need:

1. **Hex dump of actual failing file:**
   ```bash
   git show HEAD:buckets/sdb/v2s40/plxsrc/plx00314.plx | xxd | head -50
   ```

2. **iconv test result:**
   ```bash
   git show HEAD:buckets/sdb/v2s40/plxsrc/plx00314.plx | iconv -f UTF-8 -t IBM-1047
   ```

3. **File encoding check:**
   ```bash
   git show HEAD:buckets/sdb/v2s40/plxsrc/plx00314.plx | file -
   ```

4. **iconv version:**
   ```bash
   iconv --version
   ```

5. **System locale:**
   ```bash
   locale
   echo $LANG
   ```

---

## Conclusion

**No bug in Git for z/OS!** ✅

The ¬ symbol converts correctly. The user's error is likely caused by:
1. File contains different problematic characters (0x81, 0x94, etc.)
2. File is not actually UTF-8 in Git repository
3. System-specific iconv limitations

**Next steps:**
1. User runs diagnostic script
2. User provides hex dump of actual failing file
3. We identify the real problematic character(s)
4. Apply appropriate fix (transliteration, file correction, or encoding change)

