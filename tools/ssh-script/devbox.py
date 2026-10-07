#!/usr/bin/env python3
"""Portable OpenSSH server setup and named devbox connections (Python 3.9+)."""
import argparse
import base64
import json
import os
import platform
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


__version__ = "1.0.0"

HERE = Path(__file__).resolve().parent
ALIAS = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,63}\Z")
HOST = re.compile(r"[A-Za-z0-9:][A-Za-z0-9_.:-]*\Z")
USER = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.@\\-]*\Z")


def detect():
    system = platform.system()
    if system == "Windows":
        return "windows"
    if system == "Darwin":
        return "macos"
    if system == "Linux":
        release = platform.release().lower()
        return "wsl" if "microsoft" in release or os.environ.get("WSL_INTEROP") else "linux"
    raise ValueError("Unsupported OS: " + system)


def run(command):
    subprocess.run([str(x) for x in command], check=True)


def private_permissions(path, directory=False):
    if os.name != "nt":
        path.chmod(0o700 if directory else 0o600)
        return
    # Change only the DACL; touching the SACL would require elevated privileges.
    import ctypes
    from ctypes import wintypes
    sid_output = subprocess.check_output(["whoami.exe", "/user", "/fo", "csv", "/nh"])
    sid = re.search(rb"S-1-[0-9-]+", sid_output)
    if not sid:
        raise OSError("Could not determine the Windows account SID")
    flags = "OICI" if directory else ""
    sddl = "D:P" + "".join(f"(A;{flags};FA;;;{account})" for account in
                          (sid.group().decode("ascii"), "SY", "BA"))
    security = ctypes.WinDLL("advapi32", use_last_error=True)
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    pointer = ctypes.c_void_p
    security.ConvertStringSecurityDescriptorToSecurityDescriptorW.argtypes = [
        wintypes.LPCWSTR, wintypes.DWORD, ctypes.POINTER(pointer), ctypes.POINTER(wintypes.DWORD)]
    security.ConvertStringSecurityDescriptorToSecurityDescriptorW.restype = wintypes.BOOL
    security.GetSecurityDescriptorDacl.argtypes = [pointer, ctypes.POINTER(wintypes.BOOL),
                                                 ctypes.POINTER(pointer), ctypes.POINTER(wintypes.BOOL)]
    security.GetSecurityDescriptorDacl.restype = wintypes.BOOL
    security.SetNamedSecurityInfoW.argtypes = [wintypes.LPWSTR, wintypes.DWORD, wintypes.DWORD,
                                             pointer, pointer, pointer, pointer]
    security.SetNamedSecurityInfoW.restype = wintypes.DWORD
    kernel.LocalFree.argtypes = [pointer]
    kernel.LocalFree.restype = pointer
    descriptor, dacl = pointer(), pointer()
    present, defaulted = wintypes.BOOL(), wintypes.BOOL()
    if not security.ConvertStringSecurityDescriptorToSecurityDescriptorW(sddl, 1, ctypes.byref(descriptor), None):
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        if not security.GetSecurityDescriptorDacl(descriptor, ctypes.byref(present),
                                                  ctypes.byref(dacl), ctypes.byref(defaulted)):
            raise ctypes.WinError(ctypes.get_last_error())
        result = security.SetNamedSecurityInfoW(str(path), 1, 0x80000004, None, None, dacl, None)
        if result:
            raise ctypes.WinError(result)
    finally:
        kernel.LocalFree(descriptor)


def atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".devbox-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            private_permissions(Path(temporary))
            stream.write(text)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def quoted(value):
    # OpenSSH config quoting; Windows paths work with forward slashes.
    value = str(value)
    if any(c in value for c in '\r\n\0"'):
        raise ValueError("SSH values cannot contain quotes, newlines, or NUL")
    return '"' + value.replace("\\", "/") + '"'


def valid_name(value):
    if not ALIAS.fullmatch(value):
        raise ValueError("Names must start with a letter or digit; use letters, digits, dots, _ or -")
    return value


def validate_entry(name, entry):
    valid_name(name)
    if not HOST.fullmatch(entry["host"]):
        raise ValueError("Host must be a hostname, IPv4 address, or unbracketed IPv6 address")
    if not USER.fullmatch(entry["user"]):
        raise ValueError("Invalid SSH username")
    if type(entry["port"]) is not int or not 1 <= entry["port"] <= 65535:
        raise ValueError("Port must be between 1 and 65535")
    if entry.get("identity"):
        quoted(entry["identity"])


def load_boxes(directory):
    path = directory / "devbox-ssh.json"
    if not path.exists():
        return {}
    boxes = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(boxes, dict):
        raise ValueError("devbox-ssh.json must contain a JSON object")
    for name, entry in boxes.items():
        validate_entry(name, entry)
    return boxes


