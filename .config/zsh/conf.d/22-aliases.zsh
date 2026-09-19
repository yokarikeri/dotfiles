# ================================
#  Aliases
# ================================

alias ls='ls --color=auto'
alias grep='grep --color=auto'

# eza: a modern ls replacement with icons and git status
# https://github.com/eza-community/eza
if (( $+commands[eza] )); then
  alias ll='eza -la --icons --group-directories-first --git'
else
  alias ll='ls -lah'
fi

# colordiff: colorized diff output
if (( $+commands[colordiff] )); then
  alias diff='colordiff'
fi

# bat/batcat: on Debian/Ubuntu the binary is named 'batcat'
if (( $+commands[batcat] )) && ! (( $+commands[bat] )); then
  alias bat='batcat'
fi

# fd/fdfind: on Debian/Ubuntu the binary is named 'fdfind'
if (( $+commands[fdfind] )) && ! (( $+commands[fd] )); then
  alias fd='fdfind'
fi

# fzf-preview
if (( $+commands[fzf-preview] )) && ! (( $+commands[fp] )); then
  alias fp='fzf-preview'
fi

# claude-clip
if (( $+commands[claude-clip] )) && ! (( $+commands[fcc] )); then
  alias fcc='claude-clip'
fi

# ================================
#  Zsh built-in history alias
# ================================

# Display history with timestamps and elapsed times, in reverse order.
# fc flags:
#   -l ... list output
#   -n ... suppress line numbers
#   -i ... YYYY-MM-DD timestamps
#   -D ... print elapsed times
#   -r ... reverse order (most recent first)
alias history='history -niD'
