{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    slack
    firefox
    obsidian

    zed-editor
    (writeShellScriptBin "zed" ''
      exec ${zed-editor}/bin/zeditor "$@"
    '')
    vscode
    terminator
    gnome-text-editor

    libreoffice-fresh
    hunspell
    hunspellDicts.en_US
    pandoc
    imagemagick
    poppler-utils
    ksnip
    flameshot
    obs-studio
    ffmpeg-full

    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji

    pavucontrol
    bluez
    bluez-tools
    gparted
    usbutils
    pciutils
    ethtool
    xorg.xrandr
    arandr
  ];
}
