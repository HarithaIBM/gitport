#!/bin/bash
# Update all test scripts to use ./test_tmp instead of /tmp

echo "Updating test scripts to use local temp directory..."

cd tests

for test_file in test_*.sh; do
    if [ -f "$test_file" ]; then
        echo "Updating: $test_file"
        
        # Replace /tmp with ./test_tmp_$$
        sed -i 's|TEST_ROOT="$(mktemp -d /tmp/git_.*XXXXXX)"|TEST_ROOT="$(pwd)/test_tmp_$$"|g' "$test_file"
        sed -i 's|mktemp -d /tmp/|mkdir -p ./test_tmp_$$ \&\& echo ./test_tmp_$$/|g' "$test_file"
        
        # Make sure we have cleanup
        if ! grep -q "rm -rf.*test_tmp" "$test_file"; then
            echo "  Warning: No cleanup found in $test_file"
        fi
    fi
done

echo ""
echo "Done! Tests will now use ./test_tmp_PID directories"
echo "These will be cleaned up automatically via trap EXIT"
