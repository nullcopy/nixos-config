{
  config,
  lib,
  pkgs,
  ...
}:

## nullcopy's desktop: niri + Noctalia. mkHost imports this file on graphical
## hosts and skips it on headless ones. Together with ./desktop-home.nix and
## ./niri.nix it is the complete desktop definition; to reuse it, copy the
## three files into another users/<name>/ and change the username below.
## Greeters are imported per host from modules/greeters/, since a machine
## runs exactly one.
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
