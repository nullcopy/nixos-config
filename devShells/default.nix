{
  pkgs,
  fenix,
  system,
}:

# Kitchen-sink devShell — covers every language used in the nixvim LSP config,
# intended as a fallback for projects that don't ship their own flake. Real
# projects should define their own `devShells.default` pinning project-
# specific versions; this shell is for ad-hoc scratch work.

let
  # Stable Rust toolchain (cargo, rustc, rustfmt, clippy, rust-src,
  # rust-analyzer). Defined locally so other shells (e.g. embedded-arm) can
  # pin different toolchains/targets without affecting this one.
  rustToolchain = fenix.packages.${system}.combine [
    fenix.packages.${system}.stable.cargo
    fenix.packages.${system}.stable.rustc
    fenix.packages.${system}.stable.rustfmt
    fenix.packages.${system}.stable.clippy
    fenix.packages.${system}.stable.rust-src
    fenix.packages.${system}.stable.rust-analyzer
  ];
in
pkgs.mkShell {
  packages = with pkgs; [
    rustToolchain

    # C / C++
    gcc
    clang-tools # clangd, clang-format
    gnumake
    cmake

    # Go
    go
    gopls
    gotools

    # Python
    python3
    black
    pyright

    # Lua
    lua
    stylua
    lua-language-server

    # Nix
    nil
    nixfmt

    # Shell
    shfmt
    shellcheck
    bash-language-server

    # TOML
    taplo

    # Markdown / YAML / web
    prettier
  ];

  # `nix develop` always spawns bashInteractive, dropping starship,
  # aliases, completions, etc. Re-exec into zsh so interactive config
  # loads (zsh reads ~/.zshrc / $ZDOTDIR/.zshrc on its own).
  shellHook = ''
    exec ${pkgs.zsh}/bin/zsh
  '';
}
