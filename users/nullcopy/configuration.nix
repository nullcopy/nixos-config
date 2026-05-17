{
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ../shared/base.nix
    ../shared/desktops/niri-noctalia
    inputs.nixvim.homeModules.nixvim
    ./tailscale.nix
    ./aliases.nix
    ./neovim.nix
    ./opencode.nix
  ];

  ## ----- packages ------------------------------------------------------------
  # Shell base (../shared/base.nix) + GUI baseline (the niri-noctalia desktop).
  home.packages = with pkgs; [
    grayjay
    transmission_4-gtk
    signal-desktop
    tldr
    tor-browser
  ];

  ## ----- programs ------------------------------------------------------------
  # zsh/starship base lives in ../shared/base.nix; this only adds the
  # substring-search keybindings on top.
  programs.zsh.historySubstringSearch = {
    enable = true;
    # Bind both cursor-mode (^[[A) and application-mode (^[OA) escapes:v
    searchUpKey = [
      "^[[A"
      "^[OA"
    ]; # Up arrow
    searchDownKey = [
      "^[[B"
      "^[OB"
    ]; # Down arrow
  };

  # direnv: per-directory environment loader. When you `cd` into a directory
  # containing a `.envrc`, direnv exports its env into your current shell;
  # leave the directory and it unloads. nix-direnv adds the `use flake`
  # builtin so `.envrc` can be a one-liner that loads a project's devShell
  # (and caches the evaluation so repeat `cd`s are instant).
  #
  # Per-project setup:
  #   1. Project has a `flake.nix` defining `devShells.<system>.default`.
  #   2. Add a `.envrc` next to it containing:  use flake
  #   3. First time only, run `direnv allow` — direnv won't auto-execute an
  #      .envrc until you've explicitly trusted it.
  # From then on, `cd` into the project loads the toolchain defined in
  # flake.nix (cargo/rustfmt/clang/etc) into your shell automatically.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.gpg.enable = true;

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "John Boyd";
        email = "john@coldnoise.net";
      };
      core.editor = "vim";
      commit.gpgsign = true;
      tag.gpgsign = true;
    };
  };

  ## ----- state version -------------------------------------------------------
  # Don't change this unless you know what you're doing
  home.stateVersion = "25.11";
}
