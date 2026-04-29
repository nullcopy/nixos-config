---
name: actions — wisp crash triage, round 6
description: What was changed in round 6, what the user needs to do before round 7
type: project
---

# actions — wisp crash triage, round 6

## Done this session (2026-04-29)

- Confirmed round-6 outcome: clean ≥30 min soak with amdgpu
  re-enabled and
  `mt7925e,mt7925_common,amdxdna,amd_isp4,pinctrl_amdisp,i2c_designware_amdisp,amd_pmf`
  blacklisted. User rebooted out of the test cleanly and re-enabled
  the modules afterward to get WiFi for chat.
- Conclusion: amdgpu is cleared. The producer is `mt7925_common`
  (the shared WiFi+BT library for the MediaTek MT7925 / WiFi-7
  chip). The five auxiliary young drivers (amdxdna, amd_isp4,
  pinctrl_amdisp, i2c_designware_amdisp, amd_pmf) are cleared by
  elimination — only `mt7925_common` has to stay off.
- Updated `hosts/wisp/configuration.nix` for round 7:
  - Shrunk `module_blacklist` from
    `mt7925e,mt7925_common,amdxdna,amd_isp4,pinctrl_amdisp,i2c_designware_amdisp,amd_pmf`
    to just `mt7925e,mt7925_common`. (mt7925e stays so it doesn't
    autoload mt7925_common.)
  - Updated the comment block above `boot.kernelParams` to reflect
    the round-6 result and the round-7 lock-down strategy.
  - Watchdog-panic params, slub_debug=FZP, slab_nomerge,
    panic_on_warn stay on as a safety net. They can be peeled in a
    later round once we've banked a few weeks of stability.

## What the user needs to do before the next chat

1. Rebuild and reboot:
   ```
   sudo nixos-rebuild switch --flake .#wisp
   sudo reboot
   ```
2. **What to expect at boot.** Full graphical session (amdgpu loaded).
   Bluetooth and WiFi still off — `mt7925_common` carries both, and
   it stays blacklisted. Use ethernet via the dock for the test.
3. Confirm the blacklist took:
   ```
   lsmod | grep -E '^(mt7925e|mt7925_common)'
   lsmod | grep -E '^(amdxdna|amd_isp4|pinctrl_amdisp|i2c_designware_amdisp|amd_pmf|amdgpu)'
   ```
   Expect: first command empty, second command shows the five
   auxiliary drivers and amdgpu loaded.
4. Use the machine normally for ≥30 min — text editor, file ops,
   browsing, the same kind of workload that hit in rounds 1–4. If
   you can reproduce the exact round-4 trigger (quickshell open,
   typical desktop), even better.
5. Outcomes:
   - **Clean ≥30 min** → this is the long-term config. We file an
     upstream bug against the `mt76` / `mt7925` driver family and
     keep the WiFi-7 chip disabled until it's fixed. Round 8 (if
     any) is just stability monitoring + the upstream report.
   - **Crashes return** → one of the five auxiliary drivers we just
     reverted is the actual producer; round 6 was a false-clean.
     Re-add the full blacklist, then bisect them one at a time.
   - **Stalls / panic with multi-CPU pstore dump** → still useful
     even if it's the mt76 bug — we'd then have a new oops with the
     watchdog params on, naming the holder. Capture and share.
6. Either way, paste:
   ```
   sudo ls -lat /var/lib/systemd/pstore/ | head -10
   sudo journalctl -k -b -1 | tail -300
   lsmod | wc -l
   ```
   If there's a new pstore dir, also paste its `dmesg.txt` (or
   attach it as `oops-2026-04-29T<HHMM>Z.txt` in this round's
   session dir).
7. Re-enable WiFi after the test if you need it to chat — easiest is
   to bring up a phone hotspot or use ethernet. Mention if you
   re-enabled the modules when you share `lsmod`, otherwise it
   looks like the blacklist failed.

## Pending — carried forward

Ordered by ROI given round-7 outcomes:

- **If round 7 is clean** → file upstream:
  - Distro/driver tree: report against the `mt76` driver / `mt7925`
    family. Include the round-2 and round-3 oops dumps
    (`help-session-2026-04-29T*` dirs) as evidence — `slub_debug=FZP`
    caught a structured 16-byte UAF write into `skbuff_small_head`
    (a network buffer cache, which is the strongest corroborating
    signal for a WiFi/BT bug) and `anon_vma_chain`.
  - Optional confirmation pass on a throwaway branch: re-enable
    `mt7925_common` alone (the other auxiliaries also enabled, as
    they will be in the live config), expect it to crash, capture
    one more oops to attach to the upstream report. Live config
    stays with `mt7925_common` blacklisted regardless.
- **If round 7 reproduces the crash** → re-add the full blacklist,
  bisect the five auxiliaries one at a time (blacklist four, leave
  one in, soak; rotate).
- **Once stable for ≥1 week** → consider peeling the safety-net
  kernel params one by one, in order: `slub_debug=FZP` and
  `slab_nomerge` first (they have the largest perf cost), then
  `panic_on_warn=1`, last the watchdog-panic trio. No rush.
- **WiFi alternatives while waiting on upstream:** USB WiFi adapter,
  phone hotspot, or ethernet via dock. Bluetooth is also off (same
  module).
- Stretch — only if a regression appears later: bracket with
  `pkgs.linuxPackages_cachyos` or `pkgs.linuxPackages_xanmod_latest`,
  or a KASAN kernel build.

## Carried-forward clue (now likely closing)

The 16-byte pointer-shaped writes from rounds 2 and 3 — round 2 at
offset 1728 of `skbuff_small_head`, round 3 at offset 48 of
`anon_vma_chain` — are now best read as primary evidence for the
upstream mt76 bug report. `skbuff_small_head` corruption is a direct
signature of network-buffer mishandling, which is exactly where a
WiFi-7 driver bug would land. We never matched the bit patterns to a
specific producer struct member, but the upstream maintainers may be
able to once they see the module name.

## Notes for future Claude

- Round-6 had no chat.log captured automatically (rounds 4 and 5
  also did not). User is expected to `/export` and save the
  conversation here before round 7 per `help-sessions/README.md`
  step 1.
- Round 7 is the lock-down round, not another bisect. The
  expectation is "clean, file upstream, peel safety nets later."
  Resist the urge to design more experiments unless round 7
  surprises us.
