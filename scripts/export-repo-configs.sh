#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: export-repo-configs.sh [options]

Find git repos under a repos directory that have local activity within the
selected window, record the tools each repo appears to need, and copy portable
local config files into a bundle that can be moved to another machine.

Options:
  --repos-root PATH       Directory containing repos. Default: $HOME/repos
  --bundle-dir PATH       Output bundle. Default: <devshop>/repo-config-bundle
  --years N              Activity window in years. Default: 2
  --since YYYY-MM-DD     Explicit cutoff date instead of --years
  --all                  Export every discovered git repo under --repos-root
  --include-sensitive    Copy env files and obvious secret/key configs too
  --force                Replace an existing bundle directory
  --dry-run              Print what would be exported without writing files
  -h, --help             Show this help

By default, files that look like secrets are listed in config-files.tsv but are
not copied. Re-run with --include-sensitive only for a private transfer.
EOF
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
setup_repo="$(cd -- "$script_dir/.." && pwd)"

repos_root="${REPOS_ROOT:-$HOME/repos}"
bundle_dir="${BUNDLE_DIR:-$setup_repo/repo-config-bundle}"
years=2
since_date=""
include_all=0
include_sensitive=0
force=0
dry_run=0

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
    --years)
      years="${2:?missing value for --years}"
      shift 2
      ;;
    --since)
      since_date="${2:?missing value for --since}"
      shift 2
      ;;
    --all)
      include_all=1
      shift
      ;;
    --include-sensitive)
      include_sensitive=1
      shift
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

if [ ! -d "$repos_root" ]; then
  echo "repos root does not exist: $repos_root" >&2
  exit 1
fi
repos_root="$(cd -- "$repos_root" && pwd)"

if [ "$include_all" -eq 1 ]; then
  cutoff_epoch=0
  cutoff_iso="all repos"
elif [ -n "$since_date" ]; then
  cutoff_epoch="$(date -d "$since_date 00:00:00" +%s)"
else
  cutoff_epoch="$(date -d "$years years ago" +%s)"
fi
if [ "$include_all" -ne 1 ]; then
  cutoff_iso="$(date -d "@$cutoff_epoch" --iso-8601=seconds)"
fi

if [ "$dry_run" -eq 0 ]; then
  case "$bundle_dir" in
    /|"$HOME"|"$repos_root")
      echo "refusing unsafe bundle directory: $bundle_dir" >&2
      exit 1
      ;;
  esac

  if [ -e "$bundle_dir" ]; then
    if [ "$force" -ne 1 ]; then
      echo "bundle already exists: $bundle_dir" >&2
      echo "pass --force to replace it, or choose --bundle-dir" >&2
      exit 1
    fi
    rm -rf -- "$bundle_dir"
  fi

  mkdir -p -- "$bundle_dir/repos"
fi

manifest_file="$bundle_dir/manifest.tsv"
tools_file="$bundle_dir/repo-tools.tsv"
configs_file="$bundle_dir/config-files.tsv"
summary_file="$bundle_dir/README.md"

if [ "$dry_run" -eq 0 ]; then
  printf 'repo\tlast_activity\tactivity_source\tcurrent_branch\torigin\tdirty_entries\tpath\n' > "$manifest_file"
  printf 'repo\ttools\tevidence\n' > "$tools_file"
  printf 'repo\trelative_path\tsensitivity\taction\tbundle_path\n' > "$configs_file"
fi

epoch_or_zero() {
  if [ -n "${1:-}" ]; then
    printf '%s\n' "$1"
  else
    printf '0\n'
  fi
}

format_epoch() {
  local epoch="${1:-0}"
  if [ "$epoch" -gt 0 ] 2>/dev/null; then
    date -d "@$epoch" --iso-8601=seconds
  else
    printf 'unknown\n'
  fi
}

latest_reflog_epoch() {
  git -C "$1" reflog --all --date=unix --format='%cd' 2>/dev/null |
    awk 'max < $1 { max = $1 } END { if (max) print int(max) }' || true
}

latest_commit_epoch() {
  git -C "$1" log -1 --all --format='%ct' 2>/dev/null || true
}

latest_worktree_epoch() {
  local repo="$1"
  find "$repo" \
    \( -path "$repo/.git" \
      -o -path "$repo/.direnv" \
      -o -path "$repo/.claude" \
      -o -path "$repo/.codex" \
      -o -path "$repo/node_modules" \
      -o -path "$repo/target" \
      -o -path "$repo/vendor" \
      -o -path "$repo/dist" \
      -o -path "$repo/build" \
      -o -path "$repo/.next" \
      -o -path "$repo/result" \
      -o -path "$repo/result-*" \) -prune \
    -o -type f -printf '%T@\n' 2>/dev/null |
    awk 'max < $1 { max = $1 } END { if (max) print int(max) }' || true
}

