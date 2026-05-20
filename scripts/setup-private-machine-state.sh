#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: setup-private-machine-state.sh [options]

Restore a private machine bundle created by export-private-machine-state.sh.
This copies AWS, WireGuard, kube, encrypted-folder, and SSH files back to their
expected paths, imports GPG keys, and fixes common secret-file permissions.

Options:
  --bundle-dir PATH       Bundle directory. Default: BUNDLE_DIR or <devshop>/private-machine-bundle
  --user USER             Home user to restore for. Default: $SUDO_USER when set, else current user
  --home PATH             Home directory to restore into. Default: passwd entry for --user
  --overwrite             Replace existing files instead of skipping them
  --dry-run               Print actions without changing files
  -h, --help              Show this help

Run with sudo to restore /etc/wireguard or NetworkManager system connection
profiles. Home files can be restored as the normal user.
EOF
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
setup_repo="$(cd -- "$script_dir/.." && pwd)"

default_user() {
  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    printf '%s\n' "$SUDO_USER"
  else
    id -un
  fi
}

home_for_user() {
  local user="$1"
  getent passwd "$user" | cut -d: -f6
}

target_user="$(default_user)"
target_home=""
bundle_dir="${BUNDLE_DIR:-$setup_repo/private-machine-bundle}"
overwrite=0
dry_run=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --bundle-dir)
      bundle_dir="${2:?missing value for --bundle-dir}"
      shift 2
      ;;
    --user)
      target_user="${2:?missing value for --user}"
      shift 2
      ;;
    --home)
      target_home="${2:?missing value for --home}"
      shift 2
      ;;
    --overwrite)
      overwrite=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
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

if [ -z "$target_home" ]; then
  target_home="$(home_for_user "$target_user")"
fi

if [ -z "$target_home" ]; then
  echo "could not find home directory for user $target_user" >&2
  exit 1
fi

target_group="$(id -gn "$target_user" 2>/dev/null || printf 'users')"

manifest_file="$bundle_dir/manifest.tsv"

if [ ! -f "$manifest_file" ]; then
  echo "bundle is missing manifest.tsv: $bundle_dir" >&2
  exit 1
fi

run_as_target_user() {
  if [ "$(id -u)" -eq 0 ] && [ "$target_user" != "root" ]; then
    sudo -H -u "$target_user" env HOME="$target_home" "$@"
  else
    HOME="$target_home" "$@"
  fi
}

chown_home_path() {
  local path="$1"
  if [ "$(id -u)" -eq 0 ] && [ "$target_user" != "root" ]; then
    chown "$target_user:$target_group" "$path" 2>/dev/null || true
  fi
}

chown_home_tree() {
  local path="$1"
  if [ "$(id -u)" -eq 0 ] && [ "$target_user" != "root" ] && [ -e "$path" ]; then
    chown -R "$target_user:$target_group" "$path" 2>/dev/null || true
  fi
}

copy_one() {
  local kind="$1"
  local scope="$2"
  local relative_path="$3"
  local bundle_path="$4"
  local mode="$5"
  local source="$bundle_dir/$bundle_path"
  local dest

  case "$scope" in
    home)
      dest="$target_home/$relative_path"
      ;;
    system)
      dest="/$relative_path"
      if [ "$(id -u)" -ne 0 ]; then
        printf 'needs sudo, skipping system file: %s\n' "$dest"
        return 1
      fi
      ;;
    gpg)
      return 0
      ;;
    *)
      printf 'unknown scope, skipping: %s %s\n' "$scope" "$relative_path" >&2
      return 1
      ;;
  esac

  if [ ! -f "$source" ]; then
    printf 'missing bundled file, skipping: %s\n' "$source" >&2
    return 1
  fi

  if [ -e "$dest" ] && [ "$overwrite" -ne 1 ]; then
    if cmp -s "$source" "$dest"; then
      printf 'already current: %s\n' "$dest"
      return 0
    fi
    printf 'exists, not overwritten: %s\n' "$dest"
    return 1
  fi

  if [ "$dry_run" -eq 1 ]; then
    printf 'would restore %s -> %s\n' "$source" "$dest"
    return 0
  fi

  mkdir -p -- "$(dirname -- "$dest")"
  if [ "$scope" = "home" ]; then
    chown_home_path "$(dirname -- "$dest")"
  fi

  cp -p -- "$source" "$dest"
  chmod "$mode" "$dest" 2>/dev/null || true

  if [ "$scope" = "home" ]; then
    chown_home_path "$dest"
  fi

  printf 'restored: %s\n' "$dest"
}