def save_boxes(directory, boxes):
    lines = ["# Managed by devbox.py; edit with add/remove."]
    for name, entry in sorted(boxes.items()):
        validate_entry(name, entry)
        lines += ["", "Host " + name, "    HostName " + entry["host"],
                  "    User " + entry["user"], "    Port " + str(entry["port"]),
                  "    ServerAliveInterval 30", "    ServerAliveCountMax 3"]
        if entry.get("identity"):
            lines += ["    IdentityFile " + quoted(entry["identity"]), "    IdentitiesOnly yes"]
    managed = directory / "devbox-ssh.conf"
    config = directory / "config"
    for target in (managed, config, directory / "devbox-ssh.json"):
        if target.is_symlink():
            raise ValueError("Refusing to replace a symlinked SSH config file: " + str(target))
    old = config.read_text(encoding="utf-8") if config.exists() else ""
    include = "Include " + quoted(managed.resolve())
    # Include must come before Host blocks and wildcard defaults.
    remaining = "".join(line for line in old.splitlines(keepends=True)
                        if line.strip() != include)
    atomic_write(managed, "\n".join(lines) + "\n")
    atomic_write(directory / "devbox-ssh.json", json.dumps(boxes, indent=2) + "\n")
    atomic_write(config, include + "\n" + remaining)
    private_permissions(directory, directory=True)


def public_key(path):
    path = Path(path).expanduser().resolve()
    if path.stat().st_size > 16384:
        raise ValueError("Public key is too large")
    text = path.read_text(encoding="utf-8").strip()
    parts = text.split()
    if "\n" in text or "\r" in text or len(parts) < 2:
        raise ValueError("Supply one OpenSSH public key, not a private key or authorized_keys options")
    if parts[0] not in ("ssh-ed25519", "ssh-rsa", "ecdsa-sha2-nistp256",
                        "ecdsa-sha2-nistp384", "ecdsa-sha2-nistp521",
                        "sk-ssh-ed25519@openssh.com", "sk-ecdsa-sha2-nistp256@openssh.com"):
        raise ValueError("Unsupported public key type")
    base64.b64decode(parts[1], validate=True)
    subprocess.run(["ssh-keygen", "-l", "-f", str(path)], check=True,
                   stdout=subprocess.DEVNULL)
    return path, text


def install_key(directory, key):
    directory.mkdir(parents=True, exist_ok=True)
    directory.chmod(0o700)
    target = directory / "authorized_keys"
    if target.is_symlink():
        raise ValueError("Refusing to modify a symlinked authorized_keys")
    old = target.read_text(encoding="utf-8") if target.exists() else ""
    fingerprint = key.split()[:2]
    if not any(line.split()[:2] == fingerprint for line in old.splitlines()):
        atomic_write(target, old + ("\n" if old and not old.endswith("\n") else "") + key + "\n")
    target.chmod(0o600)


def linux_commands(kind):
    prefix = [] if os.geteuid() == 0 else ["sudo"]
    if shutil.which("apt-get"):
        commands = [["apt-get", "update"], ["apt-get", "install", "-y", "openssh-server"]]
        service = "ssh"
    elif shutil.which("dnf"):
        commands, service = [["dnf", "install", "-y", "openssh-server"]], "sshd"
    elif shutil.which("yum"):
        commands, service = [["yum", "install", "-y", "openssh-server"]], "sshd"
    elif shutil.which("pacman"):
        commands, service = [["pacman", "-S", "--needed", "--noconfirm", "openssh"]], "sshd"
    elif shutil.which("zypper"):
        commands, service = [["zypper", "--non-interactive", "install", "openssh"]], "sshd"
    else:
        raise ValueError("Unsupported Linux package manager; install and start OpenSSH manually")
    if Path("/run/systemd/system").is_dir():
        commands += [["systemctl", "enable", "--now", service]]
    elif kind == "wsl" and shutil.which("service"):
        commands += [["service", service, "start"]]
    else:
        raise ValueError("This Linux host needs systemd; install and start OpenSSH manually")
    return [prefix + command for command in commands]


def setup(args, directory):
    kind = detect()
    key_path, key = public_key(args.public_key) if args.public_key else (None, None)
    if kind != "windows" and os.environ.get("SUDO_USER"):
        raise ValueError("Run as your normal login user; this tool invokes sudo when needed")
    if kind == "windows":
        commands = [["powershell.exe", "-NoProfile", "-File", str(HERE / "setup-windows.ps1")]]
        if key_path:
            commands[0] += ["-PublicKey", str(key_path)]
        if args.apply:
            commands[0] += ["-Apply"]
    elif kind == "macos":
        commands = [["sudo", "systemsetup", "-setremotelogin", "on"]]
    else:
        commands = linux_commands(kind)
    print("Detected:", kind)
    print("Login user:", os.environ.get("USERNAME") or os.environ.get("USER") or "current user")
    if key_path:
        print("Authorize public key:", key_path)
    for command in commands:
        print("  " + (subprocess.list2cmdline(command) if kind == "windows" else shlex.join(command)))
    if args.apply:
        if key and kind != "windows":
            install_key(Path.home() / ".ssh", key)
        for command in commands:
            run(command)
        print("Server setup commands completed. Verify the connection from your local device.")
    else:
        print("Preview only. Add --apply to execute (administrator/sudo access required).")
    if not key:
        print("No key supplied. Use --public-key to authorize your local device's .pub file.")
    if kind == "wsl":
        print("WSL NAT: run wsl-forward.ps1 as Windows Administrator; use the Windows host's LAN IP.")
        print("Without systemd, repeat setup --apply after WSL restarts. See README.md.")
    elif kind == "linux":
        print("If a firewall is enabled, allow TCP 22 from your local device or trusted network.")
    elif kind == "macos":
        print("macOS may require Full Disk Access for your terminal; see README.md.")


