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

  # Crash triage — latest: help-sessions/help-session-2026-04-30T033617Z/.
  #
  # Round 9 (Test A+B held, third signature → jump to Test D):
  #  - Test A (D0 pin on MT7925) and Test B (pcie_aspm=off) both took
  #    effect: power/control = on, pcie_aspm=off in cmdline. System
  #    still crashed at uptime 1049s (~17.5 min — about 3× longer
  #    survival than rounds 7/8).
  #  - The new oops is a third distinct signature: GPF on a smashed
  #    objcg pointer (R12 = 0x0e579b4e60ca7d41) inside refill_obj_stock,
  #    triggered from kfree inside drm_atomic_state_default_clear, called
  #    from amdgpu's fbdev damage worker drm_fb_helper_damage_work.
  #  - The detector path is amdgpu's fbdev console-refresh worker. Round
  #    9 is consistent with the historical PASS/FAIL table where
  #    module_blacklist=amdgpu PASSes — the producer is somewhere in
  #    amdgpu's pull-in chain.
  #
  # Test D (this revision, per user direction — skipping the round-8
  # plan's Test C "pin amdgpu DPM to high"): keep A + B and add
  # module_blacklist=amd_pmf to narrow the producer. amdgpu stays
  # loaded so the display still works; only the AMD Platform
  # Management Framework (drivers/platform/x86/amd/pmf/) is removed.
  # Soak in TTY ≥30 min (≥60 min preferred since round 9 was 1049s).
  # Outcomes:
  #   - clean → strong evidence amd_pmf is in the producer chain.
  #     File upstream against drivers/platform/x86/amd/pmf/. Optionally
  #     peel A and/or B to see which layers are still required.
  #   - crashes → amd_pmf alone isn't the producer. Round 11 candidates,
  #     cheapest first:
  #       (a) Test C from round 8 (pin amdgpu DPM to high via tmpfiles
  #           on /sys/class/drm/card1/device/power_dpm_force_performance_level)
  #       (b) module_blacklist=amdgpu (historical PASS — loses display
  #           but matches ground-truth evidence)
  #       (c) module_blacklist=mt7925e,mt7925_common (round-6/7 fallback,
  #           loses WiFi+BT, ethernet via dock)
  #
  # Watchdog-panic + slub_debug params stay on as a safety net through
  # the test cycle. They caught rounds 7/8/9; peeling is later, after a
  # clean week.
  #
  # Historical PASS/FAIL table (round-7 TTY soaks, all without D0 pin /
  # without pcie_aspm=off):
  #   module_blacklist=pinctrl_amdisp,i2c_designware_amdisp,amd_pmf,amdgpu  PASS
  #   module_blacklist=pinctrl_amdisp,i2c_designware_amdisp,amdgpu          PASS
  #   module_blacklist=pinctrl_amdisp,i2c_designware_amdisp                 FAIL
  #   module_blacklist=amdgpu                                               PASS
  #   module_blacklist=                                                     FAIL  ← round-7 dump
  # Round 8 (A: D0 pin alone):                                              FAIL  ← round-8 dump (kmalloc-2k redzone)
  # Round 9 (A + B: D0 pin + pcie_aspm=off):                                FAIL  ← round-9 dump (objcg ptr GPF in fbdev)
  boot.kernelParams = [
    "consoleblank=0"
    "slub_debug=FZP"
    "slab_nomerge"
    "panic_on_warn=1"
    "softlockup_panic=1"
    "panic_on_rcu_stall=1"
    "rcu_cpu_stall_timeout=15"
    "pcie_aspm=off"
    "module_blacklist=amd_pmf"
  ];

  # Test A (kept from round 7): pin the WiFi PCIe device
  # (MT7925 @ 0000:c1:00.0) to D0 so mt792x_pm_wake_work — the path
  # that crashed at uptime 312s in round 7 — never runs. Holds across
  # rounds 8 and 9 because each subsequent round had a different
  # signature (reverting A would re-expose the round-7 wake-path crash).
  # tmpfiles writes the value at boot; the udev rule reapplies it if
  # the device re-enumerates (e.g. after a PCI rescan).
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
