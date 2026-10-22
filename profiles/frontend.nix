{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    nodejs-bin_22
    corepack_22
    fnm
  ];
}
