# Potential File Tagging Issues - Analysis

## The rerere Problem Pattern

**What we fixed in rerere:**
- Code used `fopen()` / `fwrite()` to write files
- No z/OS tagging applied
- Result: Files tagged incorrectly (ISO8859-1 instead of IBM-1047)

## Other Places That Might Have Same Issue

Let me search for similar patterns...

### Pattern to Look For:
1. Code that writes files to working tree
2. Uses `fopen()` / `fwrite()` or similar
3. Doesn't call tagging functions
4. Should respect `.gitattributes` encoding

