{ lib, pkgs, ... }:

## The greeter is HOST config: exactly one greeter can own the seat, so a
## graphical host imports one module from modules/greeters/ — a greeter is
## never part of a user's desktop config.
##
## tuigreet here is desktop-agnostic: it lists every session that users'
## desktop configs install into the system profile (e.g. programs.niri.enable
## drops niri.desktop into share/wayland-sessions) and remembers each user's
## last choice. Adding a new WM/desktop never touches this file — its session
## just shows up in the list.
{
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = lib.concatStringsSep " " [
        (lib.getExe pkgs.tuigreet)
        "--remember"
        "--remember-user-session"
        "--sessions /run/current-system/sw/share/wayland-sessions:/run/current-system/sw/share/xsessions"
      ];
      user = "greeter";
    };
  };

  # --remember* persists under /var/cache/tuigreet; without this rule the dir
  # never exists and remembering silently fails.
  systemd.tmpfiles.rules = [
    "d /var/cache/tuigreet 0755 greeter greeter -"
  ];
}
