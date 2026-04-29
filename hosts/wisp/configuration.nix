{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./yubikey-luks.nix # for Yubikey-based FDE
    ./ollama.nix
    ../../common/desktop.nix
  ];

  ## ----- boot ----------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Crash triage — see ./crash-triage.md.
  # Confirmed: kernel use-after-free, ~16-byte structured write into freed
  # objects. Hits whatever cache recycles the slot (skbuff_small_head,
  # anon_vma_chain so far). Producer unknown.
  # mt7925e (WiFi 7) ruled out 2026-04-29 round 3.
  # Round 4: shotgun-off all Strix-Halo-young drivers at once.
  # If clean → bisect back; if dirty → BIOS/microcode/RAM, not a driver.
  # amdgpu intentionally left on (mature, and disabling it confounds the
  # display path).
  boot.kernelParams = [
    "consoleblank=0"
    "slub_debug=FZP"
    "slab_nomerge"
    "panic_on_warn=1"
    "module_blacklist=mt7925e,amdxdna,amd_isp4,pinctrl_amdisp,i2c_designware_amdisp,amd_pmf"
  ];

  ## ----- hardware ------------------------------------------------------------
  hardware.graphics.enable = true;

  ## ----- network -------------------------------------------------------------
  networking.hostName = "wisp";

  ## ----- users ---------------------------------------------------------------
  programs.zsh.enable = true; # system-level so zsh is in /etc/shells

  users.users.nullcopy = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
    ];
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
