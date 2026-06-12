{
  config,
  lib,
  pkgs,
  ...
}:

## Baseline applied to every host by mkHost. Keep this strictly universal —
## a headless server gets everything in here. Role-specific config (audio,
## NetworkManager, bluetooth, power, greeters, ...) lives in sibling modules
## that hosts import explicitly from their configuration.nix.
{
  ## ----- nix -----------------------------------------------------------------
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Hard-link identical files in the store as they're added; saves disk at a
  # small cost on writes to the store.
  nix.settings.auto-optimise-store = true;

  # Central unfree whitelist. This must live at the system level — with
  # home-manager.useGlobalPkgs every user's packages evaluate against this
  # nixpkgs instance, so a user wanting an unfree package adds it here.
  # Grayjay ships under the Source First License, which nixpkgs marks unfree.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "grayjay" ];

  # Garbage collection for nix generations
  nix.gc = {
    automatic = true;
    dates = "daily"; # How frequently to run gc
    options = "--delete-older-than 14d";
  };

  ## ----- locale --------------------------------------------------------------
  # mkDefault so a host in another timezone/locale can override plainly.
  time.timeZone = lib.mkDefault "America/Chicago";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  ## ----- networking ----------------------------------------------------------
  networking.firewall.enable = true;

  ## ----- tailscale -----------------------------------------------------------
  # Daemon must run as root; per-user up/down is configured in home-manager.
  services.tailscale.enable = true;

  ## ----- gpg -----------------------------------------------------------------
  # pinentry-curses works on console and SSH alike, so this is headless-safe.
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
    pv
  ];
}
