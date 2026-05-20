#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: setup-repos-from-bundle.sh [options]

Restore repo-local config files from a bundle created by export-repo-configs.sh.
Optionally clone missing repos from their recorded origin remotes first.

Options:
  --repos-root PATH       Directory containing repos. Default: $HOME/repos
  --bundle-dir PATH       Bundle directory. Default: <devshop>/repo-config-bundle
  --clone                 Clone missing repos that have an origin remote in manifest.tsv
  --overwrite             Replace existing config files instead of skipping them
  --dry-run               Print actions without changing files
  --check-tools-only      Only report missing tools from repo-tools.tsv
  -h, --help              Show this help
EOF
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
setup_repo="$(cd -- "$script_dir/.." && pwd)"

repos_root="${REPOS_ROOT:-$HOME/repos}"
bundle_dir="${BUNDLE_DIR:-$setup_repo/repo-config-bundle}"
clone_missing=0
overwrite=0
dry_run=0
check_tools_only=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repos-root)
      repos_root="${2:?missing value for --repos-root}"
      shift 2
      ;;
    --bundle-dir)
      bundle_dir="${2:?missing value for --bundle-dir}"
      shift 2
      ;;
    --clone)
      clone_missing=1
      shift
      ;;
    --overwrite)
      overwrite=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --check-tools-only)
      check_tools_only=1
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

manifest_file="$bundle_dir/manifest.tsv"
tools_file="$bundle_dir/repo-tools.tsv"
configs_file="$bundle_dir/config-files.tsv"

if [ ! -f "$manifest_file" ] || [ ! -f "$tools_file" ] || [ ! -f "$configs_file" ]; then
  echo "bundle is missing manifest.tsv, repo-tools.tsv, or config-files.tsv: $bundle_dir" >&2
  exit 1
fi

mkdir_if_needed() {
  [ -d "$1" ] && return 0

  if [ "$dry_run" -eq 1 ]; then
    printf 'would create directory: %s\n' "$1"
  else
    mkdir -p -- "$1"
  fi
}

copy_file() {
  local src="$1"
  local dest="$2"

  if [ "$dry_run" -eq 1 ]; then
    printf 'would copy %s -> %s\n' "$src" "$dest"
  else
    mkdir -p -- "$(dirname -- "$dest")"
    cp -p -- "$src" "$dest"
  fi
}

read_tsv() {
  local line="$1"
  shift
  line="${line//$'\t'/$'\x1f'}"
  IFS=$'\x1f' read -r "$@" <<< "$line"
}

tool_command() {
  case "$1" in
    cargo) printf 'cargo' ;;
    rustup) printf 'rustup' ;;
    node) printf 'node' ;;
    corepack) printf 'corepack' ;;
    npm) printf 'npm' ;;
    pnpm) printf 'pnpm' ;;
    yarn) printf 'yarn' ;;
    bun) printf 'bun' ;;
    go) printf 'go' ;;
    python) printf 'python3' ;;
    pip) printf 'pip3' ;;
    bundler) printf 'bundle' ;;
    *) printf '%s' "$1" ;;
  esac
}

check_tools() {
  local missing=0
  local line repo tools evidence tool command

  while IFS= read -r line || [ -n "$line" ]; do
    read_tsv "$line" repo tools evidence
    [ "$repo" != "repo" ] || continue

    IFS=',' read -ra tool_list <<< "$tools"
    for tool in "${tool_list[@]}"; do
      tool="${tool#"${tool%%[![:space:]]*}"}"
      tool="${tool%"${tool##*[![:space:]]}"}"
      [ -n "$tool" ] || continue
      command="$(tool_command "$tool")"
      if ! command -v "$command" >/dev/null 2>&1; then
        printf 'missing tool: %-12s command: %-12s repo: %s\n' "$tool" "$command" "$repo"
        missing=1
      fi
    done
  done < "$tools_file"

  return "$missing"
}

declare -A repo_origins
while IFS= read -r line || [ -n "$line" ]; do
  read_tsv "$line" repo last_activity activity_source current_branch origin dirty_entries source_path
  [ "$repo" != "repo" ] || continue
  repo_origins["$repo"]="$origin"
done < "$manifest_file"

echo "checking tools from $tools_file"
if ! check_tools; then
  echo "some tools are missing; NixOS packages may need to be added before all repos run cleanly"
fi

if [ "$check_tools_only" -eq 1 ]; then
  exit 0
fi

mkdir_if_needed "$repos_root"

declare -A ensured_repos
ensure_repo() {
  local repo="$1"
  local repo_dir="$repos_root/$repo"
  local parent_dir
  local origin="${repo_origins[$repo]:-}"

  if [ -n "${ensured_repos[$repo]:-}" ]; then
    return 0
  fi
  ensured_repos["$repo"]=1

  if [ -d "$repo_dir/.git" ] || [ -f "$repo_dir/.git" ]; then
    return 0
  fi

  if [ -e "$repo_dir" ] && [ ! -d "$repo_dir" ]; then
    printf 'repo path exists but is not a directory, skipping configs: %s\n' "$repo_dir" >&2
    return 1
  fi

  if [ -d "$repo_dir" ] && [ -n "$(find "$repo_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
    printf 'existing non-git directory, restoring configs without cloning: %s\n' "$repo_dir" >&2
    return 0
  fi

  if [ "$clone_missing" -eq 1 ] && [ -n "$origin" ]; then
    parent_dir="$(dirname -- "$repo_dir")"
    mkdir_if_needed "$parent_dir"

    if [ "$dry_run" -eq 1 ]; then
      printf 'would clone %s -> %s\n' "$origin" "$repo_dir"
    else
      if ! git clone "$origin" "$repo_dir"; then
        printf 'clone failed, skipping configs: %s -> %s\n' "$origin" "$repo_dir" >&2
        return 1
      fi
    fi
  else
    printf 'missing repo, skipping configs: %s\n' "$repo_dir" >&2
    return 1
  fi
}

applied=0
skipped=0

while IFS= read -r line || [ -n "$line" ]; do
  read_tsv "$line" repo rel sensitivity action bundle_rel
  [ "$repo" != "repo" ] || continue
  [ "$action" = "copied" ] || continue
  [ -n "$bundle_rel" ] || continue

  src="$bundle_dir/$bundle_rel"
  dest="$repos_root/$repo/$rel"

  if [ ! -f "$src" ]; then
    printf 'missing bundled file, skipping: %s\n' "$src" >&2
    skipped=$((skipped + 1))
    continue
  fi

  if ! ensure_repo "$repo"; then
    skipped=$((skipped + 1))
    continue
  fi

  if [ -e "$dest" ] && [ "$overwrite" -ne 1 ]; then
    if cmp -s "$src" "$dest"; then
      printf 'already current: %s/%s\n' "$repo" "$rel"
      applied=$((applied + 1))
    else
      printf 'exists, not overwritten: %s/%s\n' "$repo" "$rel"
      skipped=$((skipped + 1))
    fi
    continue
  fi

  copy_file "$src" "$dest"
  printf 'restored: %s/%s\n' "$repo" "$rel"
  applied=$((applied + 1))
done < "$configs_file"

echo "restore complete: applied=$applied skipped=$skipped"
