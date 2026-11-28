## Self-slow while firing, charging or carrying: reference vs ours (`--move-feel-check` fire_slow rows, 2026-11-28)

Reference = the 11-27 catalog (meshy/sv-refs/source-notes/CATALOG-13-1127.md, cross-hunter pattern 6 and the hero
sections; "x" = share of move speed). Ours = the data (`content/weapons/*.json` `fire_slow`/`draw_slow`, the kit rows
in `content/archetypes/*.json`), applied as one multiplier on the one run (`Hunter._move_mult`, then
`HunterMove.ground_speed`: bonuses add, slows multiply). Owner rules kept: one blended move, no sprint, no new
constant in hunter.gd. `tools/move_feel_fire_slow.gd` asserts every row below on the real match step, keys held:
the hunter's multiplier within 0.01 of the data and the speed over his own unslowed run within 0.02 (Grimble's
shotgun kick pushes him back on each shot, so his speed may sit up to 0.1 under).

| Hunter (reference) | Move | Reference x | Ours before | Ours now (data) | Verdict |
|---|---|---|---|---|---|
| Lace (Myth) | LMB draw | self-slow, smaller after a perfect (no number) | 0.70, 0.85 after a perfect | 0.70 (`longbow.draw_slow`) | kept (matches the shape) |
| Lace (Myth) | RMB Heavy Shot hold | hold-charge (no number) | 0.38 | 0.38 (`rmb.pin.hold_move`) | kept |
| Cinder (Felix) | LMB Open Flame | none listed while firing | 1.0 | 1.0 | kept (0.6 for 0.35 s after letting go stays) |
| **Cinder (Felix)** | **E Furnace Cloak (Heat Shield spin)** | **0.6 while spinning** | 1.0 | **0.6 for the 0.45 s pull** (`e.spin_move`) | **set** |
| Albert (Oath) | RMB Brightshield held | none listed | 0.60 | 0.60 (`rmb.shield.slow`) | kept: owner #59 |
| **Albert (Oath)** | **Brightshield broken** | **0.6 for 0.425 s** | 1.0 | **0.6 for 0.425 s** (`rmb.shield.break_move`, `break_t`) | **set** |
| Tenzo (Tetra) | LMB punch hold | hold 0.2 s = punch (no number) | 0.85 | 0.85 (`rubble_fists.fire_slow`) | kept |
| Tenzo (Tetra) | RMB Quakefall charge | hold-charge, jump leaps (no number) | 0.55 | 0.55 (`rmb.slam.walk_k`) | kept |
| Grimble (Kingpin) | LMB shotgun | none listed | 0.80 | 0.80 (non-melee default) | kept |
| Vex (Ghost) | LMB Brass Tacks | none listed for Ghost's rifle | 1.0 | 1.0 (`quill_rifle.fire_slow`) | kept: pattern 6's "minigun 0.75x" is Hudson, the mapping the owner corrected to Ghost on 11-27 |
| Kael (Brall) | RMB Lunge charge | charge dash (no number) | 0.80 | 0.80 (`rmb.lunge.walk_k`) | kept (footage 0.69-0.84) |
| **Kael (Brall)** | **Lunge missed** | **0.75 (no length)** | 1.0 | **0.75 for 0.5 s** (`rmb.lunge.miss_move`, `miss_t`) | **set**; 0.5 s is ours [?] |
| Sparkle (Joule) | LMB | none listed | 0.90 | 0.90 (`fire_slow`) | kept |
| Sparkle (Joule) | RMB Storm Rod hold | hold up to 1 s (no number) | 0.82 | 0.82 (1 - `rmb.self_slow`) | kept: owner playtest 11-08 |
| Motley (Void) | LMB | none listed | 0.90 | 0.90 (`fire_slow`) | kept |
| Motley (Void) | RMB Snap cast | +50 speed on cast, +100 on impact (a burst, not a slow) | 0.75 (`rmb.snap.cast_slow`) | 0.75 | not changed here: the burst is its own backlog item; not asserted (a 0.15 s window) |
| Neve (Celeste) | LMB Ice Darts | none listed | 1.0 | 1.0 | kept |
| Meeko (Elluna) | LMB Ember Cast | none listed | 1.0 | 1.0 (`fire_slow`) | kept |
| Meeko (Elluna) | RMB Burrseed wind-up | root after 2 s (no self number) | 0.50 | 0.50 (`rmb.wind_move`) | kept |
| **Meeko (Elluna)** | **Carrier: carrying a teammate** | **0.7 (Soulpack; the note also says "20% slow")** | 1.0 (`pick_speed` 0.6 was never read) | **0.7** (`passive.carry_move`) | **set**; replaces the 11-07 "no carry slow" (that was no source number, not an owner ruling) |
| Sable (Shiv) | LMB Sleight Trigger | none listed | 0.71 | 0.71 (`arc_bolts.fire_slow`) | kept (frames 11-12) |
| Gil (Beebo) | all | not compared | | | ours on purpose (owner 11-27): left as he is |

Measured before/after (the same rows on main's kits): Cinder cloak spin 1.000 -> 0.600, Albert shield broken
1.000 -> 0.600, Kael Lunge missed 1.000 -> 0.750, Meeko carrying 1.000 -> 0.700; the 16 kept rows read their data
exactly (Grimble 0.724 of the run under the kick, multiplier 0.800).

Open: the reference gives no length for Kael's miss slow (0.5 s is ours), and its carry note gives both 0.7x and
"20% slow" (0.8x); 0.7x is used, as pattern 6 says. Back-damage penalty (the rest of pattern 6) is not built.
