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

  # Crash triage — see help-sessions/help-session-2026-04-30T022503Z/.
  #
  # Round 7 (refined). Producer/gating split:
  #  - Producer: mt76. pstore from the most recent crash (uptime 312s)
  #    shows panic_on_warn=1 tripping a page_pool pp_magic check inside
  #    mt76_dma_rx_cleanup, called from mt792x_pm_wake_work — the WiFi
  #    runtime-PM wake handler doing a DMA reset.
  #  - Gating condition: amdgpu loaded. amdgpu pulls in amd_pmf and
  #    smu_v14_0_0 and changes platform PM state on Strix Halo, which is
  #    what lets the WiFi chip enter MCU power-save and run the buggy
  #    wake path. With amdgpu off, the chip never sleeps deep enough,
  #    so the wake path doesn't fire and no WARN. TTY hits deeper idle
  #    than Wayland, which is why the bug only reproduces in TTY.
  #
  # Test A (this revision): pin the WiFi PCIe device to D0 so it never
  # enters runtime-PM sleep. Most surgical knob — no module blacklist,
  # no global ASPM change, amdgpu stays loaded. Soak in TTY ≥30 min.
  # If clean, this is the live mitigation and we file upstream against
  # mt76/mt7925.
  # If it still crashes, drop these rules and try Test B
  # (boot.kernelParams += "pcie_aspm=off"), then Test C (pin amdgpu DPM
  # to high), then the round-6 fallback (module_blacklist=mt7925e,mt7925_common).
  #
  # Watchdog-panic + slub_debug params stay on as a safety net through
  # the test cycle. They caught this oops; they need to keep catching
  # the next one if Test A doesn't hold.
  #
  # Historical PASS/FAIL table (TTY soaks, this round):
  #   module_blacklist=pinctrl_amdisp,i2c_designware_amdisp,amd_pmf,amdgpu  PASS
  #   module_blacklist=pinctrl_amdisp,i2c_designware_amdisp,amdgpu          PASS
  #   module_blacklist=pinctrl_amdisp,i2c_designware_amdisp                 FAIL
  #   module_blacklist=amdgpu                                               PASS
  #   module_blacklist=                                                     FAIL  ← dump captured here
  boot.kernelParams = [
    "consoleblank=0"
    "slub_debug=FZP"
    "slab_nomerge"
    "panic_on_warn=1"
    "softlockup_panic=1"
    "panic_on_rcu_stall=1"
    "rcu_cpu_stall_timeout=15"
  ];

  # Test A: keep the WiFi PCIe device (MT7925 @ 0000:c1:00.0) in D0 so
  # mt792x_pm_wake_work — the path that crashed at uptime 312s — never
  # runs. tmpfiles writes the value at boot; the udev rule reapplies it
  # if the device re-enumerates (e.g. after a PCI rescan).
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
