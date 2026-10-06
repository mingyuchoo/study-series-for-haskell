#!/usr/bin/env python3
"""Exercise real Vty input in an isolated PTY. Run after `stack test`."""
import fcntl
import os
from pathlib import Path
import pty
import select
import signal
import struct
import subprocess
import tempfile
import termios
import time

ROOT = Path(__file__).resolve().parents[1]
INSTALL = subprocess.check_output(["stack", "path", "--local-install-root"], cwd=ROOT, text=True).strip()
BINARY = Path(INSTALL) / "bin/hfm-exe"


class Terminal:
    def __init__(self, left, right, config):
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.environ["TERM"] = "xterm-256color"
            os.environ["XDG_CONFIG_HOME"] = str(config)
            os.execv(str(BINARY), [str(BINARY), str(left), str(right)])
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 160, 0, 0))
        self.output = b""
        deadline = time.monotonic() + 10
        while "파일 관리자".encode() not in self.output and time.monotonic() < deadline:
            self.read()
        if "파일 관리자".encode() not in self.output:
            self.close()
            raise AssertionError(self.output.decode(errors="replace"))

    def read(self):
        deadline = time.monotonic() + 0.3
        while time.monotonic() < deadline:
            if select.select([self.fd], [], [], 0.05)[0]:
                try:
                    data = os.read(self.fd, 65536)
                except OSError:
                    break
                if not data:
                    break
                self.output += data
        return self.output

    def key(self, keys):
        self.output = b""
        os.write(self.fd, keys)
        return self.read()

    def expect(self, keys, text):
        output = self.key(keys)
        assert text.encode() in output, (text, output.decode(errors="replace"))

    def quit(self):
        self.expect(b"\x18", "C-x:")
        quit_output = self.key(b"\x03")  # C-x C-c
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            pid, status = os.waitpid(self.pid, os.WNOHANG)
            if pid:
                self.pid = None
                assert os.waitstatus_to_exitcode(status) == 0
                return
            time.sleep(0.05)
        raise AssertionError(("C-x C-c did not exit", quit_output.decode(errors="replace")))

    def close(self):
        if self.pid:
            os.kill(self.pid, signal.SIGKILL)
            os.waitpid(self.pid, 0)
        os.close(self.fd)


with tempfile.TemporaryDirectory(prefix="hfm-keys-") as temporary:
    base = Path(temporary)
    left, right, config = base / "left", base / "right", base / "config"
    left.mkdir()
    right.mkdir()
    (config / "hfm").mkdir(parents=True)
    (config / "hfm/keybindings.yaml").write_text("binding_style: vim\n")
    for index in range(40):
        (left / f"file-{index:02}.txt").write_text("\n".join(f"LINE-{line:03}" for line in range(60)))
    (left / ".secret").write_text("hidden")

    terminal = Terminal(left, right, config)
    try:
        terminal.key(b"qjklh/\t")  # Removed shortcuts must leave the process in Browse.
        terminal.expect(b"\x1b>", "file-39.txt")
        terminal.expect(b"\x1b<", "file-00.txt")
        terminal.expect(b"\x0e\x18\x06", "LINE-000")  # C-n, C-x C-f
        terminal.expect(b"\x16", "LINE-020")  # C-v
        terminal.expect(b"\x1bv", "LINE-000")  # M-v
        terminal.expect(b"\x1b>", "LINE-059")
        terminal.expect(b"\x1b<", "LINE-000")
        terminal.expect(b"\x18k", "파일 관리자")
        terminal.expect(b"\x1bo", ".secret")  # M-o
        terminal.key(b"\x1bo")
        terminal.key(b"\x13file-\x1b<\x13\x13\x12\r")  # C-s/C-r result navigation
        terminal.expect(b"v", "file-00.txt")
        terminal.key(b"\x07\x07")
        terminal.key(b"\x13file-00\x0e\r")  # Search, select result, accept
        terminal.key(b"C\r")
        assert (right / "file-00.txt").exists(), "Dired C copy failed"
        terminal.key(b"R\x01\x0b")  # R, C-a C-k clears the default destination
        terminal.key(str(right / "renamed.txt").encode() + b"\r")
        assert (right / "renamed.txt").exists() and not (left / "file-00.txt").exists()
        terminal.key(b"\x07\x18o+new-folder\r")
        assert (right / "new-folder").is_dir(), "Dired + mkdir failed"
        terminal.key(b"\x18o\x13file-01\x0e\rD\x07")
        assert (left / "file-01.txt").exists(), "C-g must cancel deletion"
        terminal.key(b"Dy")
        assert not (left / "file-01.txt").exists(), "Dired D/y delete failed"
        terminal.quit()
    finally:
        terminal.close()

    # F2 is global, including pending prefixes and destructive confirmation.
    for mode_keys, english_label in [
        (b"", "File manager"), (b"\x13file-", "Search:"),
        (b"+draft", "New folder:"), (b"\x0eC", "Copy to:"),
        (b"\x0eR", "Move/rename to:"), (b"\x0eD", "Confirm delete:"),
        (b"\x0ev", "View:"), (b"\x18", "C-x:"),
    ]:
        terminal = Terminal(left, right, config)
        try:
            terminal.key(mode_keys)
            terminal.expect(b"\x1bOQ", english_label)  # xterm F2
            terminal.expect(b"\x1bOQ", "한국어")
            if mode_keys == b"\x18":
                terminal.key(b"\x07")
            terminal.key(b"\x07")
            terminal.quit()
            assert not (left / "draft").exists(), "F2 must not execute a prompt"
            assert (left / "file-02.txt").exists(), "F2 must not confirm deletion"
        finally:
            terminal.close()

    # The global quit prefix must work from every modal screen.
    for mode_keys in [b"\x13", b"+draft", b"\x0eD", b"\x0ev"]:
        terminal = Terminal(left, right, config)
        try:
            terminal.key(mode_keys)
            terminal.quit()
        finally:
            terminal.close()

print("PTY keybindings passed: legacy config, navigation, viewer, search, file operations, language toggle, modal quit")
