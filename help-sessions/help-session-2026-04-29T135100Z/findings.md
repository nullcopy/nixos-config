# Help session findings — round 3

Continuation of crash triage on wisp (HP ZBook Ultra G1a / Strix Halo).
Round 1: `../help-session-2026-04-29T090255Z/findings.md`.
Round 2: `../help-session-2026-04-29T095446Z/findings.md`.

## Where round 2 left off

Diagnosis was: write-after-free on `skbuff_small_head`, producer
unknown but suspected to be `mt7925e` (WiFi 7) given timing and the
SKB cache. Action: `module_blacklist=mt7925e` on the kernel cmdline,
soak in TTY ≥30 min.

## Round 3 result — 2026-04-29

Boot-time evidence (in pstore dmesg @ t+21s):
`Module mt7925e is blacklisted`. Module did *not* load during the
soak; user re-enabled WiFi *after* the crash to chat. Test was valid.

System still crashed, ~5 min into the soak. Pstore captured cleanly.
Full dump and module list: `oops-2026-04-29T1430Z.txt`.

Key observations from the new oops:

1. **Different cache.** Corruption was in `anon_vma_chain` (a VMA
   data structure), not `skbuff_small_head`. Detected at alloc time
   via SLUB freelist walk, called from `wpctl` (PipeWire control)
   in `mprotect()` → `__split_vma` → `anon_vma_clone`.
2. **Same fingerprint.** 16 bytes (two pointer-shaped 8-byte values)
   overwritten in the body of a freed object, redzones (0xbb) and
   padding (0x5a) intact. Identical shape to round 2's overwrite.
3. **Producer signature is "stale list-pointer write".** Two pointers
   into the body of a freed object, struct-aligned, with surrounding
   poison untouched, is the classic shape of code that holds a stale
   pointer to a list_head and does `list_add` / `list_del` on it
   after the object was freed.

## What this changes

- **Cache identity is downstream of timing, not signal.** The same
  bug hits whatever cache happens to recycle the freed slot. Round
  1 + round 2: `skbuff_small_head` (because heavy SKB churn).
  Round 3: `anon_vma_chain` (because PipeWire `mprotect`'d during
  the corruption window). Don't read meaning into the cache name.
- **mt7925e is ruled out.** Module was demonstrably not loaded;
  crash still occurred.
- **Hardware/firmware moves up the suspect list.** A stale-pointer
  UAF on brand-new Strix Halo silicon, hitting random caches across
  reboots, with the user not running anything exotic, is consistent
  with: (a) a still-suspect young driver, OR (b) BIOS/microcode
  bug, OR (c) bad RAM. The 16-byte pointer-shaped write argues
  *against* generic RAM bitflips (those would be 1-bit, not
  16-byte structured) and *for* a software UAF — but firmware-level
  software (microcode, PSP, SMU) is still in scope.

## Suspect producer drivers — updated

Strix-Halo-young modules still in scope (loaded during round 3 crash
per `oops-2026-04-29T1430Z.txt` modules-linked-in):

- `amdxdna` (NPU)
- `amd_isp4`, `pinctrl_amdisp`, `i2c_designware_amdisp` (ISP trio,
  load together)
- `amd_pmf` (power management framework)
- `amdgpu` (mature, lower probability — kept on for round 4 to
  avoid confounding the display path)

Also out-of-tree-young in this kernel: various `snd_sof_amd_*`
codecs and `cs35l56`-related, but these are audio paths and have
not shown up as suspects.

## Plan

User proposed (and we agreed): instead of N serial driver-bisect
rounds, **shotgun off all young drivers at once** for round 4. This
gives a one-bit answer (driver vs. not-driver) and either narrows
to one of the six modules (then half-bisect inside the set) or
exonerates the whole driver axis (then pivot to firmware/RAM).

| # | Step | Status |
|---|------|--------|
| 1 | Diagnostic kernelParams | done round 1 |
| 2 | Capture clean post-`slub_debug=FZP` oops | done round 2 |
| 3 | mt7925e blacklist test | done round 3 — RULED OUT |
| 4 | Shotgun-off Strix-Halo-young drivers (mt7925e, amdxdna, amd_isp4, pinctrl_amdisp, i2c_designware_amdisp, amd_pmf) | **pending — config staged** |
| 5a | If round 4 clean → half-bisect within the shotgun set | pending |
| 5b | If round 4 dirty → BIOS update via LVFS | pending |
| 5c | If round 4 dirty + BIOS doesn't help → memtest86+ | pending |
| 6 | If everything above clean: file upstream bug with the oops trail | pending |
| 7 | Bracket: alternate kernel (cachyos / xanmod) | pending |
| 8 | Stretch: KASAN kernel build to catch the producer write directly | pending |

## Notes / carry-forward

- The 16-byte writes — round 2 was
  `0x1a8d08fa_a9230d68 0xf65e91b6_fe99cf9d`; round 3 was
  `0xd6065ebc_851f37d2 0x503b9c35_f43b9c35` (approx, byte order
  may need re-checking). If we ever identify the producer struct,
  matching these bit patterns to a struct field offset nails the
  bug. Carry forward.
- KASAN would catch the *producing* write directly instead of at
  next consumer's alloc. Defer until shotgun and BIOS rounds
  are exhausted; KASAN requires a custom kernel build.
- amdgpu is intentionally NOT in the round-4 blacklist — it's
  mature and disabling it changes the display path enough to
  confound the test. If everything else is exonerated, amdgpu
  becomes its own bisect round.
