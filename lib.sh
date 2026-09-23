#!/bin/sh
# lib.sh — shared helpers sourced by install/update/import/uninstall scripts.
# Not intended to be executed directly.

# ---------------------------------------------------------------------------
# Logging

die()  { printf '%s\n' "$*" >&2; exit 1; }
info() { printf '  %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------------------
# Confirmation

# Prompt for yes/no. Returns 0 on yes, 1 on no.
# Skipped when ASSUME_YES=1 (always returns 0).
confirm() {
  if [ "${ASSUME_YES:-0}" = "1" ]; then return 0; fi
  printf '  %s [y/N] ' "$*"
  read -r _ans
  case "$_ans" in [Yy]*) return 0 ;; *) return 1 ;; esac
}

# ---------------------------------------------------------------------------
# Managed file list

MANIFEST_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/manifest.txt"

# Emit $HOME-relative paths of all git-tracked files that belong in $HOME.
tracked_files() {
  git -C "$REPO_DIR" ls-files \
    | grep -E '^(\.zshenv$|\.config/|\.claude/|\.local/)'
}

# Like tracked_files, plus derived entries (files written by copy_one
# that have no 1:1 repo counterpart).
managed_files() {
  local _all
  _all="$(git -C "$REPO_DIR" ls-files)"
  printf '%s\n' "$_all" | grep -E '^(\.zshenv$|\.config/|\.claude/|\.local/)'
  # .local/bin/tmux-popup.sh is a derived copy of .config/tmux/tmux-popup.sh
  if printf '%s\n' "$_all" | grep -q '^\.config/tmux/tmux-popup\.sh$'; then
    printf '.local/bin/tmux-popup.sh\n'
  fi
}

write_manifest() {
  mkdir -p "$(dirname "$MANIFEST_FILE")"
  managed_files | sort -u > "$MANIFEST_FILE"
  ok "Manifest updated: $MANIFEST_FILE"
}

# ---------------------------------------------------------------------------
# starship.toml helpers

# Return true if $1 is a semantic version strictly less than $2.
version_lt() {
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$1" ] && [ "$1" != "$2" ]
}

# Resolve the real Linux path of Windows USERPROFILE, or print nothing.
# Uses </dev/null on external commands so stdin is not consumed when called
# from inside a read loop that has a pipe as its stdin.
#
# wslvar is looked up by path, not via `command -v`: this runs from
# cloud-init's runcmd as a plain non-login `sh`, which never sources
# .zshenv/12-path.zsh, so PATH has no ~/.local/bin at that point regardless
# of install order. The repo copy is always present as a fallback.
_get_userprofile() {
  local _wslvar
  for _wslvar in "$HOME/.local/bin/wslvar" "$REPO_DIR/.local/bin/wslvar"; do
    [ -x "$_wslvar" ] && break
  done
  [ -x "$_wslvar" ] || return 0
  command -v wslpath > /dev/null 2>&1 || return 0
  _wp="$("$_wslvar" USERPROFILE 2>/dev/null </dev/null)"
  [ -n "$_wp" ] && wslpath "$_wp" 2>/dev/null </dev/null || true
}

STARSHIP_PLACEHOLDER='/mnt/c/Users/username'

# Repo's starship.toml targets Starship v1.22.1 (Ubuntu 26.04 universe).
# Newer versions get the extra module sections from this patch.
STARSHIP_UPGRADE_PATCH_VERSION='1.23.0'

# Print the patch file for the installed starship, or nothing when the
# installed version needs no patch (or starship is not installed).
_starship_patch_for_installed_version() {
  local _ver=""
  command -v starship > /dev/null 2>&1 && \
    _ver="$(starship --version 2>/dev/null </dev/null | awk 'NR==1{print $2}')" || true
  [ -n "$_ver" ] || return 0
  version_lt "$_ver" "$STARSHIP_UPGRADE_PATCH_VERSION" && return 0
  printf '%s\n' "$REPO_DIR/patches/starship-v${STARSHIP_UPGRADE_PATCH_VERSION}-upgrade.patch"
}

