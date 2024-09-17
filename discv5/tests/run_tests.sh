#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/../discv5_codec.sh

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

test_whoareyou_message() {
    local dest_node_id=$(generate_random_bytes 32 | bin_to_hex)
    local nonce=$(generate_random_bytes 12 | bin_to_hex)
    local id_nonce=$(generate_random_bytes 16 | bin_to_hex)
    local enr_seq=$(generate_random_bytes 8 | bin_to_hex)
    local masking_iv=$(generate_random_bytes 16 | bin_to_hex)

    echo "Encoding WHOAREYOU message..."
    local encoded_message=$(encode_whoareyou_message "$dest_node_id" "$nonce" "$id_nonce" "$enr_seq" "$masking_iv")
    
    echo "Decoding WHOAREYOU message..."
    read -r decoded_protocol_id decoded_version decoded_flag decoded_nonce decoded_authdata_size decoded_id_nonce \
            decoded_enr_seq <<< $(decode_whoareyou_message "$encoded_message" "$dest_node_id")

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

test_handshake_message() {
    # Generate test data
    local src_node_id=$(generate_random_bytes 32 | bin_to_hex)
    local dest_node_id=$(generate_random_bytes 32 | bin_to_hex)
    local nonce=$(generate_random_bytes 12 | bin_to_hex)
    local read_key=$(generate_random_bytes 16 | bin_to_hex)
    local challenge_data=$(generate_random_bytes 32 | bin_to_hex)

    # Generate ephemeral key pair
    local ephemeral_key=$(openssl ecparam -name secp256k1 -genkey -noout -outform DER | xxd -p -c 256)
    local ephemeral_private_key=${ephemeral_key:14:64}
    local ephemeral_public_key=$(openssl ec -inform DER -in <(printf "%s" "$ephemeral_key" | xxd -r -p) -pubout -outform DER -conv_form compressed 2>/dev/null | tail -c 33 | xxd -p -c 66)
    
    # Generate static private key
    local static_key=$(openssl ecparam -name secp256k1 -genkey -noout -outform DER | xxd -p -c 256)
    local static_private_key=${static_key:14:64}

    local record=$(openssl rand -hex 100)  # Shortened for simplicity

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
test_whoareyou_message
printf "\n"
test_handshake_message