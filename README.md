# appstrap

A single shell script that installs a curated set of Linux apps on a fresh
machine. It detects your distro and package manager, then installs everything
from a JSON manifest — handling third-party repos (e.g. Brave) and Flatpak apps
along the way.

## What it does

- Detects your distro and package manager (`apt`, `dnf`, `pacman`, `zypper`,
  `apk`) from `/etc/os-release`.
- Installs a curated app set from a JSON manifest: dev tools (git, python, g++,
  cmake, node, go, rust, docker, neovim), shell tools (fish, zsh, tmux, fzf,
  ripgrep, eza, bat, kitty), browsers (brave, firefox, chromium), utilities
  (btop, htop, jq, rsync, ncdu, …), media (vlc, mpv, ffmpeg, obs-studio) and
  chat (discord, telegram, slack).
- Handles third-party repos (adds the Brave repo/keys automatically) and
  Flatpak apps (per-user, no sudo).
- Safe and idempotent — skips apps already on your `PATH`, and only re-installs
  with `--force`.
- `--dry-run` to preview commands, an interactive `select` picker, and colored
  output.

## Install

Download the script once and make it executable:

```bash
curl -fsSL https://raw.githubusercontent.com/DaraDavit/appstrap/main/appstrap.sh -o appstrap.sh
chmod +x appstrap.sh
```

It only needs `bash` and `python3` (both preinstalled on virtually every
distro).

## Usage

Run `./appstrap.sh` with no command to open the interactive picker, or use an
explicit command:

```bash
./appstrap.sh select                # interactive checkbox picker
./appstrap.sh detect                # show detected distro + package manager
./appstrap.sh list                  # list apps still to install
./appstrap.sh list --all            # list every app with install status
./appstrap.sh install               # install everything in the manifest
./appstrap.sh install git fish      # install only the named apps
./appstrap.sh install --dry-run     # print commands without running them
./appstrap.sh install -y            # skip the confirmation prompt
```

In the picker: `↑`/`↓` (or `j`/`k`) move · `space` toggles · `a` selects all ·
`c` clears · `enter` confirms · `q` quits.

### Options

| Flag | Description |
| --- | --- |
| `--config FILE` | Path to `packages.json` (overrides the embedded manifest) |
| `--all` | `list` also shows already-installed apps |
| `-y`, `--yes` | Skip the confirmation prompt |
| `--dry-run` | Print commands without running them |
| `--force` | Reinstall even if already detected on `PATH` |
| `--color[=MODE]`, `--no-color` | Color output: `auto` (default), `always`, or `never` |
| `-h`, `--help` | Show help |

## Configuration

The manifest is embedded in the script; `--config FILE` points it at a custom
one. Apps are grouped into `categories` (shown as section headers in `list` and
`select`). Each app is either a package (installed via apt/dnf/pacman) or a
Flatpak app:

```json
{
  "categories": ["Development", "Browsers"],
  "apps": [
    {
      "name": "git",
      "category": "Development",
      "bin": "git",
      "packages": { "default": ["git"] }
    },
    {
      "name": "vscode",
      "category": "Development",
      "flatpak": "com.visualstudio.code"
    }
  ]
}
```

Fields:

- `category` — grouping label (used for ordering and section headers).
- `flatpak` — Flathub app ID. When set, the app installs via
  `flatpak install --user` instead of the package manager (the tool installs
  `flatpak` + the Flathub remote first if needed).
- `packages` — keys are distro families (`debian`, `arch`, `fedora`, …). A
  `default` key matches any distro with no more specific entry.
- `setup` — pre-install shell commands (repo/keys), run with `sudo`. After a
  non-empty `setup`, apt-based systems run `apt-get update` automatically.
- `bin` — executable used to check whether the app is already installed
  (defaults to `name`; ignored for `flatpak` apps).

## Notes

- Run `install` as your normal user; it uses `sudo` automatically for
  privileged commands. Flatpak apps install per-user (no sudo). You'll be
  prompted for the sudo password when needed.
- `setup` commands assume `curl` is present (it ships by default on most
  distros).
- Fedora-specific: `ffmpeg` maps to `ffmpeg-free` (full `ffmpeg` needs RPM
  Fusion); `vlc`/`mpv`/`obs-studio` use Flatpak for the same reason.
- Arch `brave` is not included (AUR package, needs `yay`/`paru`); use the
  Flatpak version instead.
- `starship` is not in Fedora repos — install it via `cargo install starship`
  or the official install script.
- Debian/Ubuntu installs `bat` as the `batcat` binary (name clash with `bat`).
