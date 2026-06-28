# ================================
#  Zsh Parameters
#  https://zsh.sourceforge.io/Doc/Release/Parameters.html
# ================================

#
# 15.6 Parameters Used By The Shell
# https://zsh.sourceforge.io/Doc/Release/Parameters.html#Parameters-Used-By-The-Shell
#

# Characters treated as part of a word for word-based movements and deletion.
export WORDCHARS='*?_-.[]~&;!#$%^(){}<>'

# History file size: keep HISTSIZE slightly larger than SAVEHIST so that
# HIST_EXPIRE_DUPS_FIRST can do its job before the in-memory list is full.
export HISTSIZE=120000
export SAVEHIST=100000
export HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
[[ -d "${HISTFILE:h}" ]] || mkdir -p "${HISTFILE:h}"
