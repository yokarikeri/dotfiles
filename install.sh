#!/bin/sh
# install.sh — Copy dotfiles from the repo into $HOME, optionally pulling first.
#
# Before copying, each managed file in $HOME is compared with the repo to find
# local edits ("drift"). Locally edited files are overwritten by default;
# --update keeps them and shows the repo diff instead. Old repo-pointing
# symlinks (from a symlink-based install) are migrated to real files.
#
# Usage:
#   sh install.sh [options]
#
#   -y, --yes           Skip the confirmation prompt.
#   -i, --interactive   Decide each step in a wizard (pull, local edits,
#                       cleanup, SSH keys). Flags given alongside set defaults.
#   -u, --update        git pull before copying. Implies --local keep.
#   --upstream          Like --update, and also merge from the 'upstream'
#                       remote (for fork users).
#   --local <mode>      How to treat files edited in $HOME:
#                         overwrite  replace with the repo version (default)
#                         keep       leave as is and show the repo diff
#                                    (default with --update)
#                         review     keep, then resolve them in the drift viewer
#   --clean             Remove files a previous install placed in $HOME that
#                       the repo no longer tracks.
#   --ssh-key <name>    Copy the SSH key pair <name> and <name>.pub from Windows
#                       %USERPROFILE%\.ssh to ~/.ssh. Repeatable. Keys that are
#                       missing on Windows or already present in ~/.ssh are skipped.
#   -d, --drift         Copy nothing; list files where $HOME and the repo differ
#                       in fzf with a diff preview, and resolve them per file.
#   --direction <dir>   Diff direction in the drift viewer:
#                         repo-home  repo is "-", $HOME is "+" (default)
#                         home-repo  $HOME is "-", repo is "+"
#   -h, --help          Show this help.

set -eu

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$REPO_DIR/lib.sh"

SELF="$REPO_DIR/install.sh"

# Exported so the fzf callbacks, which run as separate processes, see it too.
DOTFILES_DRIFT_DIRECTION="${DOTFILES_DRIFT_DIRECTION:-repo-home}"
export DOTFILES_DRIFT_DIRECTION

usage() { sed -n '2,/^$/p' "$SELF" | sed 's/^# \{0,1\}//'; }

# ---------------------------------------------------------------------------
# Drift viewer
#
# fzf key bindings call back into this script through the --_drift-* commands
# below, so every action sees the current state of $HOME and the repo.

_drift_list() {
  local _scratch
  _scratch="$(mktemp)"
  drift_status "$_scratch"
  rm -f "$_scratch"
}

_colorize_status() {
  awk -F'\t' '
    BEGIN { c["M"] = 33; c["A"] = 32; c["D"] = 31 }
    { printf "\033[%sm%s\033[0m\t%s\n", c[$1], $1, $2 }'
}

_is_managed() { managed_files | grep -qxF "$1"; }

_drift_preview() {
  local _f="$1" _scratch _home _src
  _scratch="$(mktemp)"
  _home="$HOME/$_f"
  if ! _is_managed "$_f"; then
    printf 'Dropped from the repo. ctrl-o removes it from $HOME.\n\n'
    _src=/dev/null
  elif [ ! -e "$_home" ]; then
    printf 'Missing from $HOME. ctrl-o copies it from the repo.\n\n'
    _home=/dev/null
    _src="$(source_of "$_f" "$_scratch")"
  else
    _src="$(source_of "$_f" "$_scratch")"
  fi
  if [ "$DOTFILES_DRIFT_DIRECTION" = "home-repo" ]; then
    set -- "\$HOME/$_f" "repo/$_f" "$_home" "$_src"
  else
    set -- "repo/$_f" "\$HOME/$_f" "$_src" "$_home"
  fi
  if command -v delta > /dev/null 2>&1; then
    diff -u --label "$1" --label "$2" "$3" "$4" \
      | delta --paging=never --width="${FZF_PREVIEW_COLUMNS:-80}" || true
  else
    diff -u --color=always --label "$1" --label "$2" "$3" "$4" || true
  fi
  rm -f "$_scratch"
}

_drift_apply() {
  local _f
  for _f do
    if _is_managed "$_f"; then
      copy_one "$_f"
    else
      rm -f "$HOME/$_f"
      ok "Removed $HOME/$_f"
    fi
  done
  write_manifest
}

