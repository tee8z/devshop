{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    age
    bash
    coreutils
    gawk
    gnutar
    gzip
    zsh
    git
    gh
    gnupg
    curl
    wget
    ripgrep
    fd
    jq
    tree
    tmux
    direnv
    just
    nano
    psmisc
    openssh
    sshfs
    unzip
    zip
    libsecret
    seahorse
  ];
}
