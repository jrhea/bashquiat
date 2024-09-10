#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/utils.sh
source $DIR/../rlp/rlp_codec.sh

# Function to encode header
encode_masked_header() {
    local version="$1"
    local flag="$2"
    local nonce="$3"
    local authdata_size="$4"
    local authdata="$5"
    local masking_key="$6"
    local masking_iv="$7"

    # Ensure each component is the correct length
    protocol_id=$(printf "discv5" | bin_to_hex)
    version=$(printf '%04s' "$version")
    flag=$(printf '%02s' "$flag")
    nonce=$(printf '%024s' "$nonce")
    authdata_size=$(printf '%04s' "$authdata_size")

    # Build static header
    # static-header = protocol-id || version || flag || nonce || authdata-size
    # protocol-id   = "discv5"
    # version       = 0x0001
    # authdata-size = uint16    -- byte length of authdata
    # flag          = uint8     -- packet type identifier
    # nonce         = uint96    -- nonce of message
    local static_header="${protocol_id}${version}${flag}${nonce}${authdata_size}"
    
    # Combine static header and authdata for the full header
    local header="${static_header}${authdata}"

    # Encode masked header
    local masked_header=$(printf '%s' "$header" | hex_to_bin | openssl enc -aes-128-ctr -K "$masking_key" -iv "$masking_iv" -nosalt | bin_to_hex)

    # Return the header
    printf '%s' "$masked_header"
}

# Function to decode the header of a message
decode_masked_header() {
    local packet="$1"
    local dest_node_id="$2"

    # Extract masking IV and masked header
    local masking_iv=${packet:0:32}
    local masked_header=${packet:32}

    # Derive masking key (first 16 bytes of dest_node_id)
    local masking_key=${dest_node_id:0:32}

    # Decrypt header
    local header=$(printf '%s' "$masked_header" | hex_to_bin | openssl enc -aes-128-ctr -d -K "$masking_key" -iv "$masking_iv" -nosalt | bin_to_hex)

    # Return the decrypted header
    printf '%s' "$header"
}

encrypt_message_data() {
    local message_type="$1"
    local rlp_message_content="$2"
    local masking_iv="$3"
    local masked_header="$4"
    local read_key="$5"
    local nonce="$6"

    # Combine message type and RLP-encoded content
    # message-pt    = message-type || message-data
    local message_pt=$message_type$rlp_message_content

    # Prepare the message AD (associated data)
    # message-ad    = masking-iv || masked_header
    local message_ad=$masking_iv$masked_header

    # Encrypt the message content using AES-GCM
    # message       = aesgcm_encrypt(initiator-key, nonce, message-pt, message-ad)
    local encrypted_message=$(python discv5/aes_gcm.py encrypt "$read_key" "$nonce" "$message_pt" "$message_ad")
    #local encrypted_message=$(printf '%s' "$message_pt" | hex_to_bin | /usr/local/libressl/bin/openssl enc -aes-128-gcm -K "$read_key" -iv "$nonce" | bin_to_hex)

    # Combine all parts
    local message_data="${message_ad}${encrypted_message}"

    # Return the final message
    printf '%s' "$message_data"
}

decrypt_message_data() {
    local packet="$1"
    local read_key="$2"
    local nonce="$3"
    local encrypted_message="$4"
    local message_ad="$5"

    # Extract associated data and encrypted message
    local message_ad=${packet:0:142}  # masking_iv + masked_header (32 + 110 = 142)
    local encrypted_message=${packet:142}  # 28 bytes of ciphertext+tag (12 + 16 = 28)

    # Decrypt the message content
    local decrypted_message=$(python discv5/aes_gcm.py decrypt "$read_key" "$nonce" "$encrypted_message" "$message_ad")

    # Extract message type and content
    local message_type=${decrypted_message:0:2}
    local message_content=${decrypted_message:2}

    # Return the decrypted message type and message contents
    printf '%s %s' "$message_type" "$message_content"
}