_drift_import() {
  local _f
  for _f do
    if _is_managed "$_f" && [ -f "$HOME/$_f" ]; then
      import_one "$_f"
    fi
  done
}

_drift_vimdiff() {
  local _f="$1" _repo
  _is_managed "$_f" && [ -f "$HOME/$_f" ] || return 0
  # Diff against the raw repo file (not the rendered starship.toml) so edits
  # on either side are kept.
  case "$_f" in
    .local/bin/tmux-popup.sh) _repo="$REPO_DIR/.config/tmux/tmux-popup.sh" ;;
    *)                        _repo="$REPO_DIR/$_f" ;;
  esac
  if [ "$DOTFILES_DRIFT_DIRECTION" = "home-repo" ]; then
    vim -d "$HOME/$_f" "$_repo"
  else
    vim -d "$_repo" "$HOME/$_f"
  fi
}

drift_view() {
  local _list _self _from _to
  _list="$(_drift_list)"
  if [ -z "$_list" ]; then
    printf '\nNo drift: %s matches the repo.\n\n' "$HOME"
    return 0
  fi

  if ! command -v fzf > /dev/null 2>&1 || ! [ -t 0 ] || ! [ -t 1 ]; then
    printf '\nFiles where %s and the repo differ\n' "$HOME"
    printf '(M: edited in $HOME, A: missing from $HOME, D: dropped from the repo)\n\n'
    printf '%s\n' "$_list" | sed 's/^/  /'
    printf '\nRun in a terminal with fzf installed to review and resolve them.\n\n'
    return 0
  fi

  if [ "$DOTFILES_DRIFT_DIRECTION" = "home-repo" ]; then
    _from='$HOME' _to='repo'
  else
    _from='repo' _to='$HOME'
  fi

  _self="sh '$SELF'"
  printf '%s\n' "$_list" | _colorize_status | fzf \
    --ansi --multi --reverse --border --height 100% \
    --delimiter '\t' --nth 2 --tabstop 2 \
    --border-label "╢ drift: $_from vs $_to ╟" \
    --header 'M:edited  A:missing  D:dropped from repo' \
    --footer 'ctrl-o:apply repo → $HOME
ctrl-r:import $HOME → repo
alt-v:vimdiff  tab:select  esc:quit' \
    --preview "$_self --_drift-preview {2}" \
    --preview-window 'right,60%,<50(down,60%)' \
    --preview-label " - $_from  + $_to " \
    --bind "ctrl-o:execute-silent($_self --_drift-apply {+2} && tput bel >/dev/tty)+reload($_self --_drift-list)+clear-multi" \
    --bind "ctrl-r:execute-silent($_self --_drift-import {+2} && tput bel >/dev/tty)+reload($_self --_drift-list)+clear-multi" \
    --bind "alt-v:execute($_self --_drift-vimdiff {2})+reload($_self --_drift-list)" \
    --bind 'load:transform:[ "$FZF_TOTAL_COUNT" -eq 0 ] && echo abort || :' \
    > /dev/null || true

  _list="$(_drift_list)"
  if [ -z "$_list" ]; then
    printf '\nNo drift left: %s matches the repo.\n' "$HOME"
  else
    printf '\n%d file(s) still differ from the repo.\n' \
      "$(printf '%s\n' "$_list" | wc -l)"
  fi
  if [ -n "$(git -C "$REPO_DIR" status --porcelain)" ]; then
    printf 'The repo has uncommitted changes; review them with: git -C %s diff\n' "$REPO_DIR"
  fi
  printf '\n'
}

case "${1:-}" in
  --_drift-list)    _drift_list | _colorize_status; exit 0 ;;
  --_drift-preview) _drift_preview "$2";  exit 0 ;;
  --_drift-apply)   shift; _drift_apply "$@"  > /dev/null; exit 0 ;;
  --_drift-import)  shift; _drift_import "$@" > /dev/null; exit 0 ;;
  --_drift-vimdiff) _drift_vimdiff "$2";  exit 0 ;;
esac

# ---------------------------------------------------------------------------
# Options

