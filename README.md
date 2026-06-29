# dotfiles

XDG-compliant dotfiles for a WSL2 Ubuntu 26.04 zsh dev environment.
Companion to [docs/Ubuntu-26.04-devcli.user-data](docs/Ubuntu-26.04-devcli.user-data) (cloud-init provisioning).

Designed to be **forked and customised** — see [Workflows](#workflows) below.

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
- **Copy-based installer** — `install.sh` copies files from the repo into
  `$HOME`, prompts for confirmation (or pass `-y`), and migrates old
  symlink-based installs automatically. `--clean` removes files dropped from
  the repo. New tracked files are picked up on the next `install.sh` run
  without any manual wiring.

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
├── lib.sh                    # Shared helpers (sourced by the scripts below)
├── install.sh                # Copy repo files into $HOME
├── update.sh                 # Pull latest + re-copy (respects local edits)
├── import.sh                 # Push $HOME edits back into the repo
└── uninstall.sh              # Remove the repo clone
```

## Requirements

- **zsh**, **git** (required)
- **starship**, **mise**, **tmux**, **vim**, **fzf** (optional; all provisioned
  by the cloud-init `packages:` list in [docs/Ubuntu-26.04-devcli.user-data](docs/Ubuntu-26.04-devcli.user-data))

## Install

```sh
git clone https://github.com/yokarikeri/dotfiles.git ~/.dotfiles
sh ~/.dotfiles/install.sh
```

A confirmation prompt lists the files to be copied. Pass `-y` to skip it
(useful in scripts and cloud-init):

```sh
sh ~/.dotfiles/install.sh -y
```

Open a new shell. On first start, missing zsh plugins are cloned automatically.

Re-running `install.sh` is safe — it overwrites managed files and migrates any
old symlinks to real files.

## Uninstall

```sh
sh ~/.dotfiles/uninstall.sh
```

Removes the `~/.dotfiles` repo clone after confirmation. Config files that were
copied to `$HOME` are **not** touched — your environment keeps working.

## Usage

### Editing config

Config files are plain copies in `$HOME`. Editing them does **not** affect the
repo. To send your edits back to the repo, use `import.sh`.

```sh
# After editing ~/.config/zsh/conf.d/22-aliases.zsh, for example:
sh ~/.dotfiles/import.sh
```

`import.sh` copies changed files into the repo, shows `git diff`, and prints
the commands to commit and push. It does not commit anything automatically.

### Adding a new dotfile

1. Add the file to the repo under its `$HOME`-relative path and `git add` it.
2. Re-run `sh install.sh` to copy it to `$HOME`.

No manual wiring in `install.sh` is needed — `install.sh` auto-discovers all
git-tracked files under `.zshenv`, `.config/`, `.claude/`, and `.local/bin/`.

### Managing tools with mise

```sh
mise use -g <tool>@<version>   # install and add to global config
mise ls                        # list installed tools
mise upgrade                   # upgrade all tools
```

The global config at `.config/mise/config.toml` contains a commented-out
catalogue of tools to choose from, along with a quick-reference cheatsheet.

### Fresh WSL provisioning

Pass [docs/Ubuntu-26.04-devcli.user-data](docs/Ubuntu-26.04-devcli.user-data) as cloud-init user-data when
creating a new WSL instance. It installs packages, clones this repo, and runs
`install.sh -y` automatically:

```sh
wsl --install -d Ubuntu-26.04 --name Ubuntu-26.04-devcli
```

See [docs/Ubuntu-26.04-devcli.user-data](docs/Ubuntu-26.04-devcli.user-data) for the full setup.

## Workflows

### Fork-based (recommended for customisation)

Fork this repo on GitHub, then replace the URL in
[docs/Ubuntu-26.04-devcli.user-data](docs/Ubuntu-26.04-devcli.user-data) (line 184) with your fork's URL.

**Initial setup**

```sh
# Clone your fork
git clone https://github.com/<you>/dotfiles.git ~/.dotfiles

# Add the upstream repo so you can pull improvements later
git -C ~/.dotfiles remote add upstream https://github.com/yokarikeri/dotfiles.git

# Copy files into $HOME
sh ~/.dotfiles/install.sh
```

**Daily use**

```sh
# After editing config files in $HOME, import them into the repo:
sh ~/.dotfiles/import.sh
# Then review git diff, commit, and push:
cd ~/.dotfiles && git add -p && git commit -m "…" && git push
```

**Pulling upstream improvements**

```sh
# Fetch and merge changes from the original repo, then re-copy:
sh ~/.dotfiles/update.sh --upstream
```

Files you have edited locally ("diverged" files) are **not** overwritten —
their upstream diff is shown instead. Apply small changes manually; for larger
changes, run `import.sh` first to commit your version, then merge.

**Syncing your fork to another machine**

```sh
# On the second machine after cloning your fork and running install.sh:
sh ~/.dotfiles/update.sh   # pulls from your fork's origin
```

### Direct use (no fork)

Use as-is when you just want the config without maintaining a personal fork.

```sh
git clone https://github.com/yokarikeri/dotfiles.git ~/.dotfiles
sh ~/.dotfiles/install.sh
```

**Pulling updates**

```sh
sh ~/.dotfiles/update.sh
```

Files you have edited locally are not overwritten — their diff is shown and
you can decide whether to apply the upstream changes manually.

## Notes

- Commit and comment conventions are in `CLAUDE.md`.
