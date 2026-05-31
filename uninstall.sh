#!/bin/sh
# uninstall.sh — Remove symlinks created by install.sh and restore any backups.
#
# For each symlink that points into this repo:
#   - Removes the symlink.
#   - Restores <target>.bak -> <target> if a backup exists.
#
# Symlinks that exist but point elsewhere are left untouched with a warning.
# Paths that do not exist are silently skipped.
# Re-running this script is safe (idempotent).
#
# Usage:
#   sh uninstall.sh
#   (Run from any directory; the repo root is resolved automatically.)

set -eu

# Resolve the repository root (the directory that contains this script).
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------------------------------------------------------------------------

die()  { printf '%s\n' "$*" >&2; exit 1; }
info() { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

# Remove $1 if it is a symlink pointing into $REPO_DIR, then restore $1.bak.
remove_link() {
  local link="$1"

  if [ ! -e "$link" ] && [ ! -L "$link" ]; then
    info "Skipping $link (not found)"
    return
  fi

  if [ -L "$link" ]; then
    local dest
    dest="$(readlink "$link")"
    # Accept both exact-match and subpath-of REPO_DIR.
    case "$dest" in
      "$REPO_DIR"|"$REPO_DIR/"*)
        rm "$link"
        ok "Removed $link"
        ;;
      *)
        warn "Skipping $link (points to $dest, not managed by this repo)"
        return
        ;;
    esac
  else
    warn "Skipping $link (not a symlink; remove manually if needed)"
    return
  fi

  if [ -e "${link}.bak" ]; then
    mv "${link}.bak" "$link"
    ok "Restored ${link}.bak -> $link"
  fi
}

# ---------------------------------------------------------------------------

printf '\nUninstalling dotfiles (repo: %s)\n\n' "$REPO_DIR"

# ~/.zshenv
remove_link "$HOME/.zshenv"

# ~/.config/zsh
remove_link "$HOME/.config/zsh"

# ~/.config/git/config
remove_link "$HOME/.config/git/config"

# ~/.config/starship.toml
remove_link "$HOME/.config/starship.toml"

# ~/.config/mise/config.toml
remove_link "$HOME/.config/mise/config.toml"

# ~/.config/tmux
remove_link "$HOME/.config/tmux"

# ~/.config/vim
remove_link "$HOME/.config/vim"

# ~/.claude
remove_link "$HOME/.claude"

# ~/.local/bin/<script> — one link per file in .local/bin
for src in "$REPO_DIR/.local/bin/"*; do
  remove_link "$HOME/.local/bin/$(basename "$src")"
done

# tmux-popup.sh (sourced from .config/tmux, exposed in .local/bin)
remove_link "$HOME/.local/bin/tmux-popup.sh"

printf '\nDone. Dotfile symlinks have been removed.\n\n'
