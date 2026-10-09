# Devbox SSH

Connect to **four remote devboxes** from **one or two local devices** using
shortcuts such as `ssh dev1`. Supports Windows, macOS, Linux, and WSL with
Python **3.9+** and the **OpenSSH client** (`ssh`, `ssh-keygen`); no Python
packages are needed.

## Which machine does what?

| Machine | Role | Commands you run there | Key it needs |
| --- | --- | --- | --- |
| Local device 1, e.g. your laptop | SSH client: starts connections | `keygen`, `add`, `connect`, or `ssh dev1` | Its own private key in `~/.ssh/` |
| Local device 2, e.g. your desktop (optional) | Another SSH client | `keygen`, `add`, `connect`, or `ssh dev1` | Its own separate private key in `~/.ssh/` |
| Remote devboxes 1–4 | SSH servers: accept connections | `setup`, then `setup --apply` | Public keys from the local devices allowed to connect |

**Run `keygen` on each local device. Run `setup` on each remote devbox.**
Keep each private key on the local device that generated it. Copy only the
matching `.pub` file to the remote devboxes. You do not need to generate client
keys on the remote devboxes to accept connections.

## Quick start

Every step below identifies the machine where it runs. Examples use a laptop,
an optional desktop, and four devboxes; replace the addresses and remote login
usernames with yours.

### 1. On every machine: get the tool

Clone or copy this repository onto each local device and each remote devbox.
From the **repository root on that machine**, enter the tool folder:

```sh
# Linux, macOS, or WSL
cd tools/ssh-script
```

```powershell
# Native Windows
Set-Location tools\ssh-script
```

All following `devbox.py` commands run from **this folder on the machine named
in the step**. On Windows use `py -3` wherever an example says `python3`.
For a WSL server, work inside the intended WSL distro, rather than Windows
PowerShell, except for the Windows forwarding step.

