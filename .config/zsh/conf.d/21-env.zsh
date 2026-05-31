# ================================
#  Environment Variables
# ================================

export LANG='en_US.UTF-8'
export LC_CTYPE="$LANG"
export LC_TERMINAL="${${LANG:e}:-UTF-8}"

export PAGER='less'

# less options:
#   -i  ignore case in searches that lack uppercase letters
#   -jn jump-target: show the match n lines from the top
#   -R  pass ANSI color escape sequences through raw
#   -W  highlight the first unread line after a forward move
#   -X  do not send init/de-init strings to the terminal
#   -F  quit immediately if output fits on one screen
export LESS='--ignore-case --jump-target=4 --RAW-CONTROL-CHARS --HILITE-UNREAD --no-init --quit-if-one-screen'
export LESSCHARSET='utf-8'

# Prefer nvim > vim > vi as the default editor.
if (( $+commands[nvim] )); then
  export EDITOR='nvim'
  export VISUAL='nvim'
  export MANPAGER='nvim +Man!'
elif (( $+commands[vim] )); then
  export EDITOR='vim'
  export VISUAL='vim'
  export MANPAGER='less -X'
elif (( $+commands[vi] )); then
  export EDITOR='vi'
  export VISUAL='vi'
  export MANPAGER='less -X'
fi

# Date and time format used by ls/eza and similar tools.
# Format: YYYY-MM-DD Weekday hh:mm:ss
export TIME_STYLE='+%F %a %T'
# Longer variant: YYYY-MM-DD Weekday hh:mm:ss TZ
# export TIME_STYLE='+%F %a %T %Z'

# Open URLs in the default Windows browser from WSL.
(( $+commands[wslview] )) && export BROWSER='wslview'
