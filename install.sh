#!/bin/sh
# install.sh — Symlink dotfiles into $HOME.
#
# Creates symlinks:
#   ~/.zshenv                   -> <repo>/.zshenv
#   ~/.config/zsh               -> <repo>/.config/zsh
#   ~/.config/git/config        -> <repo>/.config/git/config
#   ~/.config/starship.toml     -> <repo>/.config/starship.toml
#   ~/.config/mise/config.toml  -> <repo>/.config/mise/config.toml
#   ~/.config/tmux              -> <repo>/.config/tmux
#   ~/.config/vim               -> <repo>/.config/vim
#   ~/.claude                   -> <repo>/.claude
#   ~/.local/bin/<file>         -> <repo>/.local/bin/<file>  (one per file)
#   ~/.local/bin/tmux-popup.sh  -> <repo>/.config/tmux/tmux-popup.sh
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

# Remove $1 if identical to $2, or back it up to $1.bak, if it exists and is not a symlink.
backup_if_needed() {
  local link="$1"
  local source="$2"
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    if diff -rq "$link" "$source" > /dev/null 2>&1; then
      info "Removing identical $link"
      rm -rf "$link"
    else
      warn "Backing up existing $link to ${link}.bak"
      mv "$link" "${link}.bak"
    fi
  fi
}

# Create or update a symlink: $1 (link path) -> $2 (target in repo).
make_link() {
  local link="$1"
  local target="$2"
  backup_if_needed "$link" "$target"
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

# ~/.config/git/config -> <repo>/.config/git/config
mkdir -p "$HOME/.config/git"
make_link "$HOME/.config/git/config" "$REPO_DIR/.config/git/config"

# ~/.config/starship.toml -> <repo>/.config/starship.toml
make_link "$HOME/.config/starship.toml" "$REPO_DIR/.config/starship.toml"

# ~/.config/mise/config.toml -> <repo>/.config/mise/config.toml
mkdir -p "$HOME/.config/mise"
make_link "$HOME/.config/mise/config.toml" "$REPO_DIR/.config/mise/config.toml"

# ~/.config/tmux -> <repo>/.config/tmux
make_link "$HOME/.config/tmux" "$REPO_DIR/.config/tmux"

# ~/.config/vim -> <repo>/.config/vim
make_link "$HOME/.config/vim" "$REPO_DIR/.config/vim"

# ~/.claude -> <repo>/.claude
make_link "$HOME/.claude" "$REPO_DIR/.claude"

# ~/.local/bin/<script> -> <repo>/.local/bin/<script>  (one symlink per file)
mkdir -p "$HOME/.local/bin"
for src in "$REPO_DIR/.local/bin/"*; do
  chmod +x "$src"
  make_link "$HOME/.local/bin/$(basename "$src")" "$src"
done

# tmux-popup.sh lives under .config/tmux but is invoked from ~/.local/bin
# (referenced by tmux.conf as $HOME/.local/bin/tmux-popup.sh)
chmod +x "$REPO_DIR/.config/tmux/tmux-popup.sh"
make_link "$HOME/.local/bin/tmux-popup.sh" "$REPO_DIR/.config/tmux/tmux-popup.sh"

printf '\nDone. Open a new shell to apply the configuration.\n'
printf 'On the first start, zsh-users plugins will be cloned automatically.\n\n'
