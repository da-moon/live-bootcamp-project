{
  description = "Development flake for live-bootcamp-project";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils }:
    flake-utils.lib.eachSystem ["x86_64-linux" "aarch64-linux"] (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        # Derive musl target from system
        muslTarget = {
          "x86_64-linux" = "x86_64-unknown-linux-musl";
          "aarch64-linux" = "aarch64-unknown-linux-musl";
        }.${system} or null;

        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
          targets = pkgs.lib.optionals (muslTarget != null) [ muslTarget ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Rust toolchain with rust-analyzer
            rustToolchain
            rust-analyzer

            # Essential cargo extensions
            cargo-nextest     # Better test runner with cleaner output
            cargo-machete     # Find unused dependencies
            cargo-audit       # Security vulnerability scanning
            cargo-expand      # Macro debugging
            cargo-watch       # Auto-rebuild on file changes
            cargo-edit        # Manage dependencies (cargo add/rm)
            cargo-outdated    # Check for outdated dependencies

            # Task runner
            cargo-make        # Task runner (Makefile.toml)

            # Code quality tools
            cargo-deny        # Dependency auditing, license compliance
            typos             # Source code spell checking
            cargo-llvm-cov    # Code coverage
            bacon             # Background rust code checker
            starship          # Prompt initialized by the shell hook
            # Build and performance
            sccache           # Compilation cache for faster builds
            pkg-config
            stdenv.cc         # C toolchain for linking native deps
            binutils
            # Note: musl is NOT in buildInputs — the Rust toolchain (via rust-overlay)
            # bundles its own musl when the musl target is added. Adding musl.dev here
            # contaminates the host linker environment and causes glibc symbol resolution
            # failures (fstat64, mmap64, etc.) when compiling build scripts.
          ];

          shellHook = ''
            echo "Rust Development Environment"
            echo "========================================"
            echo "Rust: $(rustc --version | cut -d' ' -f2)"
            ${if muslTarget != null then ''echo "Musl Target: ${muslTarget}"'' else ""}
            echo ""
            echo "Tasks (cargo-make):"
            echo "  makers setup                - Fetch all dependencies"
            echo "  makers start                - Start all services"
            echo "  makers stop                 - Stop all services"
            echo "  makers test                 - Run tests"
            echo "  makers lint                 - Run clippy + typos"
            echo "  makers audit                - Security audit"
            echo "  makers coverage             - Code coverage"
            echo "  makers check-deps           - Unused/outdated deps"
            echo "========================================"

            # Enable sccache for faster rebuilds
            export RUSTC_WRAPPER=sccache
            export SCCACHE_DIR="''${SCCACHE_DIR:-$HOME/.cache/sccache}"

            # Initiate starship prompt
            eval "$(starship init bash)"
          '';

          # Development environment variables
          RUST_BACKTRACE = "1";
        };
      });
}
