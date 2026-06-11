# nixos-config

Personal NixOS flake for multiple hosts and multiple users. Desktops are
configured per user; hosts can be graphical or headless.

## Layout

```
flake.nix                # inputs + mkHost helper + one mkHost call per machine
modules/                 # system-side building blocks (NixOS modules)
  core.nix               # baseline every host gets — strictly headless-safe
  audio.nix              # pipewire + rtkit
  bluetooth.nix
  networkmanager.nix
  power.nix              # power-profiles-daemon + upower (laptops)
  greeters/
    tuigreet.nix         # greetd + tuigreet session chooser (one greeter per host)
hosts/
  wisp/                  # per-machine module
    configuration.nix    # hardware + host services + role-module imports
    hardware-configuration.nix
    luks.nix             # stage-1 systemd + FIDO2 LUKS unlock
    ollama.nix           # ROCm ollama + GTT tuning for Strix Halo iGPU
users/
  nullcopy/
    system.nix           # the account (users.users.nullcopy), host-independent
    home.nix             # portable CLI home: shell, editor, git identity —
                         #   must work unchanged on a headless host
    desktop.nix          # this user's desktop, system half: niri, portals,
                         #   screenshot tools; skipped on headless hosts
    desktop-home.nix     # desktop, home half: noctalia, alacritty, brave,
                         #   mimeapps, GUI apps (wired in by desktop.nix)
    niri.nix             # niri keybindings wired to Noctalia IPC
    aliases.nix          # zsh + oh-my-zsh-style git aliases
    neovim.nix           # nixvim config (AstroNvim-flavoured UX)
    opencode.nix         # opencode pointed at the local ollama service
    tailscale.nix        # per-user `tailscale up` service
    noctalia-settings.toml # tracked noctalia UI settings (see "Noctalia")
devShells/               # one shell per language (see "devShells")
```

Inputs: `nixpkgs` (unstable), `home-manager`, `noctalia`, `nixvim`, `fenix`.

## How a machine is assembled

`mkHost` in `flake.nix` wires three layers together:

| Layer | Owns | Files |
|---|---|---|
| core | what *every* machine gets | `modules/core.nix` |
| host | hardware, host services, role modules (audio, NM, …) and **the greeter** | `hosts/<name>/` |
| user | account, CLI home, and (on graphical hosts) their desktop | `users/<name>/` |

```nix
wisp = mkHost {
  hostname = "wisp";
  users = [ "nullcopy" ];
};
```

For each listed user, mkHost imports `users/<name>/system.nix`, wires
`users/<name>/home.nix` into home-manager, and — only when `graphical = true`
(the default) and the file exists — imports `users/<name>/desktop.nix`.

**Desktops are a user choice; greeters are a host choice.** A desktop is
defined entirely inside the user's own directory: `desktop.nix` (system half —
compositor, portals, companion tools) and `desktop-home.nix` + `niri.nix`
(home half — shell UI, terminal, keybinds). To reuse an existing desktop,
copy those files into another `users/<name>/` and edit the username in
`desktop.nix`. Several users running copies of the same desktop on one host
merge cleanly, since identical system options deduplicate.
The greeter owns the seat — a machine can only run one — so graphical hosts
import exactly one module from `modules/greeters/`. tuigreet is configured as
a desktop-agnostic session chooser: every compositor enabled by any user's
desktop installs a session file under
`/run/current-system/sw/share/wayland-sessions`, tuigreet lists them all and
remembers each user's last choice. Adding a new WM never touches the greeter.

### Adding a new host

1. `mkdir hosts/<name>` with a `configuration.nix` (use `hosts/wisp/` as a
   template) importing `./hardware-configuration.nix` plus whichever role
   modules the machine needs (`modules/audio.nix`, `modules/networkmanager.nix`,
   `modules/greeters/tuigreet.nix`, …). Set `system.stateVersion` to the
   current release and never change it.
2. Add one block to `flake.nix`:
   ```nix
   <name> = mkHost {
     hostname = "<name>";
     users = [ "alice" "bob" ];
   };
   ```

For a **headless server**, import no greeter / audio / etc. in the host config
and set `graphical = false` in the mkHost call — users keep their full CLI
homes but every `desktop.nix` is skipped, so nothing graphical enters the
closure.

### Adding a new user

