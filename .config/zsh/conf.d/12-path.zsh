# ================================
#  PATH and FPATH
#  https://zsh.sourceforge.io/Doc/Release/Parameters.html
# ================================

# typeset flags used below:
#   -g ... global scope
#   -U ... keep only the first occurrence of each duplicated value
#
# Glob qualifiers used in path expressions:
#   (N) ... null glob — skip if the path does not exist
#   (/) ... directories only

# path / PATH
# https://zsh.sourceforge.io/Doc/Release/Parameters.html#index-path
# The lowercase 'path' array and uppercase 'PATH' scalar are tied together.
# -U deduplicates entries automatically.
typeset -gU path
path=(
  ${XDG_BIN_HOME:-$HOME/.local/bin}(N/)
  $path
)

# fpath / FPATH
# https://zsh.sourceforge.io/Doc/Release/Parameters.html#index-fpath
# User site-functions directory: place custom completions here.
readonly _USER_ZSH_COMPLETIONS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions"
[[ -d "$_USER_ZSH_COMPLETIONS_DIR" ]] || mkdir -p "$_USER_ZSH_COMPLETIONS_DIR"
typeset -gU fpath
fpath=(
  $_USER_ZSH_COMPLETIONS_DIR(N/)
  $fpath
)
