# ================================
#  zsh-history-substring-search
#  https://github.com/zsh-users/zsh-history-substring-search
#
#  Type part of a previous command, then use Up/Down (or C-p/C-n) to
#  cycle through all history entries that contain that substring.
#
#  Must be sourced after zsh-syntax-highlighting (43-syntax-highlighting.zsh).
# ================================

_zsh_plugin_source zsh-history-substring-search \
  'https://github.com/zsh-users/zsh-history-substring-search.git' \
  'zsh-history-substring-search.zsh' || return

# Highlight colors for found and not-found matches.
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='bg=magenta,fg=white,bold'
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='bg=red,fg=white,bold'

# Bind keys using the key_info map built in 20-zsh-keybinds.zsh.
# Up/Down arrows plus Emacs C-p/C-n.
if [[ -n $key_info ]]; then
  bindkey -M emacs "$key_info[Up]"       history-substring-search-up
  bindkey -M emacs "$key_info[Down]"     history-substring-search-down
  bindkey -M emacs "$key_info[Control]P" history-substring-search-up
  bindkey -M emacs "$key_info[Control]N" history-substring-search-down
fi
