---
name: actions — wisp crash triage, round 8 (Test A held + Test B layered)
description: What was done in round 8 (D0 pin retained, pcie_aspm=off added) and what the user needs to do next
type: project
---

# actions — wisp crash triage, round 8

## Done this session (2026-04-30 UTC)

- Read fresh pstore from `/var/lib/systemd/pstore/1777516867/001/dmesg.txt`
  — the round-8 oops at uptime 338s. Reassembled it (pstore writes parts
  back-to-front) and saved a chronologically ordered copy to
  `oops-0241Z.txt`.
- Confirmed Test A from round 7 actually took effect this run:
  `/sys/bus/pci/devices/0000:c1:00.0/power/control = on` and the kernel
  cmdline shows the expected safety params with no `module_blacklist`.
- Diagnosed that the new oops is **not** the round-7 mt76 page-pool /
  wake-handler crash. It's a `slub_debug=FZP` right-redzone overwrite on
  a freed kmalloc-2k object — 8-byte non-pointer write past the end of a
  2K allocation. Detected by an unrelated VFS allocation in
  `nd_alloc_stack` from `.quickshell-wra` doing `newfstatat`. Quickshell
  is the *detector*, not the producer.
- Refined the hypothesis: producer is hitting memory in steady state
  (not just at MCU wake). D0 pin demonstrably suppressed one failure
  path; reverting it would just remove a working mitigation.
- Applied **Test B layered on Test A** to `hosts/wisp/configuration.nix`:
  - **Kept** the round-7 D0-pin `systemd.tmpfiles.rules` entry on
    `0000:c1:00.0/power/control`.
  - **Kept** the round-7 `services.udev.extraRules` rule that reapplies
    the D0 pin on PCI re-enumeration.
  - **Added** `"pcie_aspm=off"` to `boot.kernelParams`.
  - **Updated** the comment block above `boot.kernelParams` to record
    the round-8 outcome (D0 pin held, signature changed) and the
    layered-test plan.

## What the user needs to do before the next chat

1. Rebuild and reboot:
   ```
   sudo nixos-rebuild switch --flake .#wisp
   sudo reboot
   ```

2. After boot, log in to a TTY (Ctrl-Alt-F2 from greeter, or just stay
   on TTY rather than starting a Wayland session). Confirm Test A + B
   both took effect:
   ```
   cat /proc/cmdline
   cat /sys/bus/pci/devices/0000:c1:00.0/power/control
   lspci -vvv -s 0000:c1:00.0 | grep -A1 LnkCtl
   lsmod | grep -E '^(amdgpu|mt7925e|mt7925_common|mt76|amd_pmf)'
   ```
   Expect:
   - `/proc/cmdline` contains `pcie_aspm=off` *and* the existing safety
     params and *no* `module_blacklist`.
   - `power/control` prints `on`.
   - `LnkCtl` shows `ASPM Disabled` (or `ASPM L0s L1` with `Disabled`
     reflected in the runtime state — the kernel param overrides
     anything the firmware advertises).
   - `lsmod` shows amdgpu and the mt7925 family loaded.

3. Soak in TTY ≥30 min. Crash hit at 338s last time, so 30 min is
   comfortable. Bug fires from idle, so just leaving the session sitting
   there is the worst case. WiFi/BT should still work — that's the
   point.

4. Outcomes:
   - **Clean ≥30 min** → Test B is part of the live mitigation. We then
     do a round-9 follow-up where we *peel* the D0 pin (set
     `power/control = auto`) and re-soak, to see whether
     `pcie_aspm=off` alone is sufficient.
   - **Crashes (any signature)** → capture the new pstore and we move
     to Test C (pin amdgpu DPM to high).
   - **Different new oops** → capture and share; treat on its own.

5. After the soak, paste back:
   ```
   sudo ls -lat /var/lib/systemd/pstore/ | head -10
   sudo journalctl -k -b -1 --no-pager > /tmp/wisp-prevboot.log; wc -l /tmp/wisp-prevboot.log
   cat /sys/bus/pci/devices/0000:c1:00.0/power/control
   cat /proc/cmdline
   ```
   If a new pstore dir appeared, attach its `001/dmesg.txt` here as
   `oops-<HHMM>Z.txt`.

## Test C — pin amdgpu DPM to high (next round if B fails)

If Test B crashes with the same kmalloc-2k redzone signature, the
producer isn't link-state-driven. Next cheapest knob: pin amdgpu DPM.
In `hosts/wisp/configuration.nix`, add to `systemd.tmpfiles.rules`:

```nix
"w /sys/class/drm/card1/device/power_dpm_force_performance_level - - - - high"
```

(Verify the `card1` minor post-boot — round-8 boot showed amdgpu on
minor 1, so `card1` should be right, but check `ls /sys/class/drm`.)

Keep the D0 pin and `pcie_aspm=off` in place. Layer C on top of A+B.

## Fallback — blacklist mt7925 pair

If A+B+C all crash, accept the round-6/7 fallback and lose WiFi+BT
until upstream fixes mt76:

```nix
boot.kernelParams = [
  ...existing params...
  "module_blacklist=mt7925e,mt7925_common"
];
```

(Drop the D0 pin / pcie_aspm=off / DPM pin once we go to module
blacklist — they're irrelevant if the WiFi driver isn't loaded.)

## Pending — carried forward

Ordered by ROI given round-8 outcome:

- **If Test B passes** → file upstream against `mt76` driver / `mt7925`
  family at `linux-wireless@vger.kernel.org` and the MediaTek tree.
  Attach:
  - Round 7 pstore (page-pool / wake-handler crash):
    `/var/lib/systemd/pstore/1777512597/001/dmesg.txt`
  - Round 8 pstore (kmalloc-2k right-redzone overwrite):
    `/var/lib/systemd/pstore/1777516867/001/dmesg.txt`
  - Rounds 2 and 3 oops dumps from earlier session dirs
  - Hardware/firmware versions from round-7 findings
  - Live mitigations that worked: D0 pin + `pcie_aspm=off` (and
    whether peeling D0 alone keeps the system clean)
- **Once stable for ≥1 week** → start peeling safety-net kernel
  params. Order: `slub_debug=FZP` and `slab_nomerge` first (largest
  perf cost), then `panic_on_warn=1`, last the watchdog-panic trio.
- **WiFi alternatives during fallback path:** USB WiFi adapter, phone
  hotspot, ethernet via dock.

## Notes for future Claude

- "Test A failed" is misleading. D0 pin **changed the failure
  signature** — the round-7 wake-path crash is gone; a steady-state
  redzone overwrite shows up instead. Treat the round-8 dump as
  evidence of a *different* path, not as evidence the D0 pin is
  worthless.
- Layering knobs (A then A+B then A+B+C) is intentional and important.
  The user originally framed the plan as "revert and try the next" —
  that wastes the partial mitigation we already have. Confirm with the
  user before peeling any layer.
- The 8-byte non-pointer overwrite (`72 1b 90 27 4f a3 19 04`) doesn't
  look like the rounds 2/3 pointer-shaped writes. Could be a different
  bug, or the same producer hitting a smaller victim. Worth flagging
  upstream as a separate signature.
- BIOS / kernel / firmware versions unchanged from round 7. No newer
  BIOS available as of this session.
- `pinctrl_amdisp` and `i2c_designware_amdisp` are still in the FAIL
  module set; the user removed them from the blacklist after round 6.
  If A+B+C all fail, they're a candidate suspect to re-add to the
  blacklist before going all the way to mt7925 blacklist.
