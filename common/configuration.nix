{ config, lib, pkgs, ... }:

{
  ## ----- nix -----------------------------------------------------------------
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  ## ----- locale --------------------------------------------------------------
  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  ## ----- networking ----------------------------------------------------------
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  ## ----- packages ------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    bottom
    magic-wormhole
  ];
}
