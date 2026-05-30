# ================================
#  Aliases
# ================================

# eza: a modern ls replacement with icons and git status
# https://github.com/eza-community/eza
if (( $+commands[eza] )); then
  alias ll='eza -l --icons --group-directories-first --git'
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
