# actions — wisp crash triage, round 2

## Done this session (2026-04-29)

- Captured the post-`slub_debug=FZP` panic into
  `oops-2026-04-29T1030Z.txt`. Confirms write-after-free on
  `skbuff_small_head` (slab_nomerge unmasked the real cache name).
  Producer not visible from this oops; consumer was tailscaled →
  TUN → `__tcp_send_ack` → `__alloc_skb`. Crash happened *without*
  s2idle this time — falsifies the "s2idle-only trigger" theory.
- Added `module_blacklist=mt7925e` to `boot.kernelParams` in
  `hosts/wisp/configuration.nix` for round-1 driver bisect.
  WiFi 7 driver is the highest-probability producer.
- Updated the comment block on `boot.kernelParams` to reflect the
  new diagnosis (write-after-free, producer unknown, bisecting).

## What the user needs to do before the next chat

1. Rebuild and reboot:
   ```
   sudo nixos-rebuild switch --flake .#wisp
   sudo reboot
   ```
2. Confirm WiFi is actually disabled after reboot:
   ```
   lsmod | grep -E '^mt(7925|76)'   # expect: nothing or only mt76 core
   ip link                          # expect: no wlp* device
   dmesg | grep -i mt7925           # expect: no probe messages
   ```
   If `mt7925e` still loads, the blacklist didn't take — say so before
   running the soak test.
3. Plan for offline use during the test, **or** plug in ethernet via the
   USB-C dock (don't switch on a different WiFi driver). Tailscale
   without an underlying transport is fine — it'll just be down.
4. Drop to TTY (Ctrl+Alt+F3), log in, and use the system normally
   (cd around, edit files, whatever — keep the box busy, like the
   round-2 session). Soak for **≥30 min**, ideally an hour.
5. Outcomes:
   - **Clean ≥30 min in TTY**: very strong signal that `mt7925e` is
     the producer. Capture uptime, `journalctl --since boot -k -p warn`
     output, and any new pstore entries (there should be none). Next
     step is to file an upstream bug with the oops attached.
   - **Crashes again**: capture pstore the same way as last time (see
     `../help-session-2026-04-29T090255Z/actions.md`, step 5). The
     next bisect target is `amdxdna` — append it to `module_blacklist`
     and repeat.
6. **Either way**, paste the result of:
   ```
   sudo find /var/lib/systemd/pstore -newer \
     /etc/nixos-rebuild-marker -printf '%T+  %p\n' 2>/dev/null \
     | sort
   ```
   or just: `sudo ls -lat /var/lib/systemd/pstore/ | head -5` plus
   the contents of any new `dmesg.txt`.

   (`/etc/nixos-rebuild-marker` won't exist — the find will return
   nothing on a no-crash boot, which is the desired no-news signal.)

## Pending — carried over

Ordered by ROI assuming the bisect resolves it; do these in parallel
with the bisect if you have time:

- BIOS update via LVFS:
  ```
  nix shell nixpkgs#fwupd -c sudo fwupdmgr refresh
  nix shell nixpkgs#fwupd -c sudo fwupdmgr get-updates
  nix shell nixpkgs#fwupd -c sudo fwupdmgr update
  ```
- If `mt7925e` is innocent: bisect order is `amdxdna`, then
  `amd_isp4 pinctrl_amdisp i2c_designware_amdisp` (the ISP trio, all
  loaded together), then `amd_pmf`.
- Bracket with alternate kernel: `pkgs.linuxPackages_cachyos` or
  `pkgs.linuxPackages_xanmod_latest` to test whether 6.19.10 has
  a Strix-Halo regression specifically. Hold on this until the
  driver bisect either lands or exhausts.
- Stretch: build a KASAN kernel to catch the producing write
  directly, if the driver bisect doesn't isolate it.
