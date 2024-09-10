#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/utils.sh
source $DIR/../rlp/rlp_codec.sh

# static-header = protocol-id || version || flag || nonce || authdata-size
# protocol-id   = "discv5"
# version       = 0x0001
# authdata-size = uint16    -- byte length of authdata
# flag          = uint8     -- packet type identifier
# nonce         = uint96    -- nonce of message
encode_static_header() {
    local version="$1"
    local flag="$2"
    local nonce="$3"
    local authdata_size="$4"

    # Ensure each component is the correct length
    protocol_id=$(printf "discv5" | bin_to_hex)
    version=$(printf '%04s' "$version")
    flag=$(printf '%02s' "$flag")
    nonce=$(printf '%024s' "$nonce")
    authdata_size=$(printf '%04s' "$authdata_size")

    # Combine all components
    printf "${protocol_id}${version}${flag}${nonce}${authdata_size}"
}

# Function to encode the PING message (flag = 0x02)
encode_ping_message() {
    local src_node_id="$1"
    local dest_node_id="$2"
    local nonce="$3"
    local read_key="$4"
    local req_id="$5"
    local enr_seq="$6"

    # Convert inputs to hex if they're not already
    src_node_id=$(ensure_hex "$src_node_id" 32)
    dest_node_id=$(ensure_hex "$dest_node_id" 32)
    nonce=$(ensure_hex "$nonce" 12)
    read_key=$(ensure_hex "$read_key" 16)
    req_id=$(ensure_hex "$req_id" 1)
    #enr_seq=$(ensure_hex "$enr_seq" 1)

    # Check if any conversion failed
    if [[ -z "$src_node_id" || -z "$dest_node_id" || -z "$nonce" || -z "$read_key" || -z "$req_id" || -z "$enr_seq" ]]; then
        printf "Error: Failed to convert inputs to valid hex strings\n" >&2
        return 1
    fi

    # Ensure nonce and read_key are the correct length
    nonce=$(printf '%024s' "$nonce")
    read_key=$(printf '%032s' "$read_key")

    # Use read_key as masking IV
    local masking_iv=$read_key
    #local masking_iv=$(generate_random_bytes 32)

    # Protocol Version
    local version="0001"

    # PING message flag
    local flag="00"
    
    # Fixed authdata size for ordinary messages (32 bytes for src-id)
    local authdata_size="0020"

    # Encode static header
    local static_header=$(encode_static_header "$version" "$flag" "$nonce" "$authdata_size")

    # Combine static header and src_node_id for the full header
    local authdata=$src_node_id  # SRC Node ID is 32 bytes (64 characters)
    local header="${static_header}${authdata}"
    

    # Encode masked header
    local masked_header=$(printf '%s' "$header" | hex_to_bin | openssl enc -aes-128-ctr -K "${dest_node_id:0:32}" -iv "$masking_iv" -nosalt | bin_to_hex)

    # Prepare the message content (PING RLP: [message_type, req_id, enr_seq])
    local message_type="01"  # 0x01 for PING
    local rlp_message_content=$(rlp_encode "[\"$req_id\",\"$enr_seq\"]")

    # Combine message type and RLP-encoded content
    # message-pt    = message-type || message-data
    local message_pt=$message_type$rlp_message_content

    # Prepare the message AD (associated data)
    # message-ad    = masking-iv || header
    local message_ad=$masking_iv$masked_header

    # Encrypt the message content using AES-GCM
    # message       = aesgcm_encrypt(initiator-key, nonce, message-pt, message-ad)
    local encrypted_message=$(python discv5/aes_gcm.py encrypt "$read_key" "$nonce" "$message_pt" "$message_ad")
    #local encrypted_message=$(printf '%s' "$message_pt" | hex_to_bin | /usr/local/libressl/bin/openssl enc -aes-128-gcm -K "$read_key" -iv "$nonce" | bin_to_hex)

    # Combine all parts
    local final_message="${message_ad}${encrypted_message}"

    # Return only the final message
    printf '%s' "$final_message"
}

