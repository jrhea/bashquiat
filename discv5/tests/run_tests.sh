#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/../cryptography/utils.sh
source $DIR/../discv5_codec.sh

# Test encoding and decoding of PING message
test_ping_message() {
    local src_node_id=$(generate_random_bytes 32 | bin_to_hex)
    local dest_node_id=$(generate_random_bytes 32 | bin_to_hex)
    local nonce=$(generate_random_bytes 12 | bin_to_hex)
    local read_key=$(generate_random_bytes 16 | bin_to_hex)
    local req_id=$(generate_random_bytes 2 | bin_to_hex)
    local enr_seq=$(generate_random_bytes 8 | bin_to_hex)

    echo "Encoding PING message..."
    local encoded_message=$(encode_ping_message "$src_node_id" "$dest_node_id" "$nonce" "$read_key" "$req_id" "$enr_seq")
    
    echo "Decoding PING message..."
    read -r decoded_protocol_id decoded_version decoded_flag decoded_nonce decoded_authdata_size decoded_src_node_id decoded_req_id \
            decoded_enr_seq <<< $(decode_ping_message "$encoded_message" "$dest_node_id" "$read_key")

    if [[ "$src_node_id" == "$decoded_src_node_id" && 
          "$req_id" == "$decoded_req_id" && 
          "$enr_seq" == "$decoded_enr_seq" ]]; then
        echo "Test PASSED: All decoded values match the original values."
    else
        echo "Test FAILED: Decoded values do not match the original values."
        echo "Original Source Node ID: $src_node_id"
        echo "Decoded Source Node ID: $decoded_src_node_id"
        echo "Original Request ID: $req_id"
        echo "Decoded Request ID: $decoded_req_id"
        echo "Original ENR Sequence Number: $enr_seq"
        echo "Decoded ENR Sequence Number: $decoded_enr_seq"
    fi
}

# Test encoding and decoding of PONG message
test_pong_message() {
    local src_node_id=$(generate_random_bytes 32 | bin_to_hex)
    local dest_node_id=$(generate_random_bytes 32 | bin_to_hex)
    local nonce=$(generate_random_bytes 12 | bin_to_hex)
    local read_key=$(generate_random_bytes 16 | bin_to_hex)
    local req_id=$(generate_random_bytes 2 | bin_to_hex)
    local enr_seq=$(generate_random_bytes 8 | bin_to_hex)
    local ip="$(( RANDOM % 256 )).$(( RANDOM % 256 )).$(( RANDOM % 256 )).$(( RANDOM % 256 ))"
    local port=$((RANDOM % 65536))

    echo "Encoding PONG message..."
    local encoded_message=$(encode_pong_message "$src_node_id" "$dest_node_id" "$nonce" "$read_key" "$req_id" "$enr_seq" "$ip" "$port")

    echo "Decoding PONG message..."
    read -r decoded_protocol_id decoded_version decoded_flag decoded_nonce decoded_authdata_size decoded_src_node_id decoded_req_id \
            decoded_enr_seq decoded_ip decoded_port <<< $(decode_pong_message "$encoded_message" "$dest_node_id" "$read_key")

    # Compare values
    local test_passed=true
    if [[ "$src_node_id" != "$decoded_src_node_id" ]]; then
        echo "Source Node ID mismatch:"
        echo "Original: $src_node_id"
        echo "Decoded:  $decoded_src_node_id"
        test_passed=false
    fi
    if [[ "$req_id" != "$decoded_req_id" ]]; then
        echo "Request ID mismatch:"
        echo "Original: $req_id"
        echo "Decoded:  $decoded_req_id"
        test_passed=false
    fi
    if [[ "$enr_seq" != "$decoded_enr_seq" ]]; then
        echo "ENR Sequence Number mismatch:"
        echo "Original: $enr_seq"
        echo "Decoded:  $decoded_enr_seq"
        test_passed=false
    fi
    if [[ "$ip" != "$decoded_ip" ]]; then
        echo "IP Address mismatch:"
        echo "Original: $ip"
        echo "Decoded:  $decoded_ip"
        test_passed=false
    fi
    if [[ "$port" != "$decoded_port" ]]; then
        echo "Port mismatch:"
        echo "Original: $port"
        echo "Decoded:  $decoded_port"
        test_passed=false
    fi

    if $test_passed; then
        echo "Test PASSED: All decoded values match the original values."
    else
        echo "Test FAILED: Some decoded values do not match the original values."
    fi
}

