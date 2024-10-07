#!/bin/bash

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

aesgcm_encrypt() {
    local read_key="$1"
    local nonce="$2"
    local message_pt="$3"
    local message_ad="$4"
    python cryptography/aes_gcm.py encrypt "$read_key" "$nonce" "$message_pt" "$message_ad"
}

aesgcm_decrypt() {
    local read_key="$1"
    local nonce="$2"
    local encrypted_message="$3"
    local message_ad="$4"
    python cryptography/aes_gcm.py decrypt "$read_key" "$nonce" "$encrypted_message" "$message_ad"
}

aesctr_encrypt() {
    local masking_key="$1"
    local masking_iv="$2"
    local message_pt="$3"

    # if file descriptor 0 (stdin) is associated with a terminal
    if [ -t 0 ]; then
        openssl enc -aes-128-ctr -K "$masking_key" -iv "$masking_iv" -nosalt "$message_pt"

    # otherwise, the input is being piped from another command or redirected from a file
    else
         # If input is piped, read from stdin
        cat - | openssl enc -aes-128-ctr -K "$masking_key" -iv "$masking_iv" -nosalt
    fi
}

aesctr_decrypt() {
    local masking_key="$1"
    local masking_iv="$2"
    local encrypted_message="$3"
    
    # if file descriptor 0 (stdin) is associated with a terminal
    if [ -t 0 ]; then
        openssl enc -aes-128-ctr -d -K "$masking_key" -iv "$masking_iv" -nosalt "$encrypted_message"
    
    # otherwise, the input is being piped from another command or redirected from a file
    else
         # If input is piped, read from stdin
        cat - | openssl enc -aes-128-ctr -d -K "$masking_key" -iv "$masking_iv" -nosalt
    fi
}

ecdsa_sign() {
    local message="$1"
    local private_key="$2"
    python cryptography/ecdsa_sign.py "$message" "$private_key"
}

sha256() {
    # if file descriptor 0 (stdin) is associated with a terminal
    if [ -t 0 ]; then
        openssl dgst -sha256 -binary "$1"

    # otherwise, the input is being piped from another command or redirected from a file
    else
        # If input is piped, read from stdin
        cat - | openssl dgst -sha256 -binary
    fi
}