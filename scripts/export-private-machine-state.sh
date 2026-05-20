#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: export-private-machine-state.sh [options]

Copy private machine state into a portable bundle for transfer to another
machine. The bundle contains secrets: AWS credentials, WireGuard configs, kube
configs, $HOME/encrypted, GPG exports, and SSH keys.

Options:
  --bundle-dir PATH       Output bundle. Default: BUNDLE_DIR or <devshop>/private-machine-bundle
  --user USER             Home user to export. Default: $SUDO_USER when set, else current user
  --home PATH             Home directory to export. Default: passwd entry for --user
  --force                 Replace an existing bundle directory
  --archive               Also create <bundle-dir>.tar.gz
  --dry-run               Print what would be copied without writing files
  -h, --help              Show this help

Run as your normal user for home configs. Run with sudo if you also need
/etc/wireguard or NetworkManager WireGuard profiles that your user cannot read.
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
force=0
archive=0
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
    --force)
      force=1
      shift
      ;;
    --archive)
      archive=1
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

if [ -z "$target_home" ] || [ ! -d "$target_home" ]; then
  echo "could not find home directory for user $target_user" >&2
  exit 1
fi

target_group="$(id -gn "$target_user" 2>/dev/null || printf 'users')"

case "$bundle_dir" in
  /|"$target_home"|"$setup_repo")
    echo "refusing unsafe bundle directory: $bundle_dir" >&2
    exit 1
    ;;
esac

manifest_file="$bundle_dir/manifest.tsv"
skipped_file="$bundle_dir/skipped.tsv"
summary_file="$bundle_dir/README.md"

if [ "$dry_run" -eq 0 ]; then
  if [ -e "$bundle_dir" ]; then
    if [ "$force" -ne 1 ]; then
      echo "bundle already exists: $bundle_dir" >&2
      echo "pass --force to replace it, or choose --bundle-dir" >&2
      exit 1
    fi
    rm -rf -- "$bundle_dir"
  fi

  mkdir -p -- "$bundle_dir/files" "$bundle_dir/gpg"
  printf 'kind\tscope\trelative_path\tsource_path\tbundle_path\tmode\n' > "$manifest_file"
  printf 'kind\tsource_path\treason\n' > "$skipped_file"
fi

record_skipped() {
  local kind="$1"
  local source="$2"
  local reason="$3"

  if [ "$dry_run" -eq 1 ]; then
    printf 'skip: %s %s (%s)\n' "$kind" "$source" "$reason"
  else
    printf '%s\t%s\t%s\n' "$kind" "$source" "$reason" >> "$skipped_file"
  fi
}

bundle_rel_for_source() {
  local source="$1"
  printf 'files/%s\n' "${source#/}"
}

copy_file() {
  local kind="$1"
  local scope="$2"
  local relative_path="$3"
  local source="$4"
  local bundle_rel mode dest

  if [ ! -e "$source" ]; then
    record_skipped "$kind" "$source" "missing"
    return 0
  fi

  if [ ! -f "$source" ]; then
    record_skipped "$kind" "$source" "not-a-regular-file"
    return 0
  fi

  if [ ! -r "$source" ]; then
    record_skipped "$kind" "$source" "unreadable"
    return 0
  fi

  bundle_rel="$(bundle_rel_for_source "$source")"
  mode="$(stat -Lc '%a' "$source" 2>/dev/null || printf '600')"
  dest="$bundle_dir/$bundle_rel"

  if [ "$dry_run" -eq 1 ]; then
    printf 'copy: %s %s -> %s\n' "$kind" "$source" "$bundle_rel"
    return 0
  fi

  mkdir -p -- "$(dirname -- "$dest")"
  cp -pL -- "$source" "$dest"
  chmod "$mode" "$dest" 2>/dev/null || true
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$kind" "$scope" "$relative_path" "$source" "$bundle_rel" "$mode" >> "$manifest_file"
}

