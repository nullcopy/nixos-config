---
name: actions — wisp crash triage, round 4
description: What was changed in round 4, what the user needs to do before round 5
type: project
---

# actions — wisp crash triage, round 4

## Done this session (2026-04-29)

- Ran round-4 test (shotgun blacklist of 6 young Strix-Halo drivers).
  Result: hard hang at ~1 min, no pstore entry, caps-lock dead.
  Pulled `journalctl -k -b -1` and identified the real failure:
  RCU stall → soft lockup at `inotify_poll → _raw_spin_lock →
  native_queued_spin_lock_slowpath` on CPU 6, comm
  `.quickshell-wra`. The kernel was spinning on a lock held by
  another wedged CPU.
- Noticed `mt7925_common` was loaded in the round-4 modules-list
  even though `mt7925e` was blacklisted. Mediatek bluetooth pulls
  in the WiFi+BT shared library, so the round-4 shotgun didn't
  fully exclude the WiFi-7 code path.
- Updated `hosts/wisp/configuration.nix` for round 5:
  - Extended blacklist to:
    `mt7925e,mt7925_common,amdxdna,amd_isp4,pinctrl_amdisp,i2c_designware_amdisp,amd_pmf,amdgpu`
    (added `mt7925_common` and `amdgpu`).
  - Added watchdog-panic kernel params: `softlockup_panic=1`,
    `panic_on_rcu_stall=1`, `rcu_cpu_stall_timeout=15`. A future
    stall will now panic and pstore-dump all CPUs — exposing the
    lock holder, not just the spinner.
  - Updated the comment block above kernelParams to reflect the
    new failure-mode evidence and the round-5 strategy.

## What the user needs to do before the next chat

1. Rebuild and reboot:
   ```
   sudo nixos-rebuild switch --flake .#wisp
   sudo reboot
   ```
2. **Heads up on what to expect at boot.** With `amdgpu` and
   `mt7925_common` blacklisted:
   - No Wayland/X — the graphical session won't come up. fbcon
     should give you a TTY at lower resolution. If you get only
     a black screen, hit Ctrl+Alt+F3 to switch TTY; if even the
     framebuffer is dead, we'll need `nomodeset` instead — say so.
   - No WiFi *and* no Bluetooth. Plan offline; ethernet via dock
     if available.
3. Confirm the blacklist took:
   ```
   lsmod | grep -E '^(mt7925e|mt7925_common|amdxdna|amd_isp4|pinctrl_amdisp|i2c_designware_amdisp|amd_pmf|amdgpu)'
   ```
   Expect: empty output. If anything is still loaded, the
   blacklist didn't fully take and the test is invalid.
4. Drop to TTY (Ctrl+Alt+F3) — though with amdgpu off you may
   already be on a console. Log in, soak ≥30 min with normal
   activity (text editor, file ops, similar to round 4).
5. Outcomes:
   - **Clean ≥30 min** → one of {amdgpu, mt7925_common} (or
     something they pulled in) was the producer. Round 6 will
     half-bisect: re-enable amdgpu only and re-test, or
     mt7925_common only and re-test.
   - **Stalls and the system panics** → pstore should now have a
     fresh entry with the full multi-CPU dump. That's the prize
     — the holder of the spinlock is named in the dump.
   - **Stalls without a panic** (watchdog didn't fire) → the
     watchdog params didn't help; pivot to firmware axis (BIOS
     update via LVFS, then memtest86+).
6. Either way, paste:
   ```
   sudo ls -lat /var/lib/systemd/pstore/ | head -10
   sudo journalctl -k -b -1 | tail -300
   ```
   If there's a new pstore dir, also paste its `dmesg.txt`
   contents (or attach as `oops-2026-04-29T<HHMM>Z.txt` in the
   round-5 session dir).
7. Re-enable amdgpu / mt7925_common after the test if you need
   GPU/WiFi/BT to chat. Just mention you did so when you share
   `lsmod`, otherwise it looks like the blacklist failed.

## Pending — carried over

Ordered by ROI given round-5 outcomes:

- **If round 5 is clean** → half-bisect inside {amdgpu,
  mt7925_common}:
  1. Drop `amdgpu` from blacklist (re-enable it), keep
     `mt7925_common` blacklisted, soak. If clean → mt7925_common
     was the trigger. If dirty → amdgpu was the trigger.
- **If round 5 panics with multi-CPU dump** → walk the holder
  CPU's stack and registers, identify the producer directly. May
  collapse the rest of the plan.
- **If round 5 hangs without a panic (watchdog ineffective)** →
  pivot to firmware:
  ```
  nix shell nixpkgs#fwupd -c sudo fwupdmgr refresh
  nix shell nixpkgs#fwupd -c sudo fwupdmgr get-devices
  nix shell nixpkgs#fwupd -c sudo fwupdmgr get-updates
  nix shell nixpkgs#fwupd -c sudo fwupdmgr update
  ```
  Then memtest86+ if BIOS update doesn't fix it. We have BIOS
  X89 Ver. 01.03.02 06/18/2025 today — anything newer on LVFS is
  a candidate.
- Bracket with alternate kernel (`pkgs.linuxPackages_cachyos`
  or `pkgs.linuxPackages_xanmod_latest`) once the bisect axis is
  resolved.
- Stretch: KASAN kernel build to catch the producing write
  directly. Reserve for after shotgun + BIOS + memtest are
  exhausted.

## Carried-forward clue

The 16-byte pointer-shaped writes from rounds 2 and 3 may match
a specific struct field offset once we identify the producer.
Round 2: `0x1a8d08fa_a9230d68 0xf65e91b6_fe99cf9d` at offset
1728 of `skbuff_small_head`. Round 3:
`0xd6065ebc_851f37d2 0x503b9c35_f43b9c35` (approx — verify byte
order against round-3 oops) at offset 48 of `anon_vma_chain`.
If a producer name emerges, matching these bits to a struct
member nails the bug.

## Notes for future Claude

- This session did not capture a `chat.log` automatically; user
  is expected to `/export` and save the conversation here before
  starting round 5. Per `help-sessions/README.md` step 1.
- The journal-tail technique in this session is reusable: when
  pstore is empty after a hang, always run
  `sudo journalctl -k -b -1 | tail -300` first. Hard hangs that
  don't panic still log RCU stall + soft-lockup warnings to disk.
