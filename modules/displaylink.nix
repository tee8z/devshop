{ config, lib, pkgs, ... }:

let
  cfg = config.devshop.displaylink;
  inherit (lib) mkOption types;

  edidOverrides = cfg.edidOverrides;
  hasEdidOverrides = edidOverrides != { };

  edidFirmwarePackages = lib.mapAttrsToList
    (name: override:
      pkgs.runCommand "displaylink-${name}-edid-firmware" { } ''
        install -D -m 0644 ${override.edidFile} "$out/lib/firmware/${override.firmwarePath}"
      '')
    edidOverrides;

  serviceName = name: "displaylink-edid-override-${name}";
  edidArg = override: "drm.edid_firmware=${override.connector}:${override.firmwarePath}";
  videoArg = override: "video=${override.connector}:${override.forceMode}";
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

    # GNOME 49 no longer exposes a GNOME Xorg session in this nixpkgs pin.
    # Keep GDM/GNOME on Wayland and let DisplayLink/EVDI provide the USB monitor.
    services.displayManager.gdm.wayland = lib.mkForce true;

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
        dlm.wantedBy = [ "multi-user.target" ];
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
            '';
          })
        edidOverrides;
  };
}
