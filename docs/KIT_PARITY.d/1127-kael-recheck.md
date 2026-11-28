## Kael re-check on main cb8941b9cbf (2026-11-27, branch ext/parity-recheck-kael)

Every Kael (`juggernaut`, source Brall) row was re-read on this main against `docs/heroes/juggernaut.md`, `scripts/arch/kits/juggernaut_kit.gd`, `content/archetypes/juggernaut.json` and `content/dash_flow/juggernaut.json`: LMB (press, Searing Wave), RMB (Finishing Slam, Lunge, Haul Slam, Meteor Drop, chain Spin), E (Warchain), dash (Rampage), R (Gilded Riposte), passive (Rage), cancels, the dash-flow rows, ranges, crowd control and knock. The last full read was `1123-vex-kael-recheck.md` (11-23, main dae69e1c59). Since 11-23 nine non-merge commits touched Kael's three files (`git log --no-merges`); five of them moved something that a doc or a pin reads.

Owner rows left alone (11-11 notes first): **RMB is a straight thrust with a short lunge** (Lunge travels 4.5 to 5.4 m, `rmb.lunge.dist` [5.3, 6.35] x 0.85 dash feel; DECISIONS 11-11, `4ea2625c13`), **LMB has no knockback** (neither the slash nor the Searing Wave pushes a foe: the kit header says "Neither knocks foes back", the data has no LMB push key; the wave burns; 11-11, again 11-20), the Meteor Drop as a straight down slam (11-10), the cooldown gap of 10 (Air RMB 7.2 vs 9, R 36 vs 45), the perfect Lunge release (+20%, 6.5 m), the 24 m Warchain leash and tether max, the 0.8 s Rampage dodge-to-rage, Rage's +15% damage.

### Drift since 11-23, with the commit that moved it