# Function to decode the PING message
decode_ping_message() {
    local packet="$1"
    local dest_node_id="$2"
    local read_key="$3"

    # Extract masking IV and masked header
    local masking_iv=${packet:0:32}
    local masked_header=${packet:32}

    # Extract associated data and encrypted message
    local message_ad=${packet:0:142}  # masking_iv + masked_header (32 + 110 = 142)
    local encrypted_message=${packet:142:56}  # 28 bytes of ciphertext+tag (12 + 16 = 28)

    # Derive masking key (first 16 bytes of dest_node_id)
    local masking_key=${dest_node_id:0:32}

    # Decrypt header
    local header=$(printf '%s' "$masked_header" | hex_to_bin | openssl enc -aes-128-ctr -d -K "$masking_key" -iv "$masking_iv" -nosalt | bin_to_hex)

    # Extract header components
    local protocol_id=${header:0:12}
    local version=${header:12:4}
    local flag=${header:16:2}
    local nonce=${header:18:24}
    local authdata_size=${header:42:4}
    local src_node_id=${header:46:64}

    # Verify protocol ID
    if [ "$protocol_id" != "646973637635" ]; then  # "discv5" in hex
        printf "Invalid protocol ID\n"
        return 1
    fi

    # Verify flag (should be 00 for ordinary messages like PING)
    if [ "$flag" != "00" ]; then
        printf "Invalid flag: expected 00, got %s\n" "$flag"
        return 1
    fi
    local decrypted_message=$(python discv5/aes_gcm.py decrypt "$read_key" "$nonce" "$encrypted_message" "$message_ad")

    # Extract message type and content
    local message_type=${decrypted_message:0:2}
    local message_content=${decrypted_message:2}

    # Verify message type (should be 01 for PING)
    if [ "$message_type" != "01" ]; then
        printf "Invalid message type: expected 01, got %s\n" "$message_type"
        return 1
    fi

    # Parse RLP-encoded content
    decoded_rlp_message_content=$(rlp_decode "$message_content")
    IFS=',' read -ra array <<< "${decoded_rlp_message_content//[\[\]\"]/}"
    local req_id=${array[0]}
    local enr_seq=${array[1]}

    # Output decoded components
    printf "Protocol ID: %s\n" "$protocol_id"
    printf "Version: %s\n" "$version"
    printf "Flag: %s\n" "$flag"
    printf "Nonce: %s\n" "$nonce"
    printf "Authdata size: %s\n" "$authdata_size"
    printf "Source Node ID: %s\n" "$src_node_id"
    printf "Request ID: %s\n" "$req_id" 
    printf "ENR Sequence Number: %s\n" "$enr_seq"
}

encode_pong_message() {
    local src_node_id="$1"
    local dest_node_id="$2"
    local nonce="$3"
    local read_key="$4"
    local req_id="$5"
    local enr_seq="$6"
    local ip="$7"
    local port="$8"

    # Convert inputs to hex if they're not already
    src_node_id=$(ensure_hex "$src_node_id" 32)
    dest_node_id=$(ensure_hex "$dest_node_id" 32)
    nonce=$(ensure_hex "$nonce" 12)
    read_key=$(ensure_hex "$read_key" 16)
    req_id=$(ensure_hex "$req_id" 1)
    enr_seq=$(ensure_hex "$enr_seq" 8)

    # Check if any conversion failed
    if [[ -z "$src_node_id" || -z "$dest_node_id" || -z "$nonce" || -z "$read_key" || 
          -z "$req_id" || -z "$enr_seq" || -z "$ip" || -z "$port" ]]; then
        printf "Error: Failed to convert inputs to valid hex strings\n" >&2
        return 1
    fi

    # Use read_key as masking IV
    local masking_iv=$read_key

    # Protocol Version
    local version="0001"

    # PONG message flag
    local flag="00"
    
    # Fixed authdata size for ordinary messages (32 bytes for src-id)
    local authdata_size="0020"

    # Encode static header
    local static_header=$(encode_static_header "$version" "$flag" "$nonce" "$authdata_size")

    # Combine static header and src_node_id for the full header
    local authdata=$src_node_id
    local header="${static_header}${authdata}"

    # Encode masked header
    local masked_header=$(printf '%s' "$header" | hex_to_bin | openssl enc -aes-128-ctr -K "${dest_node_id:0:32}" -iv "$masking_iv" -nosalt | bin_to_hex)

    # Prepare the message content (PONG RLP: [req_id, enr_seq, ip, port])
    local message_type="02"  # 0x02 for PONG
    local rlp_message_content=$(rlp_encode "[\"$req_id\",\"$enr_seq\",\"$ip\",\"$port\"]")

    # Combine message type and RLP-encoded content
    local message_pt=$message_type$rlp_message_content

    # Prepare the message AD (associated data)
    local message_ad=$masking_iv$masked_header

    # Encrypt the message content using AES-GCM
    local encrypted_message=$(python discv5/aes_gcm.py encrypt "$read_key" "$nonce" "$message_pt" "$message_ad")

    # Combine all parts
    local final_message="${message_ad}${encrypted_message}"

    # Return the final message
    printf '%s' "$final_message"
}

