#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/devcontainer-common.sh"

cd "$ROOT"

devcontainer_load_project_env "$ROOT"
devcontainer_ensure_nix
devcontainer_configure_nix_bashrc "$ROOT"
devcontainer_ensure_nix_daemon

echo "Validating Nix development shell..."
devcontainer_nix_develop "$ROOT" true

if PROFILE_DIR="$(devcontainer_project_profile_dir "$ROOT")"; then
  PROJECT_POST_CREATE="$PROFILE_DIR/post_create.sh"
  if [ -x "$PROJECT_POST_CREATE" ]; then
    "$PROJECT_POST_CREATE"
  fi
fi

echo "Devcontainer setup complete."
