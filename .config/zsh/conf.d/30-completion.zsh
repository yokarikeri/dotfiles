# ================================
#  Completion System
#  https://zsh.sourceforge.io/Doc/Release/Completion-System.html
# ================================

# Skip on dumb terminals.
[[ "$TERM" == 'dumb' ]] && return

# ================================
#  Options (completion-specific; general options are in 20-zsh-options.zsh)
# ================================

setopt AUTO_MENU         # Show a completion menu on successive Tab presses.
setopt AUTO_LIST         # List choices automatically on an ambiguous completion.
setopt AUTO_PARAM_SLASH  # Append a slash after completing a directory name.
setopt PATH_DIRS         # Perform path search even on command names with slashes.
unsetopt MENU_COMPLETE   # Do not auto-select the first completion entry.

# ================================
#  compinit with XDG-compliant cache
# ================================

autoload -Uz compinit

# Cache the dump file under XDG_CACHE_HOME and regenerate at most once per day.
_zcompdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
[[ -d "${_zcompdump:h}" ]] || mkdir -p "${_zcompdump:h}"

# #q expands globs in conditional expressions.
# -mh-20 matches files modified within the last 20 hours.
if [[ $_zcompdump(#qNmh-20) ]]; then
  # Dump is fresh: skip the security check for speed.
  compinit -C -d "$_zcompdump"
else
  # Dump is stale or missing: run a full init and touch to reset the timer.
  compinit -i -d "$_zcompdump"
  touch "$_zcompdump"
fi
unset _zcompdump

# ================================
#  Completion styles
# ================================

# Use LS_COLORS for file listing colors if available.
LS_COLORS=${LS_COLORS:-'di=34:ln=35:so=32:pi=33:ex=31:bd=36;01:cd=33;01:su=31;40;07:sg=36;40;07:tw=32;40;07:ow=33;40;07:'}
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:default' list-prompt '%S%M matches%s'

# Cache completions (useful for slow commands like dpkg, apt, npm).
zstyle ':completion::complete:*' use-cache on
zstyle ':completion::complete:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"

# Smart case sensitivity: lowercase matches uppercase, not the reverse.
# This form is safe on Zsh 5.9 (avoids the broken m:{lower:upper} bug).
zstyle ':completion:*' matcher-list \
  'm:{[:lower:]}={[:upper:]}' \
  '+r:|[._-]=* r:|=*' \
  '+l:|=*'

# Insert a TAB instead of completing when the buffer is empty.
zstyle ':completion:*' insert-tab false

# Show a navigable menu and group matches with headers.
zstyle ':completion:*:*:*:*:*'  menu select
zstyle ':completion:*:matches'  group yes
zstyle ':completion:*:options'  description yes
zstyle ':completion:*:options'  auto-description '%d'
zstyle ':completion:*'          group-name ''
zstyle ':completion:*'          verbose yes

# Colored format strings for each completion category.
zstyle ':completion:*:corrections'  format '%F{green}-- %d (errors: %e) --%f'
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:messages'     format '%F{purple}-- %d --%f'
zstyle ':completion:*:warnings'     format '%F{red}-- no matches found --%f'

# Fuzzy completer: attempt approximate matching after exact and prefix matching.
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*'       original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric
# Scale max-errors with word length, capped at 7 to avoid hangs.
zstyle -e ':completion:*:approximate:*' max-errors 'reply=($((($#PREFIX+$#SUFFIX)/3>7?7:($#PREFIX+$#SUFFIX)/3))numeric)'

# Skip internal functions and prompt helpers from completion.
zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec)|prompt_*)'

# Array subscript completion order.
zstyle ':completion:*:*:-subscript-:*' tag-order 'indexes' 'parameters'

# Directory completion ordering.
zstyle ':completion:*:*:cd:*'                 tag-order local-directories directory-stack path-directories
zstyle ':completion:*:*:cd:*:directory-stack' menu yes select
zstyle ':completion:*:-tilde-:*'              group-order 'named-directories' 'path-directories' 'users' 'expand'
zstyle ':completion:*'                        squeeze-slashes true

# History word completion.
zstyle ':completion:*:history-words' stop yes
zstyle ':completion:*:history-words' remove-all-dups yes
zstyle ':completion:*:history-words' list false
zstyle ':completion:*:history-words' menu yes

# Host completion from known_hosts and ssh config.
zstyle -e ':completion:*:hosts' hosts 'reply=(
  ${=${=${=${${(f)"$(cat {/etc/ssh/ssh_,~/.ssh/}known_hosts{,2} 2>/dev/null)"}%%[#| ]*}//\]:[0-9]*/ }//,/ }//\[/ }
  ${=${(f)"$(cat /etc/hosts 2>/dev/null; (( ${+commands[ypcat]} )) && ypcat hosts 2>/dev/null)"}%%(\#)*}
  ${=${${${${(@M)${(f)"$(cat ~/.ssh/config{,.d/*(N)} 2>/dev/null)"}:#Host *}#Host }:#*\**}:#*\?*}}
)'

# Skip uninteresting system users from user completion.
zstyle ':completion:*:*:*:users' ignored-patterns \
  '_*' adm amanda apache avahi beaglidx bin cacti canna clamav daemon dbus \
  distcache dovecot fax ftp games gdm gkrellmd gopher hacluster haldaemon \
  halt hsqldb ident junkbust ldap lp mail mailman mailnull mldonkey mysql \
  nagios named netdump news nfsnobody nobody nscd ntp nut nx openvpn \
  operator pcap postfix postgres privoxy pulse pvm quagga radvd rpc rpcuser \
  rpm shutdown squid sshd sync uucp vcsa xfs
zstyle ':completion:*' single-ignored show

# Ignore already-listed arguments for multi-argument commands.
zstyle ':completion:*:(rm|kill|diff):*' ignore-line other
zstyle ':completion:*:rm:*' file-patterns '*:all-files'

# Process and kill completion.
zstyle ':completion:*:*:*:*:processes' command 'ps -u $LOGNAME -o pid,user,command -w'
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;36=0=01'
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:*:kill:*' force-list always
zstyle ':completion:*:*:kill:*' insert-ids single

# Man page completion split by section.
zstyle ':completion:*:manuals'       separate-sections true
zstyle ':completion:*:manuals.(^1*)' insert-sections true

# ================================
#  (This MUST be done AFTER `compinit`.)
#  Bash-compatible completion system (bashcompinit)
#  https://zsh.sourceforge.io/Doc/Release/Completion-System.html#index-compinit
# ================================

# Enable compatibility with the bash completion system
# https://zsh.sourceforge.io/Doc/Release/Completion-System.html#index-bashcompinit
autoload -Uz bashcompinit && bashcompinit

# AWS CLI 2
# https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-completion.html#cli-command-completion-linux
if (( ${+commands[aws]} && ${+commands[aws_completer]} )); then
  complete -C "$commands[aws_completer]" aws
fi
