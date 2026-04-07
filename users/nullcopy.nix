{ config, pkgs, inputs, ... }:

{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  ## ----- packages ------------------------------------------------------------
  home.packages = with pkgs; [
    brave
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
    settings = {
      launcher.terminalCommand = "alacritty -e";
    };
  };

  programs.alacritty.enable = true;

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
