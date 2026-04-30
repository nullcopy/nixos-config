---
name: actions — wisp crash triage, round 9 (Test A+B held + Test D layered)
description: What was done in round 9 (D0 pin + pcie_aspm=off retained, module_blacklist=amd_pmf added) and what the user needs to do next
type: project
---

# actions — wisp crash triage, round 9

## Done this session (2026-04-30 UTC)

- Read fresh pstore from `/var/lib/systemd/pstore/1777519124/001/dmesg.txt`
  (18 parts) — the round-9 oops at uptime 1049s. Saved a chronologically
  ordered copy to `oops-0301Z.txt`. (pstore writes parts back-to-front, so
  Part 18 is the boot start; the user's `dmesg.txt` was already
  reassembled.)
- Confirmed Test A and Test B from rounds 7/8 actually took effect this run:
  `power/control = on`, `pcie_aspm=off` in `/proc/cmdline`. `LnkCtl`
  showing `ASPM L1 Enabled` is the device-side capability — the kernel
  policy override holds.
- Diagnosed the new oops as a third distinct signature: GPF on a smashed
  `objcg` pointer (`R12 = 0x0e579b4e60ca7d41`) inside `refill_obj_stock`,
  triggered from `kfree` inside `drm_atomic_state_default_clear`, called
  from amdgpu's fbdev damage worker `drm_fb_helper_damage_work`.
- Per user direction, **skipped the round-8 plan's Test C (pin amdgpu DPM
  to high) and went straight to Test D (`module_blacklist=amd_pmf`)**.
  Reasoning: round 9's detector path is in DRM/amdgpu, and the historical
  PASS/FAIL data already says blacklisting amdgpu fixes the bug. Test D
  narrows by removing only the AMD Platform Management Framework while
  keeping amdgpu loaded so the display still works.
- Applied **Test D layered on A+B** to `hosts/wisp/configuration.nix`:
  - **Kept** the round-7 D0-pin `systemd.tmpfiles.rules` entry on
    `0000:c1:00.0/power/control`.
  - **Kept** the round-7 `services.udev.extraRules` rule that reapplies
    the D0 pin on PCI re-enumeration.
  - **Kept** `pcie_aspm=off` in `boot.kernelParams`.
  - **Added** `"module_blacklist=amd_pmf"` to `boot.kernelParams`.
  - **Updated** the comment block above `boot.kernelParams` to record
    the round-9 outcome (A+B held, third signature) and the round-10
    plan.

## What the user needs to do before the next chat

1. Rebuild and reboot:
   ```
   sudo nixos-rebuild switch --flake .#wisp
   sudo reboot
   ```

