#!/usr/bin/env python3
"""Exercise real SIGUSR1 delivery and logging without external services.

Build first, then run: python3 scripts/test_sigusr1.py .build/debug/modbus2mqtt
The same check can target a release executable on macOS or Linux.
"""

import argparse
import contextlib
import os
import pathlib
import signal
import socket
import subprocess
import tempfile
import time


def wait_for_log(process, log, expected, offset=0):
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        # pread leaves the child's shared output-file position untouched.
        data = os.pread(log.fileno(), max(0, os.fstat(log.fileno()).st_size - offset), offset)
        output = data.decode("utf-8", errors="replace")
        if process.poll() is not None:
            raise AssertionError(f"Bridge exited with {process.returncode}:\n{output}")
        if expected in output:
            return offset + len(data)
        time.sleep(0.02)
    raise AssertionError(f"Timed out waiting for {expected!r}:\n{output}")


def check_signals(binary, initial_level):
    # Reserve unused loopback ports without listening: connections fail locally,
    # leaving the bridge in its normal retry loop with its signal source active.
    with contextlib.ExitStack() as stack:
        ports = []
        for _ in range(2):
            endpoint = stack.enter_context(socket.socket())
            endpoint.bind(("127.0.0.1", 0))
            ports.append(str(endpoint.getsockname()[1]))
        log = stack.enter_context(tempfile.TemporaryFile())
        process = subprocess.Popen(
            [str(binary), "--log-level", initial_level,
             "--modbus-server", "127.0.0.1", "--modbus-port", ports[0],
             "--mqtt-servername", "127.0.0.1", "--mqtt-port", ports[1],
             "--device-description-file", "sma.sunnyboy.json"],
            stdout=log, stderr=log,
        )
        try:
            offset = wait_for_log(process, log, "Restarting service in")
            level = initial_level
            for _ in range(9):
                level = {"trace": "info", "debug": "trace"}.get(level, "debug")
                process.send_signal(signal.SIGUSR1)
                # Wait for each acknowledgement: POSIX signals may coalesce.
                offset = wait_for_log(process, log, f"to {level}", offset)
            print(f"PASS: {initial_level}: 9 signals, expected levels, bridge alive", flush=True)
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=pathlib.Path)
    args = parser.parse_args()
    binary = args.binary.resolve(strict=True)
    for initial_level in ("notice", "info", "debug", "trace"):
        check_signals(binary, initial_level)
