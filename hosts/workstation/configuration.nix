{ config, lib, pkgs, ... }:

let
  userName = "developer";
  userFullName = "Developer";
  userEmail = "developer@example.com";
  gitSigningKey = null;
  hostName = "workstation";
  repoDirectoryName = "devshop";
  homeDirectory = "/home/${userName}";

  # Set this to the interface name for a preferred dock ethernet device, or
  # leave it null to skip the wired-preferred NetworkManager behavior.
  hubEthernetInterface = null;
  hubEthernetEnabled = hubEthernetInterface != null;
  hubEthernetProfile = "hub-ethernet";
  hubEthernetConnectScript =
    { attempts, sleepSeconds }:
    ''
      iface=${lib.escapeShellArg hubEthernetInterface}
      profile=${lib.escapeShellArg hubEthernetProfile}
      max_attempts=${toString attempts}
      sleep_seconds=${toString sleepSeconds}
      attempt=1

      while [ "$attempt" -le "$max_attempts" ]; do
        if ! ${pkgs.networkmanager}/bin/nmcli --wait 2 -t -f DEVICE device status 2>/dev/null | ${pkgs.gnugrep}/bin/grep -Fxq "$iface"; then
          if [ "$attempt" -lt "$max_attempts" ]; then
            ${pkgs.coreutils}/bin/sleep "$sleep_seconds"
          fi
          attempt=$((attempt + 1))
          continue
        fi

        carrier="$(${pkgs.networkmanager}/bin/nmcli -g WIRED-PROPERTIES.CARRIER device show "$iface" 2>/dev/null || true)"
        if [ "$carrier" = "on" ]; then
          active="$(${pkgs.networkmanager}/bin/nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null || true)"
          if [ "$active" = "$profile" ] && ${pkgs.iputils}/bin/ping -I "$iface" -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
            ${pkgs.networkmanager}/bin/nmcli radio wifi off >/dev/null 2>&1 || true
            exit 0
          fi

          if [ "$active" = "$iface" ]; then
            ${pkgs.networkmanager}/bin/nmcli connection delete "$iface" >/dev/null 2>&1 || true
          fi

          echo "Activating $profile on $iface (attempt $attempt)"
          ${pkgs.networkmanager}/bin/nmcli --wait 10 connection up "$profile" ifname "$iface" >/dev/null 2>&1 || true

          if ${pkgs.iputils}/bin/ping -I "$iface" -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
            ${pkgs.networkmanager}/bin/nmcli radio wifi off >/dev/null 2>&1 || true
            exit 0
          fi
        fi

        if [ "$attempt" -lt "$max_attempts" ]; then
          ${pkgs.coreutils}/bin/sleep "$sleep_seconds"
        fi
        attempt=$((attempt + 1))
      done

      exit 0
    '';
  hubEthernetWifiScript = pkgs.writeShellScript "hub-ethernet-wifi-fallback" ''
    iface=${lib.escapeShellArg hubEthernetInterface}
    profile=${lib.escapeShellArg hubEthernetProfile}
    event_iface="''${1:-}"
    event_action="''${2:-}"

    ethernet_working() {
      carrier="$(${pkgs.networkmanager}/bin/nmcli -g WIRED-PROPERTIES.CARRIER device show "$iface" 2>/dev/null || true)"
      active="$(${pkgs.networkmanager}/bin/nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null || true)"
      [ "$carrier" = "on" ] \
        && [ "$active" = "$profile" ] \
        && ${pkgs.iputils}/bin/ping -I "$iface" -c 1 -W 2 1.1.1.1 >/dev/null 2>&1
    }

    case "$event_action" in
      down|pre-down)
        if [ "$event_iface" = "$iface" ]; then
          ${pkgs.networkmanager}/bin/nmcli radio wifi on >/dev/null 2>&1 || true
        fi
        exit 0
        ;;
    esac

    if ethernet_working; then
      ${pkgs.networkmanager}/bin/nmcli radio wifi off >/dev/null 2>&1 || true
    fi
  '';

  dashToDockGSettingsSchema = pkgs.stdenvNoCC.mkDerivation {
    name = "dash-to-dock-gsettings-schema";
    dontUnpack = true;

    installPhase = ''
      schema_dir="$out/share/gsettings-schemas/$name/glib-2.0/schemas"
      mkdir -p "$schema_dir"
      cp ${pkgs.gnomeExtensions.dash-to-dock}/share/gnome-shell/extensions/${pkgs.gnomeExtensions.dash-to-dock.extensionUuid}/schemas/org.gnome.shell.extensions.dash-to-dock.gschema.xml "$schema_dir/"
    '';
  };

  nixCleanOld = pkgs.writeShellScriptBin "nix-clean-old" ''
    set -eu

    flake_result="$HOME/repos/${repoDirectoryName}/result"
    if [ -L "$flake_result" ]; then
      echo "Removing flake build GC root: $flake_result"
      rm -f "$flake_result"
    fi

    echo "Deleting old generations for the ${userName} user profile..."
    ${pkgs.nix}/bin/nix-collect-garbage -d

    echo "Deleting old generations for system and root profiles..."
    sudo /run/current-system/sw/bin/nix-collect-garbage -d
  '';

  zedUpdateFlake = pkgs.writeShellScriptBin "zed-update-flake" ''
    set -eu

    usage() {
      echo "Usage: zed-update-flake VERSION"
      echo "Example: zed-update-flake 1.18.0"
    }

    if [ "$#" -ne 1 ]; then
      usage >&2
      exit 2
    fi

    version="$1"
    if ! printf '%s\n' "$version" | ${pkgs.gnugrep}/bin/grep -Eq '^[0-9]+([.][0-9]+)+$'; then
      echo "Invalid Zed version: $version" >&2
      usage >&2
      exit 2
    fi

    repo="$HOME/repos/${repoDirectoryName}"
    flake="$repo/flake.nix"
    if [ ! -f "$flake" ]; then
      echo "Cannot find $flake" >&2
      exit 1
    fi

    url="https://cloud.zed.dev/releases/stable/$version/download?asset=zed&arch=x86_64&os=linux&source=install.sh"
    name="zed-$version-linux-x86_64.tar.gz"

    echo "Prefetching Zed $version..."
    json="$(${pkgs.nix}/bin/nix --extra-experimental-features nix-command store prefetch-file --json --hash-type sha256 --name "$name" "$url")"
    hash="$(printf '%s\n' "$json" | ${pkgs.jq}/bin/jq -r '.hash')"

    if [ -z "$hash" ] || [ "$hash" = "null" ]; then
      echo "Could not read a sha256 hash from nix store prefetch-file output." >&2
      exit 1
    fi

    if ! ${pkgs.gnugrep}/bin/grep -q 'zedVersion = "' "$flake"; then
      echo "Could not find zedVersion in $flake" >&2
      exit 1
    fi

    if ! ${pkgs.gnugrep}/bin/grep -q 'zedHash = "sha256-' "$flake"; then
      echo "Could not find zedHash in $flake" >&2
      exit 1
    fi

    ZED_VERSION_NEW="$version" ZED_HASH_NEW="$hash" ${pkgs.perl}/bin/perl -0pi -e '
      s/zedVersion = "[^"]+";/zedVersion = "$ENV{ZED_VERSION_NEW}";/;
      s/zedHash = "sha256-[^"]+";/zedHash = "$ENV{ZED_HASH_NEW}";/;
    ' "$flake"

    ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt "$flake"

    echo "Updated $flake to Zed $version"
    echo "hash = $hash"
    echo "Run: rebuild"
  '';

