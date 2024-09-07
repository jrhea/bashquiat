#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/../discv5.sh

# Function to parse JSON without jq
parse_json() {
    local json_content="$1"
    local key="$2"
    
    # Remove whitespace and newlines
    json_content="${json_content//[$'\t\r\n']}"
    
    # Extract value based on key
    json_content=$(echo "$json_content" | sed -E 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"?([^,"{}]*)("|\}|\]).*/\1/')
    
    echo "$json_content"
}

run_whoareyou_test() {
    local test_name="$1"
    read -r src_node_id
    read -r dest_node_id
    read -r challenge_data
    read -r request_nonce
    read -r id_nonce
    read -r enr_seq
    read -r expected_output

    src_node_id=$(printf "%s" "$src_node_id" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")
    dest_node_id=$(printf "%s" "$dest_node_id" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")
    challenge_data=$(printf "%s" "$challenge_data" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")
    request_nonce=$(printf "%s" "$request_nonce" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")
    id_nonce=$(printf "%s" "$id_nonce" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")
    enr_seq=$(printf "%s" "$enr_seq" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")
    expected_output=$(printf "%s" "$expected_output" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")

    printf '\nRunning test: %s\n' "$test_name"
    printf 'Source Node ID: %s\n' "$src_node_id"
    printf 'Destination Node ID: %s\n' "$dest_node_id"
    printf 'Challenge Data: %s\n' "$challenge_data"
    printf 'Request Nonce: %s\n' "$request_nonce"
    printf 'ID Nonce: %s\n' "$id_nonce"
    printf 'ENR Seq: %s\n' "$enr_seq"
    printf 'Expected Output: %s\n' "$expected_output"

    parse_challenge_data "$challenge_data"

    whoareyou_message=$(encode_whoareyou "$dest_node_id" "$VERSION" "$FLAG" "$NONCE" "$ID_NONCE" "$ENR_SEQ" "$MASKING_IV")

    printf 'Generated WHOAREYOU Message: %s\n' "$whoareyou_message"
    printf 'Length: %d\n' "${#whoareyou_message}"

    if [ "$whoareyou_message" = "$expected_output" ]; then
        printf 'Test passed: Output matches expected value\n'
    else
        printf 'Test failed: Output does not match expected value\n'
        printf 'Expected: %s\n' "$expected_output"
        printf 'Got:      %s\n' "$whoareyou_message"
    fi

    printf 'Decoding the generated WHOAREYOU message:\n'
    decode_whoareyou "$whoareyou_message" "$dest_node_id"
}

run_ping_test() {
    local test_name="$1"
    read -r src_node_id
    read -r dest_node_id
    read -r nonce
    read -r id_nonce
    read -r enr_seq
    read -r expected_output

    src_node_id=$(printf "%s" "$src_node_id" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")
    dest_node_id=$(printf "%s" "$dest_node_id" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")
    nonce=$(printf "%s" "$nonce" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")
    id_nonce=$(printf "%s" "$id_nonce" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")
    enr_seq=$(printf "%s" "$enr_seq" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")
    expected_output=$(printf "%s" "$expected_output" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")

    printf '\nRunning test: %s\n' "$test_name"
    printf 'Source Node ID: %s\n' "$src_node_id"
    printf 'Destination Node ID: %s\n' "$dest_node_id"
    printf 'Nonce: %s\n' "$nonce"
    printf 'ID Nonce: %s\n' "$id_nonce"
    printf 'ENR Seq: %s\n' "$enr_seq"
    printf 'Expected Output: %s\n' "$expected_output"

    parse_challenge_data "$challenge_data"

    ping_message=$(encode_ping "$dest_node_id" "$VERSION" "$FLAG" "$NONCE" "$ID_NONCE" "$ENR_SEQ" "$MASKING_IV")

    printf 'Generated PING Message: %s\n' "$ping_message"
    printf 'Length: %d\n' "${#ping_message}"

    if [ "$ping_message" = "$expected_output" ]; then
        printf 'Test passed: Output matches expected value\n'
    else
        printf 'Test failed: Output does not match expected value\n'
        printf 'Expected: %s\n' "$expected_output"
        printf 'Got:      %s\n' "$ping_message"
    fi

    printf 'Decoding the generated PING message:\n'
    decode_whoareyou "$ping_message" "$dest_node_id"
}

run_tests_from_json() {
    local input_file="$1"

    # Split the content into individual tests
    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*\"([^\"]+)\":[[:space:]]*\{ ]]; then
            test_name="${BASH_REMATCH[1]}"
            # Run the test
            if [[ ${test_name,,} == *whoareyou* ]]; then
                run_whoareyou_test "$test_name"
            elif [[ ${test_name,,} == *ping* ]]; then
                run_ping_test "$test_name"
            else
                printf '\nSkipping test: %s (not a valid test)\n' "$test_name"
            fi
        fi
    done < "$input_file"
}

# Usage: ./run_tests.sh path/to/input_file.json
if [ $# -eq 0 ]; then
    echo "Please provide the path to the JSON input file as an argument."
    exit 1
fi

run_tests_from_json "$DIR/$1"