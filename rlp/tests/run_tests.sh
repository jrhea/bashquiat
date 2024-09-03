#!/bin/bash

source rlp_codec.sh

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
            in_value=$(printf "%s" "$in_line" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")
            out_value=$(printf "%s" "$out_line" | cut -d: -f2 | sed 's/^ *//g' | tr -d "\"" | tr -d "\n")
    
            total_tests=$((total_tests + 2))  # Two tests per case: encode and decode

            # Test encoding
            encoded=$(rlp_encode "$in_value")
            if [ "$encoded" == "$out_value" ]; then
                printf "${GREEN}PASS${NC}: Encoding %s\n" "$test_name"
                passed_tests=$((passed_tests + 1))
            else
                printf "${RED}FAIL${NC}: Encoding %s\n" "$test_name"
                printf "  Expected: %s\n" "$out_value"
                printf "  Got: %s\n" "$encoded"
            fi

            # Test decoding
            decoded=$(rlp_decode "$out_value")
            if [ "$decoded" == "$in_value" ]; then
                printf "${GREEN}PASS${NC}: Decoding %s\n" "$test_name"
                passed_tests=$((passed_tests + 1))
            else
                printf "${RED}FAIL${NC}: Decoding %s\n" "$test_name"
                printf "  Expected: %s\n" "$in_value"
                printf "  Got: %s\n" "$decoded"
            fi

            printf "\n"
        fi
    done < "$test_data"

    printf "Total tests: %d\n" "$total_tests"
    printf "Passed tests: %d\n" "$passed_tests"
    printf "Failed tests: %d\n" $((total_tests - passed_tests))
}

run_tests "tests/tests.json"