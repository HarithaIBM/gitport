# Quick Start - Build Git with All Fixes

## TL;DR

All fixes are already applied in the `git/` directory. Just build:

```bash
cd git
make clean
make -j4
./git --version
```

Then test:

```bash
cd ../tests
./run_all_tests.sh
```

Expected: **29/29 tests pass** ✅

---

## What's Been Fixed

✅ Pipe error in aliases  
✅ PYTHON_PATH build issue  
✅ Compiler warnings  
✅ Uninitialized variables  
✅ Lockfile PID creation  
✅ **Parallel checkout race condition**  
✅ **Apply 3-way verification bypass**  
✅ **Unpack-trees timing issue** (was causing test failure)  

**Total: 15 critical fixes applied**

---

## Modified Files in git/

### Critical (must rebuild):
- `apply.c` - 3-way merge fix
- `parallel-checkout.c` - race condition fix
- `convert.c`, `convert.h` - new tagging function
- `unpack-trees.c` - **timing fix (flush queue)**
- `run-command.c` - pipe error fix
- `entry.c` - warning fix
- `utf8.c` - initialization fix
- `lockfile.c` - PID file fix

### All patches from `stable-patches/` are applied (38 files)

---

## Full Documentation

- `BUILD_INSTRUCTIONS.md` - Detailed build guide
- `FINAL_TEST_SUMMARY.md` - All fixes & test coverage
- `TEST_COVERAGE_SUMMARY.md` - Test matrix
- `UNPACK_TREES_FIX_EXPLAINED.md` - Parallel checkout timing fix details

---

## Quick Commands

### Build
```bash
cd git
make clean && make -j4
```

### Test Everything
```bash
cd tests
./run_all_tests.sh
```

### Test Specific Fix
```bash
# Unpack-trees timing (was failing)
./test_pull_encoding_tag_fix.sh

# Parallel checkout race
./test_parallel_checkout_encoding.sh

# Apply 3-way
./test_apply_3way_ebcdic.sh

# 3-way merge
./test_3way_merge_encodings.sh
```

### Install
```bash
cd git
sudo make install
# or
make install prefix=$HOME/local
```

---

## Verification

After building, these should work:

```bash
# No pipe error
git status

# Encoding tags work
git checkout <branch>
chtag -p file.txt  # Should show correct encoding

# 3-way merge works
git merge <branch>  # Files tagged correctly

# Apply works
git apply --3way patch.diff  # Works with IBM-1047
```

---

## Need Help?

See `BUILD_INSTRUCTIONS.md` for:
- Troubleshooting
- Build options
- Custom install paths
- Detailed verification steps

---

**Status: Ready to build!** ✅

All mandatory issues fixed and tested.
