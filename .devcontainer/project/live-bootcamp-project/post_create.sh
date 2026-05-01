#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck disable=SC1091
. "$ROOT/.devcontainer/scripts/lib/devcontainer-common.sh"

cd "$ROOT"

devcontainer_load_project_env "$ROOT"

echo "Validating Rust toolchain..."
devcontainer_nix_develop "$ROOT" bash -lc 'rustc --version && cargo --version'

echo "Fetching Rust dependencies..."
devcontainer_nix_develop "$ROOT" bash -lc 'cd auth-service && cargo fetch --locked'
devcontainer_nix_develop "$ROOT" bash -lc 'cd app-service && cargo fetch --locked'
