---
name: actions — wisp crash triage, round 7 (refined)
description: What was done in round 7 (diagnosis only this turn — no repo edits yet) and what the user needs to do next
type: project
---

# actions — wisp crash triage, round 7 (refined)

## Done this session (2026-04-30 UTC)

- Read fresh pstore dump from the most recent crash
  (`/var/lib/systemd/pstore/1777512597/001/dmesg.txt`, uptime 312s).
  Confirmed the panic is `panic_on_warn=1` tripping a `pp_magic`
  check in `page_pool_clear_pp_info`, called from
  `mt76_dma_rx_cleanup` inside the WiFi runtime-PM wake handler
  (`mt792x_pm_wake_work`).
- Initial reading was "this contradicts the user's amdgpu PASS/FAIL
  data" — corrected after pushback from the user. Refined hypothesis:
  - **Producer:** mt76 (page_pool corruption in the RX path during
    MCU power-save wake).
  - **Gating condition:** amdgpu loaded. amdgpu pulls in `amd_pmf` /
    `smu_v14_0_0` and changes platform-wide PM behavior on Strix
    Halo, which is what lets the WiFi chip actually enter MCU
    power-save and run `mt792x_pm_wake_work`. With amdgpu off, the
    chip never sleeps deep enough for the buggy wake path to run, so
    no WARN.
  - TTY-vs-Wayland gates this further: TTY hits deeper system idle,
    so the wake path fires more often. Round 6's clean Wayland soak
    is consistent — it just didn't exercise the path.
- Created this session dir: `help-sessions/help-session-2026-04-30T022503Z/`.
- Applied **Test A** to `hosts/wisp/configuration.nix`:
  - Removed all the commented `module_blacklist=…` PASS/FAIL lines from
    `boot.kernelParams` (preserved as a comment block above for the
    record). The watchdog-panic + slub_debug + slab_nomerge params stay
    on.
  - Added `systemd.tmpfiles.rules` to write `on` to
    `/sys/bus/pci/devices/0000:c1:00.0/power/control` at boot, pinning
    the MT7925 WiFi device to D0.
  - Added a `services.udev.extraRules` rule with the same effect so the
    setting is reapplied if the PCI device re-enumerates (e.g. PCI
    rescan, hotplug).
  - Updated the comment block above `boot.kernelParams` to record the
    refined producer/gating-condition split, the test-ladder plan, and
    the historical PASS/FAIL table.

## What the user needs to do before the next chat

The plan is a ladder: cheapest, most surgical first; each step keeps
WiFi/BT working. Stop at the first one that's clean.

### Test A — pin the WiFi PCIe device to D0  *(applied this session)*

The configuration change is already on disk in
`hosts/wisp/configuration.nix`. The user just needs to rebuild, reboot,
and soak.

1. Rebuild and reboot:
   ```
   sudo nixos-rebuild switch --flake .#wisp
   sudo reboot
   ```

2. After boot, log in to a TTY (Ctrl-Alt-F2 from the greeter, or just
   stay on the TTY rather than starting a Wayland session). Confirm
   the change took:
   ```
   cat /proc/cmdline
   cat /sys/bus/pci/devices/0000:c1:00.0/power/control
   lsmod | grep -E '^(amdgpu|mt7925e|mt7925_common|mt76|amd_pmf)'
   ```
   Expect: kernel cmdline shows no `module_blacklist`, `power/control`
   prints `on`, and `lsmod` shows amdgpu **and** the mt7925 family
   loaded.

3. Use the machine in TTY for ≥30 min — the crash hit at 312s last
   time, so 30 min is a comfortable margin. Anything that exercises
   the system normally is fine; the bug fires from idle, not load.
   You can also keep WiFi/BT in use during the soak — that's the
   whole point of this test (we want to keep both working).

4. Outcomes:
   - **Clean ≥30 min in TTY** → mitigation found. This becomes the
     long-term config. We file upstream against mt76/mt7925 with the
     pstore + the round-2/3 receipts.
   - **Crashes** → revert the tmpfiles + udev rules and run Test B
     (`pcie_aspm=off`).
   - **Different new oops** → capture and share the new pstore; we
     treat it as a separate finding.

