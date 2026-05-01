# Full-disk encryption via stage-1 systemd + FIDO2.
# EFI:  /dev/nvme0n1p1
# LUKS: /dev/nvme0n1p2
#
# Enroll a token into its own LUKS2 keyslot (any FIDO2 device — YubiKey 5,
# SoloKey, Token2, etc.) with:
#   sudo systemd-cryptenroll \
#     --fido2-with-client-pin=yes \
#     --fido2-device=auto \
#     /dev/nvme0n1p2
{ ... }:
{
  boot.initrd.systemd.enable = true;
  boot.initrd.luks.devices."nixos-enc" = {
    device = "/dev/nvme0n1p2";
    crypttabExtraOpts = [ "fido2-device=auto" ];
  };
}
