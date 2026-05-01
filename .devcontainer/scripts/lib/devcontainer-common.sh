#!/usr/bin/env bash

devcontainer_load_project_env() {
  local root="$1"
  local env_file

  if [ -n "${DEVCONTAINER_PROJECT_ENV:-}" ]; then
    env_file="$DEVCONTAINER_PROJECT_ENV"
  elif [ -n "${DEVCONTAINER_PROJECT_PROFILE:-}" ]; then
    env_file="$root/.devcontainer/project/$DEVCONTAINER_PROJECT_PROFILE/project.env"
  else
    env_file="$root/.devcontainer/project.env"
  fi

  if [ ! -f "$env_file" ]; then
    return
  fi

  set -a
  # shellcheck disable=SC1090
  . "$env_file"
  set +a
}

devcontainer_project_profile_dir() {
  local root="$1"

  if [ -z "${DEVCONTAINER_PROJECT_PROFILE:-}" ]; then
    return 1
  fi

  printf '%s\n' "$root/.devcontainer/project/$DEVCONTAINER_PROJECT_PROFILE"
}

devcontainer_project_name() {
  local root="$1"

  printf '%s\n' "${DEVCONTAINER_PROJECT_NAME:-$(basename "$root")}"
}

devcontainer_state_dir() {
  local root="$1"
  local project_name

  project_name="$(devcontainer_project_name "$root")"
  printf '%s\n' "${DEVCONTAINER_STATE_DIR:-/tmp/$project_name}"
}

devcontainer_services_file() {
  local root="$1"
  local profile_dir

  if [ -n "${DEVCONTAINER_SERVICES_FILE:-}" ]; then
    printf '%s\n' "$DEVCONTAINER_SERVICES_FILE"
    return
  fi

  if profile_dir="$(devcontainer_project_profile_dir "$root")"; then
    printf '%s\n' "$profile_dir/services.tsv"
    return
  fi

  printf '%s\n' "$root/.devcontainer/services.tsv"
}

devcontainer_ensure_nix() {
  if command -v nix >/dev/null 2>&1; then
    return
  fi

  echo "nix is not installed; check the devcontainer nix feature output." >&2
  return 1
}

devcontainer_ensure_nix_daemon() {
  if nix --extra-experimental-features 'nix-command flakes' store ping >/dev/null 2>&1; then
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
    if nix --extra-experimental-features 'nix-command flakes' store ping >/dev/null 2>&1; then
      return
    fi
    sleep 0.25
  done

  echo "nix daemon is not responding; see /tmp/nix-daemon.log." >&2
  return 1
}

devcontainer_nix_develop() {
  local root="$1"
  shift

  nix --extra-experimental-features 'nix-command flakes' develop "path:$root" --command "$@"
}

devcontainer_configure_nix_bashrc() {
  local root="$1"
  local bashrc="${HOME}/.bashrc"
  local marker="# devcontainer-nix: auto-enter nix dev shell"
  local end_marker="# devcontainer-nix: end"
  local old_marker="# live-bootcamp-project: auto-enter nix dev shell"
  local old_end_marker="# live-bootcamp-project: end"
  local tmp

  tmp="$(mktemp)"

  touch "$bashrc"

  awk \
    -v marker="$marker" \
    -v end_marker="$end_marker" \
    -v old_marker="$old_marker" \
    -v old_end_marker="$old_end_marker" '
      $0 == marker || $0 == old_marker { skip = 1; next }
      ($0 == end_marker || $0 == old_end_marker) && skip { skip = 0; next }
      !skip { print }
    ' "$bashrc" >"$tmp"

  cat >>"$tmp" <<EOF

$marker
if [[ \$- == *i* ]] && [ "\${DEVCONTAINER_AUTO_NIX:-1}" != "0" ] && [ -f "$root/flake.nix" ]; then
  if [ -n "\${DEVCONTAINER_NIX_ENTERING:-}" ]; then
    unset DEVCONTAINER_NIX_ENTERING
  elif [ -z "\${IN_NIX_SHELL:-}" ]; then
    cd "$root" || return
    export DEVCONTAINER_NIX_ENTERING=1
    exec nix --extra-experimental-features 'nix-command flakes' develop "path:$root"
  fi
fi
$end_marker
EOF

  mv "$tmp" "$bashrc"
}

devcontainer_parse_service_line() {
  local line="$1"
  local -n service_name_ref="$2"
  local -n service_dir_ref="$3"
  local -n service_port_ref="$4"
  local -n service_command_ref="$5"

  if [[ "$line" == *$'\t'* ]]; then
    # shellcheck disable=SC2034
    IFS=$'\t' read -r service_name_ref service_dir_ref service_port_ref service_command_ref <<<"$line"
  else
    # shellcheck disable=SC2034
    read -r service_name_ref service_dir_ref service_port_ref service_command_ref <<<"$line"
  fi
}
