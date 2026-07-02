{
  description = "Devshop: NixOS development workstation profiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-zed.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-zed, ... }:
    let
      system = "x86_64-linux";
      zedVersion = "1.9.0";
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
        in
        {
          pgadmin4-runtime = final.callPackage ./packages/pgadmin4-runtime.nix { };

          zed-editor = final.stdenvNoCC.mkDerivation {
            pname = "zed-editor";
            version = zedVersion;

            src = final.fetchurl {
              url = "https://cloud.zed.dev/releases/stable/${zedVersion}/download?asset=zed&arch=x86_64&os=linux&source=install.sh";
              name = "zed-${zedVersion}-linux-x86_64.tar.gz";
              hash = "sha256-OeVTzjoA/ut46rY6XLcjfLRg88lZaxsZBSzre56OxN0=";
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