# Test encoding and decoding of FINDNODE message
test_findnode_message() {
    local src_node_id=$(generate_random_bytes 32 | bin_to_hex)
    local dest_node_id=$(generate_random_bytes 32 | bin_to_hex)
    local nonce=$(generate_random_bytes 12 | bin_to_hex)
    local read_key=$(generate_random_bytes 16 | bin_to_hex)
    local req_id=$(generate_random_bytes 2 | bin_to_hex)
    local distance=$(generate_random_bytes 8 | bin_to_hex)

    printf "Encoding FINDNODE message...\n"
    local encoded_message=$(encode_findnode_message "$src_node_id" "$dest_node_id" "$nonce" "$read_key" "$req_id" "$distance")

    printf "Decoding FINDNODE message...\n"
    local decoded_message=$(decode_findnode_message "$encoded_message" "$dest_node_id" "$read_key")

    # Parse decoded message
    read -r decoded_protocol_id decoded_version decoded_flag decoded_nonce decoded_authdata_size \
         decoded_src_node_id decoded_req_id decoded_distance <<< "$decoded_message"

    # Verify decoded values
    local test_passed=true
    if [[ "$src_node_id" != "$decoded_src_node_id" ]]; then
        printf "Source Node ID mismatch:\n"
        printf "Original: %s\n" "$src_node_id"
        printf "Decoded:  %s\n" "$decoded_src_node_id"
        test_passed=false
    fi
    if [[ "$req_id" != "$decoded_req_id" ]]; then
        printf "Request ID mismatch:\n"
        printf "Original: %s\n" "$req_id"
        printf "Decoded:  %s\n" "$decoded_req_id"
        test_passed=false
    fi
    if [[ "$distance" != "$decoded_distance" ]]; then
        printf "Distance mismatch:\n"
        printf "Original: %s\n" "$distance"
        printf "Decoded:  %s\n" "$decoded_distance"
        test_passed=false
    fi

    if $test_passed; then
        printf "Test PASSED: All decoded values match the original values.\n"
    else
        printf "Test FAILED: Some decoded values do not match the original values.\n"
    fi
}

# Test encoding and decoding of NODES message
test_nodes_message() {
    local src_node_id=$(generate_random_bytes 32 | bin_to_hex)
    local dest_node_id=$(generate_random_bytes 32 | bin_to_hex)
    local nonce=$(generate_random_bytes 12 | bin_to_hex)
    local read_key=$(generate_random_bytes 16 | bin_to_hex)
    local req_id=$(generate_random_bytes 2 | bin_to_hex)
    local total="1"
    local enr1="enr:-IS4QOqa3tC28XcDez-0qS8s0mQ8R1sg3KMVn0yYhJiI7hD6eIl3Y6A6l4qZbi1nKoF7wC-1JbG7YQP6g8jgLA3P8EABh2F0dG5ldHOIAAAAAAAAAACEZXRoMpB5xkmC"
    local enr2="enr:-IS4QOqa3tC28XcDez-0qS8s0mQ8R1sg3KMVn0yYhJiI7hD6eIl3Y6A6l4qZbi1nKoF7wC-1JbG7YQP6g8jgLA3P8EABh2F0dG5ldHOIAAAAAAAAAACEZXRoMpB5xkmD"

    printf "Encoding NODES message...\n"
    local encoded_message=$(encode_nodes_message "$src_node_id" "$dest_node_id" "$nonce" "$read_key" "$req_id" "$total" "$enr1" "$enr2")

    printf "Decoding NODES message...\n"
    local decoded_message=$(decode_nodes_message "$encoded_message" "$dest_node_id" "$read_key")

    # Parse decoded message
    # Read the first 8 components
    read -r decoded_protocol_id decoded_version decoded_flag decoded_nonce decoded_authdata_size \
         decoded_src_node_id decoded_req_id decoded_total <<< "$(echo "$decoded_message" | head -n1)"

    # Read the ENRs
    mapfile -t enrs <<< "$(echo "$decoded_message" | tail -n +2)"

    # Verify decoded values
    local test_passed=true
    if [[ "$src_node_id" != "$decoded_src_node_id" ]]; then
        printf "Source Node ID mismatch:\n"
        printf "Original: %s\n" "$src_node_id"
        printf "Decoded:  %s\n" "$decoded_src_node_id"
        test_passed=false
    fi
    if [[ "$req_id" != "$decoded_req_id" ]]; then
        printf "Request ID mismatch:\n"
        printf "Original: %s\n" "$req_id"
        printf "Decoded:  %s\n" "$decoded_req_id"
        test_passed=false
    fi
    if [[ "$total" != "$decoded_total" ]]; then
        printf "Total mismatch:\n"
        printf "Original: %s\n" "$total"
        printf "Decoded:  %s\n" "$decoded_total"
        test_passed=false
    fi
    if [[ "${enrs[0]}" != "$enr1" ]]; then
        printf "ENR1 mismatch:\n"
        printf "Original: %s\n" "$enr1"
        printf "Decoded:  %s\n" "${enrs[0]}"
        test_passed=false
    fi
    if [[ "${enrs[1]}" != "$enr2" ]]; then
        printf "ENR2 mismatch:\n"
        printf "Original: %s\n" "$enr2"
        printf "Decoded:  %s\n" "${enrs[1]}"
        test_passed=false
    fi

    if $test_passed; then
        printf "Test PASSED: All decoded values match the original values.\n"
    else
        printf "Test FAILED: Some decoded values do not match the original values.\n"
    fi
}

