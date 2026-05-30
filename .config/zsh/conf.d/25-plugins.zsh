# ================================
#  Zsh Plugin Bootstrap
#
#  Plugins are cloned on first use into $ZSH_PLUGINS_DIR.
#  No framework or submodule management is required.
# ================================

# Require git; degrade gracefully if it is missing.
(( $+commands[git] )) || return

typeset -g ZSH_PLUGINS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
[[ -d "$ZSH_PLUGINS_DIR" ]] || mkdir -p "$ZSH_PLUGINS_DIR"

# Ensure a plugin directory exists; clone it if not.
# Sets REPLY to the plugin's local directory path.
# Returns 0 on success, non-zero if the clone fails.
function _zsh_plugin_dir {
  local name=$1 url=$2
  REPLY="$ZSH_PLUGINS_DIR/$name"
  [[ -d "$REPLY" ]] && return 0
  print -P "%F{cyan}-- installing zsh plugin: ${name} --%f"
  command git clone --depth 1 --quiet -- "$url" "$REPLY"
}

# Ensure a plugin directory exists, then source its entry file.
# $1: plugin name (directory name under $ZSH_PLUGINS_DIR)
# $2: git URL to clone from if the directory is missing
# $3: relative path to the entry file inside the plugin directory
function _zsh_plugin_source {
  local name=$1 url=$2 entry=$3
  _zsh_plugin_dir "$name" "$url" || return 1
  source "$REPLY/$entry"
}

# ================================
#  zsh-completions
#  https://github.com/zsh-users/zsh-completions
#
#  Only adds its completion functions to fpath; must come before compinit.
# ================================
if _zsh_plugin_dir zsh-completions \
     'https://github.com/zsh-users/zsh-completions.git'; then
  fpath=("$REPLY/src" $fpath)
fi
