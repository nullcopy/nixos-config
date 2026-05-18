#!/usr/bin/env bash
set -euo pipefail

### CONFIG ###
DISK=/dev/nvme0n1
FLAKE_REPO="https://github.com/nullcopy/nixos-config"
HOSTNAME="myNewNixosComputer" # must match nixosConfigurations.<name> in your flake
ADMINUSER="myAdminUser"       # wheel-group user to administer the system
##############

[[ $EUID -eq 0 ]] || {
  echo "Run as root."
  exit 1
}
[[ -b "$DISK" ]] || {
  echo "Disk not found: $DISK"
  exit 1
}

echo "!!! This will completely erase $DISK. Type 'yes' to continue:"
read -r confirm
[[ "$confirm" == "yes" ]] || {
  echo "Aborted."
  exit 1
}

# Derive partition suffix: NVMe/eMMC use 'p' separator, SATA/USB do not
if [[ "$DISK" =~ nvme|mmcblk ]]; then
  PART="${DISK}p"
else
  PART="${DISK}"
fi
BOOT="${PART}1"
ROOT="${PART}2"

# Partition
wipefs -a "$DISK"
sgdisk --zap-all "$DISK"
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:ESP "$DISK"
sgdisk -n 2:0:0 -t 2:8300 -c 2:root "$DISK"
udevadm settle

# Encrypt
echo "Creating encrypted partition..."
cryptsetup luksFormat --type luks2 --pbkdf argon2id "$ROOT"
echo "Unlocking encrypted partition..."
cryptsetup open "$ROOT" cryptroot

# Format
mkfs.fat -F 32 -n BOOT "$BOOT"
mkfs.btrfs -L nixos /dev/mapper/cryptroot

# Subvolumes
mount /dev/mapper/cryptroot /mnt
for sv in @ @home @nix @log @snapshots; do
  btrfs subvolume create /mnt/$sv
done
umount /mnt

# Mount
OPTS="noatime,compress=zstd:3,space_cache=v2"
mount -o subvol=@,$OPTS /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{home,nix,var/log,.snapshots,boot}
mount -o subvol=@home,$OPTS /dev/mapper/cryptroot /mnt/home
mount -o subvol=@nix,$OPTS /dev/mapper/cryptroot /mnt/nix
mount -o subvol=@log,$OPTS /dev/mapper/cryptroot /mnt/var/log
mount -o subvol=@snapshots,$OPTS /dev/mapper/cryptroot /mnt/.snapshots
mount "$BOOT" /mnt/boot

# Clone flake and inject hardware config
nix-shell -p git --run "git clone '$FLAKE_REPO' /mnt/etc/nixos"
mkdir -p "/mnt/etc/nixos/hosts/$HOSTNAME"
nixos-generate-config --root /mnt --show-hardware-config \
  >"/mnt/etc/nixos/hosts/$HOSTNAME/hardware-configuration.nix"

echo
echo ">>> hardware-configuration.nix generated at /mnt/etc/nixos/hosts/$HOSTNAME/"
echo ">>> Before continuing, make sure:"
echo ">>>   1. hosts/$HOSTNAME/configuration.nix imports ./hardware-configuration.nix"
echo ">>>   2. flake.nix includes a nixosConfiguration for '$HOSTNAME'"
echo ">>> Opening a shell in /mnt/etc/nixos to make any edits. Type 'exit' when done."
echo ">>> Press ENTER to open the shell."
read -r
pushd /mnt/etc/nixos >/dev/null
${SHELL:-bash}
popd >/dev/null

# Install from local flake (path: URI bypasses the git-clean check)
nixos-install --flake "path:/mnt/etc/nixos#$HOSTNAME" --no-root-password

echo ">>> Setting password for '$ADMINUSER':"
nixos-enter --root /mnt -- passwd "$ADMINUSER"

umount -R /mnt
cryptsetup close cryptroot

echo
echo ">>> NOTE:"
echo ">>> If you defined multiple users, $ADMINUSER will need to login first and"
echo ">>> assign their passwords with 'passwd <user>', before they can login."
echo ">>>"
echo ">>> Install complete. Remove the installation media and reboot."
