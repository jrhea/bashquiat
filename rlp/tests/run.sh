#!/bin/bash

source encode.sh
source decode.sh

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

run_tests() {
    local test_data="$1"
    local total_tests=0
    local passed_tests=0

    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*\"([^\"]+)\":[[:space:]]*\{ ]]; then
            test_name="${BASH_REMATCH[1]}"
            read -r in_line
            read -r out_line
            in_value=$(echo "$in_line" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")
            out_value=$(echo "$out_line" | cut -d: -f2 | sed 's/^ *//g' | tr -d "\"" | tr -d "\n")
    
            total_tests=$((total_tests + 2))  # Two tests per case: encode and decode

            # Test encoding
            encoded=$(rlp_encode "$in_value")
            if [ "$encoded" == "$out_value" ]; then
                echo -e "${GREEN}PASS${NC}: Encoding $test_name"
                passed_tests=$((passed_tests + 1))
            else
                echo -e "${RED}FAIL${NC}: Encoding $test_name"
                echo "  Expected: $out_value"
                echo "  Got: $encoded"
            fi

            # Test decoding
            decoded=$(rlp_decode "$out_value")
            if [ "$decoded" == "$in_value" ]; then
                echo -e "${GREEN}PASS${NC}: Decoding $test_name"
                passed_tests=$((passed_tests + 1))
            else
                echo -e "${RED}FAIL${NC}: Decoding $test_name"
                echo "  Expected: $in_value"
                echo "  Got: $decoded"
            fi

            echo
        fi
    done < "$test_data"

    echo "Total tests: $total_tests"
    echo "Passed tests: $passed_tests"
    echo "Failed tests: $((total_tests - passed_tests))"
}

run_tests "tests/tests.json"
