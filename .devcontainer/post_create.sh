#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- Nix helpers (inlined) ---------------------------------------------------

ensure_nix() {
  if command -v nix >/dev/null 2>&1; then
    return
  fi
  echo "ERROR: nix is not installed; check the devcontainer nix feature output." >&2
  return 1
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

  for _ in $(seq 1 40); do
    if nix store ping >/dev/null 2>&1; then
      return
    fi
    sleep 0.25
  done

  echo "ERROR: nix daemon is not responding; see /tmp/nix-daemon.log." >&2
  return 1
}

configure_nix_bashrc() {
  local bashrc="${HOME}/.bashrc"
  local marker="# devcontainer-nix: auto-enter nix dev shell"
  local end_marker="# devcontainer-nix: end"
  local tmp

  tmp="$(mktemp)"
  touch "$bashrc"

  # Remove any existing block (idempotent)
  awk \
    -v marker="$marker" \
    -v end_marker="$end_marker" '
      $0 == marker { skip = 1; next }
      $0 == end_marker && skip { skip = 0; next }
      !skip { print }
    ' "$bashrc" >"$tmp"

  cat >>"$tmp" <<EOF

$marker
if [[ \$- == *i* ]] && [ "\${DEVCONTAINER_AUTO_NIX:-1}" != "0" ] && [ -f "$ROOT/flake.nix" ]; then
  if [ -n "\${DEVCONTAINER_NIX_ENTERING:-}" ]; then
    unset DEVCONTAINER_NIX_ENTERING
  elif [ -z "\${IN_NIX_SHELL:-}" ]; then
    cd "$ROOT" || return
    export DEVCONTAINER_NIX_ENTERING=1
    exec nix develop "path:$ROOT"
  fi
fi
$end_marker
EOF

  mv "$tmp" "$bashrc"
}

# --- Main ---------------------------------------------------------------------

cd "$ROOT"

echo "==> Ensuring Nix is available..."
ensure_nix

echo "==> Ensuring Nix daemon is running..."
ensure_nix_daemon

echo "==> Configuring shell to auto-enter nix develop..."
configure_nix_bashrc

echo "==> Validating Nix development shell..."
nix develop "path:$ROOT" --command true

echo "==> Devcontainer setup complete."
