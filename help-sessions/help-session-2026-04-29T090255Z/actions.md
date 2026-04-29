# actions — wisp crash triage

## Done this session (2026-04-29)

- Added `boot.kernelParams` to `hosts/wisp/configuration.nix` for diagnosis:
  - `consoleblank=0` — reduce TTY-mode s2idle entry rate (the suspected
    trigger for the corruption).
  - `slub_debug=FZP` — detect SLUB freelist corruption at the bad *write*,
    not the eventual read.
  - `slab_nomerge` — keep caches separate so the next oops names the actual
    corrupted cache rather than a merged alias.
  - `panic_on_warn=1` — first detected corruption becomes an immediate panic
    to pstore, with a clean stack of the producer.
- Captured the verbatim chat in `chat.log` and the running diagnosis in
  `crash-triage.md` (the findings doc for this session).

## What the user needs to do before the next chat

1. Rebuild and switch:
   ```
   sudo nixos-rebuild switch --flake .#wisp
   ```
2. Reboot.
3. Drop to a raw TTY (Ctrl+Alt+F3, log in, no DE).
4. Let it sit for **≥30 minutes**, ideally an hour. Don't touch it. Baseline
   says it should crash within 5–15 min if the trigger is unchanged; if it
   survives 30+ min in TTY, `consoleblank=0` is doing real work.
5. **If it crashes**: reboot, then capture pstore data the same way as last
   time. Quick path:
   ```
   sudo ls -1t /var/lib/systemd/pstore/ | head -5
   sudo find /var/lib/systemd/pstore -name dmesg.txt -newer \
     /home/nullcopy/Projects/nixos-config/main/help-sessions/help-session-2026-04-29T090255Z/actions.md
   ```
   Then `sudo cat` each new `dmesg.txt` and paste into the next chat. Thanks
   to `slub_debug=FZP` + `slab_nomerge`, the new oops should name the actual
   cache and (likely) the producer's stack.
6. **If it doesn't crash**: report uptime achieved, what you did during the
   session (idle? lid close? plugged in / on battery?), and pick the next
   test from the pending list below.

## Pending — not yet attempted, ordered by ROI

Carried over from the action plan in `crash-triage.md`:

- BIOS update via LVFS (`nix shell nixpkgs#fwupd -c fwupdmgr refresh &&
  fwupdmgr get-updates`).
- Driver bisect via `boot.blacklistedKernelModules`: try `amdxdna` first,
  then `amd_isp4`, then `amd_pmf`, then `mt7925e`.
- Alternate kernel: `pkgs.linuxPackages_cachyos` or
  `pkgs.linuxPackages_xanmod_latest` to bracket whether 6.19.10 has a
  Strix-Halo regression.
