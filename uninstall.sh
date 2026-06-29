#!/bin/sh
# uninstall.sh — Remove the dotfiles repo clone from $HOME.
#
# Only the repo directory (~/.dotfiles) is deleted. Config files that were
# copied to $HOME during install are NOT touched.
#
# Usage:
#   sh uninstall.sh [-y]
#
#   -y, --yes  Skip the confirmation prompt.

set -eu

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

die() { printf '%s\n' "$*" >&2; exit 1; }
ok()  { printf '  \033[32m✓\033[0m %s\n' "$*"; }

ASSUME_YES=0
for _arg do
  case "$_arg" in
    -y|--yes) ASSUME_YES=1 ;;
    *) die "Unknown option: $_arg. Usage: sh uninstall.sh [-y]" ;;
  esac
done

# ---------------------------------------------------------------------------

printf '\nThis will permanently remove the dotfiles repo:\n'
printf '  %s\n\n' "$REPO_DIR"
printf '  Config files already copied to %s will NOT be affected.\n\n' "$HOME"

if [ "$ASSUME_YES" != "1" ]; then
  printf '  Remove repo? [y/N] '
  read -r _ans
  case "$_ans" in
    [Yy]*) ;;
    *) printf '\nAborted.\n\n'; exit 0 ;;
  esac
  printf '\n'
fi

# cd out of the repo before deleting it.
cd "$HOME"
rm -rf "$REPO_DIR"
ok "Removed $REPO_DIR"

printf '\nDone. The dotfiles repo has been removed.\n'
printf 'Your config files in %s remain in place.\n\n' "$HOME"
