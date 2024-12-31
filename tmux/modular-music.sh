#!/bin/bash

frontend_dir=""
backend_dir=""
frontend_session_name="modular-music-fe"
backend_session_name="modular-music-be"
group_name="modular-music"

tmux new-session -d -s $frontend_session_name -A -t $group_name -c $frontend_dir
tmux new-window -n fe-nvim
tmux send-keys "nvim ." C-m
tmux new-window -n fe-term
tmux send-keys "npm i && npm run dev" C-m

tmux new-session -d -s $backend_session_name -A -t $group_name -c $backend_dir
tmux new-window -n be-nvim
tmux send-keys "nvim ." C-m
tmux new-window -n be-term -d
tmux select-window -t fe-nvim
