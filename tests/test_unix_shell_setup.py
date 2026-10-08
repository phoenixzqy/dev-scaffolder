"""Hermetic shell-setup regressions; never install packages or touch real profiles."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ShellSetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="scaffolder-shell-test-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.env = {"HOME": str(self.home), "PATH": "/usr/bin:/bin",
                    "USER": "test-user", "SHELL": "/bin/bash"}
        self.bin = self.home / "custom tools/bin"
        self.bin.mkdir(parents=True)

    def run_bash(self, script, **env):
        result = subprocess.run(["bash", "-c", script], cwd=ROOT,
                                env=dict(self.env, **env), text=True,
                                capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout

    def executable(self, name, body):
        path = self.bin / name
        path.write_text("#!/usr/bin/env bash\n" + body + "\n")
        path.chmod(0o755)
        return path

    def init_stubs(self, platform, body):
        init = self.home / "bash-env"
        init.write_text(f'source "{ROOT / platform / "lib/common.sh"}"\n'
                        # Tools source common.sh again; retain hermetic stubs.
                        'source() { case "$1" in */lib/common.sh) return 0;; '
                        '*) builtin source "$@";; esac; }\n' + body)
        return {"BASH_ENV": str(init)}

    def test_profiles_preserve_user_path_symlinks_and_repeated_install(self):
        self.assertIsNotNone(shutil.which("zsh"), "Install zsh to run these regressions")
        for platform in ("linux", "macos"):
            with self.subTest(platform=platform):
                zdot = self.home / platform
                zdot.mkdir()
                original = self.home / (platform + "-dotfile")
                original.write_text('export PATH="$HOME/custom tools/bin:$PATH"\n'
                                    'export USER_INIT_COUNT=$(( ${USER_INIT_COUNT:-0} + 1 ))\n')
                rc = zdot / ".zshrc"
                rc.symlink_to(original)
                omz = self.home / ".oh-my-zsh"
                omz.mkdir(exist_ok=True)
                (omz / "oh-my-zsh.sh").write_text("")
                copilot = self.executable("copilot", "echo existing-copilot")
                deploy = (f'source {platform}/lib/common.sh\n'
                          'source lib/shell-profile.sh\ndeploy_zsh_profile\n')
                self.run_bash(deploy, ZDOTDIR=str(zdot))
                first = rc.read_bytes()
                self.run_bash(deploy, ZDOTDIR=str(zdot))
                self.assertTrue(rc.is_symlink())
                self.assertEqual(rc.read_bytes(), first)
                backups = list(zdot.glob(".zshrc.bak.*"))
                self.assertEqual(len(backups), 1)
                self.assertIn('export PATH=', backups[0].read_text())
                result = subprocess.run(
                    ["zsh", "-ic", 'command -v copilot; copilot; echo "$USER_INIT_COUNT"'],
                    env=dict(self.env, ZDOTDIR=str(zdot)), text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.splitlines(), [str(copilot), "existing-copilot", "1"])

    def test_fresh_profile_supports_native_copilot_and_custom_nvm_dir(self):
        for platform in ("linux", "macos"):
            with self.subTest(platform=platform):
                zdot = self.home / platform
                zdot.mkdir()
                nvm = self.home / "custom nvm"
                nvm.mkdir(exist_ok=True)
                (nvm / "nvm.sh").write_text('export NVM_LOADED=yes\n')
                omz = self.home / ".oh-my-zsh"
                omz.mkdir(exist_ok=True)
                (omz / "oh-my-zsh.sh").write_text("")
                native = self.home / ".local/bin/copilot"
                native.parent.mkdir(parents=True, exist_ok=True)
                native.write_text("#!/bin/sh\necho native\n")
                native.chmod(0o755)
                self.run_bash(f'source {platform}/lib/common.sh\n'
                              'source lib/shell-profile.sh\ndeploy_zsh_profile', ZDOTDIR=str(zdot))
                result = subprocess.run(["zsh", "-ic", 'copilot; echo "$NVM_LOADED"'],
                    env=dict(self.env, ZDOTDIR=str(zdot), NVM_DIR=str(nvm)),
                    text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.splitlines(), ["native", "yes"])

    def test_copilot_existing_install_skips_nvm_and_npm(self):
        self.executable("copilot", "echo installed")
        for platform in ("linux", "macos"):
            with self.subTest(platform=platform):
                env = self.init_stubs(platform, 'load_nvm() { exit 81; }\n'
                                      'npm() { exit 82; }\n')
                self.run_bash(f'bash {platform}/tools/60-copilot-cli.sh',
                              PATH=str(self.bin) + ":/usr/bin:/bin", **env)

    def test_copilot_found_after_nvm_skips_npm(self):
        self.executable("copilot", "echo installed")
        for platform in ("linux", "macos"):
            with self.subTest(platform=platform):
                env = self.init_stubs(platform,
                    'load_nvm() { export PATH="$HOME/custom tools/bin:$PATH"; }\n'
                    'npm() { exit 82; }\n')
                self.run_bash(f'bash {platform}/tools/60-copilot-cli.sh', **env)

    def test_copilot_missing_uses_npm_fallback(self):
        for platform in ("linux", "macos"):
            with self.subTest(platform=platform):
                env = self.init_stubs(platform, 'load_nvm() { :; }\n'
                    'npm() { if [[ "$1" == ls ]]; then return 1; fi; '
                    'echo "$*" >> "$HOME/npm-calls"; }\n')
                log = self.home / "npm-calls"
                log.unlink(missing_ok=True)
                self.run_bash(f'bash {platform}/tools/60-copilot-cli.sh', **env)
                self.assertEqual(log.read_text().strip(),
                                 f'install -g --prefix {self.home}/.local @github/copilot --silent')

    def test_user_local_fallback_wires_bash_and_zsh_without_losing_paths(self):
        for shell in ("bash", "zsh"):
            with self.subTest(shell=shell):
                rc = self.home / (".bashrc" if shell == "bash" else ".zshrc")
                rc.write_text('export PATH="$HOME/custom tools/bin:/usr/bin:/bin"\n')
                self.executable("existing-tool", "echo existing-tool")
                copilot = self.home / ".local/bin/copilot"
                copilot.parent.mkdir(parents=True, exist_ok=True)
                copilot.write_text("#!/bin/sh\necho installed-copilot\n")
                copilot.chmod(0o755)
                self.run_bash('source linux/lib/common.sh\n'
                              'source lib/shell-profile.sh\nwire_local_bin', SHELL="/bin/" + shell)
                first = rc.read_bytes()
                self.run_bash('source linux/lib/common.sh\n'
                              'source lib/shell-profile.sh\nwire_local_bin', SHELL="/bin/" + shell)
                self.assertEqual(rc.read_bytes(), first)
                output = self.run_bash('source "$HOME/' + rc.name + '"\n'
                                       'copilot\nexisting-tool')
                self.assertEqual(output.splitlines(), ["installed-copilot", "existing-tool"])
                if shell == "bash":
                    self.assertIn('dev-scaffolder local bin', (self.home / ".profile").read_text())

    def test_node_keeps_fixed_and_floating_defaults_and_sets_fresh_default(self):
        nvm = self.home / ".nvm"
        (nvm / "alias/lts").mkdir(parents=True)
        (nvm / "nvm.sh").write_text("# installed\n")
        default = nvm / "alias/default"
        lts = nvm / "alias/lts/*"
        ready = self.home / "node-ready"
        for platform in ("linux", "macos"):
            for existing in ("v20.19.0", "lts/*", None):
                with self.subTest(platform=platform, existing=existing):
                    ready.unlink(missing_ok=True)
                    lts.write_text("v20.19.0\n")
                    if existing:
                        default.write_text(existing + "\n")
                    else:
                        default.unlink(missing_ok=True)
                    env = self.init_stubs(platform,
                        'has_command() { if [[ "$1" == node ]]; then '
                        '[[ -f "$HOME/node-ready" ]]; else command -v "$1" &>/dev/null; fi; }\n'
                        'load_nvm() { if [[ -f "$NVM_DIR/alias/default" ]]; then '
                        'touch "$HOME/node-ready"; fi; }\n'
                        'nvm() { if [[ "$1" == install ]]; then '
                        'echo v24 > "$NVM_DIR/alias/lts/*"; '
                        'touch "$HOME/node-ready"; '
                        'elif [[ "$1" == alias ]]; then '
                        'echo "$3" > "$NVM_DIR/alias/default"; fi; }\n'
                        'npm() { :; }\n')
                    self.run_bash(f'bash {platform}/tools/20-node.sh', **env)
                    self.assertEqual(default.read_text().strip(), existing or 'lts/*')
                    self.assertEqual(lts.read_text().strip(), 'v20.19.0' if existing else 'v24')

    def test_existing_node_runtime_skips_nvm_installation(self):
        for platform in ("linux", "macos"):
            with self.subTest(platform=platform):
                env = self.init_stubs(platform, 'node() { :; }\nnpm() { :; }\n'
                                      'load_nvm() { exit 85; }\n'
                                      'run_remote_script() { exit 86; }\n')
                self.run_bash(f'bash {platform}/tools/20-node.sh', **env)
                self.assertFalse((self.home / ".nvm").exists())

    def test_managed_profile_and_load_nvm_keep_inherited_node_path(self):
        self.assertIsNotNone(shutil.which("zsh"), "Install zsh to run these regressions")
        self.executable("node", "echo old-node")
        copilot = self.executable("copilot", "echo old-copilot")
        nvm = self.home / ".nvm"
        nvm.mkdir()
        # nvm normally strips the inherited Node path when selecting a default.
        (nvm / "nvm.sh").write_text('if [ "${1:-}" != --no-use ]; then '
                                     'export PATH=/usr/bin:/bin; fi\n')
        omz = self.home / ".oh-my-zsh"
        omz.mkdir()
        (omz / "oh-my-zsh.sh").write_text("")
        path = str(self.bin) + ":/usr/bin:/bin"
        for platform in ("linux", "macos"):
            with self.subTest(platform=platform):
                output = self.run_bash(f'source {platform}/lib/common.sh\n'
                                       'load_nvm\ncommand -v copilot', PATH=path)
                self.assertEqual(output.strip(), str(copilot))
                result = subprocess.run(
                    ["zsh", "-c", f'source {platform}/configs/zsh/.zshrc; command -v copilot'],
                    cwd=ROOT, env=dict(self.env, PATH=path), text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), str(copilot))

    def test_zsh_installers_preserve_login_shell_and_existing_profile(self):
        for platform in ("linux", "macos"):
            with self.subTest(platform=platform):
                zdot = self.home / platform
                zdot.mkdir()
                (zdot / ".zshrc").write_text('# personal config\n')
                omz = self.home / ".oh-my-zsh"
                for plugin in ("zsh-autosuggestions", "zsh-syntax-highlighting"):
                    (omz / "custom/plugins" / plugin).mkdir(parents=True, exist_ok=True)
                env = self.init_stubs(platform, 'apt_install() { :; }\n'
                    'brew_install() { :; }\ngit() { :; }\n'
                    'chsh() { exit 83; }\nas_root() { exit 84; }\n')
                self.run_bash(f'bash {platform}/tools/12-zsh-profile.sh', ZDOTDIR=str(zdot), **env)
                self.assertIn('# personal config', (zdot / ".zshrc").read_text())


if __name__ == "__main__":
    unittest.main()
