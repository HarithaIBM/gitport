# Manual Build Instructions

## Overview

The `git/` directory contains Git 2.55 source code with all patches already applied.

## Modified Files (Critical Fixes)

### Core Encoding & z/OS Fixes
- ✅ `apply.c` - 3-way merge verification bypass (stat check only)
- ✅ `parallel-checkout.c` - Race condition fix (use pre-computed `pc_item->ca`)
- ✅ `convert.c` - Added `tag_file_with_conv_attrs()` function
- ✅ `convert.h` - Declared `tag_file_with_conv_attrs()`
- ✅ `unpack-trees.c` - **Parallel checkout timing fix** (flush queue before cache invalidation)
- ✅ `entry.c` - Unused variable fix (cast to void)
- ✅ `utf8.c` - Uninitialized variable + iconv_translit guard
- ✅ `lockfile.c` - PID file creation (moved outside z/OS-only block)
- ✅ `run-command.c` - Pipe error message fix

### Build System
- ✅ `config.mak.uname` - PYTHON_PATH fix (direct assignment)
- ✅ `Makefile` - z/OS specific settings

### Test Files
- ✅ `t/t0083-apply-3way-zos.sh` - Apply 3-way test for z/OS (2 tests)

## Build Steps

### 1. Navigate to git directory
```bash
cd git
```

### 2. Clean previous build (if any)
```bash
make clean
```

### 3. Build Git
```bash
# Standard build
make -j4

# Or with specific settings
make -j4 CFLAGS="-O2 -g"
```

### 4. Verify build
```bash
./git --version
```

Expected output:
```
git version 2.55.0.zos
```

### 5. Test the build
```bash
# Quick test
./git status

# Run built-in z/OS tests
cd t
./t0083-apply-3way-zos.sh

# Run all tests (optional, takes time)
make test
```

### 6. Install (optional)
```bash
# Install to default location (/usr/local/bin)
sudo make install

# Or install to custom location
make install prefix=$HOME/local
```

## What Gets Built

```
git/
├── git                    # Main git binary ✓
├── git-*                  # Git subcommands
├── *.o                    # Object files
└── lib*.a                 # Libraries
```

## Verify Critical Fixes After Build

### 1. Test pipe error fix
```bash
cd /path/to/your/repo
git status  # Should not show "cannot create  pipe" error
```

### 2. Test Python scripts
```bash
git send-email --help  # Should work if git-send-email is configured
```

### 3. Test parallel checkout
```bash
cd ../tests
./test_parallel_checkout_encoding.sh
```

Expected: ✅ All 3 tests pass

### 4. Test unpack-trees timing fix
```bash
./test_pull_encoding_tag_fix.sh
```

Expected: ✅ All 3 tests pass (was failing before fix)

### 5. Test apply 3-way
```bash
./test_apply_3way_ebcdic.sh
```

Expected: ✅ All 4 tests pass

### 6. Test 3-way merge
```bash
./test_3way_merge_encodings.sh
```

Expected: ✅ All 16 tests pass

## Troubleshooting

### Build fails with "command not found"
Make sure you have development tools:
```bash
# Check compiler
cc -v

# Check make
make -v
```

### Linker errors
May need to install libraries:
```bash
# Example for common dependencies
# (adjust for your system)
zopen install curl-dev
zopen install zlib-dev
```

### "Cannot find perl" errors
Set PERL_PATH:
```bash
make PERL_PATH=/path/to/perl
```

### "Cannot find python" errors
Already fixed in config.mak.uname.patch, but you can override:
```bash
make PYTHON_PATH=/path/to/python3
```

## Build Options

### Debug build
```bash
make CFLAGS="-g -O0"
```

### Optimized build
```bash
make CFLAGS="-O3"
```

### z/OS specific
```bash
make CC=xlc CFLAGS="-qlanglvl=extc99 -qascii"
```

### Skip tests during build
```bash
make NO_TESTS=1
```

## Verification Checklist

After building, verify these fixes:

- [ ] `git status` doesn't show pipe error
- [ ] Files get correct encoding tags (test with `chtag -p`)
- [ ] `git apply --3way` works with IBM-1047 files
- [ ] `git checkout` updates tags when .gitattributes changes
- [ ] Parallel checkout doesn't mix up encoding tags
- [ ] No compiler warnings
- [ ] All custom tests pass (29/29)

## File Locations After Install

Default install (prefix=/usr/local):
```
/usr/local/bin/git           # Main binary
/usr/local/libexec/git-core/ # Git commands
/usr/local/share/git-core/   # Templates, etc.
```

Custom install (prefix=$HOME/local):
```
$HOME/local/bin/git
$HOME/local/libexec/git-core/
$HOME/local/share/git-core/
```

## Summary of Patches Applied

All patches from `stable-patches/` have been applied:
- 38 patch files total
- 14 critical bug fixes
- 4 code quality improvements
- 2 test additions

**Status: Ready to build** ✅

## Quick Build & Test

```bash
# One-liner to build and test
cd git && make clean && make -j4 && cd ../tests && ./run_all_tests.sh
```

Expected result: **Build succeeds, 29/29 tests pass** ✅

