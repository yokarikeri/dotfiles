# ================================
#  Mise
#  https://github.com/jdx/mise/blob/main/README.md#quickstart
# ================================

(( ${+commands[mise]} )) || return

export MISE_CEILING_PATHS="$HOME/.dotfiles"
eval "$(mise activate zsh)"
