# ================================
#  Mise
#  https://github.com/jdx/mise/blob/main/README.md#quickstart
# ================================

(( ${+commands[mise]} )) || return

export MISE_IGNORED_CONFIG_PATHS="$HOME/.dotfiles/.config/mise/config.toml"
eval "$(mise activate zsh)"
