{ pkgs, ... }:

pkgs.mkShell {
  packages = with pkgs; [
    go
    gopls
    gotools

    prettier
  ];
}
