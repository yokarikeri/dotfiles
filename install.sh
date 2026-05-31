#!/bin/sh
# install.sh — Symlink dotfiles into $HOME.
#
# Creates symlinks:
#   ~/.zshenv                      -> <repo>/.zshenv
#   ~/.config/zsh/<entry>          -> <repo>/.config/zsh/<entry>  (one per entry)
#   ~/.config/git/config           -> <repo>/.config/git/config
#   ~/.config/starship.toml        -> <repo>/.config/starship.toml
#   ~/.config/mise/config.toml     -> <repo>/.config/mise/config.toml
#   ~/.config/tmux/<entry>         -> <repo>/.config/tmux/<entry> (one per entry)
#   ~/.config/vim/<entry>          -> <repo>/.config/vim/<entry>  (one per entry)
#   ~/.claude/<entry>              -> <repo>/.claude/<entry>      (one per entry)
#   ~/.local/bin/<file>            -> <repo>/.local/bin/<file>    (one per file)
#   ~/.local/bin/tmux-popup.sh     -> <repo>/.config/tmux/tmux-popup.sh
#
# Directories that applications use as writable homes (zsh, tmux, vim, claude)
# are created as real directories; only their tracked contents are symlinked.
# Runtime-generated files (e.g. .zcompdump, .credentials.json) therefore stay
# in ~ and never appear inside the repo.
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

# Return true if $1 is a semantic version strictly less than $2.
version_lt() {
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$1" ] && [ "$1" != "$2" ]
}

# Create or update a symlink: $1 (link path) -> $2 (target in repo).
make_link() {
  local link="$1"
  local target="$2"
  backup_if_needed "$link" "$target"
  ln -sfn "$target" "$link"
  ok "$link -> $target"
}

# Make $1 a real directory and symlink each top-level entry of repo dir $2 into it.
# Used for application "home" directories that receive runtime-generated files,
# so those files land in the real directory and never inside the repo.
link_dir_contents() {
  local dest="$1"
  local src="$2"
  # Migration: if a previous run left $dest as a whole-directory symlink, drop it
  # first so we don't create child links *through* the link into the repo itself.
  [ -L "$dest" ] && rm -f "$dest"
  mkdir -p "$dest"
  for entry in "$src"/* "$src"/.[!.]*; do
    [ -e "$entry" ] || continue   # skip when a glob expands to nothing
    make_link "$dest/$(basename "$entry")" "$entry"
  done
}

# ---------------------------------------------------------------------------

printf '\nInstalling dotfiles from %s\n\n' "$REPO_DIR"

# Ensure ~/.config exists.
mkdir -p "$HOME/.config"

# ~/.zshenv -> <repo>/.zshenv
make_link "$HOME/.zshenv" "$REPO_DIR/.zshenv"

# ~/.config/zsh/<entry> -> <repo>/.config/zsh/<entry>
link_dir_contents "$HOME/.config/zsh" "$REPO_DIR/.config/zsh"

# ~/.config/git/config -> <repo>/.config/git/config
mkdir -p "$HOME/.config/git"
make_link "$HOME/.config/git/config" "$REPO_DIR/.config/git/config"

# ~/.config/starship.toml -> <repo>/.config/starship.toml
# starship < 1.23.0 (Ubuntu 26.04 ships 1.22.1) doesn't recognise some keys;
# apply a compat patch to a plain file instead of symlinking.
_starship_ver=""
if command -v starship > /dev/null 2>&1; then
  _starship_ver=$(starship --version 2>/dev/null | awk 'NR==1{print $2}')
fi
if [ -n "$_starship_ver" ] && version_lt "$_starship_ver" "1.23.0"; then
  _link="$HOME/.config/starship.toml"
  if [ -e "$_link" ] && [ ! -L "$_link" ]; then
    warn "Backing up existing $_link to ${_link}.bak"
    mv "$_link" "${_link}.bak"
  elif [ -L "$_link" ]; then
    rm -f "$_link"
  fi
  cp "$REPO_DIR/.config/starship.toml" "$_link"
  patch -s "$_link" < "$REPO_DIR/patches/starship-v1.22.1-compat.patch"
  ok "$_link (patched for starship $_starship_ver)"
else
  make_link "$HOME/.config/starship.toml" "$REPO_DIR/.config/starship.toml"
fi

# ~/.config/mise/config.toml -> <repo>/.config/mise/config.toml
mkdir -p "$HOME/.config/mise"
make_link "$HOME/.config/mise/config.toml" "$REPO_DIR/.config/mise/config.toml"

# ~/.config/tmux/<entry> -> <repo>/.config/tmux/<entry>
link_dir_contents "$HOME/.config/tmux" "$REPO_DIR/.config/tmux"

# ~/.config/vim/<entry> -> <repo>/.config/vim/<entry>
link_dir_contents "$HOME/.config/vim" "$REPO_DIR/.config/vim"

# ~/.claude/<entry> -> <repo>/.claude/<entry>
link_dir_contents "$HOME/.claude" "$REPO_DIR/.claude"

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
