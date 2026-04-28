#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_DIR="/tmp/live-bootcamp-project"
NIX_FLAKE="path:$ROOT"

mkdir -p "$STATE_DIR"

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

pid_is_running() {
  local pid_file="$1"

  if [ ! -f "$pid_file" ]; then
    return 1
  fi

  local pid
  pid="$(cat "$pid_file")"

  if [ -z "$pid" ]; then
    return 1
  fi

  kill -0 "$pid" >/dev/null 2>&1
}

port_is_listening() {
  local port="$1"

  if command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${port}$"
    return
  fi

  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
    return
  fi

  return 1
}

start_service() {
  local name="$1"
  local rel_dir="$2"
  local port="$3"
  shift 3

  local service_dir="$ROOT/$rel_dir"
  local log_file="$STATE_DIR/$name.log"
  local pid_file="$STATE_DIR/$name.pid"

  if pid_is_running "$pid_file"; then
    echo "$name is already running with pid $(cat "$pid_file")."
    return
  fi

  if port_is_listening "$port"; then
    echo "$name appears to already be listening on port $port."
    return
  fi

  : >"$log_file"

  if command -v setsid >/dev/null 2>&1; then
    # shellcheck disable=SC2016
    nohup setsid bash -lc '
      set -euo pipefail
      service_dir="$1"
      nix_flake="$2"
      shift 2
      cd "$service_dir"
      export AUTH_SERVICE_HOST_NAME="${AUTH_SERVICE_HOST_NAME:-localhost}"
      export AUTH_SERVICE_IP="${AUTH_SERVICE_IP:-localhost}"
      exec nix develop "$nix_flake" --command "$@"
    ' bash "$service_dir" "$NIX_FLAKE" "$@" >>"$log_file" 2>&1 &
  else
    # shellcheck disable=SC2016
    nohup bash -lc '
      set -euo pipefail
      service_dir="$1"
      nix_flake="$2"
      shift 2
      cd "$service_dir"
      export AUTH_SERVICE_HOST_NAME="${AUTH_SERVICE_HOST_NAME:-localhost}"
      export AUTH_SERVICE_IP="${AUTH_SERVICE_IP:-localhost}"
      exec nix develop "$nix_flake" --command "$@"
    ' bash "$service_dir" "$NIX_FLAKE" "$@" >>"$log_file" 2>&1 &
  fi

  echo "$!" >"$pid_file"
  echo "Started $name on port $port. Logs: $log_file"
}

ensure_nix_daemon

start_service "auth-service" "auth-service" "3000" cargo watch -q -c -w src/ -w assets/ -x run
start_service "app-service" "app-service" "8000" cargo watch -q -c -w src/ -w assets/ -w templates/ -x run
