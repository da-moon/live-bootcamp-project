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

configure_bashrc() {
  local bashrc="${HOME}/.bashrc"
  local marker="# live-bootcamp-project: auto-enter nix dev shell"
  local end_marker="# live-bootcamp-project: end"
  local tmp

  tmp="$(mktemp)"

  touch "$bashrc"

  awk -v marker="$marker" -v end_marker="$end_marker" '
    $0 == marker { skip = 1; next }
    $0 == end_marker { skip = 0; next }
    !skip { print }
  ' "$bashrc" >"$tmp"

  cat >>"$tmp" <<EOF

$marker
if [[ \$- == *i* ]] && [ "\${LIVE_BOOTCAMP_AUTO_NIX:-1}" != "0" ] && [ -f "$WORKSPACE_FOLDER/flake.nix" ]; then
  if [ -n "\${LIVE_BOOTCAMP_NIX_ENTERING:-}" ]; then
    unset LIVE_BOOTCAMP_NIX_ENTERING
  elif [ -z "\${IN_NIX_SHELL:-}" ]; then
    cd "$WORKSPACE_FOLDER" || return
    export LIVE_BOOTCAMP_NIX_ENTERING=1
    exec nix --extra-experimental-features 'nix-command flakes' develop "path:$WORKSPACE_FOLDER"
  fi
fi
$end_marker
EOF

  mv "$tmp" "$bashrc"
}

ensure_nix_daemon() {
  if nix store ping >/dev/null 2>&1; then
    return
  fi

  if ! pgrep -x nix-daemon >/dev/null 2>&1; then
    if [ "$(id -u)" = "0" ]; then
      # shellcheck disable=SC1091
      ( . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh; /nix/var/nix/profiles/default/bin/nix-daemon > /tmp/nix-daemon.log 2>&1 ) &
    elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
      sudo -n sh -c '. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh; /nix/var/nix/profiles/default/bin/nix-daemon > /tmp/nix-daemon.log 2>&1 &'
    fi
  fi

  for _ in {1..40}; do
    if nix store ping >/dev/null 2>&1; then
      return
    fi
    sleep 0.25
  done

  echo "nix daemon is not responding; see /tmp/nix-daemon.log." >&2
  return 1
}

configure_bashrc
ensure_nix_daemon

echo "Validating Nix development shell..."
nix develop "$NIX_FLAKE" --command bash -lc 'rustc --version && cargo --version'

echo "Fetching Rust dependencies..."
nix develop "$NIX_FLAKE" --command bash -lc 'cd auth-service && cargo fetch --locked'
nix develop "$NIX_FLAKE" --command bash -lc 'cd app-service && cargo fetch --locked'

echo "Devcontainer setup complete."
