# dotfiles

WSL2 Ubuntu 26.04 zsh 開発環境向けの XDG 準拠の dotfiles です。
[docs/Ubuntu-26.04-devcli.user-data](docs/Ubuntu-26.04-devcli.user-data)（cloud-init プロビジョニング）の対となるものです。

**フォークして自分用にカスタマイズする**ことを前提に設計されています。[運用フロー](#運用フロー) を参照してください。

## Features

- 全体で **XDG Base Directory** レイアウトを採用しています。`.zshenv` で `ZDOTDIR=~/.config/zsh` を設定しており、すべてのツール設定は `~/.config/` 以下に配置されます。
- **モジュール化された zsh 設定** — `conf.d/*.zsh` ファイルは、シェル起動時に数値順にソースされます（キーバインド、オプション、エイリアス、環境変数、パス、補完など）。
- **フレームワーク不使用のプラグイン** — zsh-users プラグイン（`zsh-completions`、`zsh-autosuggestions`、`zsh-syntax-highlighting`、`zsh-history-substring-search`）は、最初のシェル起動時に自動的にクローンされます。
- **Starship プロンプト** — 複数シェル対応の高速プロンプト。`.config/starship.toml` で設定。
- **mise** — ランタイムバージョンマネージャー兼タスクランナー。グローバル設定は `.config/mise/config.toml`。
- **tmux** — 設定は `.config/tmux/tmux.conf`。ポップアップシェルヘルパー（`~/.local/bin/tmux-popup.sh`）を含みます。
- **Vim** — 設定は `.config/vim/vimrc`。
- **WSL ヘルパー**（`.local/bin/`）— `wslview`（Windows でファイル・URL を開く）、`wslvar`（Windows 環境変数を読む）、`claude-clip`（クリップボードブリッジ）。
- **Claude Code 設定** — `.claude/` 以下で管理（設定、ステータスラインスクリプト、カスタムスキル）。
- **コピー方式のインストーラー** — `install.sh` はリポジトリのファイルを `$HOME` にコピーします。実行前に確認を求めます（`-y` でスキップ）。`--clean` でリポジトリから削除されたファイルを除去します。新しく追跡対象になったファイルは次回の `install.sh` 実行時に自動で取り込まれます（手動の配線不要）。

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
├── .local/bin/               # WSL ヘルパースクリプト
├── docs/
│   └── Ubuntu-26.04-devcli.user-data  # WSL セットアップ用の cloud-init user-data
├── lib.sh                    # 共有ヘルパー（以下のスクリプトからソースされます）
├── install.sh                # リポジトリファイルを $HOME へコピー
├── update.sh                 # 最新版をプルして再コピー（ローカル編集を保護）
├── import.sh                 # $HOME の変更をリポジトリへ取り込み
└── uninstall.sh              # リポジトリクローンを削除
```

## Requirements

- **zsh**, **git**（必須）
- **starship**, **mise**, **tmux**, **vim**, **fzf**（任意。すべて [docs/Ubuntu-26.04-devcli.user-data](docs/Ubuntu-26.04-devcli.user-data) の `packages:` リストによってプロビジョニングされます）

## Install

```sh
git clone https://github.com/yokarikeri/dotfiles.git ~/.dotfiles
sh ~/.dotfiles/install.sh
```

コピーされるファイル一覧が表示され、確認を求められます。`-y` を指定すると確認をスキップします（スクリプトや cloud-init での実行に便利）。

```sh
sh ~/.dotfiles/install.sh -y
```

新しいシェルを開きます。最初の起動時に、不足している zsh プラグインが自動的にクローンされます。

`install.sh` の再実行は安全です。管理ファイルを上書きし、古いシンボリックリンクは実ファイルに移行されます。

## Uninstall

```sh
sh ~/.dotfiles/uninstall.sh
```

確認の上で `~/.dotfiles` リポジトリクローンを削除します。`$HOME` にコピー済みの設定ファイルは**削除されません**。環境はそのまま動き続けます。

## Usage

### 設定ファイルの編集

設定ファイルは `$HOME` への実ファイルコピーです。`$HOME` 側で編集してもリポジトリには反映されません。変更をリポジトリへ戻すには `import.sh` を使います。

```sh
# ~/.config/zsh/conf.d/22-aliases.zsh を編集したあと、例として:
sh ~/.dotfiles/import.sh
```

`import.sh` は変更ファイルをリポジトリへコピーし、`git diff` を表示したあと、コミット・プッシュの手順を案内します。自動的にはコミットしません。

### 新しい dotfile を追加する

1. リポジトリ内の `$HOME` 相対パスにファイルを追加して `git add` します。
2. `sh install.sh` を再実行してファイルを `$HOME` にコピーします。

`install.sh` の手動配線は不要です。`.zshenv`、`.config/`、`.claude/`、`.local/bin/` 以下の git 追跡ファイルが自動検出されます。

### mise でのツール管理

```sh
mise use -g <tool>@<version>   # インストールしてグローバル設定に追加
mise ls                        # インストール済みツールの一覧表示
mise upgrade                   # すべてのツールをアップグレード
```

### Fresh WSL provisioning

新しい WSL インスタンスを作成する際に、[docs/Ubuntu-26.04-devcli.user-data](docs/Ubuntu-26.04-devcli.user-data) を cloud-init の user-data として渡します。パッケージのインストール、このリポジトリのクローン、`install.sh -y` の実行が自動的に行われます。

```sh
wsl --install -d Ubuntu-26.04 --name Ubuntu-26.04-devcli
```

## 運用フロー

### フォーク利用（カスタマイズ推奨）

GitHub でこのリポジトリをフォークし、[docs/Ubuntu-26.04-devcli.user-data](docs/Ubuntu-26.04-devcli.user-data)（184 行目）のクローン URL を自分のフォーク URL に書き換えてください。

**初回セットアップ**

```sh
# 自分のフォークをクローン
git clone https://github.com/<あなた>/dotfiles.git ~/.dotfiles

# フォーク元リポジトリを upstream として登録
git -C ~/.dotfiles remote add upstream https://github.com/yokarikeri/dotfiles.git

# $HOME へコピー
sh ~/.dotfiles/install.sh
```

**日常的な使い方**

```sh
# $HOME の設定ファイルを編集したあと、リポジトリへ取り込む:
sh ~/.dotfiles/import.sh
# git diff を確認してコミット・プッシュ:
cd ~/.dotfiles && git add -p && git commit -m "…" && git push
```

**フォーク元の改善を取り込む**

```sh
# フォーク元の最新変更をマージして再コピー:
sh ~/.dotfiles/update.sh --upstream
```

ローカルで編集済みのファイル（「分岐済み」）は上書きされず、差分だけが表示されます。小さな変更は手動で適用し、大きな変更は先に `import.sh` で自分の変更をコミットしてからマージしてください。

**別のマシンへの同期**

```sh
# 別マシンでフォークをクローン・インストール済みの場合:
sh ~/.dotfiles/update.sh   # 自分のフォークの origin からプル
```

### フォークなし利用

自分専用のフォークを管理せず、そのまま使いたい場合。

```sh
git clone https://github.com/yokarikeri/dotfiles.git ~/.dotfiles
sh ~/.dotfiles/install.sh
```

**アップデート**

```sh
sh ~/.dotfiles/update.sh
```

ローカルで編集したファイルは上書きされず、差分が表示されます。必要な変更は手動で適用してください。

## Notes

- コミットとコメントの規約は `CLAUDE.md` に記載されています。
