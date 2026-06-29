# ================================
#  tmux auto-start
# ================================

[[ -o interactive ]] || return
(( $+commands[tmux] )) || return
[[ -z "$TMUX" ]] || return

# Session name is derived from the terminal identity so that different
# terminal emulators (e.g. VS Code and Windows Terminal) get separate sessions.
#
# Priority:
#   1. $TERM_PROGRAM — set by the terminal itself (e.g. "vscode"); checked
#      first because $WT_SESSION can leak into child processes (including VS
#      Code) via Windows environment variable inheritance.
#   2. $WT_SESSION   — set by Windows Terminal; collapsed to the fixed name
#      "wt" since the raw value is a UUID.
#   3. "main"        — fallback for plain SSH sessions and the like.
local session
if [[ -n "$TERM_PROGRAM" ]]; then
  session="$TERM_PROGRAM"
elif [[ -n "$WT_SESSION" ]]; then
  session="wt"
else
  session="main"
fi

exec tmux new-session -A -s "$session"