ASSUME_YES=0
INTERACTIVE=0
DO_UPDATE=0
DO_UPSTREAM=0
DO_CLEAN=0
DO_DRIFT=0
LOCAL_MODE=''
SSH_KEYS=''

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes)         ASSUME_YES=1 ;;
    -i|--interactive) INTERACTIVE=1 ;;
    -u|--update)      DO_UPDATE=1 ;;
    --upstream)       DO_UPDATE=1; DO_UPSTREAM=1 ;;
    --clean)          DO_CLEAN=1 ;;
    -d|--drift)       DO_DRIFT=1 ;;
    --direction)
      [ $# -ge 2 ] || die "--direction requires a value. See: sh install.sh --help"
      DOTFILES_DRIFT_DIRECTION="$2"
      shift
      ;;
    --direction=*) DOTFILES_DRIFT_DIRECTION="${1#--direction=}" ;;
    -h|--help)        usage; exit 0 ;;
    --local)
      [ $# -ge 2 ] || die "--local requires a mode. See: sh install.sh --help"
      LOCAL_MODE="$2"
      shift
      ;;
    --local=*) LOCAL_MODE="${1#--local=}" ;;
    --ssh-key)
      [ $# -ge 2 ] && [ -n "$2" ] || die "--ssh-key requires a name. See: sh install.sh --help"
      SSH_KEYS="$SSH_KEYS $2"
      shift
      ;;
    --ssh-key=?*) SSH_KEYS="$SSH_KEYS ${1#--ssh-key=}" ;;
    *) die "Unknown option: $1. See: sh install.sh --help" ;;
  esac
  shift
done

case "$LOCAL_MODE" in
  ''|overwrite|keep|review) ;;
  *) die "--local expects overwrite, keep or review: $LOCAL_MODE" ;;
esac

case "$DOTFILES_DRIFT_DIRECTION" in
  repo-home|home-repo) ;;
  *) die "--direction expects repo-home or home-repo: $DOTFILES_DRIFT_DIRECTION" ;;
esac

# Restricting the charset keeps the unquoted $SSH_KEYS loops safe from
# word splitting and globbing.
for _key in $SSH_KEYS; do
  case "$_key" in
    *[!A-Za-z0-9._-]*|.*) die "--ssh-key expects a plain file name: $_key" ;;
  esac
done

export ASSUME_YES

if [ "$DO_DRIFT" = "1" ]; then
  drift_view
  exit 0
fi

# ---------------------------------------------------------------------------
# Wizard

# Prompt until the first letter of the answer is one of $2; empty picks $3.
# Prints the chosen letter.
ask() {
  local _a
  while :; do
    printf '  %s ' "$1" >&2
    read -r _a || die "Aborted."
    [ -n "$_a" ] || _a="$3"
    _a="$(printf '%s' "$_a" | cut -c1 | tr '[:upper:]' '[:lower:]')"
    case "$2" in *"$_a"*) printf '%s\n' "$_a"; return 0 ;; esac
  done
}

# $1 = question, $2 = y or n (default). Returns 0 on yes.
ask_yn() {
  if [ "$2" = "y" ]; then
    [ "$(ask "$1 [Y/n]" yn y)" = "y" ]
  else
    [ "$(ask "$1 [y/N]" yn n)" = "y" ]
  fi
}

_yn() { if [ "$1" = "1" ]; then echo y; else echo n; fi; }

# Print names of key pairs in Windows %USERPROFILE%\.ssh that ~/.ssh lacks.
_windows_ssh_keys() {
  local _up _pub _name
  _up="$(_get_userprofile)"
  [ -n "$_up" ] || return 0
  for _pub in "$_up"/.ssh/*.pub; do
    [ -f "$_pub" ] && [ -f "${_pub%.pub}" ] || continue
    _name="${_pub##*/}"
    _name="${_name%.pub}"
    case "$_name" in *[!A-Za-z0-9._-]*|.*) continue ;; esac
    [ -e "$HOME/.ssh/$_name" ] || [ -e "$HOME/.ssh/$_name.pub" ] || printf '%s\n' "$_name"
  done
}

