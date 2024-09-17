#!/bin/bash

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

# Convert a hex string to its integer value
hex_to_int() {
    printf "%d" "$((16#$1))"
}

ensure_hex() {
    local input="$1"
    local byte_length="$2"
    local hex_length=$((byte_length * 2))

    # If input is already valid hex of correct length, return it
    if [[ $input =~ ^[0-9A-Fa-f]{$hex_length}$ ]]; then
        printf "%s" "$input"
        return 0
    fi

    # If input is a number, convert to hex
    if [[ $input =~ ^[0-9]+$ ]]; then
        printf "%0${hex_length}x" "$input"
        return 0
    fi

    # If input is a string, convert each character to hex
    if [[ $input =~ ^[a-zA-Z0-9]+$ ]]; then
        local hex=""
        for (( i=0; i<${#input}; i++ )); do
            hex+=$(printf "%02x" "'${input:$i:1}")
        done
        printf "%s" "${hex:0:$hex_length}"
        return 0
    fi

    # If we get here, input couldn't be converted
    return 1
}

ipv4_to_hex() {
    local ip="$1"
    local hex=""
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
        hex+=$(printf "%02x" "$octet")
    done
    echo "$hex"
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