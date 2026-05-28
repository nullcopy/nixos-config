# nixos-config

Personal NixOS flake. Host configs + home-manager, keyed by machine name.

## Layout

```
flake.nix              # inputs + nixosConfigurations + devShells
common/
  configuration.nix    # base system (nix, locale, net, audio, base pkgs)
  desktop.nix          # niri + greetd + xdg portals
devShells/
  rust.nix             # fenix toolchain + bindgen deps (see "devShells")
  python.nix
  go.nix
  c.nix
  lua.nix
  nix.nix
  bash.nix
hosts/
  wisp/                # per-machine module
    configuration.nix  # imports hw + luks + ollama + desktop + user group
    hardware-configuration.nix
    luks.nix           # stage-1 systemd + FIDO2 LUKS unlock
    ollama.nix         # ROCm ollama + GTT tuning for Strix Halo iGPU
users/
  nullcopy/
    configuration.nix  # home-manager module (imports the files below)
    aliases.nix        # zsh + oh-my-zsh-style git aliases
    neovim.nix         # nixvim config (AstroNvim-flavoured UX)
    niri.nix           # niri keybindings wired to Noctalia IPC
    opencode.nix       # opencode pointed at the local ollama service
    tailscale.nix      # per-user `tailscale up` service
    noctalia/          # tracked noctalia-shell config (see "Noctalia")
```

Inputs: `nixpkgs` (unstable), `home-manager`, `noctalia`, `nixvim`, `fenix`.

## First-time setup on a new machine

Machine configs are organized by host name, so pick a `<name>` (e.g. `wisp`) and follow the steps below.

### Install NixOS and configure the system with this flake.

`scripts/nixos-install.sh` automates the full installation. Before running it, edit the four variables at the top of the script:

```bash
DISK=/dev/nvme0n1               # target disk — double-check with lsblk
FLAKE_REPO="https://github.com/nullcopy/nixos-config"
HOSTNAME="myNewNixosComputer"   # must match nixosConfigurations.<name> in flake.nix
ADMINUSER="myAdminUser"         # wheel-group user defined in your host config
```

Then, from the NixOS live environment, download it, edit the variables, and run it as root:

```bash
curl -O https://raw.githubusercontent.com/nullcopy/nixos-config/main/scripts/nixos-install.sh
vim nixos-install.sh   # set DISK, HOSTNAME, ADMINUSER
bash nixos-install.sh
```

The script will:
1. Partition and format the disk (GPT, EFI + LUKS2-encrypted btrfs root with subvolumes).
2. Clone this flake to `/mnt/etc/nixos` and generate `hardware-configuration.nix`.
3. Drop you into an interactive shell so you can make any necessary edits — at minimum:
   - Create `hosts/<name>/configuration.nix` (see [hosts/wisp/configuration.nix](hosts/wisp/configuration.nix) as a template) and make sure it imports `./hardware-configuration.nix`.
   - Add an entry for `<name>` under `nixosConfigurations` in `flake.nix` (mirroring the `wisp` block).
4. Run `nixos-install`, prompt for `ADMINUSER`'s password, then cleanly unmount everything.

If you defined additional users, `ADMINUSER` will need to log in first and assign their passwords with `passwd <username>`.

For FIDO2 LUKS unlock, enroll a token after the first boot with the `systemd-cryptenroll` command shown in the comment at the top of `hosts/wisp/luks.nix`.

### Enable the pre-commit hook

The repo ships a pre-commit hook that auto-formats `.nix` files with `nixfmt`. After cloning, point git at it:

```
git config core.hooksPath .githooks
```

You can also format the entire repo manually:

```
nix fmt
```

## Day to day

From anywhere inside the flake checkout:

```
sudo nixos-rebuild switch --flake
nix flake update            # bump all inputs
nix flake lock --update-input nixpkgs   # bump one input
```

## Adding a new user

1. `mkdir users/<name>` and create `configuration.nix` — this is a home-manager module. Start small:
   ```nix
   { config, lib, pkgs, inputs, ... }:
   {
     home.packages = with pkgs; [ ];
     home.stateVersion = "25.11";
   }
   ```
2. In the host module, declare the system user under `users.users.<name>`.
3. In `flake.nix`, add the home-manager wiring for the host:
   ```nix
   home-manager.users.<name> = import ./users/<name>/configuration.nix;
   ```

## devShells

One shell per language, covering the tooling used by the nixvim LSP config — a fallback for ad-hoc work in projects that don't ship their own flake. Real projects should still define their own `devShells.default` and load it via direnv (`echo 'use flake' > .envrc && direnv allow`).

There is no `default` shell; always pick one explicitly:

```
nix develop /path/to/flake#rust
nix develop /path/to/flake#python
nix develop /path/to/flake#go
nix develop /path/to/flake#c
nix develop /path/to/flake#lua
nix develop /path/to/flake#nix
nix develop /path/to/flake#bash
```

`#rust` includes `rustPlatform.bindgenHook`, which sets `LIBCLANG_PATH` and `BINDGEN_EXTRA_CLANG_ARGS` so bindgen-based crates (`librocksdb-sys`, `zcash_script`, `ring`, …) build without the user setting anything by hand.

To add another shell, drop a file like `./devShells/embedded-arm.nix` (a function taking `{ pkgs, system, fenix }` and returning a `pkgs.mkShell { … }`) and list it in `flake.nix`. Enter it with `nix develop /path/to/flake#embedded-arm`. The zsh re-exec is applied centrally by `mkDevShell` in `flake.nix`, so per-language files don't repeat it.

## Noctalia config

`users/nullcopy/noctalia/` is the tracked copy of `~/.config/noctalia/`. On first activation it is seeded into `$HOME` as writable files so the shell's UI can save changes. On every rebuild the activation script diffs the live dir against the flake copy and prints an `M` / `-` / `?` drift report with the exact `cp` / `rm` commands to reconcile. To ignore a runtime state file, add its basename to `noctaliaDriftExcludes` at the top of `users/nullcopy/configuration.nix`.

## Notes

- `system.stateVersion` and `home.stateVersion` track the initial install — do not bump them on existing machines.
