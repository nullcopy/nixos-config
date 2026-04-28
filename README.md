# nixos-config

Personal NixOS flake. Host configs + home-manager, keyed by machine name.

## Layout

```
flake.nix              # inputs + nixosConfigurations + devShells
common/
  configuration.nix    # base system (nix, locale, net, audio, base pkgs)
  desktop.nix          # niri + greetd + xdg portals
devShells/
  default.nix          # kitchen-sink dev shell (see "devShells")
hosts/
  wisp/                # per-machine module
    configuration.nix  # imports hw + desktop + ollama + user group
    hardware-configuration.nix
    yubikey-luks.nix   # Yubikey 2FA LUKS unlock
    ollama.nix         # ROCm ollama + GTT tuning for Strix Halo iGPU
users/
  nullcopy/
    configuration.nix  # home-manager module (imports the files below)
    aliases.nix        # zsh + oh-my-zsh-style git aliases
    neovim.nix         # nixvim config (AstroNvim-flavoured UX)
    tailscale.nix      # per-user `tailscale up` service
    noctalia/          # tracked noctalia-shell config (see "Noctalia")
```

Inputs: `nixpkgs` (unstable), `home-manager`, `noctalia`, `nixvim`, `fenix`.

## First-time setup on a new machine

Machine configs are organized by host name, so pick a <name> (e.g. wisp) and follow the steps below.

### Install NixOS and configure the system with this flake.

1. Boot the NixOS installer and partition/format as you like.
  * See [my guide](https://coldnoise.net/posts/2026/yubikey-full-disk-encryption-nixos) to use [ykluks-tools](https://github.com/nullcopy/ykluks-tools) to configure NixOS with Yubikey-based full-disk encryption.
1. Generate hardware config into a mounted target:
   ```
   nixos-generate-config --root /mnt
   ```
1. Clone this flake somewhere persistent (e.g. `~/.nixos-config`) and drop the generated `hardware-configuration.nix` into `hosts/<name>/`.
1. Inside the cloned flake: `mkdir hosts/<name>` and copy a generated `hardware-configuration.nix` into it.
1. Create `hosts/<name>/configuration.nix`.
  * See one of the existing host configs for a template, e.g. [hosts/wisp/configuration.nix](hosts/wisp/configuration.nix)
1. Add an entry for this host to `flake.nix` under `nixosConfigurations` (mirroring `wisp`)
1. Point `home-manager.users.<you>` at the user module you want on this host.
1. Install:
   ```
   nixos-install --flake /mnt/etc/nixos#<name>
   ```
1. Reboot, log in as root, set user password with `passwd`.

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

`devShells/default.nix` is a kitchen-sink shell covering every language used by the nixvim LSP config — a fallback for ad-hoc work in projects that don't ship their own flake. Real projects should define their own `devShells.default` and load it via direnv (`echo 'use flake' > .envrc && direnv allow`).

To add another shell, drop a file like `./devShells/embedded-arm.nix` (a function taking `{ pkgs, system, fenix }`) and list it in `flake.nix` alongside `default`. Enter named shells with `nix develop /path/to/flake#<name>`.

## Noctalia config

`users/nullcopy/noctalia/` is the tracked copy of `~/.config/noctalia/`. On first activation it is seeded into `$HOME` as writable files so the shell's UI can save changes. On every rebuild the activation script diffs the live dir against the flake copy and prints an `M` / `-` / `?` drift report with the exact `cp` / `rm` commands to reconcile. To ignore a runtime state file, add its basename to `noctaliaDriftExcludes` at the top of `users/nullcopy/configuration.nix`.

## Notes

- `hosts/wisp/yubikey-luks.nix` pins a nixpkgs fork with a `luksroot.nix` patch for Yubikey salt rotation. Unpin once the fix is upstream.
- `system.stateVersion` and `home.stateVersion` track the initial install — do not bump them on existing machines.