copy_home_file() {
  local kind="$1"
  local source="$2"
  local relative_path

  relative_path="${source#"$target_home"/}"
  copy_file "$kind" "home" "$relative_path" "$source"
}

copy_system_file() {
  local kind="$1"
  local source="$2"
  local relative_path

  relative_path="${source#/}"
  copy_file "$kind" "system" "$relative_path" "$source"
}

copy_home_tree() {
  local kind="$1"
  local dir="$2"
  local file

  if [ ! -e "$dir" ]; then
    record_skipped "$kind" "$dir" "missing"
    return 0
  fi
  if [ ! -d "$dir" ]; then
    record_skipped "$kind" "$dir" "not-a-directory"
    return 0
  fi
  if [ ! -r "$dir" ]; then
    record_skipped "$kind" "$dir" "unreadable"
    return 0
  fi

  while IFS= read -r file; do
    copy_home_file "$kind" "$file"
  done < <(find "$dir" \( -type f -o -type l \) -print | sort)
}

copy_system_tree() {
  local kind="$1"
  local dir="$2"
  local file

  if [ ! -e "$dir" ]; then
    record_skipped "$kind" "$dir" "missing"
    return 0
  fi
  if [ ! -d "$dir" ]; then
    record_skipped "$kind" "$dir" "not-a-directory"
    return 0
  fi
  if [ ! -r "$dir" ]; then
    record_skipped "$kind" "$dir" "unreadable"
    return 0
  fi

  while IFS= read -r file; do
    copy_system_file "$kind" "$file"
  done < <(find "$dir" \( -type f -o -type l \) -print | sort)
}

copy_kube_tree() {
  local dir="$target_home/.kube"
  local file

  if [ ! -e "$dir" ]; then
    record_skipped "kube" "$dir" "missing"
    return 0
  fi
  if [ ! -d "$dir" ]; then
    record_skipped "kube" "$dir" "not-a-directory"
    return 0
  fi
  if [ ! -r "$dir" ]; then
    record_skipped "kube" "$dir" "unreadable"
    return 0
  fi

  while IFS= read -r file; do
    copy_home_file "kube" "$file"
  done < <(
    find "$dir" \
      \( -path "$dir/cache" -o -path "$dir/http-cache" -o -path "$dir/logs" \) -prune \
      -o \( -type f -o -type l \) -print |
      sort
  )
}

copy_networkmanager_wireguard() {
  local dir="/etc/NetworkManager/system-connections"
  local file

  if [ ! -d "$dir" ]; then
    record_skipped "networkmanager-wireguard" "$dir" "missing"
    return 0
  fi
  if [ ! -r "$dir" ]; then
    record_skipped "networkmanager-wireguard" "$dir" "unreadable"
    return 0
  fi

  while IFS= read -r file; do
    if [ -r "$file" ] && grep -Eiq '(^type=wireguard|wireguard)' "$file"; then
      copy_system_file "networkmanager-wireguard" "$file"
    fi
  done < <(find "$dir" -maxdepth 1 -type f -name '*.nmconnection' -print | sort)
}

run_as_target_user() {
  if [ "$(id -u)" -eq 0 ] && [ "$target_user" != "root" ]; then
    sudo -H -u "$target_user" env HOME="$target_home" "$@"
  else
    HOME="$target_home" "$@"
  fi
}

record_gpg_file() {
  local kind="$1"
  local rel="$2"
  local path="$bundle_dir/$rel"
  local mode

  [ -s "$path" ] || return 0
  mode="$(stat -c '%a' "$path" 2>/dev/null || printf '600')"
  printf '%s\tgpg\t%s\tgpg-export\t%s\t%s\n' "$kind" "$rel" "$rel" "$mode" >> "$manifest_file"
}

