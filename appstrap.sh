#!/usr/bin/env bash
# appstrap.sh — self-contained shell port of the appstrap CLI.
# Run directly:  bash <(curl -fsSL <raw-url>) <command>
set -u

US=$'\x1f'
IS=$'\x1e'

RESET=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'

# Keep in sync with project(VERSION ...) in CMakeLists.txt.
VERSION="0.1.0"

GLYPH_OK='✓'
GLYPH_FAIL='✗'
GLYPH_MISS='·'

COLOR=auto
DRY_RUN=0
FORCE=0
YES=0
ALL=0
CONFIG=""
MANIFEST_LABEL="embedded"
FLATPAK_READY=0
APT_UPDATED=0

ID=""
ID_LIKE=""
PRETTY_NAME=""
PM=""

read -r -d '' MANIFEST_JSON <<'JSONEOF' || true
{
  "categories": [
    "Development",
    "Shell & Terminal",
    "Browsers",
    "System & Utilities",
    "Media",
    "Communication"
  ],
  "apps": [
    {
      "name": "git",
      "category": "Development",
      "packages": { "default": ["git"] }
    },
    {
      "name": "python",
      "category": "Development",
      "bin": "python3",
      "packages": {
        "debian": ["python3", "python3-pip", "python3-venv"],
        "fedora": ["python3", "python3-pip"],
        "arch": ["python", "python-pip"]
      }
    },
    {
      "name": "c++",
      "category": "Development",
      "bin": "g++",
      "packages": {
        "debian": ["build-essential"],
        "fedora": ["gcc-c++"],
        "arch": ["base-devel"]
      }
    },
    {
      "name": "cmake",
      "category": "Development",
      "packages": { "default": ["cmake"] }
    },
    {
      "name": "make",
      "category": "Development",
      "packages": { "default": ["make"] }
    },
    {
      "name": "nodejs",
      "category": "Development",
      "packages": { "default": ["nodejs", "npm"] }
    },
    {
      "name": "neovim",
      "category": "Development",
      "packages": { "default": ["neovim"] }
    },
    {
      "name": "go",
      "category": "Development",
      "packages": {
        "debian": ["golang-go"],
        "fedora": ["golang"],
        "arch": ["go"]
      }
    },
    {
      "name": "rust",
      "category": "Development",
      "packages": {
        "debian": ["rustc", "cargo"],
        "fedora": ["rust", "cargo"],
        "arch": ["rust"]
      }
    },
    {
      "name": "docker",
      "category": "Development",
      "packages": {
        "debian": ["docker.io"],
        "fedora": ["moby-engine", "docker-cli"],
        "arch": ["docker"]
      }
    },
    {
      "name": "vscode",
      "category": "Development",
      "flatpak": "com.visualstudio.code"
    },
    {
      "name": "fish",
      "category": "Shell & Terminal",
      "packages": { "default": ["fish"] }
    },
    {
      "name": "kitty",
      "category": "Shell & Terminal",
      "packages": { "default": ["kitty"] }
    },
    {
      "name": "zsh",
      "category": "Shell & Terminal",
      "packages": { "default": ["zsh"] }
    },
    {
      "name": "tmux",
      "category": "Shell & Terminal",
      "packages": { "default": ["tmux"] }
    },
    {
      "name": "fzf",
      "category": "Shell & Terminal",
      "packages": { "default": ["fzf"] }
    },
    {
      "name": "ripgrep",
      "category": "Shell & Terminal",
      "packages": { "default": ["ripgrep"] }
    },
    {
      "name": "eza",
      "category": "Shell & Terminal",
      "packages": { "default": ["eza"] }
    },
    {
      "name": "zoxide",
      "category": "Shell & Terminal",
      "packages": { "default": ["zoxide"] }
    },
    {
      "name": "bat",
      "category": "Shell & Terminal",
      "packages": { "default": ["bat"] }
    },
    {
      "name": "brave",
      "category": "Browsers",
      "bin": "brave-browser",
      "packages": {
        "debian": ["brave-browser"],
        "fedora": ["brave-browser"]
      },
      "setup": {
        "debian": [
          "curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg",
          "echo \"deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main\" > /etc/apt/sources.list.d/brave-browser-release.list"
        ],
        "fedora": [
          "curl -fsSLo /etc/yum.repos.d/brave-browser.repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo",
          "rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc"
        ]
      }
    },
    {
      "name": "firefox",
      "category": "Browsers",
      "packages": { "default": ["firefox"] }
    },
    {
      "name": "chromium",
      "category": "Browsers",
      "flatpak": "org.chromium.Chromium"
    },
    {
      "name": "btop",
      "category": "System & Utilities",
      "packages": { "default": ["btop"] }
    },
    {
      "name": "htop",
      "category": "System & Utilities",
      "packages": { "default": ["htop"] }
    },
    {
      "name": "fastfetch",
      "category": "System & Utilities",
      "packages": { "default": ["fastfetch"] }
    },
    {
      "name": "curl",
      "category": "System & Utilities",
      "packages": { "default": ["curl"] }
    },
    {
      "name": "wget",
      "category": "System & Utilities",
      "packages": { "default": ["wget"] }
    },
    {
      "name": "jq",
      "category": "System & Utilities",
      "packages": { "default": ["jq"] }
    },
    {
      "name": "rsync",
      "category": "System & Utilities",
      "packages": { "default": ["rsync"] }
    },
    {
      "name": "tree",
      "category": "System & Utilities",
      "packages": { "default": ["tree"] }
    },
    {
      "name": "ncdu",
      "category": "System & Utilities",
      "packages": { "default": ["ncdu"] }
    },
    {
      "name": "unzip",
      "category": "System & Utilities",
      "packages": { "default": ["unzip"] }
    },
    {
      "name": "gnupg",
      "category": "System & Utilities",
      "packages": { "default": ["gnupg"] }
    },
    {
      "name": "vlc",
      "category": "Media",
      "flatpak": "org.videolan.VLC"
    },
    {
      "name": "mpv",
      "category": "Media",
      "flatpak": "io.mpv.Mpv"
    },
    {
      "name": "ffmpeg",
      "category": "Media",
      "packages": {
        "debian": ["ffmpeg"],
        "fedora": ["ffmpeg-free"],
        "arch": ["ffmpeg"]
      }
    },
    {
      "name": "obs-studio",
      "category": "Media",
      "flatpak": "com.obsproject.Studio"
    },
    {
      "name": "discord",
      "category": "Communication",
      "flatpak": "com.discordapp.Discord"
    },
    {
      "name": "telegram",
      "category": "Communication",
      "flatpak": "org.telegram.desktop"
    },
    {
      "name": "slack",
      "category": "Communication",
      "flatpak": "com.slack.Slack"
    }
  ]
}
JSONEOF

