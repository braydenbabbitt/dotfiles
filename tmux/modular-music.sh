#!/bin/bash

frontend_dir=""
backend_dir=""
session_name="modular-music"

# Start session
tmux new-session -d -s $session_name -n "fe-nvim" -c $frontend_dir
tmux send-keys "nvim ." C-m

# Create remaining windows
tmux new-window -t $session_name:1 -n "fe-term"
tmux send-keys "cd $frontend_dir && npm i && npm run dev" C-m

tmux new-window -t $session_name:2 -n "be-nvim" -c $backend_dir
tmux send-keys "nvim ." C-m

tmux new-window -t $session_name:3 -n "be-term"
tmux send-keys "cd $backend_dir" C-m

# Select first window and attach
tmux select-window -t "${session_name}:0"
tmux attach-session -t $session_name
