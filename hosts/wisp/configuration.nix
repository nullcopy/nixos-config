{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./luks.nix
    ./ollama.nix
    ../../common/desktop.nix
  ];

  ## ----- boot ----------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "uvcvideo" ]; # USB webcam

  ## ----- hardware ------------------------------------------------------------
  hardware.graphics.enable = true;

  ## ----- network -------------------------------------------------------------
  networking.hostName = "wisp";

  ## ----- system --------------------------------------------------------------
  # HP publishes G1a BIOS updates through LVFS. Check/apply with:
  #   fwupdmgr refresh && fwupdmgr get-updates && fwupdmgr update
  services.fwupd.enable = true;

  # CoolerControl is a hwmon dashboard/controller that can help if the
  # kernel/fimrware exposes fan control
  programs.coolercontrol.enable = true;

  # `sensors` for better temperature reading
  environment.systemPackages = [ pkgs.lm_sensors ];

  # Keystone ForgeBox (pid.codes VID). Without this, /dev/bus/usb nodes are
  # root-only and forgebox-cli can't open the device; uaccess has logind
  # grant an ACL to the physically logged-in user. Re-plug after a rebuild.
  #
  # Must ship as a rules file sorting before systemd's 73-seat-late.rules
  # (which is what acts on the uaccess tag), so extraRules (=> 99-local.rules)
  # can't be used here.
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "forgebox-udev-rules";
      destination = "/lib/udev/rules.d/70-forgebox.rules";
      text = ''
        SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="3001", MODE="0660", TAG+="uaccess"
      '';
    })
  ];

  ## ----- users ---------------------------------------------------------------
  programs.zsh.enable = true; # system-level so zsh is in /etc/shells

  users.users.nullcopy = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "video"
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