read -r -d '' PY_SCRIPT <<'PYEOF' || true
import json, sys

def resolve_family(m, ident, id_like):
    if not m:
        return ""
    if ident in m:
        return ident
    for tok in id_like.split():
        if tok in m:
            return tok
    if "default" in m:
        return "default"
    return ""

args = sys.argv[1:]
path = args[0] if len(args) > 0 else ""
ident = args[1] if len(args) > 1 else ""
id_like = args[2] if len(args) > 2 else ""

if path:
    with open(path) as f:
        root = json.load(f)
else:
    root = json.load(sys.stdin)

cats = root.get("categories", [])
sys.stdout.write("\x1f".join(cats) + "\n")
for app in root.get("apps", []):
    name = app.get("name", "")
    if not name:
        continue
    bin_ = app.get("bin", name)
    cat = app.get("category", "")
    flat = app.get("flatpak", "")
    packages = app.get("packages", {})
    setup = app.get("setup", {})
    post = app.get("post", [])
    fam = resolve_family(packages, ident, id_like)
    pkgs = packages.get(fam, []) if fam else []
    sfam = resolve_family(setup, ident, id_like)
    scmds = setup.get(sfam, []) if sfam else []
    print("\x1f".join([name, bin_, cat, flat,
                       "\x1e".join(pkgs), "\x1e".join(scmds), "\x1e".join(post), "END"]))
PYEOF

# ---- pure-bash manifest parser (fallback when python3 is unavailable) ------
# Parses the manifest subset: objects, arrays of strings, strings (with
# escapes). Emits the same delimiter-separated stream as the python3 parser.

JBUF=""
JPOS=0
JSTR=""
APP_LINE=""
ARR_RESULT=()
MAP_KEYS=()
MAP_VALS=()
FAM_RESULT=""

json_skip_ws() {
    local c
    while [ "$JPOS" -lt "${#JBUF}" ]; do
        c="${JBUF:$JPOS:1}"
        case "$c" in
            ' '|$'\t'|$'\n'|$'\r') JPOS=$((JPOS+1)) ;;
            *) return 0 ;;
        esac
    done
}

json_expect() {
    local ch="$1"
    json_skip_ws
    [ "${JBUF:$JPOS:1}" = "$ch" ] || return 1
    JPOS=$((JPOS+1))
}

# Reads a JSON string at the current position into JSTR.
json_string() {
    json_skip_ws
    [ "${JBUF:$JPOS:1}" = '"' ] || return 1
    JPOS=$((JPOS+1))
    JSTR=""
    local c
    while [ "$JPOS" -lt "${#JBUF}" ]; do
        c="${JBUF:$JPOS:1}"
        case "$c" in
            '"') JPOS=$((JPOS+1)); return 0 ;;
            '\')
                JPOS=$((JPOS+1))
                c="${JBUF:$JPOS:1}"
                case "$c" in
                    '"') JSTR+='"'; JPOS=$((JPOS+1)) ;;
                    '\') JSTR+='\'; JPOS=$((JPOS+1)) ;;
                    '/') JSTR+='/'; JPOS=$((JPOS+1)) ;;
                    'b') JSTR+=$'\b'; JPOS=$((JPOS+1)) ;;
                    'f') JSTR+=$'\f'; JPOS=$((JPOS+1)) ;;
                    'n') JSTR+=$'\n'; JPOS=$((JPOS+1)) ;;
                    'r') JSTR+=$'\r'; JPOS=$((JPOS+1)) ;;
                    't') JSTR+=$'\t'; JPOS=$((JPOS+1)) ;;
                    'u') JPOS=$((JPOS+5)); JSTR+='?' ;;
                    *) return 1 ;;
                esac
                ;;
            *) JSTR+="$c"; JPOS=$((JPOS+1)) ;;
        esac
    done
    return 1
}

# Skips a primitive value (number, true/false/null) up to a delimiter.
json_skip_primitive() {
    local c
    while [ "$JPOS" -lt "${#JBUF}" ]; do
        c="${JBUF:$JPOS:1}"
        case "$c" in
            ','|'}'|']'|' '|$'\t'|$'\n'|$'\r') return 0 ;;
            *) JPOS=$((JPOS+1)) ;;
        esac
    done
}

json_skip_value() {
    json_skip_ws
    local c="${JBUF:$JPOS:1}"
    case "$c" in
        '"') json_string ;;
        '{') json_skip_object ;;
        '[') json_skip_array ;;
        *) json_skip_primitive ;;
    esac
}

json_skip_object() {
    json_expect '{' || return 1
    json_skip_ws
    if [ "${JBUF:$JPOS:1}" = '}' ]; then JPOS=$((JPOS+1)); return 0; fi
    while :; do
        json_string || return 1
        json_expect ':' || return 1
        json_skip_value || return 1
        json_skip_ws
        case "${JBUF:$JPOS:1}" in
            ',') JPOS=$((JPOS+1)) ;;
            '}') JPOS=$((JPOS+1)); return 0 ;;
            *) return 1 ;;
        esac
    done
}

json_skip_array() {
    json_expect '[' || return 1
    json_skip_ws
    if [ "${JBUF:$JPOS:1}" = ']' ]; then JPOS=$((JPOS+1)); return 0; fi
    while :; do
        json_skip_value || return 1
        json_skip_ws
        case "${JBUF:$JPOS:1}" in
            ',') JPOS=$((JPOS+1)) ;;
            ']') JPOS=$((JPOS+1)); return 0 ;;
            *) return 1 ;;
        esac
    done
}

# Parses `[ "a", "b" ]` into ARR_RESULT.
json_parse_string_array() {
    ARR_RESULT=()
    json_expect '[' || return 1
    json_skip_ws
    if [ "${JBUF:$JPOS:1}" = ']' ]; then JPOS=$((JPOS+1)); return 0; fi
    while :; do
        json_string || return 1
        ARR_RESULT+=("$JSTR")
        json_skip_ws
        case "${JBUF:$JPOS:1}" in
            ',') JPOS=$((JPOS+1)) ;;
            ']') JPOS=$((JPOS+1)); return 0 ;;
            *) return 1 ;;
        esac
    done
}

