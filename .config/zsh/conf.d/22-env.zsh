# ================================
#  Environment Variables
# ================================

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

export PAGER='less'

# less options:
#   -i, --ignore-case           ignore case in searches that lack uppercase letters
#   -jn, --jump-target=n        jump-target: show the match n lines from the top
#   -R, --RAW-CONTROL-CHARS     pass ANSI color escape sequences through raw
#   -W, --HILITE-UNREAD         highlight the first unread line after a forward move
#   -X, --no-init               do not send init/de-init strings to the terminal
#   -F, --quit-if-one-screen    quit immediately if output fits on one screen
export LESS='--ignore-case --jump-target=4 --RAW-CONTROL-CHARS --HILITE-UNREAD'
export LESSCHARSET='utf-8'

# apt >=2.9 (Ubuntu 26.04+) auto-pipes list/search/show/policy through
# $PAGER and honors LESS as-is (no forced -F), unlike older apt which
# printed straight to stdout. Scope -F to apt via APT_PAGER instead of
# adding it to LESS globally, so short apt output doesn't need a
# keypress while other pagers keep entering full-screen mode.
export APT_PAGER='less -FRX'

# Date and time format used by ls/eza and similar tools.
# Format: YYYY-MM-DD Weekday hh:mm:ss
export TIME_STYLE='+%F %a %T'
# Longer variant: YYYY-MM-DD Weekday hh:mm:ss TZ
# export TIME_STYLE='+%F %a %T %Z'

# Open URLs in the default Windows browser from WSL.
(( $+commands[wslview] )) && export BROWSER='wslview'
