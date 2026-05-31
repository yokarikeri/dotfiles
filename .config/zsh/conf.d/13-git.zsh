# ================================
#  Git (WSL)
# ================================

# Skip if Windows environment variables are not available.
[[ -n "${USERPROFILE:-}" && -n "${ProgramFiles:-}" ]] || return

# @description Set up git credential.helper and user identity from Windows.
#
# @description
#   Writes machine-local git settings to $XDG_CONFIG_HOME/git/config.local,
#   which is included by the tracked config via [include]. This keeps personal
#   and machine-specific values out of the repository.
#
#   Settings applied:
#     - credential.helper: Windows Git Credential Manager (GCM), if present
#     - user.name / user.email: copied from Windows global git config, if present
#
# @exitcode 0 Always.
function setup_win_git {
  local -r local_config="${XDG_CONFIG_HOME:-$HOME/.config}/git/config.local"
  local -r git_exe="$ProgramFiles/Git/cmd/git.exe"
  local -r gcm_exe="$ProgramFiles/Git/mingw64/bin/git-credential-manager.exe"

  # credential.helper -> Windows GCM.
  # Spaces in the path ("Program Files") must be backslash-escaped because
  # git interprets the helper value as a command line.
  if [[ -x "$gcm_exe" ]]; then
    git config --file "$local_config" credential.helper "${gcm_exe// /\\ }"
  fi

  # user.name / user.email <- Windows global git config.
  # Strip \r because git.exe on Windows outputs CRLF line endings.
  if [[ -x "$git_exe" ]]; then
    local name email
    name=$("$git_exe" config --get user.name  2>/dev/null | tr -d '\r')
    email=$("$git_exe" config --get user.email 2>/dev/null | tr -d '\r')
    [[ -n "$name"  ]] && git config --file "$local_config" user.name  "$name"
    [[ -n "$email" ]] && git config --file "$local_config" user.email "$email"
  fi
}

# Auto-run once: generate config.local on the first interactive shell.
# To regenerate, delete config.local or call setup_win_git manually.
local _git_local="${XDG_CONFIG_HOME:-$HOME/.config}/git/config.local"
[[ -f "$_git_local" ]] || setup_win_git
