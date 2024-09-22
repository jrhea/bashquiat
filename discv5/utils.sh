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

generate_secp256k1_keypair() {
    local private_key_file=$(mktemp)

    # Generate private key using OpenSSL with secp256k1 curve
    openssl ecparam -genkey -name secp256k1 -noout -out "$private_key_file" >/dev/null 2>&1

    # Extract private key in hex (32 bytes)
    local keys_hex=$(openssl ec -in "$private_key_file" -text -noout 2>/dev/null \
        | tr -d '[:space:]:')
    local private_key_hex=$(printf "%s" "${keys_hex:23:64}")

    # Extract compressed public key in hex (33 bytes)
    local public_key_hex=$(openssl ec -in "$private_key_file" -pubout -conv_form compressed -outform DER 2>/dev/null \
        | tail -c 33 | bin_to_hex)
    
    # Output the private key hex, public key hex, and private key file
    printf "$private_key_hex $public_key_hex $private_key_file"
}