wizard() {
  local _ans _key _keys _default
  [ -t 0 ] || die "--interactive needs a terminal."

  printf 'Wizard — press Enter to accept the capitalized default.\n\n'

  printf 'Repository\n'
  if git -C "$REPO_DIR" remote get-url origin > /dev/null 2>&1; then
    # Pulling is the usual choice when re-running on an installed machine.
    _default="$(_yn "$DO_UPDATE")"
    [ -f "$MANIFEST_FILE" ] && _default=y
    if ask_yn "Pull the latest changes from origin first?" "$_default"; then
      DO_UPDATE=1
      if git -C "$REPO_DIR" remote get-url upstream > /dev/null 2>&1; then
        ask_yn "Also merge from the upstream remote?" "$(_yn "$DO_UPSTREAM")" \
          && DO_UPSTREAM=1 || DO_UPSTREAM=0
      fi
    else
      DO_UPDATE=0
      DO_UPSTREAM=0
    fi
  else
    info "No origin remote; skipping pull."
  fi
  printf '\n'

  if [ -s "$_tmpdir/edited.txt" ]; then
    printf 'Files edited in %s\n' "$HOME"
    sed 's/^/    /' "$_tmpdir/edited.txt"
    info "[o] overwrite with the repo version"
    info "[k] keep and show the repo diff"
    info "[r] keep, then review each file in the drift viewer"
    case "${LOCAL_MODE:-keep}" in
      overwrite) _ans="$(ask 'Choice? [O/k/r]' okr o)" ;;
      review)    _ans="$(ask 'Choice? [o/k/R]' okr r)" ;;
      *)         _ans="$(ask 'Choice? [o/K/r]' okr k)" ;;
    esac
    case "$_ans" in
      o) LOCAL_MODE=overwrite ;;
      k) LOCAL_MODE=keep ;;
      r) LOCAL_MODE=review ;;
    esac
    printf '\n'
  fi

  if [ -s "$_tmpdir/stale.txt" ]; then
    printf 'Files no longer in the repo\n'
    sed 's/^/    /' "$_tmpdir/stale.txt"
    ask_yn "Remove them from $HOME?" "$(_yn "$DO_CLEAN")" && DO_CLEAN=1 || DO_CLEAN=0
    printf '\n'
  fi

  _keys="$(_windows_ssh_keys)"
  if [ -n "$_keys" ]; then
    printf 'SSH keys on Windows missing from ~/.ssh\n'
    for _key in $_keys; do
      case " $SSH_KEYS " in *" $_key "*) continue ;; esac
      if ask_yn "Copy $_key{,.pub}?" n; then SSH_KEYS="$SSH_KEYS $_key"; fi
    done
    printf '\n'
  fi
}

# ---------------------------------------------------------------------------

printf '\nInstalling dotfiles from %s\n\n' "$REPO_DIR"

_tmpdir="$(mktemp -d)"
trap 'rm -rf "$_tmpdir"' EXIT

# Local edits are detected against the repo as it is before any pull, so a
# file that only changed upstream is not mistaken for a local edit.
printf 'Checking for local edits...\n\n'
drift_status "$_tmpdir/starship.toml" > "$_tmpdir/drift.txt"
awk -F'\t' '$1 == "M" { print $2 }' "$_tmpdir/drift.txt" > "$_tmpdir/edited.txt"
awk -F'\t' '$1 == "D" { print $2 }' "$_tmpdir/drift.txt" > "$_tmpdir/stale.txt"

[ "$INTERACTIVE" = "1" ] && wizard

if [ -z "$LOCAL_MODE" ]; then
  if [ "$DO_UPDATE" = "1" ]; then LOCAL_MODE=keep; else LOCAL_MODE=overwrite; fi
fi

_edited="$(grep -c . "$_tmpdir/edited.txt" || true)"
_stale="$(grep -c . "$_tmpdir/stale.txt" || true)"

printf 'Plan\n'
if [ "$DO_UPDATE" = "1" ]; then
  info "Pull from origin$([ "$DO_UPSTREAM" = "1" ] && printf ' and merge upstream'), then"
fi
info "copy $(managed_files | grep -c .) file(s) to $HOME."
if [ "$_edited" -gt 0 ]; then
  case "$LOCAL_MODE" in
    overwrite) info "$_edited locally edited file(s) will be OVERWRITTEN:" ;;
    keep)      info "$_edited locally edited file(s) will be kept:" ;;
    review)    info "$_edited locally edited file(s) will be kept for review:" ;;
  esac
  sed 's/^/      /' "$_tmpdir/edited.txt"
