#!/bin/sh
# install.sh — Symlink dotfiles into $HOME.
#
# Creates two symlinks:
#   ~/.zshenv      -> <repo>/.zshenv
#   ~/.config/zsh  -> <repo>/.config/zsh
#
# Any existing non-symlink targets are backed up to <target>.bak before
# being replaced. Re-running this script is safe (idempotent).
#
# Usage:
#   sh install.sh
#   (Run from any directory; the repo root is resolved automatically.)

set -eu

# Resolve the repository root (the directory that contains this script).
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------------------------------------------------------------------------

die()  { printf '%s\n' "$*" >&2; exit 1; }
info() { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

# Back up $1 to $1.bak if it exists and is not already a symlink.
backup_if_needed() {
  local target="$1"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    warn "Backing up existing $target to ${target}.bak"
    mv "$target" "${target}.bak"
  fi
}

# Create or update a symlink: $1 (link path) -> $2 (target in repo).
make_link() {
  local link="$1"
  local target="$2"
  backup_if_needed "$link"
  ln -sfn "$target" "$link"
  ok "$link -> $target"
}

# ---------------------------------------------------------------------------

printf '\nInstalling dotfiles from %s\n\n' "$REPO_DIR"

# Ensure ~/.config exists.
mkdir -p "$HOME/.config"

# ~/.zshenv -> <repo>/.zshenv
make_link "$HOME/.zshenv" "$REPO_DIR/.zshenv"

# ~/.config/zsh -> <repo>/.config/zsh
make_link "$HOME/.config/zsh" "$REPO_DIR/.config/zsh"

# ~/.local/bin/<script> -> <repo>/.local/bin/<script>  (one symlink per file)
mkdir -p "$HOME/.local/bin"
for src in "$REPO_DIR/.local/bin/"*; do
  make_link "$HOME/.local/bin/$(basename "$src")" "$src"
done

printf '\nDone. Open a new shell to apply the configuration.\n'
printf 'On the first start, zsh-users plugins will be cloned automatically.\n\n'
