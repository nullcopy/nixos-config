---
name: Help session findings — round 4
description: Wisp crash triage round 4: shotgun-off of young drivers changed failure mode from UAF to spinlock hang; redesign for round 5
type: project
---

# Help session findings — round 4

Continuation of crash triage on wisp (HP ZBook Ultra G1a / Strix Halo).
- Round 1: `../help-session-2026-04-29T090255Z/findings.md`
- Round 2: `../help-session-2026-04-29T095446Z/findings.md`
- Round 3: `../help-session-2026-04-29T135100Z/findings.md`

## Where round 3 left off

Diagnosis: generic kernel UAF, ~16-byte structured write into freed
objects, hitting whatever cache recycled the slot
(`skbuff_small_head` rounds 1+2, `anon_vma_chain` round 3). Producer
unknown. mt7925e ruled out. Plan: shotgun-blacklist all young
Strix-Halo-fresh drivers in round 4.
Blacklist applied:
`mt7925e,amdxdna,amd_isp4,pinctrl_amdisp,i2c_designware_amdisp,amd_pmf`.
amdgpu intentionally left enabled.

## Round 4 result — 2026-04-29

System hung at ~1 minute. Symptom changed dramatically:

- TTY frozen, cursor stuck (not blinking).
- Caps Lock LED did **not** toggle when pressed → kernel itself wedged.
- No oops splat on the TTY.
- Required power cycle.
- **No new pstore entry** — newest pstore dir was still round 3's.

`journalctl -k -b -1 | tail -200` of the failed boot caught the real
event:

```
Apr 29 09:13:55 rcu_preempt self-detected stall on CPU 6
RIP: native_queued_spin_lock_slowpath+0x28a/0x2c0
Call Trace: __x64_sys_ppoll → do_sys_poll → inotify_poll
            → _raw_spin_lock → native_queued_spin_lock_slowpath
Comm: .quickshell-wra
Apr 29 09:14:19 watchdog: BUG: soft lockup - CPU#6 stuck for 44s!
Modules linked in: ... mt7925_common ... amdgpu ...
```

## What changed

1. **Failure mode flipped: UAF → spinlock deadlock.** Round 1–3 were
   structured 16-byte stale-pointer writes producing oopses caught by
   `slub_debug=FZP`. Round 4 is CPU 6 spinning forever on
   `inotify_group->notification_lock` because *another* CPU is
   holding the lock and never releasing. Caps-Lock-dead is
   consistent with one or more CPUs wedged in non-preemptible
   sections; eventually keyboard interrupt processing also stalls.
2. **mt7925_common was still loaded.** Even with `mt7925e`
   blacklisted, the Mediatek bluetooth driver pulls in
   `mt7925_common` (the WiFi+BT shared library). So the WiFi-7 code
   path was *not* fully eliminated in round 4. This is a hole in
   the round-4 test: any conclusion about "young drivers" must
   assume mt7925_common's contribution wasn't decisive — but it
   could be.
3. **Hangs leave evidence in the journal even without pstore.**
   `journalctl -k -b -1` survives a hard reset (it's on disk).
   Future stalls don't need pstore as long as the kernel logs
   anything before fully wedging. But to capture the *lock holder*
   we want a panic-on-stall, which dumps all CPUs.

## Hypothesis space

The shift from UAF → hang means one of:

- **Same root cause, different presentation.** The young drivers
  were "limping" enough that the corruption hit slub_debug first;
  with them gone, a different code path is corrupted/wedged
  earlier and shows up as a deadlock instead of an oops. Producer
  is still firmware/hardware/something not yet excluded.
- **Two different bugs.** UAF was driver-related (one of the six
  shotgun'd) and is now masked. The hang is independent — possibly
  amdgpu, possibly firmware/SMU, possibly the mt7925_common path
  via Bluetooth.
- **The round-4 test is invalid because mt7925_common was
  loaded.** WiFi-7 shared code was still in play via Bluetooth.
  We can't fully discharge "WiFi 7 driver" yet.

## Round 5 plan

Two changes to `hosts/wisp/configuration.nix`:

1. **Extend blacklist:** add `mt7925_common` (closes the BT-pulls-WiFi
   gap) and `amdgpu` (last Strix-Halo-young driver candidate; was
   intentionally excluded before, but the round-4 evidence justifies
   pulling it now).
2. **Watchdog-to-panic kernel params:** `softlockup_panic=1`,
   `panic_on_rcu_stall=1`, `rcu_cpu_stall_timeout=15`. The next
   stall becomes a panic with a full multi-CPU register dump in
   pstore — that exposes which CPU is *holding* the spinlock, not
   just the one spinning waiting for it.

Cost of the round-5 setup:
- No GPU output past early-boot framebuffer (no Wayland/X). fbcon
  TTY at low res should still work; if not, fallback is `nomodeset`.
- No WiFi, no Bluetooth (mt7925_common gone takes BT with it).
- Disk and USB are unaffected.

Outcomes:

| Outcome | Interpretation | Next |
|---|---|---|
| Clean ≥30 min | One of {amdgpu, mt7925_common} or something pulled in by them was the producer | Half-bisect: re-enable amdgpu only, soak; or mt7925_common only, soak |
| Stalls + panic captured | The all-CPU dump names the lock holder | Read the holder's stack — that's the producer |
| Stalls without panic (watchdog didn't fire) | Watchdog was wrong target; fall back to firmware axis | BIOS update via LVFS, then memtest86+ |

## Suspect axes — current state

| Axis | Status |
|---|---|
| mt7925e (WiFi PCIe driver) | Ruled out round 3 (boot-time blacklist, system still crashed) |
| amdxdna, amd_isp4, pinctrl_amdisp, i2c_designware_amdisp, amd_pmf | Ruled out round 4 *modulo* round-4 test still seeing a different failure mode |
| mt7925_common (WiFi+BT shared lib) | **Not yet tested** — was loaded in round 4 via BT |
| amdgpu | **Not yet tested** — intentionally left on through rounds 1–4 |
| BIOS / EC / SMU / PSP firmware | Not yet tested. Plan to LVFS-update if round 5 dirty |
| RAM | Not yet tested. memtest86+ if BIOS update doesn't help |
| Out-of-tree-young (snd_sof_amd_*, cs35l56) | Lower priority; audio path, no crash signature pointing here |

## Carry-forward clues

The 16-byte writes from rounds 2 and 3 may match a producer struct
field offset once we know the producer. Round 2:
`0x1a8d08fa_a9230d68 0xf65e91b6_fe99cf9d` at offset 1728 of
`skbuff_small_head`. Round 3:
`0xd6065ebc_851f37d2 0x503b9c35_f43b9c35` (approx) at offset 48 of
`anon_vma_chain`. Two pointer-shaped values, struct-aligned, with
surrounding poison untouched = stale list_head write
(list_add/list_del on a freed object). If round 5 panics with the
holder identified, walk that thread's locals/registers and look
for ~8-byte struct fields whose values match those bit patterns.