latest_activity() {
  local repo="$1"
  local reflog commit worktree max source

  reflog="$(epoch_or_zero "$(latest_reflog_epoch "$repo")")"
  commit="$(epoch_or_zero "$(latest_commit_epoch "$repo")")"
  worktree="$(epoch_or_zero "$(latest_worktree_epoch "$repo")")"

  max="$reflog"
  source="git-reflog"
  if [ "$worktree" -gt "$max" ]; then
    max="$worktree"
    source="working-tree"
  fi
  if [ "$commit" -gt "$max" ]; then
    max="$commit"
    source="git-commit"
  fi

  printf '%s\t%s\n' "$max" "$source"
}

find_repo_paths() {
  find "$repos_root" -mindepth 1 \
    \( -name .git \
      -o -name .direnv \
      -o -name .claude \
      -o -name .codex \
      -o -name node_modules \
      -o -name target \
      -o -name vendor \
      -o -name dist \
      -o -name build \
      -o -name .next \
      -o -name result \
      -o -name 'result-*' \) -prune \
    -o -type d -exec test -e '{}/.git' ';' -print -prune 2>/dev/null |
    sort
}

repo_id_for_path() {
  local repo_path="$1"
  local rel

  rel="${repo_path#"$repos_root"/}"
  if [ "$rel" = "$repo_path" ]; then
    rel="$(basename -- "$repo_path")"
  fi
  printf '%s\n' "$rel"
}

add_unique() {
  local value="$1"
  local existing
  shift
  for existing in "$@"; do
    [ "$existing" = "$value" ] && return 1
  done
  return 0
}

join_by() {
  local delimiter="$1"
  shift
  local first=1
  local value
  for value in "$@"; do
    if [ "$first" -eq 1 ]; then
      printf '%s' "$value"
      first=0
    else
      printf '%s%s' "$delimiter" "$value"
    fi
  done
}

detect_tools() {
  local repo="$1"
  local -a tools=()
  local -a evidence=()
  local package_manager

  tools+=("git")
  evidence+=(".git")

  if [ -f "$repo/flake.nix" ] || [ -f "$repo/shell.nix" ] || [ -f "$repo/default.nix" ]; then
    tools+=("nix")
    evidence+=("flake.nix/shell.nix/default.nix")
  fi
  if [ -f "$repo/.envrc" ]; then
    tools+=("direnv")
    evidence+=(".envrc")
  fi
  if [ -f "$repo/Cargo.toml" ]; then
    tools+=("cargo")
    evidence+=("Cargo.toml")
  fi
  if [ -f "$repo/rust-toolchain" ] || [ -f "$repo/rust-toolchain.toml" ]; then
    tools+=("rustup")
    evidence+=("rust-toolchain")
  fi
  if [ -f "$repo/package.json" ]; then
    tools+=("node")
    evidence+=("package.json")
    package_manager="$(grep -m 1 '"packageManager"' "$repo/package.json" 2>/dev/null | sed -E 's/.*"packageManager"[[:space:]]*:[[:space:]]*"([^"@]+).*/\1/' || true)"
    case "$package_manager" in
      pnpm) tools+=("corepack" "pnpm"); evidence+=("packageManager: pnpm") ;;
      yarn) tools+=("corepack" "yarn"); evidence+=("packageManager: yarn") ;;
      npm) tools+=("npm"); evidence+=("packageManager: npm") ;;
      bun) tools+=("bun"); evidence+=("packageManager: bun") ;;
    esac
  fi
  if [ -f "$repo/package-lock.json" ]; then tools+=("npm"); evidence+=("package-lock.json"); fi
  if [ -f "$repo/pnpm-lock.yaml" ]; then tools+=("pnpm"); evidence+=("pnpm-lock.yaml"); fi
  if [ -f "$repo/yarn.lock" ]; then tools+=("yarn"); evidence+=("yarn.lock"); fi
  if [ -f "$repo/bun.lock" ] || [ -f "$repo/bun.lockb" ]; then tools+=("bun"); evidence+=("bun.lock"); fi
  if [ -f "$repo/go.mod" ]; then tools+=("go"); evidence+=("go.mod"); fi
  if [ -f "$repo/pyproject.toml" ] || [ -f "$repo/setup.py" ] || [ -f "$repo/requirements.txt" ]; then
    tools+=("python")
    evidence+=("pyproject.toml/setup.py/requirements.txt")
  fi
  if [ -f "$repo/requirements.txt" ]; then tools+=("pip"); evidence+=("requirements.txt"); fi
  if [ -f "$repo/poetry.lock" ]; then tools+=("poetry"); evidence+=("poetry.lock"); fi
  if [ -f "$repo/uv.lock" ]; then tools+=("uv"); evidence+=("uv.lock"); fi
  if [ -f "$repo/Gemfile" ]; then tools+=("ruby" "bundler"); evidence+=("Gemfile"); fi
  if [ -f "$repo/Makefile" ] || [ -f "$repo/makefile" ]; then tools+=("make"); evidence+=("Makefile"); fi
  if [ -f "$repo/justfile" ] || [ -f "$repo/Justfile" ]; then tools+=("just"); evidence+=("justfile"); fi
  if find "$repo" -maxdepth 2 \( -name Dockerfile -o -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' -o -name compose.yml -o -name compose.yaml \) -type f -print -quit | grep -q .; then
    tools+=("docker")
    evidence+=("Dockerfile/compose")
  fi
  if find "$repo" -maxdepth 3 -name '*.tf' -type f -print -quit | grep -q .; then tools+=("terraform"); evidence+=("*.tf"); fi
  if find "$repo" -maxdepth 3 -name Chart.yaml -type f -print -quit | grep -q .; then tools+=("helm"); evidence+=("Chart.yaml"); fi
  if find "$repo" -maxdepth 3 \( -name kustomization.yaml -o -name kustomization.yml \) -type f -print -quit | grep -q .; then
    tools+=("kubectl" "kustomize")
    evidence+=("kustomization.yaml")
  fi
  if [ -f "$repo/.tool-versions" ]; then tools+=("asdf"); evidence+=(".tool-versions"); fi

  local -a unique_tools=()
  local tool
  for tool in "${tools[@]}"; do
    if add_unique "$tool" "${unique_tools[@]}"; then
      unique_tools+=("$tool")
    fi
  done

  printf '%s\t%s\n' "$(join_by ', ' "${unique_tools[@]}")" "$(join_by ', ' "${evidence[@]}")"
}

