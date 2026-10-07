# Devbox SSH

A standalone tool for Windows, macOS, Linux, and WSL. Run server setup on each
devbox, then register named connections on any local device. No Python packages
are needed; requires **Python 3.9+** and the **OpenSSH client** (`ssh`, `ssh-keygen`).

The source lives at `tools/ssh-script/` in this repository. You can use it
directly, or install a versioned per-user copy with the matching scaffolder:

```sh
# From the repository root: Linux/WSL, or use macos/ on a Mac.
bash linux/tools/36-ssh-script.sh
```

```powershell
# From the repository root on Windows; no elevation needed to copy the tool.
.\windows\tools\36-ssh-script.ps1
```

On Linux/macOS/WSL, the installed folder is
`~/.local/share/dev-scaffolder/ssh-script`; on Windows it is
`%LOCALAPPDATA%\dev-scaffolder\ssh-script`. Change into that folder to use the
commands below. Re-running the installer upgrades changed versions and repairs
missing bundle files. `DEVBOX_SSH_HOME` overrides the install folder. Installing
the tool does not enable an SSH server or change your SSH settings.

Use `python3 devbox.py` on macOS/Linux/WSL and `py -3 devbox.py` on Windows.
All examples assume your terminal is in this folder. Copy this folder to each
devbox before setup. This tool does not discover machines or create a VPN: use
reachable LAN IPs, DNS names, or existing Tailscale hostnames. Across different
networks, a VPN such as Tailscale avoids router port forwarding.

## Quick start

Run these commands from the `ssh-script` folder. On Windows, replace `python3`
with `py -3`. The addresses and usernames below are examples; use your own.

### Quickly set up an SSH server

**On your local device, once:** create the key you will use to connect.

```sh
python3 devbox.py keygen --name devboxes
```

Copy **`~/.ssh/id_ed25519_devboxes.pub`** into the `ssh-script` folder on each
devbox, using your existing access or a USB drive. For WSL, copy it into the
folder inside the distro. Keep the private file (without `.pub`) on your local
device.

**On each Linux, macOS, or WSL devbox:** preview, then apply server setup.

```sh
python3 devbox.py setup --public-key ./id_ed25519_devboxes.pub
python3 devbox.py setup --public-key ./id_ed25519_devboxes.pub --apply
```

**On each native Windows devbox:** use Administrator PowerShell as the account
you intend to log in to.

```powershell
py -3 devbox.py setup --public-key .\id_ed25519_devboxes.pub
py -3 devbox.py setup --public-key .\id_ed25519_devboxes.pub --apply
```

Setup detects the OS automatically. Native servers normally listen on port **22**.

**For WSL2 NAT, also run on its Windows host in Administrator PowerShell:**
replace `Ubuntu` with your distro name and `192.168.1.20` with the Windows host's
LAN IPv4 address.

```powershell
.\wsl-forward.ps1 -Distro Ubuntu -ListenAddress 192.168.1.20 -Apply
```

Connect to that WSL server using **the Windows host's address and port 2222**.
Rerun forwarding after WSL's IP changes. See [WSL networking details](#wsl-networking-details)
for finding the address, previewing changes, and other WSL networking modes.

### Quickly connect to a named SSH server

**Back on your local device:** save a name once, then connect.

```sh
python3 devbox.py add dev1 192.168.1.10 --user alice
ssh dev1
```

`dev1` is the shortcut you choose; `192.168.1.10` is that devbox's reachable
address; `alice` is the login account **on that devbox**. The `devboxes` key from
setup is selected automatically. Saving the alias is a local operation; it does
not rename the server. On the first connection, verify its host-key fingerprint
using your existing access before accepting it.

**Save your other three devboxes:** this example includes macOS, WSL, and a
Linux machine reachable through an existing Tailscale network.

```sh
python3 devbox.py add dev2 mac-mini.local --user alice
python3 devbox.py add dev3 192.168.1.20 --user felix --port 2222
python3 devbox.py add dev4 my-linux.tailnet-name.ts.net --user ubuntu
```

**Everyday use:** connect directly to a saved name, or choose from the menu.

```sh
ssh dev3
python3 devbox.py connect
```

## Server setup details

`setup` previews operations; `setup --apply` installs/enables the server and
authorizes the supplied public key. Run setup on the devbox that will accept
connections, and run `add`/`connect` on your local device. You can check detection
separately with `python3 devbox.py detect`.

Setup preserves the server's existing SSH configuration and authentication
settings; it does not disable password login. If you already configured a
different server port, use that port when registering the connection. Commands
stop on failure and report the error; earlier successful installation steps
remain and can be rerun.

- **Linux:** supports apt, dnf, yum, pacman, and zypper with systemd. Run as your
  normal login user; the tool uses `sudo` for installation and service changes.
  If you have a firewall, allow the actual SSH port from your trusted network.
- **macOS:** uses built-in Remote Login. Run as your normal login user. macOS
  may require your terminal to have Full Disk Access for `systemsetup`. You can
  also enable **System Settings → General → Sharing → Remote Login** yourself;
  ensure your login account is allowed. Apple includes OpenSSH; install Python
  separately if absent.