export_gpg() {
  local public_rel="gpg/public-keys.asc"
  local secret_rel="gpg/secret-keys.asc"
  local ownertrust_rel="gpg/ownertrust.txt"

  if ! command -v gpg >/dev/null 2>&1; then
    record_skipped "gpg" "gpg" "command-not-found"
    return 0
  fi

  if [ "$dry_run" -eq 1 ]; then
    printf 'export: gpg public keys, secret keys, and ownertrust for %s\n' "$target_user"
    return 0
  fi

  if run_as_target_user gpg --batch --yes --export --armor > "$bundle_dir/$public_rel"; then
    chmod 600 "$bundle_dir/$public_rel"
    record_gpg_file "gpg-public-keys" "$public_rel"
  else
    rm -f -- "$bundle_dir/$public_rel"
    record_skipped "gpg-public-keys" "$target_user" "export-failed"
  fi

  if run_as_target_user gpg --batch --yes --export-secret-keys --armor > "$bundle_dir/$secret_rel"; then
    chmod 600 "$bundle_dir/$secret_rel"
    record_gpg_file "gpg-secret-keys" "$secret_rel"
  else
    rm -f -- "$bundle_dir/$secret_rel"
    record_skipped "gpg-secret-keys" "$target_user" "export-failed"
  fi

  if run_as_target_user gpg --batch --yes --export-ownertrust > "$bundle_dir/$ownertrust_rel"; then
    chmod 600 "$bundle_dir/$ownertrust_rel"
    record_gpg_file "gpg-ownertrust" "$ownertrust_rel"
  else
    rm -f -- "$bundle_dir/$ownertrust_rel"
    record_skipped "gpg-ownertrust" "$target_user" "export-failed"
  fi
}

chown_bundle_to_target_user() {
  if [ "$(id -u)" -eq 0 ] && [ "$target_user" != "root" ]; then
    chown -R "$target_user:$target_group" "$bundle_dir" 2>/dev/null || true
    [ -e "$bundle_dir.tar.gz" ] && chown "$target_user:$target_group" "$bundle_dir.tar.gz" 2>/dev/null || true
  fi
}

copy_home_tree "aws" "$target_home/.aws"
copy_kube_tree
copy_home_tree "ssh" "$target_home/.ssh"
copy_home_tree "encrypted" "$target_home/encrypted"
copy_home_tree "wireguard-home" "$target_home/.config/wireguard"
copy_home_tree "wireguard-home" "$target_home/wireguard"
copy_system_tree "wireguard-system" "/etc/wireguard"
copy_networkmanager_wireguard
export_gpg

if [ "$dry_run" -eq 0 ]; then
  copied_count="$(tail -n +2 "$manifest_file" | wc -l | tr -d ' ')"
  skipped_count="$(tail -n +2 "$skipped_file" | wc -l | tr -d ' ')"

  cat > "$summary_file" <<EOF
# Private Machine Bundle

Generated: $(date --iso-8601=seconds)
User: $target_user
Home: $target_home

This bundle contains private credentials and keys. Keep it off git and transfer
it only through a trusted path such as an encrypted USB drive or LocalSend on a
trusted network.

Files:

- manifest.tsv: copied items, original paths, restore scope, bundle paths, modes.
- skipped.tsv: missing or unreadable requested paths.
- files/: copied AWS, kube, SSH, WireGuard, and encrypted-folder files.
- gpg/: exported GPG public keys, secret keys, and ownertrust when available.

Restore from a checkout that contains this script:

\`\`\`sh
./scripts/setup-private-machine-state.sh --bundle-dir ./private-machine-bundle
\`\`\`

Run restore with sudo if the bundle includes /etc/wireguard or NetworkManager
WireGuard profiles.
EOF

  if [ "$archive" -eq 1 ]; then
    tar -C "$(dirname -- "$bundle_dir")" -czf "$bundle_dir.tar.gz" "$(basename -- "$bundle_dir")"
    chmod 600 "$bundle_dir.tar.gz"
    echo "created archive: $bundle_dir.tar.gz"
  fi

  chown_bundle_to_target_user

  echo "exported $copied_count private items to $bundle_dir"
  echo "skipped $skipped_count requested paths; review $skipped_file"
else
  echo "dry run complete for $target_user at $target_home"
fi
