{
  pkgs,
  fenix,
  system,
}:

let
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

    # Sets LIBCLANG_PATH + BINDGEN_EXTRA_CLANG_ARGS for bindgen-based crates
    # (librocksdb-sys, zcash_script, ring, ...).
    rustPlatform.bindgenHook

    # Common -sys crate build deps.
    pkg-config
    openssl

    taplo
    prettier

    cargo-audit
    cargo-vet
  ];

  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
    pkgs.stdenv.cc.cc.lib
  ];
}
