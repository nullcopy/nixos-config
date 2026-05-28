{ pkgs, ... }:

pkgs.mkShell {
  packages = with pkgs; [
    python3
    black
    pyright

    taplo
    prettier
  ];
}
