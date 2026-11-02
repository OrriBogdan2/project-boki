# Archer (id `archer`, Light) - accuracy pass

Behaviour reference: the SUPERVIVE hero Myth (internal note; nothing of the source's names or look ships). Player-facing names are our own.

## Research summary
Sources (gameplay only; notes in our own words, nothing of the source ships):
- https://supervive.wiki.gg/wiki/Myth (hero page: passive, every slot, rank rows; re-read for this finish pass)
- The page's inline patch history (bow damage 18.12.24, charge hold 20.11.24, rank text changes)
- Combination inferences from the ability text (wall stun then a follow-up hit, knocks refunding mobility)

What the source does: a two-stage bow draw (about 0.5s then 0.6s more) with a perfect-release bonus in either stage that also eases the self slow; a charged impaling arrow (full at 1s) that knocks back and stuns 1.2s on terrain, with extra damage on the wall; a 2-charge phase dodge through terrain whose charge returns on a knock; a 4.5s wall of falling arrows that slows and stops healing; an ultimate of three empowered, undrawn, piercing shots; a passive that shows injured rivals through fog, climbs double walls and heals on a knock.

Where sources disagree: older notes list the wall-of-arrows rank row as both "-2s cooldown, +30% arc" and "-4s"; the current page reads +30% damage and -2s, then -2s, then +30% arc width. Chosen: the current page, folded into our shared rank steps (cooldown -10% / -20%, damage +15% / +30%) plus the 30% wider wall at rank 3. The passive heal is listed as 500 of 880 HP, far above the other heroes' per-knock share; we scale it to our Light class (124 HP) as 18, about 15%.
Version chosen: the latest listed (patch 20.11.24 values and the current rank rows).

## Per-slot table (slot, input, our behaviour, source behaviour, difference and why)
| Slot | Input | Before | What it does now (our words) | Source behaviour | Difference and why |
|---|---|---|---|---|---|
| Passive | always | Focus meter only | Focus + Hawk Sense (foes under half health show through cover within 22m) + a knock heals 18 and returns one dash charge | Sees injured hunters through fog, heals on a knock; a knock refunds a dash charge on the Shift | Heal scaled to our health. "Climb double walls" has no equivalent in our heightmap mantle and is left out. Focus/Deadeye stays as our own loop (documented extension) |
| LMB | hold | Bow, stages 30 / 60, perfect only at full draw (+25%) | Perfect release at both stages: +15% at stage 1 (0.4s), +25% at full draw | Two draw stages, perfect timing in either | Stage count follows the weapon json (0.4s / 0.9s), not the source's 0.5s / 1.1s, to keep ranged TTK |
| RMB | tap | Snare (root 0.6, Tripwire on a miss) | unchanged | none (source RMB is only the hold) | Kept as our extension: it feeds Focus, which drives the Deadeye payoff |
| RMB | hold | Heavy Shot, pin stun 0.8 | Heavy Shot, wall within 3m: extra hit (12 scaled by charge) and pin stun 1.2; max charge 1.1s, wind-up pose and lane telegraph | Charged impaling arrow, bonus damage on a wall, 1.2s stun | Stun now matches the source; wall bonus scaled to our damage |
| Shift | tap | Grapple Arrow | unchanged, plus the knock refund | Phase Walk (walk through walls, 2 charges) | Our terrain is a heightmap, so wall phasing is not reproducible; the grapple zip onto a ledge is the nearest wall-crossing mobility |
| E (source Q) | tap | Arrow Rain 3.75s, line 6m | Hail Wall 4.5s, rank 3 makes it 30% wider (was +1m) | 4.5s wall of arrows, slow, anti-heal, rank 3 wider arc | Renamed (the old name was too close to the source). Cone shape approximated with the 6m line |
| R | - | Great Arrows | removed | Empowered shots | See Ultimate |
| Ranks | - | listed in json | rank 2 +15% damage / -10% cooldown, rank 3 as the special text | Rank rows per the wiki | Shared framework steps; specials follow the wiki where the engine allows |

## Ultimate choice
The source ultimate (three empowered, undrawn, piercing shots) is flavour: the loop works without it and our Deadeye already plays the same "next shot needs no draw and hits harder" role. Dropped: one line of reasoning, it is flavour and Deadeye covers the role; no R (R is the Merge).

## Scaling
Light class, 124 HP: tap snare 8, full Heavy Shot 30 (+12 wall hit), Hail Wall 5 per 0.5s, Deadeye +18. Source numbers were used only as ratios (charge time 1 : stun 1.2 : wall hit about a third of a full shot).

## Cross-ability interactions
| Combination | Result | Check |
|---|---|---|
| Hold LMB, release at stage 1 timing | Smaller perfect bonus, PERFECT word | `--archer-combo-check` |
| Heavy Shot into a wall | Wall hit, 1.2s stun, PINNED, Focus filled | same |
| Wall pin, then a shot | Deadeye (gold second hit, hitstop) | same |
| Hail Wall, then snare tap | Longer root (1.0) | same |
| Knock | Heal 18, +1 dash charge, RUN DOWN word | same |
| Rival under half health | Shown through cover (Hawk Sense) | same |
| Grapple with no bite / air RMB | Hop / Plunge, each with its own move | same |

## Animations (HunterAnim.KMOVES ids per ability)
| Ability | Move id(s) | Notes |
|---|---|---|
| LMB bow draw / release | `arc_draw` (held), `arc_loose` | strips: strip_arc_draw, strip_arc_loose |
| RMB hold (Heavy Shot) | `arc_heavy_wind` (held), `arc_heavy` | deep crouch, then a recoil |
| RMB tap (Snare) | `arc_snare` | quick flick, half-step |
| Shift (Grapple Arrow) | `arc_zip` when the line bites, `arc_hop` when it does not | |
| Air RMB (Plunge) | `arc_plunge` | shooting straight down |
| E (Hail Wall) | `arc_hail` | free hand thrown to the sky |
Frame strips live in the shots folder (see MANIFEST.txt); each is rendered by `--arena-shot=anim_<id>`.

## Engine notes
- Kit logic: `scripts/arch/kits/archer_kit.gd` plus `content/archetypes/archer.json` (all numbers; Focus values under `resource`). No class R: `K.d` has no `r` key and `r_def()` is empty, so the kit card, wiki generator and archetype check skip R rows (R is the Merge, which this kit never touches).
- Knock heal and dash refund run in the kit's own hit callback. No Net shape change: the knock ring goes through the existing `net_ring` fx event (`Net` fx list), which older builds already handle.
- Hawk Sense is a scan every 0.3s (`_sense_injured`) of rivals under half health inside 22m; it only flips an existing reveal flag.
- Wall pin reuses the Match terrain test for "wall within 3m"; the heightmap has no real walls, so a wall is a step in `World.level`. The combo check raises one with `_wall_at`.
- Tooling: `--archer-combo-check` / `--hero-combo-check` (tools/hero_combo_check.gd), arena strips in `scripts/match/arena_demo.gd` (`ANIM_DEMO`).

## Payoff
Deadeye: gold second hit with T4 hitstop and shake, its own sound, "DEADEYE" word. Pins say "PINNED"; knocks say "RUN DOWN".
