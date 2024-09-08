#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/../discv5.sh

test_ping_message() {
    local src_node_id=$(generate_random_bytes 32 | bin_to_hex)
    local dest_node_id=$(generate_random_bytes 32 | bin_to_hex)
    local nonce=$(generate_random_bytes 12 | bin_to_hex)
    local read_key=$(generate_random_bytes 16 | bin_to_hex)
    local req_id=$(printf "%02x" $((RANDOM % 255)))
    local enr_seq=$(printf "%02x" $((RANDOM % 255)))

    echo "Encoding PING message..."
    local encoded_message=$(encode_ping_message "$src_node_id" "$dest_node_id" "$nonce" "$read_key" "$req_id" "$enr_seq")
    
    echo "Decoding PING message..."
    local decoded_output=$(decode_ping_message "$encoded_message" "$dest_node_id" "$read_key")

    echo "Checking decoded values..."
    local decoded_src_node_id=$(echo "$decoded_output" | grep "Source Node ID:" | awk '{print $4}')
    local decoded_req_id=$(echo "$decoded_output" | grep "Request ID:" | awk '{print $3}')
    local decoded_enr_seq=$(echo "$decoded_output" | grep "ENR Sequence Number:" | awk '{print $4}')

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


test_whoareyou_message() {
    local dest_node_id=$(generate_random_bytes 32 | bin_to_hex)
    local nonce=$(generate_random_bytes 12 | bin_to_hex)
    local id_nonce=$(generate_random_bytes 16 | bin_to_hex)
    local enr_seq=$(printf "%016x" $((RANDOM % 65536)))
    local masking_iv=$(generate_random_bytes 16 | bin_to_hex)

    echo "Encoding WHOAREYOU message..."
    local encoded_message=$(encode_whoareyou_message "$dest_node_id" "$nonce" "$id_nonce" "$enr_seq" "$masking_iv")
    
    echo "Decoding WHOAREYOU message..."
    local decoded_output=$(decode_whoareyou_message "$encoded_message" "$dest_node_id")

    echo "Checking decoded values..."
    local decoded_nonce=$(echo "$decoded_output" | grep "Req Nonce:" | awk '{print $3}')
    local decoded_id_nonce=$(echo "$decoded_output" | grep "ID Nonce:" | awk '{print $3}')
    local decoded_enr_seq=$(echo "$decoded_output" | grep "ENR Seq:" | awk '{print $3}')

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
test_ping_message
printf "\n"
test_whoareyou_message