# ================================
#  fzf — Interactive Filtering
#  https://github.com/junegunn/fzf
#
#  Provides C-r (history search) and C-s (recent-directory search)
#  as lightweight alternatives to atuin and zoxide.
# ================================

# User-Defined Widgets
# https://zsh.sourceforge.io/Doc/Release/Zsh-Line-Editor.html#User_002dDefined-Widgets-1
# - BUFFER (scalar) ... The entire contents of the edit buffer.
# - CURSOR (integer) ... The offset of the cursor, within the edit buffer.
# - LBUFFER (scalar) ... The part of the buffer that lies to the left of the cursor position.

# history - The zsh/parameter Module
# https://zsh.sourceforge.io/Doc/Release/Zsh-Modules.html#index-history-2

# Standard Widgets > Miscellaneous
# https://zsh.sourceforge.io/Doc/Release/Zsh-Line-Editor.html#Miscellaneous-1
# - clear-screen (^L ESC-^L) ... Clear the screen, remaining in incremental search mode.
# - redisplay (unbound) ... Redisplays the edit buffer.
# - reset-prompt (unbound) ... Force the prompts on both the left and right of the screen to be re-expanded, then redisplay the edit buffer.

# ================================
#  cdr — Recent Directory Tracking
#  http://zsh.sourceforge.net/Doc/Release/User-Contributions.html#index-cdr
# ================================

autoload -Uz chpwd_recent_dirs cdr add-zsh-hook
add-zsh-hook chpwd chpwd_recent_dirs

zstyle ':completion:*:*:cdr:*:*' menu selection
zstyle ':completion:*'           recent-dirs-insert both
zstyle ':chpwd:*'                recent-dirs-default true
zstyle ':chpwd:*'                recent-dirs-pushd true
zstyle ':chpwd:*'                recent-dirs-max 500
zstyle ':chpwd:*'                recent-dirs-file "${XDG_CACHE_HOME:-$HOME/.cache}/shell/chpwd-recent-dirs"

[[ -d "${XDG_CACHE_HOME:-$HOME/.cache}/shell" ]] || mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/shell"

# ================================
#  fzf default options
# ================================

FZF_DEFAULT_OPTS="--height 50% --min-height 10 --border --margin 1 --padding 1 \
--prompt '❯ ' --pointer '▐' \
--color 'hl:underline,hl+:underline:reverse,pointer:76,prompt:76' \
--info hidden --reverse --no-sort --exact --no-mouse"

# ================================
#  Helper: disable bracketed paste while fzf is running
# ================================

# Safe multi-line pasting into terminal emulators
# https://zsh.sourceforge.io/Doc/Release/Parameters.html#Parameters-Used-By-The-Shell-1
function _fzf_sanitize_bracketed_paste {
  if (( $+zle_bracketed_paste )); then
    print $zle_bracketed_paste[2]   # ESC[?2004l — disable bracketed paste
  fi
}

# ================================
#  C-r: history search with fzf
# ================================

function fzf_history_selection {
  (( $+commands[highlight] )) || return
  _fzf_sanitize_bracketed_paste
  local _history_num
  _history_num="$(
    export FZF_DEFAULT_OPTS; LANG=C
    fc -lr 1 \
      | awk '{ k=$0; sub(/^[ \t]*[0-9]+[ \t]+/, "", k); if (!seen[k]++) print }' \
      | highlight --syntax shellscript --out-format ansi \
      | fzf --ansi --border-label '╢ history ╟' --with-nth 3.. \
      | sed -r 's/^\s*([0-9]+).+$/\1/'
  )"
  if [[ -n "$_history_num" ]]; then
    BUFFER="$(echo -nE "${history[$_history_num]}")"
    CURSOR="${#BUFFER}"
  fi
  zle -Rc
  zle reset-prompt
}

# ================================
#  C-s: recent-directory search with fzf
# ================================

function fzf_cdr_selection {
  _fzf_sanitize_bracketed_paste
  local _selected_dir
  _selected_dir="$(
    export FZF_DEFAULT_OPTS; LANG=C
    cdr -l | perl -pe 's/^\d+\s*//' | fzf --border-label '╢ cdr ╟'
  )"
  if [[ -n "$_selected_dir" ]]; then
    BUFFER="cd $_selected_dir"
    CURSOR="${#BUFFER}"
  fi
  zle -Rc
  zle reset-prompt
}

# ================================
#  Keybinds
# ================================

# Register widgets and bind keys only when fzf is available.
if (( $+commands[fzf] )); then
  zle -N fzf_history_selection
  bindkey '^R' fzf_history_selection

  zle -N fzf_cdr_selection
  bindkey '^S' fzf_cdr_selection
fi
