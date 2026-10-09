import contextlib
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import devbox


class DevboxTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="devbox-ssh-test-")
        self.addCleanup(self.cleanup_temporary)
        self.directory = Path(self.temporary.name) / "ssh with spaces"

    def cleanup_temporary(self):
        path = Path(self.temporary.name)
        self.temporary.cleanup()
        self.assertFalse(path.exists(), "Task-owned test directory was not cleaned up")

    def invoke(self, *args):
        with contextlib.redirect_stdout(io.StringIO()):
            return devbox.main(["--ssh-dir", str(self.directory), *args])

    def test_platform_detection(self):
        for system, release, expected in [("Windows", "10", "windows"),
                                          ("Darwin", "24", "macos"),
                                          ("Linux", "6.1", "linux"),
                                          ("Linux", "5.15-microsoft-standard-WSL2", "wsl")]:
            with self.subTest(expected=expected), patch.dict(os.environ, {}, clear=True), \
                    patch("platform.system", return_value=system), patch("platform.release", return_value=release):
                self.assertEqual(devbox.detect(), expected)

    def test_add_replace_remove_preserves_config(self):
        self.directory.mkdir()
        config = self.directory / "config"
        original = "# Personal settings\nHost personal\n    HostName example.org\nHost *\n    ConnectTimeout 15\n"
        config.write_text(original)
        self.invoke("add", "dev1", "192.168.1.10", "--user", "alice")
        self.invoke("add", "dev2", "mac.local", "--user", "bob")
        with self.assertRaises(ValueError):
            self.invoke("add", "dev1", "other.local", "--user", "alice")
        self.invoke("add", "dev1", "192.168.1.20", "--user", "alice", "--port", "2222", "--replace")
        self.assertEqual(config.read_text().count("Include "), 1)
        self.assertTrue(config.read_text().endswith(original))
        boxes = devbox.load_boxes(self.directory)
        self.assertEqual(boxes["dev1"]["port"], 2222)
        self.invoke("remove", "dev2")
        self.assertNotIn("dev2", devbox.load_boxes(self.directory))
        self.assertNotIn("Host dev2", (self.directory / "devbox-ssh.conf").read_text())

    @unittest.skipUnless(shutil.which("ssh"), "OpenSSH unavailable")
    def test_native_ssh_resolves_managed_alias_and_original_config(self):
        self.directory.mkdir()
        (self.directory / "config").write_text("Host personal\n    HostName original.example\n")
        key = self.directory / "key with spaces"
        key.write_text("test private key placeholder")
        self.invoke("add", "dev1", "2001:db8::42", "--user", "alice", "--port", "2222", "--identity", str(key))
        def settings(name):
            result = subprocess.run(["ssh", "-G", "-F", str(self.directory / "config"), name],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            return dict(line.split(" ", 1) for line in result.stdout.splitlines())
        parsed = settings("dev1")
        self.assertEqual(parsed["hostname"], "2001:db8::42")
        self.assertEqual(parsed["port"], "2222")
        self.assertEqual(parsed["user"], "alice")
        self.assertEqual(parsed["identityfile"], key.resolve().as_posix())
        self.assertEqual(settings("personal")["hostname"], "original.example")
        self.invoke("add", "domainbox", "host", "--user", r"DOMAIN\alice")
        self.assertEqual(settings("domainbox")["user"], r"DOMAIN\alice")

    def test_invalid_inputs_do_not_write_config(self):
        for args in [("bad*", "host", "alice", "22"),
                     ("dev1", "host\nProxyCommand evil", "alice", "22"),
                     ("dev1", "host", "alice\nHost *", "22"),
                     ("dev1", "host", "alice", "0"),
                     ("dev1", "host", "alice", "65536")]:
            with self.subTest(args=args), self.assertRaises(ValueError):
                self.invoke("add", args[0], args[1], "--user", args[2], "--port", args[3])
        self.assertFalse(self.directory.exists())

    def test_keygen_refuses_existing_key(self):
        self.directory.mkdir()
        key = self.directory / "id_ed25519_devboxes"
        key.write_text("do not overwrite")
        with patch("devbox.run") as run, self.assertRaises(ValueError):
            self.invoke("keygen")
        run.assert_not_called()
        self.assertEqual(key.read_text(), "do not overwrite")

    @unittest.skipUnless(shutil.which("ssh-keygen"), "OpenSSH unavailable")
    def test_public_key_validation_and_idempotent_authorization(self):
        key = Path(self.temporary.name) / "test_key"
        subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(key)], check=True)
        _, text = devbox.public_key(str(key) + ".pub")
        with patch("devbox.detect", return_value="macos"), patch("devbox.run") as run:
            self.invoke("setup", "--public-key", str(key) + ".pub")
            run.assert_not_called()
        self.assertFalse(self.directory.exists())
        devbox.install_key(self.directory, text)
        devbox.install_key(self.directory, text)
        self.assertEqual((self.directory / "authorized_keys").read_text(), text + "\n")
        for content in [key.read_text(), 'command="bad" ' + text, text + "\n" + text]:
            bad = Path(self.temporary.name) / "bad.pub"
            bad.write_text(content)
            with self.assertRaises(ValueError):
                devbox.public_key(bad)

    @unittest.skipIf(os.name == "nt", "POSIX symlink test")
    def test_symlinked_config_is_preserved(self):
        self.directory.mkdir()
        outside = Path(self.temporary.name) / "original-config"
        outside.write_text("keep me")
        (self.directory / "config").symlink_to(outside)
        with self.assertRaises(ValueError):
            self.invoke("add", "dev1", "host", "--user", "alice")
        self.assertEqual(outside.read_text(), "keep me")
        self.assertTrue((self.directory / "config").is_symlink())

    def test_check_keeps_host_key_verification_and_propagates_exit(self):
        self.invoke("add", "dev1", "host", "--user", "alice")
        with patch("subprocess.call", return_value=255) as call:
            self.assertEqual(self.invoke("check", "dev1"), 255)
        command = call.call_args.args[0]
        self.assertIn("BatchMode=yes", command)
        self.assertEqual(command[-2:], ["dev1", "exit"])
        self.assertFalse(any("StrictHostKeyChecking" in value for value in command))

    def test_setup_authorizes_default_server_directory_with_client_override(self):
        with patch("devbox.detect", return_value="macos"), patch("devbox.run"), \
                patch("devbox.public_key", return_value=(Path("local.pub"), "public key")), \
                patch("devbox.install_key") as install, patch.dict(os.environ, {"SUDO_USER": ""}):
            self.invoke("setup", "--public-key", "local.pub", "--apply")
        install.assert_called_once_with(Path.home() / ".ssh", "public key")

    @unittest.skipUnless(shutil.which("ssh-keygen"), "OpenSSH unavailable")
    def test_setup_discovers_two_clients_beside_script_and_preserves_existing_keys(self):
        bundle = Path(self.temporary.name) / "ssh-script"
        public_keys = bundle / "pub-keys"
        public_keys.mkdir(parents=True)
        texts = []
        for name in ("desktop", "laptop"):
            # Keep test private keys outside the discovery folder, as users should.
            key = Path(self.temporary.name) / name
            subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(key)], check=True)
            copied = public_keys / (name + ".pub")
            shutil.copyfile(str(key) + ".pub", copied)
            texts.append(copied.read_text().strip())
        (public_keys / "notes.txt").write_text("not a key")
        (public_keys / "nested").mkdir()
        (public_keys / "nested" / "ignored.pub").write_text("invalid nested key")
        (public_keys / "directory.pub").mkdir()
        server_home = Path(self.temporary.name) / "remote-home"
        server_ssh = server_home / ".ssh"
        server_ssh.mkdir(parents=True)
        authorized = server_ssh / "authorized_keys"
        original = "# Keep existing access\nssh-ed25519 AAAA existing-client\n"
        authorized.write_text(original)

        # HERE differs from the current directory and the --ssh-dir client override.
        for kind in ("linux", "wsl", "macos", "windows"):
            with self.subTest(kind=kind), patch("devbox.HERE", bundle), \
                    patch("devbox.detect", return_value=kind), \
                    patch("devbox.linux_commands", return_value=[["test-service"]]), \
                    patch("devbox.run") as run, patch("devbox.Path.home", return_value=server_home), \
                    patch.dict(os.environ, {"SUDO_USER": ""}):
                output = io.StringIO()
                with contextlib.redirect_stdout(output):
                    devbox.main(["setup"])
                self.assertIn(str(public_keys / "laptop.pub"), output.getvalue())
                self.assertIn(str(public_keys / "desktop.pub"), output.getvalue())
                run.assert_not_called()
                self.assertEqual(authorized.read_text(), original)
                self.invoke("setup", "--apply")
                self.invoke("setup", "--apply")
                if kind == "windows":
                    command = run.call_args.args[0]
                    self.assertEqual(command[0], "powershell.exe")
                    self.assertEqual(command[command.index("-File") + 1], str(bundle / "setup-windows.ps1"))
                    self.assertNotIn("-PublicKey", command)
                    self.assertIn("-Apply", command)
                    self.assertEqual(authorized.read_text(), original)
                else:
                    self.assertEqual(authorized.read_text(), original + "\n".join(texts) + "\n")
                authorized.write_text(original)
        self.assertFalse(self.directory.exists())

    def test_setup_rejects_invalid_discovered_key_before_any_changes(self):
        bundle = Path(self.temporary.name) / "ssh-script"
        public_keys = bundle / "pub-keys"
        public_keys.mkdir(parents=True)
        (public_keys / "a-good.pub").write_text("placeholder")
        (public_keys / "z-bad.pub").write_text("private key")
        def validate(path):
            if path.name == "z-bad.pub":
                raise ValueError("Invalid public key")
            return path, "valid public key"
        for kind in ("macos", "windows"):
            with self.subTest(kind=kind), patch("devbox.HERE", bundle), \
                    patch("devbox.detect", return_value=kind), \
                    patch("devbox.public_key", side_effect=validate), \
                    patch("devbox.run") as run, patch("devbox.install_key") as install:
                with self.assertRaisesRegex(ValueError, "Invalid public key"):
                    self.invoke("setup", "--apply")
                run.assert_not_called()
                install.assert_not_called()

    def test_explicit_key_overrides_folder_including_invalid_keys(self):
        bundle = Path(self.temporary.name) / "ssh-script"
        public_keys = bundle / "pub-keys"
        public_keys.mkdir(parents=True)
        (public_keys / "bad.pub").write_text("not a public key")
        selected = Path(self.temporary.name) / "selected.pub"
        for kind in ("macos", "windows"):
            with self.subTest(kind=kind), patch("devbox.HERE", bundle), \
                    patch("devbox.detect", return_value=kind), patch("devbox.run") as run, \
                    patch("devbox.public_key", return_value=(selected, "selected key")) as validate, \
                    patch("devbox.install_key") as install, patch.dict(os.environ, {"SUDO_USER": ""}):
                self.invoke("setup", "--public-key", str(selected), "--apply")
                validate.assert_called_once_with(selected)
                if kind == "windows":
                    command = run.call_args.args[0]
                    self.assertEqual(command[command.index("-PublicKey") + 1], str(selected))
                    install.assert_not_called()
                else:
                    install.assert_called_once_with(Path.home() / ".ssh", "selected key")

    def test_setup_reports_missing_or_empty_discovery_folder(self):
        bundle = Path(self.temporary.name) / "ssh-script"
        for present in (False, True):
            if present:
                (bundle / "pub-keys").mkdir(parents=True)
            with self.subTest(present=present), patch("devbox.HERE", bundle), \
                    patch("devbox.detect", return_value="macos"), \
                    patch("devbox.run") as run, patch("devbox.install_key") as install:
                output = io.StringIO()
                with contextlib.redirect_stdout(output):
                    devbox.main(["setup"])
                self.assertIn("No public keys found", output.getvalue())
                self.assertIn(str(bundle / "pub-keys"), output.getvalue())
                run.assert_not_called()
                install.assert_not_called()

    def test_setup_preview_does_not_execute_or_authorize(self):
        with patch("devbox.detect", return_value="macos"), patch("devbox.run") as run, \
                patch("devbox.install_key") as install:
            self.invoke("setup")
        run.assert_not_called()
        install.assert_not_called()
        self.assertFalse(self.directory.exists())

    def test_windows_setup_dispatch_and_explicit_apply(self):
        with patch("devbox.detect", return_value="windows"), patch("devbox.run") as run:
            self.invoke("setup")
            run.assert_not_called()
            self.invoke("setup", "--apply")
        command = run.call_args.args[0]
        self.assertEqual(command[0], "powershell.exe")
        self.assertTrue(command[command.index("-File") + 1].endswith("setup-windows.ps1"))
        self.assertIn("-Apply", command)

    def test_wsl_without_systemd_uses_service_start(self):
        with patch("shutil.which", side_effect=lambda name: '/usr/bin/' + name if name in ('apt-get', 'service') else None), \
                patch.object(Path, "is_dir", return_value=False), \
                patch("os.geteuid", return_value=1000, create=True):
            commands = devbox.linux_commands("wsl")
        self.assertEqual(commands[-1], ["sudo", "service", "ssh", "start"])


if __name__ == "__main__":
    unittest.main()
