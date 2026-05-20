{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    awscli2
    terraform
    kubectl
    kubernetes-helm
    k9s
    kubie
    tilt
    k3d
    k3s
    wireguard-tools
    tor
    torsocks
    networkmanagerapplet
  ];
}
