# ================================
#  zsh-syntax-highlighting
#  https://github.com/zsh-users/zsh-syntax-highlighting
#
#  Colors command-line input in real time: valid commands, arguments,
#  strings, redirections, etc.
#
#  Must be sourced after all zle -N calls and after compinit.
#  Must be sourced before zsh-history-substring-search (44).
# ================================

_zsh_plugin_source zsh-syntax-highlighting \
  'https://github.com/zsh-users/zsh-syntax-highlighting.git' \
  'zsh-syntax-highlighting.zsh' || return

# Plugins
# - main - the base highlighter, and the only one active by default.
# - brackets - matches brackets and parenthesis.
# - pattern - matches user-defined patterns.
# - regexp - matches user-defined regular expressions.
# - cursor - matches the cursor position.
# - root - highlights the whole command line if the current user is root.
# - line - applied to the whole command line.
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor)

# ==========================================
#  pattern
#  https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters/pattern.md
# ==========================================

typeset -A ZSH_HIGHLIGHT_PATTERNS
ZSH_HIGHLIGHT_PATTERNS+=('rm -rf*' 'fg=white,bold,bg=red')
ZSH_HIGHLIGHT_PATTERNS+=('rm*-rf*' 'fg=white,bold,bg=red')