# Parses `{ "key": [ ... ], ... }` into parallel MAP_KEYS / MAP_VALS
# (MAP_VALS entries are \x1e-joined lists).
json_parse_string_map() {
    MAP_KEYS=(); MAP_VALS=()
    json_expect '{' || return 1
    json_skip_ws
    if [ "${JBUF:$JPOS:1}" = '}' ]; then JPOS=$((JPOS+1)); return 0; fi
    while :; do
        json_string || return 1
        local k="$JSTR"
        json_expect ':' || return 1
        json_parse_string_array || return 1
        MAP_KEYS+=("$k")
        MAP_VALS+=("$(IFS="$IS"; echo "${ARR_RESULT[*]}")")
        json_skip_ws
        case "${JBUF:$JPOS:1}" in
            ',') JPOS=$((JPOS+1)) ;;
            '}') JPOS=$((JPOS+1)); return 0 ;;
            *) return 1 ;;
        esac
    done
}

# Resolves the family key for the parsed map: exact ID, then ID_LIKE tokens,
# then "default" (mirrors the python3 resolve_family).
json_resolve_family() {
    FAM_RESULT=""
    local i tok
    for ((i=0;i<${#MAP_KEYS[@]};i++)); do
        [ "${MAP_KEYS[$i]}" = "$ID" ] && { FAM_RESULT="$ID"; return 0; }
    done
    for tok in $ID_LIKE; do
        for ((i=0;i<${#MAP_KEYS[@]};i++)); do
            [ "${MAP_KEYS[$i]}" = "$tok" ] && { FAM_RESULT="$tok"; return 0; }
        done
    done
    for ((i=0;i<${#MAP_KEYS[@]};i++)); do
        [ "${MAP_KEYS[$i]}" = "default" ] && { FAM_RESULT="default"; return 0; }
    done
    return 0
}

# Prints the \x1e-joined items for the currently resolved family ("" if none).
json_family_items() {
    local i
    for ((i=0;i<${#MAP_KEYS[@]};i++)); do
        [ "${MAP_KEYS[$i]}" = "$FAM_RESULT" ] && { printf '%s' "${MAP_VALS[$i]}"; return 0; }
    done
    return 0
}

# Parses one app object; emits its record into APP_LINE ("" for nameless apps).
json_parse_app() {
    json_expect '{' || return 1
    local name="" bin="" cat="" flat="" pkgs="" scmds="" post=""
    json_skip_ws
    if [ "${JBUF:$JPOS:1}" = '}' ]; then JPOS=$((JPOS+1)); APP_LINE=""; return 0; fi
    while :; do
        json_string || return 1
        local key="$JSTR"
        json_expect ':' || return 1
        case "$key" in
            name) json_string || return 1; name="$JSTR" ;;
            bin) json_string || return 1; bin="$JSTR" ;;
            category) json_string || return 1; cat="$JSTR" ;;
            flatpak) json_string || return 1; flat="$JSTR" ;;
            packages)
                json_parse_string_map || return 1
                json_resolve_family
                pkgs="$(json_family_items)" ;;
            setup)
                json_parse_string_map || return 1
                json_resolve_family
                scmds="$(json_family_items)" ;;
            post)
                json_parse_string_array || return 1
                post="$(IFS="$IS"; echo "${ARR_RESULT[*]}")" ;;
            *)
                json_skip_value || return 1 ;;
        esac
        json_skip_ws
        case "${JBUF:$JPOS:1}" in
            ',') JPOS=$((JPOS+1)) ;;
            '}') JPOS=$((JPOS+1)); break ;;
            *) return 1 ;;
        esac
    done
    if [ -z "$name" ]; then APP_LINE=""; return 0; fi
    [ -n "$bin" ] || bin="$name"
    printf -v APP_LINE '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1fEND' \
        "$name" "$bin" "$cat" "$flat" "$pkgs" "$scmds" "$post"
    return 0
}

# Parses the top-level manifest; prints the categories line first, then one
# line per app (mirrors the python3 emit order regardless of key order).
json_parse_top() {
    json_expect '{' || return 1
    local cats=""
    local app_lines=()
    json_skip_ws
    if [ "${JBUF:$JPOS:1}" = '}' ]; then JPOS=$((JPOS+1)); printf '\n'; return 0; fi
    while :; do
        json_string || return 1
        local key="$JSTR"
        json_expect ':' || return 1
        case "$key" in
            categories)
                json_parse_string_array || return 1
                cats="$(IFS="$US"; echo "${ARR_RESULT[*]}")" ;;
            apps)
                json_expect '[' || return 1
                json_skip_ws
                if [ "${JBUF:$JPOS:1}" = ']' ]; then
                    JPOS=$((JPOS+1))
                else
                    while :; do
                        json_parse_app || return 1
                        [ -n "$APP_LINE" ] && app_lines+=("$APP_LINE")
                        json_skip_ws
                        case "${JBUF:$JPOS:1}" in
                            ',') JPOS=$((JPOS+1)) ;;
                            ']') JPOS=$((JPOS+1)); break ;;
                            *) return 1 ;;
                        esac
                    done
                fi ;;
            *)
                json_skip_value || return 1 ;;
        esac
        json_skip_ws
        case "${JBUF:$JPOS:1}" in
            ',') JPOS=$((JPOS+1)) ;;
            '}') JPOS=$((JPOS+1)); break ;;
            *) return 1 ;;
        esac
    done
    printf '%s\n' "$cats"
    local i
    for ((i=0;i<${#app_lines[@]};i++)); do printf '%s\n' "${app_lines[$i]}"; done
    return 0
}

emit_manifest_bash() {
    local json_file="$1"
    if [ -n "$json_file" ]; then
        JBUF="$(< "$json_file")" || return 1
    else
        JBUF="$MANIFEST_JSON"
    fi
    JPOS=0
    json_parse_top
}

# ---- color helpers ---------------------------------------------------------

color_enabled() {
    case "$COLOR" in
        always) return 0 ;;
        never) return 1 ;;
    esac
    [ -z "${NO_COLOR:-}" ] && [ -t 1 ]
}

paint() {
    local code="$1"; shift
    local text="$*"
    if color_enabled; then printf '%s%s%s' "$code" "$text" "$RESET"; else printf '%s' "$text"; fi
}

green()  { paint "$GREEN" "$@"; }
red()    { paint "$RED" "$@"; }
yellow() { paint "$YELLOW" "$@"; }
bold()   { paint "$BOLD" "$@"; }
dim()    { paint "$DIM" "$@"; }

# ---- output helpers --------------------------------------------------------

print_section() { clear_progress; printf '== %s ==\n' "$*"; }
print_line()    { clear_progress; printf '  %s\n' "$*"; }
print_dry_run() {
    clear_progress
    local cmd="$1"; local use_sudo="${2:-0}"
    if [ "$use_sudo" = 1 ]; then printf '  [dry-run] sudo %s\n' "$cmd"
    else printf '  [dry-run] %s\n' "$cmd"; fi
}
print_warning() { clear_progress; printf '  %s %s\n' "$(yellow "warning:")" "$*"; }
print_error()   { clear_progress; printf '  %s %s\n' "$(red "error:")" "$*"; }

