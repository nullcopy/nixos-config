{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./yubikey-luks.nix # for Yubikey-based FDE
    ../../common/desktop.nix
  ];

  ## ----- boot ----------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  ## ----- hardware ------------------------------------------------------------
  hardware.graphics.enable = true;

  ## ----- network -------------------------------------------------------------
  networking.hostName = "wisp";

  ## ----- users ---------------------------------------------------------------
  users.users.nullcopy = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "audio" ];
  };

  ## ----- state version -------------------------------------------------------
  # Don't change this unless you know what you're doing
  #
  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
