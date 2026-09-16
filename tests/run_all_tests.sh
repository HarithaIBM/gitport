#!/bin/bash
# Run all tests and output in TAP format

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_NUM=0
PASSED=0
FAILED=0

# Function to run a test and capture result
run_test() {
    local test_script="$1"
    local test_name="$(basename "$test_script" .sh)"
    
    TEST_NUM=$((TEST_NUM + 1))
    
    # Run the test and capture output
    if bash "$test_script" > "/tmp/${test_name}_$$.out" 2>&1; then
        PASSED=$((PASSED + 1))
        echo "ok $TEST_NUM - $test_name"
    else
        FAILED=$((FAILED + 1))
        echo "not ok $TEST_NUM - $test_name"
        # Include error details
        echo "# Test output:"
        sed 's/^/# /' "/tmp/${test_name}_$$.out"
    fi
    
    # Clean up temp file
    rm -f "/tmp/${test_name}_$$.out"
}

echo "TAP version 13"
echo "1..$(ls -1 "$SCRIPT_DIR"/*.sh | grep -v run_all_tests.sh | wc -l)"

# Run each test script
for test_script in "$SCRIPT_DIR"/*.sh; do
    # Skip the run_all_tests.sh script itself
    if [ "$(basename "$test_script")" = "run_all_tests.sh" ]; then
        continue
    fi
    
    # Skip if not executable
    if [ ! -x "$test_script" ]; then
        echo "# Warning: $test_script is not executable, skipping"
        continue
    fi
    
    run_test "$test_script"
done

# Summary
echo "# Tests run: $TEST_NUM"
echo "# Passed: $PASSED"
echo "# Failed: $FAILED"

# Exit with failure if any test failed
[ $FAILED -eq 0 ]
