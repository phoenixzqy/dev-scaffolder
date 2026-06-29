#!/usr/bin/env python3
"""j — a tiny, cross-platform directory jumper (a simplified autojump).

This is the engine behind the global ``j`` command. Because a child process
cannot change its parent shell's working directory, ``j`` is implemented as a
shell function (see the zsh / PowerShell snippets shipped by the scaffolders)
that calls this script:

    j add            -> records the current directory in the local DB
    j                -> opens a TUI; the chosen path is printed to stdout and
                        the shell function ``cd``s into it
    j list           -> prints stored paths (newline separated)
    j rm   <path>    -> removes a path from the DB
    j pin  <path>    -> pins a path to the top of the list
    j unpin <path>   -> unpins a path
    j version        -> prints the installed version
    j update         -> downloads and installs the latest version in place

The database is a single JSON file kept next to this script (the tool's
install location), overridable with the ``JUMP_HOME`` environment variable.

No third-party dependencies — standard library only — so it runs identically
on Windows, macOS and Linux.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import time

__version__ = "1.1.0"

IS_WINDOWS = os.name == "nt"

# Where `j update` pulls the latest engine from (overridable for forks/branches).
UPDATE_URL = os.environ.get(
    "JUMP_UPDATE_URL",
    "https://raw.githubusercontent.com/phoenixzqy/dev-scaffolder/main/tools/jump/jump.py",
)


# ── Database ────────────────────────────────────────────────────────────────
def db_path() -> str:
    """Return the path to the JSON DB, which lives at the install location."""
    base = os.environ.get("JUMP_HOME") or os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base, "db.json")


def load_db() -> list:
    """Load and normalise the list of stored entries."""
    try:
        with open(db_path(), "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (FileNotFoundError, ValueError, OSError):
        data = {}
    entries = []
    for raw in data.get("paths", []) if isinstance(data, dict) else []:
        if not isinstance(raw, dict) or not raw.get("path"):
            continue
        entries.append(
            {
                "path": str(raw["path"]),
                "added": float(raw.get("added", 0) or 0),
                "pinned": bool(raw.get("pinned", False)),
                "count": int(raw.get("count", 0) or 0),
            }
        )
    return entries


def save_db(entries: list) -> None:
    """Atomically write entries back to the JSON DB."""
    path = db_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump({"paths": entries}, fh, indent=2)
    os.replace(tmp, path)


def ordered(entries: list) -> list:
    """Pinned first, then by jump count (most jumped), then most-recently-added."""
    return sorted(entries, key=lambda e: (not e["pinned"], -e["count"], -e["added"]))


def bump_count(target: str) -> None:
    """Record a jump: increment the entry's jump count and persist."""
    entries = load_db()
    for entry in entries:
        if entry["path"] == target:
            entry["count"] += 1
            save_db(entries)
            return


# ── Non-interactive sub-commands ────────────────────────────────────────────
def cmd_add(args) -> int:
    target = os.path.abspath(args.path or os.getcwd())
    entries = load_db()
    if any(e["path"] == target for e in entries):
        return 0  # already present — idempotent
    entries.append({"path": target, "added": time.time(), "pinned": False, "count": 0})
    save_db(entries)
    return 0


def cmd_rm(args) -> int:
    target = os.path.abspath(args.path)
    save_db([e for e in load_db() if e["path"] != target])
    return 0


def _set_pinned(target: str, pinned: bool) -> int:
    target = os.path.abspath(target)
    entries = load_db()
    for entry in entries:
        if entry["path"] == target:
            entry["pinned"] = pinned
    save_db(entries)
    return 0


def cmd_pin(args) -> int:
    return _set_pinned(args.path, True)


def cmd_unpin(args) -> int:
    return _set_pinned(args.path, False)


def cmd_list(_args) -> int:
    for entry in ordered(load_db()):
        print(entry["path"])
    return 0


def cmd_version(_args) -> int:
    print(f"j {__version__}")
    return 0


def _parse_version(text: str) -> str | None:
    """Pull ``__version__ = "x.y.z"`` out of a jump.py source string."""
    import re

    m = re.search(r'^__version__\s*=\s*["\']([^"\']+)["\']', text, re.MULTILINE)
    return m.group(1) if m else None


def _version_tuple(v: str):
    parts = []
    for chunk in v.split("."):
        num = "".join(ch for ch in chunk if ch.isdigit())
        parts.append(int(num) if num else 0)
    return tuple(parts)


