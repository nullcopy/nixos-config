# Help session findings

Tracking the recurring kernel crashes on wisp (HP ZBook Ultra G1a / Strix
Halo). Device under investigation is codenamed 'wisp' and corresponds to the
'wisp' host configuration in this nix flake, although on a different system.

## Symptom

- Machine crashes randomly. Crashes occur across OS installs (NixOS and others),
  so the cause is hardware/firmware/kernel-level — not specific to NixOS.
- In a raw TTY (no DE): crashes within 5–15 min, near-deterministic.
- With a DE: stays up for days.

## Hardware

- HP ZBook Ultra G1a 14" Mobile Workstation (8D01), AMD Strix Halo
- BIOS: `X89 Ver. 01.03.02` dated 2025-06-18
- Kernel: 6.19.10 (`linuxPackages_latest`)
- 32 logical CPUs, AMD iGPU at `0000:c3:00.0`
- cpuidle driver: `acpi_idle`; no `amd_pstate` loaded
- s2idle (modern standby) — `amd_pmc` reports "Last suspend didn't reach deepest state"

## Investigation

### 2026-04-29 — first triage session

Pulled the last 3 reassembled oopses from `/var/lib/systemd/pstore/` (boot
2026-04-28 17:12 → 2026-04-29 03:24).

All three Oopses are **identical**:

- `Oops: general protection fault, probably for non-canonical address 0x8e72ad0ab6cf3150`
- `RIP: kmem_cache_free+0x406/0x580`
- `R12: 8e72ad0ab6cf30e8` (same in all three)
- Call trace: `unix_stream_read_generic` → `unix_stream_recvmsg` → `sock_recvmsg` → `recvmsg` syscall
- `Comm: Chrome_ChildIOT` — three different PIDs (3535, 3762, 3477) hit the same poisoned object
- Crash time: ~52 s after the third s2idle resume on that boot (uptime ~10 h)
- The last s2idle resume before crash: `amd_pmc AMDI000B:00: Last suspend didn't reach deepest state`

### Diagnosis

**Kernel SLUB freelist corruption on `skbuff_head_cache`**, not a power-management
hang. Most likely a driver is scribbling on freed memory across an s2idle resume;
the system runs fine until a unix-socket SKB free walks the corrupted freelist
entry. Chrome (heavy AF_UNIX user) trips the read; in TTY there is no Chrome,
but presumably the same corruption hits a different path that hangs hard with
no pstore captured.

The TTY-vs-DE pattern is consistent with this: TTY console-blank +
`amd_pmc`-driven s2idle entries fire frequently when idle, while a DE generates
constant wakes that hold s2idle off. More resume cycles → more chances to
corrupt → faster crash.

Suspect drivers (all young on Strix Halo, all loaded at crash time):

- `amdxdna` (NPU)
- `amd_isp4`, `pinctrl_amdisp`, `i2c_designware_amdisp` (image signal processor)
- `amd_pmf` (Platform Management Framework — known Strix resume bugs)
- `mt7925e` (MediaTek WiFi 7)

## Action plan

| # | Step | Status |
|---|------|--------|
| 1 | Add diagnostic kernelParams: `consoleblank=0`, `slub_debug=FZP`, `slab_nomerge`, `panic_on_warn=1` | done 2026-04-29 |
| 2 | Soak test in TTY for ≥30 min on the new config | pending |
| 3 | If it crashes: next pstore should name the corrupted cache + producer stack thanks to `slub_debug=FZP` + `slab_nomerge`; record findings here | pending |
| 4 | BIOS update via LVFS (`fwupdmgr refresh && fwupdmgr get-updates`) | pending |
| 5 | Driver bisect: blacklist `amdxdna`, then `amd_isp4`, then `amd_pmf`, then `mt7925e` | pending |
| 6 | Try alternate kernel (`linuxPackages_cachyos` / `linuxPackages_xanmod_latest`) | pending |

## Notes

- `consoleblank=0` reduces TTY-mode s2idle entries but does **not** suppress
  logging. `slub_debug=FZP` detects corruption at write time; pstore still
  captures on panic. Net effect: more, better signal, not less.
- Lid-switch behavior is left alone — useful, and not a deterministic crash
  trigger.
- `panic_on_warn=1` is included so the first detected corruption becomes an
  immediate panic with a clean stack, rather than being swallowed as a WARN.
  May produce occasional false-positive panics from unrelated WARN_ONs in 6.19
  — acceptable for the diagnostic window.
