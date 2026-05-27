# Template hardware configuration.
#
# Replace this file with the output of:
#
#   sudo nixos-generate-config --show-hardware-config > hosts/workstation/hardware-configuration.nix
#
# before applying the flake to a real machine.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  boot.initrd.luks.devices."nixos-root" =
    {
      # Replace this with the LUKS container UUID or another stable path from
      # the target machine, for example /dev/disk/by-uuid/<luks-uuid>.
      device = "/dev/disk/by-label/cryptroot";
      allowDiscards = true;
    };

  fileSystems."/" =
    {
      device = "/dev/mapper/nixos-root";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  # Do not point swap at a plain block device on encrypted systems. Prefer a
  # swapfile inside the encrypted root filesystem or add a separate LUKS swap
  # mapping here.
  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
