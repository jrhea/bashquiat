#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/../codec.sh

# Function to parse JSON
parse_json() {
    local json_content="$1"
    local key="$2"
    
    # Remove whitespace and newlines
    json_content="${json_content//[$'\t\r\n']}"
    
    # Extract value based on key
    json_content=$(echo "$json_content" | sed -E 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"?([^,"{}]*)("|\}|\]).*/\1/')
    
    echo "$json_content"
}

# Function to parse whoareyou challenge data
parse_whoareyou_challenge_data() {
    local challenge_data="$1"

    # Extract masking IV
    printf -v MASKING_IV "%s" "${challenge_data:0:32}"

  # Extract and parse static header
    local static_header_data="${challenge_data:32:46}"  # 23 bytes (46 hex characters)
    printf -v PROTOCOL_ID "%s" "${static_header_data:0:12}"
    printf -v VERSION "%s" "${static_header_data:12:4}"
    printf -v FLAG "%s" "${static_header_data:16:2}"
    printf -v NONCE "%s" "${static_header_data:18:24}"
    printf -v AUTHDATA_SIZE "%s" "${static_header_data:42:4}"

    # Extract authdata
    printf -v ID_NONCE "%s" "${challenge_data:78:32}"
    printf -v ENR_SEQ "%s" "${challenge_data:110:16}"
}

# Function to parse whoareyou challenge data
parse_ping_challenge_data() {
    local challenge_data="$1"

    # Extract masking IV
    printf -v MASKING_IV "%s" "${challenge_data:0:32}"

  # Extract and parse static header
    local static_header_data="${challenge_data:32:46}"  # 23 bytes (46 hex characters)
    printf -v PROTOCOL_ID "%s" "${static_header_data:0:12}"
    printf -v VERSION "%s" "${static_header_data:12:4}"
    printf -v FLAG "%s" "${static_header_data:16:2}"
    printf -v NONCE "%s" "${static_header_data:18:24}"
    printf -v AUTHDATA_SIZE "%s" "${static_header_data:42:4}"

    # Extract authdata
    printf -v SRC_NODE_ID "%s" "${challenge_data:78:32}"
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
    parse_whoareyou_challenge_data "$challenge_data"
    whoareyou_message=$(encode_whoareyou_message "$dest_node_id" "$NONCE" "$ID_NONCE" "$ENR_SEQ" "$MASKING_IV")

    if [ "$whoareyou_message" = "$expected_output" ]; then
        printf 'Test passed: Output matches expected value\n'
    else
        printf 'Test failed: Output does not match expected value\n'
        printf 'Expected: %s\n' "$expected_output"
        printf 'Length: %d\n' "${#expected_output}"
        printf 'Got:      %s\n' "$whoareyou_message"
        printf 'Length: %d\n' "${#whoareyou_message}"
    fi

    printf 'Decoding the generated WHOAREYOU message:\n'
    read -r decoded_protocol_id decoded_version decoded_flag decoded_nonce decoded_authdata_size decoded_id_nonce \
            decoded_enr_seq <<< $(decode_whoareyou_message "$whoareyou_message" "$dest_node_id")
    printf "Protocol ID: %s\n" "$decoded_protocol_id"
    printf "Version: %s\n" "$decoded_version"
    printf "Flag: %s\n" "$decoded_flag"
    printf "Req Nonce: %s\n" "$decoded_nonce"
    printf "Authdata size: %s\n" "$decoded_authdata_size"
    printf "ID Nonce: %s\n" "$decoded_id_nonce"
    printf "ENR Seq: %s\n" "$decoded_enr_seq"
}

run_ping_test() {
    local test_name="$1"
    read -r src_node_id
    read -r dest_node_id
    read -r nonce
    read -r read_key
    read -r req_id
    read -r enr_seq
    read -r expected_output

    src_node_id=$(printf "%s" "$src_node_id" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")
    dest_node_id=$(printf "%s" "$dest_node_id" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")
    nonce=$(printf "%s" "$nonce" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")
    read_key=$(printf "%s" "$read_key" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")
    req_id=$(printf "%s" "$req_id" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")
    enr_seq=$(printf "%s" "$enr_seq" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")
    expected_output=$(printf "%s" "$expected_output" | cut -d: -f2 | sed 's/^ *//g' | sed 's/.\{1\}$//' | tr -d "\"" | tr -d "\n")

    printf '\nRunning test: %s\n' "$test_name"
    parse_ping_challenge_data "$challenge_data"
    ping_message=$(encode_ping_message "$src_node_id" "$dest_node_id" "$NONCE" "$read_key" "$req_id" "$enr_seq")

    if [ "$ping_message" = "$expected_output" ]; then
        printf 'Test passed: Output matches expected value\n'
    else
        printf 'Test failed: Output does not match expected value\n'
        printf 'Expected: %s\n' "$expected_output"
        printf 'Length: %d\n' "${#expected_output}"
        printf 'Got:      %s\n' "$ping_message"
        printf 'Length: %d\n' "${#ping_message}"
    fi

    printf 'Decoding the generated PING message:\n'
    read -r decoded_protocol_id decoded_version decoded_flag decoded_nonce decoded_authdata_size decoded_src_node_id decoded_req_id \
            decoded_enr_seq <<< $(decode_ping_message "$ping_message" "$dest_node_id" "$read_key")
    printf "Protocol ID: %s\n" "$decoded_protocol_id"
    printf "Version: %s\n" "$decoded_version"
    printf "Flag: %s\n" "$decoded_flag"
    printf "Nonce: %s\n" "$decoded_nonce"
    printf "Authdata size: %s\n" "$decoded_authdata_size"
    printf "Source Node ID: %s\n" "$decoded_src_node_id"
    printf "Request ID: %s\n" "$decoded_req_id" 
    printf "ENR Sequence Number: %s\n" "$decoded_enr_seq"
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

run_tests_from_json "$1"