# Help session findings — round 2

Continuation of crash triage on wisp (HP ZBook Ultra G1a / Strix Halo).
First session: `../help-session-2026-04-29T090255Z/findings.md`.

## Where round 1 left off

Three identical oopses on `kmem_cache_free` of (apparent) `skbuff_head_cache`,
all near s2idle resume, in TTY. Diagnosis: SLUB freelist corruption around
s2idle resume. Action: added `consoleblank=0 slub_debug=FZP slab_nomerge
panic_on_warn=1` to kernelParams to (a) reduce s2idle entries, (b) detect
the corruption at the producer side, (c) split merged caches so the next
oops names the actual cache.

## Round 2 result — 2026-04-29

User rebuilt + booted into TTY, was actively typing (no s2idle this run),
system hung at boot+354 s. Pstore captured a clean panic this time:

- New cache name: **`skbuff_small_head`** (not `skbuff_head_cache` — that
  was a merged alias; `slab_nomerge` did its job).
- `[Poison overwritten] 0xffff8b15dc6886c0-…cf @offset=1728. First byte
  0x68 instead of 0x6b`
- Object body: 16 bytes of garbage (`68 0d 23 a9 fa 08 8d 1a 9d cf 99 fe
  b6 91 5e f6` — looks like two kernel pointers) followed by uniform `0x6b`
  free poison through the rest of the object.
- Redzones (`0xbb…`) and padding (`0x5a…`) intact: the writer hit the
  *object body* exactly, not a buffer overrun from an adjacent slot.
- Detection path = consumer = next `__alloc_skb` → `__tcp_send_ack` from
  tailscale's TUN write. Producer is invisible — `slub_debug=FZP` validates
  poison at allocation time, not at the bad write.
- `panic_on_warn=1` promoted the WARN to a panic; pstore captured all 20
  EFI variable slots cleanly.

Full pstore dump and analysis: `oops-2026-04-29T1030Z.txt`.

## What this changes

1. **Not s2idle-only.** This run had no s2idle cycle (user was at the
   keyboard). The bug is reachable during normal operation; s2idle
   resumes might *increase the rate* (which would explain TTY-with-blank
   crashing fastest), but they're not required.
2. **Not Chrome-related.** Round 1's three Chrome oopses were the same
   bug — Chrome was just a heavy SKB consumer that happened to trip the
   poisoned object. This round it was tailscaled.
3. **Cache identified.** `skbuff_small_head` is the small SKB header
   cache (introduced in 6.x to back compact SKB heads). All packet RX/TX
   paths churn this cache.

## Suspect producer drivers (rank-ordered)

- **`mt7925e`** (MediaTek WiFi 7) — newest, processes SKBs constantly,
  WiFi was associated and active during the crash. Highest ROI to
  bisect first.
- `tun` — in the consumer stack, but it's mainline and broadly used.
- `amdxdna` (NPU), `amd_isp4` / `pinctrl_amdisp` / `i2c_designware_amdisp`
  (ISP), `amd_pmf` — Strix-Halo-young, but no obvious skbuff handling.
- `amdgpu` — would have been the suspect on prior generations, but
  amdgpu is mature; lower probability.

## Plan

| # | Step | Status |
|---|------|--------|
| 1 | Diagnostic kernelParams (round 1) | done 2026-04-29 |
| 2 | Capture clean post-`slub_debug=FZP` oops | done 2026-04-29 round 2 |
| 3 | Bisect: `module_blacklist=mt7925e`, soak ≥30 min in TTY | pending |
| 4 | If still crashes → next bisect candidate (`amdxdna`, then ISP trio, then `amd_pmf`) | pending |
| 5 | If clean → file upstream bug against `mt7925e` with this oops | pending |
| 6 | BIOS update via LVFS | pending |
| 7 | Try alternate kernel (cachyos / xanmod) as a bracket | pending |

## Notes

- KASAN would catch the producing write at the moment it happens
  (instead of at the next consumer's allocation), but it requires a
  custom kernel build — not just a kernelParam. Defer unless the
  driver bisect doesn't isolate it.
- The pointer-shaped value written into the freed object
  (`0x1a8d08fa_a9230d68 0xf65e91b6_fe99cf9d`) is potentially a clue —
  if the producer is identified and we can match those bits to a
  struct field offset, that nails the bug. Carry forward.
