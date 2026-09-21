# NEL/Newline Regression Fix

## Problem
IBM-1047 files in `~/delete/git-test-alt/winbuild/` directory were showing as modified when running `git status`, even though they shouldn't be. The files had incorrect line terminators.

## Root Cause
The bug was introduced in commit **1bb4dd2** (2026-04-13) by D Harithamma in `stable-patches/convert.c.patch`.

### Buggy Code (Lines 687-690 in convert.c)
```c
if (is_ebcdic_newline(*nl))
    strbuf_addstr(buf, "\r\x15");  // WRONG: Adding CR before NEL
else
    strbuf_addstr(buf, "\r\n");
```

### What Was Wrong
The `crlf_to_worktree()` function was incorrectly adding a Carriage Return (CR, x'0D') before the EBCDIC NEL (New Line, x'15') character, creating `\r\x15` sequences in IBM-1047 files.

**This is incorrect because:**
1. NEL (x'15') is already a complete newline character in EBCDIC - it doesn't need CR
2. IBM-1047 files should have **only NEL** as line terminators, not CRLF+NEL
3. Adding CR before NEL corrupts the files and makes them appear modified

### The Fix (Commit 8626b15, 2026-09-21)
```c
if (is_ebcdic_newline(*nl))
    strbuf_addch(buf, *nl);  // CORRECT: Keep NEL as-is, don't add CR
else
    strbuf_addstr(buf, "\r\n");
```

## Timeline

| Date | Commit | Action | Author |
|------|--------|--------|--------|
| 2026-04-13 | 1bb4dd2 | **Bug introduced**: Added `\r\x15` for EBCDIC newlines | D Harithamma |
| 2026-09-18 | bf43918 | Updated convert.c.patch (bug still present) | Test user |
| 2026-09-21 | 8626b15 | **Bug fixed**: Changed to preserve NEL without CR | Test user |

## Impact
- **Duration**: ~5 months (April 13 - September 21, 2026)
- **Affected files**: All IBM-1047 encoded files in Git repositories
- **Symptom**: Files showed as modified even when content was unchanged
- **File attribute**: Files had `NEL line terminators` instead of proper line endings

## Verification
After the fix, IBM-1047 files should:
1. Use NEL (x'15') as line terminators only
2. NOT have CR (x'0D') before NEL
3. Show as unmodified in `git status` when they haven't been changed
4. Be tagged correctly: `ASCII text, with NEL line terminators` (for EBCDIC files)

## Technical Details

### EBCDIC vs ASCII Newlines
- **ASCII/UTF-8**: Uses LF (x'0A') or CRLF (x'0D' x'0A')
- **EBCDIC/IBM-1047**: Uses NEL (x'15') - a single byte
- **NEL is NOT equivalent to LF**: They are different characters with different semantics

### The `crlf_to_worktree()` Function
This function converts newlines when checking out files to the working tree:
- For ASCII/UTF-8 files: Converts LF → CRLF (when eol=crlf)
- For EBCDIC files: Should preserve NEL as-is (not add CR)

The bug violated this by treating NEL like LF and adding CR before it.