print_result() {
    clear_progress
    local name="$1" status="$2"
    case "$status" in
        1) printf '  %s %s\n' "$(paint "$GREEN" "$GLYPH_OK")" "$name" ;;
        0) printf '  %s %s %s\n' "$(paint "$DIM" "$GLYPH_OK")" "$name" "$(dim "(already installed)")" ;;
        2) printf '  %s %s\n' "$(paint "$RED" "$GLYPH_FAIL")" "$name" ;;
    esac
}

print_summary() {
    local total="$1" inst="$2" already="$3" failed="$4"
    printf '%s apps · %s' "$total" "$(paint "$GREEN" "$inst installed")"
    [ "$already" -gt 0 ] && printf ' · %s' "$(paint "$DIM" "$already already installed")"
    [ "$failed" -gt 0 ] && printf ' · %s' "$(paint "$RED" "$failed failed")"
    printf '\n'
}

print_remove_result() {
    clear_progress
    local name="$1" status="$2"
    case "$status" in
        1) printf '  %s %s\n' "$(paint "$GREEN" "$GLYPH_OK")" "$name" ;;
        0) printf '  %s %s %s\n' "$(paint "$DIM" "$GLYPH_MISS")" "$name" "$(dim "(not installed)")" ;;
        2) printf '  %s %s\n' "$(paint "$RED" "$GLYPH_FAIL")" "$name" ;;
    esac
}

print_summary_remove() {
    local total="$1" removed="$2" skipped="$3" failed="$4"
    printf '%s apps · %s' "$total" "$(paint "$GREEN" "$removed removed")"
    [ "$skipped" -gt 0 ] && printf ' · %s' "$(paint "$DIM" "$skipped not installed")"
    [ "$failed" -gt 0 ] && printf ' · %s' "$(paint "$RED" "$failed failed")"
    printf '\n'
}

print_update_result() {
    clear_progress
    local status="$1"
    case "$status" in
        1) printf '  %s %s\n' "$(paint "$GREEN" "$GLYPH_OK")" "update complete" ;;
        2) printf '  %s %s\n' "$(paint "$RED" "$GLYPH_FAIL")" "update failed" ;;
    esac
}

print_manifest() {
    printf '%s\n' "$(dim "manifest: $MANIFEST_LABEL ($PM)")"
}

# ---- install progress spinner (TTY only) ------------------------------------

SPIN_PID=""

# Stops the spinner and erases its line, if one is pending. Every printer that
# starts a new line calls this first so captured output never glues onto the
# progress line.
clear_progress() {
    [ -z "$SPIN_PID" ] && return 0
    kill "$SPIN_PID" 2>/dev/null
    wait "$SPIN_PID" 2>/dev/null
    SPIN_PID=""
    printf '\r\x1b[2K'
}

spinner_start() {
    local name="$1" idx="$2" total="$3"
    printf '  [%d/%d] installing %s ' "$idx" "$total" "$name"
    (
        local c
        while :; do
            for c in '|' '/' '-' '\'; do
                printf '\b%s' "$c"
                sleep 0.1
            done
        done
    ) &
    SPIN_PID=$!
}

usage() {
    local prog="${0##*/}"
    cat <<EOF
appstrap — install a curated set of Linux apps

usage:
  $prog detect                        show detected distro + package manager
  $prog list [--all] [options]        list apps and install status
  $prog install [apps...] [options]   install all, or only named apps
  $prog uninstall [apps...] [options] remove all, or only named apps
  $prog update [options]              upgrade installed apps
  $prog select [options]              interactively pick apps to install

options:
  --config FILE   path to packages.json (overrides the embedded manifest)
  --all           list also shows already-installed apps
  -y, --yes       skip confirmation prompt
  --dry-run       print commands without running them
  --force         reinstall even if already detected on PATH
  --color[=MODE]  color output (auto|always|never), or --no-color
  --version       show version and exit
  -h, --help      show this help
EOF
}

# ---- distro / manifest -----------------------------------------------------

has_word() { case " $1 " in *" $2 "*) return 0 ;; *) return 1 ;; esac; }

detect_distro() {
    ID=""; ID_LIKE=""; PRETTY_NAME=""; PM=""
    if [ -r /etc/os-release ]; then
        local key val
        while IFS='=' read -r key val; do
            val="${val%\"}"; val="${val#\"}"
            case "$key" in
                ID) ID="$val" ;;
                ID_LIKE) ID_LIKE="$val" ;;
                PRETTY_NAME) PRETTY_NAME="$val" ;;
            esac
        done < /etc/os-release
    fi
    local family="$ID $ID_LIKE"
    if has_word "$family" debian || has_word "$family" ubuntu; then PM=apt
    elif has_word "$family" arch || has_word "$family" manjaro; then PM=pacman
    elif has_word "$family" fedora || has_word "$family" rhel || has_word "$family" centos; then PM=dnf
    elif has_word "$family" suse || has_word "$family" opensuse; then PM=zypper
    elif has_word "$family" alpine; then PM=apk
    fi
}

emit_manifest() {
    local json_file="$1" out
    if command -v python3 >/dev/null 2>&1; then
        if [ -n "$json_file" ]; then
            out=$(python3 -c "$PY_SCRIPT" "$json_file" "$ID" "$ID_LIKE") \
                && { printf '%s\n' "$out"; return; }
        else
            out=$(printf '%s' "$MANIFEST_JSON" | python3 -c "$PY_SCRIPT" "" "$ID" "$ID_LIKE") \
                && { printf '%s\n' "$out"; return; }
        fi
    fi
    emit_manifest_bash "$json_file"
}

load_manifest() {
    local json_file="$1"
    APP_NAMES=(); APP_BINS=(); APP_CATS=(); APP_FLATPAKS=(); APP_PKGS=(); APP_SETUPS=(); APP_POSTS=()
    CATEGORIES=()
    local line_no=0 line
    while IFS= read -r line; do
        if [ "$line_no" = 0 ]; then
            [ -n "$line" ] && IFS="$US" read -ra CATEGORIES <<< "$line"
        else
            local name bin_ cat flat pkgs setup post
            IFS="$US" read -r name bin_ cat flat pkgs setup post _ <<< "$line"
            APP_NAMES+=("$name")
            APP_BINS+=("$bin_")
            APP_CATS+=("$cat")
            APP_FLATPAKS+=("$flat")
            APP_PKGS+=("$pkgs")
            APP_SETUPS+=("$setup")
            APP_POSTS+=("$post")
        fi
        line_no=$((line_no+1))
    done < <(emit_manifest "$json_file")
}

