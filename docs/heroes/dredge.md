# Dredge (archetype `dredge`, heavy)

Internal design doc. Source behaviour: the hero named in the Inspired-by table in docs/ARCHETYPES.md (traceability only; none of its names, text
or looks appear in the game). Everything the player sees and hears is ours. The kitfix pass (Nov 2026) rebuilt the kit against the reference
sheet made from gameplay footage (kept outside the repo), the wiki's fine print and the owner's playtest notes.

## Research summary
Sources (gameplay facts only, written in our own words):
- The reference hero's public kit page and guides (see the Inspired-by table in docs/ARCHETYPES.md); patch notes on that page.
- The footage reference sheet (frames kept on the local machine): timing, aiming, telegraphs, animation beats.
- Owner notes: E in the air smashes straight down with the anchor (sync61 playtest); the grab goes through rocks (Nov 2 relay).

## Scaling
Source hero 1531 HP against our heavy 193 HP: damage about x0.13. Numbers follow the source's ratios, not its raw values:
- the gun fires every 0.5s (the footage and card), with each slug's damage halved so the damage per second holds;
- the Anchor hits about 1.8x a point-blank volley (25 vs 7 x 2 = 14), stuns about 1.1s (the footage shows 1.2-1.4s);
- cooldowns keep the source's order and ratios: Grapnel 12s : Anchor 7s : Barge 5s per charge (2 charges at 10s).

## Per-slot table
| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive, Salvage | none | Knocks and assists stack Salvage (+2.5% health each, max 10); being downed costs one; hits on a hunter's back +50%; a knock heals 16% | stacks of max health per knock/assist, lose one on death, +50% backstab, heal on knock | heal as a share of health |
| LMB, scattergun | hold/tap | 7 slugs in a 30 degree fan (bloom to +15) that stop at 6.3m and hang there as violet dots for 0.3s; a shot every 0.5s; while firing the spread's two edge lines lie on the ground, idle one aim line to the cursor; the body rocks back each shot; the barge resets the bloom | 7 slugs, sharp bloom, a fixed stop range, cone edge lines and an idle aim line (footage), 0.5s | the no-spread armour bonus is not reproduced |
| RMB, Grapnel | tap | a braided rope-hook 11.5m to the first foe: it flies over rocks and props and drags the foe over them (a cliff face or a placed wall still stops it); the foe is stunned and reeled to your feet (11 m/s, up to 3s) with weight, so strafing swings them round you; you are Grounded while you reel (no jump or glide, the barge still works); they land Grounded 1s. It also catches an ally (reeled in to safety) and scoops up wisps on the way. 12s | the arm pierces terrain, grabs the first target (enemy or ally), physics pull that swings, grounds on arrival, scoops wisps, only dash castable | heavy bodies (wardens) can't be pulled; cliffs stop it (see Assumptions) |
| Shift, Barge | tap | a shoulder barge toward the cursor (4.6m, 2 charges at 10s): a red spiky burst and an ember scorch where it sets off, shoves for 5; in the air (the class air dash) it goes 35% further; turn limited to 35 degrees for 0.8s after the Anchor | ground and air dash with separate cooldowns, further in the air, turn limit after the slam | one pool of ground charges plus the class air dash |
| E, Anchor Drop | tap | on the ground: the fist hauled back, a hop a body length forward, the slam at 0.38s: a giant ghost anchor drops on the 3m cone in front, a crescent sweep, dust: 25 damage, stun 1.1s, slammed down and Grounded. In the air: you smash straight down at once with the anchor falling beside you, a landing ring shows, and the 3.2m ring hits at the landing with up to +50% damage by the height fallen (+75% at rank 3). 7s | fist slam: damage, stun, ground slam, pushes you down (not over the abyss), rank 4 height damage | owner note: the air cast is a straight-down smash |
| R | | not built (R is the Boki Merge) | two volleys with Anti-Heal | see ult choice |

Rank 2 / 3: -10% cooldown steps (barge -15%); Grapnel rank 3 refunds 33% on a foe hit; barge rank 3: pellet hits trim 0.25s off
the recharge; Anchor +15% damage and +0.1s stun per rank, rank 3 raises the air smash's height bonus to +75%.

## Ult choice
Dropped. Two volleys with Anti-Heal are flavour: nothing in the loop (Salvage, grapnel, anchor, back hits) resets on it.

