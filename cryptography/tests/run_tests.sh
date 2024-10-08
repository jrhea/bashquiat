#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/../../discv5/utils.sh
source $DIR/../utils.sh

test_generate_secp256k1_keypair() {
    # Call the function
    read private_key_hex public_key_hex private_key_file <<< $(generate_secp256k1_keypair)

    local test_passed=true

    # Check if private key is 64 hex characters (32 bytes)
    if [ ${#private_key_hex} -ne 64 ]; then
        printf "Private key length mismatch: expected 64 hex characters, got %d\n" "${#private_key_hex}"
        test_passed=false
    fi

    # Check if public key is 66 hex characters (33 bytes)
    if [ ${#public_key_hex} -ne 66 ]; then
        printf "Public key length mismatch: expected 66 hex characters, got %d\n" "${#public_key_hex}"
        test_passed=false
    fi

    # Verify that the private key and public key are valid hex strings
    if ! [[ "$private_key_hex" =~ ^[0-9a-fA-F]{64}$ ]]; then
        printf "Private key is not a valid hex string\n"
        test_passed=false
    fi

    if ! [[ "$public_key_hex" =~ ^0[23][0-9a-fA-F]{64}$ ]]; then
        printf "Public key is not a valid compressed secp256k1 public key\n"
        test_passed=false
    fi

    # Optionally, verify that the public key corresponds to the private key
    # Since we have the private key file, we can extract the public key from it and compare
    
    local public_key_from_private=$(openssl ec -in "$private_key_file" -pubout -conv_form compressed -outform DER 2>/dev/null \
        | tail -c 33 | xxd -p -c 66)

    if [ "$public_key_hex" != "$public_key_from_private" ]; then
        printf "Public key does not match the one derived from the private key\n"
        test_passed=false
    fi

    # Clean up the temporary private key file
    rm -f "$private_key_file"

    if $test_passed; then
        printf "test_generate_secp256k1_keypair: Test PASSED: generate_secp256k1_keypair function works correctly.\n"
    else
        printf "test_generate_secp256k1_keypair: Test FAILED: generate_secp256k1_keypair function has issues.\n"
    fi
}

test_id_sign(){
    static_private_key="fb757dc581730490a1d7a00deea65e9b1936924caaea8f44d476014856b68736"
    challenge_data="000000000000000000000000000000006469736376350001010102030405060708090a0b0c00180102030405060708090a0b0c0d0e0f100000000000000000"
    ephemeral_public_key="039961e4c2356d61bedb83052c115d311acb3a96f5777296dcf297351130266231"
    dest_node_id="bbbb9d047f0488c0b5a93c1c3f2d8bafc7c8ff337024a55434a0d0555de64db9"

    local calculated_id_signature=$(id_sign "$challenge_data" "$ephemeral_public_key" "$dest_node_id" "$static_private_key")
    local expected_id_signature="94852a1e2318c4e5e9d422c98eaf19d1d90d876b29cd06ca7cb7546d0fff7b484fe86c09a064fe72bdbef73ba8e9c34df0cd2b53e9d65528c2c7f336d5dfc6e6"

    if [[ "$calculated_id_signature" != "$expected_id_signature" ]]; then
        printf "test_id_sign: Test FAILED: signature mismatch.\n"
        printf "Calculated: %s\n" "$calculated_id_signature"
        printf "Expected:   %s\n" "$expected_id_signature"
    else
        printf "test_id_sign: Test PASSED: signature matches.\n"
    fi  
}

test_id_sign_and_verify() {
    # Test inputs
    static_private_key="fb757dc581730490a1d7a00deea65e9b1936924caaea8f44d476014856b68736"
    static_public_key="030e2cb74241c0c4fc8e8166f1a79a05d5b0dd95813a74b094529f317d5c39d235"
    challenge_data="000000000000000000000000000000006469736376350001010102030405060708090a0b0c00180102030405060708090a0b0c0d0e0f100000000000000000"
    ephemeral_pubkey="039961e4c2356d61bedb83052c115d311acb3a96f5777296dcf297351130266231"
    dest_node_id="bbbb9d047f0488c0b5a93c1c3f2d8bafc7c8ff337024a55434a0d0555de64db9"
    
    # Generate the signature using id_sign
    local calculated_id_signature
    calculated_id_signature=$(id_sign "$challenge_data" "$ephemeral_pubkey" "$dest_node_id" "$static_private_key")
    if [ $? -ne 0 ]; then
        printf "test_id_sign_and_verify: Test FAILED: id_sign function returned an error.\n"
        return 1
    fi

    # Verify the signature using id_verify, passing static_public_key
    if id_verify "$challenge_data" "$ephemeral_pubkey" "$dest_node_id" "$calculated_id_signature" "$static_public_key"; then
        printf "test_id_sign_and_verify: Test PASSED: Signature verified successfully.\n"
        return 0
    else
        printf "test_id_sign_and_verify: Test FAILED: Signature verification failed.\n"
        return 1
    fi
}

test_generate_secp256k1_keypair
printf "\n"
test_id_sign
printf "\n"
test_id_sign_and_verify