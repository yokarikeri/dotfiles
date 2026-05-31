# ================================
#  Utility Functions
# ================================

# @description Generate a random 16-character password.
#
# @stdout The generated password.
#
# @exitcode 0 If successful.
function genpw {
  LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*_+-=' < /dev/urandom | head -c 16
  echo
}

# @description Get the download URL of the latest release asset matching a regex.
#
# @example gh_latest_asset cli/cli '_linux_'$(dpkg --print-architecture)'\.deb$'
#
# @arg $1 string Repository path (e.g., "owner/repo").
# @arg $2 string Regex pattern to match the asset name.
#
# @stdout The download URL.
# @stderr Error message if any error occurs.
#
# @exitcode 0 If successful.
# @exitcode 1 If any error occurs.
function gh_latest_asset {
  if (( $# < 2 )); then
    echo "Usage: gh_latest_asset <owner/repo> <asset-name-regex>" >&2
    return 1
  fi

  local -r repo=$1 pattern=$2

  # ref. https://docs.github.com/ja/rest/releases/releases#get-the-latest-release
  local -r url="https://api.github.com/repos/${repo}/releases/latest"

  local -r response=$(curl -fsSL -H "Accept: application/vnd.github+json" "$url") || {
    echo "Error: failed to fetch latest release for ${repo}" >&2
    return 1
  }

  local -r result=$(printf '%s' "$response" \
    | jq -r --arg pat "$pattern" '.assets[] | select(.name | test($pat)) | .browser_download_url')

  if [[ -z "$result" ]]; then
    echo "Error: no asset matching '${pattern}' found in ${repo}" >&2
    return 1
  fi

  echo "$result"
}

# @description Find an executable file in Windows drives.
#
# @arg $1 string Relative path to the file (e.g., "Windows/System32/cmd.exe").
#
# @stdout The path to the file on WSL.
#
# @exitcode 0 If the file is found.
# @exitcode 1 If the file is not found.
function find_in_win_drives {
  local -r _relative_path="${1#/}"
  local _mnt_point _full_path
  for _mnt_point in $(LANG=C df -T | awk '$2 == "9p" && $1 ~ /^[A-Z]:\\$/ {print $NF}'); do
    _full_path="$_mnt_point/$_relative_path"
    test -x "$_full_path" && echo "$_full_path" && return 0
  done
  return 1
}

# @description Get the Linux path of a Windows environment variable.
#
# @arg $1 string Name of the Windows environment variable.
#
# @stdout The translated Linux path.
#
# @exitcode 0 On success.
# @exitcode 1 If the variable name is empty or the variable is not found.
function get_win_env_path {
  local -r _win_env_var="$1"
  test -z "$_win_env_var" && return 1

  (( $+commands[wslvar] )) || return 1
  (( $+commands[wslpath] )) || return 1

  local -r _win_path="$(wslvar "$_win_env_var")"
  test -z "$_win_path" && return 1

  wslpath "$_win_path"
}
