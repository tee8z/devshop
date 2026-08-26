{
  description = "Devshop: NixOS development workstation profiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Use current sccache packaging independently of the NixOS Stable package set.
    nixpkgs-sccache.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-zed.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Use current VS Code packaging independently of the NixOS Stable package set.
    nixpkgs-vscode.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-sccache, nixpkgs-zed, nixpkgs-vscode, ... }:
    let
      system = "x86_64-linux";
      vscodeVersion = "1.132.0";
      vscodeRevision = "df53daabb18cd157bdb08c7f01c34df936cf12f4";
      zedVersion = "1.10.0";
      devshopProfiles = {
        base = ./profiles/base.nix;
        desktop = ./profiles/desktop.nix;
        frontend = ./profiles/frontend.nix;
        backend = ./profiles/backend.nix;
        rust = ./profiles/rust.nix;
        data = ./profiles/data.nix;
        infra = ./profiles/infra.nix;
        all = ./profiles/all.nix;
      };
      desktopOverlay = final: prev:
        let
          zedPkgs = nixpkgs-zed.legacyPackages.${system};
          sccachePkgs = nixpkgs-sccache.legacyPackages.${system};
          vscodePkgs = import nixpkgs-vscode {
            inherit system;
            config.allowUnfree = true;
          };
        in
        {
          pgadmin4-runtime = final.callPackage ./packages/pgadmin4-runtime.nix { };
          sccache = sccachePkgs.sccache;

          # VS Code 1.121+ renders Mermaid diagrams natively with pan and zoom.
          vscode = vscodePkgs.vscode.overrideAttrs (oldAttrs: {
            version = vscodeVersion;
            src = vscodePkgs.fetchurl {
              name = "VSCode_${vscodeVersion}_linux-x64.tar.gz";
              url = "https://update.code.visualstudio.com/${vscodeVersion}/linux-x64/stable";
              hash = "sha256-rNrw+lV72hcglW/2XKDeCWXpLWj5fi2yI0GYRACTeu0=";
            };
            passthru = oldAttrs.passthru // {
              inherit vscodeVersion;
              rev = vscodeRevision;
              vscodeServer = vscodePkgs.srcOnly {
                name = "vscode-server-${vscodeRevision}.tar.gz";
                src = vscodePkgs.fetchurl {
                  name = "vscode-server-${vscodeRevision}.tar.gz";
                  url = "https://update.code.visualstudio.com/commit:${vscodeRevision}/server-linux-x64/stable";
                  hash = "sha256-rfWBY2apqMQwdF+W/Xg99w52BqNTEZmarFO3CyV668A=";
                };
                stdenv = vscodePkgs.stdenvNoCC;
              };
            };
            meta = oldAttrs.meta // {
              changelog = "https://code.visualstudio.com/updates/v1_132";
            };
          });

          zed-editor = final.stdenvNoCC.mkDerivation {
            pname = "zed-editor";
            version = zedVersion;

            src = final.fetchurl {
              url = "https://cloud.zed.dev/releases/stable/${zedVersion}/download?asset=zed&arch=x86_64&os=linux&source=install.sh";
              name = "zed-${zedVersion}-linux-x86_64.tar.gz";
              hash = "sha256-XImEPWl4JJnzXU8eJx0uIdPgqGCmnvrJcEV1HJE1PJ8=";
            };

            sourceRoot = "zed.app";
            dontPatchELF = true;
            dontStrip = true;

            installPhase = ''
              runHook preInstall

              mkdir -p "$out"
              cp -R . "$out/"
              chmod +x "$out/bin/zed" "$out/libexec/zed-editor"
              ln -s zed "$out/bin/zeditor"
              substituteInPlace "$out/share/applications/dev.zed.Zed.desktop" \
                --replace-fail "TryExec=zed" "TryExec=$out/bin/zed" \
                --replace-fail "Exec=zed" "Exec=$out/bin/zed"

              runHook postInstall
            '';

            meta = zedPkgs.zed-editor.meta // {
              description = "Zed editor official Linux binary";
            };
          };
          gnomeExtensions = prev.gnomeExtensions // {
            dash-to-dock = zedPkgs.gnomeExtensions.dash-to-dock;
          };
        };
    in
    {
      overlays.default = desktopOverlay;

      nixosModules = devshopProfiles // {
        profiles = devshopProfiles;
        desktop-dev = ./modules/desktop-dev.nix;
        displaylink = ./modules/displaylink.nix;
        workstation = ./hosts/workstation/configuration.nix;
      };

      nixosConfigurations = {
        workstation = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ({ ... }: { nixpkgs.overlays = [ desktopOverlay ]; })
            ./hosts/workstation/configuration.nix
            ./modules/displaylink.nix
          ];
        };
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixpkgs-fmt;
    };
}
