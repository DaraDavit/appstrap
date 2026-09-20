#!/usr/bin/env python3
"""Regression test for the install-progress spinner UI.

Runs a real (non-dry) install in a pty with stubbed sudo + package-manager
binaries (its own temp dir), so no privileges are needed and the real system
is untouched. Asserts the progress line with the counter and the final
result glyph appear.

Usage: progress_pty.py "<cmd...>" <fixture> <package-manager>
"""
import os
import pty
import select
import shlex
import shutil
import sys
import tempfile
import time

cmd = shlex.split(sys.argv[1])
fixture = sys.argv[2]
pm = sys.argv[3]

stub_dir = tempfile.mkdtemp(prefix="appstrap-progress-")
try:
    for name in ("sudo", pm):
        path = os.path.join(stub_dir, name)
        with open(path, "w") as f:
            f.write("#!/bin/sh\n")
            if name == "sudo":
                f.write('exec "$@"\n')
            else:
                f.write("exit 0\n")
        os.chmod(path, 0o755)

    pid, fd = pty.fork()
    if pid == 0:
        os.environ["PATH"] = stub_dir + ":" + os.environ["PATH"]
        os.execvp(cmd[0], cmd + ["install", "gamma", "--config", fixture, "--no-color"])

    out = b""

    def drain(dur=0.3):
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
        drain(0.5)
        os.write(fd, b"y\r")   # confirm the install prompt
        drain(1.5)
    finally:
        try:
            os.close(fd)
        except OSError:
            pass

    _, status = os.waitpid(pid, 0)
    rc = os.waitstatus_to_exitcode(status)
finally:
    shutil.rmtree(stub_dir, ignore_errors=True)

text = out.decode("utf-8", "replace")
sys.stdout.write(text)

if rc != 0:
    print(f"FAIL: install exited with code {rc}")
    sys.exit(1)
if "[1/1] installing gamma" not in text:
    print("FAIL: progress line missing: [1/1] installing gamma")
    sys.exit(1)
if "\u2713 gamma" not in text:
    print("FAIL: result line missing: \u2713 gamma")
    sys.exit(1)
sys.exit(0)