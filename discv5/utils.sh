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

# This function generates an ID signature based on the provided challenge data, 
# ephemeral public key, destination node ID, and private key.
id_sign() {
    local challenge_data="$1"
    local ephemeral_public_key="$2"
    local dest_node_id="$3"
    local private_key="$4"

    # Compute SHA256 hash of the concatenated binary data
    local id_signature_text="discovery v5 identity proof"
    local id_signature_hash=$( (printf "%s" "$id_signature_text"; printf "%s%s%s" "$challenge_data" "$ephemeral_public_key" "$dest_node_id" | hex_to_bin) | sha256sum | cut -d' ' -f1)

    # Use the Python script to generate the signature
    local signature=$(ecdsa_sign "$id_signature_hash" "$private_key")
    if [ $? -ne 0 ] || [ -z "$signature" ]; then
        printf "Error: Failed to generate signature\n" >&2
        return 1
    fi

    # Ensure the signature is the correct length (64 bytes in hex)
    if [ ${#signature} -ne 128 ]; then
        printf "Error: Signature has incorrect length: expected 128, got %d\n" "${#signature}" >&2
        return 1
    fi

    # Return the signature
    printf "%s" "$signature"
}

id_verify() {
    local challenge_data="$1"
    local ephemeral_public_key="$2"
    local dest_node_id="$3"
    local signature="$4"
    local static_public_key="$5"

    # Compute SHA256 hash of the concatenated binary data    
    local id_signature_text="discovery v5 identity proof"
    local id_signature_hash=$( (printf "%s" "$id_signature_text"; printf "%s%s%s" "$challenge_data" "$ephemeral_public_key" "$dest_node_id" | hex_to_bin) | sha256sum | cut -d' ' -f1)

    # Verify the signature
    if ecdsa_verify "$id_signature_hash" "$signature" "$static_public_key"; then
        return 0
    else
        return 1
    fi
}
