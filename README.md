# appstrap

Install a curated set of Linux apps on a fresh machine. It detects your
distro and package manager, then installs everything from a JSON manifest —
handling third-party repos (e.g. Brave) and Flatpak apps along the way.

Two interchangeable implementations ship in this repo:

- `src/` — a C++17 CLI, the primary implementation. Build it with the
  bundled `Makefile`/CMake.
- `appstrap.sh` — a self-contained bash port with the manifest embedded.
  Run it straight from the internet, no build needed.

Both expose the same commands and options; keep them in sync when changing
behavior.

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

### From source (C++)

Needs `cmake` and a C++17 compiler (`g++`).

```bash
make build        # cmake configure + build -> build/appstrap
make install      # -> ~/.local/bin/appstrap
                  #    + manifest -> ~/.config/appstrap/packages.json
```

`make run` builds and runs `build/appstrap` (override with `CMD`/`ARGS`,
e.g. `make run CMD=install ARGS="--dry-run"`). `make clean` removes `build/`.

### Single file (bash)

The bash port only needs `bash`. It uses `python3` for manifest parsing when
available and falls back to a built-in pure-bash parser otherwise — so it also
runs on minimal systems and fresh machines where python3 isn't installed yet:

```bash
curl -fsSL https://raw.githubusercontent.com/DaraDavit/appstrap/main/appstrap.sh -o appstrap.sh
chmod +x appstrap.sh
```

## Usage

Run `./appstrap.sh` (or `build/appstrap`) with no command to open the
interactive picker, or use an explicit command:

```bash
appstrap select                # interactive checkbox picker
appstrap detect                # show detected distro + package manager
appstrap list                  # list apps still to install
appstrap list --all            # list every app with install status
appstrap install               # install everything in the manifest
appstrap install git fish      # install only the named apps
appstrap install --dry-run     # print commands without running them
appstrap install -y            # skip the confirmation prompt
appstrap uninstall             # remove everything in the manifest
appstrap uninstall git fish    # remove only the named apps
appstrap update                # upgrade all packages + flatpak apps
appstrap --version             # show version and exit
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
| `--version` | Print the version and exit |
| `-h`, `--help` | Show help |

`install`, `uninstall` and `update` prompt for confirmation unless `-y`
(or `--dry-run`) is given. `uninstall` skips apps that aren't installed;
`update` refreshes the package index and upgrades all packages plus
`flatpak update --user`.

### Manifest resolution

The C++ binary looks for the manifest at `~/.config/appstrap/packages.json`
first, then `packages.json` in the current directory; `--config FILE` always
wins. The bash script uses its embedded manifest, overridden by
`--config FILE`.

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
  `default` key matches any distro with no more specific entry. Matched in
  order: exact distro id, then each `ID_LIKE` token, then `default`.
- `setup` — pre-install shell commands (repo/keys), run with `sudo`. After a
  non-empty `setup`, apt-based systems run `apt-get update` automatically.
- `post` — post-install shell commands (e.g. enable a service or set up
  config). Run after a successful install, regardless of package manager.
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
- `uninstall` removes the installed packages but leaves `setup`-added repos and
  keys in place.