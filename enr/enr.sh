#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/../rlp/rlp.sh
source $DIR/../discv5/utils.sh
source $DIR/../cryptography/cryptography.sh

# Function to encode ENR
encode_enr() {
    local seq="$1"
    local public_key="$2"
    local private_key="$3"
    local ip="$4"
    local udp="$5"

    # Convert IP address to its hexadecimal representation
    local ip_hex=$(printf '%02x%02x%02x%02x' $(printf $ip | tr '.' ' '))

    # Convert UDP port to hexadecimal representation
    local udp_hex=$(printf '%04x' $udp)

    # Prepare key-value pairs as a string, sorted by key
    # Keys to include: "id", "ip", "secp256k1", "udp"
    # Sorted order: id, ip, secp256k1, udp

    # Build the content string
    local content_items
    content_items="${seq},"                     # Sequence number
    content_items="${content_items}id,v4,"      # id key and value
    content_items="${content_items}ip,${ip},"      # ip key and hex value
    content_items="${content_items}secp256k1,${public_key},"  # secp256k1 key and public key
    content_items="${content_items}udp,${udp}"     # udp key and hex value

    # RLP encode the content as a list
    local rlp_content
    rlp_content=$(rlp_encode "[$content_items]")

    # Hash the RLP-encoded content using keccak256
    local rlp_content_hash
    rlp_content_hash=$(printf "$rlp_content" | keccak_256)

    # Sign the hash
    local signature
    signature=$(ecdsa_sign "$rlp_content_hash" "$private_key")

    # Combine signature and content
    local signed_content_items
    signed_content_items="${signature},${content_items}"

    # RLP encode the signed content as a list
    local rlp_signed_content
    rlp_signed_content=$(rlp_encode "[$signed_content_items]")

    # Base64 encode using URL-safe base64 without padding
    local encoded
    encoded=$(printf "$rlp_signed_content" | hex_to_bin | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

    printf "enr:-%s" "$encoded"
}



