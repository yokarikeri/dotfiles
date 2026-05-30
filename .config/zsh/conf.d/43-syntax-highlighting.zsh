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

# Enable the main highlighter (command syntax) and the brackets highlighter
# (matching parentheses/brackets).
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)
