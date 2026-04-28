{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.noctalia.homeModules.default
    inputs.nixvim.homeModules.nixvim
    ./tailscale.nix
    ./aliases.nix
    ./neovim.nix
  ];

  ## ----- packages ------------------------------------------------------------
  home.packages = with pkgs; [
    brave
    nerd-fonts.jetbrains-mono
    fzf
    grayjay
  ];

  ## ----- session variables ---------------------------------------------------
  home.sessionVariables = {
    BROWSER = "brave";
    TERMINAL = "alacritty";
  };

  ## ----- default applications ------------------------------------------------
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "brave-browser.desktop";
      "x-scheme-handler/http" = "brave-browser.desktop";
      "x-scheme-handler/https" = "brave-browser.desktop";
      "x-scheme-handler/about" = "brave-browser.desktop";
      "x-scheme-handler/unknown" = "brave-browser.desktop";
    };
  };

  ## ----- programs ------------------------------------------------------------
  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true;
    # settings/colors/plugins are managed via mkOutOfStoreSymlink below so UI
    # changes persist back into the flake repo as unstaged edits.
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    historySubstringSearch = {
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
  };

  programs.starship = {
    enable = true;
    presets = [ "gruvbox-rainbow" ];
  };

  programs.alacritty = {
    enable = true;
    settings.font.normal.family = "JetBrainsMono Nerd Font";
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

  ## ----- xdg config files ---------------------------------------------------
  # Symlink the entire ~/.config/noctalia directory (not individual files inside
  # it) because noctalia uses atomic write-and-rename when saving, which would
  # otherwise replace per-file symlinks with regular files on every save.
  xdg.configFile."noctalia".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.nixos-config/users/nullcopy/noctalia";

  ## ----- state version -------------------------------------------------------
  # Don't change this unless you know what you're doing
  home.stateVersion = "25.11";
}
