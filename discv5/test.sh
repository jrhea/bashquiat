handle_udp_message() {
    # Read the message from stdin
    read -r message
    # Output the data separated by a delimiter (e.g., '|')
    echo "$SOCAT_PEERADDR|$SOCAT_PEERPORT|$message"
}

receive_udp() {
    local port="$1"
    while $keep_running; do
        # Start socat and read its output
        socat -u UDP4-RECVFROM:$port,fork EXEC:'/bin/bash -c "handle_udp_message"' 2>/dev/null | \
        while IFS='|' read -r source_ip source_port message; do
            # Process the message as needed
            printf "Received message from %s:%s: %s\n" "$source_ip" "$source_port" "$message"
            #process_message "$message" "$source_ip" "$source_port"
        done
    done
}

export -f handle_udp_message
receive_udp "12345"