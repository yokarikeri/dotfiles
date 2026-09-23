#!/bin/sh
# install.sh — Copy dotfiles from the repo into $HOME.
#
# Copies each tracked dotfile to $HOME, overwriting any existing file.
# A confirmation prompt is shown first; -y skips it.
# Old repo-pointing symlinks (from a symlink-based install) are migrated
# to real files automatically.
#
# Usage:
#   sh install.sh [-y] [--clean] [--ssh-key <name>]...
#
#   -y, --yes         Skip the confirmation prompt.
#   --clean           After copying, remove files that a previous install placed
#                     in $HOME but that are no longer tracked by the repo.
#   --ssh-key <name>  Copy the SSH key pair <name> and <name>.pub from Windows
#                     %USERPROFILE%\.ssh to ~/.ssh. Repeatable. Keys that are
#                     missing on Windows or already present in ~/.ssh are skipped.

set -eu

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$REPO_DIR/lib.sh"

USAGE='Usage: sh install.sh [-y] [--clean] [--ssh-key <name>]...'

ASSUME_YES=0
DO_CLEAN=0
SSH_KEYS=''

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes) ASSUME_YES=1 ;;
    --clean)  DO_CLEAN=1   ;;
    --ssh-key)
      [ $# -ge 2 ] && [ -n "$2" ] || die "--ssh-key requires a name. $USAGE"
      SSH_KEYS="$SSH_KEYS $2"
      shift
      ;;
    --ssh-key=?*) SSH_KEYS="$SSH_KEYS ${1#--ssh-key=}" ;;
    *) die "Unknown option: $1. $USAGE" ;;
  esac
  shift
done

# Restricting the charset keeps the unquoted $SSH_KEYS loops safe from
# word splitting and globbing.
for _key in $SSH_KEYS; do
  case "$_key" in
    *[!A-Za-z0-9._-]*|.*) die "--ssh-key expects a plain file name: $_key" ;;
  esac
done

export ASSUME_YES

# ---------------------------------------------------------------------------

printf '\nInstalling dotfiles from %s\n\n' "$REPO_DIR"

_files="$(managed_files)"
_count="$(printf '%s\n' "$_files" | grep -c '.')"

printf '  %d file(s) will be copied to %s.\n' "$_count" "$HOME"
printf '  Existing files will be overwritten.\n'
if [ -n "$SSH_KEYS" ]; then
  printf '  SSH key pair(s) to copy from Windows:%s\n' "$SSH_KEYS"
fi
printf '\n'

confirm "Proceed?" || { printf '\nAborted.\n\n'; exit 0; }
printf '\n'

mkdir -p "$HOME/.config"

# Write the file list to a temp file so the while loop below is not a pipe
# subshell — this avoids external commands inside copy_one (wslvar/cmd.exe)
# inadvertently consuming bytes from a pipe connected to the loop's stdin.
_tmpfile="$(mktemp)"
trap 'rm -f "$_tmpfile"' EXIT
printf '%s\n' "$_files" > "$_tmpfile"
while IFS= read -r _f; do
  copy_one "$_f"
done < "$_tmpfile"

# --clean: remove files that are in the old manifest but no longer managed.
if [ "$DO_CLEAN" = "1" ]; then
  if [ ! -f "$MANIFEST_FILE" ]; then
    warn "--clean: no previous manifest found; skipping removal step."
  else
    printf '\nCleaning up removed files...\n'
    _new="$(managed_files | sort -u)"
    while IFS= read -r _old; do
      if ! printf '%s\n' "$_new" | grep -qxF "$_old"; then
        _old_path="$HOME/$_old"
        if [ -e "$_old_path" ] || [ -L "$_old_path" ]; then
          rm -f "$_old_path"
          ok "Removed $HOME/$_old"
        fi
      fi
    done < "$MANIFEST_FILE"
  fi
fi

if [ -n "$SSH_KEYS" ]; then
  printf '\nCopying SSH keys from Windows...\n'
  for _key in $SSH_KEYS; do
    copy_ssh_key "$_key"
  done
fi

write_manifest

printf '\nDone. Open a new shell to apply the configuration.\n'
printf 'On the first start, zsh-users plugins will be cloned automatically.\n\n'