1. `mkdir users/<name>` with two files (plus an optional desktop):
   - `system.nix` — the account:
     ```nix
     { config, lib, pkgs, ... }:
     {
       users.users.<name> = {
         isNormalUser = true;
         extraGroups = [ "audio" "video" ];
       };
     }
     ```
   - `home.nix` — a home-manager module. Start small, keep it headless-safe:
     ```nix
     { config, lib, pkgs, inputs, ... }:
     {
       home.packages = with pkgs; [ ];
       home.stateVersion = "25.11";
     }
     ```
   - `desktop.nix` (optional) — the user's desktop, only ever evaluated on
     graphical hosts. To run the same desktop as an existing user, copy their
     `desktop.nix`, `desktop-home.nix` and `niri.nix`, then change the
     username in `desktop.nix`'s `home-manager.users.<name>` line. (Also copy
     or create `noctalia-settings.toml` — empty is fine.) For a different
     desktop, write your own: anything system-side (compositor, portals) in
     `desktop.nix`, anything home-manager-side in `desktop-home.nix`.
2. Add the user to the `users` list of each host they belong on.
3. After the first rebuild, an admin sets their password with `passwd <name>`.

The host's greeter picks up new desktop sessions automatically. If a desktop
needs a *different* greeter (e.g. SDDM), add a module under
`modules/greeters/` and swap the host's import — it's one greeter per machine,
shared by all of its users.

## Where the repo lives

Rebuilds run as root (`sudo nixos-rebuild …`), so the checkout can live in the
admin's home directory; it does not need to be world-readable. At build time
the flake is snapshotted into the world-readable nix store wherever the
checkout lives, which is why secrets (e.g. the tailscale env file) stay
outside the repo. The one runtime reference to the checkout is per-user: the
Noctalia settings symlink points at
`~/.nixos-config/users/<username>/noctalia-settings.toml` in each user's own
home, so only users who track their UI settings need a checkout.

## First-time setup on a new machine

Machine configs are organized by host name, so pick a `<name>` (e.g. `wisp`) and follow the steps below.

### Install NixOS and configure the system with this flake.

`scripts/nixos-install.sh` automates the full installation. Before running it, edit the four variables at the top of the script:

```bash
DISK=/dev/nvme0n1               # target disk — double-check with lsblk
FLAKE_REPO="https://github.com/nullcopy/nixos-config"
HOSTNAME="myNewNixosComputer"   # must match nixosConfigurations.<name> in flake.nix
ADMINUSER="myAdminUser"         # wheel-group user defined in users/<name>/system.nix
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
3. Drop you into an interactive shell so you can make any necessary edits — at minimum,
   follow "Adding a new host" above (and "Adding a new user" if the machine gets new users).
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

This config tracks **Noctalia v5** (a compiled Wayland shell; v4 was a QML/quickshell wrapper). The user's desktop config (`users/<name>/desktop-home.nix`) enables it with `programs.noctalia`, and `users/<name>/niri.nix` drives every panel/OSD through the v5 `noctalia msg <command>` IPC (run `noctalia msg --help` for the full list).

v5 splits its writable files across two XDG dirs, and the settings UI writes to the **state** dir, not the config dir:

- `~/.config/noctalia/config.toml` — the base config layer. The settings UI never writes it; it's left at noctalia's built-in defaults. Pin a base value declaratively with `programs.noctalia.settings.<…>` in `desktop-home.nix` and the module renders a read-only `config.toml`. (Custom palettes saved in the UI also land in `~/.config/noctalia/palettes/`, writeable but untracked.)
- `~/.local/state/noctalia/settings.toml` — **everything you change in the settings UI**, layered on top of `config.toml`. This is the only writeable file we track: `users/<username>/noctalia-settings.toml` is mirrored to it via a single-file `mkOutOfStoreSymlink` (the username is derived, so each user tracks their own copy in their own checkout), and in-UI changes write straight back into the flake repo as unstaged edits — commit them to persist. The rest of the state dir (`state.toml`, caches, the `.setup-complete` marker) is runtime noise and stays untracked.

Noctalia's atomic writer is symlink-aware (it canonicalises the link and renames onto the real target), so the single-file `settings.toml` symlink survives every save.

## Notes

- `system.stateVersion` and `home.stateVersion` track the initial install — do not bump them on existing machines.
- tuigreet remembers each user's last session in `/var/cache/tuigreet` (created via tmpfiles): a user's first login asks for a session choice, and later logins preselect it.
