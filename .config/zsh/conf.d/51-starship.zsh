# ================================
#  Starship
#  https://starship.rs/
# ================================

# Disabling starship is recommended for AI agents in VS Code.
#
# $TERM_PROGRAM is not reliably "vscode" here — shells spawned for the
# Claude Code extension (and some Remote-WSL terminals) can start with it
# unset. $VSCODE_IPC_HOOK_CLI is set by VS Code itself on every shell it
# spawns (integrated terminals and extension hosts alike), so check it too.
if [[ ! (( ${+commands[starship]} )) || -n "$VSCODE_IPC_HOOK_CLI" || "$TERM_PROGRAM" == 'vscode' ]]; then
  uname -snr
  lsb_release -d | cut -f 2
  zsh --version
  PROMPT='%(?.%F{green}✓.%F{red}%?)%f %F{cyan}%~%f %# '
  return
fi

eval "$(starship init zsh)"
