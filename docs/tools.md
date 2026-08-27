# Devshop Tools

This catalog lists the tools Devshop installs or wires into the default
workstation. The profile files are the source of truth:

- [`profiles/base.nix`](../profiles/base.nix)
- [`profiles/desktop.nix`](../profiles/desktop.nix)
- [`profiles/frontend.nix`](../profiles/frontend.nix)
- [`profiles/backend.nix`](../profiles/backend.nix)
- [`profiles/rust.nix`](../profiles/rust.nix)
- [`profiles/data.nix`](../profiles/data.nix)
- [`profiles/infra.nix`](../profiles/infra.nix)
- [`profiles/all.nix`](../profiles/all.nix)

The example [`workstation`](../hosts/workstation/configuration.nix) imports
`profiles/all.nix`. A team can create lighter machines by importing only the
profiles they need.

## Base Profile

Common shell, Git, security, transfer, and terminal utilities.

| Tool | Package | Purpose |
| --- | --- | --- |
| [age](https://age-encryption.org/) | `age` | File encryption. |
| [Bash](https://www.gnu.org/software/bash/) | `bash` | POSIX-oriented shell scripting. |
| [GNU Coreutils](https://www.gnu.org/software/coreutils/) | `coreutils` | Standard Unix file and text commands. |
| [GNU Awk](https://www.gnu.org/software/gawk/) | `gawk` | Text processing. |
| [GNU tar](https://www.gnu.org/software/tar/) | `gnutar` | Archive creation and extraction. |
| [gzip](https://www.gnu.org/software/gzip/) | `gzip` | Compression. |
| [Zsh](https://www.zsh.org/) | `zsh` | Interactive shell. |
| [Git](https://git-scm.com/) | `git` | Version control. |
| [GitHub CLI](https://cli.github.com/) | `gh` | GitHub workflow automation. |
| [GnuPG](https://gnupg.org/) | `gnupg` | Signing and encryption. |
| [curl](https://curl.se/) | `curl` | HTTP and network transfer. |
| [GNU Wget](https://www.gnu.org/software/wget/) | `wget` | HTTP and FTP downloads. |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | `ripgrep` | Fast code and text search. |
| [fd](https://github.com/sharkdp/fd) | `fd` | Fast file finding. |
| [jq](https://jqlang.org/) | `jq` | JSON processing. |
| [tree](https://gitlab.com/OldManProgrammer/unix-tree) | `tree` | Directory tree display. |
| [tmux](https://github.com/tmux/tmux/wiki) | `tmux` | Terminal multiplexing. |
| [direnv](https://direnv.net/) | `direnv` | Per-directory environment loading. |
| [just](https://just.systems/) | `just` | Project command runner. |
| [GNU nano](https://www.nano-editor.org/) | `nano` | Terminal editor. |
| [psmisc](https://gitlab.com/psmisc/psmisc) | `psmisc` | Process utilities such as `killall` and `pstree`. |
| [OpenSSH](https://www.openssh.com/) | `openssh` | SSH client and server tools. |
| [SSHFS](https://github.com/libfuse/sshfs) | `sshfs` | Mount remote filesystems over SSH. |
| [Info-ZIP](https://infozip.sourceforge.net/) | `unzip`, `zip` | Zip archive extraction and creation. |
| [libsecret](https://gitlab.gnome.org/GNOME/libsecret) | `libsecret` | Secret-service integration. |
| [Seahorse](https://gitlab.gnome.org/GNOME/seahorse) | `seahorse` | GNOME key and password manager UI. |

## Desktop Profile

GNOME-oriented desktop apps, editors, document tools, media tools, fonts, and
hardware inspection utilities.

| Tool | Package | Purpose |
| --- | --- | --- |
| [Slack](https://slack.com/) | `slack` | Team messaging. |
| [Firefox](https://www.mozilla.org/firefox/) | `firefox` | Web browser. |
| [Obsidian](https://obsidian.md/) | `obsidian` | Markdown notes. |
| [Zed](https://zed.dev/) | `zed-editor`, local `zed` wrapper | Code editor from the official Linux archive. |
| [Visual Studio Code](https://code.visualstudio.com/) | `vscode` | Code editor. |
| [Terminator](https://gnome-terminator.org/) | `terminator` | Terminal emulator. |
| [GNOME Text Editor](https://apps.gnome.org/TextEditor/) | `gnome-text-editor` | Desktop text editor. |
| [LibreOffice](https://www.libreoffice.org/) | `libreoffice-fresh` | Office documents. |
| [Hunspell](https://hunspell.github.io/) | `hunspell`, `hunspellDicts.en_US` | Spell checking and English dictionary. |
| [Pandoc](https://pandoc.org/) | `pandoc` | Document conversion. |
| [ImageMagick](https://imagemagick.org/) | `imagemagick` | Image conversion and inspection. |
| [Poppler](https://poppler.freedesktop.org/) | `poppler-utils` | PDF command-line tools. |
| [ksnip](https://github.com/ksnip/ksnip) | `ksnip` | Screenshot annotation. |
| [Flameshot](https://flameshot.org/) | `flameshot` | Screenshot capture. |
| [OBS Studio](https://obsproject.com/) | `obs-studio` | Screen recording and streaming. |
| [FFmpeg](https://ffmpeg.org/) | `ffmpeg-full` | Audio/video processing. |
| [Noto Fonts](https://fonts.google.com/noto) | `noto-fonts`, `noto-fonts-cjk-sans`, `noto-fonts-color-emoji` | Broad text and emoji coverage. |
| [PulseAudio Volume Control](https://freedesktop.org/software/pulseaudio/pavucontrol/) | `pavucontrol` | Audio device control UI. |
| [BlueZ](https://www.bluez.org/) | `bluez`, `bluez-tools` | Bluetooth tools. |
| [GParted](https://gparted.org/) | `gparted` | Disk partitioning UI. |
| [usbutils](https://github.com/gregkh/usbutils) | `usbutils` | USB inspection tools. |
| [pciutils](https://mj.ucw.cz/sw/pciutils/) | `pciutils` | PCI inspection tools. |
| [ethtool](https://www.kernel.org/pub/software/network/ethtool/) | `ethtool` | Network interface inspection and tuning. |
| [xrandr](https://www.x.org/wiki/Projects/XRandR/) | `xrandr` | X display configuration. |
| [ARandR](https://christian.amsuess.com/tools/arandr/) | `arandr` | X display layout UI. |

## Frontend Profile

JavaScript and TypeScript runtime/versioning tools.

| Tool | Package | Purpose |
| --- | --- | --- |
| [Node.js](https://nodejs.org/) | `nodejs_22` | JavaScript runtime. |
| [Corepack](https://nodejs.org/api/corepack.html) | `corepack_22` | Package manager shims for pnpm and Yarn. |
| [fnm](https://github.com/Schniz/fnm) | `fnm` | Fast Node.js version manager. |

## Backend Profile

Python, Ruby, Go, native build tools, schema/config tooling, and PostgreSQL
clients.

| Tool | Package | Purpose |
| --- | --- | --- |
| [Python](https://www.python.org/) | `python3` | Python runtime. |
| [pip](https://pip.pypa.io/) | `python3Packages.pip` | Python package installer. |
| [Poetry](https://python-poetry.org/) | `poetry` | Python packaging and dependency management. |
| [uv](https://docs.astral.sh/uv/) | `uv` | Fast Python package and project manager. |
| [Ruby](https://www.ruby-lang.org/) | `ruby` | Ruby runtime. |
| [Go](https://go.dev/) | `go` | Go toolchain. |
| [gopls](https://pkg.go.dev/golang.org/x/tools/gopls) | `gopls` | Go language server. |
| [Delve](https://github.com/go-delve/delve) | `delve` | Go debugger. |
| [GoLand](https://www.jetbrains.com/go/) | `jetbrains.goland` | JetBrains Go IDE. |
| [GCC](https://gcc.gnu.org/) | `gcc` | C/C++ compiler toolchain. |
| [Clang](https://clang.llvm.org/) | `clang` | LLVM C/C++ compiler. |
| [LLD](https://lld.llvm.org/) | `lld` | LLVM linker. |
| [mold](https://github.com/rui314/mold) | `mold` | Fast linker. |
| [CMake](https://cmake.org/) | `cmake` | Build system generator. |
| [GNU Make](https://www.gnu.org/software/make/) | `gnumake` | Build automation. |
| [pkg-config](https://www.freedesktop.org/wiki/Software/pkg-config/) | `pkg-config` | Native dependency metadata lookup. |
| [OpenSSL](https://www.openssl.org/) | `openssl` | TLS and crypto library/tools. |
| [Automake](https://www.gnu.org/software/automake/) | `automake` | Autotools build generation. |
| [Autoconf](https://www.gnu.org/software/autoconf/) | `autoconf` | Portable configure script generation. |
| [GNU Libtool](https://www.gnu.org/software/libtool/) | `libtool` | Portable library build support. |
| [Protocol Buffers](https://protobuf.dev/) | `protobuf` | Protobuf compiler and libraries. |
| [Graphviz](https://graphviz.org/) | `graphviz` | Graph visualization. |
| [YAML Language Server](https://github.com/redhat-developer/yaml-language-server) | `yaml-language-server` | YAML editor language support. |
| [yamllint](https://yamllint.readthedocs.io/) | `yamllint` | YAML linting. |
| [yq](https://github.com/mikefarah/yq) | `yq-go` | YAML, JSON, XML, CSV, and properties processing. |
| [Taplo](https://taplo.tamasfe.dev/) | `taplo` | TOML formatter and language server. |
| [PostgreSQL](https://www.postgresql.org/) | `postgresql_16` | PostgreSQL client tools. |
| [pgAdmin](https://www.pgadmin.org/) | `pgadmin4-runtime` | Local pgAdmin runtime package. |

## Rust Profile

Rust toolchain manager, Cargo subcommands, SQLx tooling, WebAssembly packaging,
and cache helpers.

| Tool | Package | Purpose |
| --- | --- | --- |
| [rustup](https://rustup.rs/) | `rustup` | Rust toolchain manager. |
| [cargo-audit](https://github.com/rustsec/rustsec/tree/main/cargo-audit) | `cargo-audit` | RustSec vulnerability checks. |
| [cargo-bloat](https://github.com/RazrFalcon/cargo-bloat) | `cargo-bloat` | Binary size analysis. |
| [cargo-llvm-cov](https://github.com/taiki-e/cargo-llvm-cov) | `cargo-llvm-cov` | LLVM-based Rust coverage. |
| [cargo-machete](https://github.com/bnjbvr/cargo-machete) | `cargo-machete` | Unused dependency detection. |
| [cargo-nextest](https://nexte.st/) | `cargo-nextest` | Faster Rust test runner. |
| [cargo-outdated](https://github.com/kbknapp/cargo-outdated) | `cargo-outdated` | Dependency update reporting. |
| [cargo-sort](https://github.com/DevinR528/cargo-sort) | `cargo-sort` | Cargo.toml dependency sorting. |
| [SQLx CLI](https://github.com/launchbadge/sqlx/tree/main/sqlx-cli) | `sqlx-cli` | SQLx migrations and query metadata. |
| [sccache](https://github.com/mozilla/sccache) | `sccache` | Compiler cache. |
| [wasm-pack](https://rustwasm.github.io/wasm-pack/) | `wasm-pack` | Rust WebAssembly package workflow. |
| [OpenSSL](https://www.openssl.org/) build inputs | `opensslForRust` | Joined OpenSSL runtime/dev paths for Rust crates. |
| Local Cargo cache wrapper | `cached-cargo` | Runs `cargo` with repo-local sccache settings. |
| [Depot](https://depot.dev/) Cargo cache wrapper | `depot-cargo` | Runs `cargo` with Depot-backed sccache settings. |

## Data Profile

Local data inspection and analysis tools.

| Tool | Package | Purpose |
| --- | --- | --- |
| [pandas](https://pandas.pydata.org/) | `python3Packages.pandas` | Python data analysis. |
| [Apache Arrow](https://arrow.apache.org/) | `python3Packages.pyarrow` | Arrow/Parquet data support. |
| [SQLite](https://sqlite.org/) | `sqlite` | Embedded SQL database CLI. |
| [DB Browser for SQLite](https://sqlitebrowser.org/) | `sqlitebrowser` | SQLite desktop UI. |
| [DuckDB](https://duckdb.org/) | `duckdb` | Analytical SQL database CLI. |

## Infra Profile

Cloud, Kubernetes, local cluster, VPN, and proxy tools.

| Tool | Package | Purpose |
| --- | --- | --- |
| [AWS CLI](https://aws.amazon.com/cli/) | `awscli2` | AWS command-line tools. |
| [Terraform](https://developer.hashicorp.com/terraform) | `terraform` | Infrastructure as code. |
| [kubectl](https://kubernetes.io/docs/reference/kubectl/) | `kubectl` | Kubernetes CLI. |
| [Helm](https://helm.sh/) | `kubernetes-helm` | Kubernetes package manager. |
| [k9s](https://k9scli.io/) | `k9s` | Kubernetes terminal UI. |
| [kubie](https://github.com/sbstp/kubie) | `kubie` | Kubernetes context and namespace switching. |
| [Tilt](https://tilt.dev/) | `tilt` | Local development environments on Kubernetes. |
| [k3d](https://k3d.io/) | `k3d` | k3s clusters in Docker. |
| [k3s](https://k3s.io/) | `k3s` | Lightweight Kubernetes distribution. |
| [WireGuard](https://www.wireguard.com/) | `wireguard-tools` | WireGuard CLI tools. |
| [Tor](https://www.torproject.org/) | `tor` | Tor daemon and client tools. |
| [torsocks](https://gitlab.torproject.org/tpo/core/torsocks) | `torsocks` | Route command traffic through Tor. |
| [NetworkManager applet](https://networkmanager.dev/) | `networkmanagerapplet` | Desktop NetworkManager tray tools. |

## Workstation Host Tools

The default workstation host adds operating-system services, shell aliases,
desktop defaults, and local wrappers on top of the profiles.

| Tool | Source | Purpose |
| --- | --- | --- |
| [Nix](https://nixos.org/) flakes | Nix settings | Enables `nix-command` and `flakes` and raises the download buffer for large fetches. |
| [`rebuild`](../hosts/workstation/configuration.nix) | zsh alias | Runs `sudo nixos-rebuild switch --flake $HOME/repos/devshop#workstation`. |
| [`nix-clean-old`](../hosts/workstation/configuration.nix) | local script | Removes the repo `result` GC root and old user/system generations. |
| [`zed-update-flake`](../hosts/workstation/configuration.nix) | local script | Prefetches a Zed release, updates the flake version/hash, and formats `flake.nix`. |
| `onlymaster` | zsh alias | Deletes local Git branches except `master`. |
| [systemd-boot](https://www.freedesktop.org/software/systemd/man/latest/systemd-boot.html) | NixOS boot loader | UEFI boot loader. |
| [NetworkManager](https://networkmanager.dev/) | NixOS service | Desktop networking with optional wired-preferred dock profile. |
| [systemd-resolved](https://www.freedesktop.org/software/systemd/man/latest/systemd-resolved.service.html) | NixOS service | DNS resolver. |
| [fwupd](https://fwupd.org/) | NixOS service | Firmware updates. |
| [CUPS](https://openprinting.github.io/cups/) | NixOS service | Printing. |
| [GNOME](https://www.gnome.org/) and GDM | NixOS services | Wayland desktop session and display manager. |
| [GNOME Keyring](https://gitlab.gnome.org/GNOME/gnome-keyring) | NixOS service | Desktop secrets and SSH agent integration. |
| [PipeWire](https://pipewire.org/) | NixOS service | Audio and screen sharing media stack. |
| [XDG Desktop Portal](https://flatpak.github.io/xdg-desktop-portal/) | NixOS service | Desktop integration portals for apps. |
| [Docker](https://www.docker.com/) | NixOS service | Container runtime. |
| [Oh My Zsh](https://ohmyz.sh/) | zsh config | Interactive shell theme and Git plugin. |
| [LocalSend](https://localsend.org/) | NixOS program | Local-network file transfer with firewall port open. |
| [envfs](https://github.com/Mic92/envfs) | NixOS service | Compatibility paths for scripts that expect `/bin/bash` or `/usr/bin/zsh`. |
| [1Password](https://1password.com/) | NixOS programs | CLI, GUI, and polkit integration. |
| [Wireshark](https://www.wireshark.org/) | NixOS program | Packet capture and inspection. |
| [nix-ld](https://github.com/nix-community/nix-ld) | NixOS program | Dynamic linker compatibility for external binaries. |
| [direnv](https://direnv.net/) and [nix-direnv](https://github.com/nix-community/nix-direnv) | NixOS program | Automatic per-directory Nix environments. |
| [Git](https://git-scm.com/) config | NixOS program config | Sets identity, pull rebase, GitHub SSH URL rewriting, and optional commit/tag signing. |
| [PostgreSQL](https://www.postgresql.org/) | NixOS service | Local PostgreSQL 16 service. |
| [OpenSSH](https://www.openssh.com/) | NixOS service | Key-only SSH server. |
| [Tor](https://www.torproject.org/) | NixOS service | Tor daemon. |
| [Caffeine](https://extensions.gnome.org/extension/517/caffeine/) | GNOME extension | Prevents idle sleep/lock when enabled. |
| [Dash to Dock](https://micheleg.github.io/dash-to-dock/) | GNOME extension | Persistent GNOME dock. |
| [Mesa](https://www.mesa3d.org/) and [Vulkan](https://www.vulkan.org/) | system packages/libraries | Graphics stack and diagnostics. |
| [xkeyboard-config](https://gitlab.freedesktop.org/xkeyboard-config/xkeyboard-config) | system package | XKB keyboard data for GUI apps. |

### Pinned GNOME Apps

The workstation host sets the GNOME favorite apps list so a fresh desktop opens
with the common workbench tools already pinned to the dock:

| App | Desktop entry | Why it is pinned |
| --- | --- | --- |
| [Firefox](https://www.mozilla.org/firefox/) | `firefox.desktop` | Browser and web login handoffs. |
| [GNOME Text Editor](https://apps.gnome.org/TextEditor/) | `org.gnome.TextEditor.desktop` | Quick local text edits. |
| [Obsidian](https://obsidian.md/) | `obsidian.desktop` | Notes and local knowledge base. |
| [Slack](https://slack.com/) | `slack.desktop` | Team messaging. |
| [Zed](https://zed.dev/) | `dev.zed.Zed.desktop` | Primary code editor. |
| [Terminator](https://gnome-terminator.org/) | `terminator.desktop` | Terminal workspace. |
| [pgAdmin](https://www.pgadmin.org/) | `org.pgadmin.pgadmin4.desktop` | PostgreSQL UI. |
| [Files](https://apps.gnome.org/Nautilus/) | `org.gnome.Nautilus.desktop` | File manager. |
| [LocalSend](https://localsend.org/) | `LocalSend.desktop` | Local-network file transfer. |
| [GNOME System Monitor](https://apps.gnome.org/SystemMonitor/) | `org.gnome.SystemMonitor.desktop` | Process and resource inspection. |
| [GNOME Settings](https://apps.gnome.org/Settings/) | `org.gnome.Settings.desktop` | Desktop and device settings. |

## DisplayLink Module

[`modules/displaylink.nix`](../modules/displaylink.nix) enables the NixOS
DisplayLink video driver path while keeping GDM/GNOME on Wayland.

The module also exposes `devshop.displaylink.edidOverrides` for host-specific
DisplayLink connectors that need a fixed EDID and hotplug trigger after docking.

The helper script [`scripts/prefetch-displaylink.sh`](../scripts/prefetch-displaylink.sh)
prefetches the Synaptics DisplayLink driver archive after EULA acceptance. Use
`--rebuild-target` when your host flake output is not `.#workstation`.

## Migration And Maintenance Scripts

These scripts live in [`scripts/`](../scripts). The scripts themselves are
public and generic; generated bundles may contain secrets depending on what you
export.

| Script | Purpose |
| --- | --- |
| [`export-repo-configs.sh`](../scripts/export-repo-configs.sh) | Records repo remotes, detected tools, dirty counts, and portable repo-local config. |
| [`setup-repos-from-bundle.sh`](../scripts/setup-repos-from-bundle.sh) | Restores repo-local config and can clone missing repos from recorded origins. |
| [`export-private-machine-state.sh`](../scripts/export-private-machine-state.sh) | Bundles AWS, kube, SSH, GPG, WireGuard, and `~/encrypted` state from standard locations. |
| [`setup-private-machine-state.sh`](../scripts/setup-private-machine-state.sh) | Restores the private machine bundle, imports GPG keys, fixes common permissions, and reloads NetworkManager when run as root. |
| [`export-file-bundle.sh`](../scripts/export-file-bundle.sh) | Packages a staged directory tree for transfer. |
| [`setup-file-bundle.sh`](../scripts/setup-file-bundle.sh) | Restores a file-transfer bundle into a target directory. |
| [`prefetch-displaylink.sh`](../scripts/prefetch-displaylink.sh) | Prefetches the DisplayLink archive after EULA acceptance. |

## AI And Dotfile Setup

The workstation activation scripts install small user configs from
[`dotfiles/`](../dotfiles):

- [Terminator](https://gnome-terminator.org/) config.
- [Zed](https://zed.dev/) settings, keymap, and theme.
- [GitHub CLI](https://cli.github.com/) config.
- [`AGENTS.md`](../AGENTS.md), a tool-neutral guide for AI assistants.
- [`git-commit-policy`](../dotfiles/codex/skills/git-commit-policy/SKILL.md),
  a Codex-compatible skill that defaults to Conventional Commits and signed
  commits.
- [`github-stacked-prs`](../dotfiles/codex/skills/github-stacked-prs/SKILL.md),
  a Codex-compatible skill for planning and managing formally linked GitHub PR
  stacks for large features with dependent review layers.
- [`ste-system-docs`](../dotfiles/codex/skills/ste-system-docs/SKILL.md), a
  Codex-compatible skill that uses STE-informed prose and faithful Mermaid or
  ASCII diagrams for system documentation, runbooks, troubleshooting, and
  debugging.
