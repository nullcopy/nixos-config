---
name: Help session findings — round 8 (D0 pin held, signature changed)
description: Test A (D0 pin on the MT7925 PCIe device) took effect but did not stop the crash. New oops is a different signature — slub_debug right-redzone overwrite on a freed kmalloc-2k object, detected by an unrelated VFS allocation. Producer/gating split survives but the producer is hitting memory in steady state, not just from the wake handler.
type: project
---

# Help session findings — round 8

Continuation of crash triage on wisp (HP ZBook Ultra G1a 14" / AMD Strix Halo).

- Round 1: `../help-session-2026-04-29T090255Z/findings.md`
- Round 2: `../help-session-2026-04-29T095446Z/findings.md`
- Round 3: `../help-session-2026-04-29T135100Z/findings.md`
- Round 4: `../help-session-2026-04-29T141642Z/findings.md`
- Round 5: `../help-session-2026-04-29T152450Z/findings.md`
- Round 6: `../help-session-2026-04-29T155300Z/findings.md`
- Round 7: `../help-session-2026-04-30T022503Z/findings.md`

## What the user did since round 7

Rebuilt with the round-7 config (Test A: D0 pin on `0000:c1:00.0` via
tmpfiles + udev, no module blacklist, amdgpu loaded), rebooted, soaked
in TTY. System crashed at uptime 338s — about 6 seconds longer than the
round-7 reference run (312s).

Pre-crash verification (paste from the user, before reboot/crash):

```
/proc/cmdline:   ...slub_debug=FZP slab_nomerge panic_on_warn=1
                 softlockup_panic=1 panic_on_rcu_stall=1
                 rcu_cpu_stall_timeout=15 lsm=landlock,yama,bpf
/sys/bus/pci/devices/0000:c1:00.0/power/control: on
```

So Test A was actually live. The runtime-PM wake handler on the WiFi
device was not the trigger this time. Yet the system crashed anyway —
on a different signature.

## Round-8 oops summary (full content in `oops-0241Z.txt`)

```
[  338.199472] [Right Redzone overwritten]
              0xffff8a5a617b7000-0xffff8a5a617b7007 @offset=28672.
              First byte 0x72 instead of 0xbb
[  338.199656] BUG kmalloc-rnd-05-2k (Not tainted): Object corrupt
[  338.199825] Slab 0xfffff5660485ec00 objects=5 used=5 fp=0xec5f0ddd7c9b4681
[  338.199825] Object 0xffff8a5a617b6800 @offset=26624
```

Object body is full of `0x6b` (`SLUB_RED_INACTIVE`) — the object had
been freed and poisoned cleanly. Past its end the right redzone was
smashed by exactly **8 bytes** of non-pointer-looking data:

```
72 1b 90 27 4f a3 19 04        (le u64: 0x0419a34f27901b72)
```

That's not a kernel pointer (no `0xffff8x` pattern) and not a typical
userspace pointer either. It's closer in shape to streamed/DMA bytes or
a 64-bit integer field. The padding past the redzone (the 0x5a region)
is fully intact, so this was a single 8-byte overwrite, not a long
overrun.

Detection (CPU 14, PID 2802, `.quickshell-wra` doing `newfstatat`):

```
object_err
check_bytes_and_report
check_object
alloc_debug_processing
get_partial_node
___slab_alloc
__kmalloc_cache_noprof
nd_alloc_stack             <-- VFS path-walk allocator
pick_link
step_into_slowpath
link_path_walk
path_lookupat
filename_lookup
vfs_statx → vfs_fstatat → __do_sys_newfstatat → do_syscall_64
```

Quickshell did a stat() on a symlink chain that hit `nd_alloc_stack`,
which kmallocs a 2K buffer for the symlink walk stack. The 2K slab it
got back was already poisoned by a prior tenant whose right redzone had
been overwritten. **Quickshell is the *detector*, not the producer.**
The actual write happened earlier on whoever previously held that 2K
allocation.

Modules loaded at panic time include amdgpu, mt76, mt76_connac_lib,
mt792x_lib, mt7925_common, mt7925e, amd_pmf, pinctrl_amdisp,
i2c_designware_amdisp — i.e. the historical FAIL set. Same as round 7.

## What this means for the round-7 hypothesis

Round 7 said: producer = mt76, gating = amdgpu (changes platform PM
state so the WiFi chip enters MCU power-save and the buggy
`mt792x_pm_wake_work` runs). Test A pinned the device to D0 to block
the wake path.

Result: the wake-path crash (round-7 signature) is gone. The system
still crashes, but on a different signature. So:

- **Confirmed** by Test A: the wake-handler call chain (`mt792x_pm_wake_work`
  → `mt792x_wpdma_reset` → `mt76_dma_rx_cleanup` → `page_pool_return_netmem`
  → `page_pool_clear_pp_info`) was *one* path through which the producer
  reached bad memory. With it suppressed, that specific WARN site goes
  away.
- **Falsified**: that the wake handler is the *only* path. There's a
  steady-state corruption happening too. ~6 extra seconds before
  another victim is hit.
- **Refined producer hypothesis**: still mt76 (or another DMA-using
  driver in the loaded set), but it corrupts memory in normal RX/idle
  operation, not just at MCU-wake. Possibilities:
  1. mt76 RX page-pool / skb path corrupting buffers without going
     through `mt76_dma_rx_cleanup` (e.g. an off-by-one in skb buffer
     size accounting that splatters into the right redzone).
  2. PCIe link-state transition corrupting in-flight DMA. Strix Halo's
     SoC fabric does L1/L1.x transitions that can race with DMA on
     buggy/poorly-tuned endpoints.
  3. amdgpu / amd_pmf / SMU stack scribbling via a shared mailbox or
     DMA region.
  4. `pinctrl_amdisp` / `i2c_designware_amdisp` — the user's earlier
     PASS/FAIL data showed these in every FAIL run; they remain a
     suspect, especially as a producer that doesn't depend on WiFi
     activity.

The 8-byte non-pointer write is suggestive of (1) or (2): a single
unaligned 64-bit DMA or memcpy past end of a 2K buffer. Could be skb
linear data that overruns by a small amount. Could be a DMA descriptor
ring landing in the wrong slab.

## Carry-forward — corruption signature library

Now four distinct receipts:

| Round | Victim | Offset | Bytes written | Look |
|---|---|---|---|---|
| 2 | `skbuff_small_head` | 1728 | 16 (pointer-shaped) | likely stale ptr |
| 3 | `anon_vma_chain` | 48 | 16 (pointer-shaped) | likely stale ptr |
| 7 | page_pool netmem | n/a | `pp_magic` mismatch | `pp_magic` field |
| 8 | `kmalloc-rnd-05-2k` redzone | 28672 (right of obj@26624) | 8 (`72 1b 90 27 4f a3 19 04`) | non-pointer junk |

Rounds 2 and 3 look like a use-after-free pointer write (16 bytes is
two pointers — head/tail of a linked list? a `list_head`?). Round 8
looks like an 8-byte overrun of unrelated data. Could be the same bug
hitting two different victims, or two different bugs. The fact that
round 8's victim is a 2K kmalloc (skbuff_head is also 2K-class on this
config) is consistent with mt76 RX skb sizing being involved.

