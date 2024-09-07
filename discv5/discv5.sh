#!/bin/bash

# Ethereum Discovery V5

set -e

# Function to convert hex to binary
hex_to_bin() {
    local hex
    hex=$(cat)  # Read from stdin
    local len=${#hex}
    for ((i=0; i<len; i+=2)); do
        printf "\\x${hex:i:2}"
    done
}

# Function to convert binary to hex
bin_to_hex() {
    local LC_ALL=C
    local c
    while IFS= read -r -d '' -n 1 c; do
        printf '%02x' "'$c"
    done
    # Handle the last byte if it's not null
    if [ -n "$c" ]; then
        printf '%02x' "'$c"
    fi
}

# Function to generate random bytes (hexadecimal string)
generate_random_bytes() {
    local length=$1
    local result=""
    for ((i=0; i<length; i+=2)); do
        result+=$(printf "%02x" $((RANDOM % 256)))
    done
    printf "%s" "$result"
}

# Function to parse challenge data
parse_challenge_data() {
    local challenge_data="$1"

    # Extract masking IV
    printf -v MASKING_IV "%s" "${challenge_data:0:32}"

    # Extract and parse static header
    local static_header_data="${challenge_data:32:46}"  # 23 bytes (46 hex characters)
    printf -v PROTOCOL_ID "%s" "${header_data:0:12}"
    printf -v VERSION "%s" "${header_data:12:4}"
    printf -v FLAG "%s" "${header_data:16:2}"
    printf -v NONCE "%s" "${header_data:18:24}"
    printf -v AUTHDATA_SIZE "%s" "${header_data:42:4}"

    # Extract authdata
    printf -v ID_NONCE "%s" "${challenge_data:78:32}"
    printf -v ENR_SEQ "%s" "${challenge_data:110:16}"
}

# static-header = protocol-id || version || flag || nonce || authdata-size
# protocol-id   = "discv5"
# version       = 0x0001
# authdata-size = uint16    -- byte length of authdata
# flag          = uint8     -- packet type identifier
# nonce         = uint96    -- nonce of message
encode_static_header() {
    local version="$1"
    local flag="$2"
    local nonce="$3"
    local authdata_size="$4"

    # Ensure each component is the correct length
    protocol_id=$(printf "discv5" | bin_to_hex)
    version=$(printf '%04s' "$version")
    flag=$(printf '%02s' "$flag")
    nonce=$(printf '%024s' "$nonce")
    authdata_size=$(printf '%04s' "$authdata_size")

    # Combine all components
    printf "${protocol_id}${version}${flag}${nonce}${authdata_size}"
}

# Function to encode the complete header and encrypt it using the masking key (first 16 bytes of dest_node_id)
# header        = static-header || authdata
encode_masked_header() {
    local dest_node_id="$1"
    local version="$2"
    local flag="$3"
    local nonce="$4"
    local authdata_size="$5"
    local id_nonce="$6"
    local enr_seq="$7"
    local masking_iv="$8"

    # Build the header
    local static_header=$(encode_static_header "$version" "$flag" "$nonce" "$authdata_size")
    local header="${static_header}${id_nonce}${enr_seq}"

    # Derive masking key (first 16 bytes of dest_node_id)
    local masking_key="${dest_node_id:0:32}"

    # Encrypt header
    local masked_header=$(printf '%s' "$header" | hex_to_bin | openssl enc -aes-128-ctr -K "$masking_key" -iv "$masking_iv" -nosalt | bin_to_hex)

    printf '%s' "$masked_header"
}

# Function to encode the WHOAREYOU message
encode_whoareyou() {
    local dest_node_id="$1"
    local version="$2"
    local flag="$3"
    local nonce="$4"
    local id_nonce="$5"
    local enr_seq="$6"
    local masking_iv="$7"

    # Generate random masking IV if not provided
    if [ -z "$masking_iv" ]; then
        masking_iv=$(generate_random_bytes 32)
    fi

    # Fixed authdata size for WHOAREYOU (24 bytes)
    local authdata_size="0018"

    # Encode masked header
    local masked_header=$(encode_masked_header "$dest_node_id" "$version" "$flag" "$nonce" "$authdata_size" "$id_nonce" "$enr_seq" "$masking_iv")

    # Combine masking IV and masked header
    printf '%s%s' "$masking_iv" "$masked_header"
}

# Decode WHOAREYOU message
decode_whoareyou() {
    local packet=$1
    local dest_id=$2

    # Extract masking IV and masked header
    local masking_iv=${packet:0:32}
    local masked_header=${packet:32}

    # Derive masking key (first 16 bytes of dest_id)
    local masking_key=${dest_id:0:32}

    # Decrypt header
    local header=$(echo -n "$masked_header" | hex_to_bin | openssl enc -aes-128-ctr -d -K "$masking_key" -iv "$masking_iv" -nosalt | bin_to_hex)

    # Extract header components
    local protocol_id=${header:0:12}
    local version=${header:12:4}
    local flag=${header:16:2}
    local nonce=${header:18:24}
    local authdata_size=${header:42:4}
    local id_nonce=${header:46:32}
    local enr_seq=${header:78:16}

    # Verify protocol ID
    if [ "$protocol_id" != "646973637635" ]; then  # "discv5" in hex
        printf "Invalid protocol ID"
        return 1
    fi

    # Output decoded components
    printf "Protocol ID: $protocol_id\n"
    printf "Version: $version\n"
    printf "Flag: $flag\n"
    printf "Nonce: $nonce\n"
    printf "Authdata size: $authdata_size\n"
    printf "ID Nonce: $id_nonce\n"
    printf "ENR Seq: $enr_seq\n"
}

test_whoareyou() {
    local challenge_data="$1"
    local expected_output="$2"
    local DEST_ID="bbbb9d047f0488c0b5a93c1c3f2d8bafc7c8ff337024a55434a0d0555de64db9"

    if [ -n "$challenge_data" ]; then
        parse_challenge_data "$challenge_data"
        printf 'Using provided challenge data\n'
    else
        # Generate random values for components
        VERSION="0001"  # This is typically fixed
        FLAG="01"       # This is typically fixed for WHOAREYOU
        NONCE=$(generate_random_bytes 24)
        ID_NONCE=$(generate_random_bytes 32)
        printf -v ENR_SEQ '%016x' $((RANDOM % 1000000))  # Random ENR sequence number
        MASKING_IV=$(generate_random_bytes 32)

        printf 'Generated random values:\n'
        printf 'NONCE: %s\n' "$NONCE"
        printf 'ID_NONCE: %s\n' "$ID_NONCE"
        printf 'ENR_SEQ: %s\n' "$ENR_SEQ"
        printf 'MASKING_IV: %s\n' "$MASKING_IV"
    fi

    whoareyou_message=$(encode_whoareyou "$DEST_ID" "$VERSION" "$FLAG" "$NONCE" "$ID_NONCE" "$ENR_SEQ" "$MASKING_IV")

    printf 'WHOAREYOU Message: %s\n' "$whoareyou_message"
    printf 'Length: %d\n' "${#whoareyou_message}"

    if [ -n "$expected_output" ]; then
        if [ "$whoareyou_message" = "$expected_output" ]; then
            printf 'Encoding successful: Output matches expected value\n'
        else
            printf 'Encoding failed: Output does not match expected value\n'
            printf 'Expected: %s\n' "$expected_output"
            printf 'Got:      %s\n' "$whoareyou_message"
        fi
    else
        # Verify the length of the message
        expected_length=126  # 63 bytes * 2 (hex representation)
        if [ ${#whoareyou_message} -eq $expected_length ]; then
            printf 'Encoding successful: Output length is correct\n'
        else
            printf 'Encoding failed: Incorrect output length\n'
            printf 'Expected length: %d\n' "$expected_length"
            printf 'Actual length: %d\n' "${#whoareyou_message}"
        fi
    fi

    # Decode the generated WHOAREYOU message
    printf 'Decoding the generated WHOAREYOU message:\n'
    decode_whoareyou "$whoareyou_message" "$DEST_ID"
}

# To test with challenge data and expected output:
test_whoareyou "000000000000000000000000000000006469736376350001010102030405060708090a0b0c00180102030405060708090a0b0c0d0e0f100000000000000000" "00000000000000000000000000000000088b3d434277464933a1ccc59f5967ad1d6035f15e528627dde75cd68292f9e6c27d6b66c8100a873fcbaed4e16b8d"
printf '\n'
# To test without challenge data (using random values):
test_whoareyou "" ""