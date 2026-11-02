# Archer (id `archer`, Light) - accuracy pass

Behaviour reference: the SUPERVIVE hero Myth (internal note; nothing of the source's names or look ships). Player-facing names are our own.

## Research summary
Sources (gameplay only, notes in our own words):
- https://supervive.wiki.gg/wiki/Myth (hero page: passive, every slot, rank 2-4 rows, patch notes inline)
- Patch notes quoted on that page (18.12.24 bow damage, 20.11.24 charge hold, rank text changes)
- Combo inferences from the ability text (wall stun then follow-up damage, knocks refunding mobility)

Where they disagreed: the wiki's rank-3 row for the volley says both "-2s cooldown, +30% arc" (page) and "-4s cooldown, +30% arc" (20.11.24 patch). Chosen: the later patch, folded into our shared rank steps (cooldown -10% / -20%) plus the 30% wider wall at rank 3. The passive heal is listed as 500 HP, which is out of line with the other heroes' per-knock heals; we scale heal by the same health ratio the other heroes use (about 18% of our 100 HP).
Version chosen: the latest listed (patch 20.11.24 values).

## Source slots against ours (what changed in this pass)
| Slot | Input | Before | After | Source behaviour | Difference and why |
|---|---|---|---|---|---|
| Passive | always | Focus meter only | Focus + Hawk Sense (foes under half health show through cover within 22m) + a knock heals 18 and returns one dash charge | Sees injured hunters through fog, heals on a knock; a knock refunds a dash charge on the Shift | Heal scaled to our health. "Climb double walls" has no equivalent in our heightmap mantle and is left out. Focus/Deadeye stays as our own loop (documented extension) |
| LMB | hold | Bow, stages 30 / 60, perfect only at full draw (+25%) | Perfect release at both stages: +15% at stage 1 (0.4s), +25% at full draw | Two draw stages, perfect timing in either | Stage count follows the weapon json (0.4s / 0.9s), not the source's 0.5s / 1.1s, to keep ranged TTK |
| RMB | tap | Snare (root 0.6, Tripwire on a miss) | unchanged | none (source RMB is only the hold) | Kept as our extension: it feeds Focus, which drives the Deadeye payoff |
| RMB | hold | Heavy Shot, pin stun 0.8 | Heavy Shot, wall within 3m: extra hit (12 scaled by charge) and pin stun 1.2; max charge 1.1s, wind-up pose and lane telegraph | Charged impaling arrow, bonus damage on a wall, 1.2s stun | Stun now matches the source; wall bonus scaled to our damage |
| Shift | tap | Grapple Arrow | unchanged, plus the knock refund | Phase Walk (walk through walls, 2 charges) | Our terrain is a heightmap, so wall phasing is not reproducible; the grapple zip onto a ledge is the nearest wall-crossing mobility |
| E (source Q) | tap | Arrow Rain 3.75s, line 6m | Hail Wall 4.5s, rank 3 makes it 30% wider (was +1m) | 4.5s wall of arrows, slow, anti-heal, rank 3 wider arc | Renamed (the old name was too close to the source). Cone shape approximated with the 6m line |
| R | - | Great Arrows | removed | Empowered shots | See Ultimate |
| Ranks | - | listed in json | rank 2 +15% damage / -10% cooldown, rank 3 as the special text | Rank rows per the wiki | Shared framework steps; specials follow the wiki where the engine allows |

## Ultimate decision
The source ultimate (three empowered, undrawn, piercing shots) is flavour: the loop works without it and our Deadeye already plays the same "next shot needs no draw and hits harder" role. Dropped; no R (R is the Merge).

## Scaling
Light class, 100 HP base: tap snare 8, full Heavy Shot 30 (+12 wall hit), Hail Wall 5 per 0.5s, Deadeye +18. Source numbers were used only as ratios (charge time 1 : stun 1.2 : wall hit about a third of a full shot).

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

## Animations (HunterAnim.KMOVES)
`arc_draw` (held), `arc_loose`, `arc_heavy_wind` (held), `arc_heavy`, `arc_snare`, `arc_hail`, `arc_zip`, `arc_hop`, `arc_plunge`. Frame strips are in the shots folder (see the branch report).

## Payoff
Deadeye: gold second hit with T4 hitstop and shake, its own sound, "DEADEYE" word. Pins say "PINNED"; knocks say "RUN DOWN".
