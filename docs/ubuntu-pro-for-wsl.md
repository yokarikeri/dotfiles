# Ubuntu Pro for WSL (optional, manual)

> Announced: [Canonical announces Ubuntu Pro for WSL](https://ubuntu.com/blog/ubuntu-pro-for-wsl) (March 5, 2026)

[Ubuntu Pro](https://ubuntu.com/pricing/pro) is free for personal use on up to 5 machines.
It adds Expanded Security Maintenance (ESM), which extends the scope of security updates beyond
the default `Main` component — for example, `Universe` packages receive security fixes via
`esm-apps`.

It is straightforward to enable and costs nothing, so it is worth doing.

## Steps

### 1. Create an Ubuntu One account

Go to <https://login.ubuntu.com/> and register.

### 2. Subscribe to Ubuntu Pro

Go to <https://ubuntu.com/pro/subscribe> and subscribe.
An **Ubuntu Pro token** will be issued — keep it handy.

### 3. Install Ubuntu Pro for WSL

```powershell
# Verify the package is available
PS C:\> winget search "Ubuntu Pro"
Name               ID                        Version Source
----------------------------------------------------------------
Ubuntu Pro for WSL 9PD1WZNBDXKZ              Unknown msstore
Ubuntu Pro for WSL Canonical.UbuntuProforWSL 1.0.6   winget

# Install from the Microsoft Store (auto-updates by default)
PS C:\> winget install --id 9PD1WZNBDXKZ

# Launch Ubuntu Pro for WSL
PS C:\> Get-StartApps | ? Name -match "Ubuntu Pro for WSL" | % { Start-Process "shell:AppsFolder\$($_.AppID)" }
```

### 4. Enter the token

Enter your Ubuntu Pro token in the application.
When prompted to register with Landscape (an instance management tool), select **Skip for now**.

A success message confirms activation:

```plaintext
Ubuntu Pro is enabled on this machine

All Ubuntu WSL instances have access to Ubuntu Pro security features.
```

The token is stored in the registry at `HKEY_CURRENT_USER\Software\Canonical\UbuntuPro`:

```powershell
PS C:\> Get-ItemProperty -Path "HKCU:\Software\Canonical\UbuntuPro"
```

## Verifying inside WSL

Any Ubuntu on WSL instance will have Ubuntu Pro activated automatically via `wsl-pro.service`.

```sh
# Check subscription status
pro status
# SERVICE          ENTITLED  STATUS       DESCRIPTION
# esm-apps         yes       enabled      Expanded Security Maintenance for Applications
# esm-infra        yes       enabled      Expanded Security Maintenance for Infrastructure
# landscape        yes       disabled     Management and administration tool for Ubuntu

# Apply ESM-provided security fixes
sudo apt upgrade -Uy
```
