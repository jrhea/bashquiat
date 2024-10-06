#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/discv5_codec.sh
source $DIR/../discv5/udp_duplex.sh

# Set up the trap for Ctrl+C (SIGINT)
printf "Script is running. Press Ctrl+C to stop.\n"
trap cleanup SIGINT

# Usage and argument parsing
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <src_node_id> <listen_port> [dest_node_id] [dest_ip] [dest_port]"
    exit 1
fi

export SRC_NODE_ID=$1
export LISTEN_PORT=$2
printf "\nListening on port %d\n" "$LISTEN_PORT"

# Optional arguments
# If destination node info is provided, we are in ACTIVE mode
# otherwise, we are in PASSIVE mode
if [ "$#" -eq 5 ]; then
    export MODE="ACTIVE"
    export DEST_NODE_ID=$3
    export DEST_IP=$4
    export DEST_PORT=$5
else
    export MODE="PASSIVE"
    # Calculate DEST_PORT
    # NOTE: This is only for testing purposes
    export DEST_PORT=$(( LISTEN_PORT + 1 ))
fi

# Start the receiver
receive_udp $LISTEN_PORT &
RECEIVER_PID=$!

# Start the incoming message processor
process_incoming_messages &
INCOMING_PROCESSOR_PID=$!

# Start the outgoing message processor
process_outgoing_messages &
OUTGOING_PROCESSOR_PID=$!

if [ "$MODE" == "ACTIVE" ]; then
    printf "Mode: ACTIVE\n\n"
    # Send a random message to the destination node
    nonce=$(generate_random_bytes 12 | bin_to_hex)
    read_key=$(generate_random_bytes 16 | bin_to_hex)
    req_id=$(generate_random_bytes 2 | bin_to_hex)
    enr_seq=$(generate_random_bytes 8 | bin_to_hex)
    random_message=$(generate_random_message)
    add_to_queue "$OUTGOING_QUEUE" "$random_message" "$DEST_IP"
    printf "Sending RANDOM message\n" >&2
elif [ "$MODE" == "PASSIVE" ]; then
    # Listen for incoming messages
    printf "Mode: PASSIVE\n\n"
fi

# Main loop
while $keep_running; do
    # Do nothing
    sleep 1
done

# The script will exit here when Ctrl+C is pressed and cleanup is done