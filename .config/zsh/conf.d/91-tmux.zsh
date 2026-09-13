# ================================
#  tmux auto-start
# ================================

[[ -o interactive ]] || return
(( $+commands[tmux] )) || return
[[ -z "$TMUX" ]] || return

# Disabling tmux is recommended for AI agents in VS Code.
#
# $TERM_PROGRAM is not reliably "vscode" here — shells spawned for the
# Claude Code extension (and some Remote-WSL terminals) can start with it
# unset, in which case $WT_SESSION leaking in from the Windows host would
# otherwise cause tmux to auto-start anyway. $VSCODE_IPC_HOOK_CLI is set by
# VS Code itself on every shell it spawns (integrated terminals and
# extension hosts alike) and isn't subject to either problem, so check it
# too.
[[ -n "$VSCODE_IPC_HOOK_CLI" || "$TERM_PROGRAM" == 'vscode' ]] && return

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
