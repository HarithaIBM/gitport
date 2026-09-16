# Test Coverage Summary

## Architectural Fixes Test Coverage

### 1. Parallel Checkout Race Condition Fix
**File:** `tests/test_parallel_checkout_encoding.sh`

**Tests:**
- ✅ Mixed encoding files (IBM-1047, UTF-8, ISO8859-1) are tagged correctly
- ✅ No race condition with 20 concurrent files
- ✅ Binary files are handled correctly
- ✅ Attributes don't get mixed between files

**What it validates:**
- `parallel-checkout.c` uses pre-computed `pc_item->ca` (not stale)
- No race on global `convert_attrs()` static variable
- Each file gets its own correct encoding tag

---

### 2. Git Apply 3-Way Merge Verification
**File:** `tests/test_apply_3way_ebcdic.sh`

**Tests:**
- ✅ `git apply --3way` works with unmodified IBM-1047 files
- ✅ 3-way merge detects and merges local modifications correctly
- ✅ Non-3way apply still validates files (no bypass)
- ✅ EBCDIC/UTF-8 size differences don't break 3-way merge

**What it validates:**
- `apply.c` only bypasses stat check for 3-way merge with IBM-1047
- 3-way merge provides content verification through conversion
- Non-3way operations still get full validation
- File size difference (EBCDIC vs UTF-8) is handled correctly

---

### 3. Existing Tests

**File:** `git/t/t0083-apply-3way-zos.sh`
- ✅ `git apply --3way` tagging for IBM-1047 files
- Status: **2/2 passing**

**File:** `tests/test_3way_merge_encodings.sh`
- ✅ 3-way branch merge with various encodings
- ✅ 16 comprehensive merge scenarios
- Status: **16/16 passing** (after fixes)

**File:** `tests/test_pull_encoding_tag_fix.sh`
- ✅ Attribute cache invalidation during pull
- Tests the unpack-trees.c fix

---

## Test Execution

### Run all custom tests:
```bash
cd tests
./run_all_tests.sh
```

### Run specific test:
```bash
./tests/test_parallel_checkout_encoding.sh
./tests/test_apply_3way_ebcdic.sh
```

### Run Git's built-in tests:
```bash
cd git/t
./t0083-apply-3way-zos.sh
```

---

## Coverage Matrix

| Issue | Code Fix | Test File | Test Status |
|-------|----------|-----------|-------------|
| Parallel checkout race | `parallel-checkout.c` | `test_parallel_checkout_encoding.sh` | ✅ New |
| Apply verification bypass | `apply.c` | `test_apply_3way_ebcdic.sh` | ✅ New |
| **Unpack-trees timing** | `unpack-trees.c` | `test_pull_encoding_tag_fix.sh` | ✅ **Fixed & Tested** |
| Apply 3-way basic | `apply.c` | `t0083-apply-3way-zos.sh` | ✅ Existing |
| 3-way merge encoding | `merge-ort.c` | `test_3way_merge_encodings.sh` | ✅ Existing |
| Attribute cache | `unpack-trees.c` | `test_pull_encoding_tag_fix.sh` | ✅ Existing |
| Pipe error | `run-command.c` | Manual (aliases) | ⚠️ Manual |
| PYTHON_PATH | `config.mak.uname` | Build system | ⚠️ Build |
| Unused variables | `entry.c` | Compiler | ⚠️ Compiler |
| Mutex (no deadlock) | `attr.c` | Function analysis | ✅ Safe |
| Bad char init | `utf8.c` | Error handling | ✅ Fixed |
| Lockfile PID | `lockfile.c` | Integration | ✅ Fixed |
| iconv_translit guard | `utf8.c` | Cross-platform | ✅ Fixed |
| Test framework | `buildenv` | TAP output | ✅ Fixed |

---

## Key Findings

### Safe Issues (No Tests Needed)
1. **Mutex in attr.c** - No early returns found, no deadlock possible
2. **iconv_translit** - Now properly guarded with `#ifdef __MVS__`
3. **Lockfile PID** - Moved outside z/OS-only block

### Tested & Validated
1. **Parallel checkout** - New comprehensive test suite
2. **Apply 3-way** - New test + existing Git test
3. **3-way merge** - Extensive existing test suite
4. **Attribute cache** - Pull encoding regression test

### Build/Compile-Time
1. **PYTHON_PATH** - Fixed, validated at build
2. **Unused fcntl_ret** - Fixed, no compiler warnings
3. **Pipe error** - Fixed in source, tested manually with aliases

---

## Running the Full Test Suite

```bash
# Custom tests (in tests/)
./tests/run_all_tests.sh

# Git built-in tests (in git/t/)
cd git/t && make test

# Build validation
cd git && make clean && make -j4
```

All critical architectural fixes are now tested! ✅