5. After the soak, paste back:
   ```
   sudo ls -lat /var/lib/systemd/pstore/ | head -10
   sudo journalctl -k -b -1 --no-pager > /tmp/wisp-prevboot.log; wc -l /tmp/wisp-prevboot.log
   cat /sys/bus/pci/devices/0000:c1:00.0/power/control
   ```
   If a new pstore dir appeared, attach its `001/dmesg.txt` here as
   `oops-<HHMM>Z.txt`.

### Test B — disable PCIe ASPM globally

If A failed: revert the Test-A tmpfiles + udev rules, then in
`boot.kernelParams` add `"pcie_aspm=off"`. Rebuild, reboot, same soak.

- **Clean** → lock in `pcie_aspm=off`. File upstream.
- **Crashes** → run test C.

### Test C — pin amdgpu DPM to high

If B failed: replace the tmpfiles rule with

```nix
systemd.tmpfiles.rules = [
  "w /sys/class/drm/card1/device/power_dpm_force_performance_level - - - - high"
];
```

(Adjust `card1` if `/sys/class/drm/` numbers differ post-boot — currently
amdgpu is on minor 1.) Same soak.

### Fallback — blacklist mt7925 pair

If A/B/C all crash, accept the round-6/7 plan and lose WiFi+BT until
upstream fixes mt76:

```nix
boot.kernelParams = [
  ...
  "module_blacklist=mt7925e,mt7925_common"
];
```

### After each test, capture

```
cat /proc/cmdline
sudo ls -lat /var/lib/systemd/pstore/ | head -10
sudo journalctl -k -b -1 --no-pager > /tmp/wisp-prevboot.log; wc -l /tmp/wisp-prevboot.log
lsmod | grep -E '^(amdgpu|mt7925e|mt7925_common|mt76|amd_pmf)'
cat /sys/bus/pci/devices/0000:c1:00.0/power/control
```

If a new pstore dir appeared since the last test, attach its
`001/dmesg.txt` here as `oops-<HHMM>Z.txt`.

## Pending — carried forward

Ordered by ROI given round-7 outcomes:

- **If a test passes** → file upstream against `mt76` driver / `mt7925`
  family at `linux-wireless@vger.kernel.org` and the MediaTek tree.
  Attach:
  - This round's pstore: `/var/lib/systemd/pstore/1777512597/001/dmesg.txt`
  - Round-2 and round-3 oops dumps from the earlier session dirs
  - Hardware/firmware versions from `findings.md`
  - The exact mitigation that worked (D0 pin / pcie_aspm=off / DPM-pin)
- **Once stable for ≥1 week** → start peeling safety-net kernel
  params. Order: `slub_debug=FZP` and `slab_nomerge` first (largest
  perf cost), then `panic_on_warn=1`, last the watchdog-panic trio.
- **WiFi alternatives during the fallback path:** USB WiFi adapter,
  phone hotspot, ethernet via dock.

## Notes for future Claude

- The user pushed back hard and correctly when an earlier turn
  dismissed the amdgpu PASS/FAIL data based on the oops alone. Both
  things are true: mt76 is the producer, amdgpu is the gating
  condition. Don't collapse that distinction back into "just one
  driver" without checking with the user.
- Round 7 deliberately does **not** start with a module blacklist.
  The user wants to keep WiFi if at all possible, and the test ladder
  is structured to find the smallest knob that holds.
- The pstore content above (`Panic#1 Part1..Part18`) is the
  kernel-side ringbuffer split into 18 chunks because efi_pstore
  records are small. The interesting bits are Parts 1–5 (the WARN +
  call trace + panic). Parts 6–18 are pre-panic boot noise.
- BIOS X89 01.03.02 is the same firmware as round 5 — the round-5
  BIOS-clear didn't change the failing version, just verified the
  install. No newer BIOS is available as of this session.
