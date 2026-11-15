# Balance 11-11: 12x12 bot duels and kit parity

PARITY FIRST (briefs/DECISIONS.md 2026-11-07): every kit is compared with its SUPERVIVE source before
any tuning. Findings split in two: **differs from source** (fixed to the source, one commit each, for
coordinator review) and **source-faithful but broken in our build** (explained, not changed). Owner
rules beat the source data (DECISIONS line 2; the burst cap in SERVER_UPDATE6 is one).

## The simulator
`godot --headless -- --duel-sim [--duel-sim-n=12] [--duel-sim-diff=hard] [--duel-sim-only=a,b]
[--duel-sim-t=60] [--duel-sim-out=<file>]` (tools/duel_sim.gd), then
`python3 tools/duel_sim_report.py <file>` for the tables below.
- The duel room, both fighters bots on the **same mind** (Hard: skill 0.72, react 0.28; damage scale
  1.0 for both, since the room's own 0.82 bot scale would only hit one side), level 6 so R is open
  (both grow the same; the bot spends its points by the kit's `order`). **No Boki, no gloves** (the
  room's glove rack is taken away: bots picked Quake and Blink up mid-duel, ~15% of all damage, unevenly).
- A fresh match per round: full health and armour, every cooldown ready. A round ends at the first knock
  (win) or 60 s (draw, counted half). TTK = seconds from the round's first hit to the knock.
- Every unordered pair runs 12 seeds from each mark (mirrors once per seed): 1,728 rounds, ~1 s each.
  The mark matters little (48/52 over all rounds) and cancels because each pair plays both ways.
- Damage by slot: the hit's CombatBus tags. Generic "abil" hits now carry the kit's own slot key as a
  second tag (`Match.on_damage`, one line more), so Tenzo's rocks and Motley's orbs file correctly.
  **Burn ticks take health directly (`Ent`, outside CombatBus)**; the sim sums them per round and files
  them under Passive (Cinder's Ignite is the only kit burn).
- Noise: a Hunter's overall win rate stands on 264 rounds (about +-3%); one matchup cell on 24 (about
  +-10%). The 12 mirror cells (expected 50) spread 25-79: read single cells with that in mind.
- Seeds: kit bots roll the global `randf()`; the sim now seeds it per round so a round replays exactly
  (the first run did not: 44 of 756 re-run rounds came out differently).

## Results (base: before the parity commits)

### Win rate matrix (row beats column, %; 1728 rounds)

| | Vex | Kael | Cinder | Meeko | Tenzo | Lace | Grimble | Neve | Sparkle | Mossy | Sable | Motley |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Vex** | 42 | 19 | 62 | 88 | 54 | 71 | 71 | 17 | 38 | 85 | 50 | 88 |
| **Kael** | 81 | 50 | 56 | 62 | 100 | 100 | 96 | 54 | 54 | 98 | 71 | 96 |
| **Cinder** | 38 | 44 | 62 | 83 | 62 | 69 | 88 | 65 | 46 | 100 | 25 | 81 |
| **Meeko** | 12 | 38 | 17 | 42 | 44 | 50 | 31 | 21 | 17 | 81 | 8 | 50 |
| **Tenzo** | 46 | 0 | 38 | 56 | 79 | 75 | 46 | 27 | 21 | 75 | 25 | 58 |
| **Lace** | 29 | 0 | 31 | 50 | 25 | 42 | 29 | 6 | 8 | 85 | 6 | 50 |
| **Grimble** | 29 | 4 | 12 | 69 | 54 | 71 | 25 | 21 | 21 | 83 | 29 | 71 |
| **Neve** | 83 | 46 | 35 | 79 | 73 | 94 | 79 | 75 | 52 | 81 | 71 | 83 |
| **Sparkle** | 62 | 46 | 54 | 83 | 79 | 92 | 79 | 48 | 38 | 96 | 62 | 92 |
| **Mossy** | 15 | 2 | 0 | 19 | 25 | 15 | 17 | 19 | 4 | 50 | 4 | 40 |
| **Sable** | 50 | 29 | 75 | 92 | 75 | 94 | 71 | 29 | 38 | 96 | 25 | 75 |
| **Motley** | 12 | 4 | 19 | 50 | 42 | 50 | 29 | 17 | 8 | 60 | 25 | 33 |

### Per Hunter

TTK p90 below was taken one rank low (floor index; fixed to nearest rank after the run): at 100+ knocks a Hunter that is one
sample under the true p90, well inside the seed noise.

| Hunter | Win % (mirrors out) | Rounds | Draws | TTK median s | TTK p90 s |
|---|---|---|---|---|---|
| Vex | 58 | 264 | 4 | 8.5 | 22.0 |
| Kael | 79 | 264 | 3 | 8.4 | 15.8 |
| Cinder | 64 | 264 | 7 | 13.0 | 24.7 |
| Meeko | 34 | 264 | 5 | 13.7 | 41.8 |
| Tenzo | 42 | 264 | 15 | 13.5 | 34.1 |
| Lace | 29 | 264 | 4 | 10.9 | 30.6 |
| Grimble | 42 | 264 | 3 | 11.9 | 24.8 |
| Neve | 71 | 264 | 7 | 8.3 | 26.4 |
| Sparkle | 72 | 264 | 2 | 7.8 | 21.8 |
| Mossy | 14 | 264 | 40 | 36.0 | 48.2 |
| Sable | 66 | 264 | 1 | 7.1 | 14.9 |
| Motley | 29 | 264 | 6 | 13.3 | 28.2 |

### Damage share by slot (% of all damage the Hunter dealt to the other Hunter)

| Hunter | LMB | RMB | Dash | E | R | Passive | Env | Other |
|---|---|---|---|---|---|---|---|---|
| Vex | 76 | 3 | 0 | 11 | 10 | 0 | 1 | 0 |
| Kael | 43 | 34 | 5 | 3 | 15 | 0 | 0 | 0 |
| Cinder | 27 | 22 | 0 | 4 | 3 | 45 | 0 | 0 |
| Meeko | 80 | 19 | 0 | 0 | 0 | 0 | 0 | 0 |
| Tenzo | 78 | 18 | 1 | 0 | 0 | 0 | 2 | 0 |
| Lace | 56 | 22 | 0 | 14 | 8 | 0 | 1 | 0 |
| Grimble | 75 | 4 | 0 | 12 | 9 | 0 | 0 | 0 |
| Neve | 31 | 26 | 0 | 0 | 10 | 32 | 1 | 0 |
| Sparkle | 37 | 12 | 44 | 3 | 2 | 0 | 0 | 0 |
| Mossy | 68 | 6 | 6 | 0 | 19 | 0 | 1 | 0 |
| Sable | 84 | 4 | 0 | 3 | 8 | 0 | 0 | 0 |
| Motley | 88 | 0 | 0 | 10 | 1 | 0 | 0 | 0 |

### Outliers

- Hunter outside 40-60%: Kael 79%, Sparkle 72%, Neve 71%, Sable 66%, Cinder 64%, Meeko 34%, Lace 29%, Motley 29%, Mossy 14%
- Matchups past 80/20: 27: Kael over Vex 81%; Vex over Meeko 88%; Neve over Vex 83%; Vex over Mossy 85%; Vex over Motley 88%; Kael over Tenzo 100%; Kael over Lace 100%; Kael over Grimble 96%; Kael over Mossy 98%; Kael over Motley 96%; Cinder over Meeko 83%; Cinder over Grimble 88%; Cinder over Mossy 100%; Cinder over Motley 81%; Sparkle over Meeko 83%; Meeko over Mossy 81%; Sable over Meeko 92%; Neve over Lace 94%; Sparkle over Lace 92%; Lace over Mossy 85%; Sable over Lace 94%; Grimble over Mossy 83%; Neve over Mossy 81%; Neve over Motley 83%; Sparkle over Mossy 96%; Sparkle over Motley 92%; Sable over Mossy 96%
- One slot over 60% of a Hunter's damage: Vex LMB 76%, Meeko LMB 80%, Tenzo LMB 78%, Grimble LMB 75%, Mossy LMB 68%, Sable LMB 84%, Motley LMB 88%


## After the parity commits (Vex and Kael pairs re-run, 528 rounds)

| Hunter | Base win % | After | TTK median base / after s |
|---|---|---|---|
| Vex | 58 | 55 | 8.5 / 9.0 |
| Kael | 79 | 79 | 8.4 / 8.4 |

Everyone else moves 0-2 points (noise). Longneedle was 11% of Vex's damage and the hook 3% of Kael's,
so neither fix changes the picture: both are parity corrections, not balance levers.

## Outliers explained

**Source-faithful but broken in our build** (not changed: each touches a core system or an owner call)
1. **Cinder 64% on 6 damage a second of hits: burn skips armour and CombatBus.** Ignite's burn is 45% of
   her damage. `Ent` takes burn ticks straight off health (scripts/match/ent.gd, the `burn_t` block), and
   `Hunter.hurt` also skips armour for `src` "burn"; our armour is 2.2x base health, so a burn point is
   worth about 3x a hit point. The source's Ignite is a plain DoT (no tooltip says it ignores armour).
   The ticks also never reach `Match.on_damage`, so nothing on CombatBus (the duel room's numbers,
   anything counting damage) sees them. Fix needs a design note (combat is a core system): route burn
   ticks through `hurt` with armour. Proposed, not built.
2. **Kael 79% (100% against Tenzo and Lace).** Every Kael ratio matches the source. Heavy health sits at
   the top of the health bar (1.249x the source share, docs/KIT_PARITY.md "Health"), and the duel room is
   a small open island where melee closes for free and Hard bots do not kite. KIT_PARITY's "lower heavy
   to ~185" suggestion is the source-ward lever; it moves a whole weight class, so it is the owner's call.
3. **Sparkle 72%: Wirerun is 44% of her damage.** A pass through a 4-Static foe hits double, sets off a
   Blowout and resets the dash. Base and rank-3 numbers match the source, and the payoff is still below
   it (docs/heroes/mage.md: the source's detonation is ~9 bolts, ours ~6.5 with the double), so it is
   not cut. In a 1v1 every bolt lands on the one foe, so Static sits at 4 and the reset loops.
4. **Mossy 14%, 40 draws, 36 s median TTK, 3.3 damage a second.** A shield frontliner whose E heals (0%
   of damage, by design) and whose bot holds the Aegis; a duel shows only the trading half of the kit.
5. **Meeko 34%**: a healer whose R heals a teammate (unused in a duel, `NO_ULT` in --bot-kit-use).
   **Motley 29%**: Singularity has no damage (source the same) and the Anomaly pays for hold time the
   bot rarely gives it. **Lace 29%**: a light (124) charge-bow; her tooltip gives no bow number to check.
   All three are source roles a 1v1 undervalues; Arena/extraction tests should judge them.

**Differs from source, listed for the next pass (not built)**
- Sparkle Kitefall 22 -> ~10 (2.3x the source ratio; 2% of her damage).
- Sable: Bola 5 -> ~4, pair 13 -> ~8, Encore 4 -> ~6 (11% of her damage together).
- Neve: spear detonation 60 and Rimelock 40 follow the footage (high level), 2.8x / 2.3x the level-1
  tooltip ratio. Needs a level-matched read before any change.
- Cinder's carpet (below): held by the burst cap.

## Kit damage against the source

Source: `briefs/supervive-data/supervive_kits.md` (tooltips; Oath, Shiv, Tetra and Void were read at
level 15). Our numbers are on a smaller scale (health ~1/8), so each ability is compared as a **ratio to
the same kit's basic attack** (level-free; the tooltips' level-15 rows stay comparable). Ours =
`content/archetypes/<id>.json` + the signature weapon (`content/weapons`). Bar 1.25x either way, like the
health audit (docs/KIT_PARITY.md "Health"). `[?]` = the tooltip gives no number to compare.

| Hunter (source) | Ability: ours / source, as x basic | Ratio | Verdict |
|---|---|---|---|
| Vex (Ghost) | Grenade 22/6 = 3.7 / 165:51 = 3.2 | 1.13 | match |
| Vex | Longneedle 36/6 = 6.0 / Railgun 202:51 = 4.0 | 1.52 | **differs: fixed 36 -> 24** (532c6f5d9) |
| Vex | Cinderfall 24/6 = 4.0, zone 6/s = 1.0 / 203:51 = 4.0, 59/s = 1.16 | 1.0, 0.86 | match |
| Kael (Brall) | Slam 3.25, lunge 1.75-2.5, air slam 2.25, spin 2.25, Flame Step 1.13, R 5.4 / 3.0, 1.95, 2.05, 2.3, 1.14, 5.35 | 0.9-1.1 | match |
| Kael | Warchain 8/8 = 1.0 / Feysteel 30:43 = 0.70 | 1.43 | **differs: fixed 8 -> 6** (33f505028), locked in kit_parity.json |
| Cinder (Felix) | Bolt 14, Ram 16, Cloak 7 per 27/s stream = 0.52, 0.59, 0.26 s / 0.41, 0.58, 0.30 s | 1.27, 1.0, 0.87 | bolt at the bar (footage ratios, docs/heroes/ashwick.md); rest match |
| Cinder | Flue Flight carpet 4.5/s = 0.17x stream / 239.2:258 = 0.93x | 0.18 | **differs, held by the owner's burst cap**: see below |
| Sparkle (Joule) | Rod 1.5-2.5, Wirerun 1.67 (x2 at rank 3), Skycall 1.67 / 1.48, 1.70 (+100%), 1.80 | 1.0-1.1 | match |
| Sparkle | Kitefall 22/12 = 1.83 / Thunderstorm 72:90 = 0.80 | 2.3 | differs: docs/heroes/mage.md holds it at 22 for the escape (our reasoning, not an owner note). Proposed 22 -> 10, not built this pass (2% of her damage) |
| Motley (Void) | Primed orb 1.34, Snap 1.06, Anomaly 1.39 up to 3.5x / 1.34, 1.05, 1.39, 3.5x | 1.0 | match |
| Mossy (Oath) | Whirl 2.0, R 1.83 / 1.90, 2.22 | 1.05, 0.82 | match / at the bar |
| Mossy | Hammer smash 3-5.5 / 2.72 at the short hold | 1.1-2.0 | kept: footage full hold 976 = 5.1x (docs/heroes/bulwark.md row (c)) |
| Sable (Shiv) | Bola 0.38, pair 1.0, Encore 0.31 / 0.29, 0.59, 0.43 | 1.33, 1.7, 0.72 | differs (small: bola + R are 11% of her damage). Listed, not changed this pass |
| Neve (Celeste) | Spear 18, detonation 60, Rimelock 40 per Shatter 37 = 0.49, 1.62, 1.08 / 156, 190, 155 per 324 = 0.48, 0.59, 0.48 | 1.0, 2.8, 2.3 | [?]: ours copy the footage (detonation 584 ~ 1.1x a Shatter, a high level); the tooltip is level 1. Level-dependent, not changed; Rimelock is already held by the burst cap |
| Lace, Meeko, Tenzo, Grimble | the tooltips give no basic-attack number (Myth's bow, Elluna's bolt, Tetra's punch, Kingpin's slugs) | - | [?]: Lace's Fury 18 -> 25 = 1.39 vs 326 -> 422 = 1.29 (match) |

**Cinder's carpet and the burst cap.** At the source ratio (25/s) `--ashwick-combo-check` fails "burst:
Flue Flight then the merge never one-shots a full-health light hunter" (ult 118, + merge 136 of 124);
at 18/s 89 + 129, at 12/s 63 + 129, at today's 4.5/s 32 + 118. The merge's own ultimate is most of that
burst (~86), so the cap leaves the carpet ~7/s at most. SERVER_UPDATE6 (owner) wins over the data, so
the number stays; raising it means changing the cap or the merge, an owner call.

## Cost
New: tools/duel_sim.gd (~130 lines), tools/duel_sim_report.py (~140), this doc. Changed: one line in
Match.on_damage became two (the slot tag), the check registry entry, four check lines now read the data,
two numbers in content/archetypes (+ their text), one kit_parity row.
