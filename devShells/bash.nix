{ pkgs, ... }:

pkgs.mkShell {
  packages = with pkgs; [
    shfmt
    shellcheck
    bash-language-server

    prettier
  ];
}
