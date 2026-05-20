#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: export-file-bundle.sh [options]

Package a prepared directory tree for transfer to another machine.

Options:
  --source-dir PATH       Source tree to package. Default: $HOME/devshop-transfer
  --bundle-dir PATH       Temporary bundle directory. Default: <devshop>/file-transfer-bundle
  --archive PATH          Output tar.gz. Default: <bundle-dir>.tar.gz
  --force                 Replace an existing bundle directory or archive
  --dry-run               Print actions without writing files
  -h, --help              Show this help

Prepare the source tree however you want it restored. For example:

  ~/devshop-transfer/Documents
  ~/devshop-transfer/Pictures
  ~/devshop-transfer/project-notes

Symlinks are dereferenced when copied into the bundle.
EOF
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
setup_repo="$(cd -- "$script_dir/.." && pwd)"

source_dir="${DEVSHOP_FILE_SOURCE:-$HOME/devshop-transfer}"
bundle_dir="${DEVSHOP_FILE_BUNDLE_DIR:-$setup_repo/file-transfer-bundle}"
archive_path=""
force=0
dry_run=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source-dir)
      source_dir="${2:?missing value for --source-dir}"
      shift 2
      ;;
    --bundle-dir)
      bundle_dir="${2:?missing value for --bundle-dir}"
      shift 2
      ;;
    --archive)
      archive_path="${2:?missing value for --archive}"
      shift 2
      ;;
    --force)
      force=1
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

archive_path="${archive_path:-$bundle_dir.tar.gz}"

if [ ! -d "$source_dir" ]; then
  echo "source directory does not exist: $source_dir" >&2
  exit 1
fi

source_dir="$(cd -- "$source_dir" && pwd)"
bundle_parent="$(dirname -- "$bundle_dir")"
archive_parent="$(dirname -- "$archive_path")"

case "$bundle_dir" in
  /|"$HOME"|"$source_dir"|"$setup_repo")
    echo "refusing unsafe bundle directory: $bundle_dir" >&2
    exit 1
    ;;
esac

case "$archive_path" in
  "$bundle_dir"/*)
    echo "archive must not be inside the bundle directory: $archive_path" >&2
    exit 1
    ;;
esac

if [ -z "$(find "$source_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
  echo "source directory is empty: $source_dir" >&2
  exit 1
fi

if [ "$dry_run" -eq 1 ]; then
  printf 'would create bundle directory: %s\n' "$bundle_dir"
  printf 'would create archive: %s\n' "$archive_path"
  find "$source_dir" -mindepth 1 -maxdepth 2 -print | sort | sed "s#^$source_dir/#would include: #"
  exit 0
fi

if [ -e "$bundle_dir" ] || [ -e "$archive_path" ]; then
  if [ "$force" -ne 1 ]; then
    echo "bundle output already exists; pass --force to replace it" >&2
    echo "bundle dir: $bundle_dir" >&2
    echo "archive:    $archive_path" >&2
    exit 1
  fi
  rm -rf -- "$bundle_dir"
  rm -f -- "$archive_path"
fi

mkdir -p -- "$bundle_dir/payload" "$bundle_parent" "$archive_parent"

manifest_file="$bundle_dir/manifest.tsv"
summary_file="$bundle_dir/README.md"

printf 'relative_path\tsize_bytes\n' > "$manifest_file"
cp -aL -- "$source_dir"/. "$bundle_dir/payload/"

while IFS= read -r file; do
  rel="${file#"$bundle_dir/payload"/}"
  size="$(stat -Lc '%s' "$file" 2>/dev/null || printf '0')"
  printf '%s\t%s\n' "$rel" "$size" >> "$manifest_file"
done < <(find "$bundle_dir/payload" -type f -print | sort)

cat > "$summary_file" <<EOF
# Devshop File Transfer Bundle

Generated: $(date --iso-8601=seconds)
Source: $source_dir

This bundle is intended for scripts/setup-file-bundle.sh.

Files:

- manifest.tsv: copied file inventory.
- payload/: copied content, preserving paths relative to the source directory.
EOF

tar -C "$(dirname -- "$bundle_dir")" -czf "$archive_path" "$(basename -- "$bundle_dir")"
chmod 600 "$archive_path" 2>/dev/null || true

copied_count="$(tail -n +2 "$manifest_file" | wc -l | tr -d ' ')"
echo "exported $copied_count files to $archive_path"
