# Generic Nix/Coder Devcontainer

This directory has a generic Nix flake devcontainer base plus an optional
project profile used by this repository.

## Generic Copy-Paste Use

For another Nix project:

1. Copy `.devcontainer` into the project.
2. Copy `.devcontainer/devcontainer.generic.json` to `.devcontainer/devcontainer.json`.
3. Remove `.devcontainer/project/live-bootcamp-project` unless you want it as an example.
4. Rebuild the devcontainer.

The generic base:

- installs Nix with flakes enabled
- installs code-server for Coder
- installs a safe interactive Bash hook that enters `nix develop`
- validates the local flake with `nix develop path:$PWD --command true`
- does not start services
- does not run Cargo or language-specific setup

Set `DEVCONTAINER_AUTO_NIX=0` before opening a shell to opt out of the automatic
`nix develop` hook.

## Project Profiles

Project-specific behavior lives under `.devcontainer/project/<profile>/`.

An active devcontainer opts into a profile with:

```json
"containerEnv": {
  "DEVCONTAINER_PROJECT_PROFILE": "live-bootcamp-project"
}
```

A profile can contain:

- `project.env`: environment variables and state-dir settings
- `services.tsv`: optional auto-start service definitions
- `post_create.sh`: optional project-specific setup

Without `DEVCONTAINER_PROJECT_PROFILE`, the root scripts stay generic and skip
profile setup and service startup.

## `services.tsv` Format

Rows are tab-separated:

```text
name	directory	port	command
```

Example:

```text
web	.	8080	npm run dev -- --host 0.0.0.0
```

`port` may be left empty if a service should be process-managed but not
port-checked.

## This Repository

The active `devcontainer.json` intentionally enables the
`live-bootcamp-project` profile so the current Coder setup still auto-starts:

- `auth-service` on port `3000`
- `app-service` on port `8000`

The Rust/Cargo dependency prefetch lives in
`.devcontainer/project/live-bootcamp-project/post_create.sh`.
