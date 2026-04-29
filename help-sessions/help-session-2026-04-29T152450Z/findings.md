---
name: Help session findings — round 5
description: Wisp crash triage round 5 — clean soak with extended blacklist; round 6 half-bisects amdgpu vs mt7925_common
type: project
---

# Help session findings — round 5

Continuation of crash triage on wisp (HP ZBook Ultra G1a / Strix Halo).
- Round 1: `../help-session-2026-04-29T090255Z/findings.md`
- Round 2: `../help-session-2026-04-29T095446Z/findings.md`
- Round 3: `../help-session-2026-04-29T135100Z/findings.md`
- Round 4: `../help-session-2026-04-29T141642Z/findings.md`

## Where round 4 left off

Failure mode flipped from a structured 16-byte UAF write (rounds 1–3,
caught by `slub_debug=FZP`) to a hard hang with RCU stall + soft lockup
on `inotify_group->notification_lock` (round 4, captured in
`journalctl -k -b -1`, no pstore because no panic). mt7925_common was
still loaded in round 4 via the Mediatek BT stack, so the WiFi-7 code
path wasn't fully excluded. Round-5 plan: extend blacklist with
`mt7925_common` and `amdgpu` and add watchdog-panic kernel params so
any future stall pstore-dumps the lock holder.

## Round 5 result — 2026-04-29

**Clean.** ≥30 min of normal use with the full blacklist
(`mt7925e,mt7925_common,amdxdna,amd_isp4,pinctrl_amdisp,i2c_designware_amdisp,amd_pmf,amdgpu`).
No stall, no oops, no panic. User gave up waiting and rebooted, then
re-enabled the modules to get WiFi back for chat.

## What this tells us

The producer lives in `{amdgpu, mt7925_common}` or something one of
them pulls in (DRM helpers, scheduler workqueues, BT host stack,
firmware loaders for either). Everything else on the suspect list —
the other five young drivers (amdxdna, amd_isp4, pinctrl_amdisp,
i2c_designware_amdisp, amd_pmf), as well as RAM and BIOS — is
discharged for now: the system was clean with all of them still
shipping their normal load, just with these two off.

Caveat: the round-5 environment had no GPU compositor and no
networking, so the *workload* during soak was lighter than a normal
desktop session. Round 6 will run with amdgpu re-enabled, which
restores Wayland/X — the more realistic load actually helps reproduce
the bug.

## Hypothesis space — narrowed

| Candidate | Status |
|---|---|
| amdgpu | **Live suspect**, will be re-enabled in round 6 |
| mt7925_common (WiFi+BT shared lib) | **Live suspect**, stays blacklisted in round 6 |
| mt7925e | Discharged round 3 |
| amdxdna, amd_isp4, pinctrl_amdisp, i2c_designware_amdisp, amd_pmf | Discharged round 5 (clean with all blacklisted, but so were the live suspects — see "joint discharge" below) |
| RAM | Discharged for now (clean soak rules out broad memory corruption under that workload) |
| BIOS / EC / SMU / PSP firmware | Discharged for now (same reason) |

**Joint discharge caveat.** The five young drivers were blacklisted
*together* with amdgpu and mt7925_common in round 5. We can't strictly
prove they're individually innocent — only that they don't crash the
box on their own when the two big suspects are off. If round 6 doesn't
narrow cleanly (e.g. clean with amdgpu on, dirty with amdgpu off and
mt7925_common on), we may need to revisit them.

## Round 6 plan

One change to `hosts/wisp/configuration.nix`:

- Drop `amdgpu` from `module_blacklist`. Keep everything else
  (`mt7925e,mt7925_common,amdxdna,amd_isp4,pinctrl_amdisp,i2c_designware_amdisp,amd_pmf`).
- Watchdog-panic params (`softlockup_panic=1`, `panic_on_rcu_stall=1`,
  `rcu_cpu_stall_timeout=15`) stay on. Any stall now panics with the
  full multi-CPU dump in pstore.
- `slub_debug=FZP`, `slab_nomerge`, `panic_on_warn=1` stay on. Catches
  the structured UAF presentation if that's what comes back.

Soak conditions: graphical session is back (amdgpu loaded), WiFi/BT
still off. Run a normal desktop workload for ≥30 min — the previous
crashes hit within a few minutes, so 30 min is generous.

## Outcomes

| Outcome | Interpretation | Round 7 |
|---|---|---|
| Clean ≥30 min | mt7925_common (WiFi+BT shared lib) is the producer. amdgpu is innocent. | Lock down: keep `mt7925e,mt7925_common` blacklisted permanently; revert the other six. File upstream against mt76 driver. Optionally re-enable mt7925_common alone to confirm dirty (full bisect). |
| Stalls / panic with all-CPU dump in pstore | amdgpu is the producer (or a path it pulls in). | Read the multi-CPU pstore dump — the lock holder names the function. Possibly narrow within amdgpu (DPM, SMU, scheduler, display) by trying `nomodeset` or `amdgpu.dc=0` etc. |
| Stalls without panic | Watchdog params didn't fire even though we thought they would in round 5+. Unlikely given round 4's RCU stall was already 21s — `rcu_cpu_stall_timeout=15` should preempt that. If it happens, fall back to firmware axis (LVFS BIOS update). | — |

## Carry-forward clues

The 16-byte pointer-shaped writes from rounds 2 and 3 are still
unmatched to a producer struct. Round 2:
`0x1a8d08fa_a9230d68 0xf65e91b6_fe99cf9d` at offset 1728 of
`skbuff_small_head`. Round 3:
`0xd6065ebc_851f37d2 0x503b9c35_f43b9c35` (approx) at offset 48 of
`anon_vma_chain`. If round 6 panics and names a function, walk the
holder thread's locals/registers for these bit patterns.
