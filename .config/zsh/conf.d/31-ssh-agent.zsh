# ================================
#  SSH Agent Management
#  https://dyn.manpages.debian.org/jump?q=ssh-add
#
#  Reuses a running ssh-agent across shells and tmux sessions by
#  persisting the agent environment and pinning the socket to a
#  stable XDG-compliant path.
#
#  Keys to load are listed in the zstyle below. Bare names are expanded
#  to $HOME/.ssh/<name>. When a key pair is missing, an interactive shell
#  offers to copy it from Windows (%USERPROFILE%\.ssh) or generate it
#  (see ssh_ensure_key). Keys that remain missing are not loaded.
# ================================

zstyle ':ssh-agent' ids 'id_ed25519'

# @description Make sure an SSH key pair exists, offering to create it if not.
#
# @description
#   If <key> and <key>.pub already exist, nothing happens. Otherwise, in an
#   interactive shell, the user is asked whether to:
#     - generate a key pair at all (no -> give up)
#     - copy it from Windows %USERPROFILE%\.ssh (generating it there first
#       with Windows OpenSSH if missing) or generate it on Ubuntu only
#     - protect a newly generated key with a passphrase
#   Every prompt can be skipped, which gives up without changing anything.
#
#   Keys are copied instead of relayed through a Windows named pipe
#   (e.g. npiperelay) to keep dependencies minimal; changes made on Windows
#   later are not reflected.
#
# @example ssh_ensure_key ~/.ssh/id_ed25519
#
# @arg $1 string Absolute path to the private key on Ubuntu.
#
# @exitcode 0 If the key pair exists (already, or after this call).
# @exitcode 1 If it is missing, skipped, or could not be created.
function ssh_ensure_key {
  local -r key="$1"
  [[ -f "$key" && -f "$key.pub" ]] && return 0
  [[ -o interactive && -t 0 && -t 1 ]] || return 1

  local ans
  print -r -- "SSH key pair not found: ${key}{,.pub}"
  print -r -- "  [g] Generate a key pair"
  print -r -- "  [s] Skip (the SSH agent will not load this key)"
  read -r "ans?Choose [g/S]: "
  [[ "$ans" == [gG] ]] || return 1

  # Windows side is only offered when 12-wsl.zsh could resolve its paths.
  local win_key="" win_keygen=""
  if [[ -d "${USERPROFILE:-}" ]]; then
    win_key="$USERPROFILE/.ssh/${key:t}"
    [[ -x "$systemroot/System32/OpenSSH/ssh-keygen.exe" ]] &&
      win_keygen="$systemroot/System32/OpenSSH/ssh-keygen.exe"
  fi

  # origin: windows-copy | windows-gen | ubuntu
  local origin=ubuntu
  if [[ -n "$win_key" ]]; then
    local win_exists=0
    [[ -f "$win_key" && -f "$win_key.pub" ]] && win_exists=1
    if (( win_exists )); then
      print -r -- "  [c] Copy the existing Windows key pair: ${win_key}{,.pub}"
    elif [[ -n "$win_keygen" ]]; then
      print -r -- "  [c] Generate on Windows (${win_key}) and copy it here"
    fi
    print -r -- "  [u] Generate on Ubuntu only"
    print -r -- "  [s] Skip"
    read -r "ans?Choose [c/u/S]: "
    case "$ans" in
      [cC])
        if (( win_exists )); then
          origin=windows-copy
        elif [[ -n "$win_keygen" ]]; then
          origin=windows-gen
        else
          return 1
        fi
        ;;
      [uU]) origin=ubuntu ;;
      *) return 1 ;;
    esac
  fi

  if [[ "$origin" != windows-copy ]]; then
    local -a pass_opt
    print -r -- "  [p] Set a passphrase (ssh-keygen will prompt for it)"
    print -r -- "  [n] No passphrase"
    print -r -- "  [s] Skip"
    read -r "ans?Choose [p/n/S]: "
    case "$ans" in
      [pP]) pass_opt=() ;;
      [nN]) pass_opt=(-N '') ;;
      *) return 1 ;;
    esac

    local email
    email="$(git config --get user.email 2>/dev/null)"
    if [[ "$origin" == windows-gen ]]; then
      local -a comment=("$email" "$(wslvar COMPUTERNAME 2>/dev/null)")
      mkdir -p "${win_key:h}"
      "$win_keygen" -t ed25519 -C "${(j: :)comment:#}" "${pass_opt[@]}" \
        -f "$(wslpath -w "$win_key")"
    else
      local -a comment=("$email" "$HOST")
      mkdir -p -m 700 "${key:h}"
      ssh-keygen -t ed25519 -C "${(j: :)comment:#}" "${pass_opt[@]}" -f "$key"
    fi
  fi

  if [[ "$origin" == windows-* ]]; then
    if [[ -f "$win_key" && -f "$win_key.pub" ]]; then
      mkdir -p -m 700 "${key:h}"
      (umask 077; cp "$win_key" "$key") &&
        cp "$win_key.pub" "$key.pub" &&
        chmod 600 "$key" && chmod 644 "$key.pub"
    fi
  fi

  if [[ ! -f "$key" || ! -f "$key.pub" ]]; then
    print -u2 -r -- "Failed to set up SSH key pair: ${key}{,.pub}"
    return 1
  fi
  print -r -- "SSH key pair ready: ${key}{,.pub}"
}

(( ${+commands[ssh-agent]} )) && () {
  local ssh_env="${XDG_CACHE_HOME:-${HOME}/.cache}/ssh/agent.env"
  local ssh_sock="${XDG_CACHE_HOME:-${HOME}/.cache}/ssh/agent.sock"

  # Resolve the list of keys, keeping only those that exist (or were just
  # created). With none left, skip the agent entirely.
  local -a ssh_ids=() _conf_ids
  zstyle -a ':ssh-agent' ids _conf_ids
  local _id
  for _id in "${_conf_ids[@]}"; do
    [[ "${_id}" == /* ]] || _id="${HOME}/.ssh/${_id}"
    ssh_ensure_key "${_id}" && ssh_ids+=("${_id}")
  done
  (( ${#ssh_ids} )) || return 0

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

  # Use SSH_ASKPASS for a GUI passphrase dialog when a display is available.
  if [[ -n "${DISPLAY}" && -x "${SSH_ASKPASS}" ]]; then
    ssh-add "${ssh_ids[@]}" </dev/null 2>/dev/null
  else
    ssh-add "${ssh_ids[@]}" 2>/dev/null
  fi
}