fi
if [ "$_stale" -gt 0 ]; then
  if [ "$DO_CLEAN" = "1" ]; then
    info "$_stale file(s) no longer in the repo will be removed:"
    sed 's/^/      /' "$_tmpdir/stale.txt"
  else
    info "$_stale file(s) no longer in the repo will be left in place (see --clean)."
  fi
fi
if [ -n "$SSH_KEYS" ]; then
  info "SSH key pair(s) to copy from Windows:$SSH_KEYS"
fi
printf '\n'

confirm "Proceed?" || { printf '\nAborted.\n\n'; exit 0; }
printf '\n'

# ---------------------------------------------------------------------------
# Pull

if [ "$DO_UPDATE" = "1" ]; then
  printf 'Pulling from origin...\n'
  if ! git -C "$REPO_DIR" pull; then
    printf '\n'
    warn "git pull failed. Common causes:"
    warn "  - No network access"
    warn "  - Local commits that conflict with the remote (try: git rebase origin/main)"
    warn "  - Uncommitted changes in the repo (try: git stash)"
    die "Resolve the issue and re-run install.sh --update."
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
      warn "Resolve conflicts in $REPO_DIR, commit, then re-run install.sh --update."
      die "Merge failed."
    fi
  fi
  printf '\n'
fi

# ---------------------------------------------------------------------------
# Copy

printf 'Copying files...\n'
mkdir -p "$HOME/.config" "$_tmpdir/old"

_copied=0
_kept=0

# Read the file list from a temp file so the while loop below is not a pipe
# subshell — this lets the counters accumulate, and keeps external commands
# inside copy_one (wslvar/cmd.exe) from consuming the loop's stdin.
managed_files > "$_tmpdir/files.txt"
while IFS= read -r _f; do
  _dst="$HOME/$_f"

  if [ "$LOCAL_MODE" != "overwrite" ] && grep -qxF "$_f" "$_tmpdir/edited.txt"; then
    warn "Kept (locally edited): $_dst"
    if [ "$LOCAL_MODE" = "keep" ] && [ -f "$_dst" ]; then
      diff -u --label "\$HOME/$_f" --label "repo/$_f" \
        "$_dst" "$(source_of "$_f" "$_tmpdir/starship.toml")" | sed 's/^/      /' || true
    fi
    _kept=$((_kept + 1))
    continue
  fi

  _snap="$_tmpdir/old/$(printf '%s' "$_f" | tr '/' '-')"
  if [ -f "$_dst" ]; then cp "$_dst" "$_snap"; fi
  copy_one "$_f"
  if [ -f "$_snap" ] && ! cmp -s "$_snap" "$_dst"; then
    diff -u --label "old/$_f" --label "new/$_f" "$_snap" "$_dst" | sed 's/^/      /' || true
  fi
  _copied=$((_copied + 1))
done < "$_tmpdir/files.txt"

if [ "$DO_CLEAN" = "1" ]; then
  if [ ! -f "$MANIFEST_FILE" ]; then
    warn "--clean: no previous manifest found; skipping removal step."
  else
    printf '\nCleaning up removed files...\n'
    stale_files > "$_tmpdir/stale.txt"
    while IFS= read -r _f; do
      rm -f "$HOME/$_f"
      ok "Removed $HOME/$_f"
    done < "$_tmpdir/stale.txt"
  fi
fi

if [ -n "$SSH_KEYS" ]; then
  printf '\nCopying SSH keys from Windows...\n'
  for _key in $SSH_KEYS; do
    copy_ssh_key "$_key"
  done
fi

write_manifest

printf '\nDone.\n'
info "Copied : $_copied file(s)"
info "Kept   : $_kept file(s) (locally edited)"

if [ "$_kept" -gt 0 ]; then
  if [ "$LOCAL_MODE" = "review" ]; then
    drift_view
  else
    printf '\nTo resolve kept files one by one, run: sh %s --drift\n' "$SELF"
    printf 'To bring all local edits into the repo, run: sh %s/import.sh\n' "$REPO_DIR"
  fi
fi

printf '\nOpen a new shell to apply the configuration.\n'
printf 'On the first start, zsh-users plugins will be cloned automatically.\n\n'