fix_home_permissions() {
  [ "$dry_run" -eq 0 ] || return 0

  if [ -d "$target_home/.ssh" ]; then
    chmod 700 "$target_home/.ssh" 2>/dev/null || true
    find "$target_home/.ssh" -type f -exec chmod 600 {} \; 2>/dev/null || true
    find "$target_home/.ssh" -type f -name '*.pub' -exec chmod 644 {} \; 2>/dev/null || true
    chown_home_tree "$target_home/.ssh"
  fi

  for dir in "$target_home/.aws" "$target_home/.kube" "$target_home/.gnupg"; do
    if [ -d "$dir" ]; then
      chmod 700 "$dir" 2>/dev/null || true
      find "$dir" -type f -exec chmod 600 {} \; 2>/dev/null || true
      chown_home_tree "$dir"
    fi
  done

  for dir in "$target_home/encrypted" "$target_home/.config/wireguard" "$target_home/wireguard"; do
    chown_home_tree "$dir"
  done
}

fix_system_permissions() {
  [ "$dry_run" -eq 0 ] || return 0
  [ "$(id -u)" -eq 0 ] || return 0

  if [ -d /etc/wireguard ]; then
    chmod 700 /etc/wireguard 2>/dev/null || true
    find /etc/wireguard -type f -exec chmod 600 {} \; 2>/dev/null || true
  fi

  if [ -d /etc/NetworkManager/system-connections ]; then
    find /etc/NetworkManager/system-connections -type f -name '*.nmconnection' -exec chmod 600 {} \; 2>/dev/null || true
  fi
}

import_gpg() {
  local public="$bundle_dir/gpg/public-keys.asc"
  local secret="$bundle_dir/gpg/secret-keys.asc"
  local ownertrust="$bundle_dir/gpg/ownertrust.txt"

  if ! command -v gpg >/dev/null 2>&1; then
    echo "gpg is not installed; skipping GPG import" >&2
    return 0
  fi

  if [ "$dry_run" -eq 1 ]; then
    [ -s "$public" ] && printf 'would import GPG public keys from %s\n' "$public"
    [ -s "$secret" ] && printf 'would import GPG secret keys from %s\n' "$secret"
    [ -s "$ownertrust" ] && printf 'would import GPG ownertrust from %s\n' "$ownertrust"
    return 0
  fi

  mkdir -p -- "$target_home/.gnupg"
  chmod 700 "$target_home/.gnupg" 2>/dev/null || true
  chown_home_tree "$target_home/.gnupg"

  [ -s "$public" ] && run_as_target_user gpg --batch --yes --import "$public"
  [ -s "$secret" ] && run_as_target_user gpg --batch --yes --import "$secret"
  [ -s "$ownertrust" ] && run_as_target_user gpg --batch --yes --import-ownertrust "$ownertrust"
}

restored=0
skipped=0

while IFS=$'\t' read -r kind scope relative_path source_path bundle_path mode; do
  [ "$kind" != "kind" ] || continue
  if copy_one "$kind" "$scope" "$relative_path" "$bundle_path" "$mode"; then
    restored=$((restored + 1))
  else
    skipped=$((skipped + 1))
  fi
done < "$manifest_file"

import_gpg
fix_home_permissions
fix_system_permissions

if [ "$dry_run" -eq 0 ] && [ "$(id -u)" -eq 0 ] && command -v systemctl >/dev/null 2>&1; then
  systemctl reload NetworkManager >/dev/null 2>&1 || true
fi

echo "private restore complete: restored=$restored skipped=$skipped"
