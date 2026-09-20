#!/usr/bin/env bash
# Test harness for both appstrap implementations. Run from repo root:
#   bash tests/run.sh                # runs everything that can run here
#   bash tests/run.sh bash           # bash port only (python3 path)
#   bash tests/run.sh bash-nopython  # bash port only (pure-bash parser fallback)
#   bash tests/run.sh cpp            # C++ binary only (needs `make build` first)
#
# All assertions use --dry-run so nothing is ever installed or removed.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$ROOT/tests/fixtures/basic.json"
STUB_DIR="$(mktemp -d)"
FAKE_BIN=""
trap 'rm -rf "$STUB_DIR" "${FAKE_BIN:-}"' EXIT

PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $*"; }

check_exit() { # label expected actual
    if [ "$2" = "$3" ]; then ok; else fail "$1: expected exit $2, got $3"; fi
}

contains() { # label haystack needle
    case "$2" in
        *"$3"*) ok ;;
        *) fail "$1: output missing '$3'"; printf '%s\n' "$2" | sed 's/^/    /' ;;
    esac
}

not_contains() { # label haystack needle
    case "$2" in
        *"$3"*) fail "$1: output unexpectedly contains '$3'"; printf '%s\n' "$2" | sed 's/^/    /' ;;
        *) ok ;;
    esac
}

make_stub() { # name  -> executable stub in STUB_DIR
    printf '#!/bin/sh\nexit 0\n' > "$STUB_DIR/$1"
    chmod +x "$STUB_DIR/$1"
}

