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
  # Round 5 result: clean ≥30 min with the full blacklist (incl. amdgpu
  # and mt7925_common). The producer is in {amdgpu, mt7925_common} or
  # something one of them pulls in.
  # Round 6: half-bisect — re-enable amdgpu, keep mt7925_common (and the
  # other young drivers) blacklisted. If still clean → mt7925_common was
  # the trigger. If it crashes → amdgpu was the trigger.
  # Watchdog-panic params stay on so any stall produces a multi-CPU
  # pstore dump naming the lock holder.
  boot.kernelParams = [
    "consoleblank=0"
    "slub_debug=FZP"
    "slab_nomerge"
    "panic_on_warn=1"
    "softlockup_panic=1"
    "panic_on_rcu_stall=1"
    "rcu_cpu_stall_timeout=15"
    "module_blacklist=mt7925e,mt7925_common,amdxdna,amd_isp4,pinctrl_amdisp,i2c_designware_amdisp,amd_pmf"
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
