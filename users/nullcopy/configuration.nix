{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.noctalia.homeModules.default
    ./tailscale.nix
    ./git-aliases.nix
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
    # Config files exported from the live desktop. Edit the JSON in-repo, or
    # re-export from ~/.config/noctalia/ after tweaking in the noctalia UI.
    settings = ./noctalia/settings.json;
    colors = ./noctalia/colors.json;
    plugins = ./noctalia/plugins.json;
  };

  # The noctalia home-manager module manages settings/colors/plugins JSON but
  # does NOT install plugin binaries. Symlink the catwalk plugin sources so the
  # bar widget `plugin:catwalk` resolves without needing an in-app download.
  xdg.configFile."noctalia/plugins/catwalk".source = ./noctalia/plugins/catwalk;

  programs.zsh.enable = true;
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

  ## ----- state version -------------------------------------------------------
  # Don't change this unless you know what you're doing
  home.stateVersion = "25.11";
}
