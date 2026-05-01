#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/devcontainer-common.sh"

devcontainer_load_project_env "$ROOT"

STATE_DIR="$(devcontainer_state_dir "$ROOT")"
SERVICES_FILE="$(devcontainer_services_file "$ROOT")"
NIX_FLAKE="path:$ROOT"

mkdir -p "$STATE_DIR"

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
  local command="$4"

  local service_dir="$ROOT/$rel_dir"
  local log_file="$STATE_DIR/$name.log"
  local pid_file="$STATE_DIR/$name.pid"

  if [ ! -d "$service_dir" ]; then
    echo "Skipping $name; service directory does not exist: $service_dir" >&2
    return
  fi

  if pid_is_running "$pid_file"; then
    echo "$name is already running with pid $(cat "$pid_file")."
    return
  fi

  if [ -n "$port" ] && port_is_listening "$port"; then
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
      service_command="$3"
      cd "$service_dir"
      exec nix --extra-experimental-features "nix-command flakes" develop "$nix_flake" --command bash -lc "$service_command"
    ' bash "$service_dir" "$NIX_FLAKE" "$command" >>"$log_file" 2>&1 &
  else
    # shellcheck disable=SC2016
    nohup bash -lc '
      set -euo pipefail
      service_dir="$1"
      nix_flake="$2"
      service_command="$3"
      cd "$service_dir"
      exec nix --extra-experimental-features "nix-command flakes" develop "$nix_flake" --command bash -lc "$service_command"
    ' bash "$service_dir" "$NIX_FLAKE" "$command" >>"$log_file" 2>&1 &
  fi

  echo "$!" >"$pid_file"
  echo "Started $name${port:+ on port $port}. Logs: $log_file"
}

if [ ! -s "$SERVICES_FILE" ]; then
  echo "No services configured at $SERVICES_FILE."
  exit 0
fi

devcontainer_ensure_nix
devcontainer_ensure_nix_daemon

while IFS= read -r line || [ -n "$line" ]; do
  if [[ -z "${line//[[:space:]]/}" || "$line" == \#* ]]; then
    continue
  fi

  name=""
  rel_dir=""
  port=""
  command=""
  devcontainer_parse_service_line "$line" name rel_dir port command

  if [ -z "$name" ] || [ -z "$rel_dir" ] || [ -z "$command" ]; then
    echo "Invalid service row in $SERVICES_FILE: $line" >&2
    exit 1
  fi

  start_service "$name" "$rel_dir" "$port" "$command"
done <"$SERVICES_FILE"
