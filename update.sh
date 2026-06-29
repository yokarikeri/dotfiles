#!/bin/sh
# update.sh — Pull the latest repo changes and re-copy dotfiles into $HOME.
#
# Before pulling, each managed file is compared against the current repo version
# to detect local edits ("divergence"):
#
#   Unchanged files: overwritten after pull; the diff from old to new is shown.
#   Locally edited:  NOT overwritten; the upstream diff is shown instead.
#                    For small differences, edit manually. For large changes,
#                    run import.sh to push your edits back into the repo first.
#
# Usage:
#   sh update.sh [--upstream]
#
#   --upstream  Also merge from the 'upstream' remote (for fork users).
#               Requires: git remote add upstream <original-repo-url>

set -eu

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$REPO_DIR/lib.sh"

DO_UPSTREAM=0
for _arg do
  case "$_arg" in
    --upstream) DO_UPSTREAM=1 ;;
    *) die "Unknown option: $_arg. Usage: sh update.sh [--upstream]" ;;
  esac
done

# ---------------------------------------------------------------------------

printf '\nUpdating dotfiles in %s\n\n' "$REPO_DIR"

_tmpdir="${TMPDIR:-/tmp}/dotfiles-update-$$"
mkdir -p "$_tmpdir/old"
trap 'rm -rf "$_tmpdir"' EXIT

# ---------------------------------------------------------------------------
# Step 1: Record divergence status before pull

printf 'Checking for local edits...\n'

_status_file="$_tmpdir/status.txt"
: > "$_status_file"

# Write managed files to a temp file so that the while loop below does not
# run in a pipe subshell (which would prevent variable updates from sticking).
managed_files > "$_tmpdir/files.txt"

while IFS= read -r _f; do
  _home_dst="$HOME/$_f"

  if [ ! -f "$_home_dst" ]; then
    printf 'clean\t%s\n' "$_f" >> "$_status_file"
    continue
  fi

  if [ "$_f" = ".config/starship.toml" ]; then
    _cmp="$_tmpdir/starship-pre.toml"
    apply_starship_transform "$_cmp"
  elif [ "$_f" = ".local/bin/tmux-popup.sh" ]; then
    _cmp="$REPO_DIR/.config/tmux/tmux-popup.sh"
  else
    _cmp="$REPO_DIR/$_f"
  fi

  if diff -q "$_cmp" "$_home_dst" > /dev/null 2>&1; then
    printf 'clean\t%s\n' "$_f" >> "$_status_file"
  else
    printf 'diverged\t%s\n' "$_f" >> "$_status_file"
  fi
done < "$_tmpdir/files.txt"

_div=$(awk -F'\t' '$1=="diverged"' "$_status_file" | wc -l | tr -d ' ')
_cln=$(awk -F'\t' '$1=="clean"'   "$_status_file" | wc -l | tr -d ' ')
printf '  %s file(s) unchanged, %s file(s) locally edited\n\n' "$_cln" "$_div"

# ---------------------------------------------------------------------------
# Step 2: Pull

printf 'Pulling from origin...\n'
if ! git -C "$REPO_DIR" pull; then
  printf '\n'
  warn "git pull failed. Common causes:"
  warn "  - No network access"
  warn "  - Local commits that conflict with the remote (try: git rebase origin/main)"
  warn "  - Uncommitted changes in the repo (try: git stash)"
  die "Resolve the issue and re-run update.sh."
fi

if [ "$DO_UPSTREAM" = "1" ]; then
  printf '\nMerging from upstream...\n'
  if ! git -C "$REPO_DIR" fetch upstream; then
    warn "git fetch upstream failed."
    warn "Make sure the upstream remote is configured:"
    warn "  git remote add upstream https://github.com/yokarikeri/dotfiles.git"
    die "Aborting."
  fi
  _branch="$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)"
  if ! git -C "$REPO_DIR" merge "upstream/$_branch"; then
    warn "Merge conflict detected."
    warn "Resolve conflicts in $REPO_DIR, commit, then re-run update.sh."
    die "Merge failed."
  fi
fi

printf '\n'

# ---------------------------------------------------------------------------
# Step 3: Re-copy managed files based on pre-pull divergence status.
# Use a temp file for managed_files output so the while loop is not a
# pipe subshell — this lets _overwritten and _skipped accumulate correctly.

managed_files > "$_tmpdir/files-post.txt"

_overwritten=0
_skipped=0

while IFS= read -r _f; do
  _home_dst="$HOME/$_f"

  if awk -F'\t' -v f="$_f" 'BEGIN{r=1} $1=="diverged"&&$2==f{r=0} END{exit r}' \
      "$_status_file"; then
    # Locally edited: show upstream diff, do not overwrite.
    warn "Skipped (locally edited): $HOME/$_f"
    if [ "$_f" = ".config/starship.toml" ]; then
      _udiff_src="$_tmpdir/starship-post.toml"
      apply_starship_transform "$_udiff_src"
    elif [ "$_f" = ".local/bin/tmux-popup.sh" ]; then
      _udiff_src="$REPO_DIR/.config/tmux/tmux-popup.sh"
    else
      _udiff_src="$REPO_DIR/$_f"
    fi
    if [ -f "$_home_dst" ] && [ -f "$_udiff_src" ]; then
      printf '\n  Upstream changes for %s:\n' "$_f"
      diff "$_home_dst" "$_udiff_src" || true
      printf '  To incorporate large changes run: sh %s/import.sh\n\n' "$REPO_DIR"
    fi
    _skipped=$((_skipped + 1))
  else
    # Unchanged (or new from pull): overwrite and show diff.
    _snap="$_tmpdir/old/$(printf '%s' "$_f" | tr '/' '-')"
    [ -f "$_home_dst" ] && cp "$_home_dst" "$_snap" || true
    copy_one "$_f"
    if [ -f "$_snap" ] && ! diff -q "$_snap" "$_home_dst" > /dev/null 2>&1; then
      printf '\n  Updated %s:\n' "$_f"
      diff "$_snap" "$_home_dst" || true
      printf '\n'
    fi
    _overwritten=$((_overwritten + 1))
  fi
done < "$_tmpdir/files-post.txt"

write_manifest

printf '\nDone.\n'
printf '  Updated : %d file(s)\n' "$_overwritten"
printf '  Skipped : %d file(s) (locally edited, not overwritten)\n' "$_skipped"
if [ "$_skipped" -gt 0 ]; then
  printf '\nSkipped files were not overwritten. Edit them manually or run:\n'
  printf '  sh %s/import.sh\n' "$REPO_DIR"
fi
printf '\n'
