#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: setup-file-bundle.sh [options]

Restore a file transfer bundle created by export-file-bundle.sh.

Options:
  --archive PATH          Bundle archive. Default: <devshop>/file-transfer-bundle.tar.gz
  --bundle-dir PATH       Already unpacked bundle directory instead of an archive
  --target-dir PATH       Destination directory. Default: $HOME
  --user USER             User to own restored files when run as root. Default: $SUDO_USER or current user
  --overwrite             Replace existing files instead of skipping them
  --dry-run               Print actions without changing files
  -h, --help              Show this help

Existing files are skipped by default.
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
target_dir=""
archive_path="$setup_repo/file-transfer-bundle.tar.gz"
bundle_dir=""
overwrite=0
dry_run=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --archive)
      archive_path="${2:?missing value for --archive}"
      shift 2
      ;;
    --bundle-dir)
      bundle_dir="${2:?missing value for --bundle-dir}"
      shift 2
      ;;
    --target-dir)
      target_dir="${2:?missing value for --target-dir}"
      shift 2
      ;;
    --user)
      target_user="${2:?missing value for --user}"
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

if [ -z "$target_dir" ]; then
  target_dir="$(home_for_user "$target_user")"
fi

if [ -z "$target_dir" ]; then
  echo "could not find target directory for user $target_user" >&2
  exit 1
fi

target_group="$(id -gn "$target_user" 2>/dev/null || printf 'users')"

if [ -n "$bundle_dir" ] && [ ! -d "$bundle_dir" ]; then
  echo "bundle directory does not exist: $bundle_dir" >&2
  exit 1
fi

if [ -z "$bundle_dir" ] && [ ! -f "$archive_path" ]; then
  echo "archive does not exist: $archive_path" >&2
  exit 1
fi

tmp_dir=""
cleanup() {
  if [ -n "$tmp_dir" ] && [ -d "$tmp_dir" ]; then
    rm -rf -- "$tmp_dir"
  fi
}
trap cleanup EXIT

validate_archive_paths() {
  local entry
  while IFS= read -r entry; do
    case "$entry" in
      /*|../*|*/../*|*/..|..)
        echo "refusing unsafe archive path: $entry" >&2
        exit 1
        ;;
    esac
  done < <(tar -tzf "$archive_path")
}

detect_payload_root() {
  local dir="$1"
  local child_count child

  if [ -d "$dir/payload" ]; then
    printf '%s\n' "$dir/payload"
    return 0
  fi

  child_count="$(find "$dir" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
  if [ "$child_count" -eq 1 ]; then
    child="$(find "$dir" -mindepth 1 -maxdepth 1 -type d -print -quit)"
    if [ -d "$child/payload" ]; then
      printf '%s\n' "$child/payload"
      return 0
    fi
  fi

  echo "bundle has no payload directory" >&2
  return 1
}

chown_target_path() {
  local path="$1"
  if [ "$(id -u)" -eq 0 ] && [ "$target_user" != "root" ]; then
    chown "$target_user:$target_group" "$path" 2>/dev/null || true
  fi
}

mkdir_for_restore() {
  local dir="$1"

  if [ "$dry_run" -eq 1 ]; then
    [ -d "$dir" ] || printf 'would create directory: %s\n' "$dir"
    return 0
  fi

  mkdir -p -- "$dir"
  chown_target_path "$dir"
}

copy_file_for_restore() {
  local src="$1"
  local dest="$2"

  if [ -e "$dest" ] && [ "$overwrite" -ne 1 ]; then
    if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
      printf 'already current: %s\n' "$dest"
      return 0
    fi
    printf 'exists, not overwritten: %s\n' "$dest"
    return 1
  fi

  if [ "$dry_run" -eq 1 ]; then
    printf 'would restore %s -> %s\n' "$src" "$dest"
    return 0
  fi

  mkdir -p -- "$(dirname -- "$dest")"
  chown_target_path "$(dirname -- "$dest")"
  cp -pL -- "$src" "$dest"
  chown_target_path "$dest"
  printf 'restored: %s\n' "$dest"
}

if [ -z "$bundle_dir" ]; then
  validate_archive_paths
  tmp_dir="$(mktemp -d)"
  tar -xzf "$archive_path" -C "$tmp_dir"
  payload_root="$(detect_payload_root "$tmp_dir")"
else
  payload_root="$(detect_payload_root "$bundle_dir")"
fi

mkdir_for_restore "$target_dir"

restored=0
skipped=0

while IFS= read -r -d '' entry; do
  rel="${entry#"$payload_root"/}"
  dest="$target_dir/$rel"

  if [ -d "$entry" ] && [ ! -L "$entry" ]; then
    mkdir_for_restore "$dest"
  elif [ -f "$entry" ] || [ -L "$entry" ]; then
    if copy_file_for_restore "$entry" "$dest"; then
      restored=$((restored + 1))
    else
      skipped=$((skipped + 1))
    fi
  else
    printf 'skipping unsupported file type: %s\n' "$entry"
    skipped=$((skipped + 1))
  fi
done < <(find "$payload_root" -mindepth 1 -print0 | sort -z)

echo "file restore complete: restored=$restored skipped=$skipped target=$target_dir"
