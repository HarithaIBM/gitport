# Unicode Unmappable Characters Issue on z/OS

## The Problem

### Reported Issue

When cloning a repository containing Unicode characters that cannot be represented in IBM-1047:

**File contains:** U+2011 (NON-BREAKING HYPHEN `‑`)  
**Expected in IBM-1047:** Some representation  
**Actual result:** `0x3f` (`?`) - an **illegal character** that breaks z/OS tooling  
**Symptom:** File appears modified after clone, vim shows `^Z`

### Example

```
# In GitHub (UTF-8)
file.txt contains: "This is a non‑breaking hyphen"
                                    ↑ U+2011

# After git clone on z/OS with zos-working-tree-encoding=IBM-1047
file.txt contains: "This is a non? breaking hyphen"
                                 ↑ 0x3f (illegal!)
                                 
# In vim: "This is a non^Z breaking hyphen"
```

---

## Root Cause

### The Conversion Problem

1. **UTF-8 → IBM-1047 conversion** encounters U+2011 (NON-BREAKING HYPHEN)
2. IBM-1047 **doesn't have this character**
3. Without transliteration: iconv converts it to `0x3f` (`?`)
4. `0x3f` is an **illegal/control character** in IBM-1047
5. Result: File is corrupted, tooling breaks

### Why It Appears Modified

Git sees the corrupted character (`0x3f`) is different from what it expects, so:
```bash
$ git status
modified: file.txt
```

Even though you didn't change anything!

---

## The Solution: Enable Transliteration

### What You Need

**Enable `GIT_ICONV_TRANSLIT`** to handle unmappable characters gracefully:

```bash
# Temporary (for one operation)
export GIT_ICONV_TRANSLIT=1
git clone https://github.com/example/repo-with-special-chars.git

# Permanent (recommended)
git config --global core.iconvtranslit true
```

### What Transliteration Does

With `GIT_ICONV_TRANSLIT=1`:

| Character | Unicode | Without Translit | With Translit |
|-----------|---------|------------------|---------------|
| ‑ (non-breaking hyphen) | U+2011 | `0x3f` (?) ⚠️ | `-` (U+002D) ✅ |
| – (en dash) | U+2013 | `0x3f` (?) ⚠️ | `-` (hyphen) ✅ |
| — (em dash) | U+2014 | `0x3f` (?) ⚠️ | `-` (hyphen) ✅ |
| café | é=U+00E9 | caf? ⚠️ | cafe ✅ |
| naïve | ï=U+00EF | na?ve ⚠️ | naive ✅ |
| € | U+20AC | ? ⚠️ | EUR ✅ |

**Result:** Characters are approximated instead of corrupted!

---

## Testing the Issue

### Reproduce the Problem

```bash
# Create a test file with U+2011
cd /tmp
mkdir test-unmappable && cd test-unmappable
git init
git config user.name "Test"
git config user.email "test@test.com"

# Create .gitattributes
echo "*.txt zos-working-tree-encoding=IBM-1047" > .gitattributes
git add .gitattributes
git commit -m "Add attributes"

# Create file with U+2011 (non-breaking hyphen)
# Note: You need UTF-8 terminal for this
printf 'This is a non\xe2\x80\x91breaking hyphen\n' > test.txt

# Tag as UTF-8 and add
chtag -tc UTF-8 test.txt
git add test.txt
git commit -m "Add file with U+2011"

# Now checkout (simulating clone)
rm test.txt
git checkout test.txt

# Check the file
xxd test.txt | grep -A1 "non"
# You'll see 0x3f where U+2011 should be
```

### Test With Transliteration

```bash
# Enable transliteration
export GIT_ICONV_TRANSLIT=1

# Checkout again
rm test.txt
git checkout test.txt

# Now check
xxd test.txt | grep -A1 "non"
# Should show regular hyphen (0x2d in ASCII, 0x60 in EBCDIC)
```

---

## Current Git Behavior (Our Fix)

### What Happens Now (With Our Fixes)

1. **Without `GIT_ICONV_TRANSLIT`:**
   - Git **fails** with error: "failed to encode from UTF-8 to IBM-1047"
   - This is **better** than silent corruption!
   - User knows something is wrong

2. **With `GIT_ICONV_TRANSLIT=1`:**
   - Git **succeeds** and transliterates: `‑` → `-`
   - Git **warns**: "transliteration used for 'file.txt'"
   - User is aware of approximation

### Why This Is Better

**Old behavior (before our fixes):**
- Silent conversion to `0x3f`
- Corrupted files
- No warning

**New behavior (with our fixes):**
- **Fail by default** (strict mode)
- Or **transliterate with warning** (if enabled)
- User is always informed

---

## Recommendations

### For Repository Owners

#### Option 1: Use ASCII-Safe Characters (Best)

Replace special characters in files that will be checked out on z/OS:

```bash
# Instead of: file‑name.txt (U+2011)
# Use:        file-name.txt (U+002D)
```

#### Option 2: Document Transliteration Requirement

Add to `README.md`:

```markdown
## z/OS Users

This repository contains Unicode characters that require transliteration.
Enable it before cloning:

```bash
git config --global core.iconvtranslit true
git clone <repo-url>
```
```

#### Option 3: Pre-commit Hook

Create `.git/hooks/pre-commit`:

```bash
#!/bin/sh
# Check for unmappable characters

# List of problematic characters for IBM-1047
UNMAPPABLE=$(git diff --cached --name-only | while read file; do
    if file -b "$file" | grep -q text; then
        # Check for common unmappable Unicode chars
        if grep -qP '[\x{2011}\x{2013}\x{2014}\x{20AC}]' "$file" 2>/dev/null; then
            echo "$file"
        fi
    fi
done)

if [ -n "$UNMAPPABLE" ]; then
    echo "ERROR: Files contain characters unmappable to IBM-1047:"
    echo "$UNMAPPABLE"
    echo ""
    echo "These characters will corrupt on z/OS systems."
    echo "Please replace with ASCII equivalents or enable transliteration."
    exit 1
fi
```

### For z/OS Users

#### Recommended Setup

Add to `~/.gitconfig`:

```ini
[core]
    # Enable transliteration for unmappable characters
    iconvtranslit = true
    
    # Don't ignore file tags
    ignorefiletags = false
```

Or via environment (takes precedence):

```bash
# Add to ~/.profile
export GIT_ICONV_TRANSLIT=1
```

#### When To Enable/Disable

**Enable (`true`) for:**
- Public repositories (likely have special chars)
- Documentation/websites (internationalization)
- User-generated content
- When you need "best effort" conversion

**Disable (`false`) for:**
- Pure source code repositories
- Data files where precision matters
- When you want to catch encoding issues immediately

---

## Warnings and Detection

### Current Warning System (Our Implementation)

With our fixes, Git will:

```bash
# Without transliteration (strict mode)
$ git clone <repo>
error: failed to encode 'file.txt' from UTF-8 to IBM-1047
       at line 5, col 12 (char: 0xe28091 = U+2011)
fatal: unable to checkout working tree

# With transliteration enabled
$ export GIT_ICONV_TRANSLIT=1
$ git clone <repo>
warning: transliteration (best-effort) conversion used for 'file.txt'
         from UTF-8 to IBM-1047 at line 5, col 12 (char: 0xe28091 = U+2011)
Cloning into 'repo'... done.
```

### Proposed Enhancement: Better Warnings

We could enhance the warning to be more specific:

```c
// In convert.c, when transliteration is used
warning("character U+2011 (NON-BREAKING HYPHEN) in '%s'\n"
        "       converted to '-' (hyphen) for IBM-1047\n"
        "       Original character is not representable in target encoding",
        path);
```

---

## Technical Details

### Character Mapping

| Character | Name | UTF-8 bytes | IBM-1047 | Translit |
|-----------|------|-------------|----------|----------|
| `-` | HYPHEN-MINUS | 0x2d | 0x60 | - |
| `‑` | NON-BREAKING HYPHEN | 0xe2 0x80 0x91 | ❌ N/A | `0x60` (hyphen) |
| `–` | EN DASH | 0xe2 0x80 0x93 | ❌ N/A | `0x60` (hyphen) |
| `—` | EM DASH | 0xe2 0x80 0x94 | ❌ N/A | `0x60` (hyphen) |
| `?` | QUESTION MARK | 0x3f | 0x6f | - |
| `^Z` | SUB control | - | 0x3f | ⚠️ illegal |

### Why 0x3f Is Bad

In IBM-1047 (EBCDIC):
- `0x3f` = SUB (substitute) control character
- Not a printable character
- Breaks text processing tools
- Vim displays as `^Z`

### Proper Handling

```c
// In iconv, with //TRANSLIT suffix:
iconv(cd, 
      "UTF-8",           // from
      "IBM-1047//TRANSLIT", // to (with transliteration!)
      &inbuf, &outbuf)

// Results:
U+2011 → 0x60 (hyphen) instead of 0x3f (SUB)
```

---

## GitHub/Pre-receive Hook (Advanced)

### Server-Side Protection

For GitHub Enterprise or self-hosted Git servers:

```bash
#!/bin/sh
# pre-receive hook to detect unmappable characters

while read oldrev newrev refname; do
    # Get list of changed files
    files=$(git diff --name-only $oldrev..$newrev)
    
    for file in $files; do
        # Check if file has zos-working-tree-encoding
        encoding=$(git check-attr zos-working-tree-encoding -- "$file" | 
                   cut -d: -f3 | tr -d ' ')
        
        if [ "$encoding" = "IBM-1047" ]; then
            # Test if file can be converted
            content=$(git show "$newrev:$file")
            if ! echo "$content" | iconv -f UTF-8 -t IBM-1047 >/dev/null 2>&1; then
                echo "ERROR: $file contains characters not representable in IBM-1047"
                echo "Please use ASCII-compatible characters or enable transliteration on z/OS"
                exit 1
            fi
        fi
    done
done
```

---

## Summary

### The Issue
- U+2011 (non-breaking hyphen) → `0x3f` (illegal char) in IBM-1047
- Silent corruption breaks z/OS tooling
- File appears modified after clone

### The Solution
- **Enable transliteration:** `export GIT_ICONV_TRANSLIT=1`
- Or: `git config --global core.iconvtranslit true`
- Characters are approximated instead of corrupted

### Best Practices

1. **For repo owners:** Use ASCII-safe characters when possible
2. **For z/OS users:** Enable transliteration by default
3. **For teams:** Document encoding requirements
4. **For enterprises:** Add pre-commit/pre-receive hooks

### Our Fixes Address This

✅ Fail by default (no silent corruption)  
✅ Warn when transliterating  
✅ Allow user to choose strict vs lenient mode  
✅ Precedence: env var > config > default  

The user's issue is exactly why we implemented the transliteration feature!

