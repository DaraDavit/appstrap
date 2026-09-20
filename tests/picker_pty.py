#!/usr/bin/env python3
"""Regression test for the interactive picker.

Drives the picker in a pty: DOWN, DOWN, SPACE (toggle), ENTER (confirm).
Asserts Enter exits the picker and the toggled app's install command is
emitted. Runs with --dry-run so nothing is installed.

Usage: picker_pty.py "<cmd...>" <fixture> <expected-install-substring>
"""
import os
import pty
import select
import shlex
import sys
import time

cmd = shlex.split(sys.argv[1])
fixture = sys.argv[2]
expected = sys.argv[3]

pid, fd = pty.fork()
if pid == 0:
    os.execvp(cmd[0], cmd + ["select", "--config", fixture, "--dry-run", "--no-color"])

out = b""


def drain(dur=0.25):
    global out
    time.sleep(dur)
    while True:
        r, _, _ = select.select([fd], [], [], 0)
        if not r:
            break
        try:
            d = os.read(fd, 4096)
        except OSError:
            break
        if not d:
            break
        out += d


try:
    drain(0.5)                  # initial render
    os.write(fd, b"\x1b[B")     # DOWN -> beta
    drain(0.2)
    os.write(fd, b"\x1b[B")     # DOWN -> gamma
    drain(0.2)
    os.write(fd, b" ")          # toggle gamma
    drain(0.2)
    os.write(fd, b"\r")         # ENTER -> confirm selection
    drain(0.6)
finally:
    try:
        os.close(fd)
    except OSError:
        pass

_, status = os.waitpid(pid, 0)
rc = os.waitstatus_to_exitcode(status)

text = out.decode("utf-8", "replace")
sys.stdout.write(text)

if rc != 0:
    print(f"FAIL: picker exited with code {rc}")
    sys.exit(1)
if "\x1b[?1049h" not in text:
    print("FAIL: picker did not enter the alternate screen buffer")
    sys.exit(1)
if "\x1b[?1049l" not in text:
    print("FAIL: picker did not leave the alternate screen buffer")
    sys.exit(1)
if expected not in text:
    print(f"FAIL: install command missing: {expected}")
    sys.exit(1)
sys.exit(0)