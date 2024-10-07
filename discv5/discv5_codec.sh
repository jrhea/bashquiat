#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/utils.sh
source $DIR/../rlp/rlp_codec.sh

# Function to encode header
encrypt_masked_header() {
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
    local masked_header=$(printf '%s' "$header" | hex_to_bin | aesctr_encrypt "$masking_key" "$masking_iv" | bin_to_hex)

    # Return the header
    printf '%s' "$masked_header"
}

# Function to decode the header of a message
decrypt_masked_header() {
    local packet="$1"
    local dest_node_id="$2"

    # Extract masking IV and masked header
    local masking_iv=${packet:0:32}
    local masked_header=${packet:32}

    # Derive masking key (first 16 bytes of dest_node_id)
    local masking_key=${dest_node_id:0:32}

    # Decrypt header
    local header=$(printf '%s' "$masked_header" | hex_to_bin | aesctr_decrypt "$masking_key" "$masking_iv" | bin_to_hex)

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
    local encrypted_message=$(aesgcm_encrypt "$read_key" "$nonce" "$message_pt" "$message_ad")
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
    local authdata_size="$4"

    # Convert authdata_size from hex to decimal
    local authdata_size_dec=$((16#$authdata_size))

    # Extract masking IV
    local masking_iv=${packet:0:32}

    # Calculate the length of the masked header
    local header_length=$((46 + authdata_size_dec * 2))  # Multiply by 2 for hex chars

    # Now proceed with the correct header length
    local masked_header=${packet:32:$header_length}

    # Combine masking IV and masked header to form the associated data
    local message_ad="${masking_iv}${masked_header}"

    # Extract the encrypted message (rest of the packet)
    local encrypted_message=${packet:$((32 + header_length))}

    # Decrypt the message content
    local decrypted_message=$(aesgcm_decrypt "$read_key" "$nonce" "$encrypted_message" "$message_ad" 2>/dev/null)

    # Extract message_type and message_content
    local message_type=${decrypted_message:0:2}
    local message_content=${decrypted_message:2}

    # Return the decrypted message type and message contents
    printf '%s %s' "$message_type" "$message_content"
}

# Function to generate a random packet
generate_random_message() {
    # Generate a random packet of a plausible size
    # 32 bytes for masking_iv + header, 44 bytes for encrypted content
    local random_packet=$(generate_random_bytes 76 | bin_to_hex)

    # Return the random packet
    printf "$random_packet"
}


# Function to encode the PING message (flag = 0x00)
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

    # 16 bytes of dest_node_id for masking key
    local masking_key="${dest_node_id:0:32}"  

    # 16 random bytes for masking IV
    local masking_iv=$(generate_random_bytes 16 | bin_to_hex)

    # Protocol Version
    local version="0001"

    # PING message flag
    local flag="00"
    
    # Fixed authdata size for ordinary messages (32 bytes for src-id)
    local authdata_size="0020"
    local authdata=$src_node_id  # SRC Node ID is 32 bytes (64 characters)

    # Encode masked header
    local masked_header=$(encrypt_masked_header "$version" "$flag" "$nonce" "$authdata_size" "$authdata" "$masking_key" "$masking_iv")

    # 0x01 for PING message
    local message_type="01" 

    # Prepare the message content (PING RLP: [message_type, req_id, enr_seq])
    local rlp_message_content=$(rlp_encode "[\"$req_id\",\"$enr_seq\"]") 

    local message_data=$(encrypt_message_data $message_type $rlp_message_content $masking_iv $masked_header $read_key $nonce)

    # Return message data
    printf '%s' "$message_data"
}

# Function to decode the PING message (flag = 0x00)
decode_ping_message() {
    local packet="$1"
    local dest_node_id="$2"
    local read_key="$3"

    # Decode the header
    local header=$(decrypt_masked_header "$packet" "$dest_node_id")

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

    # Verify flag (should be 00 for ordinary messages like PING)
    if [ "$flag" != "00" ]; then
        printf "Invalid flag: expected 00, got %s\n" "$flag" >&2
        return 1
    fi

    # Extract message_type and message_content
    read -r message_type message_content <<< $(decrypt_message_data "$packet" "$read_key" "$nonce" "$authdata_size")

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
    printf '%s %s %s %s %s %s %s %s %s %s' "$protocol_id" "$version" "$flag" "$nonce" "$authdata_size" "$src_node_id" "$req_id" "$enr_seq"
}

# Function to encode the PONG message (flag = 0x00)
encode_pong_message() {
    local src_node_id="$1"
    local dest_node_id="$2"
    local nonce="$3"
    local read_key="$4"
    local req_id="$5"
    local enr_seq="$6"
    local ip="$7"
    local port="$8"

    # 16 bytes of dest_node_id for masking key
    local masking_key="${dest_node_id:0:32}"  

    # 16 random bytes for masking IV
    local masking_iv=$(generate_random_bytes 16 | bin_to_hex)

    # Protocol Version
    local version="0001"

    # PONG message flag
    local flag="00"
    
    # Fixed authdata size for ordinary messages (32 bytes for src-id)
    local authdata_size="0020"
    local authdata=$src_node_id

    # Encode masked header
    local masked_header=$(encrypt_masked_header "$version" "$flag" "$nonce" "$authdata_size" "$authdata" "$masking_key" "$masking_iv")

   # 0x02 for PONG message
    local message_type="02" 

    # Prepare the message content (PONG RLP: [message_type, req_id, enr_seq])
    local rlp_message_content=$(rlp_encode "[\"$req_id\",\"$enr_seq\",\"$ip\",\"$port\"]")

    local message_data=$(encrypt_message_data $message_type $rlp_message_content $masking_iv $masked_header $read_key $nonce)

    # Return message data
    printf '%s' "$message_data"
}

# Function to decode the PONG message (flag = 0x00)
decode_pong_message() {
    local packet="$1"
    local dest_node_id="$2"
    local read_key="$3"

    # Decode the header
    local header=$(decrypt_masked_header "$packet" "$dest_node_id")

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
    read -r message_type message_content <<< $(decrypt_message_data "$packet" "$read_key" "$nonce" "$authdata_size")

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
    printf '%s %s %s %s %s %s %s %s %s %s' "$protocol_id" "$version" "$flag" "$nonce" "$authdata_size" "$src_node_id" "$req_id" "$enr_seq" "$ip" "$port"
}

# Function to encode the FINDNODE message (flag = 0x00)
encode_findnode_message() {
    local src_node_id="$1"
    local dest_node_id="$2"
    local nonce="$3"
    local read_key="$4"
    local req_id="$5"
    local distance="$6"

    # 16 bytes of dest_node_id for masking key
    local masking_key="${dest_node_id:0:32}"  

    # 16 random bytes for masking IV
    local masking_iv=$(generate_random_bytes 16 | bin_to_hex)

    # Protocol Version
    local version="0001"

    # FINDNODE message flag
    local flag="00"
    
    # Fixed authdata size for ordinary messages (32 bytes for src-id)
    local authdata_size="0020"
    local authdata=$src_node_id  # SRC Node ID is 32 bytes (64 hex characters)

    # Encode masked header
    local masked_header=$(encrypt_masked_header "$version" "$flag" "$nonce" "$authdata_size" "$authdata" "$masking_key" "$masking_iv")

    # 0x03 for FINDNODE message
    local message_type="03"

    # Prepare the message content (FINDNODE RLP: [req_id, distance])
    local rlp_message_content=$(rlp_encode "[\"$req_id\",$distance]")

    local message_data=$(encrypt_message_data "$message_type" "$rlp_message_content" "$masking_iv" "$masked_header" "$read_key" "$nonce")

    # Return the complete FINDNODE message
    printf '%s' "$message_data"
}

# Function to decode the FINDNODE message (flag = 0x00)
decode_findnode_message() {
    local packet="$1"
    local dest_node_id="$2"
    local read_key="$3"

    # Decode the header
    local header=$(decrypt_masked_header "$packet" "$dest_node_id")

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

    # Convert authdata_size from hex to decimal
    local authdata_size_dec=$((16#$authdata_size))

    # Decrypt the message content
    read -r message_type message_content <<< $(decrypt_message_data "$packet" "$read_key" "$nonce" "$authdata_size")

    # Verify message type (should be 03 for FINDNODE)
    if [ "$message_type" != "03" ]; then
        printf "Invalid message type: expected 03, got %s\n" "$message_type" >&2
        return 1
    fi

    # Parse RLP-encoded content
    local decoded_rlp_message_content=$(rlp_decode "$message_content")
    IFS=',' read -ra array <<< "${decoded_rlp_message_content//[\[\]\"]/}"
    local req_id=${array[0]}
    local distance=${array[1]}

    # Output decoded components
    printf '%s %s %s %s %s %s %s %s' "$protocol_id" "$version" "$flag" "$nonce" "$authdata_size" "$src_node_id" "$req_id" "$distance"
}

# Function to encode the NODES message (flag = 0x00)
encode_nodes_message() {
    local src_node_id="$1"
    local dest_node_id="$2"
    local nonce="$3"
    local read_key="$4"
    local req_id="$5"
    local total="$6"
    shift 6
    local enrs=("$@")  # Remaining arguments are ENRs

    # 16 bytes of dest_node_id for masking key
    local masking_key="${dest_node_id:0:32}"  

    # 16 random bytes for masking IV
    local masking_iv=$(generate_random_bytes 16 | bin_to_hex)

    # Protocol Version
    local version="0001"

    # NODES message flag
    local flag="00"
    
    # Fixed authdata size for ordinary messages (32 bytes for src-id)
    local authdata_size="0020"
    local authdata=$src_node_id  # SRC Node ID is 32 bytes (64 hex characters)

    # Encode masked header
    local masked_header=$(encrypt_masked_header "$version" "$flag" "$nonce" "$authdata_size" "$authdata" "$masking_key" "$masking_iv")

    # 0x04 for NODES message
    local message_type="04"

    # Prepare the message content (NODES RLP: [req_id, total, [enrs]])
    # Build the list of ENRs in RLP format
    local enr_list_rlp="["

    for enr in "${enrs[@]}"; do
        enr_list_rlp+="\"$enr\","
    done

    # Remove trailing comma if necessary
    enr_list_rlp="${enr_list_rlp%,}]"

    # Full RLP message content
    local rlp_message_content=$(rlp_encode "[\"$req_id\",$total,$enr_list_rlp]")

    local message_data=$(encrypt_message_data "$message_type" "$rlp_message_content" "$masking_iv" "$masked_header" "$read_key" "$nonce")

    # Return the complete NODES message
    printf '%s' "$message_data"
}

# Function to decode the NODES message (flag = 0x00)
decode_nodes_message() {
    local packet="$1"
    local dest_node_id="$2"
    local read_key="$3"

    # Decode the header
    local header=$(decrypt_masked_header "$packet" "$dest_node_id")

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

    # Convert authdata_size from hex to decimal
    local authdata_size_dec=$((16#$authdata_size))

    # Decrypt the message content
    read -r message_type message_content <<< $(decrypt_message_data "$packet" "$read_key" "$nonce" "$authdata_size")

    # Verify message type (should be 04 for NODES)
    if [ "$message_type" != "04" ]; then
        printf "Invalid message type: expected 04, got %s\n" "$message_type" >&2
        return 1
    fi

    # Parse RLP-encoded content
    local decoded_rlp_message_content=$(rlp_decode "$message_content")

    # Extract req_id, total, and enrs
    # Remove leading and trailing brackets and quotes
    local content="${decoded_rlp_message_content#\[}"
    content="${content%\]}"
    IFS=',' read -ra array <<< "$content"

    local req_id=${array[0]//\"/}
    local total=${array[1]}
    local enrs_raw="${array[@]:2}"

    # Process the ENRs
    # Reconstruct the ENR list
    local enrs=()
    for (( i=2; i<${#array[@]}; i++ )); do
        local enr=${array[$i]}
        # Remove surrounding quotes if present
        enr=${enr//\"/}
        # Remove leading and trailing brackets
        enr=${enr#\[}
        enr=${enr%\]}
        enrs+=("$enr")
    done

    # Output decoded components
    printf '%s %s %s %s %s %s %s %s\n' "$protocol_id" "$version" "$flag" "$nonce" "$authdata_size" "$src_node_id" "$req_id" "$total"
    # Print the ENRs
    for enr in "${enrs[@]}"; do
        printf '%s\n' "$enr"
    done
}

# Function to encode the WHOAREYOU message (flag = 0x01)
encode_whoareyou_message() {
    local nonce="$1"
    local id_nonce="$2"
    local enr_seq="$3"

    # Check if any conversion failed
    if [[ -z "$nonce" || -z "$id_nonce" || -z "$enr_seq" ]]; then
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

    # 16 bytes of zeros for masking key
    local masking_key="00000000000000000000000000000000"  

    # 16 random bytes for masking IV
    local masking_iv=$(generate_random_bytes 16 | bin_to_hex)

    # Encode masked header
    local masked_header=$(encrypt_masked_header "$version" "$flag" "$nonce" "$authdata_size" "$authdata" "$masking_key" "$masking_iv")

    # Combine masking IV and masked header
    printf '%s%s' "$masking_iv" "$masked_header"
}

# Decode WHOAREYOU message (flag = 0x01)
decode_whoareyou_message() {
    local packet=$1

    # Set masking_key to zeros (since sender doesn't know dest-node-id)
    local dest_node_id="00000000000000000000000000000000"  # 16 bytes of zeros

    # Decode the header
    local header=$(decrypt_masked_header "$packet" "$dest_node_id")

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
        printf "Invalid protocol ID\n" >&2
        return 1
    fi

    # Output decoded components
    printf '%s %s %s %s %s %s %s %s %s %s' "$protocol_id" "$version" "$flag" "$nonce" "$authdata_size" "$id_nonce" "$enr_seq"
}

# Function to encode the Handshake message (flag = 0x02)
encode_handshake_message() {
    local src_node_id="$1"
    local dest_node_id="$2"
    local nonce="$3"
    local read_key="$4"
    local challenge_data="$5"
    local ephemeral_public_key="$6"
    local ephemeral_private_key="$7"
    local static_private_key="$8"
    local record="$9"

    # Validate inputs with detailed error messages
    [ ${#src_node_id} -ne 64 ] && { printf "Error: src_node_id should be 64 characters, got %d\n" "${#src_node_id}" >&2; return 1; }
    [ ${#dest_node_id} -ne 64 ] && { printf "Error: dest_node_id should be 64 characters, got %d\n" "${#dest_node_id}" >&2; return 1; }
    [ ${#nonce} -ne 24 ] && { printf "Error: nonce should be 24 characters, got %d\n" "${#nonce}" >&2; return 1; }
    [ ${#read_key} -ne 32 ] && { printf "Error: read_key should be 32 characters, got %d\n" "${#read_key}" >&2; return 1; }
    [ ${#ephemeral_public_key} -ne 66 ] && { printf "Error: ephemeral_public_key should be 66 characters, got %d\n" "${#ephemeral_public_key}" >&2; return 1; }
    [ ${#ephemeral_private_key} -ne 64 ] && { printf "Error: ephemeral_private_key should be 64 characters, got %d\n" "${#ephemeral_private_key}" >&2; return 1; }
    [ ${#static_private_key} -ne 64 ] && { printf "Error: static_private_key should be 64 characters, got %d\n" "${#static_private_key}" >&2; return 1; }

    # Create id-signature
    local id_signature_text="discovery v5 identity proof"
    local id_signature_input="${id_signature_text}${challenge_data}${ephemeral_public_key}${dest_node_id}"
    local id_signature_hash=$(printf "%s" "$id_signature_input" | sha256 | bin_to_hex)
    local id_signature=$(id_sign "$id_signature_hash" "$static_private_key")
    local id_sign_result=$?
    if [ $id_sign_result -ne 0 ] || [ ${#id_signature} -ne 128 ]; then
        printf "Error: Failed to create id-signature, length: %d\n" "${#id_signature}" >&2
        return 1
    fi

    # Protocol Version and flag
    local version="0001"
    local flag="02"

    # Calculate sizes
    local sig_size=$(( (${#id_signature} + 1) / 2 ))  # Ensure proper rounding
    local eph_key_size=$(( (${#ephemeral_public_key} + 1) / 2 ))
    local record_length=$(( (${#record} + 1) / 2 ))
    
    # Calculate authdata size
    local authdata_size=$((34 + sig_size + eph_key_size + record_length))
    local authdata_size_hex=$(printf '%04x' $authdata_size)

    # Prepare authdata
    local authdata_head="${src_node_id}$(printf '%02x' $sig_size)$(printf '%02x' $eph_key_size)"
    local authdata="${authdata_head}${id_signature}${ephemeral_public_key}${record}"

    # 16 bytes of dest_node_id for masking key
    local masking_key="${dest_node_id:0:32}"

    # 16 random bytes for masking IV
    local masking_iv=$(generate_random_bytes 16 | bin_to_hex)

    # Encode masked header
    local masked_header=$(encrypt_masked_header "$version" "$flag" "$nonce" "$authdata_size_hex" "$authdata" "$masking_key" "$masking_iv")

    # Handshake messages don't have a separate message type, so we use dummy data
    local message_type="00"
    local rlp_message_content=$(rlp_encode "[]")

    # Encrypt message data
    local encrypt_message_data=$(encrypt_message_data $message_type $rlp_message_content $masking_iv $masked_header $read_key $nonce)

    # Return complete handshake message
    printf "%s" "$encrypt_message_data"
}

# Function to decode the Handshake message (flag = 0x02)
decode_handshake_message() {
    local packet="$1"
    local dest_node_id="$2"
    local read_key="$3"

    # Decode the header
    local header=$(decrypt_masked_header "$packet" "$dest_node_id")

    # Extract header components
    local protocol_id=${header:0:12}
    local version=${header:12:4}
    local flag=${header:16:2}
    local nonce=${header:18:24}
    local authdata_size=${header:42:4}

    # Verify protocol ID
    if [ "$protocol_id" != "646973637635" ]; then  # "discv5" in hex
        printf "Invalid protocol ID\n" >&2
        return 1
    fi

    # Total length of authdata in hex characters
    local authdata_length=$(( 16#$authdata_size * 2 ))

    # Extract authdata
    local authdata=${header:46:$authdata_length}

    # Parse authdata
    local src_node_id=${authdata:0:64}
    local sig_size_hex=${authdata:64:2}
    local sig_size=$((16#$sig_size_hex))
    local eph_key_size_hex=${authdata:66:2}
    local eph_key_size=$((16#$eph_key_size_hex))

    # Start positions and lengths
    local id_signature_start=68
    local id_signature_length=$((sig_size * 2))
    local eph_pubkey_start=$((id_signature_start + id_signature_length))
    local eph_pubkey_length=$((eph_key_size * 2))
    local record_start=$((eph_pubkey_start + eph_pubkey_length))
    local record_length=$((authdata_length - record_start))

    # Extract components
    local id_signature=${authdata:$id_signature_start:$id_signature_length}
    local ephemeral_public_key=${authdata:$eph_pubkey_start:$eph_pubkey_length}
    local record=${authdata:$record_start:$record_length}

    # Decrypt the message content (which should be empty for handshake)
    read -r message_type message_content <<< $(decrypt_message_data "$packet" "$read_key" "$nonce" "$authdata_size")

    # Return the extracted values
    printf '%s %s %s %s %s %s %s %s %s %s %s' \
        "$protocol_id" "$version" "$flag" "$nonce" "$authdata_size" \
        "$src_node_id" "$sig_size" "$eph_key_size" "$id_signature" \
        "$ephemeral_public_key" "$record"
}


id_sign() {
    local message="$1"
    local private_key="$2"

    # Ensure inputs are the correct length
    if [ ${#message} -ne 64 ] || [ ${#private_key} -ne 64 ]; then
        printf "Error: Invalid input lengths for id_sign (message: %d, private_key: %d)\n" "${#message}" "${#private_key}" >&2
        return 1
    fi

    # Use the Python script to generate the signature
    local signature=$(ecdsa_sign "$message" "$private_key")
    if [ $? -ne 0 ] || [ -z "$signature" ]; then
        printf "Error: Failed to generate signature\n" >&2
        return 1
    fi

    # Ensure the signature is the correct length (64 bytes in hex)
    if [ ${#signature} -ne 128 ]; then
        printf "Error: Signature has incorrect length: expected 128, got %d\n" "${#signature}" >&2
        return 1
    fi

    # Return the signature
    printf "%s" "$signature"
}

# Function to retrieve the message type from a packet
get_message_type() {
    local packet="$1"
    local local_node_id="$2"
    
    # Extract potential header (next 55 bytes / 110 hex characters)
    local potential_header=$(decrypt_masked_header "$packet" "00000000000000000000000000000000")

    # Check if this is a WHOAREYOU message (unmasked header)
    if [[ ${potential_header:0:12} == "646973637635" ]]; then # "discv5" in hex
        local version=${potential_header:12:4}
        local flag=${potential_header:16:2}
        local nonce=${potential_header:18:24}
        local authdata_size=${potential_header:42:4}

        # Additional checks for WHOAREYOU message
        if [[ "$flag" == "01" && "$authdata_size" == "0018" ]]; then
            # WHOAREYOU message
            printf "WHOAREYOU"
        fi
    else

        # Decode the header and extract the nonce
        local header=$(decrypt_masked_header "$packet" "$local_node_id")
        local flag="${header:16:2}"
        local nonce="${header:18:24}"

        if [ "$flag" == "02" ]; then
            # HANDSHAKE packet
            printf "HANDSHAKE"
        else
            local read_key=${packet:0:32}

            # Decrypt the message type and message content
            read -r message_type message_content <<< $(decrypt_message_data "$packet" "$read_key" "$nonce")

            # Extract message type and content
            local message_type_int=$((16#$message_type))

            case "$message_type" in
                "01") printf "PING" ;;
                "02") printf "PONG" ;;
                "03") printf "FINDNODE" ;;
                "04") printf "NODES" ;;
                "05") printf "TALKREQ" ;;
                "06") printf "TALKRESP" ;;
                "07") printf "REGTOPIC" ;;
                "08") printf "TICKET" ;;
                "09") printf "REGCONFIRMATION" ;;
                "0a") printf "TOPICQUERY" ;;
                *) printf "RANDOM" ;;
            esac
        fi
    fi
}


