# ================================
#  Zsh Key Bindings
#  https://zsh.sourceforge.io/Doc/Release/Zsh-Line-Editor.html#index-bindkey
#  https://zsh.sourceforge.io/Doc/Release/Editor-Functions-Index.html
# ================================

# Skip on dumb terminals.
[[ "$TERM" == 'dumb' ]] && return

# Use Emacs key bindings.
bindkey -e

# Build a human-readable key identifier map from terminfo.
zmodload -F zsh/terminfo +b:echoti +p:terminfo
typeset -gA key_info
key_info=(
  Control         '\C-'
  ControlLeft     '\e[1;5D \e[5D \e\e[D \eOd \eOD'
  ControlRight    '\e[1;5C \e[5C \e\e[C \eOc \eOC'
  ControlPageUp   '\e[5;5~'
  ControlPageDown '\e[6;5~'
  Escape          '\e'
  Meta            '\M-'
  Backspace       '^?'
  Delete          '^[[3~'
  BackTab         "${terminfo[kcbt]}"
  Left            "${terminfo[kcub1]}"
  Down            "${terminfo[kcud1]}"
  Right           "${terminfo[kcuf1]}"
  Up              "${terminfo[kcuu1]}"
  End             "${terminfo[kend]}"
  F1              "${terminfo[kf1]}"
  F2              "${terminfo[kf2]}"
  F3              "${terminfo[kf3]}"
  F4              "${terminfo[kf4]}"
  F5              "${terminfo[kf5]}"
  F6              "${terminfo[kf6]}"
  F7              "${terminfo[kf7]}"
  F8              "${terminfo[kf8]}"
  F9              "${terminfo[kf9]}"
  F10             "${terminfo[kf10]}"
  F11             "${terminfo[kf11]}"
  F12             "${terminfo[kf12]}"
  Home            "${terminfo[khome]}"
  Insert          "${terminfo[kich1]}"
  PageDown        "${terminfo[knp]}"
  PageUp          "${terminfo[kpp]}"
)

# Basic navigation keys
bindkey ${key_info[Delete]}    delete-char
bindkey ${key_info[Backspace]} backward-delete-char

if [[ -n ${key_info[Home]} ]]     bindkey ${key_info[Home]}     beginning-of-line
if [[ -n ${key_info[End]} ]]      bindkey ${key_info[End]}      end-of-line
if [[ -n ${key_info[PageUp]} ]]   bindkey ${key_info[PageUp]}   up-line-or-history
if [[ -n ${key_info[PageDown]} ]] bindkey ${key_info[PageDown]} down-line-or-history
if [[ -n ${key_info[Insert]} ]]   bindkey ${key_info[Insert]}   overwrite-mode
if [[ -n ${key_info[Left]} ]]     bindkey ${key_info[Left]}     backward-char
if [[ -n ${key_info[Right]} ]]    bindkey ${key_info[Right]}    forward-char

# S-Tab: cycle completions in reverse order.
if [[ -n ${key_info[BackTab]} ]] bindkey ${key_info[BackTab]} reverse-menu-complete

# Space: expand history substitutions (!! !$ etc.) immediately.
bindkey ' ' magic-space

#
# Emacs key bindings
#

# Free ^K to use as a prefix key.
bindkey -M emacs -r '^K'

# Remove redundant default bindings.
bindkey -M emacs -r '^Xu'  # undo (duplicate of ^_)
bindkey -M emacs -r '^X^U' # undo (duplicate of ^_)
bindkey -M emacs -r '^[Q'  # push-line (duplicate of ^q)
bindkey -M emacs -r '^[q'  # push-line (duplicate of ^q)
bindkey -M emacs -r '^[^L' # clear-screen (duplicate of ^l)

# A-b / A-B / C-Left / A-Left: move back one word.
# A-f / A-F / C-Right / A-Right: move forward one word.
local key
for key in "^["{B,b} "${(s: :)key_info[ControlLeft]}" "^[${key_info[Left]}"
  bindkey -M emacs "$key" emacs-backward-word
for key in "^["{F,f} "${(s: :)key_info[ControlRight]}" "^[${key_info[Right]}"
  bindkey -M emacs "$key" emacs-forward-word

# A-.: insert the last argument of the previous command (default, explicit).
bindkey -M emacs '^[.' insert-last-word

# C-k s: prepend 'sudo ' to the current command line.
function prepend-sudo {
  if [[ "$BUFFER" != su(do|)\ * ]]; then
    BUFFER="sudo $BUFFER"
    (( CURSOR += 5 ))
  fi
}
zle -N prepend-sudo
bindkey -M emacs '^ks' prepend-sudo

# C-x C-e: open $EDITOR to compose the current command.
autoload -Uz edit-command-line && zle -N edit-command-line && \
  bindkey -M emacs '^x^e' edit-command-line

# C-x C-a: expand aliases in place.
function glob-alias {
  zle _expand_alias
  zle expand-word
  zle magic-space
}
zle -N glob-alias
bindkey -M emacs '^x^a' glob-alias

# C-I (Tab): redisplay the prompt after completion on Zsh < 5.3.
autoload -Uz is-at-least && if ! is-at-least 5.3; then
  expand-or-complete-with-redisplay() {
    print -n ...
    zle expand-or-complete
    zle redisplay
  }
  zle -N expand-or-complete-with-redisplay
  bindkey -M emacs '^I' expand-or-complete-with-redisplay
fi

# Automatically escape URLs pasted into the command line.
autoload -Uz bracketed-paste-url-magic && zle -N bracketed-paste bracketed-paste-url-magic
autoload -Uz url-quote-magic && zle -N self-insert url-quote-magic

# Switch the terminal into application mode while ZLE is active so that
# terminfo sequences (smkx/rmkx) report the correct key codes.
if (( ${+terminfo[smkx]} && ${+terminfo[rmkx]} && ! ${+functions[_start_application_mode]} && ! ${+functions[_stop_application_mode]} )); then
  functions[_start_application_mode]=${widgets[zle-line-init]#user:}'
echoti smkx'
  functions[_stop_application_mode]=${widgets[zle-line-finish]#user:}'
echoti rmkx'
  zle -N zle-line-init _start_application_mode
  zle -N zle-line-finish _stop_application_mode
fi

# C-d: delete the word after the cursor (overrides delete-char-or-list).
bindkey -M emacs '^d' kill-word

# A-_: redo (overrides insert-last-word, which is bound to A-. above).
bindkey -M emacs '^[_' redo

# C-U: delete from cursor to start of line (Bash/Readline behavior).
bindkey -M emacs '^U' backward-kill-line

# C-q: push the current line onto the buffer stack to type another command.
bindkey -M emacs '^q' push-line-or-edit

# Vim-style motion widgets accessible from Emacs mode.
bindkey -M emacs '^[v%' vi-match-bracket
bindkey -M emacs '^[vf' vi-find-next-char
bindkey -M emacs '^[vF' vi-find-prev-char
bindkey -M emacs '^[vt' vi-find-next-char-skip
bindkey -M emacs '^[vT' vi-find-prev-char-skip
