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

- Set the font to **PlemolJP NF Console** (installed by `setup.ps1`) in  
  Settings → Profiles → Default → Appearance → Font face.
- Recommended: set the bell notification style to **Flash window** in  
  Settings → Appearance → Bell notification style.