# Copy repo's starship.toml to $1, applying USERPROFILE substitution and upgrade patch.
apply_starship_transform() {
  local dst="$1"
  cp "$REPO_DIR/.config/starship.toml" "$dst"
  local _up
  _up="$(_get_userprofile)"
  [ -n "$_up" ] && sed -i "s|${STARSHIP_PLACEHOLDER}|${_up}|g" "$dst" || true
  local _patch
  _patch="$(_starship_patch_for_installed_version)"
  [ -n "$_patch" ] && patch -s "$dst" < "$_patch" || true
}

# Reverse USERPROFILE substitution on $1 in-place. Best-effort upgrade patch reversal.
reverse_starship_transform() {
  local file="$1"
  local _up
  _up="$(_get_userprofile)"
  [ -n "$_up" ] && sed -i "s|${_up}|${STARSHIP_PLACEHOLDER}|g" "$file" || true
  local _patch
  _patch="$(_starship_patch_for_installed_version)"
  [ -n "$_patch" ] || return 0
  if patch -R --dry-run -s "$file" < "$_patch" > /dev/null 2>&1; then
    patch -R -s "$file" < "$_patch"
  else
    warn "Could not reverse starship upgrade patch — review .config/starship.toml manually before committing."
  fi
}

# ---------------------------------------------------------------------------
# Copy one managed file

# Copy the repo's version of <relpath> to $HOME/<relpath>.
# Handles starship transform, tmux-popup.sh source mapping, executable bits,
# and migration of old repo-pointing symlinks.
copy_one() {
  local relpath="$1"
  local dst="$HOME/$relpath"

  # Migrate: remove old symlinks that pointed into the repo.
  if [ -L "$dst" ]; then
    case "$(readlink "$dst")" in
      "$REPO_DIR"|"$REPO_DIR/"*) rm -f "$dst" ;;
    esac
  fi

  mkdir -p "$(dirname "$dst")"

  if [ "$relpath" = ".config/starship.toml" ]; then
    apply_starship_transform "$dst"
    ok "$dst (transformed)"
  elif [ "$relpath" = ".local/bin/tmux-popup.sh" ]; then
    # Source lives under .config/tmux/ in the repo.
    cp -p "$REPO_DIR/.config/tmux/tmux-popup.sh" "$dst"
    chmod +x "$dst"
    ok "$dst"
  else
    cp -p "$REPO_DIR/$relpath" "$dst"
    ok "$dst"
  fi

  case "$relpath" in .local/bin/*) chmod +x "$dst" ;; esac
}

# ---------------------------------------------------------------------------
# SSH keys

# Copy the SSH key pair <name> from Windows %USERPROFILE%\.ssh to ~/.ssh.
# Existing keys in ~/.ssh are never overwritten.
copy_ssh_key() {
  local name="$1"
  local _up _src _dst
  _up="$(_get_userprofile)"
  if [ -z "$_up" ]; then
    warn "SSH key $name: Windows USERPROFILE not available; skipped."
    return 0
  fi
  _src="$_up/.ssh/$name"
  _dst="$HOME/.ssh/$name"
  if [ ! -f "$_src" ] || [ ! -f "$_src.pub" ]; then
    warn "SSH key $name: $_src{,.pub} not found; skipped."
    return 0
  fi
  if [ -e "$_dst" ] || [ -e "$_dst.pub" ]; then
    warn "SSH key $name: $_dst{,.pub} already exists; not overwritten."
    return 0
  fi
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  (umask 077; cp "$_src" "$_dst")
  cp "$_src.pub" "$_dst.pub"
  chmod 600 "$_dst"
  chmod 644 "$_dst.pub"
  ok "$_dst{,.pub} (from $_src)"
}
