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

# Function to generate random bytes (hexadecimal string)
generate_random_bytes() {
    local length=$1
    local result=""
    for ((i=0; i<length; i+=2)); do
        result+=$(printf "%02x" $((RANDOM % 256)))
    done
    printf "%s" "$result"
}