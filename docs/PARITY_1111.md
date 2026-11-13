# Parity check of the 11-11 owner-playtest branches (2026-11-11)

These branches changed kit numbers after the KIT_PARITY re-audit (`origin/ext/parity-audit-0244` 4250ac165), and none of them is on main 88b06b9e7 yet:

| Branch | Tip | Base |
|---|---|---|
| ext/lace-one-bow | 3b8003105 | main 88b06b9e7 |
| ext/kael-owner-1111 | 4cb48148d | release-integ-0245 272368589 (+ ext/parity-kael-slam-lane 704b7636e) |
| ext/neve-1111 | 75ae3382d | release-integ-0245 272368589 |
| ext/neve-cancels-1111 | 5280b1ab9 | ext/neve-1111 (adds docs and checks only, no kit change) |
| ext/motley-1111 | 5cb30de95 | release-integ-0245 272368589 |
| ext/sparkle-dash-1111 | 58b71c07d | release-integ-0245 272368589 |
| ext/vex-rmb-1111 | a796f3a38 | main 88b06b9e7 |
| ext/meeko-rmb-1111 | a2e62336b | main 88b06b9e7 |

**Method.** For each branch I diffed `content/archetypes`, `content/rules` and `scripts/arch` against its base. I checked every changed number, cancel and timing against `briefs/supervive-data/supervive_kits.md` [D] and `briefs/hero-ref/<sheet>.md` [F] (1 bh = 1.8 m, 5 fps, so a time read is good to about 0.2 s). Trust order is O (owner) > D > wiki > F. Text-only and look-only changes are listed only where they change what a player can read or aim by.

**Verdicts.**
- `match`: the same as the source, within footage error.
- `differ (owner)`: an owner note covers the change; it stays unless the owner reverses it.
- `drift`: moved away from the source with no owner note. These would be fixed here.
- `ours-only rider`: the source is silent, and the rule is ours.

**Result: no drift.** Every change is either owner-direct (11-11 playtest, noted on the branch) or brings the kit closer to the source, so I changed no numbers. The open points for the owner are listed at the end.

## Rows

