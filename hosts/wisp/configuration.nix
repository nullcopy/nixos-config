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
  # Round 6 result: clean ≥30 min with amdgpu re-enabled and
  # mt7925_common (+ the five other young drivers) still blacklisted.
  # That clears amdgpu and pins the producer to mt7925_common (the
  # WiFi+BT shared lib for the MT7925 / WiFi-7 chip) or something it
  # pulls in.
  # Round 7: shrink the blacklist to just the mt7925 pair. Revert
  # amdxdna, amd_isp4, pinctrl_amdisp, i2c_designware_amdisp, amd_pmf —
  # they were only blacklisted as part of the shotgun. Soak ≥30 min.
  # If still clean, this is the long-term config and we file upstream
  # against mt76. Watchdog-panic + slub_debug params stay on as a
  # safety net.
  boot.kernelParams = [
    "consoleblank=0"
    "slub_debug=FZP"
    "slab_nomerge"
    "panic_on_warn=1"
    "softlockup_panic=1"
    "panic_on_rcu_stall=1"
    "rcu_cpu_stall_timeout=15"
    #"module_blacklist=pinctrl_amdisp,i2c_designware_amdisp,amd_pmf,amdgpu" # <---PASS
    #"module_blacklist=pinctrl_amdisp,i2c_designware_amdisp,amdgpu" # <---PASS
    #"module_blacklist=pinctrl_amdisp,i2c_designware_amdisp" # <--FAIL
    #"module_blacklist=amdgpu" # <---PASS
    #"module_blacklist=" <---FAIL
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
