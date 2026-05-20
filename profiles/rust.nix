{ pkgs, ... }:

let
  opensslForRust = pkgs.symlinkJoin {
    name = "openssl-rust-build-inputs";
    paths = [
      pkgs.openssl.out
      pkgs.openssl.dev
    ];
  };

  cachedCargo = pkgs.writeShellScriptBin "cached-cargo" ''
    set -euo pipefail

    if ! command -v cargo >/dev/null 2>&1; then
      echo "cached-cargo: cargo is not on PATH; install/select a rustup toolchain first" >&2
      exit 1
    fi

    repo_root="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || ${pkgs.coreutils}/bin/pwd -P)"
    cd "$repo_root"

    mkdir -p "$repo_root/.direnv"

    export RUSTC_WRAPPER="''${RUSTC_WRAPPER:-${pkgs.sccache}/bin/sccache}"
    export SCCACHE_CACHE_SIZE="''${SCCACHE_CACHE_SIZE:-50G}"
    export SCCACHE_SERVER_UDS="''${SCCACHE_SERVER_UDS:-$repo_root/.direnv/sccache.sock}"
    export SCCACHE_BASEDIRS="''${SCCACHE_BASEDIRS:-$repo_root}"

    exec cargo "$@"
  '';

  depotCargo = pkgs.writeShellScriptBin "depot-cargo" ''
    set -euo pipefail

    if ! command -v cargo >/dev/null 2>&1; then
      echo "depot-cargo: cargo is not on PATH; install/select a rustup toolchain first" >&2
      exit 1
    fi

    repo_root="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || ${pkgs.coreutils}/bin/pwd -P)"
    cd "$repo_root"

    load_env_file() {
      local file="$1"

      if [ -f "$file" ]; then
        set -a
        . "$file"
        set +a
      fi
    }

    load_env_file "$HOME/.config/depot/sccache.env"
    load_env_file "$repo_root/.env.depot"

    if [ -n "''${DEPOT_TOKEN:-}" ] && [ -z "''${SCCACHE_WEBDAV_TOKEN:-}" ] && [ -z "''${SCCACHE_WEBDAV_PASSWORD:-}" ]; then
      export SCCACHE_WEBDAV_TOKEN="$DEPOT_TOKEN"
    fi

    if [ -n "''${SCCACHE_WEBDAV_PASSWORD:-}" ]; then
      unset SCCACHE_WEBDAV_TOKEN
    fi

    if [ -z "''${SCCACHE_WEBDAV_TOKEN:-}" ] && [ -z "''${SCCACHE_WEBDAV_PASSWORD:-}" ]; then
      cat >&2 <<'EOF'
depot-cargo: Depot sccache credentials were not found.

Create ~/.config/depot/sccache.env with either:

  SCCACHE_WEBDAV_TOKEN="depot_..."

or:

  SCCACHE_WEBDAV_USERNAME="depot-user"
  SCCACHE_WEBDAV_PASSWORD="depot_..."

Repo-local .env.depot files are also loaded when present.
EOF
      exit 1
    fi

    if [ -n "''${SCCACHE_WEBDAV_PASSWORD:-}" ] && [ -z "''${SCCACHE_WEBDAV_USERNAME:-}" ]; then
      echo "depot-cargo: SCCACHE_WEBDAV_PASSWORD is set, but SCCACHE_WEBDAV_USERNAME is missing" >&2
      exit 1
    fi

    repo_name="$(${pkgs.coreutils}/bin/basename "$repo_root")"
    default_key_prefix="$repo_name"

    mkdir -p "$repo_root/.direnv"

    export RUSTC_WRAPPER="${pkgs.sccache}/bin/sccache"
    export SCCACHE_CACHE_SIZE="''${SCCACHE_CACHE_SIZE:-50G}"
    export SCCACHE_SERVER_UDS="''${SCCACHE_SERVER_UDS:-$repo_root/.direnv/sccache.sock}"
    export SCCACHE_BASEDIRS="''${SCCACHE_BASEDIRS:-$repo_root}"
    export SCCACHE_WEBDAV_ENDPOINT="''${SCCACHE_WEBDAV_ENDPOINT:-https://cache.depot.dev}"
    export SCCACHE_WEBDAV_KEY_PREFIX="''${SCCACHE_WEBDAV_KEY_PREFIX:-$default_key_prefix}"
    export CARGO_INCREMENTAL=0

    ${pkgs.sccache}/bin/sccache --stop-server 2>/dev/null || true

    if [ "$#" -eq 0 ]; then
      set -- build
    fi

    set +e
    cargo "$@"
    status="$?"
    set -e

    ${pkgs.sccache}/bin/sccache --show-stats || true
    exit "$status"
  '';
in
{
  environment.sessionVariables = {
    OPENSSL_DIR = "${opensslForRust}";
    OPENSSL_INCLUDE_DIR = "${opensslForRust}/include";
    OPENSSL_LIB_DIR = "${opensslForRust}/lib";
    PKG_CONFIG_PATH = [ "${opensslForRust}/lib/pkgconfig" ];
    LD_LIBRARY_PATH = [ "${opensslForRust}/lib" ];
    RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";
    SCCACHE_CACHE_SIZE = "50G";
  };

  environment.shellInit = ''
    export OPENSSL_DIR="${opensslForRust}"
    export OPENSSL_INCLUDE_DIR="${opensslForRust}/include"
    export OPENSSL_LIB_DIR="${opensslForRust}/lib"

    case ":''${PKG_CONFIG_PATH:-}:" in
      *":${opensslForRust}/lib/pkgconfig:"*) ;;
      *) export PKG_CONFIG_PATH="${opensslForRust}/lib/pkgconfig''${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}" ;;
    esac

    case ":''${LD_LIBRARY_PATH:-}:" in
      *":${opensslForRust}/lib:"*) ;;
      *) export LD_LIBRARY_PATH="${opensslForRust}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
    esac

    export RUSTC_WRAPPER="''${RUSTC_WRAPPER:-${pkgs.sccache}/bin/sccache}"
    export SCCACHE_CACHE_SIZE="''${SCCACHE_CACHE_SIZE:-50G}"
  '';

  programs.nix-ld.libraries = [
    opensslForRust
  ];

  environment.systemPackages = with pkgs; [
    rustup
    cargo-audit
    cargo-bloat
    cargo-llvm-cov
    cargo-machete
    cargo-nextest
    cargo-outdated
    cargo-sort
    sqlx-cli
    sccache
    wasm-pack
    opensslForRust
    cachedCargo
    depotCargo
  ];
}
