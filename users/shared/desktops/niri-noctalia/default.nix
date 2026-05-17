{
  config,
  pkgs,
  inputs,
  ...
}:

{
  ## The niri + Noctalia desktop. A user opts in by importing this module
  ## (e.g. `../shared/desktops/niri-noctalia`). To offer a different desktop
  ## (KDE, GNOME, …) add a sibling directory under users/shared/desktops/ and
  ## import that instead — everything else in a user's config (the shell base
  ## in ../base.nix, apps, identity) is desktop-agnostic.
  imports = [
    inputs.noctalia.homeModules.default
    ./niri.nix
  ];

  ## ----- packages (GUI) ------------------------------------------------------
  home.packages = with pkgs; [
    brave
    nautilus
    nerd-fonts.jetbrains-mono # provides the alacritty font below
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
    # Noctalia upstream deprecated systemd startup — it causes delayed start
    # and unreliable IPC. The shell is spawned from niri's spawn-at-startup
    # instead. See https://docs.noctalia.dev/v4/getting-started/nixos/#running-the-shell
    # settings/colors/plugins are managed via mkOutOfStoreSymlink below so UI
    # changes persist back into the flake repo as unstaged edits.
  };

  programs.alacritty = {
    enable = true;
    settings.font.normal.family = "JetBrainsMono Nerd Font";
  };

  ## ----- xdg config files ----------------------------------------------------
  # Symlink the entire ~/.config/noctalia directory (not individual files inside
  # it) because noctalia uses atomic write-and-rename when saving, which would
  # otherwise replace per-file symlinks with regular files on every save. The
  # target is derived from the username so each user persists their own Noctalia
  # config back into users/<name>/noctalia/ in the repo (at /etc/nixos).
  xdg.configFile."noctalia".source =
    config.lib.file.mkOutOfStoreSymlink "/etc/nixos/users/${config.home.username}/noctalia";
}
