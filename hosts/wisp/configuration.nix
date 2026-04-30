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

  # Crash triage — latest: help-sessions/help-session-2026-04-30T025055Z/.
  #
  # Round 8 (Test A held, signature changed → layer Test B):
  #  - Test A (D0 pin on the MT7925 PCIe device, applied round 7) took
  #    effect: power/control = on, no module_blacklist, all safety
  #    params live. System still crashed at uptime 338s (≈6s longer
  #    than the round-7 312s reference).
  #  - The new oops is **not** the mt76 page_pool / wake-handler crash.
  #    It's slub_debug=FZP catching an 8-byte right-redzone overwrite
  #    on a freed kmalloc-2k object. Detected by an unrelated VFS
  #    allocation in nd_alloc_stack from .quickshell-wra doing
  #    newfstatat — quickshell is the detector, not the producer.
  #  - Conclusion: D0 pin suppressed *one* failure path (the wake
  #    handler), but a steady-state corruption is still happening from
  #    a different producer / different code path. Don't revert A —
  #    layer B on top.
  #
  # Test B (this revision): keep the D0 pin AND add pcie_aspm=off to
  # rule out PCIe L0s/L1 link-state transitions as the couplant for
  # whatever DMA / memcpy is overrunning a 2K allocation. Soak in TTY
  # ≥30 min.
  # Outcomes:
  #   - clean → live mitigation = D0 pin + pcie_aspm=off. Round 9 then
  #     tries peeling the D0 pin alone to see whether ASPM-off is
  #     sufficient.
  #   - crashes → keep A+B, layer Test C (pin amdgpu DPM to high via a
  #     second tmpfiles rule on
  #     /sys/class/drm/card1/device/power_dpm_force_performance_level).
  #   - all of A+B+C fail → fall back to round-6 plan
  #     (module_blacklist=mt7925e,mt7925_common). WiFi+BT off; ethernet
  #     via dock. We'd still file upstream against mt76 with the
  #     full pstore evidence pack.
  #
  # Watchdog-panic + slub_debug params stay on as a safety net through
  # the test cycle. They caught both the round-7 and round-8 oopses;
  # peeling is later, after a clean week.
  #
  # Historical PASS/FAIL table (round-7 TTY soaks, all without D0 pin /
  # without pcie_aspm=off):
  #   module_blacklist=pinctrl_amdisp,i2c_designware_amdisp,amd_pmf,amdgpu  PASS
  #   module_blacklist=pinctrl_amdisp,i2c_designware_amdisp,amdgpu          PASS
  #   module_blacklist=pinctrl_amdisp,i2c_designware_amdisp                 FAIL
  #   module_blacklist=amdgpu                                               PASS
  #   module_blacklist=                                                     FAIL  ← round-7 dump
  # Round 8 (D0 pin + no module_blacklist):                                 FAIL  ← round-8 dump (different signature)
  boot.kernelParams = [
    "consoleblank=0"
    "slub_debug=FZP"
    "slab_nomerge"
    "panic_on_warn=1"
    "softlockup_panic=1"
    "panic_on_rcu_stall=1"
    "rcu_cpu_stall_timeout=15"
    "pcie_aspm=off"
  ];

  # Test A (kept from round 7): pin the WiFi PCIe device
  # (MT7925 @ 0000:c1:00.0) to D0 so mt792x_pm_wake_work — the path
  # that crashed at uptime 312s in round 7 — never runs. Holds across
  # round 8 because the round-8 signature is different (and reverting
  # this would re-expose the round-7 wake-path crash). tmpfiles writes
  # the value at boot; the udev rule reapplies it if the device
  # re-enumerates (e.g. after a PCI rescan).
  systemd.tmpfiles.rules = [
    "w /sys/bus/pci/devices/0000:c1:00.0/power/control - - - - on"
  ];
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:c1:00.0", ATTR{power/control}="on"
  '';

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
