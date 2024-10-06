#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

test_generate_secp256k1_keypair() {
    printf "Testing generate_secp256k1_keypair...\n"

    # Call the function
    read private_key_hex public_key_hex private_key_file <<< $(generate_secp256k1_keypair)

    local test_passed=true

    # Check if private key is 64 hex characters (32 bytes)
    if [ ${#private_key_hex} -ne 64 ]; then
        printf "Private key length mismatch: expected 64 hex characters, got %d\n" "${#private_key_hex}"
        test_passed=false
    else
        printf "Private key length is correct: 64 hex characters\n"
    fi

    # Check if public key is 66 hex characters (33 bytes)
    if [ ${#public_key_hex} -ne 66 ]; then
        printf "Public key length mismatch: expected 66 hex characters, got %d\n" "${#public_key_hex}"
        test_passed=false
    else
        printf "Public key length is correct: 66 hex characters\n"
    fi

    # Verify that the private key and public key are valid hex strings
    if ! [[ "$private_key_hex" =~ ^[0-9a-fA-F]{64}$ ]]; then
        printf "Private key is not a valid hex string\n"
        test_passed=false
    else
        printf "Private key is a valid hex string\n"
    fi

    if ! [[ "$public_key_hex" =~ ^0[23][0-9a-fA-F]{64}$ ]]; then
        printf "Public key is not a valid compressed secp256k1 public key\n"
        test_passed=false
    else
        printf "Public key is a valid compressed secp256k1 public key\n"
    fi

    # Optionally, verify that the public key corresponds to the private key
    # Since we have the private key file, we can extract the public key from it and compare
    
    local public_key_from_private=$(openssl ec -in "$private_key_file" -pubout -conv_form compressed -outform DER 2>/dev/null \
        | tail -c 33 | xxd -p -c 66)

    printf "Public key from private key: %s\n" "$public_key_from_private"
    printf "Public key from function: %s\n" "$public_key_hex"


    if [ "$public_key_hex" != "$public_key_from_private" ]; then
        printf "Public key does not match the one derived from the private key\n"
        test_passed=false
    else
        printf "Public key matches the one derived from the private key\n"
    fi

    # Clean up the temporary private key file
    rm -f "$private_key_file"

    if $test_passed; then
        printf "Test PASSED: generate_secp256k1_keypair function works correctly.\n"
    else
        printf "Test FAILED: generate_secp256k1_keypair function has issues.\n"
    fi
}

test_generate_secp256k1_keypair