is_sensitive_path() {
  local rel="$1"
  local base
  base="$(basename -- "$rel")"

  case "$base" in
    .env.example|.env.sample|.env.template|env.example|env.sample)
      return 1
      ;;
    .env|.env.*|*.env|*.env.*|*.pem|*.key|*.p12|*.pfx|id_rsa|id_ed25519|credentials|credentials.*)
      return 0
      ;;
  esac

  case "$rel" in
    *secret*|*Secret*|*credential*|*Credential*|*token*|*Token*|*private-key*|*private_key*)
      return 0
      ;;
  esac

  return 1
}

looks_sensitive_content() {
  local file="$1"
  grep -Eiq '(_AUTH_TOKEN|AUTH_TOKEN|API_KEY|SECRET|PASSWORD|PRIVATE_KEY|ACCESS_TOKEN|CLIENT_SECRET)' "$file" 2>/dev/null
}

emit_config_candidate() {
  local repo_name="$1"
  local repo_path="$2"
  local rel="$3"
  local src="$repo_path/$rel"
  local sensitivity="normal"
  local action="copied"
  local bundle_rel="repos/$repo_name/$rel"
  local dest="$bundle_dir/$bundle_rel"

  [ -f "$src" ] || return 0

  if is_sensitive_path "$rel" || looks_sensitive_content "$src"; then
    sensitivity="sensitive"
  fi

  if [ "$sensitivity" = "sensitive" ] && [ "$include_sensitive" -ne 1 ]; then
    action="skipped-sensitive"
    bundle_rel=""
  elif [ "$dry_run" -eq 1 ]; then
    action="dry-run"
  else
    mkdir -p -- "$(dirname -- "$dest")"
    cp -p -- "$src" "$dest"
  fi

  if [ "$dry_run" -eq 0 ]; then
    printf '%s\t%s\t%s\t%s\t%s\n' "$repo_name" "$rel" "$sensitivity" "$action" "$bundle_rel" >> "$configs_file"
  else
    printf '[%s] %s %s (%s)\n' "$repo_name" "$action" "$rel" "$sensitivity"
  fi
}

