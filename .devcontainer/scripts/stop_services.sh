#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="/tmp/live-bootcamp-project"

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

stop_service "app-service"
stop_service "auth-service"
