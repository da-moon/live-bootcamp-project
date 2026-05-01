## Development with Nix

This repo uses `flake.nix` as the source of truth for the Rust toolchain and
developer tools.

```bash
nix develop

cd app-service
cargo build
cd ..

cd auth-service
cargo build
cd ..
```

## Coder / Devcontainer

The repo includes a `.devcontainer` setup for Coder. It installs Nix in the
container, enters this repo's flake dev shell for interactive Bash sessions, and
auto-starts both Rust services with `cargo watch`.

Your Coder template still needs devcontainer support enabled, including Docker
and `@devcontainers/cli`, so Coder can discover and run `.devcontainer/devcontainer.json`.

From the Coder dashboard:

1. Start the `live-bootcamp-project` devcontainer.
2. Open `code-server` from the devcontainer apps.
3. Open `App Service` for `http://localhost:8000`.
4. Open `Auth Service` for `http://localhost:3000`.

Service logs are written outside the repo:

```bash
tail -f /tmp/live-bootcamp-project/app-service.log
tail -f /tmp/live-bootcamp-project/auth-service.log
```

Restart the services manually if needed:

```bash
.devcontainer/scripts/stop_services.sh
.devcontainer/scripts/start_services.sh
```

If an older devcontainer build freezes when opening a shell or SSH session,
rebuild or recreate the devcontainer from the Coder dashboard after pulling the
latest repo changes. The rebuild reruns `postCreateCommand` and replaces the old
shell auto-enter block.

The app's login/logout links still point at `localhost:3000`. That works for
local forwarding and Coder Desktop; when using only browser-based Coder dashboard
apps, open the `Auth Service` app button directly if your browser cannot resolve
that localhost link.

## Run Servers Locally

#### App service

```bash
nix develop
cd app-service
cargo watch -q -c -w src/ -w assets/ -w templates/ -x run
```

visit http://localhost:8000

#### Auth service

```bash
nix develop
cd auth-service
cargo watch -q -c -w src/ -w assets/ -x run
```

visit http://localhost:3000

## Run Servers Locally with Docker

```bash
docker compose build
docker compose up
```

visit http://localhost:8000 and http://localhost:3000