def choose_box(boxes, name):
    if not boxes:
        raise ValueError("No devboxes registered. Run add first.")
    names = sorted(boxes)
    if name is None:
        for index, alias in enumerate(names, 1):
            entry = boxes[alias]
            print(f"{index}. {alias}: {entry['user']}@{entry['host']}:{entry['port']}")
        name = input("Connect to name or number: ").strip()
        if name.isdigit() and 1 <= int(name) <= len(names):
            name = names[int(name) - 1]
    if name not in boxes:
        raise ValueError("Unknown devbox: " + name)
    return name


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", action="version", version="devbox " + __version__)
    parser.add_argument("--ssh-dir", type=Path, default=Path.home() / ".ssh",
                        help="Client SSH directory (default: ~/.ssh); server keys always use ~/.ssh")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("detect", help="Identify Windows, macOS, Linux, or WSL")
    server = commands.add_parser("setup", help="Preview or enable this devbox's SSH server")
    server.add_argument("--apply", action="store_true")
    server.add_argument("--public-key", help="Your local device's OpenSSH .pub file")
    keygen = commands.add_parser("keygen", help="Create a named local SSH key (prompts for passphrase)")
    keygen.add_argument("--name", default="devboxes")
    add = commands.add_parser("add", help="Register a devbox and install a native ssh alias")
    add.add_argument("name")
    add.add_argument("host")
    add.add_argument("--user", required=True)
    add.add_argument("--port", type=int, default=22)
    add.add_argument("--identity", help="Private key path; defaults to id_ed25519_devboxes if it exists")
    add.add_argument("--replace", action="store_true", help="Update an existing alias")
    commands.add_parser("list", help="List named connections")
    remove = commands.add_parser("remove", help="Remove a managed alias")
    remove.add_argument("name")
    connect = commands.add_parser("connect", help="Connect by name, or select from a menu")
    connect.add_argument("name", nargs="?")
    check = commands.add_parser("check", help="Check key authentication without prompting")
    check.add_argument("name")
    args = parser.parse_args(argv)
    directory = args.ssh_dir.expanduser().resolve()
    if args.command == "detect":
        print(detect())
    elif args.command == "setup":
        setup(args, directory)
    elif args.command == "keygen":
        name = valid_name(args.name)
        directory.mkdir(parents=True, exist_ok=True)
        private_permissions(directory, directory=True)
        key = directory / ("id_ed25519_" + name)
        if key.exists() or Path(str(key) + ".pub").exists():
            raise ValueError("Key already exists; refusing to overwrite: " + str(key))
        run(["ssh-keygen", "-t", "ed25519", "-f", key, "-C", "devbox-" + name])
        print("Copy only this public key to each devbox:", str(key) + ".pub")
    else:
        boxes = load_boxes(directory)
        if args.command == "add":
            identity = Path(args.identity).expanduser().resolve() if args.identity else directory / "id_ed25519_devboxes"
            if args.identity and not identity.is_file():
                raise ValueError("Private key not found: " + str(identity))
            entry = {"host": args.host, "user": args.user, "port": args.port,
                     "identity": str(identity) if identity.is_file() else None}
            validate_entry(args.name, entry)
            if args.name in boxes and not args.replace:
                raise ValueError("Alias already exists; use --replace to update it")
            boxes[args.name] = entry
            save_boxes(directory, boxes)
            print("Registered. Connect with: ssh " + args.name)
        elif args.command == "remove":
            if args.name not in boxes:
                raise ValueError("Unknown devbox: " + args.name)
            del boxes[args.name]
            save_boxes(directory, boxes)
            print("Removed:", args.name)
        elif args.command == "list":
            for name, entry in sorted(boxes.items()):
                print(f"{name:16} {entry['user']}@{entry['host']}:{entry['port']}")
        else:
            name = choose_box(boxes, args.name)
            command = ["ssh", "-F", str(directory / "config")]
            if args.command == "check":
                command += ["-o", "BatchMode=yes", "-o", "ConnectTimeout=8"]
            command += [name]
            if args.command == "check":
                command += ["exit"]
            return subprocess.call(command)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, subprocess.CalledProcessError, KeyError, TypeError) as error:
        print("Error:", error, file=sys.stderr)
        sys.exit(1)
    except (KeyboardInterrupt, EOFError):
        sys.exit(130)
