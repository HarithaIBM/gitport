#!/bin/bash
# Fix all test scripts to properly create and cleanup temp directories

for script in test_*.sh; do
    [ "$script" = "fix_all_test_scripts.sh" ] && continue
    [ ! -f "$script" ] && continue
    
    echo "Fixing: $script"
    
    # Check current TEST_ROOT line
    if grep -q 'TEST_ROOT=.*mktemp.*XXXXXX' "$script"; then
        # Has old mktemp format - replace it
        sed -i 's|TEST_ROOT="$(mktemp -d .*XXXXXX)"|TEST_ROOT="$(pwd)/test_tmp_$$"\nmkdir -p "$TEST_ROOT"|' "$script"
        echo "  ✓ Updated TEST_ROOT"
    elif grep -q 'TEST_ROOT="$(pwd)/test_tmp_' "$script"; then
        # Already has new format - check if mkdir is there
        # More robust check: look for mkdir in the line immediately after TEST_ROOT
        if grep -A1 'TEST_ROOT="$(pwd)/test_tmp_' "$script" | tail -1 | grep -q 'mkdir -p.*TEST_ROOT'; then
            echo "  ✓ Already correct"
        else
            # Check if mkdir exists anywhere near TEST_ROOT (prevent duplicates)
            if grep -A5 'TEST_ROOT="$(pwd)/test_tmp_' "$script" | grep -q 'mkdir -p.*TEST_ROOT'; then
                echo "  ✓ mkdir exists (possibly manual edit)"
            else
                # Add mkdir after TEST_ROOT line
                sed -i '/TEST_ROOT="$(pwd)\/test_tmp_/a mkdir -p "$TEST_ROOT"' "$script"
                echo "  ✓ Added mkdir"
            fi
        fi
    fi
    
    # Make sure there's a trap for cleanup
    if ! grep -q "trap.*rm -rf.*TEST_ROOT" "$script"; then
        # Add trap after TEST_ROOT setup
        sed -i '/mkdir -p "$TEST_ROOT"/a trap '"'"'rm -rf "$TEST_ROOT"'"'"' EXIT' "$script"
        echo "  ✓ Added trap"
    fi
done

echo ""
echo "All test scripts fixed!"
