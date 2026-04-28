#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKSPACE_FOLDER="/workspaces/live-bootcamp-project"
NIX_FLAKE="path:$ROOT"

cd "$ROOT"

if ! command -v nix >/dev/null 2>&1; then
  echo "nix is not installed; check the devcontainer nix feature output." >&2
  exit 1
fi

ensure_nix_daemon() {
  if nix store info >/dev/null 2>&1; then
    return
  fi

  if ! pgrep -x nix-daemon >/dev/null 2>&1; then
    if [ "$(id -u)" = "0" ]; then
      ( . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh; /nix/var/nix/profiles/default/bin/nix-daemon > /tmp/nix-daemon.log 2>&1 ) &
    elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
      sudo -n sh -c '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh; /nix/var/nix/profiles/default/bin/nix-daemon > /tmp/nix-daemon.log 2>&1 &'
    fi
  fi

  for _ in {1..40}; do
    if nix store info >/dev/null 2>&1; then
      return
    fi
    sleep 0.25
  done

  echo "nix daemon is not responding; see /tmp/nix-daemon.log." >&2
  return 1
}

ensure_nix_daemon

echo "Validating Nix development shell..."
nix develop "$NIX_FLAKE" --command bash -lc 'rustc --version && cargo --version'

echo "Fetching Rust dependencies..."
nix develop "$NIX_FLAKE" --command bash -lc 'cd auth-service && cargo fetch --locked'
nix develop "$NIX_FLAKE" --command bash -lc 'cd app-service && cargo fetch --locked'

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
