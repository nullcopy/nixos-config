# nixos-config

Personal NixOS flake. Host configs + home-manager, keyed by machine name.

## Layout

```
flake.nix              # inputs + nixosConfigurations + devShells
common/                # every *.nix here is auto-applied to all hosts
  configuration.nix    # base system (nix, locale, net, audio, base pkgs)
  desktop.nix          # niri + greetd + xdg portals
modules/               # opt-in modules a host imports explicitly
  net-disable.nix      # custom.restrictInternet: block users' outbound traffic
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
  eregion/             # multi-user desktop
    configuration.nix  # nullcopy + vbug/zed; vbug/zed are internet-restricted
    hardware-configuration.nix
users/
  shared/              # home-manager modules users import
    base.nix           # desktop-agnostic baseline: zsh + starship + CLI tools
    desktops/          # one self-contained module per desktop — a user picks one
      niri-noctalia/   # the niri + Noctalia desktop
        default.nix    # niri + noctalia-shell + alacritty + browser
        niri.nix       # niri keybindings wired to Noctalia IPC
  nullcopy/
    configuration.nix  # imports base + niri-noctalia + the files below
    aliases.nix        # zsh + oh-my-zsh-style git aliases
    neovim.nix         # nixvim config (AstroNvim-flavoured UX)
    opencode.nix       # opencode pointed at the local ollama service
    tailscale.nix      # per-user `tailscale up` service
    noctalia/          # tracked noctalia-shell config (see "Noctalia")
  vbug/
    configuration.nix  # imports base + niri-noctalia + own apps + git identity
    noctalia/          # per-user noctalia config (seeded from nullcopy's)
  zed/
    configuration.nix  # imports base + niri-noctalia + own apps + git identity
    noctalia/          # per-user noctalia config (seeded from nullcopy's)
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

1. `mkdir users/<name>` and create `configuration.nix` — this is a home-manager module. Import the shell baseline plus one desktop, then add your own packages:
   ```nix
   { pkgs, ... }:
   {
     imports = [
       ../shared/base.nix              # zsh/starship/CLI baseline
       ../shared/desktops/niri-noctalia # pick a desktop (see "Desktops")
     ];
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

## Desktops

A user's desktop is one module imported from `users/shared/desktops/`. Today there's only `niri-noctalia/`, but the split is deliberate: `users/shared/base.nix` (zsh/starship/CLI) is desktop-agnostic and every user imports it, while the desktop module carries everything tied to a compositor (niri config, the Noctalia shell, terminal, browser, default apps). To give a user a different desktop, add a sibling directory (e.g. `users/shared/desktops/kde/`) and have that user import it instead of `niri-noctalia` — nothing else in their config changes.

> System side: `common/desktop.nix` currently enables niri + greetd for every host, and greetd launches `niri-session` directly. A non-niri desktop would also need that system-level session wired up; the home-manager split above is only half the story.

## Noctalia config

The niri-noctalia desktop module points each user's `~/.config/noctalia` at `/etc/nixos/users/<name>/noctalia` with an out-of-store symlink (`mkOutOfStoreSymlink`, target derived from the username), so settings saved through the Noctalia UI land directly in the repo as unstaged edits. This assumes the flake lives at `/etc/nixos` (where the install script clones it). The whole directory is symlinked, not individual files, because Noctalia saves via atomic write-and-rename.

Each user has their own tracked config under `users/<name>/noctalia/`. `vbug` and `zed` are seeded from a copy of nullcopy's `settings.json` with his personal bits stripped (avatar, wallpaper directory, location, the laptop-only widget, the custom plugin); Noctalia rewrites the file in place as they tweak it.

## Notes

- `system.stateVersion` and `home.stateVersion` track the initial install — do not bump them on existing machines.
- To block a user's outbound traffic, import `modules/net-disable.nix` in the host and set `custom.restrictInternet = [ "user" … ];`. It drops non-loopback traffic owned by those users via iptables/ip6tables owner rules (see `eregion` for an example).
