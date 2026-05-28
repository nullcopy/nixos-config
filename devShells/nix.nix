{ pkgs, ... }:

pkgs.mkShell {
  packages = with pkgs; [
    nil
    nixfmt

    prettier
  ];
}
