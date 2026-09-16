# dev-environment-vdi

Rebuild a no-admin Windows VDI dev environment from one command. Built for a VDI that resets
each night: portable VS Code, portable git, your settings, keybindings, and extensions, all
recreated from this repo.

## The one-liner (run after each nightly reset)

Needs only PowerShell and internet. No admin, no git, nothing pre-installed.

```powershell
irm https://raw.githubusercontent.com/MariusDinita/dev-environment-vdi/main/bootstrap.ps1 | iex
```

What it does:

1. Downloads this repo.
2. Installs portable VS Code (latest stable x64) to `%USERPROFILE%\dev-tools\code`.
3. Installs portable MinGit and puts it on PATH.
4. Copies `settings.json` and `keybindings.json` into VS Code's user folder (`%APPDATA%\Code\User`).
5. Installs every extension in `extensions.txt`.
6. Creates a Desktop shortcut for VS Code.

If you have a persistent drive that survives the reset, point the tools there so restore skips
the big VS Code re-download:

```powershell
$env:DEVENV_ROOT = 'D:\dev-tools'
irm https://raw.githubusercontent.com/MariusDinita/dev-environment-vdi/main/bootstrap.ps1 | iex
```

## Updating your config (when you change settings or add extensions)

Do this from a local clone, a few times a month, not every night:

```powershell
git clone https://github.com/MariusDinita/dev-environment-vdi
cd dev-environment-vdi
$env:GITHUB_TOKEN = 'ghp_yourtoken'   # PAT with Contents: read+write on this repo
.\export.ps1
```

`export.ps1` reads your live VS Code settings/keybindings/extensions and commits + pushes them
back here. Next nightly restore picks them up automatically.

## Linux dotfiles (`.bashrc`, `.tmux.conf`)

On a fresh Linux box:

```bash
git clone https://github.com/MariusDinita/dev-environment-vdi
bash dev-environment-vdi/linux/restore.sh
```

`linux/restore.sh` backs up any existing `.bashrc`/`.tmux.conf` first, copies the repo's versions
into `~`, then installs the tmux plugins (TPM, tmux-resurrect, tmux-continuum) declared in your
`.tmux.conf`. Needs git + internet for the plugin step; install tmux itself on the box first.

> This repo is public so the Windows one-liner stays passwordless. Keep it that way, and don't
> commit secrets or tokens into any file here.

## Files

- `bootstrap.ps1` — the one-liner entry point.
- `restore.ps1` — does the actual rebuilding.
- `export.ps1` — captures live VS Code config back into this repo.
- `settings.json` — VS Code user settings.
- `keybindings.json` — VS Code keybindings.
- `extensions.txt` — one extension id per line.
- `linux/.bashrc`, `linux/.tmux.conf` — Linux dotfiles, restored by `linux/restore.sh`.

## Notes

- Everything lands under `%USERPROFILE%\dev-tools` (or `$env:DEVENV_ROOT`), so it needs no admin.
- `settings.json` and `keybindings.json` here are placeholders until you run `export.ps1` (or
  drop your real ones in). `extensions.txt` already has your full list.
