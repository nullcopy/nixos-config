# Yubikey LUKS configuration
# EFI: /dev/nvme0n1p1
# LUKS: /dev/nvme0n1p2
{
  config,
  lib,
  pkgs,
  ...
}:
let
  myNixpkgs = builtins.fetchTarball {
    url = "https://github.com/nullcopy/nixpkgs/archive/fix/luksroot-salt-rotation.tar.gz";
    sha256 = "0503wqci562148s1p561fsy2gf7zwxynh5lzh6w0xd2iqdfx2jw9";
  };
in
{
  disabledModules = [ "system/boot/luksroot.nix" ];
  imports = [ "${myNixpkgs}/nixos/modules/system/boot/luksroot.nix" ];
  boot.initrd.systemd.enable = false; # stage 1 systemd doesn't support Yubikey LUKS
  boot.initrd.kernelModules = [
    "vfat"
    "nls_cp437"
    "nls_iso8859-1"
    "usbhid"
  ];
  boot.initrd.luks.yubikeySupport = true;
  boot.initrd.luks.devices."nixos-enc" = {
    device = "/dev/nvme0n1p2";
    preLVM = true;
    yubikey = {
      slot = 1;
      twoFactor = true;
      salt = "f2ddc98450b78c0e3cfef72df3bf544dbe50d5d6880ecdeec59098f7ba9a6ba6ae1fb2851b82f5ae740a66fe9e4a5d482b1f1190d2631b72d7008d659b6d1c212814a9acca138d22dd569b29b627f781c3ef90493f363d03dd55830680d1512d70af88dfed4334e6e314bd26259342e4be545322d3d7a830b2d8e32e74f61834fb897030f1110a6172b73c74093971729fddf4fd357f43e28616a854cab30a08fe05349d1113ebd7973f004cad2b92576f50d2a729950413f81157e379d6959636e30e677c7f7ec7568dba6a7f2368f3fb0a30760e7a7bda6d64b2c9a18e5d8c951e051da3c54116d8be91e54b8bee2b116dd5c749468286f7fac37f3b38c1fa";
      iterations = 12392155;
      keyLength = 64;
      gracePeriod = 30;
    };
  };
}