## Small mechanics
| Mechanic | Ours | Source | Footage |
|---|---|---|---|
| The grab pierces terrain and drags the target over it | built for rocks and props; cliff faces stop it | [wiki](https://supervive.wiki.gg/wiki/Kingpin), owner | yes (0141, 0147) |
| The grab takes the first target, enemy or ally; an ally is pulled to safety | built | [wiki](https://supervive.wiki.gg/wiki/Kingpin), [guide](https://deltiasgaming.com/?p=298298) | no |
| The pull follows physics: a target you don't let reach you swings round you | built (weighted reel; strafing shifts the arrival 1.5m+) | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | partly (0147: the pull follows the hunter) |
| The pull lasts until arrival or 3s | built | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | yes |
| It scoops up wisps along its path | built (downed hunters it passes are reeled in too) | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | no |
| Only the dash and the air dash can be used while pulling | built | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | no |
| The caster is Grounded while reeling; the target is stunned for the pull | built | footage | yes (0127) |
| Enemies are briefly Grounded on arrival | built | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | yes |
| The dash goes further in the air and has its own cooldown there | built (class air dash x1.35) | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | no |
| The slam then a dash limits the dash's turn | built (35 degrees for 0.8s) | [wiki](https://supervive.wiki.gg/wiki/Kingpin), patch 05.02.25 | no |
| The slam pushes you down, never over the abyss | built (owner: the air cast smashes straight down) | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | no |
| Height adds slam damage (rank 4 in the source) | built for every rank (+50%), +75% at rank 3 (owner note) | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | no |
| The scattergun's accuracy drops sharply with each shot; the dash resets it | built | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | yes (0040 vs 0112) |
| Rank 4 dash: pellet hits cut the dash recharge | built at rank 3 | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | no |
| Backstab +50% | built | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | no |
| Bonus armour damage when fired without spread | not built (our armour rules differ) | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | no |

## Assumptions
Where the footage and the wiki are silent, we picked the most likely behaviour (the owner can correct these):
- "Through terrain" means rocks, trees and props: the hook flies over them and the body is hauled up and over to the first clear spot
  beyond. A cliff face (a rise past 1.2m) and a placed ability wall stop the hook and the reel ("SNAGGED" / "WALLED"), because a body
  can't be dragged up a cliff in our world. The abyss is not special: a body dragged over it falls (the knock rules).
- The reel can't be cancelled by the caster; he can walk and barge during it (walking is what swings the body).
- The grab's hitbox is the hook's own size; with no target it flies its full 11.5m.
- An ally caught by the hook is neither damaged, stunned nor Grounded; a wisp is pulled like an ally.
- The air smash needs at least 1.2m of height; lower casts use the ground slam (with the old small downward push).
- The air dash distance is 35% more than the class air dash (the footage doesn't show it).
- The scattergun keeps a magazine (12 rounds, 6s of fire) and reload; the source spends mana instead.
- Backstab and Salvage values follow the wiki; the footage doesn't show them separately.

## Combinations (all scripted in `--dredge-combo-check`)
| Do this | You get | Asserted by (check line) |
|---|---|---|
| Hold the gun | a shot every 0.5s, the spread's edge lines out to 6.3m, the body rocks back; idle, one aim line | "gun: a shot every half second"; "gun: the spread's edge lines lie on the ground out to the slug range"; "gun: each shot rocks the body back (dr_shot)"; "gun: idle, the cone folds into one aim line" |
| Grapnel hit | reel begins; you are Grounded, they are stunned; the braided rope shows | "grapnel: hooks the first foe, reel begins"; "reel: Dredge is Grounded while he reels, the foe is stunned"; "reel: the braided rope is drawn (through rocks)" |
| Wait for the arrival | foe lands Grounded at your feet, "HAULED"; your Grounded ends | "grapnel: foe arrives and lands Grounded"; "reel: Dredge's own Grounded ends with the reel" |
| During the reel: RMB, E, the gun | denied (only the barge works) | "reel: a second Grapnel is denied"; "reel: E is denied while reeling"; "reel: the gun is locked" |
| During the reel: barge | works; the reel continues | "reel: the barge still works" |
| Reel, then Anchor Drop | the hop, the slam at ~0.38s: damage, a long stun with a spiral, Grounded | "anchor: hop about a body length forward, the slam lands at ~0.38s"; "combo: reel > Anchor Drop = damage, stun, Grounded"; "anchor: the stunned foe shows a stun spiral"; "anchor: E cooldown set" |
| Anchor Drop, then barge within 0.8s | barge turns at most 35 degrees | "combo: Anchor > barge turns at most 35 degrees" |
| Grapnel at a cliff face | the hook stops there, nobody is pulled | "cliff: a cliff face stops the hook, nobody is pulled"; "cliff: a reel is stopped by a cliff face, the foe stays behind it" |
| Grapnel past a rock | the foe is dragged over it | "rocks: the hook goes over a rock and drags the foe over it" |
| Strafe while reeling | the body swings round; the arrival point shifts 1.5m+ | "reel: strafing sideways shifts the arrival point by 1.5m or more"; "reel: the body swings on an arc, not a straight line" |
| Hook an ally | reeled to safety, no damage, no stun, no Grounded | "ally: the hook catches an ally in its path and reels them in"; "ally: they arrive safe (not Grounded)" |
| Hook a wisp | it is scooped up and reeled in | "wisp: a downed hunter the hook passes is scooped up with the catch" |
| Anchor Drop in the air | straight down, the landing ring and the falling anchor, a ring of damage and stun, height adds damage | "air smash: straight down at once"; "air smash: the landing ring shows while you fall, the anchor falls with you"; "air smash: it lands where you land, a ring of damage and stun"; "air smash: height adds damage (6m: about +50%)"; "air smash rank 3: up to +75% by height" |
| Anchor over the abyss | no downward push, no smash | "abyss: the Anchor never pushes you down over the void" |
| Barge in the air | 35% further | "barge: further in the air than on the ground" |
| A hit from behind | +50% | "passive: from behind +50%, from the front none" |
| Knock or assist | +1 Salvage (+2.5% health); a knock also heals | "passive: a knock = 1 stack, +2.5% health, a heal"; "passive: an assist stacks but does not heal"; "passive: capped at 10 stacks (+25%)" |
| Downed | -1 Salvage | "passive: being downed costs a stack" |
| Rank 3 Grapnel hit / pellet hit | 33% refund / barge recharge trimmed | "grapnel rank 3: a hit refunds a third of the cooldown"; "barge rank 3: a pellet hit trims the recharge" |
| Reel over a gap in the island | the body is carried over the void and falls | "abyss: a foe reeled over the void falls (knock rules)" |
| A Boki merge mid-reel or mid-wind-up | the rope goes, no landing; no slam | "merge hold: dredge's reel ends with the merge, the rope is freed, nobody lands Grounded"; "merge hold: dredge's Anchor wind-up is dropped, no slam mid-merge" |

## Animation moves
Keyed full-body moves live in `scripts/match/kmoves_pair.gd` (`KMovesPair.MOVES`, sampled through `HunterAnim.km_sample`).
| Ability | KMOVES ids | Pose idea |
|---|---|---|
| Scattergun (LMB, each shot) | `dr_shot` | the barrel kicks up, the torso rocks back and turns side-on, back to the aim in about 0.2s |
| Grapnel (RMB) | `dr_throw`, `dr_reel`, `dr_pullend` | the gun to the off side, the free arm coils back then punches out; side-on and braced, hauling hand over hand while reeling (held up to 3s); a last yank and a settle |
| Barge (Shift) | `dr_barge` | sink and coil, shoulder-first launch with the gun trailing, a crouched landing and a turn back to the aim |
| Air dash (the class air dash) | `dr_hop` | arms flung wide, legs pumping, a heavy settle |
| Anchor Drop (E) | `dr_anchor` | fist hauled back, the hop up and forward, the fist driven down (0.38s), crouched follow-through, a small rebound |
| Anchor Drop in the air | `dr_dive` (hold), `dr_quake` | both fists locked overhead dropping like a stone; a huge squash on landing, a heave back up |
| Salvage stack | `dr_flex` | chest out, both fists flexed, a stomp |

## Look and sound
- Effects (`scripts/arch/kits/ld_fx.gd`, `shaders/ld_fx.gdshader`, `shaders/ld_rope.gdshader`): pink-white slug streaks that hang as
  violet dots; a white-hot muzzle star; the braided golden rope with a brass three-pronged claw, drawn through rocks; the chain ring
  at his feet while Grounded; the giant translucent ghost anchor, a crescent sweep, the dust cloud and stun spirals; the landing ring,
  sunburst and scorch of the air smash; the red spiky burst and ember scorch where the barge sets off.
- Weapon: `HeroGearPair.scattergun`: a fat iron barrel with a flared brass bell, a rope-wrapped pump, a slug drum, a glowing seam.
- Sounds (tools/sfx_linwick_dredge.py): `dr_shot`, `dr_throw`, `dr_grab`, `dr_reel`, `dr_barge`, `dr_anchor_wind`, `dr_dive`,
  `dr_quake`, `dr_hop` (plus the older `dr_anchor`, `pay_salvage`).

## Engine notes
The reel moves the body in small steps toward wherever Dredge is now, with a weighted velocity (`SWING`), so it swings when he
moves. It is hauled over rock tiles (`World.T_BLOCK`) and props to the first clear spot, stopped by a cliff rise (`CLIFF`) or a
placed wall (`Verbs.wall_blocks`); the void is not special. The hook's shot carries `"rocks": true`, which the match's shot step
reads to let it fly over rocks (one condition in `match.gd`). Grounded on the caster uses `KitStatus` "gnd"; `Hunter.do_dash` lets a
reeling Dredge barge anyway (`DredgeKit.reeling`). A foe owned by another player's game (remote) takes the hit and Grounded only.
Holds dropped on a merge (`_drop_holds`): `wind`, `dive`, `flying`, `hook_sd`, `scoop`, `pull` (with the caster's own Grounded).
No new sync shape.
