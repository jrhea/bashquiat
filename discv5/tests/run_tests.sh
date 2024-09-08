#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/../discv5.sh

test_whoareyou() {
    local challenge_data="$1"
    local expected_output="$2"
    local DEST_ID="bbbb9d047f0488c0b5a93c1c3f2d8bafc7c8ff337024a55434a0d0555de64db9"

    if [ -n "$challenge_data" ]; then
        parse_challenge_data "$challenge_data"
        printf 'Using provided challenge data\n'
    else
        # Generate random values for components
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

    whoareyou_message=$(encode_whoareyou "$DEST_ID" "$NONCE" "$ID_NONCE" "$ENR_SEQ" "$MASKING_IV")

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