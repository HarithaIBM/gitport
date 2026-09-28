#!/bin/bash
# Run all tests and output in TAP format

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/TEST_MANIFEST"
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

# Check if manifest exists
if [ ! -f "$MANIFEST" ]; then
    echo "Error: TEST_MANIFEST not found at $MANIFEST"
    echo "# Please create TEST_MANIFEST with list of tests to run"
    exit 1
fi

# Count tests in manifest (excluding comments and empty lines)
TEST_COUNT=$(grep -v '^#' "$MANIFEST" | grep -v '^$' | wc -l)

echo "TAP version 13"
echo "1..$TEST_COUNT"
echo "# Using TEST_MANIFEST for test discovery"
echo "# Tests to run: $TEST_COUNT"

# Run each test from manifest
while IFS= read -r test_name || [ -n "$test_name" ]; do
    # Skip comments
    [[ "$test_name" =~ ^#.*$ ]] && continue
    
    # Skip empty lines
    [[ -z "$test_name" ]] && continue
    
    # Strip leading/trailing whitespace
    test_name=$(echo "$test_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    test_script="$SCRIPT_DIR/$test_name"
    
    # Check if test file exists
    if [ ! -f "$test_script" ]; then
        echo "# Warning: $test_name not found at $test_script, skipping"
        continue
    fi
    
    # Check if test is executable
    if [ ! -x "$test_script" ]; then
        echo "# Warning: $test_name is not executable, skipping"
        continue
    fi
    
    run_test "$test_script"
done < "$MANIFEST"

# Summary
echo "# Tests run: $TEST_NUM"
echo "# Passed: $PASSED"
echo "# Failed: $FAILED"

# Exit with failure if any test failed
[ $FAILED -eq 0 ]