- **Windows:** run `py -3 devbox.py setup --public-key C:\path\key.pub --apply`
  in Administrator PowerShell as the intended login account. It installs the
  Windows OpenSSH Server capability, starts `sshd`, sets automatic startup, and
  adds a LAN-scoped firewall rule. Existing firewall rules are preserved, so an
  existing broader OpenSSH rule may still allow other networks. Default Windows
  OpenSSH Administrator logins use `%ProgramData%\ssh\administrators_authorized_keys`:
  the helper writes there and sets SYSTEM/Administrators-only permissions.
  **A key in that file can authenticate as other Administrator accounts too.**
  For a non-Administrator login, authorize the public key separately in that
  user's `%USERPROFILE%\.ssh\authorized_keys`, with appropriate user-only ACLs.
  A customized `sshd_config` may specify a different key location.
- **WSL:** detected separately from native Linux. Installs OpenSSH inside the
  distro. With systemd, service startup is enabled for subsequent distro starts.
  Without systemd, `service ssh start` starts it for the current session; repeat
  setup after a restart. To enable systemd on supported WSL versions, add
  `systemd=true` to the `[boot]` section of `/etc/wsl.conf`, preserving other
  settings, then restart WSL when convenient. This tool does not edit that file
  or shut down running distros.

If Windows lacks `ssh`/`ssh-keygen`, install **OpenSSH Client** via Windows
Optional Features (or `Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0`
in Administrator PowerShell).

Windows helpers are ordinary `.ps1` files and must be permitted by your
PowerShell execution policy. Copy this folder onto the Windows device before
running them; network/WSL UNC paths may be treated as untrusted. If your
organization requires signed scripts, follow that policy. The tool does not
change execution policy.

### WSL networking details

In **Windows Administrator PowerShell**, find the distro name and the Windows
host's LAN IPv4 address:

```powershell
wsl --list --verbose
Get-NetIPAddress -AddressFamily IPv4
```

Use that address, not WSL's internal address, for `ListenAddress`:

```powershell
.\wsl-forward.ps1 -Distro Ubuntu -ListenAddress 192.168.1.20
.\wsl-forward.ps1 -Distro Ubuntu -ListenAddress 192.168.1.20 -Apply
```

This exposes **Windows-host port 2222 → WSL port 22** and adds a LAN-scoped
firewall rule. It refuses an unrelated listener/mapping at that address and port.
Preview queries (and may start) the selected distro but does not change forwarding
or firewall settings. Rerun with `-Apply` after WSL restarts or its IP changes.
The Windows host must be awake and the distro/SSH service running. Use `-Port`
for a different host port or `-WslPort` for a customized WSL server port. Multiple
distros need different host ports.

Remove a forwarding rule created by this helper:

```powershell
.\wsl-forward.ps1 -Distro Ubuntu -ListenAddress 192.168.1.20 -Remove -Apply
```

This helper targets **WSL2 NAT**. WSL1 and WSL mirrored networking have different
reachability/firewall requirements; don't use this forwarding helper for them.
For mirrored networking, configure Windows/Hyper-V firewall access to the
WSL SSH port yourself, avoiding a collision with native Windows SSH. An existing
VPN running inside WSL is another way to give the distro a reachable hostname.

## Keys and connection settings

Key generation prompts for a passphrase and refuses to overwrite existing keys.
Each local device should generate its own key and authorize its public key on
the devboxes. Optionally load your private key into your system's SSH agent to
avoid entering its passphrase for each connection:

```sh
ssh-add ~/.ssh/id_ed25519_devboxes
```

The agent must already be running. On Windows, enable/start the `ssh-agent`
service in Administrator PowerShell, then run `ssh-add` in your normal terminal.

If `id_ed25519_devboxes` exists, it is selected automatically. For another named
key, add `--identity /path/to/private-key`. Without a selected key, OpenSSH uses
your normal agent/default identities and authentication settings. IPv6 addresses
should be supplied without brackets.

The tool stores its registry and generated config in `~/.ssh/devbox-ssh.json`
and `~/.ssh/devbox-ssh.conf`. It prepends an `Include` to `~/.ssh/config`, retaining
existing content. Pick alias names not already used in that config: the managed
alias settings take precedence. Do not edit the generated config manually.

## Manage saved connections

List aliases, update a changed address, or connect by name through the tool:

```sh
python3 devbox.py list
python3 devbox.py add dev1 192.168.1.11 --user alice --replace
python3 devbox.py connect dev1
```

After your first verified connection, check authentication without prompting,
or remove a saved alias. `check` requires a loaded agent for a
passphrase-protected key:

```sh
python3 devbox.py check dev1
python3 devbox.py remove dev4
```

`remove` removes only the managed alias; it does not delete keys or disable SSH.
Connection/check commands return SSH's exit code. Run `python3 devbox.py --help`
for the command list. Global `--ssh-dir PATH` selects a separate directory for client keys, aliases, and config.
Server setup always authorizes keys in the login user's default `~/.ssh` directory
on macOS, Linux, and WSL, so stock sshd can find them.

## Validation

```sh
python3 -B -m unittest discover -s tests -v
```

Tests use temporary directories, mocked platform/service calls, and a real
OpenSSH config parser when available. They do not install services or change
your own SSH configuration. Native Windows/macOS service setup and WSL port
forwarding still require validation on those machines.

Run the tests from the source folder in the repository; tests are not copied
into the installed bundle. `python3 devbox.py --version` reports the tool version.