## Round-8 plan — keep Test A, add Test B (pcie_aspm=off)

Round 7's plan said "if A fails, revert A and run B." Revising: **keep
A, layer B on top.** A demonstrably suppressed one failure path
(round-7 signature is gone). Reverting it would make round-9 noisier.
Layer the knobs and only peel them after we have a clean run.

### Test B (this round)

In `hosts/wisp/configuration.nix`:

- Keep `systemd.tmpfiles.rules` D0-pin and `services.udev.extraRules`
  D0-pin from round 7.
- Add `"pcie_aspm=off"` to `boot.kernelParams`.

Soak in TTY ≥30 min as before. Outcomes:

| Outcome | Interpretation | Next |
|---|---|---|
| Clean ≥30 min | Producer was an L1/L0s ASPM transition smashing in-flight DMA. Live mitigation = D0 pin + pcie_aspm=off. | Peel D0 pin (set `power/control = auto` via tmpfiles) and re-soak. If still clean, drop the D0 pin from config. File upstream against mt76. |
| Crashes (same kmalloc-2k redzone signature) | Not ASPM. Producer is a steady-state DMA / driver bug independent of link state. | Move to Test C (pin amdgpu DPM `power_dpm_force_performance_level=high`). |
| Crashes with a different signature | Different producer surfaces with ASPM off. Treat the new dump on its own merits. | Capture pstore, new round. |
| Crashes with the round-7 wake-path signature | D0 pin somehow got reverted by ASPM-off or the udev/tmpfiles ordering. | Re-verify `power/control` post-boot before accepting any other reading. |

