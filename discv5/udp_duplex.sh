#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
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
    printf '%s\n' "$message" >> "$queue_file"
}

# UDP Sender function
send_udp() {
    local host="$1"
    local port="$2"
    local message="$3"
    printf '%s' "$message" | nc -u -w1 "$host" "$port"
}

# UDP Receiver function
receive_udp() {
    local port="$1"
    while $keep_running; do
        message=$(timeout 1 nc -ul "$port")
        if [ -n "$message" ]; then
            #printf "Received: %s\n" "$message"
            add_to_queue "$INCOMING_QUEUE" "$message"
        fi
    done
}

# Function to process incoming messages
process_incoming_messages() {
    while $keep_running; do
        if [ -s "$INCOMING_QUEUE" ]; then
            message=$(head -n 1 "$INCOMING_QUEUE")
            sed -i '1d' "$INCOMING_QUEUE"
            process_message "$message"
        fi
        sleep 0.1
    done
}

# Function to process a single message
process_message() {
    local message="$1"

    local message_type=$(get_message_type "$message" "$SRC_NODE_ID")
    printf "Message Type: %s\n" "$message_type"
    if [ "$message_type" == "PING" ]; then
        local src_node_id=$SRC_NODE_ID
        local dest_node_id=$DEST_NODE_ID
        local nonce=$(generate_random_bytes 12 | bin_to_hex)
        local read_key=$(generate_random_bytes 16 | bin_to_hex)
        local req_id=$(generate_random_bytes 2 | bin_to_hex)
        local enr_seq=$(generate_random_bytes 8 | bin_to_hex)
        local ip="$(( RANDOM % 256 )).$(( RANDOM % 256 )).$(( RANDOM % 256 )).$(( RANDOM % 256 ))"
        local port=$((RANDOM % 65536))
        local pong_message=$(encode_pong_message "$src_node_id" "$dest_node_id" "$nonce" "$read_key" "$req_id" "$enr_seq")
        add_to_queue "$OUTGOING_QUEUE" "$pong_message"
    fi
}

# Function to process outgoing messages
process_outgoing_messages() {
    while $keep_running; do
        if [ -s "$OUTGOING_QUEUE" ]; then
            message=$(head -n 1 "$OUTGOING_QUEUE")
            sed -i '1d' "$OUTGOING_QUEUE"
            send_udp "$SEND_HOST" "$SEND_PORT" "$message"
            #printf "Sent message to %s:%s - %s\n" "$SEND_HOST" "$SEND_PORT" "$message"
        fi
        sleep 0.1
    done
}

# Function to send the next message in the queue
send_next_message() {
    if [ ${#outgoing_message_queue[@]} -eq 0 ]; then
        return 1  # Queue is empty
    fi
    
    local next_message="${outgoing_message_queue[0]}"
    outgoing_message_queue=("${outgoing_message_queue[@]:1}")  # Remove the first element
    
    local host port message
    IFS=':' read -r host port message <<< "$next_message"
    send_udp "$host" "$port" "$message"
    #printf "Sent message to %s:%s - %s\n" "$host" "$port" "$message"
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