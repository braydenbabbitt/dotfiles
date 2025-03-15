#!/bin/bash

frontend_repo_dir=""
session_name="frontend"

# Parse command line arguments
auto_attach=false
while getopts "a" opt; do
  case $opt in
  a)
    auto_attach=true
    ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    exit 1
    ;;
  esac
done

# Check if session already exists
tmux has-session -t $session_name 2>/dev/null

# If session exists, offer option to attach or kill
if [ $? = 0 ]; then
  if [ "$auto_attach" = true ]; then
    echo "Attaching to existing session..."
    tmux attach-session -t $session_name
    exit 0
  else
    while true; do
      read -p "Session '$session_name' exists. Would you like to attach to it (y/a), create a new one (n/k), or cancel (c)?" choice
      case "$choice" in
      y | Y | a | A)
        echo "Attaching to existing session..."
        tmux attach-session -t $session_name
        exit 0
        ;;
      n | N | k | K)
        echo "Killing existing session..."
        tmux kill-session -t $session_name
        ;;
      c | C)
        echo "Operation cancelled."
        exit 0
        ;;
      *)
        echo "Please answer y (attach), n (create new), or c (cancel)."
        ;;
      esac
    done
  fi
fi

# Start session
tmux new-session -d -s $session_name -n "nvim"
tmux send-keys "cd $frontend_repo_dir" C-m
tmux send-keys "nvim ." C-m

# Create remaining windows
# tmux new-window -t $session_name:1 -n "term"
# tmux send-keys "cd $frontend_repo_dir" C-m

tmux new-window -t $session_name:1 -n "server"
tmux send-keys "cd $frontend_repo_dir" C-m
tmux send-keys "(pnpm i || pnpm i) && pnpm exec nx run weave:start" C-m

# Select first window and attach
tmux select-window it "${session_name}:0"
tmux attach-session -t $session_name
