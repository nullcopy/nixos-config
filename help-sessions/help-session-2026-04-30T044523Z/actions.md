---
name: actions — wisp crash triage, round 10 (Test A+B+D held + Test C layered)
description: What was done in round 10 (D0 pin + pcie_aspm=off + module_blacklist=amd_pmf retained, DPM-pin amdgpu added) and what the user needs to do next
type: project
---

# actions — wisp crash triage, round 10

## Done this session (2026-04-30 UTC, 0445Z)

- Read pstore from BOTH `/var/lib/systemd/pstore/1777524010/001/dmesg.txt`
  (parts 1-10) and `/var/lib/systemd/pstore/1777524011/001/dmesg.txt`
  (parts 11-39) — pstore split this panic across two adjacent dump dirs.
  Saved a chronologically ordered reassembly to `oops-0445Z.txt`.
- Confirmed Test A, B, and D all took effect this run:
  - `/proc/cmdline`: `pcie_aspm=off` and `module_blacklist=amd_pmf` both present
  - `power/control`: `on` (D0 pin held)
  - `lsmod`: `amd_pmf` absent; `amdgpu`, `mt7925e`, `mt7925_common`,
    `mt76*` family, `amd_pmc` all loaded as expected
- Diagnosed the new oops as a **fourth distinct signature**: SLUB
  poison-violation panic on a freed kmalloc-4k object. 16 bytes of
  pointer-shaped data overwrote the freed-object body at offset 0xfc0
  (= 64B from end of object). Detected by an innocent userspace
  `access(2)` → kernfs symlink lookup → `kernfs_iop_get_link` allocation.
  Producer not visible in this trace.
- Test D **falsified**: amd_pmf is not the (sole) producer. Followed
  the round-9 actions.md round-11 plan and applied **Test C** layered
  on A+B+D.
- Applied **Test C layered on A+B+D** to `hosts/wisp/configuration.nix`:
  - **Kept** the round-7 D0-pin tmpfiles + udev rules (Test A)
  - **Kept** `pcie_aspm=off` (Test B)
  - **Kept** `module_blacklist=amd_pmf` (Test D)
  - **Added** a tmpfiles rule writing `high` to
    `/sys/class/drm/card1/device/power_dpm_force_performance_level`
    (Test C — pin amdgpu's DPM to the highest P-state to suppress
    GPU clock/voltage transitions)
  - **Updated** the comment block above `boot.kernelParams` to record
    the round-10 outcome and the round-11 plan

## What the user needs to do before the next chat

1. **Verify the DRM card minor** before rebuild. Round-7 hardware notes
   say amdgpu is on minor 1 (`fb0` primary), but the tmpfiles rule will
   silently no-op if `card1` is wrong:
   ```
   ls /sys/class/drm
   cat /sys/class/drm/card1/device/uevent | head -5
   ```
   If amdgpu is on `card0` instead, edit the rule in
   `hosts/wisp/configuration.nix` to use `card0` before rebuilding.

2. Rebuild and reboot:
   ```
   sudo nixos-rebuild switch --flake .#wisp
   sudo reboot
   ```

3. After boot, log in to a TTY (Ctrl-Alt-F2 from greeter, or stay on
   TTY without starting a Wayland session). Confirm A+B+C+D all live:
   ```
   cat /proc/cmdline
   cat /sys/bus/pci/devices/0000:c1:00.0/power/control
   cat /sys/class/drm/card1/device/power_dpm_force_performance_level
   lsmod | grep -E '^(amdgpu|amd_pmf|amd_pmc|mt7925e|mt7925_common|mt76)'
   ```
   Expect:
   - `/proc/cmdline` contains `pcie_aspm=off` AND `module_blacklist=amd_pmf`
     plus all the safety params
   - `power/control` = `on`
   - `power_dpm_force_performance_level` = `high`
   - `lsmod` shows amdgpu + mt7925 family + amd_pmc; amd_pmf absent

4. Soak in TTY ≥30 min — preferably 60 min, since round 10 took 1257s
   (~21 min) to crash. Bug fires from idle, just leave the TTY alone.
   WiFi/BT still work.

5. Outcomes:
   - **Clean ≥30 min** → strong evidence GPU DPM transitions are part of
     the producer chain. Round 12: optionally peel A and/or B and/or D
     individually to see which layers can come off, and start drafting
     the upstream report against `drivers/gpu/drm/amd/`.
   - **Crashes (any signature)** → DPM transitions aren't the trigger.
     Capture pstore (check for split across two dirs again like round 10).
     Round-12 candidates (cheapest first):
     - `module_blacklist=amd_pmc` (S2idle / s0ix accounting driver — a
       smaller blacklist than full amdgpu, cheap to test)
     - `module_blacklist=amdgpu` (historical PASS — loses display, but
       confirms the bug really is in amdgpu's pull-in chain with current
       kernel/firmware/safety params)
     - `module_blacklist=mt7925e,mt7925_common` (round-6/7 fallback —
       loses WiFi+BT, ethernet via dock; tests whether mt76 is part of
       the producer chain or just a victim)
   - **Different new oops** → capture and analyze on its own merits.