| Hero (source) | Change (branch) | Ours, base -> branch | Source | Verdict |
|---|---|---|---|---|
| Kael (Brall) | Finishing Slam shape (kael-owner-1111, via parity-kael-slam-lane) | `rmb.slam` radius 4.0 m, a 70° cone -> a lane 4.3 x 0.72 m (`len`, `width`) | F 0157-0158: the strike reaches 2.4 bh (4.3 m) down a magenta lane 0.4 bh wide with parallel sides | match (pinned in kit_parity.json, tol 0.18 / 0.09) |
| Kael | Slam wind-up: planted, lane locked at the press | wind-up 0.6 s (unchanged); move during the wind-up 0.6x -> 0 (`move_k`); the lane follows the aim -> locks at the press | F: a ~0.6 s wind-up, blade cocked low; the lane shows only at the end of the wind-up; nothing on whether he moves | differ (owner): lock at the press, and planted |
| Kael | Lunge hold: nothing drawn ahead | the red, then magenta, lane growing ahead -> none; blade overhead; full at 0.8 s (`full_t`, unchanged) | F 0124-0126: a red lane grows ahead, magenta at full, full after 0.6-0.8 s | differ (owner): no lane; the full time matches |
| Kael | Chain Lunge removed | a hold let go on a hooked chain ran down it, x1.25 damage and a 0.35 s stun (`lunge.chain_deg` 30) -> a plain Lunge along the aim; `chain_deg` deleted | D: Adaptive Strike has no chain lunge (only the Spin while pulling) | match (drops the ours-only rider KIT_PARITY flagged, "Chain Lunge stun 0.35 s") |
| Kael | Chain breaks past its length during the hold or Lunge | held him at the chain's length -> breaks | F 0305-0317: the tether stays on while he walks about 2.5 s; no leash length shown | ours-only rider (owner 11-11) |
| Kael | Meteor Drop centre | 2.4 m circle 0.8 m ahead in the facing (`drop.ahead`) -> centred under him; `ahead` deleted | F 0263, 0286: a ~1.2 bh disc at the cursor (cursor-placed) | differ (owner): 11-10 made it straight down, 11-11 put it under him |
| Kael | Warchain pull arc hidden from the Smash's press to the Lunge's end | shown -> hidden | F: no lane seen for the chain at all | ours-only rider (a look, owner 11-11) |
| Neve (Celeste) | Skate steering (neve-1111) | `dash.steer` 3.6 rad/s instant -> a 1.6 rad/s cap that builds over ~0.17 s; a full skate bends ~131° at most (was a U-turn in 0.87 s) | D: "HOLD to skate"; F: "Follows the movement input"; no turn rate given | differ (owner): source silent on the rate |
| Neve | Skate release | a hard 0.3 speed cut (~0.2 m) -> `dash.slide_out` 0.7: the release keeps 70% of 11.5 m/s into the ground brake, ~0.8 m over 0.25 s (the unused `dash.stop` 0.15 deleted) | D: "release to stop"; F: stops within 0.1-0.2 s of the release | differ (owner): 0.25 s against 0.1-0.2 s (about one frame over) |
| Neve | Chill read: ice shards in the foe replace the CHILL/FAN/COMBO badges | look only, no numbers | D: Chill 4 s, 8 darts = Shatter (unchanged) | ours-only rider (a look, owner 11-11) |
| Neve | Cancels re-walked (neve-cancels-1111) | docs + `--neve-feel-check` rows only | as in rimewright.md: slide-out rows match D, the rest `[?]` | match (no kit change) |
| Motley (Void) | Lantern Trade circle (motley-1111) | `dash.radius` 1.5 -> 1.9 m (the lantern drawn 1.3 -> 1.65x) | F 0156-0157: the landing circle is about 1.5 h across (~1.35 m radius); D gives no number | differ (owner): "a bit bigger", ostra.md; 1.5 was nearer the footage |
| Motley | Trade lands on top of a ledge or cliff under the cursor, never in a wall | landed at the cursor point, could end in rock -> top surface, settled clear (OstraLand) | D: "lob a projectile that swaps you ... to its location"; F: lands at the cursor | match (lands at the cursor; never-in-a-wall is our safety) |
| Motley | Brimseed: no world "E AGAIN" marker | look only | F: no recast marker described | match |
| Sparkle (Joule) | Wirerun lane (sparkle-dash-1111) | `dash.dist` 5.6-9.75 -> 6.02-10.48 m; `speed` 40 -> 43 m/s (a full run still takes 0.24 s) | F 0102-0108: full length ~7.5-8 bh (13.5-14.4 m) in ~0.6 s (~23 m/s); D gives no number | differ (owner): +7.5% moves toward the source length; speed and time stay ours |
| Vex (Ghost) | Burr Charge miss (vex-rmb-1111) | a lane end on nothing stuck to the ground and blasted the cone -> a dud (no damage, no Daze, no cone), on the ground or from the air | D: "If it hits a wall it explodes in a cone"; F 0044-0045: a miss flies past the cursor, no blast | match (owner item 130 asks the same) |
| Vex | Burr rides up ramps and low ledges; only a strict wall stops it | already on main (ext/vex-rmb-terrain-rebased), so no change | F: sticks to the first enemy or wall | match |
| Vex | Daze rifle bonus shown on its own (pink +N) | look only; +90% unchanged | D: +39 per 51-damage round (+76%); F: ~1.9x | no change (the 0.24.4 audit row stands) |
| Vex | Other games draw the stuck Burr's cone (net_cone, Net.VERSION 0.24.4 -> 0.24.5) | the cone 6 m, 100°, 0.9 s, unchanged | F: a 100° cone ~3.5 bh, 0.6-0.8 s | match (sync only) |
| Meeko (Elluna) | Burrseed wind-up (meeko-rmb-1111) | `rmb.windup` 1.0 -> 0.6 s (pip.json `mm_seed_aim` fit 0.6) | D: no cast time; F 720.9-722.4 s: a held aim (~1 s, the player's choice), then a ~0.3 s release hop | differ (owner): a forced 0.6 s, not a held aim |
| Meeko | Seed start point | 0.6 m out, 0.95 m up -> 0.8 m out, 0.72 m up (hand height) | F: a forward push of both arms | match |
| Meeko | Cast flare | a 1.4 m ring at her feet for the whole wind-up and a flare on her shoulder -> no ring, a half-size flare at the seed's start | F 0109: a large blue-white flare round her, about 1.5 bh, on the cast frame | differ (owner): "nothing at her feet" |
| Lace (Myth) | One bow (lace-one-bow) | an LMB draw and a Heavy Shot hold ran at once -> the newer press drops the held draw, with no arrow and no charge spent | D: no ability tags or block lists for Myth; F 0264-0269, 0494: one reticle at a time, no press mid-draw | ours-only rider (the rule follows the existing LMB -> X row; the alternative was "LMB ignored while the Heavy Shot is held") |

## For the owner (not changed here)

1. **Kael `rmb.drop.radius`.** kit_parity.json still pins it at 2.2 ±0.22, the source's cursor disc, but the data is 2.4. It passes only at the edge of the tolerance, as GATE_0244 and KIT_PARITY already flag. Now that the drop is centred under him, it is even less the source's cursor disc. Choose one: re-pin it at 2.4 as an owner value, or drop the row.
2. **Kael `rmb.slam.sweet_deg` 18.** On the 0.72 m lane this angle almost never decides the sweet spot: a foe can sit up to 0.36 m plus its body radius off the axis, which is about 20° at 2.4 m and less further out. The band (2.4-4.2 m) is what decides it now. The source says "edge hits do more". The row is not wrong, only nearly dead. It could be removed, or the sweet spot could be re-read as "the lane's far end".
3. **Sparkle Wirerun.** It is still about 0.75x the source length and about 1.9x its speed. KIT_PARITY's row ("7.5-13 m at 40 m/s (owner)") is stale against both the base (5.6-9.75) and this branch.
4. **Neve slide-out.** It runs 0.25 s against the footage's 0.1-0.2 s. This is an owner ask; the turn-rate cap has no source number.
5. **Motley Trade radius.** 1.9 m is further from the footage (~1.35 m) than 1.5 was. This is an owner ask ("a bit bigger").
6. **Stale KIT_PARITY.md rows once these merge.** These rows will be out of date:
   - Kael Air RMB: "0.8 m ahead".
   - Kael RMB: "over-head pose", with the lane now hidden.
   - Kael: the ours-only Chain Lunge stun, now gone.
   - Meeko RMB: "windup 1.0".
   - Neve Dash: no steer or slide-out noted.
   - Motley Dash: radius.
   - Sparkle Dash.
   - Vex RMB: the ground blast, now gone.

   KIT_PARITY.md is not edited here, because each of these branches would conflict with it. The integrator should refresh those rows on the train that merges them.
