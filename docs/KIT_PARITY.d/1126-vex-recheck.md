## Vex re-check on main fad508b31c9 (2026-11-26, branch ext/parity-recheck-vex)

Every Vex (`gunslinger`, source Ghost) row was re-read on today's main against `docs/heroes/gunslinger.md`, `scripts/arch/kits/gunslinger_kit.gd`, `content/archetypes/gunslinger.json`, `content/dash_flow/gunslinger.json` and `content/weapons/quill_rifle.json`: LMB, RMB, E, dash, R (Cinderfall), passive (Fever), cancels, the dash-flow rows, ranges, crowd control and knock. The last full read was `1123-vex-kael-recheck.md` (11-23, main dae69e1c59). Four commits touched the Vex data or kit since; one moved a number. No data was changed here: the one drift has an owner reason, so the docs follow the data.

Owner rows left alone: all cooldown ratios (gap 10: RMB 6.5 vs 9, R 42 vs 55), the RMB coin from her free hand, E from her palm, the E yaw lock 30 deg/s, no Cinderfall hold, one Slipstep charge, Palm Lance width, the rifle round and decay below.

### Drift since 11-23, with the commit that moved it

| # | Item | Was (doc) | Now (data) | Moved by | Reason | Action |
|---|---|---|---|---|---|---|
| 1 | Vex rifle round | 6 a round | 8 (`content/weapons/quill_rifle.json` `dmg`) | `8495f5a6b84` (11-24, "TTK: ... damage to the parity bar") | owner 11-24 playtest: hard to do damage | owner; **fixed** the doc rows (`gunslinger.md` Parity pass and Small mechanics, `KIT_PARITY.md` LMB row) |
| 2 | Vex rifle sustain | 10 rounds fall to 50% (the source's) | to 80% (`sustain_loss` 0.2, asserted in `hero_combo_check.gd` as "loses a fifth") | `8495f5a6b84` | same playtest | owner; **fixed** the same rows and the KIT_PARITY intro line |
| 3 | Vex time to knock, LMB | 5.47 s vs source 2.48 (2.20x) | 2.35 s (0.95x) | `8495f5a6b84` | follows 1 and 2 | closes 11-23 "Still open"; `docs/TTK.md` was already updated by that commit |
| 4 | Vex time to knock, combo | 2.72 s vs 1.92 (1.41x), 2.38 vs 1.76 (1.35x) | 1.55 s (0.81x), 1.47 s (0.83x) | `8495f5a6b84` | follows 1 and 2 | closes 11-23 "Still open"; bar 0.8 to 1.25 holds, 0.81 sits at its low edge |
| 5 | Vex Cinderfall rank data | no rank rows in the doc | `x.per_rank`: cooldown -4 a rank (42 to 38 to 34), damage +4.8 (24 to 28.8 to 33.6), fire tick +0.7 (3.5 to 4.2 to 4.9); rank 2 also lengthens the Fusion 30% | `555debe7d28` (11-19, "Ult ranks data ... from the source R tiers") | source R tiers | none (parity); recorded here (the hero doc keeps no rank rows) |
| 6 | Vex Fever light cue | none | `FEVER_DB` -9 dB quiet stim as Fever lights | `761742d0af6` (11-20) | audio polish, no number a kit row reads | none |
| 7 | `GunslingerKit.ready_label()` | returned "" | gone (the plate status row replaced it) | `c6c9537a450` (11-19) | UI declutter | none |
| 8 | `gunslinger_kit.gd` formatting | tab-aligned trailing comments | one space | `0d4e59b7f92`, `cb9c3c56514`, `00114fc7508` (11-24, 11-25) | style ratchet | none (no behavior) |
| 9 | Vex model path | `meshy_native` off, so the contract model `vex.glb` plays her clips (`Warden/Sync` present) | on: the game draws `vex_meshy.glb` | `47f92c4da2b` (11-25), a Revert of `9adfc108de8` (11-24, "meshy_native off again so the contract-model checks stay green"); the `e6205ad1ed6` (11-24) on-commit is back | owner visual call ("drop this commit to keep the contract model") | owner; **open**: `tools/vex_anim_time_check.gd:20` skips every Vex timing row on a native model, so the combo check reads one FAIL ("Vex timing: her clips are on (nothing to time)") and 14 timing checks are not run |
| 10 | `docs/wiki/Class-Hired-Gun.md` hand-written sections | Burr Charge, Longneedle, 10-round decay to 50%, no Cinderfall | Coin Blast, Palm Lance, Cinderfall on X, the Boki Fusion on R, decay to 80% | many (11-11 to 11-24) | stale prose, not generated | **fixed** (hand-written parts only; generated blocks untouched) |

Not moved since 11-23 (re-read, same): rifle cadence 0.08 (~12 rounds/s), mag 30, refill 40/s after 0.35 s; Dazed bonus +76% (`rattle_k` 0.76); Coin Blast 22 / 16, range 10.5, cone 6 m at 100 degrees, push 11, stun 0.7, cd 6.5; Palm Lance charge 0.6, range 18, half-width 0.9 (width 1.8), damage 24, recoil 6, shave 20% / 30%, cd 11.5, yaw lock 30 deg/s (`turn.e.early`), 0.6 s recovery; Cinderfall cd 42, delay 1.6, damage 24, radius 3.4 (core 1.2), zone 3 s, tick 3.5 every 0.5 s, slow 30%, range 14, 0.25 s wind-up at 70% walk; Slipstep one charge, tap 4.8 m in 0.45 s, hold 7 m at +40% cooldown, cd 8.5; Fever vamp 0.06, wait 3.5; dash-flow rows; `kit_parity.json` Vex rows (the file moved by one Sable row, not Vex).

### Still open (none is a number change made here)

- **Cooldowns** (gap 10, owner): RMB 6.5 (source 9, footage 5.4), R 42 (55).
- **Unsourced `[?]`**: Cinderfall range 14 (no clamp seen) and the hold-slide length.
- **Time to knock, combo rank 0 at 0.81x** is 0.01 over the bar's edge; one more owner damage tweak could cross it.
- **Vex timing check cannot run on the native model** (row 9): `tools/vex_anim_time_check.gd` times `Warden/Sync` clips, which the native path does not build. Either the switch goes back off or the timing check learns the native player; that is the owner's call on the model, so it is not touched here.
- **Failing checks on main, not touched here** (`--gunslinger-combo-check`, 5 of 153, identical with and without this branch): the four from 11-23 (RMB direct-hit body flash 0.02 against a lit time above 0.12 s; `air steer gunslinger` carry 4.6 m/s after the Palm Lance recoil; `Vex sounds` reading the string's top-up kit sounds; `Vex cancel E recovery + any` with the jump, RMB and LMB inside 0.1 s of the beam) and the new timing one (row 9).

### Not drift (checked and left)

- `docs/KIT_PARITY.md` still carries dated snapshot sections that name Burr Charge, Longneedle and the 11-10 numbers (hit shapes 11-12, crowd control 11-09, knock table 11-19, casting speed 11-12, starter trio 11-10). They are labelled with their date and were not rewritten.
- `docs/TTK.md` matrix section (a dated snapshot) still shows the 11-23 Vex numbers; its table and note at the top were updated by `8495f5a6b84`.
- `docs/wiki/Rules.md` was out of date on main (cc_guard and farm rows); regenerated with `tools/gen_wiki.py`.

### Checks (this branch)

| Check | Main fad508b31c9 | This branch |
|---|---|---|
| `--gunslinger-combo-check` | 153 checks, 5 failures | 153 checks, the same 5 failures (docs only) |
| `--card-numbers-check` | 344 numbers, 0 failures | 344 numbers, 0 failures |
| `--ttk-check` (Vex rows) | LMB 2.35 s (0.95x); combo 1.55 s (0.81x), 1.47 s (0.83x); RMB hit 1.11, E hit 0.99; run total 42 rows, 1 FAIL (Kael combo rank max 0.54) | the same |
| `python3 tools/health.py --strict` | red, not touched by this branch (docs only): style ratchet `scripts/match/boki_rig.gd` long_line 0 -> 1 and `tools/tutorial_dead_air_check.gd` long_line 0 -> 1; `tools/sfx_loudness.py` cannot import numpy on this worker | red, the same two files and the same numpy error; NEW-RED 0 |
| `python3 tools/gen_wiki.py --check` | red: `Rules.md` | OK after regenerating `Rules.md` |
