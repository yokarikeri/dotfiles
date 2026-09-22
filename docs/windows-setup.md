# Finishing the Windows setup (manual)

After running `windows/setup.ps1`, a few settings still need to be applied by hand.

## Git identity

Open Git Bash (or any shell) and set your name and email:

```sh
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

## VS Code

Install the [Remote Development](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack)
extension pack so VS Code can open files inside WSL.

## Windows Terminal

- Install a Nerd Font with `windows/install-nerd-font.ps1` (`setup.ps1`'s
  next-steps output has the exact command), or use one of your own. The
  script defaults to **JetBrainsMono NL Nerd Font**; run it with `-List` to
  see the full catalogue, which also has Nerd Fonts for Japanese, Korean,
  and Chinese.
- Set the installed (or your own) font in  
  Settings → Profiles → Default → Appearance → Font face.
- Recommended: set the bell notification style to **Flash window** in  
  Settings → Appearance → Bell notification style.
