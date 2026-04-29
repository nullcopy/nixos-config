---
name: Help session findings — round 6
description: Wisp crash triage round 6 — clean with amdgpu re-enabled, pins producer to mt7925_common; round 7 shrinks blacklist to just the mt7925 pair
type: project
---

# Help session findings — round 6

Continuation of crash triage on wisp (HP ZBook Ultra G1a / Strix Halo).
- Round 1: `../help-session-2026-04-29T090255Z/findings.md`
- Round 2: `../help-session-2026-04-29T095446Z/findings.md`
- Round 3: `../help-session-2026-04-29T135100Z/findings.md`
- Round 4: `../help-session-2026-04-29T141642Z/findings.md`
- Round 5: `../help-session-2026-04-29T152450Z/findings.md`

## Where round 5 left off

Clean ≥30 min with the full extended blacklist
(`mt7925e,mt7925_common,amdxdna,amd_isp4,pinctrl_amdisp,i2c_designware_amdisp,amd_pmf,amdgpu`).
That ruled out RAM, BIOS/firmware, and (jointly) the five young
auxiliary drivers, and pinned the producer to one of `{amdgpu,
mt7925_common}` or a shared dependency. Round 6 plan: half-bisect by
dropping amdgpu from the blacklist while keeping the WiFi-7 lib off,
to see which side of the pair is actually responsible.

## Round 6 result — 2026-04-29

**Clean.** With amdgpu re-enabled (Wayland/X back) and
`mt7925e,mt7925_common,amdxdna,amd_isp4,pinctrl_amdisp,i2c_designware_amdisp,amd_pmf`
still blacklisted, the box ran a normal desktop workload well past
30 minutes with no stall, no oops, no panic. User rebooted out of
the soak voluntarily and re-enabled the modules to get WiFi back for
chat.

## What this tells us

amdgpu is **cleared**. The producer is `mt7925_common` (the shared
WiFi+BT library for the MediaTek MT7925 / WiFi-7 chip) or something
it pulls in. `mt7925e` was already discharged in round 3 (blacklisted
alone, still crashed via the BT path that goes through the shared
`mt7925_common`), so the chain is consistent: keeping `mt7925_common`
out keeps the box stable across all six tested rounds; bringing back
*everything else* including amdgpu and the desktop workload it
enables does not reintroduce the crash.

The five young auxiliary drivers (amdxdna, amd_isp4, pinctrl_amdisp,
i2c_designware_amdisp, amd_pmf) carried a "joint discharge" caveat
out of round 5 — they were blacklisted alongside the live suspects.
Round 6 doesn't strictly resolve that for them either, but with the
real culprit identified, there's no remaining motive to keep them off.
Round 7 will revert all five.

## Hypothesis space — final

| Candidate | Status |
|---|---|
| mt7925_common (WiFi+BT shared lib for MT7925) | **Producer.** Stays blacklisted. |
| mt7925e (WiFi PHY/MAC, depends on mt7925_common) | Stays blacklisted to keep `mt7925_common` from being auto-loaded. |
| amdgpu | Cleared, round 6. |
| amdxdna, amd_isp4, pinctrl_amdisp, i2c_designware_amdisp, amd_pmf | Cleared by elimination. To be reverted. |
| RAM | Cleared, round 5. |
| BIOS / EC / SMU / PSP firmware | Cleared, round 5. |

## Round 7 plan

One change to `hosts/wisp/configuration.nix`:

- Shrink `module_blacklist` to just `mt7925e,mt7925_common`.
- Watchdog-panic params (`softlockup_panic=1`, `panic_on_rcu_stall=1`,
  `rcu_cpu_stall_timeout=15`) stay on as a safety net — if anything
  surprises us, we want the multi-CPU dump.
- `slub_debug=FZP`, `slab_nomerge`, `panic_on_warn=1` also stay on for
  the same reason. These can be peeled later once we have a few weeks
  of stability.

Soak conditions: full graphical session, full hardware load aside from
WiFi/BT (still off — they need `mt7925_common`). Plug in for any
network needs. Run normally for ≥30 min, ideally with the workload
that triggered round 4 (quickshell + typical desktop).

## Outcomes

| Outcome | Interpretation | Round 8 |
|---|---|---|
| Clean ≥30 min | This is the long-term config. The auxiliary drivers were innocent; only the mt7925 pair has to stay off. | Lock down. File an upstream report against the `mt76` driver / `mt7925` family with the round-2 and round-3 oops as evidence. Optionally, on a separate branch, re-enable `mt7925_common` alone to confirm it crashes — closes the bisect — but live config stays with it off. |
| Crashes return | One of the five auxiliary drivers we just reverted is the real producer (or co-conspirator), and round 6 was a false-clean because they were also off. | Re-add the blacklist, then bisect them one at a time: blacklist four, leave one in, soak; rotate. |
| Different crash signature (new pstore dump, different stack) | A second latent bug, separate from mt7925. | Read the new dump on its own merits. |

## Carry-forward clues

The 16-byte pointer-shaped writes from rounds 2 and 3 are still
unmatched to a producer struct. Round 2:
`0x1a8d08fa_a9230d68 0xf65e91b6_fe99cf9d` at offset 1728 of
`skbuff_small_head`. Round 3:
`0xd6065ebc_851f37d2 0x503b9c35_f43b9c35` (approx) at offset 48 of
`anon_vma_chain`. These are the receipts to file with the upstream
mt76 bug report — they pin the corruption to the WiFi/BT data path
even before we knew which module was responsible.

`skbuff_small_head` in particular is a network buffer cache, which
is a strong corroborating signal for a WiFi/BT bug.