# Test encoding and decoding of WHOAREYOU message
test_whoareyou_message() {
    local nonce=$(generate_random_bytes 12 | bin_to_hex)
    local id_nonce=$(generate_random_bytes 16 | bin_to_hex)
    local enr_seq=$(generate_random_bytes 8 | bin_to_hex)

    echo "Encoding WHOAREYOU message..."
    local encoded_message=$(encode_whoareyou_message "$nonce" "$id_nonce" "$enr_seq" "$masking_iv")
    
    echo "Decoding WHOAREYOU message..."
    read -r decoded_protocol_id decoded_version decoded_flag decoded_nonce decoded_authdata_size decoded_id_nonce \
            decoded_enr_seq <<< $(decode_whoareyou_message "$encoded_message")

    # Compare values
    if [[ "$nonce" == "$decoded_nonce" && 
          "$id_nonce" == "$decoded_id_nonce" && 
          "$enr_seq" == "$decoded_enr_seq" ]]; then
        echo "Test PASSED: All decoded values match the original values."
    else
        echo "Test FAILED: Decoded values do not match the original values."
        echo "Original Nonce: $nonce"
        echo "Decoded Nonce: $decoded_nonce"
        echo "Original ID Nonce: $id_nonce"
        echo "Decoded ID Nonce: $decoded_id_nonce"
        echo "Original ENR Sequence Number: $enr_seq"
        echo "Decoded ENR Sequence Number: $decoded_enr_seq"
    fi
}

# Test encoding and decoding of HANDSHAKE message
test_handshake_message() {
    # Generate test data
    local src_node_id=$(generate_random_bytes 32 | bin_to_hex)
    local dest_node_id=$(generate_random_bytes 32 | bin_to_hex)
    local nonce=$(generate_random_bytes 12 | bin_to_hex)
    local read_key=$(generate_random_bytes 16 | bin_to_hex)
    local challenge_data=$(generate_random_bytes 32 | bin_to_hex)

    # Generate ephemeral key pair
    read ephemeral_private_key ephemeral_public_key ephemeral_private_key_file <<< $(generate_secp256k1_keypair)
    
    # Generate static private key
    read static_private_key static_public_key static_private_key_file <<< $(generate_secp256k1_keypair)

    local record=$(generate_random_bytes 100 | bin_to_hex) # Shortened for simplicity

    printf "Encoding HANDSHAKE message...\n"
    local encoded_message=$(encode_handshake_message "$src_node_id" "$dest_node_id" "$nonce" "$read_key" "$challenge_data" "$ephemeral_public_key" "$ephemeral_private_key" "$static_private_key" "$record")
    
    if [ $? -ne 0 ]; then
        printf "Encoding failed. Exiting test.\n"
        return 1
    fi

    printf "Decoding HANDSHAKE message...\n"
    local decoded_message=$(decode_handshake_message "$encoded_message" "$dest_node_id" "$read_key")

    # Parse decoded message
    read -r decoded_protocol_id decoded_version decoded_flag decoded_nonce decoded_authdata_size \
         decoded_src_node_id decoded_sig_size decoded_eph_key_size decoded_id_signature \
         decoded_ephemeral_public_key decoded_record <<< "$decoded_message"

    # Verify decoded values
    local test_passed=true
    if [[ "$src_node_id" != "$decoded_src_node_id" ]]; then
        printf "Source Node ID mismatch:\n"
        printf "Original: %s\n" "$src_node_id"
        printf "Decoded:  %s\n" "$decoded_src_node_id"
        test_passed=false
    fi
    if [[ "$record" != "$decoded_record" ]]; then
        printf "Record mismatch:\n"
        printf "Original: %s\n" "$record"
        printf "Decoded:  %s\n" "$decoded_record"
        test_passed=false
    fi
    if [[ $decoded_sig_size -ne 64 ]]; then
        printf "Unexpected signature size: %d\n" "$decoded_sig_size"
        test_passed=false
    fi
    if [[ $decoded_eph_key_size -ne 33 ]]; then
        printf "Unexpected ephemeral public key size: %d\n" "$decoded_eph_key_size"
        test_passed=false
    fi

    if $test_passed; then
        printf "Test PASSED: All decoded values match the original values.\n"
    else
        printf "Test FAILED: Some decoded values do not match the original values.\n"
    fi
}

test_ping_message
printf "\n"
test_pong_message
printf "\n"
test_findnode_message
printf "\n"
test_nodes_message
printf "\n"
test_whoareyou_message
printf "\n"
test_handshake_message