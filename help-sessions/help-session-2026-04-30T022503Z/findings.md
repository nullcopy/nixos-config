---
name: Help session findings — round 7 (TTY crash, refined)
description: Wisp crash on Strix Halo — pstore confirms producer is mt76 page_pool corruption in mt792x_pm_wake_work, but amdgpu is the empirical gating condition; refined hypothesis is GPU-induced platform PM state changes that let the WiFi chip enter MCU power-save where the wake path then corrupts state
type: project
---

# Help session findings — round 7 (refined)

Continuation of crash triage on wisp (HP ZBook Ultra G1a 14" / AMD Strix Halo).
- Round 1: `../help-session-2026-04-29T090255Z/findings.md`
- Round 2: `../help-session-2026-04-29T095446Z/findings.md`
- Round 3: `../help-session-2026-04-29T135100Z/findings.md`
- Round 4: `../help-session-2026-04-29T141642Z/findings.md`
- Round 5: `../help-session-2026-04-29T152450Z/findings.md`
- Round 6: `../help-session-2026-04-29T155300Z/findings.md`

## What changed since round 6

User reports the failure mode has narrowed in the last few hours. They no
longer believe multiple drivers are co-conspiring; in this round only one
flips clean ↔ crash:

```
module_blacklist=pinctrl_amdisp,i2c_designware_amdisp,amd_pmf,amdgpu  PASS
module_blacklist=pinctrl_amdisp,i2c_designware_amdisp,amdgpu          PASS
module_blacklist=pinctrl_amdisp,i2c_designware_amdisp                 FAIL
module_blacklist=amdgpu                                               PASS
module_blacklist=                                                     FAIL
```

amdgpu off → never crashes (across many tries). amdgpu on → crashes,
predictably at ≈5 min, exclusively in TTY. Crashes under a graphical
session are extremely rare. Round 6 ran clean for ≥30 min with amdgpu
loaded — but that was a Wayland session, not TTY, so the runtime-PM
behavior of the WiFi chip was different.

## Smoking gun — pstore from this boot

`/var/lib/systemd/pstore/1777512597/001/dmesg.txt` (uptime 312s ≈ 5 min,
matching the user's reproducer). Kernel 6.19.10, BIOS X89 Ver. 01.03.02
(2025-06-18), `module_blacklist=` (everything loaded).

```
WARNING: net/core/netmem_priv.h:18 at page_pool_clear_pp_info+0x39/0x40
CPU: 14 UID: 0 PID: 12 Comm: kworker/u128:0 Not tainted 6.19.10 #1-NixOS
Workqueue: mt76 mt792x_pm_wake_work [mt792x_lib]
Call Trace:
 page_pool_clear_pp_info+0x39/0x40
 page_pool_return_netmem+0x108/0x180
 mt76_dma_rx_cleanup.part.0+0x12b/0x170 [mt76]
 mt792x_wpdma_reset+0xb1/0x1d0 [mt792x_lib]
 mt792x_wpdma_reinit_cond+0x67/0xa0 [mt792x_lib]
 mt792xe_mcu_drv_pmctrl+0x28/0x60 [mt792x_lib]
 mt792x_mcu_drv_pmctrl+0x38/0x80 [mt792x_lib]
 mt792x_pm_wake_work+0x29/0x1a0 [mt792x_lib]
Kernel panic - not syncing: kernel: panic_on_warn set ...
```

`panic_on_warn=1` tripped a `pp_magic` check in `page_pool_clear_pp_info`
while `mt76_dma_rx_cleanup` was returning RX netmems to the page pool.
The path is the **WiFi runtime-PM wake handler** (`mt792x_pm_wake_work`)
doing a DMA reset (`mt792x_wpdma_reset`) and finding a netmem with a bad
`pp_magic`. That signature is consistent with the round-2 / round-3
`slub_debug=FZP` receipts — 16-byte pointer-shaped writes into
`skbuff_small_head` and `anon_vma_chain`. Producer corroborated as the
mt76 RX path.

## Refined hypothesis — both drivers matter, in different ways

The empirical PASS/FAIL pattern (amdgpu off ⇒ no crash) is real and
not a coincidence. Reconciliation:

1. **Producer:** mt76. The corruption / `pp_magic` mismatch happens
   inside the mt76 RX page-pool teardown when the WiFi chip is woken
   from MCU power-save. This is what panics.
2. **Gating condition:** amdgpu being loaded changes platform-wide PM
   state in a way that lets the WiFi chip actually *enter* MCU
   power-save. With amdgpu off, the chip likely never goes idle deep
   enough for `mt792x_pm_wake_work` to run, so the buggy wake path is
   never executed and no WARN fires.

Why amdgpu specifically gates this (most likely → least):

- amdgpu pulls in `amd_pmf` and the SMU (`smu_v14_0_0`) and changes
  cross-IP power policy on Strix Halo. iGPU, NPU, and WiFi share the
  PCIe fabric and SMU; a power-policy change on one side can move the
  others' D-state / ASPM behavior.
- TTY vs. Wayland gates this further: a quiet TTY hits deeper system
  idle than a compositor-driven session, so the WiFi chip sleeps more
  often / more deeply, and the wake handler runs more often. That
  matches "crashes in TTY, almost never under Wayland."
- amdgpu's own runtime PM is reported as "Runtime PM not available"
  in dmesg, so this isn't amdgpu's runpm directly — it's the SoC-wide
  PM behavior amdgpu's stack participates in.

User's electrical/noise-coupling hypothesis is possible but harder to
test and less likely than a software PM-state interaction; we hold it
as a fallback if the PM-state tests below come out clean.

## Why the round-6 attribution wasn't wrong, just incomplete

Round 6 fingered `mt7925_common`. That's still consistent with the
producer. The new TTY data adds the gating condition: under TTY, the
WiFi PM wake path fires reliably; under a desktop session it almost
never does. Round 6 happened to soak under Wayland, which is why
amdgpu-on / mt76-on still ran clean for ≥30 min.

## Round-7 plan — keep both drivers, neutralize the wake path

Test order is cheapest → most invasive. Each is a single, reversible
knob and keeps WiFi/BT functional.

### Test A — pin the WiFi PCIe device to D0

Most surgical: blocks the exact runtime-PM wake path that crashed,
without touching amdgpu, ASPM, or anything else.

In `hosts/wisp/configuration.nix`:

```nix
systemd.tmpfiles.rules = [
  "w /sys/bus/pci/devices/0000:c1:00.0/power/control - - - - on"
];
services.udev.extraRules = ''
  ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:c1:00.0", ATTR{power/control}="on"
'';
```

Leave `module_blacklist=` empty, leave amdgpu loaded, soak in TTY ≥30 min.
Verify with `cat /sys/bus/pci/devices/0000:c1:00.0/power/control` (should
print `on`).

- **Clean:** confirms the runtime-PM wake path is the trigger. Live
  config keeps WiFi usable. Upstream report becomes "mt76 corrupts
  page-pool state in `mt792x_pm_wake_work` on MT7925; pinning the
  device to D0 avoids the path."
- **Crash:** path-pinning wasn't enough; move to test B.

### Test B — disable PCIe ASPM globally

`boot.kernelParams = [ "pcie_aspm=off" ];`. Forces all PCIe links to
L0 and rules out link-state transitions as the couplant.

### Test C — pin amdgpu to high performance

```nix
systemd.tmpfiles.rules = [
  "w /sys/class/drm/card1/device/power_dpm_force_performance_level - - - - high"
];
```

Tests whether GPU DPM transitions (not link transitions) are the
trigger. Currently `auto`.

### Fallback — round-6 plan, blacklist mt7925 pair

If A/B/C all crash, fall back to `module_blacklist=mt7925e,mt7925_common`
as the round-6/7 lock-down. WiFi+BT off; ethernet via dock.

## Carry-forward — kernel safety nets stay on

`slub_debug=FZP`, `slab_nomerge`, `panic_on_warn=1`, `softlockup_panic=1`,
`panic_on_rcu_stall=1`, `rcu_cpu_stall_timeout=15` all stay on. They
caught this oops; they need to stay on through the test cycle. Peeling
is later, after a clean week.

## Hardware / firmware snapshot

- Board: HP ZBook Ultra G1a 14 inch / 8D01
- BIOS: X89 Ver. 01.03.02 (2025-06-18)
- Kernel: 6.19.10 #1-NixOS (linuxPackages_latest as of build
  2026-04-01)
- iGPU: AMD Strix Halo, PCI 1002:1586 rev d1, ATOM BIOS
  113-STRXLGEN-001, DCN 3.5.1, IP discovery: gfx_v11_0_0, sdma_v6_0,
  vcn_v4_0_5, mes_v11_0, vpe_v6_1, isp_v4_1_1, smu_v14_0_0,
  psp_v13_0_0
- WiFi/BT: MediaTek MT7925, PCI 14c3:7925 rev 01, ASIC 79250000, WM FW
  build `20260106153120`, BT FW build `20260106153314`. mt76 +
  mt76_connac_lib + mt792x_lib + mt7925_common + mt7925e all loaded
- Suspect runtime-PM wake path: `mt792x_pm_wake_work` →
  `mt792x_mcu_drv_pmctrl` → `mt792xe_mcu_drv_pmctrl` →
  `mt792x_wpdma_reinit_cond` → `mt792x_wpdma_reset` →
  `mt76_dma_rx_cleanup` → `page_pool_return_netmem` →
  WARN at `net/core/netmem_priv.h:18`

## Outcomes table

| Outcome | Interpretation | Next |
|---|---|---|
| Test A clean ≥30 min in TTY | Runtime-PM wake path is the trigger; D0 pin is the live mitigation. | Lock down with the tmpfiles+udev rules; file upstream against mt76/mt7925 with this dump + the round-2/3 receipts. |
| Test A crashes | D0 pin alone insufficient; deeper PM-state coupling. | Run test B (pcie_aspm=off). |
| Test B clean | ASPM link transitions are the trigger. | Lock down with `pcie_aspm=off`; same upstream report with refined trigger. |
| Test B crashes | Not link-state. | Run test C (pin amdgpu DPM to high). |
| Test C clean | GPU DPM transitions are the couplant. Unusual but possible. | Lock down with the DPM-pin tmpfiles rule; file upstream with this twist. |
| All crash | PM-state hypothesis falsified. Either deeper electrical coupling or a different gating condition. | Fall back to round-6 plan: blacklist mt7925e,mt7925_common. WiFi off until upstream fixes mt76. |
| Different new oops | Treat on its own merits — second latent bug. | New round. |

## Carry-forward clue (still relevant)

The 16-byte pointer-shaped writes from rounds 2 and 3 — round 2 at
offset 1728 of `skbuff_small_head`, round 3 at offset 48 of
`anon_vma_chain` — are now the strongest receipts to file upstream.
`skbuff_small_head` corruption is exactly where mt76 RX would land.
Round-7 pstore (the panic-on-warn page-pool magic mismatch in the
PM wake path) closes the loop on which mt76 codepath produces the
corruption.
