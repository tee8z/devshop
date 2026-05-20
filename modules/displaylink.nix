{ lib, ... }:

{
  services.xserver.videoDrivers = lib.mkForce [
    "modesetting"
    "displaylink"
  ];

  # GNOME 49 no longer exposes a GNOME Xorg session in this nixpkgs pin.
  # Keep GDM/GNOME on Wayland and let DisplayLink/EVDI provide the USB monitor.
  services.displayManager.gdm.wayland = lib.mkForce true;
}
