# Git z/OS Patch List

This directory contains patches to be applied to vanilla Git for z/OS support.

## Core Patches (Required)

### Encoding and Conversion
- `convert.c.patch` - Core encoding conversion with iconv_translit support
- `convert.h.patch` - Headers for conversion functions
- `utf8.c.patch` - UTF-8 handling and bad_char_out initialization
- `utf8.h.patch` - UTF-8 headers
- `environment.c.patch` - GIT_ICONV_TRANSLIT environment variable support

### Platform Support
- `config.mak.uname.patch` - z/OS build configuration (PYTHON_PATH fix)
- `entry.c.patch` - File entry handling (fcntl_ret cast)
- `lockfile.c.patch` - Lockfile handling with PID file creation fix
- `run-command.c.patch` - Command execution (pipe error handling)

### File Operations
- `apply.c.patch` - git apply with 3-way merge stat bypass
- `parallel-checkout.c.patch` - Parallel checkout with pre-computed attributes
- `unpack-trees.c.patch` - Unpack trees with parallel checkout flush timing
- `rerere.c.patch` - git rerere with file tagging (Issue #17)

### NEW: Additional Command Fixes
- `builtin/merge-file.c.patch` - git merge-file with file tagging (Issue #18)
- `diff.c.patch` - git diff --output with file tagging (Issue #19)
- `diff.h.patch` - diff.h struct for output_path field (Issue #19)

## Test Patches

- `t0082-zos-encoding.patch` - Basic z/OS encoding tests
- `t0083-apply-3way-zos.sh.patch` - 3-way merge encoding tests
- `t0084-rerere-zos.sh.patch` - rerere encoding tests

## Patch Application Order

Apply in this order:

1. Core platform patches first:
   - config.mak.uname.patch
   - environment.c.patch
   - run-command.c.patch
   - lockfile.c.patch
   - entry.c.patch

2. Encoding patches:
   - utf8.h.patch
   - utf8.c.patch
   - convert.h.patch
   - convert.c.patch

3. File operation patches:
   - apply.c.patch
   - parallel-checkout.c.patch
   - unpack-trees.c.patch
   - rerere.c.patch

4. NEW: Command patches:
   - builtin/merge-file.c.patch
   - diff.h.patch
   - diff.c.patch

5. Test patches:
   - t0082-zos-encoding.patch
   - t0083-apply-3way-zos.sh.patch
   - t0084-rerere-zos.sh.patch

## Built-in Command Patches

Located in `builtin/` subdirectory:
- archive.c.patch
- cat-file.c.patch
- hash-object.c.patch
- help.c.patch
- index-pack.c.patch
- merge-file.c.patch (NEW)

## Applying Patches

```bash
cd git
for patch in ../stable-patches/*.patch; do
    git apply "$patch"
done
for patch in ../stable-patches/builtin/*.patch; do
    git apply "$patch"
done
for patch in ../stable-patches/t/*.patch; do
    git apply "$patch"
done
```

## Issues Fixed

See KNOWN_ISSUES.md for complete list. Latest additions:
- Issue #17: git rerere encoding (rerere.c.patch)
- Issue #18: git merge-file tagging (builtin/merge-file.c.patch)
- Issue #19: git diff --output tagging (diff.c.patch, diff.h.patch)