install_command() {
    local args="$*"
    case "$PM" in
        apt) echo "apt-get install -y $args" ;;
        dnf) echo "dnf install -y $args" ;;
        pacman) echo "pacman -S --noconfirm --needed $args" ;;
        zypper) echo "zypper --non-interactive install $args" ;;
        apk) echo "apk add $args" ;;
        *) echo "" ;;
    esac
}

remove_command() {
    local args="$*"
    case "$PM" in
        apt) echo "apt-get remove -y $args" ;;
        dnf) echo "dnf remove -y $args" ;;
        pacman) echo "pacman -R --noconfirm $args" ;;
        zypper) echo "zypper --non-interactive remove $args" ;;
        apk) echo "apk del $args" ;;
        *) echo "" ;;
    esac
}

update_command() {
    case "$PM" in
        apt) echo "apt-get upgrade -y" ;;
        dnf) echo "dnf upgrade -y" ;;
        pacman) echo "pacman -Syu --noconfirm" ;;
        zypper) echo "zypper --non-interactive update" ;;
        apk) echo "apk upgrade" ;;
        *) echo "" ;;
    esac
}

is_installed() {
    local flat="$1" bin="$2"
    if [ -n "$flat" ]; then
        flatpak info --user "$flat" >/dev/null 2>&1
    else
        command -v "$bin" >/dev/null 2>&1
    fi
}

app_source() {
    local i="$1"
    [ -n "${APP_FLATPAKS[$i]}" ] && { echo flatpak; return; }
    [ -z "${APP_PKGS[$i]}" ] && { echo "-"; return; }
    [ -z "$PM" ] && { echo "-"; return; }
    echo "$PM"
}

run_captured() {
    local cmd="$1" use_sudo="${2:-0}"
    if [ "$use_sudo" = 1 ] && [ "$(id -u)" != 0 ]; then
        LAST_OUT=$(sudo sh -c "$cmd" 2>&1)
    else
        LAST_OUT=$(sh -c "$cmd" 2>&1)
    fi
    LAST_RC=$?
}

refresh_index() {
    [ "$PM" = apt ] || return 0
    [ "$APT_UPDATED" = 1 ] && return 0
    if [ "$DRY_RUN" = 1 ]; then
        print_dry_run "apt-get update"
        APT_UPDATED=1
        return 0
    fi
    run_captured "apt-get update" 1
    [ "$LAST_RC" != 0 ] && print_warning "apt-get update failed"
    APT_UPDATED=1
}

ensure_flatpak() {
    [ "$FLATPAK_READY" = 1 ] && return 0
    local add_remote="flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
    if command -v flatpak >/dev/null 2>&1; then
        FLATPAK_READY=1
        if [ "$DRY_RUN" = 1 ]; then
            print_dry_run "$add_remote"
            return 0
        fi
        flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 \
            || print_warning "could not add flathub remote"
        return 0
    fi
    local cmd; cmd=$(install_command flatpak)
    if [ -z "$cmd" ]; then
        print_error "cannot install flatpak (unsupported package manager)"
        return 1
    fi
    if [ "$DRY_RUN" = 1 ]; then
        print_dry_run "$cmd" 1
        print_dry_run "$add_remote"
        FLATPAK_READY=1
        return 0
    fi
    refresh_index
    run_captured "$cmd" 1
    if [ "$LAST_RC" != 0 ]; then
        print_error "failed to install flatpak:"
        printf '%s' "$LAST_OUT"
        return 1
    fi
    flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 \
        || print_warning "could not add flathub remote"
    FLATPAK_READY=1
    return 0
}

run_post() {
    local i="$1"
    local post="${APP_POSTS[$i]}"
    [ -z "$post" ] && return 0
    local arr=()
    IFS="$IS" read -ra arr <<< "$post"
    local p
    for p in "${arr[@]}"; do
        if [ "$DRY_RUN" = 1 ]; then print_dry_run "$p"; continue; fi
        run_captured "$p" 1
        [ "$LAST_RC" != 0 ] && print_warning "post command failed"
    done
}

install_app() {
    local i="$1"
    local name="${APP_NAMES[$i]}" flat="${APP_FLATPAKS[$i]}" bin="${APP_BINS[$i]}"

    [ "$DRY_RUN" = 1 ] && print_section "$name"

    if is_installed "$flat" "$bin" && [ "$FORCE" != 1 ]; then
        if [ "$DRY_RUN" = 1 ]; then
            if [ -n "$flat" ]; then print_line "already installed (flatpak $flat)"
            else print_line "already installed ($bin)"; fi
        fi
        return 0
    fi

    if [ -n "$flat" ]; then
        ensure_flatpak || return 2
        local cmd="flatpak install -y --user flathub $flat"
        if [ "$DRY_RUN" = 1 ]; then
            print_dry_run "$cmd"
        else
            run_captured "$cmd" 0
            if [ "$LAST_RC" != 0 ]; then
                print_error "flatpak install failed:"
                printf '%s' "$LAST_OUT"
                return 2
            fi
        fi
        run_post "$i"
        return 1
    fi

    local pkgs="${APP_PKGS[$i]}" setup="${APP_SETUPS[$i]}"
    local pkg_arr=() setup_arr=()
    [ -n "$pkgs" ] && IFS="$IS" read -ra pkg_arr <<< "$pkgs"
    [ -n "$setup" ] && IFS="$IS" read -ra setup_arr <<< "$setup"

    local ran_setup=0 c
    for c in "${setup_arr[@]}"; do
        if [ "$DRY_RUN" = 1 ]; then
            print_dry_run "$c" 1
            ran_setup=1
            continue
        fi
        run_captured "$c" 1
        if [ "$LAST_RC" != 0 ]; then
            print_error "setup command failed:"
            printf '%s' "$LAST_OUT"
            return 2
        fi
        ran_setup=1
    done

    [ $ran_setup = 1 ] && refresh_index

    if [ -z "$pkgs" ]; then
        print_line "no packages mapped for this distro ($PM)"
        return 2
    fi

    local cmd; cmd=$(install_command "${pkg_arr[@]}")
    if [ -z "$cmd" ]; then
        print_error "unsupported package manager"
        return 2
    fi

    refresh_index

    if [ "$DRY_RUN" = 1 ]; then
        print_dry_run "$cmd" 1
    else
        run_captured "$cmd" 1
        if [ "$LAST_RC" != 0 ]; then
            print_error "install failed:"
            printf '%s' "$LAST_OUT"
            return 2
        fi
    fi

    run_post "$i"
    return 1
}