run_impl() {
    local impl="$1"
    local label run bin launcher=""
    if [ "$impl" = cpp ]; then
        bin="$ROOT/build/appstrap"
        [ -x "$bin" ] || { echo "skip cpp: $bin not built (run make build)"; return 0; }
        label="cpp"
        launcher="$bin"
        run() { "$bin" "$@"; }
    elif [ "$impl" = bash-nopython ]; then
        # PATH with no python3: forces the pure-bash manifest parser.
        FAKE_BIN="$(mktemp -d)"
        ln -s "$(command -v bash)" "$FAKE_BIN/bash"
        ln -s "$(command -v sh)" "$FAKE_BIN/sh"
        ln -s "$(command -v cat)" "$FAKE_BIN/cat"
        ln -s "$(command -v id)" "$FAKE_BIN/id"
        label="bash (no python3)"
        run() { PATH="$FAKE_BIN:$STUB_DIR" bash "$ROOT/appstrap.sh" "$@"; }
    else
        label="bash"
        launcher="bash $ROOT/appstrap.sh"
        run() { bash "$ROOT/appstrap.sh" "$@"; }
    fi
    echo "== $label =="
    rm -f "$STUB_DIR"/*

    local out rc

    # version / help
    out=$(run --version); rc=$?
    check_exit "version" 0 "$rc"
    contains "version output" "$out" "appstrap 0.1.0"
    out=$(run --help); rc=$?
    check_exit "help" 0 "$rc"
    contains "help lists uninstall" "$out" "uninstall"
    contains "help lists update" "$out" "update"

    # unknown command
    out=$(run frobnicate --no-color 2>&1); rc=$?
    check_exit "unknown command" 1 "$rc"
    contains "unknown command message" "$out" "unknown command"

    # unknown app name
    out=$(run install --config "$FIXTURE" --dry-run -y --no-color nope 2>&1); rc=$?
    check_exit "unknown app" 1 "$rc"
    contains "unknown app message" "$out" "unknown app: nope"

    # detect
    out=$(run detect --no-color); rc=$?
    check_exit "detect" 0 "$rc"
    contains "detect header" "$out" "package manager:"
    local pm
    pm=$(printf '%s\n' "$out" | awk '/package manager:/ { print $NF }')
    [ -n "$pm" ] && [ "$pm" != unknown ] || fail "detect: no known package manager ($pm)"

    # map PM to expected command prefixes
    local install_cmd remove_cmd update_cmd
    case "$pm" in
        apt)     install_cmd="apt-get install -y";        remove_cmd="apt-get remove -y";        update_cmd="apt-get upgrade -y" ;;
        dnf)     install_cmd="dnf install -y";            remove_cmd="dnf remove -y";            update_cmd="dnf upgrade -y" ;;
        pacman)  install_cmd="pacman -S --noconfirm --needed"; remove_cmd="pacman -R --noconfirm"; update_cmd="pacman -Syu --noconfirm" ;;
        zypper)  install_cmd="zypper --non-interactive install"; remove_cmd="zypper --non-interactive remove"; update_cmd="zypper --non-interactive update" ;;
        apk)     install_cmd="apk add";                    remove_cmd="apk del";                    update_cmd="apk upgrade" ;;
        *)       fail "detect: unexpected pm '$pm'"; return 0 ;;
    esac

    # list
    out=$(run list --config "$FIXTURE" --all --no-color); rc=$?
    check_exit "list" 0 "$rc"
    contains "list names alpha" "$out" "alpha"
    contains "list names beta" "$out" "beta"
    contains "list names gamma" "$out" "gamma"
    contains "list summary" "$out" "Summary:"

    # install --dry-run
    out=$(run install --config "$FIXTURE" --dry-run -y --no-color); rc=$?
    check_exit "install dry-run" 0 "$rc"
    contains "install alpha pkg" "$out" "$install_cmd alpha-pkg"
    contains "install setup cmd" "$out" "setup-alpha"
    contains "install post cmd" "$out" "post-alpha"
    contains "install flatpak remote" "$out" "flatpak remote-add --user --if-not-exists flathub"
    contains "install flatpak app" "$out" "flatpak install -y --user flathub org.test.Beta"
    local gamma_pkg="gamma-pkg"
    [ "$pm" = apt ] && gamma_pkg="gamma-deb"
    contains "install gamma resolve_family" "$out" "$gamma_pkg"

    # uninstall --dry-run (stub `alpha` + `flatpak` so removal paths are taken)
    make_stub alpha
    make_stub flatpak
    out=$(PATH="$STUB_DIR:$PATH" run uninstall --config "$FIXTURE" --dry-run -y --no-color); rc=$?
    rm -f "$STUB_DIR/alpha" "$STUB_DIR/flatpak"
    check_exit "uninstall dry-run" 0 "$rc"
    contains "uninstall alpha pkg" "$out" "$remove_cmd alpha-pkg"
    contains "uninstall flatpak" "$out" "flatpak uninstall -y --user org.test.Beta"
    not_contains "uninstall no setup" "$out" "setup-alpha"
    not_contains "uninstall no gamma" "$out" "$remove_cmd gamma"

    # update --dry-run (stub `flatpak` so the flatpak path is taken)
    make_stub flatpak
    out=$(PATH="$STUB_DIR:$PATH" run update --config "$FIXTURE" --dry-run -y --no-color); rc=$?
    rm -f "$STUB_DIR/flatpak"
    check_exit "update dry-run" 0 "$rc"
    contains "update pm cmd" "$out" "$update_cmd"
    contains "update flatpak" "$out" "flatpak update -y --user"

    # picker on non-tty errors out cleanly
    out=$(run select --config "$FIXTURE" --no-color </dev/null 2>&1); rc=$?
    check_exit "select non-tty" 0 "$rc"
    contains "select non-tty message" "$out" "not a terminal"

    # already-installed detection via PATH stub
    make_stub alpha
    out=$(PATH="$STUB_DIR:$PATH" run list --config "$FIXTURE" --all --no-color); rc=$?
    check_exit "list with stub" 0 "$rc"
    contains "list marks alpha installed" "$out" "✓ alpha"
    contains "list marks beta missing" "$out" "· beta"

    # interactive picker: Enter must confirm and the selection must flow
    # into install (regression: Enter used to be ignored)
    if command -v python3 >/dev/null 2>&1 && [ -n "$launcher" ]; then
        out=$(python3 "$ROOT/tests/picker_pty.py" "$launcher" "$FIXTURE" "$install_cmd gamma-pkg"); rc=$?
        check_exit "picker enter" 0 "$rc"
        contains "picker install cmd" "$out" "[dry-run] sudo $install_cmd gamma-pkg"
    fi
}

run_impl cpp
run_impl bash
run_impl bash-nopython

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]