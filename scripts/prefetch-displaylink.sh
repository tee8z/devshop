#!/usr/bin/env bash
set -euo pipefail

displaylink_name="displaylink-620.zip"
displaylink_url="https://www.synaptics.com/sites/default/files/exe_files/2025-09/DisplayLink%20USB%20Graphics%20Software%20for%20Ubuntu6.2-EXE.zip"
rebuild_target="${DISPLAYLINK_REBUILD_TARGET:-.#workstation}"

usage() {
  cat <<'EOF'
Usage: prefetch-displaylink.sh [options]

Prefetch Synaptics' DisplayLink driver archive after you have accepted the
DisplayLink EULA.

Options:
  --rebuild-target TARGET   Rebuild target to print after prefetching.
                            Default: DISPLAYLINK_REBUILD_TARGET or .#workstation
  -h, --help                Show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --rebuild-target)
      rebuild_target="${2:?missing value for --rebuild-target}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

cat <<EOF
This will download Synaptics' DisplayLink driver archive into the Nix store:

  ${displaylink_name}

NixOS cannot fetch this file automatically during a pure build because the
driver is distributed behind Synaptics' DisplayLink EULA.

Before continuing, review and accept the EULA from:

  https://www.synaptics.com/products/displaylink-usb-graphics-software-ubuntu-62

EOF

read -r -p "Type 'yes' if you have accepted the Synaptics DisplayLink EULA: " answer
if [[ "${answer}" != "yes" ]]; then
  echo "Aborting. DisplayLink prefetch requires EULA acceptance." >&2
  exit 1
fi

echo "Prefetching ${displaylink_name}..."
nix-prefetch-url --name "${displaylink_name}" "${displaylink_url}"

cat <<EOF

DisplayLink archive is now available to Nix.
Re-run:

  sudo nixos-rebuild switch --flake ${rebuild_target}

EOF
