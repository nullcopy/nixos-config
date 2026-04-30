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

  # Crash triage — latest: help-sessions/help-session-2026-04-30T044523Z/.
  #
  # Round 10 (Test A+B+D held, fourth signature → layer Test C):
  #  - Tests A (D0 pin on MT7925), B (pcie_aspm=off), and D
  #    (module_blacklist=amd_pmf) all took effect: power/control = on,
  #    pcie_aspm=off and module_blacklist=amd_pmf in cmdline, amd_pmf
  #    absent from lsmod. System still crashed at uptime 1257s
  #    (~21 min — slightly longer than round 9's 1049s).
  #  - The new oops is a fourth distinct signature: SLUB poison-violation
  #    panic (object_err at mm/slub.c:1227) on a freed kmalloc-4k object
  #    at base ffff8b0d3eaf1000. 16 bytes of pointer-shaped data
  #    overwrote the freed-object body 64B from the end. Detected by an
  #    innocent userspace access(2) → kernfs_iop_get_link allocation;
  #    producer not visible in the captured trace.
  #  - Test D falsified: amd_pmf is not the (sole) producer.
  #
  # Test C (this revision — the round-8 plan that round 9 skipped):
  # keep A + B + D and pin amdgpu's DPM (Dynamic Power Management) to
  # the highest P-state via tmpfiles on
  # /sys/class/drm/card1/device/power_dpm_force_performance_level.
  # This suppresses GPU clock/voltage transitions to test whether DPM
  # state-transition logic (SMU mailbox traffic, sensor readback,
  # thermal callbacks) is part of the producer chain.
  # Soak in TTY ≥30 min (≥60 min preferred since round 10 was 1257s).
  # Outcomes:
  #   - clean → strong evidence GPU DPM transitions are part of the
  #     producer chain. Start drafting upstream report against
  #     drivers/gpu/drm/amd/ (mailing list: amd-gfx@lists.freedesktop.org).
  #     Optionally peel A/B/D to see which layers are still required.
  #   - crashes → DPM transitions aren't the trigger. Round 12 candidates,
  #     cheapest first:
  #       (a) module_blacklist=amd_pmc (S2idle / s0ix accounting driver,
  #           separate from amd_pmf — cheap, no functional regression)
  #       (b) module_blacklist=amdgpu (historical PASS — loses display
  #           but confirms producer is in amdgpu's pull-in chain with
  #           current kernel/firmware/safety params)
  #       (c) module_blacklist=mt7925e,mt7925_common (round-6/7 fallback,
  #           loses WiFi+BT, ethernet via dock)
  #
  # Watchdog-panic + slub_debug params stay on as a safety net through
  # the test cycle. They caught rounds 7-10; peeling is later, after a
  # clean week.
  #
  # Historical PASS/FAIL table (round-7 TTY soaks, all without D0 pin /
  # without pcie_aspm=off):
  #   module_blacklist=pinctrl_amdisp,i2c_designware_amdisp,amd_pmf,amdgpu  PASS
  #   module_blacklist=pinctrl_amdisp,i2c_designware_amdisp,amdgpu          PASS
  #   module_blacklist=pinctrl_amdisp,i2c_designware_amdisp                 FAIL
  #   module_blacklist=amdgpu                                               PASS
  #   module_blacklist=                                                     FAIL  ← round-7 dump
  # Round 8  (A: D0 pin alone):                                             FAIL  ← round-8 dump (kmalloc-2k redzone)
  # Round 9  (A + B: D0 pin + pcie_aspm=off):                               FAIL  ← round-9 dump (objcg ptr GPF in fbdev)
  # Round 10 (A + B + D: + module_blacklist=amd_pmf):                       FAIL  ← round-10 dump (kmalloc-4k UAF write)
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
  # rounds 8/9/10 because each subsequent round had a different
  # signature (reverting A would re-expose the round-7 wake-path crash).
  #
  # Test C (added round 11): pin amdgpu's DPM to "high" so the GPU
  # stays at its highest P-state and never transitions. Verify card
  # number with `ls /sys/class/drm` post-boot — round-7 hardware notes
  # have amdgpu on minor 1 (fb0 primary). tmpfiles silently no-ops if
  # the path is wrong, so check the value post-rebuild before declaring
  # the rule effective.
  #
  # tmpfiles writes the values at boot; the udev rule reapplies the D0
  # pin if the WiFi device re-enumerates (e.g. after a PCI rescan).
  systemd.tmpfiles.rules = [
    "w /sys/bus/pci/devices/0000:c1:00.0/power/control - - - - on"
    "w /sys/class/drm/card1/device/power_dpm_force_performance_level - - - - high"
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
