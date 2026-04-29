---
name: actions — wisp crash triage, round 5
description: What was changed in round 5, what the user needs to do before round 6
type: project
---

# actions — wisp crash triage, round 5

## Done this session (2026-04-29)

- Confirmed round-5 outcome: ≥30 min clean soak with the full
  extended blacklist
  (`mt7925e,mt7925_common,amdxdna,amd_isp4,pinctrl_amdisp,i2c_designware_amdisp,amd_pmf,amdgpu`)
  and the watchdog-panic kernel params on. User rebooted out of the
  test cleanly and re-enabled the modules afterward to get WiFi back
  for chat.
- Conclusion: the producer lives in `{amdgpu, mt7925_common}`. Other
  young Strix-Halo drivers, RAM, and firmware are jointly discharged
  *modulo* the round-5 caveat that they were all blacklisted together
  with the live suspects.
- Updated `hosts/wisp/configuration.nix` for round 6:
  - Removed `amdgpu` from `module_blacklist`. Kept
    `mt7925e,mt7925_common,amdxdna,amd_isp4,pinctrl_amdisp,i2c_designware_amdisp,amd_pmf`.
  - Updated the comment block above `boot.kernelParams` to reflect
    the round-5 result and the round-6 half-bisect strategy.
  - Watchdog-panic params (`softlockup_panic=1`,
    `panic_on_rcu_stall=1`, `rcu_cpu_stall_timeout=15`) and
    slub_debug/slab_nomerge/panic_on_warn stay on.

## What the user needs to do before the next chat

1. Rebuild and reboot:
   ```
   sudo nixos-rebuild switch --flake .#wisp
   sudo reboot
   ```
2. **What to expect at boot.** With amdgpu re-enabled, Wayland/X
   should come up normally. WiFi *and* Bluetooth are still off
   (mt7925_common stays blacklisted). Plan offline; ethernet via
   dock if needed.
3. Confirm the blacklist took:
   ```
   lsmod | grep -E '^(mt7925e|mt7925_common|amdxdna|amd_isp4|pinctrl_amdisp|i2c_designware_amdisp|amd_pmf)'
   lsmod | grep -E '^amdgpu'
   ```
   Expect: first command empty, second command shows amdgpu loaded.
4. Use the machine normally for ≥30 min — text editor, file ops,
   browsing local files, similar to the workloads that crashed in
   rounds 1–4. If you can reproduce the *exact* workload that hit in
   round 4 (quickshell open, typical desktop usage), even better.
5. Outcomes:
   - **Clean ≥30 min** → mt7925_common is the producer. amdgpu is
     cleared. Round 7 locks down the WiFi-7 driver and reverts the
     unnecessary blacklist entries.
   - **Stalls and the system panics** → pstore should now have a
     fresh dir with a multi-CPU dump. **This is the prize.** The
     holder of the spinlock will be named in one of the CPU stacks.
   - **Stalls without a panic** → unlikely given the watchdog
     params are tuned tight, but if it happens, fall back to firmware
     (LVFS BIOS update via fwupdmgr).
6. Either way, paste:
   ```
   sudo ls -lat /var/lib/systemd/pstore/ | head -10
   sudo journalctl -k -b -1 | tail -300
   ```
   If there's a new pstore dir, also paste its `dmesg.txt` (or
   attach it as `oops-2026-04-29T<HHMM>Z.txt` in this round's session
   dir, mirroring round 3).
7. Re-enable mt7925_common after the test if you need WiFi/BT to
   chat. Mention you did so when you share `lsmod`, otherwise it
   looks like the blacklist failed.

## Pending — carried over

Ordered by ROI given round-6 outcomes:

- **If round 6 is clean (mt7925_common is the trigger)** → Round 7:
  shrink the blacklist to just `mt7925e,mt7925_common`, revert the
  other five entries, soak. If still clean, that's our long-term
  config; file an upstream report against mt76. Optional confirmation
  pass: re-enable mt7925_common alone (with the others off) and
  expect it to crash, fully closing the bisect.
- **If round 6 panics with multi-CPU dump (amdgpu is the trigger)**
  → walk the holder CPU's stack and registers, identify the
  producer directly inside amdgpu. Possibly narrow with
  `amdgpu.dc=0`, `nomodeset`, etc.
- **If round 6 hangs without a panic** → pivot to firmware:
  ```
  nix shell nixpkgs#fwupd -c sudo fwupdmgr refresh
  nix shell nixpkgs#fwupd -c sudo fwupdmgr get-devices
  nix shell nixpkgs#fwupd -c sudo fwupdmgr get-updates
  nix shell nixpkgs#fwupd -c sudo fwupdmgr update
  ```
  Then memtest86+ if BIOS update doesn't help. Current BIOS is X89
  Ver. 01.03.02 06/18/2025.
- Bracket with alternate kernel (`pkgs.linuxPackages_cachyos` or
  `pkgs.linuxPackages_xanmod_latest`) once the bisect axis is
  resolved.
- Stretch: KASAN kernel build to catch the producing write directly.
  Reserve for after shotgun + BIOS + memtest are exhausted.

## Carried-forward clue

16-byte pointer-shaped writes still unmatched to a producer struct.
Round 2: `0x1a8d08fa_a9230d68 0xf65e91b6_fe99cf9d` at offset 1728 of
`skbuff_small_head`. Round 3: `0xd6065ebc_851f37d2 0x503b9c35_f43b9c35`
(approx — verify byte order against round-3 oops) at offset 48 of
`anon_vma_chain`. If a producer name emerges, matching these bits to
a struct member nails the bug.

## Notes for future Claude

- Round-5 had no chat.log captured automatically (round 4 also did
  not). User is expected to `/export` and save the conversation here
  before round 6 per `help-sessions/README.md` step 1.
- If a panic finally lands in pstore in round 6, prioritize reading
  the *holder* CPU stack, not the spinning CPU. The spinning CPU is
  always inside `native_queued_spin_lock_slowpath` — boring. The
  holder's stack names the function that's stuck inside the
  critical section.
