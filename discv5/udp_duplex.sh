#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/../cryptography/utils.sh
source $DIR/discv5_codec.sh

# Create temporary files for our queues
INCOMING_QUEUE=$(mktemp /tmp/discv5_incoming.XXXXXX)
OUTGOING_QUEUE=$(mktemp /tmp/discv5_outgoing.XXXXXX)

# Print the queue file names (for debugging purposes)
printf "Incoming queue file: %s\n" "$INCOMING_QUEUE"
printf "Outgoing queue file: %s\n" "$OUTGOING_QUEUE"

# Ensure the queue files exist and are empty
> "$INCOMING_QUEUE"
> "$OUTGOING_QUEUE"

# Global variable to control the main loop
keep_running=true

# Function to add a message to a queue
add_to_queue() {
    local queue_file="$1"
    local message="$2"
    local source_ip="$3"
    printf '%s\n' "$message" >> "$queue_file"
    printf '%s\n' "$source_ip" >> "$queue_file"
}

# UDP Sender function
send_udp() {
    local host="$1"
    local port="$2"
    local message="$3"
    printf '%s' "$message" | nc -u -w1 "$host" "$port"
}

# Function get the source IP and message
handle_udp_message() {
    # Read the message from stdin
    IFS= read -r -d '' message || true
    # Output the source IP and message separated by null characters
    printf '%s\0%s\0' "$SOCAT_PEERADDR" "$message"
}
export -f handle_udp_message


# UDP Receiver function
receive_udp() {
    local port="$1"
    while $keep_running; do
        socat -u UDP4-RECVFROM:$port,fork EXEC:'/bin/bash -c "handle_udp_message"' 2>/dev/null | \
        while IFS= read -r -d '' source_ip && \
              IFS= read -r -d '' message; do
            if [ ${#message} -gt 5 ]; then
                # Add the message to the incoming queue
                add_to_queue "$INCOMING_QUEUE" "$message" "$source_ip"
            fi
        done
    done
}

# Function to process incoming messages
process_incoming_messages() {
    while $keep_running; do
        if [ -s "$INCOMING_QUEUE" ]; then
            local message=$(head -n 1 "$INCOMING_QUEUE")
            sed -i '1d' "$INCOMING_QUEUE"
            local ip=$(head -n 1 "$INCOMING_QUEUE")
            sed -i '1d' "$INCOMING_QUEUE"
            process_message "$message" "$ip"
        fi
        sleep 0.1
    done
}

# Function to process a single message
process_message() {
    local message="$1"
    local ip="$2"
    local message_type=$(get_message_type "$message" "$SRC_NODE_ID")
    printf "Received message type: %s from %s%s\n" "$message_type" "$ip" >&2
    if [ "$message_type" == "RANDOM" ]; then
        # Send a WHOAREYOU message
        local src_node_id=$SRC_NODE_ID
        local nonce=$(generate_random_bytes 12 | bin_to_hex)
        local id_nonce=$(generate_random_bytes 16 | bin_to_hex)
        local enr_seq=$(generate_random_bytes 8 | bin_to_hex)
        local masking_iv=$(generate_random_bytes 16 | bin_to_hex)

        # Encode the WHOAREYOU message
        local whoareyou_message=$(encode_whoareyou_message "$nonce" "$id_nonce" "$enr_seq" "$masking_iv")

        # Add the WHOAREYOU message to the outgoing queue
        add_to_queue "$OUTGOING_QUEUE" "$whoareyou_message" "$ip"
        printf "Sending WHOAREYOU message\n" >&2
    elif [ "$message_type" == "PING" ]; then
        # Send a PONG message
        local src_node_id=$SRC_NODE_ID
        local dest_node_id=$DEST_NODE_ID
        local nonce=$(generate_random_bytes 12 | bin_to_hex)
        local read_key=$(generate_random_bytes 16 | bin_to_hex)
        local req_id=$(generate_random_bytes 2 | bin_to_hex)
        local enr_seq=$(generate_random_bytes 8 | bin_to_hex)

        # Encode the PONG message
        local pong_message=$(encode_pong_message "$src_node_id" "$dest_node_id" "$nonce" "$read_key" "$req_id" "$enr_seq")

        # Add the PONG message to the outgoing queue
        add_to_queue "$OUTGOING_QUEUE" "$pong_message" "$ip"
        printf "Sending PONG message\n" >&2
    elif [ "$message_type" == "WHOAREYOU" ]; then
        # Send a HANDSHAKE message
        local src_node_id=$SRC_NODE_ID
        local dest_node_id=$DEST_NODE_ID
        local nonce=$(generate_random_bytes 12 | bin_to_hex)
        local read_key=$(generate_random_bytes 16 | bin_to_hex)
        local challenge_data=$(generate_random_bytes 32 | bin_to_hex)

        # Generate ephemeral key pair
        read ephemeral_private_key ephemeral_public_key ephemeral_private_key_file <<< $(generate_secp256k1_keypair)

        # Generate static private key
        read static_private_key static_public_key static_private_key_file <<< $(generate_secp256k1_keypair)

        # Include the ENR record
        local record=$(generate_random_bytes 100 | bin_to_hex)

        # Encode the handshake message
        local encoded_message=$(encode_handshake_message "$src_node_id" "$dest_node_id" "$nonce" "$read_key" "$challenge_data" "$ephemeral_public_key" "$ephemeral_private_key" "$static_private_key" "$record")

        # Add the message to the outgoing queue
        add_to_queue "$OUTGOING_QUEUE" "$encoded_message" "$ip"

        printf "Sending HANDSHAKE message\n" >&2
    elif [ "$message_type" == "HANDSHAKE" ]; then
        # TODO: Process the handshake message
        printf "Received HANDSHAKE message\n" >&2
    fi
}

# Function to process outgoing messages
process_outgoing_messages() {
    while $keep_running; do
        if [ -s "$OUTGOING_QUEUE" ]; then
            local message=$(head -n 1 "$OUTGOING_QUEUE")
            sed -i '1d' "$OUTGOING_QUEUE"
            local ip=$(head -n 1 "$OUTGOING_QUEUE")
            sed -i '1d' "$OUTGOING_QUEUE"
            send_udp "$ip" "$DEST_PORT" "$message"
        fi
        sleep 0.1
    done
}

# Function to clean up resources
cleanup() {
    printf "\nCleaning up...\n"
    keep_running=false
    kill "$RECEIVER_PID" "$INCOMING_PROCESSOR_PID" "$OUTGOING_PROCESSOR_PID" 2>/dev/null
    wait "$RECEIVER_PID" "$INCOMING_PROCESSOR_PID" "$OUTGOING_PROCESSOR_PID" 2>/dev/null
    rm -f "$INCOMING_QUEUE" "$OUTGOING_QUEUE"
    printf "Cleanup completed. Exiting.\n"
    exit 0
}