in
{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/all.nix
  ];

  networking.hostName = hostName;
  time.timeZone = "Etc/UTC";
  i18n.defaultLocale = "en_US.UTF-8";
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    download-buffer-size = 536870912;
  };

  nixpkgs.config.allowUnfree = true;
  environment.sessionVariables = {
    XKB_CONFIG_ROOT = "${pkgs.xkeyboard_config}/share/X11/xkb";
    # Slack's Electron wrapper enables Wayland PipeWire capture for huddles
    # when this is set in a Wayland session.
    NIXOS_OZONE_WL = "1";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Keep the default NixOS kernel for better out-of-tree module compatibility
  # if the DisplayLink profile is enabled later.
  boot.kernelPackages = pkgs.linuxPackages;

  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "systemd-resolved";
  networking.networkmanager.wifi.backend = "wpa_supplicant";
  networking.networkmanager.settings.main = lib.mkIf hubEthernetEnabled {
    no-auto-default = hubEthernetInterface;
  };
  networking.networkmanager.dispatcherScripts = lib.mkIf hubEthernetEnabled [
    {
      source = hubEthernetWifiScript;
      type = "basic";
    }
  ];
  networking.networkmanager.ensureProfiles.profiles = lib.mkIf hubEthernetEnabled {
    "hub-ethernet" = {
      connection = {
        id = hubEthernetProfile;
        type = "ethernet";
        interface-name = hubEthernetInterface;
        autoconnect = true;
        "autoconnect-priority" = 100;
        "autoconnect-retries" = 0;
      };

      ipv4 = {
        method = "auto";
        "route-metric" = 50;
      };

      ipv6 = {
        method = "auto";
        "route-metric" = 50;
      };
    };
  };
  services.udev.extraRules = lib.mkIf hubEthernetEnabled ''
    ACTION=="add", SUBSYSTEM=="net", KERNEL=="${hubEthernetInterface}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="hub-ethernet-connect.service"
  '';
  systemd.services.hub-ethernet-connect = lib.mkIf hubEthernetEnabled {
    description = "Activate USB hub ethernet through NetworkManager";
    wants = [
      "NetworkManager.service"
      "NetworkManager-ensure-profiles.service"
    ];
    after = [
      "NetworkManager.service"
      "NetworkManager-ensure-profiles.service"
    ];
    wantedBy = [
      "multi-user.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "2min";
    };
    script = hubEthernetConnectScript {
      attempts = 12;
      sleepSeconds = 5;
    };
  };
  networking.firewall.enable = true;
  services.resolved.enable = true;

  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.fwupd.enable = true;
  services.printing.enable = true;
  services.gnome.gnome-keyring.enable = true;
  services.gnome.gcr-ssh-agent.enable = true;

  services.xserver.enable = true;
  services.xserver.videoDrivers = [
    "modesetting"
  ];
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome = {
    enable = true;
    favoriteAppsOverride = ''
      [org.gnome.shell]
      favorite-apps=[ 'firefox.desktop', 'org.gnome.TextEditor.desktop', 'obsidian.desktop', 'slack.desktop', 'dev.zed.Zed.desktop', 'terminator.desktop', 'org.pgadmin.pgadmin4.desktop', 'org.gnome.Nautilus.desktop', 'LocalSend.desktop', 'org.gnome.SystemMonitor.desktop', 'org.gnome.Settings.desktop' ]
    '';
    extraGSettingsOverridePackages = [
      pkgs.gsettings-desktop-schemas
      dashToDockGSettingsSchema
    ];
    extraGSettingsOverrides = ''
      [org.gnome.desktop.interface]
      color-scheme='prefer-dark'
      clock-format='12h'
      enable-hot-corners=false

      [org.gnome.desktop.wm.preferences]
      button-layout='appmenu:minimize,maximize,close'

      [org.gnome.desktop.session]
      idle-delay=uint32 0

      [org.gnome.desktop.screensaver]
      lock-enabled=true
      lock-delay=uint32 7200

      [org.gnome.desktop.notifications]
      show-in-lock-screen=true

      [org.gnome.mutter]
      workspaces-only-on-primary=true

      [org.gnome.shell]
      enabled-extensions=['dash-to-dock@micxgx.gmail.com', 'caffeine@patapon.info']

      [org.gnome.shell.extensions.dash-to-dock]
      dock-position='LEFT'
      dock-fixed=true
      autohide=false
      autohide-in-fullscreen=false
      intellihide=false
      manualhide=false
      require-pressure-to-show=false
      multi-monitor=false
      preferred-monitor-by-connector='primary'
      disable-overview-on-startup=true
      extend-height=true
    '';
  };
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/mutter" = {
          workspaces-only-on-primary = true;
        };
        "org/gnome/shell/extensions/dash-to-dock" = {
          multi-monitor = false;
          preferred-monitor-by-connector = "primary";
        };
      };
      locks = [
        "/org/gnome/mutter/workspaces-only-on-primary"
        "/org/gnome/shell/extensions/dash-to-dock/multi-monitor"
        "/org/gnome/shell/extensions/dash-to-dock/preferred-monitor-by-connector"
      ];
    }
  ];

  environment.systemPackages = [
    nixCleanOld
    zedUpdateFlake

    pkgs.xkeyboard_config

    pkgs.mesa
    pkgs.vulkan-loader
    pkgs.vulkan-tools

    pkgs.gnomeExtensions.caffeine
    pkgs.gnomeExtensions.dash-to-dock
    pkgs.gnome-system-monitor
  ];

  environment.etc."pgadmin/config_system.py".text = ''
    LLM_ENABLED = True
    DEFAULT_LLM_PROVIDER = 'openai'
    OPENAI_API_KEY_FILE = '~/.openai-api-key'
    MAX_LLM_TOOL_ITERATIONS = 20
  '';

  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita-dark";
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
    config.common = {
      default = [
        "gnome"
        "gtk"
      ];
      "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
    };
  };
  xdg.mime.defaultApplications = {
    "application/xhtml+xml" = "firefox.desktop";
    "text/html" = "firefox.desktop";
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
    "x-scheme-handler/slack" = "slack.desktop";
  };

  virtualisation.docker.enable = true;

  users.users.${userName} = {
    isNormalUser = true;
    description = userFullName;
    extraGroups = [
      "docker"
      "networkmanager"
      "wheel"
      "wireshark"
    ];
    shell = pkgs.zsh;
  };

  security.sudo.extraRules = [
    {
      users = [ userName ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/nix-collect-garbage";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    histSize = 10000;
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake $HOME/repos/${repoDirectoryName}#workstation";
      nix-clean-old = "${nixCleanOld}/bin/nix-clean-old";
      zed-update-flake = "${zedUpdateFlake}/bin/zed-update-flake";
      onlymaster = "git branch | grep -v \"master\" | xargs git branch -D";
    };
    ohMyZsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [ "git" ];
    };
    interactiveShellInit = lib.mkAfter ''
      export KUBE_EDITOR="nano"
      export GOPATH="$HOME/go"
      export BUN_INSTALL="$HOME/.bun"
      export GPG_TTY="$(tty)"

      path=(
        "$HOME/bin"
        "$HOME/.local/bin"
        "$HOME/.cargo/bin"
        "$HOME/go/bin"
        "$BUN_INSTALL/bin"
        $path
      )

      [ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"
      [ -s "$HOME/.rover/env" ] && source "$HOME/.rover/env"
      [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

      git_stash_prompt() {
        local count

        git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return
        git rev-parse --verify refs/stash >/dev/null 2>&1 || return

        count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
        [[ "$count" != "0" ]] && echo " %{$fg[yellow]%}{''${count}}%{$reset_color%}"
      }

      PROMPT+='$(git_stash_prompt)'
    '';
  };
  programs.firefox.enable = true;
  programs.ssh = {
    startAgent = false;
    askPassword = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";
  };
  programs.git = {
    enable = true;
    config = {
      user = {
        name = userFullName;
        email = userEmail;
      } // lib.optionalAttrs (gitSigningKey != null) {
        signingkey = gitSigningKey;
      };
      commit.gpgsign = gitSigningKey != null;
      url."git@github.com:".insteadOf = "https://github.com/";
      pull.rebase = true;
      core.editor = "nano";
      tag = {
        gpgsign = gitSigningKey != null;
        forcesignannotated = false;
      };
      gpg.program = "gpg";
    };
  };
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-gnome3;
  };
  programs.localsend = {
    enable = true;
    openFirewall = true;
  };
  # Support external scripts with hard-coded paths like /bin/bash and /usr/bin/zsh.
  services.envfs = {
    enable = true;
    extraFallbackPathCommands = ''
      ln -s ${pkgs.bash}/bin/bash $out/bash
      ln -s ${pkgs.zsh}/bin/zsh $out/zsh
    '';
  };
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ userName ];
  };
  programs.wireshark.enable = true;
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      alsa-lib
      wayland
      libxkbcommon
      libGL
      libx11
      libxcb
      libxcursor
      libxi
      libxrandr
      libxrender
      libxfixes
      libxext
      libxkbfile
      vulkan-loader
      fontconfig
      freetype
    ];
  };
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  services.tor.enable = true;
  systemd.services.tor = {
    wants = [ "systemd-resolved.service" ];
    after = [ "systemd-resolved.service" ];
  };

  system.activationScripts.ensureUserZshrc.text = ''
        home=${lib.escapeShellArg homeDirectory}
        zshrc="$home/.zshrc"

        if [ -d "$home" ] && [ ! -e "$zshrc" ]; then
          cat > "$zshrc" <<'EOF'
    # Created by the workstation flake.
    # System-wide zsh settings are managed from the NixOS config.
    EOF
          chown ${lib.escapeShellArg userName}:users "$zshrc"
          chmod 0644 "$zshrc"
        fi
  '';

  system.activationScripts.installUserTerminatorConfig.text = ''
    home=${lib.escapeShellArg homeDirectory}
    config_dir="$home/.config/terminator"

    if [ -d "$home" ]; then
      install -d -m 0755 -o ${lib.escapeShellArg userName} -g users "$config_dir"
      install -m 0644 -o ${lib.escapeShellArg userName} -g users ${../../dotfiles/terminator/config} "$config_dir/config"
    fi
  '';

  system.activationScripts.installUserZedConfig.text = ''
    home=${lib.escapeShellArg homeDirectory}
    config_dir="$home/.config/zed"
    themes_dir="$config_dir/themes"

    if [ -d "$home" ]; then
      install -d -m 0755 -o ${lib.escapeShellArg userName} -g users "$config_dir"
      install -d -m 0755 -o ${lib.escapeShellArg userName} -g users "$themes_dir"
      install -m 0644 -o ${lib.escapeShellArg userName} -g users ${../../dotfiles/zed/settings.json} "$config_dir/settings.json"
      install -m 0644 -o ${lib.escapeShellArg userName} -g users ${../../dotfiles/zed/keymap.json} "$config_dir/keymap.json"
      install -m 0644 -o ${lib.escapeShellArg userName} -g users ${../../dotfiles/zed/themes/vscode-dark-modern.json} "$themes_dir/vscode-dark-modern.json"
    fi
  '';

  system.activationScripts.installUserGitHubConfig.text = ''
    home=${lib.escapeShellArg homeDirectory}
    config_dir="$home/.config/gh"

    if [ -d "$home" ]; then
      install -d -m 0755 -o ${lib.escapeShellArg userName} -g users "$config_dir"
      install -m 0644 -o ${lib.escapeShellArg userName} -g users ${../../dotfiles/gh/config.yml} "$config_dir/config.yml"
    fi
  '';

  system.activationScripts.installUserCodexSkills.text = ''
    user_home=${lib.escapeShellArg homeDirectory}
    skills_dir="$user_home/.codex/skills"
    commit_skill_dir="$skills_dir/git-commit-policy"
    docs_skill_dir="$skills_dir/ste-system-docs"
    stack_skill_dir="$skills_dir/github-stacked-prs"
    via_skill_dir="$skills_dir/via-integrations"

    if [ -d "$user_home" ]; then
      install -d -m 0755 -o ${lib.escapeShellArg userName} -g users "$commit_skill_dir" "$docs_skill_dir" "$stack_skill_dir" "$via_skill_dir"
      install -m 0644 -o ${lib.escapeShellArg userName} -g users ${../../dotfiles/codex/skills/git-commit-policy/SKILL.md} "$commit_skill_dir/SKILL.md"
      install -m 0644 -o ${lib.escapeShellArg userName} -g users ${../../dotfiles/codex/skills/ste-system-docs/SKILL.md} "$docs_skill_dir/SKILL.md"
      install -m 0644 -o ${lib.escapeShellArg userName} -g users ${../../dotfiles/codex/skills/github-stacked-prs/SKILL.md} "$stack_skill_dir/SKILL.md"
      install -m 0644 -o ${lib.escapeShellArg userName} -g users ${../../dotfiles/codex/skills/via-integrations/SKILL.md} "$via_skill_dir/SKILL.md"
    fi
  '';

  # Initial install version. Do not change except after reading NixOS release notes.
  system.stateVersion = "25.11";
}