### Test C (next round if B fails)

Pin amdgpu DPM to high. Tests whether GPU clock/voltage transitions
are couplant to the WiFi DMA corruption. Cheap and reversible.

```nix
systemd.tmpfiles.rules = [
  "w /sys/bus/pci/devices/0000:c1:00.0/power/control - - - - on"
  "w /sys/class/drm/card1/device/power_dpm_force_performance_level - - - - high"
];
```

(Adjust `card1` if `/sys/class/drm/` numbers differ post-boot.)

### Fallback — round-6/7 plan

If A+B+C all crash, fall back to `module_blacklist=mt7925e,mt7925_common`.
WiFi+BT off; ethernet via dock. We'd still file upstream against mt76
but with the live mitigation being "don't load the driver."

## Carry-forward — kernel safety nets stay on

`slub_debug=FZP`, `slab_nomerge`, `panic_on_warn=1`,
`softlockup_panic=1`, `panic_on_rcu_stall=1`, `rcu_cpu_stall_timeout=15`
all stay on. They caught both the round-7 oops and the round-8 oops,
and we'll need them to keep catching whatever round 9 produces.
Peeling is later.

## Hardware / firmware snapshot — unchanged from round 7

- Board: HP ZBook Ultra G1a 14 inch / 8D01
- BIOS: X89 Ver. 01.03.02 (2025-06-18)
- Kernel: 6.19.10 #1-NixOS (`linuxPackages_latest` as of build
  2026-04-01)
- iGPU: AMD Strix Halo, PCI 1002:1586 rev d1
- WiFi/BT: MediaTek MT7925, PCI 14c3:7925, ASIC 79250000, WM FW
  build `20260106153120`, BT FW build `20260106153314`. mt76 +
  mt76_connac_lib + mt792x_lib + mt7925_common + mt7925e all loaded
- amdgpu PCI address: `0000:c3:00.0`, minor 1, fb0 primary
- WiFi PCI address: `0000:c1:00.0` (target of the D0 pin)

## Notes for future Claude

- D0 pinning **changed the failure signature** — that's important
  data, not a wash. Don't characterize it as "Test A failed" without
  qualifier; it suppressed one failure path and surfaced another.
- Round 9's reading depends on whether the next dump (if any) keeps
  the round-8 signature, regresses to round-7, or shows something
  new. Verify `power/control` and `/proc/cmdline` post-boot every
  time before interpreting the result.
- The producer is still mt76-shaped given context (rounds 2, 3, 7
  all had mt76-side fingerprints), but round 8 doesn't directly
  implicate it — the 8-byte non-pointer overrun could come from any
  driver doing DMA or a small memcpy off-by-one. Stay open to
  amdgpu / amd_pmf / pinctrl_amdisp as the producer if Test B/C
  rule out mt76 wake + ASPM.