emit_config_candidates() {
  local repo_name="$1"
  local repo_path="$2"
  local rel
  local -a seen=()
  local -a candidates=(
    ".envrc"
    ".tool-versions"
    ".node-version"
    ".nvmrc"
    ".ruby-version"
    ".python-version"
    "rust-toolchain"
    "rust-toolchain.toml"
    ".cargo/config"
    ".cargo/config.toml"
    ".npmrc"
    ".yarnrc"
    ".yarnrc.yml"
    ".pnpmrc"
    "bunfig.toml"
    "docker-compose.override.yml"
    "docker-compose.override.yaml"
    "compose.override.yml"
    "compose.override.yaml"
  )

  while IFS= read -r rel; do
    candidates+=("$rel")
  done < <(
    cd "$repo_path" &&
      find . -maxdepth 3 \
        \( -path './.git' -o -path './node_modules' -o -path './target' -o -path './.direnv' -o -path './.claude' -o -path './.codex' \) -prune \
        -o -type f \
        \( -name '.env' \
          -o -name '.env.*' \
          -o -name '*.local' \
          -o -name '*.local.*' \
          -o -path './config/local.*' \
          -o -path './config/*.local.*' \
          -o -name 'config.local.*' \
          -o -name 'settings.local.*' \) \
        -printf '%P\n' 2>/dev/null
  )

  for rel in "${candidates[@]}"; do
    [ -n "$rel" ] || continue
    if add_unique "$rel" "${seen[@]}"; then
      seen+=("$rel")
      emit_config_candidate "$repo_name" "$repo_path" "$rel"
    fi
  done
}

repo_count=0
config_count=0

while IFS= read -r repo_path; do
  repo_name="$(repo_id_for_path "$repo_path")"

  activity="$(latest_activity "$repo_path")"
  activity_epoch="$(printf '%s' "$activity" | cut -f1)"
  activity_source="$(printf '%s' "$activity" | cut -f2)"

  if [ "$include_all" -ne 1 ] && [ "$activity_epoch" -lt "$cutoff_epoch" ] 2>/dev/null; then
    continue
  fi

  current_branch="$(git -C "$repo_path" branch --show-current 2>/dev/null || true)"
  origin="$(git -C "$repo_path" remote get-url origin 2>/dev/null || true)"
  dirty_entries="$(git -C "$repo_path" status --porcelain --untracked-files=normal 2>/dev/null | wc -l | tr -d ' ')"
  tools="$(detect_tools "$repo_path")"
  tools_list="$(printf '%s' "$tools" | cut -f1)"
  tools_evidence="$(printf '%s' "$tools" | cut -f2)"
  last_activity="$(format_epoch "$activity_epoch")"

  repo_count=$((repo_count + 1))

  if [ "$dry_run" -eq 0 ]; then
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$repo_name" "$last_activity" "$activity_source" "$current_branch" "$origin" "$dirty_entries" "$repo_path" >> "$manifest_file"
    printf '%s\t%s\t%s\n' "$repo_name" "$tools_list" "$tools_evidence" >> "$tools_file"
  else
    printf 'repo: %s\tlast_activity: %s\ttools: %s\n' "$repo_name" "$last_activity" "$tools_list"
  fi

  before_count="$config_count"
  emit_config_candidates "$repo_name" "$repo_path"
  if [ "$dry_run" -eq 0 ]; then
    config_count="$(tail -n +2 "$configs_file" | wc -l | tr -d ' ')"
  else
    config_count="$before_count"
  fi
done < <(find_repo_paths)

if [ "$dry_run" -eq 0 ]; then
  cat > "$summary_file" <<EOF
# Repo Config Bundle

Generated: $(date --iso-8601=seconds)
Repos root: $repos_root
Activity cutoff: $cutoff_iso
Sensitive files copied: $include_sensitive

Files:

- manifest.tsv: active repos, last activity, branch, origin, dirty count, source path.
- repo-tools.tsv: detected tools and the files that implied them.
- config-files.tsv: config candidates, sensitivity, whether each was copied, and bundle path.
- repos/: copied config files, preserving repo-relative paths.

Restore on another machine from Devshop:

\`\`\`sh
./scripts/setup-repos-from-bundle.sh --bundle-dir ./repo-config-bundle --clone
\`\`\`

Use --overwrite only when you intentionally want bundled configs to replace
existing local files.
EOF
fi

if [ "$dry_run" -eq 0 ]; then
  if [ "$include_all" -eq 1 ]; then
    echo "exported $repo_count repos to $bundle_dir"
  else
    echo "exported $repo_count active repos to $bundle_dir"
  fi
  echo "review $manifest_file, $tools_file, and $configs_file"
else
  if [ "$include_all" -eq 1 ]; then
    echo "dry run complete: $repo_count repos"
  else
    echo "dry run complete: $repo_count active repos since $cutoff_iso"
  fi
fi
