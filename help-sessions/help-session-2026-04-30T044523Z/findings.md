---
name: Help session findings — round 10 (Test A+B+D layered, fourth signature)
description: Round 10 confirmed Test D (module_blacklist=amd_pmf) live but did not prevent the crash. Survival 1257s. New oops is a SLUB poison-violation panic — 16 bytes pointer-shaped UAF write inside a freed kmalloc-4k object, detected by an innocent userspace access(2) → kernfs symlink lookup. amd_pmf is NOT the (sole) producer.
type: project
---

# Help session findings — round 10

Continuation of crash triage on wisp (HP ZBook Ultra G1a 14" / AMD Strix Halo).

- Round 1: `../help-session-2026-04-29T090255Z/findings.md`
- Round 2: `../help-session-2026-04-29T095446Z/findings.md`
- Round 3: `../help-session-2026-04-29T135100Z/findings.md`
- Round 4: `../help-session-2026-04-29T141642Z/findings.md`
- Round 5: `../help-session-2026-04-29T152450Z/findings.md`
- Round 6: `../help-session-2026-04-29T155300Z/findings.md`
- Round 7: `../help-session-2026-04-30T022503Z/findings.md`
- Round 8: `../help-session-2026-04-30T025055Z/findings.md`
- Round 9: `../help-session-2026-04-30T033617Z/findings.md`

## What the user did since round 9

Rebuilt with the round-9 config (Test A: D0 pin retained, Test B: `pcie_aspm=off`
retained, plus Test D: `module_blacklist=amd_pmf` added). Rebooted, soaked in
TTY. System crashed at uptime **1257s** (~21 min), slightly longer than
round 9's 1049s.

Pre-/post-crash verification (paste from the user, before reboot):

```
/proc/cmdline:   ...slub_debug=FZP slab_nomerge panic_on_warn=1
                 softlockup_panic=1 panic_on_rcu_stall=1
                 rcu_cpu_stall_timeout=15 pcie_aspm=off
                 module_blacklist=amd_pmf ...
/sys/bus/pci/devices/0000:c1:00.0/power/control: on
lsmod | grep -E '^(amdgpu|amd_pmf|amd_pmc|mt7925e|mt7925_common|mt76)':
  amdgpu              16556032  26
  mt7925e                28672  0
  mt7925_common         139264  1 mt7925e
  mt76_connac_lib        98304  3 mt792x_lib,mt7925e,mt7925_common
  mt76                  155648  4 mt792x_lib,mt7925e,mt76_connac_lib,mt7925_common
  amd_pmc                61440  0
```

amd_pmf correctly absent from `lsmod` and present in cmdline blacklist —
Test D took effect.

## Round-10 oops summary (full ordered dump in `oops-0445Z.txt`)

The dump spanned TWO pstore dirs (`1777524010/` parts 1-10 and `1777524011/`
parts 11-39) created the same wall-clock second. SLUB redzone reports under
`slub_debug=FZP` are large enough that pstore splits them across adjacent
records when its ring buffer rotates. The reassembled trace is complete
from "Part 39" (oldest) through "Part 1" (newest).

```
[ 1257.984069] WARNING: mm/slub.c:1227 at object_err+0x1d7/0x1e5,
               CPU#10: Thread (pooled)/4198
[ 1257.984198] CPU: 10 UID: 1000 PID: 4198 Comm: Thread (pooled)
[ 1257.984213] R12 = ffff8b0d3eaf0000   ← slab page base
[ 1257.984213] RBP = ffff8b0d3eaf1000   ← object base (corrupted slot)
```

Object geometry (from the SLUB hex dump):

- Object base `ffff8b0d3eaf1000`
- End-of-body marker `0xa5` at `ffff8b0d3eaf1fff`
- Right redzone `bb*8` at `ffff8b0d3eaf2000` — INTACT
- Padding `5a...` at `ffff8b0d3eaf2010` — INTACT

Object size = `0x2000 - 0x1000 = 0x1000 = 4096 bytes` → **kmalloc-4k**
slab cache.

Corruption (single contiguous 16-byte write):

```
ffff8b0d3eaf1fc0: 44 ca 76 d5 8e c2 28 07  e7 e3 a1 a2 40 bb a8 2c
                  └─────── pointer #1 ──┘  └─────── pointer #2 ──┘
```

- Position: 64 bytes from end of the freed object body (offset 0xfc0 from
  base). Surrounded by intact `0x6b` SLUB free-poison.
- Shape: two 64-bit values, both with high bytes consistent with kernel
  virtual addresses if they are pointers (though `0x07` and `0x04` high
  bytes don't match the canonical kernel-VA range `0xffff8b...`, so these
  may be stale userspace pointers, encoded handles, or a struct field
  that happens to be 16-byte sized rather than two raw ptrs).

Detector chain (Part 4-1, kernel-side):

```
__x64_sys_access  (#21)            ← userspace called access("/sys/...", F_OK)
do_faccessat
user_path_at
filename_lookup
path_lookupat
link_path_walk
step_into_slowpath
pick_link
kernfs_iop_get_link               ← following a kernfs (sysfs/cgroupfs) symlink
__kmalloc_cache_noprof            ← allocating a buffer (likely 4K) for the link target
__slab_alloc.isra.0
___slab_alloc
get_partial_node
alloc_debug_processing
check_object                      ← SLUB validates the freed-poison before reuse
check_bytes_and_report.cold
object_err                        ← poison violation → WARN → panic_on_warn → die
```

The detector is a userspace thread-pool worker (UID 1000, `Comm: "Thread
(pooled)"`, PID 4198) calling `access(2)` on a path that walked through a
kernfs symlink. Identical pattern to round 8 (where quickshell's
`newfstatat` was the detector). The producer is NOT in this trace — only
SLUB's "first freed by / first allocated by" backtraces would identify
the freer/allocator that left the poisoned-and-rewritten slot, and those
backtraces are not present in the captured pstore (likely truncated to
the same record-split that produced the dual-dir capture).

## What round 10 means for the producer hypothesis

Test D **falsified**. amd_pmf was confirmed absent from `lsmod` and the
crash continued, with a fourth distinct corruption signature. amd_pmf
alone is not the (sole) producer.

What is *not* falsified:

- The producer is in the historical FAIL module set
  (amdgpu / amd_pmc / mt7925e / mt7925_common / mt76 family /
  pinctrl_amdisp / i2c_designware_amdisp / amdxdna / amdtee / amd_sfh /
  amd_isp4). PASS/FAIL data still says `module_blacklist=amdgpu = PASS`,
  so something in amdgpu's pull-in chain (now narrowed: NOT amd_pmf) is
  the producer.
- The producer hits multiple slab caches across rounds — kmalloc-2k
  (round 8), kmalloc-4k (round 10), `anon_vma_chain` (round 3),
  `skbuff_small_head` (round 2), page-pool memory (round 7), per-cpu
  obj_stock `cached_objcg` (round 9). A single producer doing
  out-of-bounds writes via stale pointers to whatever happens to be
  adjacent / aliased / freshly freed would explain this pattern.

What round 10 *adds*:

- A clean SLUB poison-violation: the freed object was poisoned by `kfree`
  (`6b`-fill), then 16 bytes of pointer-shaped data were written into the
  body **after** the free. That is a textbook **use-after-free write**.
  Not a redzone overrun (round 8 was), not a forward-allocator issue —
  someone freed a 4K kmalloc object, kept a pointer to (object_base +
  0xfc0), and wrote two 64-bit values through it.
- Survival 1257s vs the round-7 reference 312s — `pcie_aspm=off` (and/or
  removing amd_pmf, and/or pinning the WiFi PCIe device to D0) is
  reducing the firing rate of *something*. We are not seeing identical
  survival numbers, so each layer is plausibly removing one path while
  others remain.
- Detector path is `kernfs_iop_get_link` allocating 4K — innocent. Same
  as round 8 (quickshell's `newfstatat` allocating 2K). Whichever slab
  cache the producer's stale pointer aliases into is the one whose next
  allocation gets the poison-violation panic.

## Carry-forward — corruption signature library

Now six distinct receipts:

| Round | Victim | Offset | Bytes written | Look |
|---|---|---|---|---|
| 2 | `skbuff_small_head` | 1728 | 16 (pointer-shaped) | likely stale ptr |
| 3 | `anon_vma_chain` | 48 | 16 (pointer-shaped) | likely stale ptr |
| 7 | page_pool netmem | n/a | `pp_magic` mismatch | `pp_magic` field |
| 8 | `kmalloc-rnd-05-2k` redzone | 28672 (right of obj@26624) | 8 (`72 1b 90 27 4f a3 19 04`) | non-pointer junk |
| 9 | obj_stock `cached_objcg` | n/a | 8 (R12=`0e579b4e60ca7d41`) | random pointer-slot garbage |
|10 | kmalloc-4k (4096-byte slot) | 4032 (= obj+0xfc0, 64B from end) | 16 (`44 ca 76 d5 8e c2 28 07 / e7 e3 a1 a2 40 bb a8 2c`) | two qwords, pointer-shaped |

Pointer-shaped 16-byte UAF writes (rounds 2, 3, 10) and pointer-slot
8-byte writes (rounds 9 and arguably 7's `pp_magic` smash) dominate.
Round 8's 8-byte non-pointer redzone overrun looks like an outlier — or
is the same producer hitting a smaller adjacent allocation.

## Rounds 11+ plan — Test C layered on A+B+D

Round-9 actions.md listed three round-11 fallback candidates ordered
cheapest-first. Test D is now disproved, so the next step is **Test C
from round 8's plan: pin amdgpu's DPM to high** — layered on A+B+D.

Rationale:
- Cheapest and most reversible of the three fallbacks. One-line tmpfiles
  rule on `/sys/class/drm/card1/device/power_dpm_force_performance_level`.
- Tests whether GPU clock/voltage transitions are coupling into the
  corruption. amdgpu's DPM (Dynamic Power Management) drives
  P-state/voltage changes in response to engine load and thermal headroom.
  If the producer is in DPM-state-transition logic (SMU mailbox traffic,
  sensor readback, thermal callbacks), pinning to "high" should suppress
  the transitions that fire it.
- Display still works. WiFi/BT still work. No functional regression for
  TTY soak.

If Test C fails, round 12 candidates (still from round-9 actions.md):

- **`module_blacklist=amdgpu`** (historical PASS — loses display).
  Confirms producer is in amdgpu's pull-in chain with current
  kernel/firmware. If clean, we know the bug really is in the amdgpu
  graph, not in something coincidentally co-loaded.
- **`module_blacklist=mt7925e,mt7925_common`** (round-6/7 fallback —
  loses WiFi+BT). Tests whether mt76 stack is part of the producer
  chain (round 7's wake-handler crash hinted yes; rounds 8/9/10 all
  detected in non-mt76 paths).

## Carry-forward — kernel safety nets stay on

`slub_debug=FZP`, `slab_nomerge`, `panic_on_warn=1`, `softlockup_panic=1`,
`panic_on_rcu_stall=1`, `rcu_cpu_stall_timeout=15`, `pcie_aspm=off`,
`module_blacklist=amd_pmf` all stay on through the round-11 cycle. They
caught rounds 7-10. Peeling is later.

## Hardware / firmware snapshot — unchanged from round 9

- Board: HP ZBook Ultra G1a 14 inch / 8D01
- BIOS: X89 Ver. 01.03.02 (2025-06-18)
- Kernel: 6.19.10 #1-NixOS (`linuxPackages_latest` as of build 2026-04-01)
- iGPU: AMD Strix Halo, PCI 1002:1586 rev d1, address `0000:c3:00.0`,
  minor 1 (fb0 primary)
- WiFi/BT: MediaTek MT7925, PCI 14c3:7925, ASIC 79250000, address
  `0000:c1:00.0`
- AMDXDNA NPU: `0000:c4:00.1`

## Notes for future Claude

- Six rounds, four distinct oops signatures (round 7 page-pool, round 8
  redzone overrun, round 9 GPF on objcg ptr, round 10 SLUB poison
  violation). The producer is one bug (or a small set) hitting whatever
  victim happens to be aliased — don't expect signature uniqueness.
- The kmalloc-4k SLUB report didn't print "first freed by / first
  allocated by" in the captured pstore — those backtraces would have
  identified the freer of the 4K slot and might have implicated the
  producer directly. They were truncated. If round 11+ produces another
  SLUB violation, check for an additional pstore dir created the same
  second (round 10 had 1777524010 and 1777524011 — the older one held
  the start of the trace).
- Test D removed `amd_pmf` from `lsmod` cleanly. `amd_pmc` (a different
  driver — S2idle accounting) loaded as expected. If round 11 (Test C)
  fails, blacklisting `amd_pmc` is another narrowing experiment cheaper
  than full `module_blacklist=amdgpu`.
- The detector path in round 10 (`access(2)` → kernfs symlink follow)
  fires constantly from anything traversing `/sys`, `/proc/PID/cgroup`,
  systemd, or shells. That's why the bug hits at all uptimes — it's
  whichever slab cache the producer's stale pointer aliases into that
  triggers next.
