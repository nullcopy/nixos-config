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
    ./git-aliases.nix
    ./neovim.nix
  ];

  ## ----- packages ------------------------------------------------------------
  home.packages = with pkgs; [
    brave
    nerd-fonts.jetbrains-mono
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
      searchUpKey = [ "^[[A" ]; # Up arrow
      searchDownKey = [ "^[[B" ]; # Down arrow
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

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "John Boyd";
        email = "john@coldnoise.net";
      };
      core.editor = "vim";
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