# Function to encode the PING message (flag = 0x02)
encode_ping_message() {
    local src_node_id="$1"
    local dest_node_id="$2"
    local nonce="$3"
    local read_key="$4"
    local req_id="$5"
    local enr_seq="$6"

    # Ensure nonce and read_key are the correct length
    nonce=$(printf '%024s' "$nonce")
    read_key=$(printf '%032s' "$read_key")

    # Use read_key as masking IV
    local masking_iv=$read_key

    # Protocol Version
    local version="0001"

    # PING message flag
    local flag="00"
    
    # Fixed authdata size for ordinary messages (32 bytes for src-id)
    local authdata_size="0020"
    local authdata=$src_node_id  # SRC Node ID is 32 bytes (64 characters)

    # Encode masked header
    local masked_header=$(encode_masked_header "$version" "$flag" "$nonce" "$authdata_size" "$authdata" "${dest_node_id:0:32}" "$masking_iv")

    # 0x01 for PING message
    local message_type="01" 

    # Prepare the message content (PING RLP: [message_type, req_id, enr_seq])
    local rlp_message_content=$(rlp_encode "[\"$req_id\",\"$enr_seq\"]") 

    local message_data=$(encrypt_message_data $message_type $rlp_message_content $masking_iv $masked_header $read_key $nonce)

    # Return message data
    printf '%s' "$message_data"
}

# Function to decode the PING message
decode_ping_message() {
    local packet="$1"
    local dest_node_id="$2"
    local read_key="$3"

    # Decode the header
    local header=$(decode_masked_header "$packet" "$dest_node_id")

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

    # Extract message_type and message_content
    read -r message_type message_content <<< $(decrypt_message_data "$packet" "$read_key" "$nonce" "$encrypted_message" "$message_ad")

    # Verify message type (should be 01 for PING)
    if [ "$message_type" != "01" ]; then
        printf "Invalid message type: expected 01, got %s\n" "$message_type"
        return 1
    fi

    # Parse RLP-encoded content
    local decoded_rlp_message_content=$(rlp_decode "$message_content")
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

    # Use read_key as masking IV
    local masking_iv=$read_key

    # Protocol Version
    local version="0001"

    # PONG message flag
    local flag="00"
    
    # Fixed authdata size for ordinary messages (32 bytes for src-id)
    local authdata_size="0020"
    local authdata=$src_node_id

    # Encode masked header
    local masked_header=$(encode_masked_header "$version" "$flag" "$nonce" "$authdata_size" "$authdata" "${dest_node_id:0:32}" "$masking_iv")

   # 0x02 for PONG message
    local message_type="02" 

    # Prepare the message content (PONG RLP: [message_type, req_id, enr_seq])
    local rlp_message_content=$(rlp_encode "[\"$req_id\",\"$enr_seq\",\"$ip\",\"$port\"]")

    local message_data=$(encrypt_message_data $message_type $rlp_message_content $masking_iv $masked_header $read_key $nonce)

    # Return message data
    printf '%s' "$message_data"
}

decode_pong_message() {
    local packet="$1"
    local dest_node_id="$2"
    local read_key="$3"

    # Decode the header
    local header=$(decode_masked_header "$packet" "$dest_node_id")

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

    # Verify flag (should be 00 for ordinary messages)
    if [ "$flag" != "00" ]; then
        printf "Invalid flag: expected 00, got %s\n" "$flag" >&2
        return 1
    fi

    # Extract message_type and message_content
    read -r message_type message_content <<< $(decrypt_message_data "$packet" "$read_key" "$nonce" "$encrypted_message" "$message_ad")

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

    # Check if any conversion failed
    if [[ -z "$dest_node_id" || -z "$nonce" || -z "$id_nonce" || -z "$enr_seq" ]]; then
        printf "Error: Failed to convert inputs to valid hex strings\n" >&2
        return 1
    fi

    # Protocol Version
    local version="0001"

    # WHOAREYOU message flag
    local flag="01"
    
    # Fixed authdata size for WHOAREYOU = 24
    local authdata_size="0018"

    # Combine id_nonce and enr_seq to create authdata
    local authdata="${id_nonce}${enr_seq}"

    # Encode masked header
    local masked_header=$(encode_masked_header "$version" "$flag" "$nonce" "$authdata_size" "$authdata" "${dest_node_id:0:32}" "$masking_iv")

    # Combine masking IV and masked header
    printf '%s%s' "$masking_iv" "$masked_header"
}

# Decode WHOAREYOU message (flag = 0x01)
decode_whoareyou_message() {
    local packet=$1
    local dest_id=$2

    # Decode the header
    local header=$(decode_masked_header "$packet" "$dest_node_id" "$read_key")

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

# Function to retrieve the message type from a packet
get_message_type() {
    local packet="$1"
    local read_key="$2"
    local nonce="$3"

    # Decrypt the message type and message content
    read -r message_type message_content <<< $(decrypt_message_data "$packet" "$read_key" "$nonce")

    # Extract message type and content
    local message_type=${decrypted_message:0:2}

    # Return the decrypted message type
    printf '%s' "$message_type"
}