| # | Item | Was (doc) | Now (data) | Moved by | Reason | Action |
|---|---|---|---|---|---|---|
| 1 | LMB slash | 8 | 6.5 (`lmb.dmg`) | `8495f5a6b84` (11-24, "TTK: ... damage to the parity bar") | owner 11-24 playtest: hard to do damage; slash share 5.2 of the source's 154 | owner; **fixed** the docs (`juggernaut.md` Scaling, per-slot LMB row; `KIT_PARITY.md` LMB cell) |
| 2 | Finishing Slam | 26 | 18 (`rmb.slam.dmg`; 2.77x the slash, pin 3.0 +/- 0.35 still holds) | `8495f5a6b84` | same playtest | owner; **fixed** the per-slot RMB row and the KIT_PARITY RMB cell |
| 3 | Rampage along / tip | 9 / 18 | 6 / 12 (`dash.hit_dmg`, `tip_dmg`) | `8495f5a6b84` | same playtest | owner; **fixed** the per-slot Dash row and the KIT_PARITY Dash cell; the "Rampage 2 with tip 4" share in the Scaling paragraph was wrong (5.9, tip 11.8) and is corrected |
| 4 | Warchain hook | 6 (0.75x the slash) | 4 (0.62x; pin 0.7 +/- 0.1 holds) | `8495f5a6b84` | same playtest | owner; **fixed** the Throwing row and the KIT_PARITY E cell |
| 5 | Time to knock (`--ttk-check`) | LMB 8.47 s (0.65x), combo 4.78 s (0.62x), combo max 3.18 s (0.45x) | LMB 10.65 s (0.82x), combo 6.25 s (0.81x), combo max 3.80 s (0.54x, FAIL, owner call) | `8495f5a6b84` | follows 1 to 4 | **fixed** the Scaling paragraph and the KIT_PARITY "Still open" line; `docs/TTK.md` already had them |
| 6 | Meteor Drop fall | 24 m/s, 0.12 to 0.35 s | 30 m/s, 0.08 to 0.35 s (`rmb.drop.dive_speed`, `dive_t`); the Lunge may strike a foe up to 2.0 m above or below (was 1.6) | `11f59f9183d` (11-26, `--air-rmb-feel-check`) | the source's air slam fall is 30 m/s | parity (closer to the source); hero doc per-slot row already says 30 m/s; **added** to the KIT_PARITY air RMB cell |
| 7 | Model and plate numbers | `body.size` 0.95, hit radius 0.428, nameplate 2.75 m | `size` 0.825, `hit_r` 0.429 (`body_r` 0.428, the doc had read the body radius as the hit radius), `hit_h` 2.15, `top_h` 1.52, `plate_offset` 2.26 | `3a50a38abb9` (11-18, size), `a8b4449e37e` (11-15, hit data), `10d343ad6eb` (11-18, plate), `2874a59b082` and `5e2fc28389e` (11-26, `top_h`) | visual and hurtbox data to the chart heights (`docs/HITBOX_SIZE.md`); no kit effect | **fixed** the Body and movement section |
| 8 | Passive gauge | Rage had no bar | Rage shows a fill bar (`gauge: true`) | `181c391ea5f` (11-25) | HUD only: the numbers (6 s Enraged, +15% damage, +12% dash recharge, +20% cooldown speed, knock heals 20%) are unchanged | none; not a kit change |
| 9 | Lunge lane and trail look | an arrow-tipped lane | a straight crimson lane, soft streak ribbon | `8571a03bf13`, `8fe6d6f4b0b` (11-25) | visual only; the 11-11 "straight thrust" note is the footage's shape and is now also the telegraph | none |
| 10 | Anim row | 22 moves, `kael.glb` clips (54) | the same 22 moves and 54 clips, plus `kael_clips.glb` 12 native clips (`kmoves` in `warden_native.json`: slash r/l, wave wind/wave, slam, lunge wind/lunge, chain, reel, guard, riposte, ult recover) | `5f841372691` (11-23), merged by `a8f45383864` (11-24) | native clips on the v95 body | **fixed** the KIT_PARITY Anim cell |
| 11 | Warchain hook blight | two contradicting Throwing rows: "blighted while tethered" and "no blight from the hook" | no blight from the hook; only the Cinder Spin blights (`juggernaut_kit.gd` applies `blt` in the spin only; asserted in `dancer_jug_check.gd` "Warchain hooks (no blight ...)") | docs only (the code has only ever blighted in the spin) | the footage and data put Anti-Heal on the spin | **fixed**: the stale row is removed |
| 12 | Ult reset on a monster | Small-mechanics row: "a monster or a wisp resets nothing"; the next row: "a hunter, a monster or a foe Boki; not a wisp" | the second (code, `4ea2625c13`, 11-20) | `4ea2625c13` | the data's "killing a living enemy" | **fixed** the first row |
| 13 | Kit number golden (`tools/goldens/kit_numbers.tsv`) | `rmb.drop.dive_speed` 24.0, `dive_t[0]` 0.12 | 30.0 and 0.08 | `11f59f9183d` changed the data and not the snapshot; `python3 tools/health.py --strict` printed KIT GOLDEN FAIL for these two Kael rows | the same parity change as row 6 | **fixed**: the two rows edited by hand to the data (a full `--bless` would also have taken Dredge `arrive_stun` and Dolm `rock.slow_*`, which are not Kael's and are left red) |

### Not moved (re-read and still true)

- LMB cadence .34, tip 1.6x (tap .22, full .95), reach 3.1, arc 175; Searing Wave 12 to 20, range 7 to 14, 36 m/s, burn 4 s, walk 55% while it charges.
- Slam lane 4.3 x 0.72, push 6, sweet spot +40%, low +50% under 35%; Lunge 14 to 20 over 4.5 to 5.4 m, walk 80%, a miss doubles the cooldown; Haul Slam 16 to 30; Meteor Drop 18 in 2.4 m (core 1.2, +50%, stun 0.8 s), cd 7.2; chain Spin radius 2.2.
- Warchain range 13, 32 m/s, holds 5 s, pull 22 m/s, tether max 24, cd 12.8 (11.2 and 8 at ranks 2 and 3).
- Gilded Riposte guard .65, strike .1, recover .35, 3.6 x 1.8, 43 damage, heal 80%, cd 36 (32 and 28 at ranks 2 and 3).
- Rampage 4.5 m / .17 s raw, 0.07 s dip, cd 10.4 (8.8, 6.4 at ranks 2 and 3), two charges and a third at rank 2, no knock.
- Every `kit_parity.json` Kael pin: `e.dmg` per `lmb.dmg` 0.7 (4 / 6.5 = 0.62, inside 0.1), `slam.dmg` per `lmb.dmg` 3.0 (2.77, inside 0.35), `slam.len` 4.3, `slam.width` .72, `drop.radius` 2.4, `spin.radius` 2.2, `e.reel_speed` 22.5, `e.speed` 31.5.
- Dash-flow rows: `ground` lmb buffer, rmb fire with carry, e fire, x cancel, q fire; `air` rmb cancel, x cancel, e and q fire; `into_dash` lmb and rmb fire, e cancel with carry, x buffer; `hold` keeps; `into_jump.x` lock; `into_cast` rows all fire except x into lmb, rmb and e (drop) and x into lmb_hold (queue, 0.45 s). `content/dash_flow/juggernaut.json` has no commit since 11-23 (the `into_cast` rows landed with `c6369f7de12` and `61c88f9196b`, 11-23).
- CC and knock: Slam knock push 6; the Lunge and the Haul Slam have no knock (owner 11-20); Rampage has no knock; fireblast slow 30%, Chain Lunge stun .35 s, Haul Slam stun .25 to .6 s (ours-only riders, DECISIONS 11-07).

### Still open (none is a number change made here)

- **Kael combo at max rank 0.54x** (`--ttk-check`): an owner call; the fix would be a nerf of the 11-24 note (docs/TTK.md "Owner-override candidates"). Not touched.
- **Lunge, Meteor Drop, chain Spin, Haul Slam and Searing Wave** were not part of the 11-24 cut: they sit at the 11-03 footage ratios, 1.4 to 2x the source share (Meteor 18 against 10.5, Spin 18 against 11.9). Moving them is a damage change; the owner's 11-24 note was "hard to do damage", so they are left.
- **Cooldown gap of 10** (Air RMB, R), the perfect Lunge release, the 24 m leash: owner rows, unchanged.
- The `[?]` rows (Warchain leash 24 m, tether max, dash-flow rows without a source) remain unsourced.

### Not drift (checked and left)

- `docs/heroes/juggernaut.md` line "LMB tip 2.0x" (audit history), the 11-11 and 11-20 audit rows and the "Open rows closed" table keep the numbers of their dates; they are dated history.
- `docs/TTK.md` matrix sections dated 11-11 and 11-20 keep their old Kael numbers.


### Checks (this branch; docs and two golden rows only, so code results equal main's)

| Check | Main cb8941b9cbf | This branch |
|---|---|---|
| `--juggernaut-combo-check` | 327 checks, 0 failures (the 11-23 DASHFLOW failure is gone) | 327 checks, 0 failures |
| `--card-numbers-check` | 348 numbers, 0 failures | 348 numbers, 0 failures |
| `--kit-parity-check` | 0 failures | 0 failures |
| `--ttk-check` (Kael rows) | LMB 10.65 s (0.82x); combo 6.25 s (0.81x); combo rank max 3.80 s (0.54x, the one FAIL, owner call); run total 42 rows, 1 FAIL | the same |
| `--dash-flow-check` | not completed (timed out at 500 s on a loaded worker; no dash-flow file changed; the combo check carries the `DASHFLOW` rows) | same |
| `python3 tools/health.py --strict` | red: style ratchet (`arch_kit.gd` long_line 26 -> 27, `dash_streak.gd` 0 -> 1), `sfx_loudness.py` has no numpy on this worker, KIT GOLDEN (2 Kael rows, 1 Dredge removed, 3 Dredge/Dolm new) | red for the same three reasons; the two Kael golden rows are fixed, the Dredge and Dolm rows are not Kael's and are left; no NEW-RED |
| `python3 tools/gen_wiki.py --check` | red: `Class-Stone-Seer.md#kit`, `Rules.md` | the same two; no page of Kael's changed |
