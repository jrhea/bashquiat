#!/bin/bash

session_name="bashquiat"
window_name="bashquiat"
pane_1_cmd="./discv5/discv5.sh bbbb9d047f0488c0b5a93c1c3f2d8bafc7c8ff337024a55434a0d0555de64db9 12345"
pane_2_cmd="./discv5/discv5.sh aaaa8419e9f49d0083561b48287df592939a8d19947d8c0ef88f2a4856a69fbb 12346 bbbb9d047f0488c0b5a93c1c3f2d8bafc7c8ff337024a55434a0d0555de64db9 127.0.0.1 12345"

# Create a new tmux session
tmux new-session -d -s "$session_name" -n "$window_name"

# Split the window horizontally
tmux split-window -h

# Send commands to each pane
tmux send-keys -t "$session_name:$window_name.0" "$pane_1_cmd" Enter
tmux send-keys -t "$session_name:$window_name.1" "$pane_2_cmd" Enter

# Attach to the tmux session
tmux attach-session -t "$session_name"