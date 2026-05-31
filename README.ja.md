# dotfiles

WSL2 Ubuntu 26.04 zsh 開発環境向けの XDG 準拠の dotfiles です。
[docs/Ubuntu-26.04-devcli.user-data](docs/Ubuntu-26.04-devcli.user-data) （cloud-init プロビジョニング）の対となるものです。

## Features

- 全体で **XDG Base Directory** レイアウトを採用しています。`.zshenv` で `ZDOTDIR=~/.config/zsh` を設定しており、すべてのツール設定は `~/.config/` 以下に配置されます。
- **モジュール化された zsh 設定** — `conf.d/*.zsh` ファイルは、シェル起動時に数値順にソース（読み込み）されます（キーバインド、オプション、エイリアス、環境変数、パス、補完など）。
- **フレームワーク不使用のプラグイン** — zsh-users プラグイン（`zsh-completions`、`zsh-autosuggestions`、`zsh-syntax-highlighting`、`zsh-history-substring-search`）は、最初のシェル起動時に自動的にクローンされます。フレームワークやサブモジュールは使用していません。
- **Starship プロンプト** — 複数のシェルに対応した高速なプロンプトです。`.config/starship.toml` で設定されています。
- **mise** — ランタイムバージョンマネージャーおよびタスクランナーです。グローバル設定は `.config/mise/config.toml` にあり、選択可能なツールカタログがコメントアウトされた状態で記載されています。
- **tmux** — 設定は `.config/tmux/tmux.conf` にあります。`~/.local/bin/tmux-popup.sh` として公開されているポップアップシェルヘルパー（`tmux-popup.sh`）を含んでいます。
- **Vim** — 設定は `.config/vim/vimrc` にあります。
- `.local/bin/` 内の **WSL ヘルパー** — `wslview`（Windows でファイルや URL を開く）、`wslvar`（Windows の環境変数を読み込む）、`claude-clip`（クリップボードのブリッジ）があります。
- **Claude Code 設定** — `.claude/` 以下で管理されています（設定、ステータスラインスクリプト、カスタムスキル）。
- **べき等性のあるインストーラー** — `install.sh` はシンボリックリンクを作成し、内容が異なる既存のファイルは `*.bak` にバックアップし、同一のファイルは削除します。再実行しても安全です。

## Directory structure

```
.dotfiles/
├── .zshenv                   # ZDOTDIR を設定。zsh によって最初にソースされます
├── .config/
│   ├── zsh/
│   │   ├── .zshrc            # conf.d/*.zsh を順番にソースします
│   │   └── conf.d/           # モジュール化された設定フラグメント (NN-name.zsh)
│   ├── git/config            # Git 設定
│   ├── starship.toml         # Starship プロンプト設定
│   ├── mise/config.toml      # mise のグローバルツール + 設定
│   ├── tmux/
│   │   ├── tmux.conf
│   │   ├── tmux-popup.conf
│   │   └── tmux-popup.sh
│   └── vim/vimrc
├── .claude/                  # Claude Code の設定とカスタムスキル
├── .local/bin/               # WSL ヘルパー Peterスクリプト
├── docs/
│   └── Ubuntu-26.04-devcli.user-data  # WSL セットアップ用の cloud-init user-data
├── install.sh
└── uninstall.sh
```

## Requirements

- **zsh**, **git**（必須）
- **starship**, **mise**, **tmux**, **vim**, **fzf**（任意。すべて [docs/Ubuntu-26.04-devcli.user-data](docs/Ubuntu-26.04-devcli.user-data) 内の cloud-init の `packages:` リストによってプロビジョニングされます）

## Install

```sh
git clone --recursive https://github.com/yokarikeri/dotfiles.git ~/.dotfiles
sh ~/.dotfiles/install.sh
```

新しいシェルを開きます。最初の起動時に、不足している zsh プラグインが自動的にクローンされます。

`install.sh` の再実行は安全です。シンボリックリンクを更新し、内容が異なるファイルは `*.bak` にバックアップし、すでに同一であるファイルはスキップします。

## Uninstall

```sh
sh ~/.dotfiles/uninstall.sh
```

このリポジトリ内を指しているシンボリックリンクのみが削除されます。インストール中に作成された `*.bak` バックアップが復元されます。ご自身で作成されたシンボリックリンクはそのまま残ります。

## Usage

### Editing config

`~/.config/*` のすべてのエントリーはリポジトリへのシンボリックリンクであるため、編集はリポジトリに直接反映されます。変更は次のシェル（または zsh 設定の場合は `exec zsh`）で有効になります。

zsh の設定フラグメントを追加するには、`.config/zsh/conf.d/NN-name.zsh` を作成します。数値のプレフィックスで読み込み順序を制御します（例: 補完関連のセットアップには `30-`）。

### Adding a new dotfile

1. リポジトリ内の適切なパスにファイルを追加します。
2. `install.sh` 内にシンボリックリンクを配線します（既存のパターンに従ってください）。
3. `sh install.sh` を再実行します。

### Managing tools with mise

```sh
mise use -g <tool>@<version>   # インストールしてグローバル設定に追加
mise ls                        # インストール済みツールの一覧表示
mise upgrade                   # すべてのツールをアップグレード
```

`.config/mise/config.toml` のグローバル設定には、選択できるツールのカタログがコメントアウトされて含まれており、クイックリファレンスのチートシートも用意されています。

### Syncing across machines

```sh
cd ~/.dotfiles
git pull
sh install.sh   # 新しく追加されたシンボリックリンクを取り込みます
```

### Fresh WSL provisioning

新しい WSL インスタンスを作成する際に、[docs/Ubuntu-26.04-devcli.user-data](docs/Ubuntu-26.04-devcli.user-data) を cloud-init の user-data として渡します。パッケージのインストール、このリポジトリのクローン、および `install.sh` の実行が自動的に行われます。

```sh
wsl --install -d Ubuntu-26.04 --name Ubuntu-26.04-devcli
```

セットアップの全容については、[docs/Ubuntu-26.04-devcli.user-data](docs/Ubuntu-26.04-devcli.user-data) を参照してください。

## Notes

- コミットとコメントの規約は `CLAUDE.md` に記載されています。
