# Devshop

Reusable NixOS workstation setup for a development shop. It gives you a
repeatable desktop, shared defaults, and composable tool profiles for different
kinds of engineering work.

## Layout

- `flake.nix`: flake inputs, overlay, and the `workstation` NixOS configuration.
- `AGENTS.md`: repo-level guidance for AI assistants working from this setup.
- `docs`: reference docs, including the linked [tool catalog](docs/tools.md).
- `hosts/workstation`: host-level NixOS configuration and hardware placeholder.
- `profiles`: composable development profiles.
- `modules`: reusable workstation modules.
- `packages`: local package definitions.
- `dotfiles`: small user config files and Codex skills installed by activation scripts.
- `scripts`: helper scripts that are safe to keep in the public setup.

## Development Profiles

Profiles are NixOS modules under `profiles/`. Compose only the tool groups a
machine needs, or use `profiles/all.nix` for a full development workstation.
For the complete linked inventory, see [Devshop Tools](docs/tools.md).

- `base`: shell, Git/GitHub, `via`, GPG, SSH, direnv, tmux, ripgrep, fd, jq, and
  common Unix utilities.
- `desktop`: GNOME-oriented desktop apps, browsers, editors, docs/capture tools,
fonts, and hardware diagnostics.
- `frontend`: Node.js 22, Corepack, and fnm for JavaScript/TypeScript work.
- `backend`: Python, Ruby, Go, compilers, build systems, protobuf, schema/config
tooling, PostgreSQL client tools, pgAdmin, and GoLand.
- `rust`: rustup, cargo subcommands, SQLx CLI, sccache, wasm-pack, OpenSSL build
inputs, and `cached-cargo`/`depot-cargo` helpers.
- `data`: pandas, pyarrow, SQLite, SQLite Browser, and DuckDB for local data
inspection and analysis.
- `infra`: AWS CLI v2, Terraform, kubectl, Helm, k9s, kubie, Tilt, k3d, k3s,
WireGuard tools, Tor, and torsocks.
- `all`: imports every profile above.

The example `workstation` host imports `profiles/all.nix`. Teams can create
lighter hosts by importing `base`, `desktop`, and only the role-specific
profiles they need.

When consuming this flake from another NixOS config, use the exported profile
modules:

```nix
modules = [
  ({ ... }: { nixpkgs.overlays = [ devshop.overlays.default ]; })
  devshop.nixosModules.profiles.base
  devshop.nixosModules.profiles.desktop
  devshop.nixosModules.profiles.frontend
];
```

## Reflash To Devshop

### Build The USB Installer

Use the official NixOS download page:

https://nixos.org/download/

Download the graphical 64-bit Intel/AMD ISO unless your target machine needs a
different image.

Plug in the USB drive and find its device:

```sh
lsblk
```

Be exact here. The target should be the whole USB disk, such as `/dev/sda` or
`/dev/sdb`, not a partition like `/dev/sda1`.

Flash the ISO:

