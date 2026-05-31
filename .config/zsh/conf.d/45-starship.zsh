# ================================
#  Starship
#  https://starship.rs/
# ================================

(( ${+commands[starship]} )) || return

eval "$(starship init zsh)"
