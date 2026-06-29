# CLAUDE.md

## Repository Purpose
Dotfiles for the WSL environment defined in `docs/Ubuntu-26.04-devcli.user-data`.

Target environment:
- Ubuntu 26.04 on WSL2, systemd disabled
- Default shell: zsh
- Installed via `install.sh`, which copies tracked files into `$HOME` (not symlinks)

## Conventions
- Comments and commit messages: concise, plain English
- Do not add comments that explain what the code does — only add them when the *why* is non-obvious
- When adding a new dotfile, `git add` it under the appropriate `$HOME`-relative path;
  `install.sh` auto-discovers all tracked files under `.zshenv`, `.config/`, `.claude/`, `.local/`