You can also use a per-user installed copy; see [Install a per-user copy](#install-a-per-user-copy).
In that case run commands from the installed `ssh-script` folder and put public
keys in its `pub-keys/` subfolder.

### 2. On local device 1 (laptop): create its client key

```sh
# Run on the LAPTOP, from its ssh-script folder
python3 devbox.py keygen
```

This prompts for a passphrase and creates:

| File on the laptop | What to do with it |
| --- | --- |
| `~/.ssh/id_ed25519_devboxes` | Private key. Keep it on the laptop; the SSH client uses it. |
| `~/.ssh/id_ed25519_devboxes.pub` | Public key. Copy it to each remote devbox in step 4. |

On native Windows, these files are under `$HOME\.ssh\`.
If this key pair already exists, reuse it; `keygen` refuses to overwrite it.

### 3. On local device 2 (desktop), if used: create its own client key

```sh
# Run on the DESKTOP, from its ssh-script folder
python3 devbox.py keygen
```

The desktop gets a **different key pair**, even though the filenames are the
same as on the laptop. Its private key stays on the desktop. With only one
local device, skip this step and every reference to `desktop.pub` below.

### 4. On EACH remote devbox: collect the local devices' public keys

Create a `pub-keys` folder **inside that devbox's `ssh-script` folder**:

```sh
# Run on EACH REMOTE DEVBOX: Linux, macOS, or WSL
mkdir -p pub-keys
```

```powershell
# Run on EACH REMOTE DEVBOX: native Windows
New-Item -ItemType Directory -Path .\pub-keys -Force
```

Using your existing access, file transfer, or a USB drive, copy:

- The laptop's `~/.ssh/id_ed25519_devboxes.pub` → `pub-keys/laptop.pub`
  **on each of the four devboxes**.
- The desktop's `~/.ssh/id_ed25519_devboxes.pub` → `pub-keys/desktop.pub`
  **on each of the four devboxes**, if you use a desktop too.

Rename the copied files as shown so the two devices' keys do not overwrite each
other. Each remote devbox should now have:

```text
ssh-script/
  devbox.py
  setup-windows.ps1
  wsl-forward.ps1
  pub-keys/
    laptop.pub
    desktop.pub     # Only if you use a second local device
```

`pub-keys/` is ignored by Git in this repository: these files are local to each
checkout and **will not arrive on other machines through a clone or pull**.
Copy them explicitly to every remote devbox. Private keys never go in this folder.

### 5. On EACH remote devbox: preview and enable its SSH server

```sh
# Run on EACH REMOTE DEVBOX: Linux, macOS, or WSL
python3 devbox.py setup
python3 devbox.py setup --apply
```

```powershell
# Run on EACH REMOTE DEVBOX: native Windows
# Use Administrator PowerShell as the account you intend to log in to.
py -3 devbox.py setup
py -3 devbox.py setup --apply
```

`setup` detects the OS and lists every `.pub` file in `pub-keys/` beside
`devbox.py`, regardless of the terminal's working directory. Review that list:
**every listed key will allow its matching local device to log in**.
`setup --apply` authorizes those keys and installs/enables the SSH server.
It validates all keys before changing keys or services and avoids duplicate
authorized-key entries on reruns. Files in subfolders and files without the
`.pub` extension are not included.

If no keys are found, setup reports that and can still enable the server;
key-based access requires copying the keys and rerunning `setup --apply`.
To authorize just one file instead of discovering the folder:

```sh
# Optional, on a REMOTE DEVBOX
python3 devbox.py setup --public-key /path/to/laptop.pub --apply
```

Native servers normally listen on port **22**. For a WSL2 NAT devbox, also run
this in **Administrator PowerShell on that devbox's Windows host**:

```powershell
# Run on the WSL DEVBOX'S WINDOWS HOST, from its copy of ssh-script
wsl --list --verbose
Get-NetIPAddress -AddressFamily IPv4 |
    Select-Object InterfaceAlias, IPAddress
```

From the output, find the **Windows devbox's Ethernet or Wi-Fi IPv4 address**.
Use that address, not the WSL `vEthernet` address, `127.0.0.1`, or your laptop's
address. The forwarding helper requires an address assigned to this Windows host.

In the **same Administrator PowerShell window on the Windows devbox**:

```powershell
$distro = Read-Host 'Enter the WSL distro name shown above'
$windowsHostIP = Read-Host 'Enter this Windows devbox Ethernet or Wi-Fi IPv4 address'
.\wsl-forward.ps1 -Distro $distro -ListenAddress $windowsHostIP
.\wsl-forward.ps1 -Distro $distro -ListenAddress $windowsHostIP -Apply
```

Keep a note of the address you entered. Connect to that WSL server from your
local devices using **this Windows devbox's address and port 2222**.
Rerun forwarding after WSL's IP changes. See [WSL networking details](#wsl-networking-details).

### 6. On EACH local device: save connections to all four devboxes

Return to the **laptop's** `ssh-script` folder and run:

```sh
# Run on the LAPTOP. Replace each address and remote login username.
python3 devbox.py add dev1 192.168.1.10 --user alice
python3 devbox.py add dev2 mac-mini.local --user alice
python3 devbox.py add dev4 my-linux.tailnet-name.ts.net --user ubuntu
```

For the WSL devbox, use **the Windows devbox's IPv4 address you found in step 5**.
Enter that remote address when prompted, not this local device's address.
Replace `felix` with your login username **inside the remote WSL distro**:

```sh
# Run on the LAPTOP: Linux, macOS, or WSL
printf 'Windows devbox IPv4 address from step 5: '
read -r windows_host_ip
python3 devbox.py add dev3 "$windows_host_ip" --user felix --port 2222
```

```powershell
# Run on the LAPTOP: native Windows
$windowsHostIP = Read-Host 'Enter the remote Windows devbox IPv4 address from step 5'
py -3 devbox.py add dev3 $windowsHostIP --user felix --port 2222
```

If you use the **desktop** too, run those same four `add` commands from the
**desktop's** `ssh-script` folder. Aliases are stored separately on each local
device; saving them on the laptop does not save them on the desktop.

| Example alias | Remote destination | Login account on that remote machine |
| --- | --- | --- |
| `dev1` | Linux devbox at `192.168.1.10:22` | `alice` |
| `dev2` | Mac devbox at `mac-mini.local:22` | `alice` |
| `dev3` | WSL distro via the Windows devbox's actual IPv4 address from step 5, port 2222 | WSL user `felix` |
| `dev4` | Linux devbox via an existing Tailscale hostname, port 22 | `ubuntu` |

The alias is your local shortcut; it does not rename the remote machine.
`--user` is the **remote** login account, which may differ from your local
username. Each local device automatically uses **its own**
`~/.ssh/id_ed25519_devboxes` private key. For a different existing key, pass
`--identity /path/to/private-key` to `add`.

This tool does not discover machines or create a VPN. Supply reachable LAN IPs,
DNS names, or existing Tailscale hostnames. Across different networks, an
existing VPN such as Tailscale avoids router port forwarding.

### 7. Everyday use: connect FROM either local device

```sh
# Run on the LAPTOP or DESKTOP, from any folder
ssh dev1
ssh dev2
ssh dev3
ssh dev4
```

On each device's first connection to a devbox, verify the server's host-key
fingerprint using your existing access before accepting it. This server identity
check is separate from the client keys you copied earlier.

Or choose a saved devbox from a menu:

```sh
# Run on a LOCAL DEVICE, from its ssh-script folder
python3 devbox.py connect
```

To add another local device later, generate its own key, copy its `.pub` file
into `pub-keys/` on all four remote devboxes, rerun server setup there, and save
the four aliases on the new local device. Removing a file from `pub-keys/` does
not revoke an already authorized key; remove that key from each server's
applicable authorized-keys file to revoke access.

## Install a per-user copy

Instead of running from the repository folder, install the tool on **each
machine where you need it**. From that machine's repository root:

```sh
# Linux/WSL; use macos/ on a Mac
bash linux/tools/36-ssh-script.sh
```

```powershell
# Native Windows; no elevation needed to copy the tool
.\windows\tools\36-ssh-script.ps1
```

Then enter the installed folder:

- Linux/macOS/WSL: `~/.local/share/dev-scaffolder/ssh-script`
- Windows: `%LOCALAPPDATA%\dev-scaffolder\ssh-script`

`DEVBOX_SSH_HOME` overrides the install location. Re-running the installer
upgrades changed versions and repairs missing bundle files. It does not copy
the repository's `pub-keys/` folder: on a remote devbox, create `pub-keys/`
**beside the installed `devbox.py`** and copy the client public keys there.
Existing keys in that installed folder are preserved during upgrades.
Installing the tool alone does not enable an SSH server or change SSH settings.

## Server setup details

`setup` previews operations; `setup --apply` installs/enables the server and
authorizes all discovered `pub-keys/*.pub` files, or only the file selected by
`--public-key`. Run setup on the devbox that will accept
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
- **Windows:** run `py -3 devbox.py setup --apply` with client public keys in
  the adjacent `pub-keys/` folder (or select one file with `--public-key PATH`)
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

On the **remote devbox's Windows host**, open **Administrator PowerShell** in
its `ssh-script` folder. Find the distro name and the Windows host's LAN IPv4
address:

```powershell
wsl --list --verbose
Get-NetIPAddress -AddressFamily IPv4 |
    Select-Object InterfaceAlias, IPAddress
```

Choose the **Ethernet or Wi-Fi IPv4 address assigned to this Windows devbox**,
not the WSL `vEthernet` address, loopback address, or a local client's address.
If you get `ListenAddress is not assigned to this Windows host`, rerun the
address listing on this Windows devbox and check the address you entered.

In that **same Administrator PowerShell window**, enter the values from the
listing, preview, then apply:

```powershell
$distro = Read-Host 'Enter the WSL distro name shown above'
$windowsHostIP = Read-Host 'Enter this Windows devbox Ethernet or Wi-Fi IPv4 address'
.\wsl-forward.ps1 -Distro $distro -ListenAddress $windowsHostIP
.\wsl-forward.ps1 -Distro $distro -ListenAddress $windowsHostIP -Apply
```

This exposes **Windows-host port 2222 → WSL port 22** and adds a LAN-scoped
firewall rule. It refuses an unrelated listener/mapping at that address and port.
Preview queries (and may start) the selected distro but does not change forwarding
or firewall settings. Rerun with `-Apply` after WSL restarts or its IP changes.
The Windows host must be awake and the distro/SSH service running. Use `-Port`
for a different host port or `-WslPort` for a customized WSL server port. Multiple
distros need different host ports.

Remove a forwarding rule created by this helper, in the same Windows
Administrator PowerShell window using the values above (enter them again if
you opened a new window):

```powershell
.\wsl-forward.ps1 -Distro $distro -ListenAddress $windowsHostIP -Remove -Apply
```

This helper targets **WSL2 NAT**. WSL1 and WSL mirrored networking have different
reachability/firewall requirements; don't use this forwarding helper for them.
For mirrored networking, configure Windows/Hyper-V firewall access to the
WSL SSH port yourself, avoiding a collision with native Windows SSH. An existing
VPN running inside WSL is another way to give the distro a reachable hostname.

## Keys and connection settings

On each **local device**, key generation prompts for a passphrase and refuses
to overwrite existing keys. Each local device should generate its own key and
authorize its public key on the devboxes. On that **same local device**, optionally
load your private key into your system's SSH agent to
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
