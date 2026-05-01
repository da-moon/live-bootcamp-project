#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/devcontainer-common.sh"

devcontainer_load_project_env "$ROOT"

STATE_DIR="$(devcontainer_state_dir "$ROOT")"
SERVICES_FILE="$(devcontainer_services_file "$ROOT")"

stop_service() {
  local name="$1"
  local pid_file="$STATE_DIR/$name.pid"

  if [ ! -f "$pid_file" ]; then
    echo "$name is not running."
    return
  fi

  local pid
  pid="$(cat "$pid_file")"

  if [ -z "$pid" ] || ! kill -0 "$pid" >/dev/null 2>&1; then
    rm -f "$pid_file"
    echo "$name had a stale pid file."
    return
  fi

  echo "Stopping $name..."

  if ! kill -TERM -- "-$pid" >/dev/null 2>&1; then
    kill -TERM "$pid" >/dev/null 2>&1 || true
  fi

  for _ in {1..20}; do
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      rm -f "$pid_file"
      echo "Stopped $name."
      return
    fi
    sleep 0.25
  done

  if ! kill -KILL -- "-$pid" >/dev/null 2>&1; then
    kill -KILL "$pid" >/dev/null 2>&1 || true
  fi

  rm -f "$pid_file"
  echo "Stopped $name."
}

if [ ! -s "$SERVICES_FILE" ]; then
  echo "No services configured at $SERVICES_FILE."
  exit 0
fi

services=()
while IFS= read -r line || [ -n "$line" ]; do
  if [[ -z "${line//[[:space:]]/}" || "$line" == \#* ]]; then
    continue
  fi

  if [[ "$line" == *$'\t'* ]]; then
    IFS=$'\t' read -r name _ <<<"$line"
  else
    read -r name _ <<<"$line"
  fi

  if [ -n "$name" ]; then
    services+=("$name")
  fi
done <"$SERVICES_FILE"

for ((idx = ${#services[@]} - 1; idx >= 0; idx--)); do
  stop_service "${services[$idx]}"
done
