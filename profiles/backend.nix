{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    python3
    python3Packages.pip
    poetry
    uv
    ruby

    go
    gopls
    delve
    jetbrains.goland

    gcc
    clang
    lld
    mold
    cmake
    gnumake
    pkg-config
    openssl
    automake
    autoconf
    libtool
    protobuf
    graphviz

    yaml-language-server
    yamllint
    yq-go
    taplo

    postgresql_16
    pgadmin4-runtime
  ];
}
