{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.niri.enable = true;

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${lib.getExe pkgs.tuigreet} --cmd niri-session";
      user = "greeter";
    };
  };

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
}
