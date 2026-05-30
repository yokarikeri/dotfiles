# ================================
#  fzf — Interactive Filtering
#  https://github.com/junegunn/fzf
#
#  Provides C-r (history search) and C-s (recent-directory search)
#  as lightweight alternatives to atuin and zoxide.
# ================================

# ================================
#  cdr — Recent Directory Tracking
#  http://zsh.sourceforge.net/Doc/Release/User-Contributions.html#index-cdr
# ================================

autoload -Uz chpwd_recent_dirs cdr add-zsh-hook
add-zsh-hook chpwd chpwd_recent_dirs

zstyle ':completion:*:*:cdr:*:*' menu selection
zstyle ':completion:*'            recent-dirs-insert both
zstyle ':chpwd:*'                 recent-dirs-default true
zstyle ':chpwd:*'                 recent-dirs-pushd true
zstyle ':chpwd:*'                 recent-dirs-max 500
zstyle ':chpwd:*'                 recent-dirs-file \
  "${XDG_CACHE_HOME:-$HOME/.cache}/shell/chpwd-recent-dirs"

[[ -d "${XDG_CACHE_HOME:-$HOME/.cache}/shell" ]] || \
  mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/shell"

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

function _fzf_sanitize_bracketed_paste {
  if (( $+zle_bracketed_paste )); then
    print $zle_bracketed_paste[2]   # ESC[?2004l — disable bracketed paste
  fi
}

# ================================
#  C-r: history search with fzf
# ================================

function fzf_history_selection {
  _fzf_sanitize_bracketed_paste
  local _history_num
  if (( $+commands[highlight] )); then
    _history_num="$(
      export FZF_DEFAULT_OPTS; LANG=C
      fc -lr 1 | highlight --syntax shellscript --out-format ansi \
        | fzf --ansi --border-label '╢ history ╟' --with-nth 3.. \
        | sed -r 's/^\s*([0-9]+).+$/\1/'
    )"
  elif (( $+commands[batcat] )); then
    _history_num="$(
      export FZF_DEFAULT_OPTS; LANG=C
      fc -lr 1 | batcat --language=sh --color=always --plain \
        | fzf --ansi --border-label '╢ history ╟' --with-nth 3.. \
        | sed -r 's/^\s*([0-9]+).+$/\1/'
    )"
  else
    _history_num="$(
      export FZF_DEFAULT_OPTS; LANG=C
      fc -lr 1 | fzf --border-label '╢ history ╟' --with-nth 2.. \
        | sed -r 's/^\s*([0-9]+).+$/\1/'
    )"
  fi
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

# Register widgets and bind keys only when fzf is available.
if (( $+commands[fzf] )); then
  zle -N fzf_history_selection
  bindkey '^R' fzf_history_selection   # C-r: replaces history-incremental-search-backward

  zle -N fzf_cdr_selection
  bindkey '^S' fzf_cdr_selection       # C-s: replaces history-incremental-search-forward
                                        # (stty -ixon is set in 20-zsh-options.zsh)
fi