decode_pong_message() {
    local packet="$1"
    local dest_node_id="$2"
    local read_key="$3"

    # Extract masking IV and masked header
    local masking_iv=${packet:0:32}
    local masked_header=${packet:32}

    # Extract associated data and encrypted message
    local message_ad=${packet:0:142}  # masking_iv + masked_header
    local encrypted_message=${packet:142}

    # Derive masking key (first 16 bytes of dest_node_id)
    local masking_key=${dest_node_id:0:32}

    # Decrypt header
    local header=$(printf '%s' "$masked_header" | hex_to_bin | openssl enc -aes-128-ctr -d -K "$masking_key" -iv "$masking_iv" -nosalt | bin_to_hex)

    # Extract header components
    local protocol_id=${header:0:12}
    local version=${header:12:4}
    local flag=${header:16:2}
    local nonce=${header:18:24}
    local authdata_size=${header:42:4}
    local src_node_id=${header:46:64}

    # Verify protocol ID
    if [ "$protocol_id" != "646973637635" ]; then  # "discv5" in hex
        printf "Invalid protocol ID\n" >&2
        return 1
    fi

    # Verify flag (should be 09 for ordinary messages)
    if [ "$flag" != "00" ]; then
        printf "Invalid flag: expected 00, got %s\n" "$flag" >&2
        return 1
    fi

    # Decrypt the message content
    local decrypted_message=$(python discv5/aes_gcm.py decrypt "$read_key" "$nonce" "$encrypted_message" "$message_ad")

    # Extract message type and content
    local message_type=${decrypted_message:0:2}
    local message_content=${decrypted_message:2}

    # Verify message type (should be 02 for PONG)
    if [ "$message_type" != "02" ]; then
        printf "Invalid message type: expected 02, got %s\n" "$message_type" >&2
        return 1
    fi

    # Parse RLP-encoded content
    local decoded_rlp_message_content=$(rlp_decode "$message_content")
    IFS=',' read -ra array <<< "${decoded_rlp_message_content//[\[\]\"]/}"
    local req_id=${array[0]}
    local enr_seq=${array[1]}
    local ip=${array[2]}
    local port=${array[3]}

    # Output decoded components
    printf "Protocol ID: %s\n" "$protocol_id"
    printf "Version: %s\n" "$version"
    printf "Flag: %s\n" "$flag"
    printf "Nonce: %s\n" "$nonce"
    printf "Authdata size: %s\n" "$authdata_size"
    printf "Source Node ID: %s\n" "$src_node_id"
    printf "Request ID: %s\n" "$req_id"
    printf "ENR Sequence Number: %s\n" "$enr_seq"
    printf "IP Address: %s\n" "$ip"
    printf "Port: %d\n" "$port"
}

# Function to encode the WHOAREYOU message (flag = 0x01)
encode_whoareyou_message() {
    local dest_node_id="$1"
    local nonce="$2"
    local id_nonce="$3"
    local enr_seq="$4"
    local masking_iv="$5"

    # Convert inputs to hex if they're not already
    dest_node_id=$(ensure_hex "$dest_node_id" 32)
    nonce=$(ensure_hex "$nonce" 12)
    id_nonce=$(ensure_hex "$id_nonce" 16) # 16 bytes for ID nonce
    enr_seq=$(ensure_hex "$enr_seq" 8)  # 8 bytes for ENR sequence number

    # Check if any conversion failed
    if [[ -z "$dest_node_id" || -z "$nonce" || -z "$id_nonce" || -z "$enr_seq" ]]; then
        printf "Error: Failed to convert inputs to valid hex strings\n" >&2
        return 1
    fi

    # Generate random masking IV if not provided
    if [ -z "$masking_iv" ]; then
        masking_iv=$(generate_random_bytes 32)
    fi

    # Protocol Version
    local version="0001"

    # WHOAREYOU message flag
    local flag="01"
    
    # Fixed authdata size for WHOAREYOU = 24
    local authdata_size="0018"

    # Build the header
    local static_header=$(encode_static_header "$version" "$flag" "$nonce" "$authdata_size")
    local header="${static_header}${id_nonce}${enr_seq}"

    # Derive masking key (first 16 bytes of dest_node_id)
    local masking_key="${dest_node_id:0:32}"

    # Encrypt header
    local masked_header=$(printf '%s' "$header" | hex_to_bin | openssl enc -aes-128-ctr -K "$masking_key" -iv "$masking_iv" -nosalt | bin_to_hex)

    # Combine masking IV and masked header
    printf '%s%s' "$masking_iv" "$masked_header"
}

# Decode WHOAREYOU message (flag = 0x01)
decode_whoareyou_message() {
    local packet=$1
    local dest_id=$2

    # Extract masking IV and masked header
    local masking_iv=${packet:0:32}
    local masked_header=${packet:32}

    # Derive masking key (first 16 bytes of dest_id)
    local masking_key=${dest_id:0:32}

    # Decrypt header
    local header=$(echo -n "$masked_header" | hex_to_bin | openssl enc -aes-128-ctr -d -K "$masking_key" -iv "$masking_iv" -nosalt | bin_to_hex)

    # Extract header components
    local protocol_id=${header:0:12}
    local version=${header:12:4}
    local flag=${header:16:2}
    local nonce=${header:18:24}
    local authdata_size=${header:42:4}
    local id_nonce=${header:46:32}
    local enr_seq=${header:78:16}

    # Verify protocol ID
    if [ "$protocol_id" != "646973637635" ]; then  # "discv5" in hex
        printf "Invalid protocol ID"
        return 1
    fi

    # Output decoded components
    printf "Protocol ID: %s\n" "$protocol_id"
    printf "Version: %s\n" "$version"
    printf "Flag: %s\n" "$flag"
    printf "Req Nonce: %s\n" "$nonce"
    printf "Authdata size: %s\n" "$authdata_size"
    printf "ID Nonce: %s\n" "$id_nonce"
    printf "ENR Seq: %s\n" "$enr_seq"
}