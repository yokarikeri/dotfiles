# ================================
#  zsh-autosuggestions
#  https://github.com/zsh-users/zsh-autosuggestions
#
#  Shows a dimmed inline suggestion as you type, based on history.
#  Accept with Right-arrow or End; accept one word with forward-word.
#
#  Must be sourced before zsh-syntax-highlighting (43-syntax-highlighting.zsh).
# ================================

_zsh_plugin_source zsh-autosuggestions \
  'https://github.com/zsh-users/zsh-autosuggestions.git' \
  'zsh-autosuggestions.zsh' || return

# Suggestion highlight color: muted gray (color 8 in the 256-color palette).
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
