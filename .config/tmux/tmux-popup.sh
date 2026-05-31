#!/bin/sh

# @(#) Start a tmux server for popups

# Intended to be bound to display-popup
# Usage: bind P display-popup -E -d '#{pane_current_path}' -w 100% -h 100% "$HOME/.local/bin/tmux-popup.sh"

# Save the current directory (the working directory specified by the caller's -d option)
pane_path="$PWD"

# Hash the path (sanitize forbidden characters like slashes for the session name & truncate to 8 characters)
# Using the current directory's path for the session name allows retaining the state when the popup is reopened
session_name="popup_$(echo -n "$pane_path" | md5sum | cut -c1-8)"

# Start a popup server separate from the main tmux server
# 'new-session -A' attaches to the session if it exists, or creates a new one if it doesn't
TMUX= exec tmux -L popup -f "$HOME/.config/tmux/tmux-popup.conf" \
  new-session -A -s "$session_name" -c "$pane_path"
