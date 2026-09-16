# Testing Integration Documentation

## Overview

The git port now includes custom test integration into the `zopen_check_results` function. Tests in the `tests/` directory are automatically run and their results are combined with the standard git test suite results.

## Components

### 1. Test Runner Script: `tests/run_all_tests.sh`

This script:
- Discovers and runs all executable `.sh` scripts in the `tests/` directory
- Outputs results in TAP (Test Anything Protocol) format
- Excludes itself from the test run
- Provides detailed output for failed tests
- Returns non-zero exit code if any test fails

**Usage:**
```bash
cd tests
./run_all_tests.sh
```

**Output Format (TAP):**
```
TAP version 13
1..4
ok 1 - basicclone
not ok 2 - stepwiseclone
# Test output:
# <error details>
ok 3 - test_3way_merge_encodings
ok 4 - testtags
# Tests run: 4
# Passed: 3
# Failed: 1
```

### 2. Modified `zopen_check_results` in `buildenv`

The function now:

1. **Processes standard git test results** (as before):
   - Parses `$1/$2_check.log` for TAP format results
   - Counts successes and failures
   - Writes failures to `$1/$2_check_failures.log`

2. **Runs custom tests** (new):
   - Locates the `tests/` directory relative to the git build directory
   - Executes `tests/run_all_tests.sh` if it exists and is executable
   - Captures output to `$1/$2_custom_tests.log`
   - Parses custom test results in TAP format
   - Writes custom test failures to `$1/$2_custom_test_failures.log`

3. **Combines results**:
   - Adds custom test counts to standard test counts
   - Reports combined totals in the output

**Output:**
```
actualFailures:<combined_failures>
totalTests:<combined_total>
expectedFailures:2400
```

## Test Directory Structure

```
tests/
├── run_all_tests.sh           # Main test runner (auto-generated)
├── basicclone.sh              # Test: Basic git clone functionality
├── stepwiseclone.sh           # Test: Step-by-step clone process
├── test_3way_merge_encodings.sh  # Test: 3-way merge with encoding handling
└── testtags.sh                # Test: File tagging functionality
```

## Adding New Tests

To add a new test:

1. Create a new executable shell script in the `tests/` directory:
   ```bash
   touch tests/my_new_test.sh
   chmod +x tests/my_new_test.sh
   ```

2. Write your test logic:
   ```bash
   #!/bin/bash
   # Test description
   
   # Your test code here
   
   if [ condition ]; then
       echo "Test passed"
       exit 0
   else
       echo "Test failed: reason"
       exit 1
   fi
   ```

3. The test will automatically be picked up by `run_all_tests.sh`

## Running Tests

### During Build Process

Tests are automatically run as part of the `zopen_check` phase:
```bash
zopen build
```

### Manual Testing

To run only the custom tests:
```bash
cd tests
./run_all_tests.sh
```

To simulate the full check process:
```bash
source buildenv
zopen_check_results <build_dir> git
```

## Output Files

After running tests, the following log files are created:

- `git_check.log` - Standard git test suite results
- `git_check_failures.log` - Failed tests from standard suite
- `git_custom_tests.log` - Custom test results (TAP format)
- `git_custom_test_failures.log` - Failed custom tests

## Example Output

```
Running custom tests from /path/to/tests...
Custom tests encountered failures
Custom tests: 3 passed, 1 failed out of 4
actualFailures:2401
totalTests:25004
expectedFailures:2400
```

This indicates:
- 4 custom tests ran (3 passed, 1 failed)
- Combined with standard test results: 2401 total failures, 25004 total tests

## Notes

- Tests should be independent and idempotent
- Tests should clean up after themselves
- Long-running tests should be kept in separate suites
- Test scripts should use relative paths to locate git binaries
- All test scripts must be executable (`chmod +x`)
