#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKSPACE_FOLDER="/workspaces/live-bootcamp-project"

cd "$ROOT"

if ! command -v nix >/dev/null 2>&1; then
  echo "nix is not installed; check the devcontainer nix feature output." >&2
  exit 1
fi

echo "Validating Nix development shell..."
nix develop "$ROOT" --command bash -lc 'rustc --version && cargo --version'

echo "Fetching Rust dependencies..."
nix develop "$ROOT" --command bash -lc 'cd auth-service && cargo fetch --locked'
nix develop "$ROOT" --command bash -lc 'cd app-service && cargo fetch --locked'

configure_bashrc() {
  local bashrc="${HOME}/.bashrc"
  local marker="# live-bootcamp-project: auto-enter nix dev shell"

  touch "$bashrc"

  if grep -qF "$marker" "$bashrc"; then
    return
  fi

  cat >>"$bashrc" <<EOF

$marker
if [[ \$- == *i* ]] && [ -z "\${IN_NIX_SHELL:-}" ] && [ "\${LIVE_BOOTCAMP_AUTO_NIX:-1}" != "0" ] && [ -f "$WORKSPACE_FOLDER/flake.nix" ]; then
  cd "$WORKSPACE_FOLDER" || return
  exec nix develop
fi
# live-bootcamp-project: end
EOF
}

configure_bashrc

echo "Devcontainer setup complete."
