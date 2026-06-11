{ lib, pkgs, ... }:

## greetd + tuigreet. Greeters are imported by hosts rather than by user
## desktop configs: only one greeter can own the seat, so each graphical host
## imports exactly one module from modules/greeters/.
##
## tuigreet is desktop-agnostic: it lists every session installed into the
## system profile (e.g. programs.niri.enable drops niri.desktop into
## share/wayland-sessions) and remembers each user's last choice, so new
## desktops show up at the login screen without any change here.
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
