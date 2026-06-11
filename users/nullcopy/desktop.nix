{
  config,
  lib,
  pkgs,
  ...
}:

## nullcopy's desktop: niri + Noctalia. Included by mkHost only on graphical
## hosts; never evaluated on headless ones. The user — not the host — owns
## this choice: this file plus ./desktop-home.nix and ./niri.nix are the
## complete definition, so another user wanting the same desktop copies those
## three files into users/<them>/ and edits the username below. The greeter is
## NOT defined here — it's host config (see modules/greeters/) because a
## machine can only run one.
{
  # Enabling niri also installs its session file into
  # /run/current-system/sw/share/wayland-sessions, which is how the host's
  # greeter discovers and offers it.
  programs.niri.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    config.common.default = [ "gtk" ];
  };

  ## ----- noctalia companions -------------------------------------------------
  environment.systemPackages = with pkgs; [
    grim
    slurp
    satty
    wlsunset
    playerctl
    xdg-utils
  ];

  ## ----- home-manager half ---------------------------------------------------
  home-manager.users.nullcopy = import ./desktop-home.nix;
}
