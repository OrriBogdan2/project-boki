# Linwick (archetype `ashwick`, heavy; display name was Ashwick)

Internal design doc. Source behaviour: the hero named in the Inspired-by table in docs/ARCHETYPES.md (traceability only; none of its
names, text or looks appear in the game). Everything the player sees and hears is ours. The kitfix pass (Nov 2026) rebuilt the kit
against the reference sheet made from gameplay footage (kept outside the repo) and the wiki's fine print.

## Research summary
Sources (gameplay facts only, written in our own words):
- The reference hero's public kit page (see the Inspired-by table in docs/ARCHETYPES.md), patch notes on that page.
- The footage reference sheet (frames kept on the local machine): timing, aiming, telegraphs, animation beats.

Where they disagreed: one guide attributes the pull, Anti-Heal and shield to the bolt; the wiki puts them on the shield ability,
which is what we follow. Latest version chosen.

## Scaling
Source hero 1367 HP against our heavy 193 HP: damage about x0.13 (flamethrower 205/s -> 27/s). Cooldowns about x0.8. The
ability damages keep the source's ratios to each other: bolt : ram : cloak = 248 : 279 : 117 (footage) -> 14 : 16 : 7.

## Per-slot table
| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive, Flashover | none | Every hit builds Char; at 31 the foe is Ablaze (3s, 2% of their health a second, one flame pip over the head); fed to 31 again they Flash over (4%, three pips and a glow). Anything that stokes a burning foe upgrades it. Char falls off all at once after 5s. A knock heals 16%, resets the cloak and gives back one ram charge | two burn levels, 3s, 31 stacks, refresh on any source, excess discarded, knock heal, knock restores 1 dash charge | food removing the burn not reproduced |
| LMB, Torch Lance | hold | a hose of fire 7m long (it doesn't stop at the cursor): a cyan pilot flame for 0.2s, then puffs leave the nozzle and keep their own velocity, so a sweep bends the stream; 0.5m wide at the nozzle, 2.2m at the end; walls stop it; 27 damage a second, +25% on a burning foe; Char 30/s (half on a burning foe); the fire stops at once on release; 0.35s before it can relight and a 0.35s self-slow | hold flamethrower, 2 burns every 65ms (half on an Ignited foe), 0.35s between uses, 0.35s self-slow after release; the stream lags like a hose (footage) | own weapon (`flamethrower`); 8s of fuel kept (the source shows none) |
| RMB, Cinder Shot | hold to aim, release | a thin lane to the cursor while held, then a red-pink fireball that lands at the cursor (14m at most) and fizzles there on a miss; 14 damage, sets the foe Ablaze; on a burning foe it upgrades the burn and spreads it (at the old level) to foes within 4m. 7s | bolt applies Ignite; on an Ignited foe it spreads (initial level) and upgrades; no knockback | cursor landing from one footage sample (see Assumptions) |
| Shift, Soot Ram | tap, 2 charges | a short head-first dash toward the cursor (up to 4.4m) that stops on the first foe: 16 damage, a shove, 17 Char, and Linwick bounces back a little. Two charges chain right away. Rank 3: stokes at once | dash in flames, knocks struck targets back and the hero slightly back, 17 burns, 2 charges, rank 4 upgrades the burn | none (the folded lava carpet went back to the ult on X) |
| E, Furnace Cloak | tap | a thin ring at 4.5m for 0.2s (everyone sees it, arms crossed), then the blast: 7 damage, 16 Char, Anti-Heal 3s, foes in sight dragged to you (walls stop them), a swirling 3s fire shield of 6.4% + 5.1% per foe hit. A knock resets it. 10.5s | spin: damage, Anti-Heal, pull, shield by foes hit, knock reset, blocked by line of sight; a 0.2s edge ring before it (footage) | none |
| X, Flue Flight (ult, level 6) | tap; X again lands | a ring of embers (2.2m, everyone sees it), then 1.4s of low flight (12.6 m/s, about 17.6m) toward the cursor that steers with the aim at up to 120 degrees a second. A 1.8m molten carpet forms under him and lasts 4s (the oldest end fades first): 4.5 damage a second, a 30% slow and 4 Char every 0.3s (Ablaze in about 2.4s). The Furnace Cloak works mid-flight; a knockback speeds the flight up; a stun ends it; the carpet never forms over the abyss. 32s | flight forward that steers, a fire trail that slows and builds Ignite (4 stacks every 0.3s), 4s, recast ends it, Heat Shield castable mid-flight, impulses speed it up, no trail over abyss | no flamethrower or Cinder Shot mid-flight (see Assumptions) |
| R | | the Boki Merge (not a hero ability) | | |

Rank 2 / 3: shared cooldown and damage steps; rank 3 Cinder Shot +60% damage and refunds 25% when it stokes; Soot Ram stokes at
once; Cloak +50% damage and shield, refunds 25% when it stokes.

## Ultimate on X: Flue Flight
The source's flight is back as its own ultimate on X (owner decision, SERVER_UPDATE6), so the rank-3 Soot Ram no longer lays the
carpet: that fold would have duplicated the X ult, and the ram's rank 3 is back to its source behaviour (it upgrades the burn).
- Numbers keep the source's ratios: cooldown 32s against the cloak's 10.5s (source 25s : 8.3s); the carpet ticks far below the
  hose (about 1/6 of its damage a second, as in the footage), and its value is the slow and the Ignite build-up.
- Bond: an enemy hunter the carpet burns fills the Boki bond (a hit; a knock or a kill counts higher), the best event of the cast
  once, never the cast alone (`HeroUlt.landed`, then `KinBond.from_ult`; a guarded stub until branch ultbond lands).
- Burst: Flue Flight plus the cloak, then straight into a merge and its ultimate, leaves a full-health light hunter standing
  (`--ashwick-combo-check`, "burst").

## Small mechanics
| Mechanic | Ours | Source | Footage |
|---|---|---|---|
| The flame stream lags behind a sweep (a hose, not a cone) | built | footage only | yes (0016) |
| The stream runs its full length whatever the cursor distance | built | footage | yes (0012) |
| Cyan pilot flame for one beat before the fire, and while idle | built | footage | yes (0021, 0047) |
| Fire stops at once on release | built | footage | yes (0047) |
| 0.35s before the flamethrower can be used again; 0.35s self-slow after release | built | [wiki](https://supervive.wiki.gg/wiki/Felix), patch 20.11.2024 | the slow is not visible at 5 fps |
| Flame hits harder on a burning foe | built (+25%) | footage (29 -> 36) | yes (219-220 s) |
| Burns half as fast on a foe already burning | built | [wiki](https://supervive.wiki.gg/wiki/Felix) | no |
| Char above 31 is discarded; it all falls off after 5s | built | [wiki](https://supervive.wiki.gg/wiki/Felix) | no |
| Any new burn refreshes the duration | built | [wiki](https://supervive.wiki.gg/wiki/Felix) | no |
| Cinder spread uses the first foe's level before its upgrade | built | [wiki](https://supervive.wiki.gg/wiki/Felix) | no (one dummy) |
| Cinder Shot doesn't knock back | built | [wiki](https://supervive.wiki.gg/wiki/Felix), patch 18.12.24 | yes |
| Cinder Shot ends at the cursor on a miss | built | footage | one sample (0133) |
| Ram stops on the first foe; the foe is knocked back and Linwick slightly too | built | [wiki](https://supervive.wiki.gg/wiki/Felix), footage | yes (0141-0145) |
| A knock restores only one ram charge | built | [wiki](https://supervive.wiki.gg/wiki/Felix) | no |
| The cloak is blocked by line of sight; a knock resets it | built | [wiki](https://supervive.wiki.gg/wiki/Felix) | no |
| The carpet can't form over the abyss; builds burns every 0.3s | built | [wiki](https://supervive.wiki.gg/wiki/Felix) | no |
| The flight steers toward the cursor while flying (curved trails) | built: 120 degrees a second at most | footage | yes (ult 0034, 0038) |
| Reactivating ends the flight early | built (X again lands) | [wiki](https://supervive.wiki.gg/wiki/Felix), card | no |
| The trail forms under him whatever his height or speed and grows with the distance flown | built (a piece every metre) | [wiki](https://supervive.wiki.gg/wiki/Felix) | yes |
| The trail slows and builds Ignite quickly: 4 stacks every 0.3s, Ignited after about 2.4s | built (4 Char every 0.3s, Ablaze at 31) | [wiki](https://supervive.wiki.gg/wiki/Felix) | no |
| The trail lasts 4s and fades from the oldest end | built | [wiki](https://supervive.wiki.gg/wiki/Felix), footage | yes (ult 0072) |
| The trail can't form over the abyss | built | [wiki](https://supervive.wiki.gg/wiki/Felix) | no |
| The shield ability can be cast mid-flight | built (Furnace Cloak) | [wiki](https://supervive.wiki.gg/wiki/Felix) | yes (ult 0137) |
| Knockback impulses greatly increase the flight's speed | built (up to +10 m/s, bent the way he was pushed) | [wiki](https://supervive.wiki.gg/wiki/Felix) | no |
| A red-orange ember ring at lift-off, no big landing | built | footage | yes (ult 0025, 0039) |

## Assumptions
Where the footage and the wiki are silent, we picked the most likely behaviour (the owner can correct these):
- Cinder Shot is "hold to aim, release to fire" (the lane shows about 0.4s before each shot); a tap fires at once. It is
  cursor-clamped (one miss sample ended at the cursor).
- The "SLOWED" on the dummy after a bolt came from the jump pad, so the bolt doesn't slow.
- The ram can't be steered once it starts and has no wind-up; it goes toward the cursor (the footage shows the cursor side).
- The pull of the cloak reaches the whole 4.5m ring and needs line of sight; dragged foes stop at walls.
- The shield's size follows the wiki numbers (the footage doesn't show them); it lasts 3s.
- Ablaze lasts 3s on its own; a fresh stoke refreshes it.
- The hose keeps 8s of fuel and a refill (the source shows no fuel bar; keeping ours avoids an endless roar).
- The pilot flame is cyan in our palette too (it reads as cool against warm fire); the burn pips use our own flame shape.
- Flue Flight: he is not crowd-control immune; a stun ends the flight where he is. He flies over the abyss at the height he had
  (only the carpet is missing there). The hose and the Cinder Shot are locked while flying (only the cloak was seen cast); a
  Shift press waits for the landing (the dash buffer).
- The flight's telegraph for the player is a heading lane with chevrons as long as the flight still has to go; foes see only the
  ember ring and the carpet, as in the footage.
- Only enemy hunters count for the bond (the carpet still burns monsters and Boki).

## Combinations (all scripted in `--ashwick-combo-check`)
| Do this | You get | Asserted by (check line) |
|---|---|---|
| Hold the lance | a cyan pilot, no fire for 0.2s, then a 7m stream past a close cursor | "lance: the cyan pilot shows, no fire for the first 0.2s"; "lance: the stream runs its full ~7m past a close cursor" |
| Sweep while firing | the old fire keeps flying its own way (the stream bends) | "lance: a sweep bends the stream (old fire keeps its own heading)" |
| Look at the stream | narrow at the nozzle, billowing at the end | "lance: narrow at the nozzle, billowing at the far end" |
| Let go, press again at once | the fire stops at once; 0.35s before it relights; a short slow | "lance: letting go stops the fire at once"; "lance: 0.35s before it can roar again" |
| Keep the lance on a foe about 1s | Ablaze, one pip | "lance: ~1s on the foe = Ablaze (level 1)"; "burn stage: one flame pip over a foe Ablaze" |
| Keep holding on a burning foe | Flashover, three pips and a glow | "lance: kept on a burning foe it Flashes over (level 2)"; "burn stage: three flame pips and a glow over a Flashover" |
| Lance a burning foe | +25% per tick | "lance: +25% on a burning foe (per tick)" |
| Hold RMB | the lane to the cursor; release fires; a miss fizzles at the cursor; 14m cap | "cinder: holding shows the aim lane out to the cursor"; "cinder: a miss lands at the cursor and fizzles there"; "cinder: a far cursor caps it at 14m" |
| Cinder Shot on an unburnt foe | Ablaze | "cinder: a hit sets the foe Ablaze" |
| Cinder Shot on a burning foe | upgrade + spread at the old level | "combo: lance burn > Cinder Shot = upgrade + spread" |
| Soot Ram into a foe | stops on them with the flame skull: damage, 17 Char | "ram: the flame skull wraps his front while it flies"; "ram: stops on the first foe (doesn't pass through)"; "ram: impact damage and 17 Char" |
| Two rams in a row | chained within 0.4s | "ram: toward the cursor, two charges chain within 0.4s" |
| Knock with no charges | one ram charge back | "passive: a knock gives back one ram charge, not both" |
| Soot Ram rank 3 | stoke at once (no carpet: that is the X ult) | "ram rank 3: stokes at once, and lays no carpet" |
| X below level 6 | nothing | "ult: no cast below level 6" |
| X | the ember ring, the lift-off move, a heading lane, 32s cooldown | "ult cast: lifts off with the ember ring everyone sees"; "ult cast: its own cooldown starts (32s)"; "ult telegraph: the heading lane shows while flying" |
| X, then X again | lands early | "ult recast: X again lands early" |
| X and steer | the flight curves, at most 120 degrees a second | "ult steer: the heading turns toward the cursor, capped at 120 deg/s"; "ult steer: the flight curves (it ends well to the side)" |
| X through foes | a 4s carpet that burns, slows 30% and builds Char; Ablaze in about 2.4s | "ult payoff: a molten carpet along the flight that lasts about 4s"; "ult payoff: the carpet burns, slows and builds Char"; "ult payoff: standing in it, Ablaze after about 2.4s" |
| X over nobody / through hunters / knocking one | no bond / a hit (once per cast) / a knock | "ult bond: nothing for a cast that lands on nobody"; "ult bond: burning a hunter fills it once per cast"; "ult bond: a knock with the carpet counts as the cast's best event (0.7)" |
| X, then E mid-flight | the cloak goes off, the flight goes on (pull foes into the carpet) | "ult: the Furnace Cloak works mid-flight (the flight goes on)" |
| X, then RMB | denied | "ult: no Cinder Shot mid-flight" |
| X over a gap | he flies across, no carpet over the void | "ult abyss: the carpet never forms over the void, he flies across" |
| A knockback or a stun mid-flight | faster / the flight ends | "ult: a knockback mid-flight speeds it up"; "ult: a stun ends the flight" |
| X, then the merge and its ultimate | a full-health light hunter survives | "burst: Flue Flight then the merge never one-shots a full-health light hunter" |
| Furnace Cloak | a 0.2s ring, then damage, Char, Anti-Heal, drag, swirling shield | "cloak: the edge ring shows for 0.2s before the blast"; "cloak: damage, Char, Anti-Heal and a shield"; "cloak: foes in sight are dragged toward you"; "cloak: the swirling fire shield shows while it holds" |
| Lance or cloak behind a wall | nothing | "wall: the lance does not burn through a wall"; "wall: the cloak does not reach behind a wall" |
| Knock | heal and the cloak resets | "passive: a knock resets the cloak and heals" |
| Rank 3 ability that stokes | 25% cooldown refund | "rank 3: stoking refunds a quarter of the cooldown" |
| Char past 31; Char left alone | discarded; falls off after 5s | "passive: Char past 31 is discarded (burn, then 0)"; "passive: Char falls off all at once after 5s" |
| Carpet over the abyss | never forms | "abyss: the carpet never forms over the void" |
| A Boki merge mid-lance, mid-cloak or mid-flight | the hose, the cloak's ring and the flight drop, nothing fires or is laid | "merge hold: linwick's lance is dropped, no fire mid-merge"; "merge hold: linwick's cloak never goes off mid-merge"; "merge hold: linwick's flight is dropped, nothing more is laid" |

## Animation moves
Keyed full-body moves live in `scripts/match/kmoves_pair.gd` (`KMovesPair.MOVES`, sampled through `HunterAnim.km_sample`), timed
to the sheet's beats: anticipation, release (with an overshoot key), follow-through, recovery.
| Ability | KMOVES ids | Pose idea |
|---|---|---|
| Torch Lance (LMB, held) | `as_lance` (hold), `as_lance_end` | sets his feet and drops the nozzle to the right hip during the 0.2s pilot, kicked back as the roar starts, then braced leaning in; a little recoil off the hose on release |
| Cinder Shot (RMB) | `as_aim` (hold), `as_shot` | gun hand cocked at the shoulder sighting down the lane; release: the arm thrusts out (overshoot), the body kicked back by the shot |
| Soot Ram (Shift) | `as_leap` | a coil, then head first like a battering ram, arms swept back, legs trailing; squashes on impact, springs upright |
| Air dash (the class air dash) | `lw_hop` | a jet of flame from the bellows tucks him into a forward ball, then a settle |
| Furnace Cloak (E) | `as_cloak` | 0.2s curled in, arms crossed (the ring shows), flung wide with the blast up on his toes, held, settle |
| Flashover payoff, a knock | `lw_stoke` | the off fist pumps up, a lean back, a bounce |
| Flue Flight (X) | `lw_jet` (held), `lw_land` | a crouch as the ember ring bursts (0.08s), then he springs up and leans into the jet, arms swept back to the bellows straps, legs trailing, a slight bob; on landing a squash onto his feet |

## Look and sound
- Effects: `scripts/arch/kits/ld_fx.gd` (pooled, `shaders/ld_fx.gdshader`): the hose as one MultiMesh of fire puffs (white-hot to
  yellow to orange to a sooty violet fringe), the cyan pilot, the Cinder Shot fireball (red-pink body, yellow core, cool violet halo,
  smoky comet tail; an ember spray and red flash on hit, a blue-white fizzle ring on a miss), the flame skull with ember tails on the
  ram, the sunburst and cracked scorch of the cloak, the swirling two-ring fire shield, the molten carpet with violet scorched edges,
  and the flame pips over burning foes.
- Weapon: `HeroGearPair.flamer`: ribbed brass barrel, flared bell nozzle with a pilot cage, fuel canister, hose to the pack.
- Sounds (tools/sfx_linwick_dredge.py): `lw_pilot`, `lw_roar`, `lw_bolt`, `lw_bolt_hit`, `lw_bash`, `lw_bash_hit`, `lw_shield`,
  `lw_blaze`, `lw_trail`, `lw_hop`, `lw_jet` (lift-off whoomp and jet roar), `lw_jet_land` (plus the older `as_ignite`).
- Flue Flight (`scripts/arch/kits/ashwick_jet.gd`): the ember ring, scorch and sunburst at lift-off, a hot core and embers blown
  out of the bellows while flying, and the carpet as pooled LDFx lava strips.

## Engine notes
The hose is simulated on the match step (`scripts/arch/kits/ashwick_hose.gd`); a puff stops at a wall (`World.occupy`) and hurts
only with line of sight from the puff. The burn uses the engine's own burn status (credit to Linwick); remote bodies get it through
a hit with a burn option. The cloak's drag moves foes in steps against the world's occupancy test like a knock. No new sync shape.
Flue Flight rides the hunter's own dash movement (`Hunter.dash_with`, kind "jet"), re-aimed every step, so walls stop it as they
stop a dash; the kit holds him a little off the ground. Other players see the ember ring and carpet as Net fx rings and the moves
through the kit move id; no new sync shape.
Holds dropped on a merge (`_drop_holds`): `hose` (the stream), `spool`, `was_held`, `after_t`, `flame_acc`, `cloak_t`, `bash`, `aiming`,
and `jet.flight` (Flue Flight).
