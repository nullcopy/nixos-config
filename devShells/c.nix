{ pkgs, ... }:

pkgs.mkShell {
  packages = with pkgs; [
    gcc
    clang-tools
    gnumake
    cmake
    pkg-config

    prettier
  ];
}