2. After boot, log in to a TTY (Ctrl-Alt-F2 from greeter, or just stay
   on TTY rather than starting a Wayland session). Confirm A + B + D all
   took effect:
   ```
   cat /proc/cmdline
   cat /sys/bus/pci/devices/0000:c1:00.0/power/control
   lsmod | grep -E '^(amdgpu|amd_pmf|mt7925e|mt7925_common|mt76)'
   ```
   Expect:
   - `/proc/cmdline` contains both `pcie_aspm=off` *and*
     `module_blacklist=amd_pmf` plus the existing safety params.
   - `power/control` prints `on`.
   - `lsmod` shows amdgpu and the mt7925 family loaded but **NOT**
     amd_pmf. (`amd_pmc` may still load — that's a different driver.)

3. Soak in TTY ≥30 min — ideally 60 min, since round 9 took 1049s
   (~17.5 min) to crash. Bug fires from idle, so just leave the TTY
   sitting there. WiFi/BT should still work.

4. Outcomes:
   - **Clean ≥30 min** → strong evidence amd_pmf is in the producer
     chain. Round 11: optionally peel A and/or B and re-soak to see
     which layers can come off.
   - **Crashes (any signature)** → amd_pmf alone isn't the producer.
     Capture the new pstore. Round-11 candidates:
     - Test C from round 8 (pin amdgpu DPM to high) layered on A+B+D
     - `module_blacklist=amdgpu` (loses display, matches historical
       PASS — confirms producer is somewhere in amdgpu's pull-in chain)
     - `module_blacklist=mt7925e,mt7925_common` (round-6/7 fallback —
       loses WiFi, tests whether mt76 is in the chain)
   - **Different new oops** → capture and treat on its own merits.

5. After the soak, paste back:
   ```
   sudo ls -lat /var/lib/systemd/pstore/ | head -10
   sudo journalctl -k -b -1 --no-pager > /tmp/wisp-prevboot.log; wc -l /tmp/wisp-prevboot.log
   cat /sys/bus/pci/devices/0000:c1:00.0/power/control
   cat /proc/cmdline
   lsmod | grep -E '^(amdgpu|amd_pmf|mt7925e|mt7925_common|mt76)'
   ```
   If a new pstore dir appeared, attach its `001/dmesg.txt` here as
   `oops-<HHMM>Z.txt`.

## Round-11 plan if Test D fails

Layer order from cheapest to most invasive:

1. **Test C (round-8 plan)** — pin amdgpu DPM to high. Adds a tmpfiles
   rule:
   ```nix
   "w /sys/class/drm/card1/device/power_dpm_force_performance_level - - - - high"
   ```
   (Verify `card1` post-boot via `ls /sys/class/drm`.) Tests whether GPU
   clock/voltage transitions are coupling into the corruption.
2. **`module_blacklist=amdgpu`** — historical PASS. Loses display
   acceleration but the system runs. Confirms producer is in amdgpu's
   pull-in chain (which we already strongly suspect).
3. **`module_blacklist=mt7925e,mt7925_common`** — round-6/7 fallback.
   Loses WiFi+BT (use ethernet via dock or USB WiFi). Tests whether
   mt76 is also in the producer chain or just a victim.

## Pending — carried forward

Ordered by ROI given round-9 outcome:

- **If Test D passes** → file upstream against
  `drivers/platform/x86/amd/pmf/` (kernel mailing list:
  `platform-driver-x86@vger.kernel.org`). Attach:
  - Round 7 pstore (page-pool / wake-handler crash):
    `/var/lib/systemd/pstore/1777512597/001/dmesg.txt`
  - Round 8 pstore (kmalloc-2k right-redzone overwrite):
    `/var/lib/systemd/pstore/1777516867/001/dmesg.txt`
  - Round 9 pstore (objcg pointer GPF in fbdev path):
    `/var/lib/systemd/pstore/1777519124/001/dmesg.txt`
  - Rounds 2 and 3 oops dumps from earlier session dirs
  - Hardware/firmware versions from round-7 findings
  - Live mitigations that worked: D0 pin + `pcie_aspm=off` +
    `module_blacklist=amd_pmf` (and whichever layers are still required
    after peeling experiments)
- **Once stable for ≥1 week** → start peeling kernel params. Order:
  `slub_debug=FZP` and `slab_nomerge` first (largest perf cost), then
  `panic_on_warn=1`, last the watchdog-panic trio. Try peeling
  `pcie_aspm=off` and the D0 pin individually to see whether D alone
  suffices.
- **WiFi alternatives during fallback path:** USB WiFi adapter, phone
  hotspot, ethernet via dock (still relevant if we end up at
  `module_blacklist=mt7925e,mt7925_common`).

## Notes for future Claude

- The user opted to skip Test C and go straight to Test D
  (`module_blacklist=amd_pmf`). Reasoning: round 9 crashed in the
  DRM/amdgpu stack, and the historical PASS/FAIL data already isolates
  amdgpu's pull-in chain as the producer. Test D is a faster
  bisection — narrows producer to PMF or not-PMF in one experiment.
- `amd_pmf` is `drivers/platform/x86/amd/pmf/` — the AMD Platform
  Management Framework. It talks to SMU via mailboxes, exposes thermal
  / battery telemetry, and registers a PMF input device for
  HW-event-driven UI hints. Removing it cuts a chunk of the SMU/PMF
  surface while leaving amdgpu's display path intact.
- `amd_pmc` is a different driver (S2idle / s0ix accounting). It will
  still load with amd_pmf blacklisted. If round 10 fails, blacklisting
  `amd_pmc` separately is another narrowing test before going to
  full `module_blacklist=amdgpu`.
- BIOS / kernel / firmware versions unchanged. No newer BIOS available.
- `LnkCtl` from `lspci` shows the device-side cap register, not the
  runtime-enforced state. `pcie_aspm=off` in `/proc/cmdline` is the
  authoritative receipt.
- Three distinct signatures in three rounds: round 7 (mt76 page-pool),
  round 8 (kmalloc-2k redzone), round 9 (objcg pointer GPF in fbdev
  damage worker). Don't expect a single mitigation to map to a single
  signature — there are likely multiple bugs gated on the same module
  set.