# ---- commands --------------------------------------------------------------

category_order() {
    ORDER=()
    local c i o found
    for c in "${CATEGORIES[@]}"; do ORDER+=("$c"); done
    local n=${#APP_NAMES[@]}
    for ((i=0;i<n;i++)); do
        c="${APP_CATS[$i]}"
        found=0
        for o in "${ORDER[@]}"; do [ "$o" = "$c" ] && { found=1; break; }; done
        [ $found = 0 ] && ORDER+=("$c")
    done
}

cmd_detect() {
    printf '%s %s\n' "$(bold "distro:         ")" "$PRETTY_NAME"
    printf '%s %s\n' "$(bold "id:             ")" "$ID"
    printf '%s %s\n' "$(bold "id_like:        ")" "$ID_LIKE"
    printf '%s%s\n' "$(bold "package manager:")" "$([ -z "$PM" ] && echo ' unknown' || echo " $PM")"
    printf '%s%s\n' "$(bold "running as root:")" "$([ "$(id -u)" = 0 ] && echo ' yes' || echo ' no')"
}

cmd_list() {
    local all="$1"
    local n=${#APP_NAMES[@]}
    local i
    INSTALLED=()
    local installed=0
    for ((i=0;i<n;i++)); do
        if is_installed "${APP_FLATPAKS[$i]}" "${APP_BINS[$i]}"; then INSTALLED[$i]=1; installed=$((installed+1)); else INSTALLED[$i]=0; fi
    done

    if [ "$all" = 1 ]; then
        local max_name=0
        for ((i=0;i<n;i++)); do [ ${#APP_NAMES[$i]} -gt $max_name ] && max_name=${#APP_NAMES[$i]}; done
        category_order
        local o cnt
        for o in "${ORDER[@]}"; do
            cnt=0
            for ((i=0;i<n;i++)); do [ "${APP_CATS[$i]}" = "$o" ] && cnt=$((cnt+1)); done
            [ $cnt -eq 0 ] && continue
            [ -n "$o" ] && printf '%s (%s)\n' "$(bold "$o")" "$cnt"
            for ((i=0;i<n;i++)); do
                [ "${APP_CATS[$i]}" = "$o" ] || continue
                local mark
                if [ "${INSTALLED[$i]}" = 1 ]; then mark="$(paint "$GREEN" "$GLYPH_OK")"; else mark="$(paint "$DIM" "$GLYPH_MISS")"; fi
                printf '  %s %-*s  %s\n' "$mark" "$max_name" "${APP_NAMES[$i]}" "$(dim "$(app_source "$i")")"
            done
            echo
        done
        printf 'Summary: %s apps · %s installed · %s to install\n' "$n" "$installed" "$((n-installed))"
        return 0
    fi

    printf '%s/%s installed · ' "$(green "$installed")" "$n"
    if [ $((n-installed)) -gt 0 ]; then printf '%s to install\n' "$(yellow "$((n-installed))")"
    else printf '%s\n' "$(green "nothing to install")"; fi
    [ $installed -eq $n ] && return 0

    local label_w=0
    for ((i=0;i<n;i++)); do [ ${#APP_CATS[$i]} -gt $label_w ] && label_w=${#APP_CATS[$i]}; done
    label_w=$((label_w+2)); [ $label_w -gt 20 ] && label_w=20

    local width; width=$(stty size 2>/dev/null | awk '{print $2}'); [ -z "$width" ] && width=80
    [ "$width" -le 0 ] && width=80

    echo
    category_order
    local o m
    for o in "${ORDER[@]}"; do
        local miss=()
        for ((i=0;i<n;i++)); do
            if [ "${APP_CATS[$i]}" = "$o" ] && [ "${INSTALLED[$i]}" = 0 ]; then miss+=("${APP_NAMES[$i]}"); fi
        done
        [ ${#miss[@]} -eq 0 ] && continue
        local label="$o"; [ -z "$label" ] && label="(other)"
        printf '%-*s' "$label_w" "$label"
        local col=$label_w
        for ((m=0;m<${#miss[@]};m++)); do
            local tok="${miss[$m]}"
            if [ $((col + ${#tok} + 2)) -gt $width ] && [ $col -gt $label_w ]; then
                printf '\n%-*s' "$label_w" ""
                col=$label_w
            fi
            printf '%s' "$tok"
            col=$((col + ${#tok}))
            if [ $((m+1)) -lt ${#miss[@]} ]; then printf '  '; col=$((col+2)); fi
        done
        printf '\n'
    done
}

cmd_install() {
    local todo=()
    local n=${#APP_NAMES[@]}
    local i name idx
    if [ $# -eq 0 ]; then
        for ((i=0;i<n;i++)); do todo+=("$i"); done
    else
        for name in "$@"; do
            idx=-1
            for ((i=0;i<n;i++)); do [ "${APP_NAMES[$i]}" = "$name" ] && { idx=$i; break; }; done
            if [ $idx -lt 0 ]; then echo "unknown app: $name (see \`list\`)"; return 1; fi
            todo+=("$idx")
        done
    fi
    [ ${#todo[@]} -eq 0 ] && { echo "nothing to do (empty manifest?)"; return 1; }

    if [ "$YES" != 1 ] && [ "$DRY_RUN" != 1 ]; then
        printf 'install %d app(s)? [y/N] ' "${#todo[@]}"
        read -r answer
        case "$answer" in y|Y|yes) ;; *) echo "aborted."; return 0 ;; esac
    fi

    local installed=0 already=0 failed=0 s cnt=0
    for i in "${todo[@]}"; do
        cnt=$((cnt+1))
        if [ "$DRY_RUN" != 1 ] && [ -t 1 ]; then
            spinner_start "${APP_NAMES[$i]}" "$cnt" "${#todo[@]}"
        fi
        install_app "$i"
        s=$?
        clear_progress
        case $s in 1) installed=$((installed+1)) ;; 0) already=$((already+1)) ;; 2) failed=$((failed+1)) ;; esac
        if [ "$DRY_RUN" = 1 ]; then echo; else print_result "${APP_NAMES[$i]}" "$s"; fi
    done

    if [ "$DRY_RUN" != 1 ]; then
        print_summary "${#todo[@]}" "$installed" "$already" "$failed"
    fi
    [ $failed -eq 0 ]
}

uninstall_app() {
    local i="$1"
    local name="${APP_NAMES[$i]}" flat="${APP_FLATPAKS[$i]}" bin="${APP_BINS[$i]}"

    [ "$DRY_RUN" = 1 ] && print_section "$name"

    if ! is_installed "$flat" "$bin"; then
        if [ "$DRY_RUN" = 1 ]; then
            if [ -n "$flat" ]; then print_line "not installed (flatpak $flat)"
            else print_line "not installed ($bin)"; fi
        fi
        return 0
    fi

    if [ -n "$flat" ]; then
        local cmd="flatpak uninstall -y --user $flat"
        if [ "$DRY_RUN" = 1 ]; then
            print_dry_run "$cmd"
        else
            run_captured "$cmd" 0
            if [ "$LAST_RC" != 0 ]; then
                print_error "flatpak uninstall failed:"
                printf '%s' "$LAST_OUT"
                return 2
            fi
        fi
        return 1
    fi

    local pkgs="${APP_PKGS[$i]}"
    local pkg_arr=()
    [ -n "$pkgs" ] && IFS="$IS" read -ra pkg_arr <<< "$pkgs"

    if [ -z "$pkgs" ]; then
        print_line "no packages mapped for this distro ($PM)"
        return 2
    fi

    local cmd; cmd=$(remove_command "${pkg_arr[@]}")
    if [ -z "$cmd" ]; then
        print_error "unsupported package manager"
        return 2
    fi

    if [ "$DRY_RUN" = 1 ]; then
        print_dry_run "$cmd" 1
    else
        run_captured "$cmd" 1
        if [ "$LAST_RC" != 0 ]; then
            print_error "remove failed:"
            printf '%s' "$LAST_OUT"
            return 2
        fi
    fi

    return 1
}

cmd_uninstall() {
    local todo=()
    local n=${#APP_NAMES[@]}
    local i name idx
    if [ $# -eq 0 ]; then
        for ((i=0;i<n;i++)); do todo+=("$i"); done
    else
        for name in "$@"; do
            idx=-1
            for ((i=0;i<n;i++)); do [ "${APP_NAMES[$i]}" = "$name" ] && { idx=$i; break; }; done
            if [ $idx -lt 0 ]; then echo "unknown app: $name (see \`list\`)"; return 1; fi
            todo+=("$idx")
        done
    fi
    [ ${#todo[@]} -eq 0 ] && { echo "nothing to do (empty manifest?)"; return 1; }

    if [ "$YES" != 1 ] && [ "$DRY_RUN" != 1 ]; then
        printf 'remove %d app(s)? [y/N] ' "${#todo[@]}"
        read -r answer
        case "$answer" in y|Y|yes) ;; *) echo "aborted."; return 0 ;; esac
    fi

    local removed=0 skipped=0 failed=0 s
    for i in "${todo[@]}"; do
        uninstall_app "$i"
        s=$?
        case $s in 1) removed=$((removed+1)) ;; 0) skipped=$((skipped+1)) ;; 2) failed=$((failed+1)) ;; esac
        if [ "$DRY_RUN" = 1 ]; then echo; else print_remove_result "${APP_NAMES[$i]}" "$s"; fi
    done

    if [ "$DRY_RUN" != 1 ]; then
        print_summary_remove "${#todo[@]}" "$removed" "$skipped" "$failed"
    fi
    [ $failed -eq 0 ]
}

cmd_update() {
    [ "$DRY_RUN" = 1 ] && print_section "system"
    refresh_index

    local cmd; cmd=$(update_command)
    if [ -n "$cmd" ]; then
        if [ "$DRY_RUN" = 1 ]; then
            print_dry_run "$cmd" 1
        else
            run_captured "$cmd" 1
            if [ "$LAST_RC" != 0 ]; then
                print_error "update failed:"
                printf '%s' "$LAST_OUT"
                print_update_result 2
                return 1
            fi
        fi
    fi

    if ! command -v flatpak >/dev/null 2>&1; then
        [ "$DRY_RUN" != 1 ] && print_update_result 1
        return 0
    fi

    local fcmd="flatpak update -y --user"
    if [ "$DRY_RUN" = 1 ]; then
        print_dry_run "$fcmd"
    else
        run_captured "$fcmd" 0
        if [ "$LAST_RC" != 0 ]; then
            print_error "flatpak update failed:"
            printf '%s' "$LAST_OUT"
            print_update_result 2
            return 1
        fi
    fi

    [ "$DRY_RUN" = 1 ] || print_update_result 1
    return 0
}

cmd_select() {
    local n=${#APP_NAMES[@]}
    category_order
    ROWS=(); SELECTABLE=(); ROW_APP=()
    local o i
    for o in "${ORDER[@]}"; do
        local has=0
        for ((i=0;i<n;i++)); do [ "${APP_CATS[$i]}" = "$o" ] && { has=1; break; }; done
        [ $has -eq 0 ] && continue
        if [ -n "$o" ]; then ROWS+=("$o"); SELECTABLE+=(0); ROW_APP+=(-1); fi
        for ((i=0;i<n;i++)); do
            if [ "${APP_CATS[$i]}" = "$o" ]; then ROWS+=("${APP_NAMES[$i]}"); SELECTABLE+=(1); ROW_APP+=("$i"); fi
        done
    done

    checkbox_select

    local sel=() r ai
    for r in "${PICK_RESULT[@]}"; do
        ai="${ROW_APP[$r]}"
        [ "$ai" -ge 0 ] && sel+=("${APP_NAMES[$ai]}")
    done
    [ ${#sel[@]} -eq 0 ] && { echo "nothing selected."; return 0; }
    cmd_install "${sel[@]}"
}

# ---- TUI picker ------------------------------------------------------------

read_key() {
    local k
    if ! IFS= read -rsn1 k; then echo "Q"; return; fi
    if [ "$k" = $'\033' ]; then
        local k2 k3
        IFS= read -rsn1 -t 1 k2 || { echo "Q"; return; }
        if [ "$k2" != '[' ] && [ "$k2" != 'O' ]; then echo "Q"; return; fi
        IFS= read -rsn1 -t 1 k3 || { echo "Q"; return; }
        case "$k3" in
            A) echo "UP" ;;
            B) echo "DOWN" ;;
            H) echo "HOME" ;;
            F) echo "END" ;;
            5) IFS= read -rsn1 -t 1 _; echo "PGUP" ;;
            6) IFS= read -rsn1 -t 1 _; echo "PGDN" ;;
            1) IFS= read -rsn1 -t 1 _; echo "HOME" ;;
            4) IFS= read -rsn1 -t 1 _; echo "END" ;;
            *) echo "Q" ;;
        esac
        return
    fi
    case "$k" in
        ''|$'\r'|$'\n') echo "ENTER" ;;
        ' ') echo "SPACE" ;;
        q|Q) echo "Q" ;;
        a|A) echo "ALL" ;;
        c|C) echo "CLEAR" ;;
        k) echo "UP" ;;
        j) echo "DOWN" ;;
        *) echo "NONE" ;;
    esac
}

checkbox_select() {
    PICK_RESULT=()
    local n=${#ROWS[@]}
    local i first=-1 last=-1 sel_total=0
    for ((i=0;i<n;i++)); do
        if [ "${SELECTABLE[$i]}" = 1 ]; then
            [ $first -lt 0 ] && first=$i
            last=$i
            sel_total=$((sel_total+1))
        fi
    done
    [ $first -lt 0 ] && return 0

    if [ ! -t 0 ]; then
        echo "stdin is not a terminal; cannot show picker." >&2
        return 0
    fi

    local selected=()
    for ((i=0;i<n;i++)); do selected[$i]=0; done
    local cursor=$first scroll=0

    local size; size=$(stty size 2>/dev/null)
    local height=0
    [ -n "$size" ] && height="${size%% *}"
    local visible=$n
    if [ -n "$height" ] && [ "$height" -gt 0 ]; then visible=$((height-3)); fi
    [ $visible -lt 1 ] && visible=1

    local saved; saved=$(stty -g 2>/dev/null)
    stty -icanon -echo min 1 time 0 2>/dev/null

    local restore
    restore() {
        printf '\033[?25h'
        printf '\033[?1049l'
        [ -n "$saved" ] && stty "$saved" 2>/dev/null
    }
    trap 'restore; exit 130' INT TERM

    local render first_frame=1
    render() {
        local sel_count=0 j
        for ((j=0;j<n;j++)); do
            [ "${SELECTABLE[$j]}" = 1 ] && [ "${selected[$j]}" = 1 ] && sel_count=$((sel_count+1))
        done
        printf '\033[H'
        if [ "$first_frame" = 1 ]; then printf '\033[2J'; first_frame=0; fi
        printf 'select apps to install:\n'
        local k
        for ((k=scroll; k<n && k<scroll+visible; k++)); do
            [ $k -eq $cursor ] && printf '\033[7m'
            if [ "${SELECTABLE[$k]}" = 1 ]; then
                if [ "${selected[$k]}" = 1 ]; then printf ' [%s] %s' "$(paint "$GREEN" x)" "${ROWS[$k]}"
                else printf ' [ ] %s' "${ROWS[$k]}"; fi
            else
                printf '\033[1m  %s\033[0m' "${ROWS[$k]}"
            fi
            [ $k -eq $cursor ] && printf '\033[0m'
            printf '\n'
        done
        printf '\033[J'
        printf 'selected: %d/%d  |  up/down move · space toggle · a all · c clear · enter ok · q quit\n' "$sel_count" "$sel_total"
        printf '\n'
    }

    printf '\033[?1049h'
    printf '\033[?25l'
    render

    local done=0 key p
    while [ $done = 0 ]; do
        key=$(read_key)
        case "$key" in
            UP)
                p=$((cursor-1)); while [ $p -ge 0 ] && [ "${SELECTABLE[$p]}" != 1 ]; do p=$((p-1)); done
                [ $p -ge 0 ] && cursor=$p ;;
            DOWN)
                p=$((cursor+1)); while [ $p -lt $n ] && [ "${SELECTABLE[$p]}" != 1 ]; do p=$((p+1)); done
                [ $p -lt $n ] && cursor=$p ;;
            HOME) cursor=$first ;;
            END) cursor=$last ;;
            SPACE)
                if [ "${SELECTABLE[$cursor]}" = 1 ]; then
                    [ "${selected[$cursor]}" = 1 ] && selected[$cursor]=0 || selected[$cursor]=1
                fi ;;
            ALL) for ((i=0;i<n;i++)); do [ "${SELECTABLE[$i]}" = 1 ] && selected[$i]=1; done ;;
            CLEAR) for ((i=0;i<n;i++)); do selected[$i]=0; done ;;
            ENTER) done=1 ;;
            Q) trap - INT TERM; restore; printf '\n'; return 0 ;;
        esac
        [ $cursor -lt $scroll ] && scroll=$cursor
        [ $cursor -ge $((scroll+visible)) ] && scroll=$((cursor-visible+1))
        [ $scroll -gt $((n-visible)) ] && scroll=$((n-visible))
        [ $scroll -lt 0 ] && scroll=0
        [ $done = 0 ] && render
    done

    trap - INT TERM
    restore
    printf '\n'

    for ((i=0;i<n;i++)); do
        [ "${SELECTABLE[$i]}" = 1 ] && [ "${selected[$i]}" = 1 ] && PICK_RESULT+=("$i")
    done
    return 0
}

