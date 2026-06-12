{
  config,
  pkgs,
  inputs,
  ...
}:

## Home-manager half of nullcopy's desktop, wired in by ./desktop.nix: shell
## UI, terminal, browser, GUI apps, and the niri keybindings (./niri.nix).
## Per-user paths are derived from config.home.username, so a copied desktop
## config needs no edits in this file.
{
  imports = [
    inputs.noctalia.homeModules.default
    ./niri.nix
  ];

  ## ----- packages ------------------------------------------------------------
  home.packages = with pkgs; [
    brave
    grayjay
    nautilus
    nerd-fonts.jetbrains-mono # provides the alacritty font below
    signal-desktop
    tor-browser
    transmission_4-gtk

    # Noctalia companions / screenshot stack, invoked from the niri binds in
    # ./niri.nix (grim/slurp/satty) and by noctalia itself (wlsunset,
    # playerctl, xdg-utils).
    grim
    playerctl
    satty
    slurp
    wlsunset
    xdg-utils
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
  programs.noctalia = {
    enable = true;
    # systemd startup is opt-in (programs.noctalia.systemd.enable) and left off
    # here: it causes delayed start and unreliable IPC. The shell is spawned
    # from niri's spawn-at-startup instead.
    # See https://docs.noctalia.dev/v5/getting-started/nixos/#running-the-shell
    #
    # Base config (config.toml) is left at noctalia's built-in defaults — the
    # settings UI never writes it, only ~/.local/state/noctalia/settings.toml
    # (tracked via the symlink below). To pin a base setting declaratively, set
    # it here and this module renders a read-only config.toml, e.g.:
    #   settings.shell.font_family = "JetBrainsMono Nerd Font";
  };

  programs.alacritty = {
    enable = true;
    settings = {
      font.normal.family = "JetBrainsMono Nerd Font";
      window.decorations = "None";
    };
  };

  ## ----- noctalia UI settings -----------------------------------------------
  # v5 writes everything changed in the settings UI to its *state* dir, not the
  # config dir: ~/.local/state/noctalia/settings.toml (layered over config.toml /
  # built-in defaults). Symlink just that one file back into the flake repo so
  # in-UI changes show up as unstaged diffs. noctalia's atomic writer is
  # symlink-aware — it canonicalises the link and renames onto the real target —
  # so the single-file out-of-store symlink survives every save.
  #
  # The target lives in the user's own checkout of this repo (~/.nixos-config),
  # at users/<username>/noctalia-settings.toml. A user copying this desktop
  # config creates that file alongside it (empty is fine).
  #
  # config.toml itself is read-only (built-in defaults, or declarative via
  # programs.noctalia.settings above), so it isn't symlinked. Note: custom
  # palettes saved in the UI land in ~/.config/noctalia/palettes/ and are NOT
  # tracked here.
  home.file.".local/state/noctalia/settings.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.nixos-config/users/${config.home.username}/noctalia-settings.toml";
}