def cmd_update(_args) -> int:
    """Download the latest engine and replace this script in place."""
    import tempfile
    import urllib.request

    target = os.path.abspath(__file__)
    print(f"Current version: {__version__}")
    print(f"Fetching latest from {UPDATE_URL} …")
    try:
        req = urllib.request.Request(UPDATE_URL, headers={"User-Agent": "jump-update"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = resp.read()
    except Exception as exc:  # noqa: BLE001 - report any network/HTTP failure
        print(f"Update failed: could not download ({exc})", file=sys.stderr)
        return 1

    text = data.decode("utf-8", errors="replace")

    # Validate it's real, compilable Python before trusting it.
    try:
        compile(text, "<downloaded jump.py>", "exec")
    except SyntaxError as exc:
        print(f"Update failed: downloaded file is not valid Python ({exc})", file=sys.stderr)
        return 1

    new_version = _parse_version(text)
    if new_version is None:
        print("Update failed: could not determine downloaded version", file=sys.stderr)
        return 1

    if new_version == __version__:
        print(f"Already up to date (v{__version__}).")
        return 0

    direction = (
        "Upgrading" if _version_tuple(new_version) > _version_tuple(__version__) else "Changing"
    )
    print(f"{direction} {__version__} -> {new_version} …")

    # Atomic replace: write to a temp file in the same dir, then os.replace.
    dest_dir = os.path.dirname(target)
    try:
        fd, tmp = tempfile.mkstemp(dir=dest_dir, prefix=".jump-", suffix=".py")
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        if not IS_WINDOWS:
            os.chmod(tmp, 0o755)
        os.replace(tmp, target)
    except Exception as exc:  # noqa: BLE001
        print(f"Update failed: could not write {target} ({exc})", file=sys.stderr)
        return 1

    print(f"Updated to v{new_version}.")
    return 0


# ── Terminal input/output ───────────────────────────────────────────────────
class Terminal:
    """Raw key reading + ANSI rendering that works on every OS.

    On Unix we talk to ``/dev/tty`` directly so the TUI still works while the
    process's stdout is captured by the shell's command substitution. On
    Windows we read keys via ``msvcrt`` and render to stderr (the console).
    """

    def __init__(self) -> None:
        self._unix_in = None
        self._unix_out = None
        self._old_attrs = None
        if IS_WINDOWS:
            self._enable_windows_vt()
            self.out = sys.stderr
        else:
            import termios
            import tty

            self._unix_in = open("/dev/tty", "rb", buffering=0)
            self._unix_out = open("/dev/tty", "w", encoding="utf-8")
            self.out = self._unix_out
            self._fd = self._unix_in.fileno()
            self._old_attrs = termios.tcgetattr(self._fd)
            tty.setraw(self._fd)

    @staticmethod
    def _enable_windows_vt() -> None:
        try:
            import ctypes

            kernel32 = ctypes.windll.kernel32
            for handle_id in (-11, -12):  # stdout, stderr
                handle = kernel32.GetStdHandle(handle_id)
                mode = ctypes.c_uint32()
                if kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
                    kernel32.SetConsoleMode(handle, mode.value | 0x0004)
        except Exception:
            pass  # best effort; modern terminals already handle ANSI

    # -- output --
    def write(self, text: str) -> None:
        self.out.write(text)
        self.out.flush()

    def enter_fullscreen(self) -> None:
        self.write("\x1b[?1049h\x1b[?25l")

    def leave_fullscreen(self) -> None:
        self.write("\x1b[?25h\x1b[?1049l")

    def close(self) -> None:
        try:
            self.leave_fullscreen()
        finally:
            if not IS_WINDOWS and self._old_attrs is not None:
                import termios

                termios.tcsetattr(self._fd, termios.TCSADRAIN, self._old_attrs)
                self._unix_in.close()
                self._unix_out.close()

    # -- input --
    def read_key(self):
        return self._read_windows() if IS_WINDOWS else self._read_unix()

    def _read_windows(self):
        import msvcrt

        ch = msvcrt.getwch()
        if ch in ("\x00", "\xe0"):
            code = msvcrt.getwch()
            return {"H": "UP", "P": "DOWN", "K": "LEFT", "M": "RIGHT"}.get(code, "OTHER")
        return self._classify(ch)

    def _read_unix(self):
        import select

        data = self._unix_in.read(1)
        if not data:
            return "EOF"
        if data == b"\x1b":
            ready, _, _ = select.select([self._unix_in], [], [], 0.05)
            if ready:
                nxt = self._unix_in.read(1)
                if nxt in (b"[", b"O"):
                    code = self._unix_in.read(1)
                    return {
                        b"A": "UP",
                        b"B": "DOWN",
                        b"C": "RIGHT",
                        b"D": "LEFT",
                    }.get(code, "OTHER")
                return "ESC"
            return "ESC"
        return self._classify(data.decode("utf-8", "ignore"))

    @staticmethod
    def _classify(ch: str):
        if ch in ("\r", "\n"):
            return "ENTER"
        if ch in ("\x7f", "\x08"):
            return "BACKSPACE"
        if ch == "\x1b":
            return "ESC"
        if ch == "\x03":
            return "CTRL_C"
        if not ch:
            return "OTHER"
        return ("CHAR", ch)


# ── Interactive selector ────────────────────────────────────────────────────
class Selector:
    """Stateful TUI. Input handling is decoupled from the Terminal so it can
    be unit-tested by feeding synthetic keys to :meth:`handle`."""

    def __init__(self) -> None:
        self.entries = load_db()
        self.query = ""
        self.search_mode = False
        self.index = 0
        self.done = False
        self.result = None  # selected path, or None on quit

    def visible(self) -> list:
        items = ordered(self.entries)
        if self.query:
            needle = self.query.lower()
            items = [e for e in items if needle in e["path"].lower()]
        return items

    def _clamp(self, items: list) -> None:
        if not items:
            self.index = 0
        else:
            self.index = max(0, min(self.index, len(items) - 1))

    # -- key handling (pure; testable without a real terminal) --
    def handle(self, key, items: list) -> None:
        if self.search_mode:
            self._handle_search(key)
            return
        if key in ("UP",) or key == ("CHAR", "k"):
            self.index -= 1
        elif key in ("DOWN",) or key == ("CHAR", "j"):
            self.index += 1
        elif key == "ENTER":
            if items:
                self.result = items[self.index]["path"]
                bump_count(self.result)  # record the jump
            self.done = True
        elif key in ("ESC", "CTRL_C", "EOF") or key == ("CHAR", "q"):
            self.done = True
        elif key == ("CHAR", "/"):
            self.search_mode = True
        elif key == ("CHAR", "d"):
            self._delete(items)
        elif key == ("CHAR", "p"):
            self._pin(items, True)
        elif key == ("CHAR", "u"):
            self._pin(items, False)
        self._clamp(self.visible())

    def _handle_search(self, key) -> None:
        if key == "ENTER":
            self.search_mode = False
        elif key in ("ESC", "CTRL_C"):
            self.search_mode = False
            self.query = ""
        elif key == "BACKSPACE":
            self.query = self.query[:-1]
        elif isinstance(key, tuple) and key[0] == "CHAR":
            self.query += key[1]
        self.index = 0

    def _selected_path(self, items: list):
        return items[self.index]["path"] if items else None

    def _delete(self, items: list) -> None:
        target = self._selected_path(items)
        if target is None:
            return
        self.entries = [e for e in self.entries if e["path"] != target]
        save_db(self.entries)

    def _pin(self, items: list, pinned: bool) -> None:
        target = self._selected_path(items)
        if target is None:
            return
        for entry in self.entries:
            if entry["path"] == target:
                entry["pinned"] = pinned
        save_db(self.entries)

    # -- rendering --
    @staticmethod
    def _clip(text: str, width: int) -> str:
        """Truncate a plain (ANSI-free) string to *width* visible columns."""
        if width <= 0:
            return ""
        if len(text) <= width:
            return text
        if width == 1:
            return text[:1]
        return text[: width - 1] + "…"

    def _format_row(self, entry: dict, number: int, selected: bool, cols: int) -> str:
        """Render one table row: path on the left, count + date flushed right.

        Missing directories are shown in red; the selected row is reverse-video.
        """
        missing = not os.path.isdir(entry["path"])
        prefix = "> " if selected else "  "
        marker = "★ " if entry["pinned"] else "  "
        left = "{}{:>2}. {}{}".format(prefix, number, marker, entry["path"])

        date = (
            time.strftime("%Y-%m-%d %H:%M", time.localtime(entry["added"]))
            if entry["added"]
            else "—"
        )
        right = "{}×  {}".format(entry["count"], date)

        gap = 2
        avail_left = cols - len(right) - gap
        if avail_left < 8:  # too narrow for a metadata column — just show the path
            text = self._clip(left, cols)
            if missing:
                text = "\x1b[31m" + text + "\x1b[39m"
            return "\x1b[7m" + text + "\x1b[27m" if selected else text

        left = self._clip(left, avail_left)
        pad = cols - len(left) - len(right)
        left_seg = ("\x1b[31m" + left + "\x1b[39m") if missing else left
        right_seg = "\x1b[2m" + right + "\x1b[22m"
        line = left_seg + (" " * pad) + right_seg
        return "\x1b[7m" + line + "\x1b[27m" if selected else line

    def render(self, term: Terminal, items: list) -> None:
        cols, rows = shutil.get_terminal_size((80, 24))
        rows = max(rows, 4)
        cols = max(cols, 10)
        # Reserve the top row for the header and the bottom two rows for the
        # divider + footer; the body fills everything in between.
        body_rows = max(1, rows - 3)

        start = 0
        if self.index >= body_rows:
            start = self.index - body_rows + 1
        window = items[start : start + body_rows]

        body = []
        if not items:
            body.append(self._clip("   (no entries — run 'j add' in a directory to begin)", cols))
        for offset, entry in enumerate(window):
            i = start + offset
            body.append(self._format_row(entry, i + 1, i == self.index, cols))
        # Pad the body so the footer always sticks to the bottom of the viewport.
        while len(body) < body_rows:
            body.append("")

        header = "\x1b[1m" + self._clip(" j — jump to directory", cols) + "\x1b[0m"
        divider = "\x1b[2m" + ("─" * min(cols, 70)) + "\x1b[0m"
        if self.search_mode:
            footer = "\x1b[33m" + self._clip(" /" + self.query, cols - 22) + "\x1b[0m" + (
                "\x1b[7m \x1b[0m  \x1b[2m(enter=apply • esc=clear)\x1b[0m"
            )
        else:
            hint = " ↑/↓ move • enter jump • d delete • p pin • u unpin • / search • q quit"
            if self.query:
                hint = " [filter: {}]".format(self.query) + hint
            footer = "\x1b[2m" + self._clip(hint, cols) + "\x1b[0m"

        screen = [header] + body[:body_rows] + [divider, footer]
        # Reset + clear each line (\x1b[0m\x1b[K) to scrub stale content/styling; no
        # trailing newline so the footer lands on the last row without scrolling.
        out = "\x1b[H" + "\r\n".join(line + "\x1b[0m\x1b[K" for line in screen) + "\x1b[J"
        term.write(out)

    # -- main loop --
    def run(self) -> int:
        try:
            term = Terminal()
        except OSError:
            sys.stderr.write("j: no interactive terminal available\n")
            return 1
        try:
            term.enter_fullscreen()
            while not self.done:
                items = self.visible()
                self._clamp(items)
                self.render(term, items)
                self.handle(term.read_key(), self.visible())
        finally:
            term.close()
        if self.result:
            print(self.result)
            return 0
        return 1


def cmd_select(_args) -> int:
    return Selector().run()


# ── CLI ─────────────────────────────────────────────────────────────────────
HELP_EPILOG = """\
examples:
  j                 open the picker and jump into the chosen directory
  j add             save the current directory
  j add /tmp/foo    save a specific directory
  j list            print saved paths (pinned, then most-jumped, then newest)
  j rm /tmp/foo     forget a directory
  j pin /tmp/foo    pin a directory to the top
  j unpin /tmp/foo  unpin a directory
  j version         print the installed version
  j update          download and install the latest version

picker keys:
  ↑/↓ or k/j   move          enter   jump to selection
  d            delete         p       pin          u   unpin
  /            search/filter  q/esc   quit without jumping

The directory list is stored as JSON next to this script (override with the
JUMP_HOME environment variable). Because a child process cannot change its
parent shell's directory, `j` is a shell function that runs this script and
cd's into the path it prints.
"""


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="j",
        description="j — a tiny, cross-platform directory jumper (simplified autojump).",
        epilog=HELP_EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "-V", "--version", action="version", version=f"j {__version__}"
    )
    sub = parser.add_subparsers(dest="command", metavar="<command>")

    p_add = sub.add_parser("add", help="add a directory (default: cwd) to the DB")
    p_add.add_argument("path", nargs="?", default=None, help="directory to add (default: cwd)")
    p_add.set_defaults(func=cmd_add)

    p_rm = sub.add_parser("rm", help="remove a directory from the DB")
    p_rm.add_argument("path", help="directory to remove")
    p_rm.set_defaults(func=cmd_rm)

    p_pin = sub.add_parser("pin", help="pin a directory to the top")
    p_pin.add_argument("path", help="directory to pin")
    p_pin.set_defaults(func=cmd_pin)

    p_unpin = sub.add_parser("unpin", help="unpin a directory")
    p_unpin.add_argument("path", help="directory to unpin")
    p_unpin.set_defaults(func=cmd_unpin)

    sub.add_parser("list", help="print stored paths").set_defaults(func=cmd_list)
    sub.add_parser("select", help="open the interactive picker (default)").set_defaults(
        func=cmd_select
    )
    sub.add_parser("version", help="print the installed version").set_defaults(
        func=cmd_version
    )
    sub.add_parser("update", help="download and install the latest version").set_defaults(
        func=cmd_update
    )

    return parser


def main(argv=None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    func = getattr(args, "func", cmd_select)  # bare `j` opens the picker
    return func(args)


if __name__ == "__main__":
    sys.exit(main())
