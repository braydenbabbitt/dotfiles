#!/bin/bash

frontend_repo_dir=""
session_name="frontend"

# Start session
tmux new-session -d -s $session_name -n "nvim"
tmux send-keys "cd $frontend_repo_dir && nvim ." C-m

# Create remaining windows
tmux new-window -t $session_name:1 -n "term"
tmux send-keys "cd $frontend_repo_dir" C-m

tmux new-window -t $session_name:2 -n "server"
tmux send-keys "cd $frontend_repo_dir && (pnpm i || pnpm i) && pnpm exec nx run weave:start" C-m

# Select first window and attach
tmux select-window it "${session_name}:0"
tmux attach-session -t $session_name
