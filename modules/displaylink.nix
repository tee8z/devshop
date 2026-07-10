{ config, lib, pkgs, ... }:

let
  cfg = config.devshop.displaylink;
  inherit (lib) mkOption types;

  edidOverrides = cfg.edidOverrides;
  hasEdidOverrides = edidOverrides != { };
  hasEvdiConnectEdidFile = cfg.evdiConnectEdidFile != null;

  evdiEdidShim = pkgs.callPackage ../packages/displaylink-evdi-edid-shim.nix {
    realLibevdi = config.boot.kernelPackages.evdi;
  };

  edidFirmwarePackages = lib.mapAttrsToList
    (name: override:
      pkgs.runCommand "displaylink-${name}-edid-firmware"
        {
          # edido writes the EDID bytes through DRM debugfs and expects the
          # exact uncompressed firmware filename passed in drm.edid_firmware.
          compressFirmware = false;
        }
        ''
        install -D -m 0644 ${override.edidFile} "$out/lib/firmware/${override.firmwarePath}"
      '')
    edidOverrides;

  serviceName = name: "displaylink-edid-override-${name}";
  edidArg = override: "drm.edid_firmware=${override.connector}:${override.firmwarePath}";
  videoArg = override: "video=${override.connector}:${override.forceMode}";
  sysfsStatusMode = override: if override.forceMode == "D" then "on-digital" else "on";
  usbRule = name: override:
    lib.optionalString (override.usbVendorId != null && override.usbProductId != null) ''
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="${override.usbVendorId}", ATTR{idProduct}=="${override.usbProductId}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="${serviceName name}.service"
    '';
  drmRules = name: override: lib.optionalString override.triggerOnDrmEvents ''
    ACTION=="add", SUBSYSTEM=="drm", KERNEL=="card*-${override.connector}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="${serviceName name}.service"
    ACTION=="change", SUBSYSTEM=="drm", KERNEL=="card*-${override.connector}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="${serviceName name}.service"
  '';
in
{
  options.devshop.displaylink = {
    initialDeviceCount = mkOption {
      type = types.ints.positive;
      default = 1;
      description = ''
        Number of EVDI DRM devices to create before the display manager starts.
      '';
    };

    evdiConnectEdidFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Optional EDID file to inject into DisplayLinkManager's libevdi connect
        calls when the manager detects a monitor but EVDI receives no EDID.
      '';
    };

    edidOverrides = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          connector = mkOption {
            type = types.str;
            default = name;
            description = "DRM connector name to apply the EDID override to.";
          };

          edidFile = mkOption {
            type = types.path;
            description = "Binary EDID file to install into firmware and apply.";
          };

          firmwarePath = mkOption {
            type = types.str;
            default = "edid/displaylink-${name}.bin";
            description = "Path under /lib/firmware used for the EDID file.";
          };

          forceMode = mkOption {
            type = types.enum [ "e" "D" ];
            default = "D";
            description = ''
              Kernel video force suffix passed to edido. Use D for digital
              connectors and e for generic enabled connectors.
            '';
          };

          usbVendorId = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Optional USB vendor ID that should trigger the override service.";
          };

          usbProductId = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Optional USB product ID that should trigger the override service.";
          };

          triggerOnDrmEvents = mkOption {
            type = types.bool;
            default = true;
            description = "Whether DRM connector add/change events should trigger the override service.";
          };

          delaySeconds = mkOption {
            type = types.ints.unsigned;
            default = 2;
            description = "Seconds to wait after hotplug before applying the EDID override.";
          };
        };
      }));
      default = { };
      description = ''
        DisplayLink connector EDID overrides to apply at boot and hotplug.
      '';
    };
  };

  config = {
    services.xserver.videoDrivers = lib.mkForce [
      "modesetting"
      "displaylink"
    ];

    # Create EVDI DRM devices before GNOME starts so DisplayLink outputs are
    # present for the compositor instead of being hot-added after login.
    boot.extraModprobeConfig = ''
      options evdi initial_device_count=${toString cfg.initialDeviceCount}
    '';

    boot.kernelParams = lib.mkIf hasEdidOverrides (
      lib.mapAttrsToList (_: override: edidArg override) edidOverrides
    );
    hardware.firmware = lib.mkIf hasEdidOverrides edidFirmwarePackages;
    services.udev.extraRules = lib.mkIf hasEdidOverrides (
      lib.concatStringsSep "\n" (
        lib.flatten (
          lib.mapAttrsToList
            (name: override: [
              (usbRule name override)
              (drmRules name override)
            ])
            edidOverrides
        )
      )
    );
    systemd.services =
      {
        # The NixOS DisplayLink service exists when the displaylink video driver is
        # enabled, but does not always get pulled into a normal graphical boot.
        dlm = {
          wantedBy = [ "multi-user.target" ];
          environment = lib.mkIf hasEvdiConnectEdidFile {
            DEVSHOP_DISPLAYLINK_EVDI_EDID = "${cfg.evdiConnectEdidFile}";
            LD_LIBRARY_PATH = "${evdiEdidShim}/lib";
          };
        };
      }
      // lib.mapAttrs'
        (name: override:
          lib.nameValuePair (serviceName name) {
            description = "Apply EDID override for DisplayLink connector ${override.connector}";
            wants = [ "dlm.service" ];
            after = [ "dlm.service" ];
            wantedBy = [ "graphical.target" ];
            serviceConfig = {
              Type = "oneshot";
              TimeoutStartSec = "30s";
            };
            script = ''
              ${pkgs.coreutils}/bin/sleep ${toString override.delaySeconds}
              ${pkgs.edido}/bin/edido ${lib.escapeShellArg (edidArg override)} ${lib.escapeShellArg (videoArg override)}

              shopt -s nullglob
              for connector in /sys/class/drm/card*-${override.connector}; do
                modes="$connector/modes"
                status="$connector/status"
                if [ ! -e "$status" ] || ${pkgs.gnugrep}/bin/grep -q . "$modes"; then
                  continue
                fi

                stamp="/run/${serviceName name}-$(${pkgs.coreutils}/bin/basename "$connector").status-trigger"
                now="$(${pkgs.coreutils}/bin/date +%s)"
                last="$(${pkgs.coreutils}/bin/cat "$stamp" 2>/dev/null || true)"
                case "$last" in
                  "" | *[!0-9]*) last=0 ;;
                esac
                if [ "$((now - last))" -lt 10 ]; then
                  echo "Skipping sysfs status fallback for $connector; triggered recently"
                  continue
                fi

                echo "$now" > "$stamp"
                echo "Writing ${sysfsStatusMode override} to $status after EDID override left no modes"
                if ! echo ${lib.escapeShellArg (sysfsStatusMode override)} > "$status"; then
                  echo "Unable to write sysfs status fallback for $connector" >&2
                fi
              done
            '';
          })
        edidOverrides;
  };
}
