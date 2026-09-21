#!/bin/sh
# import.sh — Copy locally edited config files back into the repo.
#
# For each tracked dotfile, the $HOME version is copied into the repo.
# starship.toml has its USERPROFILE path and upgrade patch reversed.
# After copying, git diff is shown and commit/push instructions are printed.
# Nothing is committed automatically.
#
# Usage:
#   sh import.sh

set -eu

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$REPO_DIR/lib.sh"

# ---------------------------------------------------------------------------

printf '\nImporting local config changes into %s\n\n' "$REPO_DIR"

_tmpfile="$(mktemp)"
trap 'rm -f "$_tmpfile"' EXIT
tracked_files > "$_tmpfile"
while IFS= read -r _f; do
  _home_src="$HOME/$_f"
  _repo_dst="$REPO_DIR/$_f"

  if [ ! -f "$_home_src" ]; then
    info "Skipping $HOME/$_f (not installed)"
    continue
  fi

  mkdir -p "$(dirname "$_repo_dst")"
  cp -p "$_home_src" "$_repo_dst"

  if [ "$_f" = ".config/starship.toml" ]; then
    reverse_starship_transform "$_repo_dst"
    ok "$_repo_dst (transform reversed)"
  else
    ok "$_repo_dst"
  fi
done < "$_tmpfile"

printf '\n'

# Show what changed in the repo.
_diff="$(git -C "$REPO_DIR" diff)"
if [ -z "$_diff" ]; then
  printf 'No changes detected in the repo — everything is already in sync.\n\n'
  exit 0
fi

printf 'Changes in the repo (git diff):\n\n'
printf '%s\n' "$_diff"

printf '\nTo commit and push these changes:\n\n'
printf '  cd %s\n' "$REPO_DIR"
printf '  git add -p            # stage hunks interactively\n'
printf '  git commit -m "your message"\n'
printf '  git push\n\n'
