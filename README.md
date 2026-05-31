# dotfiles

XDG-compliant dotfiles for a WSL2 Ubuntu 26.04 zsh dev environment.
Companion to [docs/Ubuntu-26.04-devcli.user-data](docs/Ubuntu-26.04-devcli.user-data) (cloud-init provisioning).

## Features

- **XDG Base Directory** layout throughout — `ZDOTDIR=~/.config/zsh` set in
  `.zshenv`; all tool configs live under `~/.config/`.
- **Modular zsh config** — `conf.d/*.zsh` files are sourced in numeric order at
  shell start (keybinds, options, aliases, env, path, completions, …).
- **Framework-free plugins** — zsh-users plugins (`zsh-completions`,
  `zsh-autosuggestions`, `zsh-syntax-highlighting`,
  `zsh-history-substring-search`) are auto-cloned on first shell start; no
  framework, no submodules.
- **Starship prompt** — cross-shell, fast, configured at
  `.config/starship.toml`.
- **mise** — runtime version manager and task runner; global config at
  `.config/mise/config.toml` with a commented-out tool catalogue to pick from.
- **tmux** — config at `.config/tmux/tmux.conf`; includes a popup-shell helper
  (`tmux-popup.sh`) exposed as `~/.local/bin/tmux-popup.sh`.
- **Vim** — config at `.config/vim/vimrc`.
- **WSL helpers** in `.local/bin/` — `wslview` (open files/URLs in Windows),
  `wslvar` (read Windows env vars), `claude-clip` (clipboard bridge).
- **Claude Code settings** tracked under `.claude/` (settings, status-line
  script, custom skills).
- **Idempotent installer** — `install.sh` creates symlinks, backs up differing
  pre-existing files to `*.bak`, and removes identical ones. Safe to re-run.

## Directory structure

```
.dotfiles/
├── .zshenv                   # Sets ZDOTDIR; sourced first by zsh
├── .config/
│   ├── zsh/
│   │   ├── .zshrc            # Sources conf.d/*.zsh in order
│   │   └── conf.d/           # Modular config fragments (NN-name.zsh)
│   ├── git/config            # Git config
│   ├── starship.toml         # Starship prompt config
│   ├── mise/config.toml      # mise global tools + settings
│   ├── tmux/
│   │   ├── tmux.conf
│   │   ├── tmux-popup.conf
│   │   └── tmux-popup.sh
│   └── vim/vimrc
├── .claude/                  # Claude Code settings and custom skills
├── .local/bin/               # WSL helper scripts
├── docs/
│   └── Ubuntu-26.04-devcli.user-data  # cloud-init user-data for WSL setup
├── install.sh
└── uninstall.sh
```

## Requirements

- **zsh**, **git** (required)
- **starship**, **mise**, **tmux**, **vim**, **fzf** (optional; all provisioned
  by the cloud-init `packages:` list in [docs/Ubuntu-26.04-devcli.user-data](docs/Ubuntu-26.04-devcli.user-data))

## Install

```sh
git clone --recursive https://github.com/yokarikeri/dotfiles.git ~/.dotfiles
sh ~/.dotfiles/install.sh
```

Open a new shell. On first start, missing zsh plugins are cloned automatically.

Re-running `install.sh` is safe — it updates symlinks, backs up differing files
to `*.bak`, and skips files that are already identical.

## Uninstall

```sh
sh ~/.dotfiles/uninstall.sh
```

Only symlinks that point into this repo are removed. Any `*.bak` backups created
during install are restored. Symlinks you created yourself are left untouched.

## Usage

### Editing config

All `~/.config/*` entries are symlinks into the repo, so edits go directly to
the repo. Changes take effect on the next shell (or `exec zsh` for zsh config).

To add a zsh config fragment, create `.config/zsh/conf.d/NN-name.zsh`. The
numeric prefix controls load order (e.g. `30-` for completion-related setup).

### Adding a new dotfile

1. Add the file to the repo under the appropriate path.
2. Wire the symlink in `install.sh` (follow the existing pattern).
3. Re-run `sh install.sh`.

### Managing tools with mise

```sh
mise use -g <tool>@<version>   # install and add to global config
mise ls                        # list installed tools
mise upgrade                   # upgrade all tools
```

The global config at `.config/mise/config.toml` contains a commented-out
catalogue of tools to choose from, along with a quick-reference cheatsheet.

### Syncing across machines

```sh
cd ~/.dotfiles
git pull
sh install.sh   # picks up any newly added symlinks
```

### Fresh WSL provisioning

Pass [docs/Ubuntu-26.04-devcli.user-data](docs/Ubuntu-26.04-devcli.user-data) as cloud-init user-data when
creating a new WSL instance. It installs packages, clones this repo, and runs
`install.sh` automatically:

```sh
wsl --install -d Ubuntu-26.04 --name Ubuntu-26.04-devcli
```

See [docs/Ubuntu-26.04-devcli.user-data](docs/Ubuntu-26.04-devcli.user-data) for the full setup.

## Notes

- Commit and comment conventions are in `CLAUDE.md`.
