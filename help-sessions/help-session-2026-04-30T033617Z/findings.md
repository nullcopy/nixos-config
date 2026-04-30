---
name: Help session findings — round 9 (Test A+B held, third signature, jumping to Test D)
description: Round 9 confirmed Test B (pcie_aspm=off) live but did not prevent the crash. Survival 1049s vs 312s/338s. New oops is a GPF on a smashed objcg pointer inside refill_obj_stock from the amdgpu fbdev damage worker. Skipping Test C (DPM pin) and going straight to Test D (module_blacklist=amd_pmf) per user direction.
type: project
---

# Help session findings — round 9

Continuation of crash triage on wisp (HP ZBook Ultra G1a 14" / AMD Strix Halo).

- Round 1: `../help-session-2026-04-29T090255Z/findings.md`
- Round 2: `../help-session-2026-04-29T095446Z/findings.md`
- Round 3: `../help-session-2026-04-29T135100Z/findings.md`
- Round 4: `../help-session-2026-04-29T141642Z/findings.md`
- Round 5: `../help-session-2026-04-29T152450Z/findings.md`
- Round 6: `../help-session-2026-04-29T155300Z/findings.md`
- Round 7: `../help-session-2026-04-30T022503Z/findings.md`
- Round 8: `../help-session-2026-04-30T025055Z/findings.md`

## What the user did since round 8

Rebuilt with the round-8 config (Test A: D0 pin on `0000:c1:00.0` retained,
plus Test B: `pcie_aspm=off` added to `boot.kernelParams`). Rebooted, soaked
in TTY. System crashed at uptime **1049s** — about 3× longer than the
round-8 reference run (338s).

Pre-/post-crash verification (paste from the user, before reboot):

```
/proc/cmdline:   ...slub_debug=FZP slab_nomerge panic_on_warn=1
                 softlockup_panic=1 panic_on_rcu_stall=1
                 rcu_cpu_stall_timeout=15 pcie_aspm=off ...
/sys/bus/pci/devices/0000:c1:00.0/power/control: on
sudo lspci -vvv -s 0000:c1:00.0 | grep -A1 LnkCtl:
  LnkCtl:  ASPM L1 Enabled; RCB 64 bytes, LnkDisable- CommClk+
           ExtSynch+ ClockPM- AutWidDis- BWInt- AutBWInt- FltModeDis-
```

`LnkCtl` reports the device-side capability (always reflects what hardware
supports). The kernel `pcie_aspm=off` parameter overrides at the policy
layer; per-device `link/l1_aspm` sysfs would reflect the runtime state, but
the cmdline param is sufficient evidence Test B took effect.

## Round-9 oops summary (full dump in `oops-0301Z.txt`)

```
[ 1049.470622] Oops: general protection fault, probably for non-canonical
               address 0xe579b4e60ca7d41: 0000 [#1] SMP NOPTI
[ 1049.470739] CPU: 10 UID: 0 PID: 50 Comm: kworker/10:0
[ 1049.473053] Workqueue: events drm_fb_helper_damage_work
[ 1049.473613] RIP: 0010:refill_obj_stock+0x7e/0x240

R12 = 0e579b4e60ca7d41   ← smashed pointer
Code: ... <49> 8b 04 24 ...   ← mov rax, [r12]  faults here
```

R12 is the bad pointer. Non-canonical, fully randomized. The fault is on
`mov rax, [r12]` — `refill_obj_stock` reading `objcg->something` from a
per-cpu memcg slab obj cache where `cached_objcg` has been overwritten
with garbage.

Call trace:

```
refill_obj_stock                    ← per-cpu memcg slab obj cache
__memcg_slab_free_hook              ← memcg slab free fast-path
kfree
drm_atomic_state_default_clear
__drm_atomic_state_free
drm_atomic_helper_dirtyfb
drm_fbdev_ttm_helper_fb_dirty       [drm_ttm_helper]
drm_fb_helper_damage_work           ← amdgpu fbdev console refresh
process_one_work
worker_thread
```

Modules loaded include amdgpu, amd_pmf, amd_pmc, mt76, mt76_connac_lib,
mt792x_lib, mt7925_common, mt7925e, pinctrl_amdisp, i2c_designware_amdisp —
the historical FAIL set, same as rounds 7 and 8.

## What round 9 means for the producer hypothesis

Three rounds, three different signatures, three different victims:

| Round | Detector | Victim | Bytes |
|---|---|---|---|
| 7 | mt76 wake handler `mt792x_pm_wake_work` → `mt76_dma_rx_cleanup` → page-pool | netmem `pp_magic` | mismatched magic |
| 8 | VFS `nd_alloc_stack` from quickshell `newfstatat` | kmalloc-rnd-05-2k right redzone | 8 bytes non-pointer |
| 9 | amdgpu fbdev worker `drm_fb_helper_damage_work` → `kfree` | obj_stock `cached_objcg` | full pointer (~64 bits) of garbage |

What is *not* falsified yet:

- The producer is in the historical FAIL module set (amdgpu / amd_pmf / mt76
  / pinctrl_amdisp / i2c_designware_amdisp). PASS/FAIL data still says
  `module_blacklist=amdgpu` PASSes, so something in the amdgpu pull-in chain
  is in the producer chain.

What round 9 *adds*:

- Detector ran inside `drm_fb_helper_damage_work` — an amdgpu fbdev path
  that fires periodically while the TTY framebuffer is dirtied. The path
  is consistent with corruption hitting amdgpu-side allocations directly,
  rather than landing on a downstream consumer. That's a stronger hint
  toward amdgpu / amd_pmf / SMU than rounds 2/3/8 gave.
- Survival jumped 3×. Could be variance (the bug is rate-dependent), or B
  removed *one* of several producer paths and what remains is slower. We
  don't have enough samples to say.
- The corrupted slot is a **pointer-shaped** field smashed with garbage.
  That's closer to round-2/round-3 (16-byte pointer overwrites) than to
  round-8 (8-byte non-pointer overrun). May indicate two different bugs:
  - a steady-state pointer-slot UAF / out-of-bounds-write (rounds 2, 3, 9)
  - a small-overrun bug specific to round 8

## User direction for round 10 — Test D, not Test C

Round-8 plan said: if A+B fails, layer Test C (`power_dpm_force_performance_level=high`).
User opted to **skip Test C and jump to Test D (module_blacklist=amd_pmf)**.
Reasoning given: round 9 crashed in the DRM/amdgpu path, and the historical
PASS/FAIL data already says blacklisting amdgpu fixes it. Test D narrows the
producer further by removing only `amd_pmf` (the AMD Platform Management
Framework) while keeping amdgpu loaded so the display still works.

This is a faster bisection: it targets the SMU/PMF mailbox surface
specifically. If D PASSes, we know the producer is in PMF (or in a path PMF
exercises that amdgpu doesn't on its own); if D FAILs, the producer is
somewhere else in amdgpu's stack and we can fall back to module_blacklist=amdgpu
or revisit Test C.

## Round-10 plan — Test D layered on A+B

In `hosts/wisp/configuration.nix`:

- **Keep** the round-7 D0-pin tmpfiles + udev rules.
- **Keep** `pcie_aspm=off` from round 8.
- **Add** `"module_blacklist=amd_pmf"` to `boot.kernelParams`.

Soak in TTY ≥30 min. With the rounds 7/8/9 reference points (312s, 338s,
1049s) we'd want at least 30 min — preferably 60 — before declaring clean.

| Outcome | Interpretation | Next |
|---|---|---|
| Clean ≥30 min | Producer is in `amd_pmf` (SMU/PMF mailbox or platform-PM glue). Live mitigation = D0 pin + pcie_aspm=off + amd_pmf blacklist. File upstream against `drivers/platform/x86/amd/pmf/`. | Optionally peel A and/or B to see if they're still needed. |
| Crashes (any signature) | amd_pmf isn't the producer (or isn't the only one). Capture pstore. Move to round-11 fallback options below. | Pick one: Test C (DPM pin), or `module_blacklist=amdgpu` (loses display but matches historical PASS), or `module_blacklist=mt7925e,mt7925_common` (round-6/7 fallback — loses WiFi, tests whether mt76 is in the chain). |
| Crashes with round-7 wake-path signature | Test A somehow got reverted by the new module set. Re-verify `power/control` post-boot. | Same as above after re-verifying. |

## Carry-forward — corruption signature library

Now five distinct receipts:

| Round | Victim | Offset | Bytes written | Look |
|---|---|---|---|---|
| 2 | `skbuff_small_head` | 1728 | 16 (pointer-shaped) | likely stale ptr |
| 3 | `anon_vma_chain` | 48 | 16 (pointer-shaped) | likely stale ptr |
| 7 | page_pool netmem | n/a | `pp_magic` mismatch | `pp_magic` field |
| 8 | `kmalloc-rnd-05-2k` redzone | 28672 (right of obj@26624) | 8 (`72 1b 90 27 4f a3 19 04`) | non-pointer junk |
| 9 | obj_stock `cached_objcg` | n/a | 8 (R12=`0e579b4e60ca7d41`) | random pointer-slot garbage |

Rounds 2, 3, 9: pointer-slot overwrites (UAF / OOB-write of pointer fields).
Rounds 7, 8: smaller / non-pointer corruptions in different victims.
Best current guess: at least two distinct upstream bugs, both gated on
the same module set.

## Carry-forward — kernel safety nets stay on

`slub_debug=FZP`, `slab_nomerge`, `panic_on_warn=1`, `softlockup_panic=1`,
`panic_on_rcu_stall=1`, `rcu_cpu_stall_timeout=15`, `pcie_aspm=off` all
stay on. They caught rounds 7/8/9; we'll need them for round 10. Peeling
is later.

## Hardware / firmware snapshot — unchanged from round 8

- Board: HP ZBook Ultra G1a 14 inch / 8D01
- BIOS: X89 Ver. 01.03.02 (2025-06-18)
- Kernel: 6.19.10 #1-NixOS (`linuxPackages_latest` as of build 2026-04-01)
- iGPU: AMD Strix Halo, PCI 1002:1586 rev d1, address `0000:c3:00.0`,
  minor 1 (fb0 primary)
- WiFi/BT: MediaTek MT7925, PCI 14c3:7925, ASIC 79250000, address
  `0000:c1:00.0` (target of the D0 pin), HW/SW `0x8a108a10`, WM FW
  build `20260106153120`, BT FW build `20260106153314`
- AMDXDNA NPU: `0000:c4:00.1`, present and registered

## Notes for future Claude

- Three different oops signatures across A, A+B configs. The bug isn't
  one path — it's a producer that hits multiple victims. Don't expect a
  single mitigation to map cleanly to a single signature.
- The user asked to skip Test C (DPM pin) and go straight to
  `module_blacklist=amd_pmf`. Honor that direction; Test C remains
  available as a fallback for round 11 if D fails.
- `LnkCtl` from `lspci` shows the device-side cap register, not the
  enforced runtime state. `pcie_aspm=off` in cmdline is sufficient
  evidence the kernel-side policy is off.
- The historical PASS/FAIL row `module_blacklist=amdgpu = PASS` is
  the most load-bearing piece of evidence. It says the producer is in
  amdgpu's pull-in chain, not in the WiFi stack alone. Whatever Test D
  shows, that row stays the ground truth for narrowing.
