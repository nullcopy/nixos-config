{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./luks.nix
    ./ollama.nix
    # Role modules this host opts into. A headless host would import none of
    # these; the greeter (one per machine) is always chosen here
    ../../modules/audio.nix
    ../../modules/bluetooth.nix
    ../../modules/networkmanager.nix
    ../../modules/power.nix
    ../../modules/greeters/tuigreet.nix
  ];

  ## ----- boot ----------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "uvcvideo" ]; # USB webcam

  ## ----- hardware ------------------------------------------------------------
  hardware.graphics.enable = true;

  ## ----- state version -------------------------------------------------------
  # Don't change this unless you know what you're doing
  #
  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
