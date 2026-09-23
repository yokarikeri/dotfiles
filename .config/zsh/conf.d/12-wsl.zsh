# ================================
#  WSL
# ================================

# Skip if no commands are not available.
(( $+commands[wslpath] )) || return
(( $+commands[wslvar] )) || return

# Skip if WSL/Windows interoperability is disabled.
grep -qx enabled /proc/sys/fs/binfmt_misc/WSLInterop 2>/dev/null || return

# ================================
#  Export major Windows environment variables
# ================================

# Each lookup round-trips through wslvar+wslpath (~450ms for all 7 combined),
# and every new shell pays this cost since it isn't a login shell — cache the
# resolved values for the life of the WSL instance instead. This matters a lot
# for AI agents (e.g. Claude Code), which spawn a fresh shell per command.
local -r _win_env_cache="/tmp/zsh_win_env_${USER}"
if [[ -r "$_win_env_cache" ]]; then
  source "$_win_env_cache"
else
  export USERPROFILE="$(get_win_env_path USERPROFILE)"             # C:\Users\<username>
  export APPDATA="$(get_win_env_path APPDATA)"                     # C:\Users\<username>\AppData\Roaming
  export ProgramData="$(get_win_env_path ProgramData)"             # C:\ProgramData
  export ProgramFiles="$(get_win_env_path ProgramFiles)"           # C:\Program Files
  export ProgramFilesX86="$(get_win_env_path 'ProgramFiles(x86)')" # C:\Program Files (x86)
  export systemroot="$(get_win_env_path SystemRoot)"               # C:\WINDOWS
  export LOCALAPPDATA="$(get_win_env_path LOCALAPPDATA)"           # C:\Users\<username>\AppData\Local

  {
    print -r -- "export USERPROFILE=${(qq)USERPROFILE}"
    print -r -- "export APPDATA=${(qq)APPDATA}"
    print -r -- "export ProgramData=${(qq)ProgramData}"
    print -r -- "export ProgramFiles=${(qq)ProgramFiles}"
    print -r -- "export ProgramFilesX86=${(qq)ProgramFilesX86}"
    print -r -- "export systemroot=${(qq)systemroot}"
    print -r -- "export LOCALAPPDATA=${(qq)LOCALAPPDATA}"
  } >! "$_win_env_cache"
fi

# ================================
#  Windows executable wrappers
# ================================

# Skip if wrappers were already generated in this WSL session.
[[ -f "/tmp/zsh_already_run_${USER}_$(basename "$0")" ]] && return

# Create a shell wrapper script to run a Windows executable.
#
# Usage:
#   gen_win_wrapper "/mnt/c/Windows/explorer.exe"
#   gen_win_wrapper "/mnt/c/Windows/notepad.exe" "notepad"
#
# $1: path to the Windows executable
# $2: (optional) wrapper command name; defaults to the target filename
#
# Prints an error to stderr and returns 1 if the target does not exist or is
# not executable. Silently skips if the wrapper already exists.
function gen_win_wrapper {
  local -r target_path="$1"
  local -r cmd_name="${2:-${target_path:t}}"
  local -r wrapper_path="${XDG_BIN_HOME:-$HOME/.local/bin}/$cmd_name"
  if [[ ! -f "$target_path" ]]; then
    print -u2 "gen_win_wrapper: target not found: $target_path"
    return 1
  fi
  if [[ ! -x "$target_path" ]]; then
    print -u2 "gen_win_wrapper: target is not executable: $target_path"
    return 1
  fi
  [[ -f "$wrapper_path" ]] && return
  echo '#!/bin/sh' > "$wrapper_path"
  echo "exec \"$target_path\" \"\$@\"" >> "$wrapper_path"
  chmod +x "$wrapper_path"
}

gen_win_wrapper "$LOCALAPPDATA/Programs/Microsoft VS Code/bin/code"
gen_win_wrapper "$systemroot/explorer.exe"
gen_win_wrapper "$systemroot/System32/where.exe"

# gen_win_wrapper "$LOCALAPPDATA/Microsoft/WindowsApps/pwsh.exe"
# gen_win_wrapper "$ProgramFiles/PowerShell/7/pwsh.exe" # %ProgramFiles%\WindowsApps cannot be used because it lacks execution permissions
# gen_win_wrapper "$systemroot/System32/WindowsPowerShell/v1.0/powershell.exe"
# gen_win_wrapper "$systemroot/System32/cmd.exe"

# gen_win_wrapper "$LOCALAPPDATA/Microsoft/WindowsApps/wsl.exe"
# gen_win_wrapper "$LOCALAPPDATA/Microsoft/WindowsApps/wslconfig.exe"
# gen_win_wrapper "$LOCALAPPDATA/Microsoft/WindowsApps/bash.exe"
# gen_win_wrapper "$systemroot/System32/nvidia-smi.exe"

# gen_win_wrapper "$systemroot/notepad.exe"
# gen_win_wrapper "$systemroot/py.exe"
# gen_win_wrapper "$systemroot/pyw.exe"
# gen_win_wrapper "$systemroot/regedit.exe"

# gen_win_wrapper "$systemroot/System32/Robocopy.exe"
# gen_win_wrapper "$systemroot/System32/takeown.exe"
# gen_win_wrapper "$systemroot/System32/compact.exe"
# gen_win_wrapper "$systemroot/System32/quser.exe"
# gen_win_wrapper "$systemroot/System32/qwinsta.exe"
# gen_win_wrapper "$systemroot/System32/powercfg.exe"
# gen_win_wrapper "$systemroot/System32/powercfg.exe"

# # Generate wrappers for all .exe files under a directory:
# #   (N) = null glob (skip missing paths)
# #   (.) = regular files only (same as -type f)
local exe
for exe in $systemroot/system32/OpenSSH/*.exe(N.); do
  gen_win_wrapper "$exe"
done
# for exe in "$LOCALAPPDATA/Microsoft/WindowsApps"/*.exe(N.); do
#   gen_win_wrapper "$exe"
# done

touch "/tmp/zsh_already_run_${USER}_$(basename "$0")"
