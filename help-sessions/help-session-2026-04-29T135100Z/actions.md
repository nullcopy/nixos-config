# actions — wisp crash triage, round 3

## Done this session (2026-04-29)

- Captured the round-3 panic into `oops-2026-04-29T1430Z.txt`. Same
  16-byte structured-write fingerprint as round 2, different cache
  (`anon_vma_chain` vs. `skbuff_small_head`). Confirms the bug is a
  generic kernel UAF; cache identity is downstream of timing.
- Ruled out `mt7925e`. Boot dmesg shows `Module mt7925e is blacklisted`
  at t+21s; module did not load during the soak. System still
  crashed at t+294s.
- Updated `boot.kernelParams` in `hosts/wisp/configuration.nix` —
  swapped the single-module blacklist for a shotgun-off of all
  Strix-Halo-young drivers:
  `module_blacklist=mt7925e,amdxdna,amd_isp4,pinctrl_amdisp,i2c_designware_amdisp,amd_pmf`.
  Updated the comment block above kernelParams to reflect the new
  diagnosis (generic UAF, not skbuff-specific) and the new strategy
  (one shotgun round vs. several serial rounds).
- amdgpu intentionally left enabled (mature, disabling it confounds
  the display path; will be its own round if needed).

## What the user needs to do before the next chat

1. Rebuild and reboot:
   ```
   sudo nixos-rebuild switch --flake .#wisp
   sudo reboot
   ```
2. Confirm the shotgun took:
   ```
   lsmod | grep -E '^(mt7925e|amdxdna|amd_isp4|pinctrl_amdisp|i2c_designware_amdisp|amd_pmf)'
   ```
   Expect: empty output. If anything's still loaded, say so — the
   blacklist didn't fully take and the test is invalid.
3. WiFi will be off again (mt7925e blacklisted). Plan offline use,
   or plug into ethernet via the USB-C dock if you have it.
4. Drop to TTY (Ctrl+Alt+F3), log in, soak ≥30 min, normal usage
   like round 2.
5. Outcomes:
   - **Clean ≥30 min** → producer is one of the six. Next round
     will half-bisect: keep half blacklisted, watch for crash.
   - **Crashes again** → not a driver in the shotgun set. Pivot
     to BIOS update via LVFS:
     ```
     nix shell nixpkgs#fwupd -c sudo fwupdmgr refresh
     nix shell nixpkgs#fwupd -c sudo fwupdmgr get-updates
     nix shell nixpkgs#fwupd -c sudo fwupdmgr update
     ```
     Then memtest86+ if BIOS update doesn't fix it. (memtest86+ is
     bootable from `pkgs.memtest86plus` or via a USB stick — we'll
     figure out logistics next chat.)
6. **Either way**, paste:
   ```
   sudo ls -lat /var/lib/systemd/pstore/ | head -10
   ```
   Plus the contents of any new `dmesg.txt` (or note "no new
   pstore entries" if it stayed clean).
7. Re-enable WiFi after the test if you need it to chat — same
   thing you did last round. Just mention you did so when you
   share `lsmod` output, otherwise it looks like the blacklist
   failed.

## Pending — carried over

Ordered by ROI assuming the shotgun comes back clean:

- Half-bisect inside the shotgun set. Best split:
  - Group A: `amdxdna` + `mt7925e` (both standalone, easy to disable)
  - Group B: `amd_isp4 pinctrl_amdisp i2c_designware_amdisp amd_pmf`
    (ISP trio + power-management framework — these tend to load
    together)
  Disable Group A only, soak, see which group still crashes.
- BIOS update via LVFS (regardless of round 4 outcome — it's a
  good idea on brand-new silicon and will be needed if shotgun
  comes back dirty).
- Bracket with alternate kernel (`pkgs.linuxPackages_cachyos` or
  `pkgs.linuxPackages_xanmod_latest`) once the bisect axis is
  resolved.
- Stretch: KASAN kernel build to catch the producing write
  directly. Reserve for after shotgun + BIOS + memtest are
  exhausted.

## Carried-forward clue

The 16-byte pointer-shaped writes from each round may match a
specific struct field offset once we identify the producer. Round
2 wrote `0x1a8d08fa_a9230d68 0xf65e91b6_fe99cf9d` at offset 1728
of `skbuff_small_head`. Round 3 wrote
`0xd6065ebc_851f37d2 0x503b9c35_f43b9c35` (approx — verify byte
order against `oops-2026-04-29T1430Z.txt`) at offset 48 of
`anon_vma_chain`. If we ever get a producer name, matching these
bits to a struct member nails the bug.
