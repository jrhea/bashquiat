#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/discv5_codec.sh
source $DIR/../discv5/udp_duplex.sh


# Usage and argument parsing
if [ $# -ne 5 ]; then
    echo "Usage: $0 <listen_port> <host> <send_port> <src_node_id> <dest_node_id>"
    exit 1
fi

export LISTEN_PORT=$1
export SEND_HOST=$2
export SEND_PORT=$3
export SRC_NODE_ID=$4
export DEST_NODE_ID=$5


# Set up the trap for Ctrl+C (SIGINT)
trap cleanup SIGINT

# Start the receiver
receive_udp $LISTEN_PORT &
RECEIVER_PID=$!

# Start the incoming message processor
process_incoming_messages &
INCOMING_PROCESSOR_PID=$!

# Start the outgoing message processor
process_outgoing_messages &
OUTGOING_PROCESSOR_PID=$!

printf "Script is running. Press Ctrl+C to stop.\n"

# Main loop
while $keep_running; do
    # Example usage: enqueue some DiscV5 messages
    nonce=$(generate_random_bytes 12 | bin_to_hex)
    read_key=$(generate_random_bytes 16 | bin_to_hex)
    req_id=$(generate_random_bytes 2 | bin_to_hex)
    enr_seq=$(generate_random_bytes 8 | bin_to_hex)
    ping_message=$(encode_ping_message "$SRC_NODE_ID" "$DEST_NODE_ID" "$nonce" "$read_key" "$req_id" "$enr_seq")
    add_to_queue "$OUTGOING_QUEUE" "$ping_message"
    sleep 1
done

# The script will exit here when Ctrl+C is pressed and cleanup is done