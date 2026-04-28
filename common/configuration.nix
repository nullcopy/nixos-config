{
  config,
  lib,
  pkgs,
  ...
}:

{
  ## ----- nix -----------------------------------------------------------------
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Grayjay ships under the Source First License, which nixpkgs marks unfree.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "grayjay" ];

  # Garbage collection for nix generations
  nix.gc = {
    automatic = true;
    dates = "daily"; # How frequently to run gc
    options = "--delete-older-than 14d";
  };

  ## ----- locale --------------------------------------------------------------
  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  ## ----- networking ----------------------------------------------------------
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  ## ----- tailscale -----------------------------------------------------------
  # Daemon must run as root; per-user up/down is configured in home-manager.
  services.tailscale.enable = true;

  ## ----- bluetooth -----------------------------------------------------------
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };

  ## ----- power management ----------------------------------------------------
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  ## ----- audio ---------------------------------------------------------------
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  ## ----- gpg -----------------------------------------------------------------
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-curses;
  };
  services.pcscd.enable = true;

  ## ----- packages ------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    bottom
    magic-wormhole
    nixfmt
    tree
  ];
}