```sh
sudo dd if=~/Downloads/nixos-graphical-VERSION-x86_64-linux.iso of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

Replace `VERSION` with the downloaded ISO version and `/dev/sdX` with the USB
device from `lsblk`.

### Install NixOS

This can erase the existing operating system.

1. Back up anything needed from the existing machine.
2. Boot the target machine and open its boot menu. `F12` is common on many
Lenovo/ThinkPad machines, but this varies by vendor.
3. Choose the UEFI USB entry. If it refuses to boot, enter firmware setup and
disable Secure Boot.
4. In the graphical installer, choose:
   - `Erase disk` when you want a clean install
   - the internal drive, not the USB drive
   - disk encryption when offered
   - swap with hibernation if offered
   - allow unfree software
   - GNOME desktop, or no desktop if you plan to immediately apply this flake
5. Create the normal user you plan to manage with this flake.
6. Reboot into the installed system.

The Devshop workstation template defaults to an encrypted root filesystem:
`/boot` is the normal unencrypted EFI partition, and `/` is expected to live
inside a LUKS device that opens during the initrd. Do not use plain swap on a
separate disk partition; hibernation swap should either be encrypted by the
installer or live inside the encrypted root filesystem.

### Apply Devshop After First Boot

Clone Devshop, then apply the flake:

```sh
nix-shell -p git
mkdir -p ~/repos
git clone https://github.com/tee8z/devshop ~/repos/devshop
cd ~/repos/devshop
```

Generate a hardware config for the target machine:

```sh
sudo nixos-generate-config --show-hardware-config > hosts/workstation/hardware-configuration.nix
```

Review the generated file before committing it. Disk UUIDs and other hardware
details are machine-specific. For an encrypted install, the generated file
should include a `boot.initrd.luks.devices` entry. If it does not, stop and
reinstall with disk encryption enabled before applying Devshop.

This check should print at least one LUKS line on an encrypted install:

```sh
rg -n 'boot.initrd.luks|/dev/mapper|swapDevices' hosts/workstation/hardware-configuration.nix
```

Edit the placeholders at the top of `hosts/workstation/configuration.nix`.
See [Customize First](#customize-first) below for the values that should be
reviewed before the first rebuild.

Use `sudo` for the first switch because updating the system profile requires
root. The inline `NIX_CONFIG` bootstraps flakes and the larger download buffer
before Devshop's persistent `nix.settings` has been activated:

```sh
sudo env NIX_CONFIG=$'experimental-features = nix-command flakes\ndownload-buffer-size = 536870912' \
nixos-rebuild switch --flake .#workstation
```

After this config has been applied, open a new shell, or run `exec zsh`, so the
aliases from the system zsh config are loaded.

Normal rebuilds can then use:

```sh
rebuild
```

To keep only the newest NixOS/profile generations and free old store paths, run:

```sh
nix-clean-old
```

This removes rollback targets.

Reboot once after the first successful rebuild so the desktop session, user
services, portals, and shell defaults all start from the managed system.

## Customize First

Before applying the flake to a real machine, edit the placeholders at the top of
`hosts/workstation/configuration.nix`:

```nix
userName = "developer";
userFullName = "Developer";
userEmail = "developer@example.com";
gitSigningKey = null;
hostName = "workstation";
repoDirectoryName = "devshop";
hubEthernetInterface = null;
```

Set `gitSigningKey` to a GPG key fingerprint when you want this config to
enable Git commit and tag signing. Leave it as `null` until
signing is configured.

Set `hubEthernetInterface` to your dock ethernet interface, such as
`"enp0s20f0u1"`, if you want the wired-preferred NetworkManager behavior. Leave
it as `null` if you do not need that behavior.

Then replace the template hardware file with hardware generated on the target
machine:

```sh
sudo nixos-generate-config --show-hardware-config > hosts/workstation/hardware-configuration.nix
```

Review the generated file before committing it. Disk UUIDs and other hardware
details are machine-specific.

For the default encrypted layout, keep the generated
`boot.initrd.luks.devices` entry and make sure `/` resolves to the unlocked
LUKS mapping or the filesystem inside it. If the generated file contains a
plain swap partition, remove it or replace it with encrypted swap before the
first Devshop rebuild.

## Apply The Flake

From the repo root after the first rebuild:

```sh
rebuild
```

Or run the underlying command directly:

```sh
sudo nixos-rebuild switch --flake ~/repos/devshop#workstation
```

## Move Repos And Files

Devshop includes migration helpers for rebuilding a workstation from another
machine. The scripts are safe to keep public because they only describe common
filesystem locations and restore mechanics. The generated bundles are different:
they contain whatever was copied from your machine and should be handled based
on their contents. For the full script reference, see
[Migration And Maintenance Scripts](docs/tools.md#migration-and-maintenance-scripts).

There are three useful bundle types:

- `repo-config-bundle`: repo remotes, detected tooling, dirty counts, and
  portable repo-local config.
- `private-machine-bundle`: credentials and machine state from well-known user
  and system locations.
- `file-transfer-bundle`: arbitrary files staged by you for transfer into the
  target home directory.

LocalSend is included and has its receive port opened by the workstation config.
After the first rebuild, it is usually the easiest way to move these tarballs
between machines on the same local network. USB storage is a simple fallback.

### Repo Metadata

Export Git repo metadata and portable repo-local config:

```sh
cd ~/repos/devshop
./scripts/export-repo-configs.sh --force
tar -czf repo-config-bundle.tar.gz repo-config-bundle
```

On the target machine:

```sh
cd ~/repos/devshop
tar -xzf repo-config-bundle.tar.gz
./scripts/setup-repos-from-bundle.sh --bundle-dir ./repo-config-bundle --clone
```

The repo bundle records origin remotes, detected tools, dirty counts, and
portable local config files. Files that look sensitive are listed but not copied
unless you pass `--include-sensitive`.

### Private Machine State

Export private machine state from well-known locations such as AWS credentials,
kube configs, SSH keys, GPG keys, WireGuard files, and `~/encrypted`:

```sh
cd ~/repos/devshop
./scripts/export-private-machine-state.sh --force --archive
```

If `/etc/wireguard` or NetworkManager WireGuard profiles are skipped as
unreadable, rerun the export with sudo. The script still targets the original
user when `SUDO_USER` is set:

```sh
sudo ./scripts/export-private-machine-state.sh --force --archive
```

Move `private-machine-bundle.tar.gz` to the target machine, unpack it, then
restore:

```sh
cd ~/repos/devshop
tar -xzf private-machine-bundle.tar.gz
sudo ./scripts/setup-private-machine-state.sh
```

The private machine bundle contains credentials and keys. Transfer it only
through a trusted path, such as LocalSend on a trusted local network or
encrypted USB storage.

### Ordinary Files

For files that do not belong to a standard config location, prepare a staging
tree exactly how you want it restored under the target home directory:

```sh
mkdir -p ~/devshop-transfer
# put files and folders under ~/devshop-transfer
cd ~/repos/devshop
./scripts/export-file-bundle.sh --source-dir ~/devshop-transfer --force
```

Move `file-transfer-bundle.tar.gz` to the target machine, dry-run, then apply:

```sh
cd ~/repos/devshop
./scripts/setup-file-bundle.sh --archive ./file-transfer-bundle.tar.gz --dry-run
./scripts/setup-file-bundle.sh --archive ./file-transfer-bundle.tar.gz
```

## AI Agent Guidance

Devshop includes `AGENTS.md` with tool-neutral guidance for AI assistants.
Applying the flake also installs these Codex-compatible skills to
`~/.codex/skills`:

- `git-commit-policy` for Conventional Commits and signed commits.
- `github-stacked-prs` for planning and managing formally linked GitHub PR
  stacks for large features with dependent review layers.
- `ste-system-docs` for STE-informed system documentation, runbooks,
  troubleshooting guides, and faithful Mermaid or ASCII diagrams.
- `via-integrations` for accessing configured services, including Linear,
  through `via` without handling API secrets directly.

The commit policy also avoids staging unrelated work.

## Rust Build Cache

Rust builds use `sccache` by default through `RUSTC_WRAPPER`. The local cache
size is set to 50 GiB.

For normal local caching in a Rust repo:

```sh
cached-cargo build
```

For Depot-backed shared caching, keep credentials outside this repo:

```sh
mkdir -p ~/.config/depot
chmod 700 ~/.config/depot
nano ~/.config/depot/sccache.env
chmod 600 ~/.config/depot/sccache.env
```

Use either token auth:

```sh
SCCACHE_WEBDAV_TOKEN="depot_..."
```

or username/password auth:

```sh
SCCACHE_WEBDAV_USERNAME="depot-user"
SCCACHE_WEBDAV_PASSWORD="depot_..."
```

Then run:

```sh
depot-cargo build --locked
```

`depot-cargo` also loads a repo-local `.env.depot` when present.

## DisplayLink

DisplayLink is enabled through `modules/displaylink.nix`. The proprietary driver
requires accepting Synaptics' EULA before Nix can fetch the archive.

Run once on the target machine:

```sh
./scripts/prefetch-displaylink.sh
sudo nixos-rebuild switch --flake .#workstation
```

If DisplayLink breaks the graphical login, boot an earlier generation from the
boot menu and adjust or remove `modules/displaylink.nix`.

## Zed Updates

Zed is pinned in `flake.nix` to the official Linux archive, so updating it
requires changing both the version and the fixed-output hash. After applying this
config once, use:

```sh
zed-update-flake 1.3.5
rebuild
```

The helper prefetches the archive, updates `zedVersion` and `hash`, and formats
`flake.nix`.

## Nix Cleanup

Use:

```sh
nix-clean-old
```

This removes the repo-local `result` GC root left by `nix build`, deletes old
user/system generations, and runs garbage collection. It removes rollback
targets.
