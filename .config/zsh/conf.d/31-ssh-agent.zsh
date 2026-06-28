# ================================
#  SSH Agent Management
#  https://dyn.manpages.debian.org/jump?q=ssh-add
#
#  Reuses a running ssh-agent across shells and tmux sessions by
#  persisting the agent environment and pinning the socket to a
#  stable XDG-compliant path.
#
#  To specify which keys to load, set:
#    zstyle ':ssh-agent' ids 'id_ed25519' 'id_work'
#  Bare names are expanded to $HOME/.ssh/<name>.
#  When not set, defaults to $HOME/.ssh/id_ed25519.
# ================================

(( ${+commands[ssh-agent]} )) && () {
  local ssh_env="${XDG_CACHE_HOME:-${HOME}/.cache}/ssh/agent.env"
  local ssh_sock="${XDG_CACHE_HOME:-${HOME}/.cache}/ssh/agent.sock"

  # Check whether a reachable agent is already available.
  ssh-add -l &>/dev/null
  if (( ? == 2 )); then
    # No agent contact — try loading a previously saved environment.
    [[ -r "${ssh_env}" ]] && source "${ssh_env}" >/dev/null

    ssh-add -l &>/dev/null
    if (( ? == 2 )); then
      # Still no agent — start a new one and save its environment.
      mkdir -p "${ssh_env:h}"
      (umask 066; ssh-agent | sed '/^echo /d' >! "${ssh_env}")
      source "${ssh_env}" >/dev/null
      # Abort if the freshly started agent is still unreachable.
      ssh-add -l &>/dev/null
      (( ? != 2 )) || return 1
    fi
  fi

  # Pin SSH_AUTH_SOCK to a stable path so tmux/screen reattaches work.
  if [[ -S "${SSH_AUTH_SOCK}" && "${SSH_AUTH_SOCK}" != "${ssh_sock}" ]]; then
    mkdir -p "${ssh_sock:h}"
    ln -sf "${SSH_AUTH_SOCK}" "${ssh_sock}"
    export SSH_AUTH_SOCK="${ssh_sock}"
  fi

  # If the agent is running but holds no keys, load them now.
  ssh-add -l &>/dev/null
  (( ? == 1 )) || return 0

  # Resolve the list of keys from zstyle, falling back to id_ed25519.
  local -a ssh_ids
  zstyle -a ':ssh-agent' ids ssh_ids
  if (( ${#ssh_ids} )); then
    local -a _expanded=()
    local _id
    for _id in "${ssh_ids[@]}"; do
      [[ "${_id}" == /* ]] || _id="${HOME}/.ssh/${_id}"
      _expanded+=("${_id}")
    done
    ssh_ids=("${_expanded[@]}")
  else
    [[ -f "${HOME}/.ssh/id_ed25519" ]] || return 1
    ssh_ids=("${HOME}/.ssh/id_ed25519")
  fi

  # Use SSH_ASKPASS for a GUI passphrase dialog when a display is available.
  if [[ -n "${DISPLAY}" && -x "${SSH_ASKPASS}" ]]; then
    ssh-add "${ssh_ids[@]}" </dev/null 2>/dev/null
  else
    ssh-add "${ssh_ids[@]}" 2>/dev/null
  fi
}
