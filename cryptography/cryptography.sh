#!/bin/bash

# This function creates a keypair for secp256k1 curve
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

# This function encrypts an AES-GCM message using the provided read key
aesgcm_encrypt() {
    local read_key="$1"
    local nonce="$2"
    local message_pt="$3"
    local message_ad="$4"
    python cryptography/aes_gcm.py encrypt "$read_key" "$nonce" "$message_pt" "$message_ad"
}

# This function decrypts an AES-GCM encrypted message using the provided read key
aesgcm_decrypt() {
    local read_key="$1"
    local nonce="$2"
    local encrypted_message="$3"
    local message_ad="$4"
    python cryptography/aes_gcm.py decrypt "$read_key" "$nonce" "$encrypted_message" "$message_ad"
}

# This function encrypts an AES-CTR message using the provided masking key and IV
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

# This function decrypts an AES-CTR encrypted message using the provided masking key and IV
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

# This function generates an ECDSA signature based on the provided message and private key
ecdsa_sign() {
    local message="$1"
    local private_key="$2"
    python cryptography/ecdsa_sign.py "$message" "$private_key"
}

ecdsa_verify() {
    local message_hash="$1"    # The hex-encoded SHA256 hash of the message
    local signature="$2"       # The hex-encoded signature (r || s)
    local public_key="$3"      # The hex-encoded compressed public key (33 bytes, starts with 02 or 03)

    # Call the Python script to perform verification
    local result=$(python cryptography/ecdsa_verify.py "$message_hash" "$signature" "$public_key")
    if [ $? -ne 0 ]; then
        printf "Error: Verification failed due to an error in the Python script.\n" >&2
        return 1
    fi

    if [ "$result" == "True" ]; then
        return 0  # Verification successful
    else
        return 1  # Verification failed
    fi
}

# This function computes the Keccak-256 hash of the input.
# Note: Inputs are expected to be hex encoded
keccak_256() {
    local input

    # if file descriptor 0 (stdin) is associated with a terminal
    if [ -t 0 ]; then
        # Use command-line argument
        input="$1"
    
    # otherwise, the input is being piped from another command or redirected from a file
    else
        # Read from pipe
        input=$(cat)
    fi
    python cryptography/keccak_256.py "$input"
}