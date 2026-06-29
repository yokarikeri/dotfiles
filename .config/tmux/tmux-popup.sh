#!/bin/sh

# @(#) Start a tmux server for popups

# Intended to be invoked via run-shell so that tmux expands #{...} format
# strings before the shell sees them:
#   bind P run-shell "tmux display-popup -E -d '#{pane_current_path}' \
#     -w 100% -h 100% '$HOME/.local/bin/tmux-popup.sh' '#{session_name}'"
#
# Note: passing #{session_name} as a direct argument to display-popup or via
# its -e option does NOT expand format strings; run-shell is required.

# Save the current directory (the working directory specified by the caller's -d option)
pane_path="$PWD"

# Hash the path + parent session name so that the same directory opened from
# different tmux sessions gets separate popups, while reopening from the same
# session reattaches to the existing one.
# $1 receives #{session_name} expanded by run-shell (e.g. "vscode", "wt").
session_name="popup_$(printf '%s\n%s' "$pane_path" "$1" | md5sum | cut -c1-8)"

# Start a popup server separate from the main tmux server
# 'new-session -A' attaches to the session if it exists, or creates a new one if it doesn't
TMUX= exec tmux -L popup -f "$HOME/.config/tmux/tmux-popup.conf" \
  new-session -A -s "$session_name" -c "$pane_path"
