# ================================
#  zsh-autosuggestions
#  https://github.com/zsh-users/zsh-autosuggestions
#
#  Shows a dimmed inline suggestion as you type, based on history.
#  Accept with Right-arrow or End; accept one word with forward-word.
#
#  Must be sourced before zsh-syntax-highlighting (43-syntax-highlighting.zsh).
# ================================

# Disable the per-prompt widget rebind for faster prompt startup.
#
# NOTE:
# Safe as long as no plugin loaded after 44-history-substring-search.zsh rewraps ZLE widgets.
# If such a plugin is added later, either remove this line or call _zsh_autosuggest_bind_widgets manually after that plugin sources.
ZSH_AUTOSUGGEST_MANUAL_REBIND=1

_zsh_plugin_source zsh-autosuggestions \
  'https://github.com/zsh-users/zsh-autosuggestions.git' \
  'zsh-autosuggestions.zsh' || return

# Suggestion highlight color: muted gray (color 8 in the 256-color palette).
# See https://github.com/zsh-users/zsh-autosuggestions/blob/master/README.md#suggestion-highlight-style
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