6. After the soak, paste back:
   ```
   sudo ls -lat /var/lib/systemd/pstore/ | head -10
   sudo journalctl -k -b -1 --no-pager > /tmp/wisp-prevboot.log; wc -l /tmp/wisp-prevboot.log
   cat /sys/bus/pci/devices/0000:c1:00.0/power/control
   cat /sys/class/drm/card1/device/power_dpm_force_performance_level
   cat /proc/cmdline
   lsmod | grep -E '^(amdgpu|amd_pmf|amd_pmc|mt7925e|mt7925_common|mt76)'
   ```
   If any new pstore dir(s) appeared, attach all `001/dmesg.txt` files
   as `oops-<HHMM>Z.txt` (and `oops-<HHMM>Z-pt2.txt` if pstore split).

## Round-12 plan if Test C fails

Layer order from cheapest to most invasive:

1. **Add `module_blacklist=amd_pmc` to existing kernelParams.** amd_pmc
   is `drivers/platform/x86/amd/pmc/` — S2idle (s0ix) accounting and SMU
   mailbox glue, separate from the now-blacklisted amd_pmf. Cheap to
   add; doesn't lose any visible functionality.
2. **Replace `module_blacklist=amd_pmf` with `module_blacklist=amdgpu`**
   (or layer it). Historical PASS in the round-7 table. Loses display
   but the system runs. Confirms producer is in amdgpu's pull-in chain
   with current kernel/firmware/safety params.
3. **Add `module_blacklist=mt7925e,mt7925_common` to existing kernelParams.**
   Loses WiFi+BT (use ethernet via dock or USB WiFi). Tests whether mt76
   is in the producer chain. Round-6/7 saw mt76 wake handler crash;
   rounds 8/9/10 detected in non-mt76 paths, so this isn't currently
   the leading suspect — but it's a known hard fix.

## Pending — carried forward

Ordered by ROI given round-10 outcome:

- **If Test C passes** → start drafting an upstream report against
  `drivers/gpu/drm/amd/` (specifically the DPM/SMU/PM glue). Mailing list:
  `amd-gfx@lists.freedesktop.org`. Attach the full pstore evidence pack:
  - Round 7 (page-pool / wake-handler): `/var/lib/systemd/pstore/1777512597/001/dmesg.txt`
  - Round 8 (kmalloc-2k right-redzone overwrite): `/var/lib/systemd/pstore/1777516867/001/dmesg.txt`
  - Round 9 (objcg pointer GPF in fbdev path): `/var/lib/systemd/pstore/1777519124/001/dmesg.txt`
  - Round 10 (kmalloc-4k UAF write): both `/var/lib/systemd/pstore/1777524010/001/dmesg.txt` and `/var/lib/systemd/pstore/1777524011/001/dmesg.txt` (parts 1-10 and 11-39)
  - Rounds 2 and 3 dumps from earlier session dirs
  - Hardware/firmware snapshot from round-7 findings
  - Live mitigations that worked (D0 pin + `pcie_aspm=off` +
    `module_blacklist=amd_pmf` + DPM pin to high — and whichever layers
    are still required after peeling experiments)
- **Once stable for ≥1 week** → start peeling kernel params. Order:
  `slub_debug=FZP` and `slab_nomerge` first (largest perf cost), then
  `panic_on_warn=1`, last the watchdog-panic trio. Try peeling
  `pcie_aspm=off`, the D0 pin, the DPM pin, and the amd_pmf blacklist
  individually to see whether any single layer suffices.
- **WiFi alternatives during fallback path:** USB WiFi adapter, phone
  hotspot, ethernet via dock (still relevant if round 12+ ends up at
  `module_blacklist=mt7925e,mt7925_common`).

## Notes for future Claude

- Round 10 confirmed pstore can split a single panic across two dump
  dirs created the same wall-clock second. ALWAYS check both dirs in
  `/var/lib/systemd/pstore/` if their timestamps are adjacent — the
  newer one will have lower part numbers (the actual oops trace), the
  older one will have higher part numbers (the SLUB hex body).
- Test C is the round-8 plan that round 9 skipped. The user opted for
  Test D (`module_blacklist=amd_pmf`) first; D failed, so we're back to
  C. C is a cheap, reversible single-line tmpfiles rule.
- The historical PASS row `module_blacklist=amdgpu = PASS` remains the
  most load-bearing piece of evidence. Whatever Test C shows, the
  producer is somewhere in amdgpu's pull-in chain — round 10 narrows it
  to "not amd_pmf alone" (and the round-7 historical row narrowed it to
  "not pinctrl_amdisp + i2c_designware_amdisp alone").
- `card1` for the DPM pin matches round-7 hardware notes (amdgpu on
  minor 1, fb0 primary). Verify post-boot before declaring the rule
  effective; tmpfiles silently no-ops on missing paths.
- The kmalloc-4k SLUB report did NOT include the "first freed by / first
  allocated by" backtraces — those would have implicated the producer.
  They may have been in pstore parts that didn't fit. If round 11
  triggers another SLUB violation, look harder for those backtraces in
  the captured trace; they appear AFTER the panic header but BEFORE
  the call trace dump.