# ---- main ------------------------------------------------------------------

main() {
    local CMD="${1:-select}"
    [ $# -gt 0 ] && shift

    case "$CMD" in -h|--help|help) usage; exit 0 ;;
        -V|--version|version) echo "appstrap $VERSION"; exit 0 ;;
    esac

    local names=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --config) CONFIG="$2"; shift 2 ;;
            -y|--yes) YES=1; shift ;;
            --dry-run) DRY_RUN=1; shift ;;
            --force) FORCE=1; shift ;;
            --all) ALL=1; shift ;;
            --no-color) COLOR=never; shift ;;
            --color) COLOR=always; shift ;;
            --color=*) COLOR="${1#--color=}"; shift ;;
            -h|--help) usage; exit 0 ;;
            -V|--version) echo "appstrap $VERSION"; exit 0 ;;
            *) names+=("$1"); shift ;;
        esac
    done

    case "$COLOR" in always|never|auto) ;; *) COLOR=auto ;; esac

    detect_distro

    if [ "$CMD" = detect ]; then cmd_detect; exit 0; fi

    if [ -n "$CONFIG" ]; then MANIFEST_LABEL="$CONFIG"; fi
    load_manifest "$CONFIG"
    if [ "${#APP_NAMES[@]}" -eq 0 ]; then
        echo "error: could not load manifest${CONFIG:+ from $CONFIG} (use --config FILE)" >&2
        exit 1
    fi

    case "$CMD" in
        list) print_manifest; cmd_list "$ALL"; exit $? ;;
        install) print_manifest; cmd_install "${names[@]}"; exit $? ;;
        uninstall) print_manifest; cmd_uninstall "${names[@]}"; exit $? ;;
        update) print_manifest; cmd_update; exit $? ;;
        select) print_manifest; cmd_select; exit $? ;;
        *) echo "unknown command: $CMD" >&2; usage; exit 1 ;;
    esac
}

main "$@"
