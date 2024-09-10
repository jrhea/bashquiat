#!/bin/bash

session_name="bashquiat"
window_name="bashquiat"
pane_1_cmd="./discv5/discv5.sh 12345 "127.0.0.1" 54321"
pane_2_cmd="./discv5/discv5.sh 54321 "127.0.0.1" 12345"

# Create a new tmux session
tmux new-session -d -s "$session_name" -n "$window_name"

# Split the window horizontally
tmux split-window -h

# Send commands to each pane
tmux send-keys -t "$session_name:$window_name.0" "$pane_1_cmd" C-m
tmux send-keys -t "$session_name:$window_name.1" "$pane_2_cmd" C-m

# Attach to the tmux session
tmux attach-session -t "$session_name"
