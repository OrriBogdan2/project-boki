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
- cooldowns keep the source's order and ratios: Grapnel 12s : Anchor 7s : Barge 5s per charge (3 charges at 10s, chained a beat apart).

## Per-slot table
| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive, Salvage | none | Knocks and assists stack Salvage (+2.5% health each, max 10); being downed costs one; hits on a hunter's back +50%; a knock heals 16% | stacks of max health per knock/assist, lose one on death, +50% backstab, heal on knock | heal as a share of health |
| LMB, scattergun | hold/tap | 7 slugs in a 30 degree fan (bloom to +15) that stop at 6.3m and hang there as violet dots for 0.3s; a shot every 0.5s; while firing the spread's two edge lines lie on the ground, idle one aim line to the cursor; the body rocks back each shot; the barge resets the bloom | 7 slugs, sharp bloom, a fixed stop range, cone edge lines and an idle aim line (footage), 0.5s | the no-spread armour bonus is not reproduced |
| RMB, Grapnel | tap | a braided rope-hook 11.5m to the first foe: it flies over rocks and props and drags the foe over them (a cliff face or a placed wall still stops it); the foe is stunned and reeled to your feet (11 m/s, up to 3s) with weight, so strafing swings them round you; you are Grounded while you reel (no jump or glide, the barge still works); they land Grounded 1s. It also catches an ally (reeled in to safety) and scoops up wisps on the way. 12s | the arm pierces terrain, grabs the first target (enemy or ally), physics pull that swings, grounds on arrival, scoops wisps, only dash castable | heavy bodies (wardens) can't be pulled; cliffs stop it (see Assumptions) |
| Shift, Barge | tap | a quick, short shoulder barge toward the cursor (3.2m in 0.16s before the global dash feel, about 2.7m in 0.18s after it; 3 charges at 10s that chain 0.22s apart): a red spiky burst and an ember scorch where it sets off, shoves for 5; in the air (the class air dash) it goes 35% further; turn limited to 35 degrees for 0.8s after the Anchor | ground and air dash with separate cooldowns, further in the air, turn limit after the slam | one pool of ground charges plus the class air dash |
| E, Anchor Drop | tap | on the ground: the fist hauled back, a hop a body length forward, the slam at 0.38s: a giant ghost anchor drops on the 3m cone in front, a crescent sweep, dust: 25 damage, stun 1.1s, slammed down and Grounded. In the air: you smash straight down at once with the anchor falling beside you, a landing ring shows, and the 3.2m ring hits at the landing with up to +50% damage by the height fallen (+75% at rank 3). 7s | fist slam: damage, stun, ground slam, pushes you down (not over the abyss), rank 4 height damage | owner note: the air cast is a straight-down smash |
| X, Brass Broadside (ult, level 6) | tap | planted for a 1.1s charge while a 105 degree, 5.9m fan grows on the ground in front (everyone sees it; it is the exact area, locked at the press), then two waves 0.6s apart of six heavy brass slugs each (real shots): 4 a slug and Anti-Heal 3s. Point blank all twelve land, at 4.6m two a wave. A stun in the charge stops it (back in 8s). 21s | one press, two waves 0.6s apart, 6 slugs each with Anti-Heal, a fan telegraph, planted | 4 a slug, no back bonus: the burst cap (see Ult) |
| R | | the Boki Merge (not a hero ability) | | |

Rank 2 / 3: -10% cooldown steps (barge -15%); Grapnel rank 3 refunds 33% on a foe hit; barge rank 3: pellet hits trim 0.25s off
the recharge; Anchor +15% damage and +0.1s stun per rank, rank 3 raises the air smash's height bonus to +75%.

## Ultimate on X: Brass Broadside
Built as its own ultimate on X (owner decision, SERVER_UPDATE6). It was never folded into another slot, so nothing is unfolded.
- Cooldown 21s against the Grapnel's 12s (source 20.8s : 11.7s).
- Damage: the source's two point-blank waves hit about 2.2x the slam each. Ours are 4 a slug (24 a wave against the Anchor's 25),
  lower than the ratio, because an ult straight into a merge must not one-shot anyone: at level 10 the twelve slugs deal 65 and
  the merge's burst after them leaves a full-health light hunter (124) standing (`--dredge-combo-check`, "burst"). For the same
  reason the slugs take no Salvage back bonus.
- Bond: a slug that hits an enemy hunter fills the Boki bond (a hit; a knock or a kill counts higher), the best event of the cast
  once, not per slug or wave (`HeroUlt.landed`, then `KinBond.from_ult` with one cast id per cast).

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
| The ult is one press that fires two waves 0.6s apart, 6 slugs a wave | built | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | yes (ult 0034, 0040) |
| Every slug applies Anti-Heal | built (3s, as the cloak's) | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | yes (green streaks) |
| A fan grows on the ground over the 1.1s charge and is the exact hit area | built (AimKit cone, everyone sees it) | footage | yes (ult 0026, 0033) |
| He stands planted through the charge | built (no walking, gun, Grapnel, Anchor or barge until it ends) | footage | yes (ult 0022-0041) |
| Up close every slug of both waves connects | built (slugs leave his fists, so at 1.6m all six hit) | footage | yes (ult 0034, 0040) |
| Best after a stun (the reel or the slam covers the charge) | built (the reel combo is asserted) | [guide](https://deltiasgaming.com/?p=298298) | yes |
| Explosive: more damage to destructibles | not built (we have no destructible cover) | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | no |

## Assumptions
Where the footage and the wiki are silent, we picked the most likely behaviour (the owner can correct these):
- "Through terrain" means rocks, trees and props: the hook flies over them and the body is hauled up and over to the first clear spot
  beyond. A cliff face (a rise past 1.2m) and a placed ability wall stop the hook and the reel ("SNAGGED" / "WALLED"), because a body
  can't be dragged up a cliff in our world. The abyss is not special: a body dragged over it falls (the knock rules).
- The reel can't be cancelled by the caster; he can walk and barge during it (walking is what swings the body).
- The grab's hitbox is the hook's own size; with no target it flies its full 11.5m.
- An ally caught by the hook is neither damaged, stunned nor Grounded; a wisp is pulled like an ally.
- The air smash needs at least 1.2m of height; lower casts use the ground slam (with the old small downward push).
- Owner (23:40): several short, fast barges in a row, each a visible burst, not a blink. Three charges with a 0.22s gap.
  The air barge is the same quick shove with 35% more distance (faster, not longer); the footage doesn't show it. Out of
  either he keeps at most 3 m/s, so he arrives planted.
- The scattergun keeps a magazine (12 rounds, 6s of fire) and reload; the source spends mana instead.
- Backstab and Salvage values follow the wiki; the footage doesn't show them separately.
- Brass Broadside: the aim locks at the press (the fan doesn't turn after). A stun in the charge stops it with a short cooldown
  (8s); a stun between the waves stops the second. The second wave is a different colour (violet) like the footage's bluer one.
- Only enemy hunters count for the bond (the slugs still hit monsters and Boki).
- Body and movement (hero-ref "Body, scale and movement feel"): a heavy's height, 1.3x as broad across the chest and shoulders;
  slower, longer, planted steps (0.9x the step rate, stride 0.7).
- Not in the footage, built from his character: a plain jump is a deep heave off planted feet with the arms out, landing on a
  heavy squash (`dr_land`); the idle fidgets are a shoulder roll, a neck crack and a stretch. His barge leaves dark iron
  after-images with a brass rim instead of the shared pill.

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
| Barge timing | short and fast, seen travelling, then he stops | "barge: a short, fast shove you see travel (about half way at half its time), then he stops" |
| A run of barges | three, a short gap between | "barge: three in a row, a short gap between (a press inside the gap does nothing)" |
| Barge in the air | the same quick time, 35% further | "barge: in the air the same quick time, 35% further" |
| A hit from behind | +50% | "passive: from behind +50%, from the front none" |
| Knock or assist | +1 Salvage (+2.5% health); a knock also heals | "passive: a knock = 1 stack, +2.5% health, a heal"; "passive: an assist stacks but does not heal"; "passive: capped at 10 stacks (+25%)" |
| Downed | -1 Salvage | "passive: being downed costs a stack" |
| Rank 3 Grapnel hit / pellet hit | 33% refund / barge recharge trimmed | "grapnel rank 3: a hit refunds a third of the cooldown"; "barge rank 3: a pellet hit trims the recharge" |
| Reel over a gap in the island | the body is carried over the void and falls | "abyss: a foe reeled over the void falls (knock rules)" |
| A Boki merge mid-reel, mid-wind-up or mid-charge | the rope goes, no landing; no slam; no wave | "merge hold: dredge's reel ends with the merge, the rope is freed, nobody lands Grounded"; "merge hold: dredge's Anchor wind-up is dropped, no slam mid-merge"; "merge hold: dredge's Broadside is dropped, no wave mid-merge" |
| X below level 6 | nothing | "ult: no cast below level 6" |
| X | planted, the charge move, a growing fan everyone sees, 21s cooldown | "ult cast: planted, the charge move plays, its own cooldown starts (21s)"; "ult telegraph: a 105 degree fan everyone sees, growing over the charge"; "ult: planted through the charge (walking does nothing)" |
| X, then wait | wave 1 at 1.1s, wave 2 at 1.7s, six slugs each (spawn_shot) | "ult: one press, two waves of six slugs through spawn_shot"; "ult beats: wave 1 at the end of the 1.1s charge, wave 2 0.6s later" |
| X point blank / at 4.6m | all twelve slugs and Anti-Heal / two a wave | "ult payoff: point blank, all six slugs of each wave land"; "ult payoff: 4 a slug, no back bonus"; "ult payoff: the slugs leave Anti-Heal"; "ult payoff: at 4.6m fewer slugs land" |
| X at nobody / into a hunter | no bond / a hit, once per cast | "ult bond: nothing for waves that hit nobody"; "ult bond: 12 slugs land, the cast still counts once (a hit: 0.6)" |
| Reel, then X | the hauled foe takes every slug | "ult combo: reel the foe in, then the Broadside lands (10+ slugs)" |
| RMB, E or barge while planted; a stun in the charge | denied; stopped, back in 8s | "ult: RMB, E and the barge are locked while planted"; "ult: a stun in the charge stops it, back in 8s" |
| X, then the merge and its ultimate | a full-health light hunter survives | "burst: Brass Broadside then the merge never one-shots a full-health light hunter" |

## Animation moves
Keyed full-body moves live in `scripts/match/kmoves_pair.gd` (`KMovesPair.MOVES`, sampled through `HunterAnim.km_sample`).
| Ability | KMOVES ids | Pose idea |
|---|---|---|
| Scattergun (LMB, each shot) | `dr_shot` | the barrel kicks up, the torso rocks back and turns side-on, back to the aim in about 0.2s |
| Grapnel (RMB) | `dr_throw`, `dr_reel`, `dr_pullend` | the gun to the off side, the free arm coils back then punches out; side-on and braced, hauling hand over hand while reeling (held up to 3s); a last yank and a settle |
| Barge (Shift) | `dr_barge` | hunched shoulder-first through the quick shove, a squash on arrival, back to rest by 0.42s for the next |
| Plain jump / landing | `dr_jump`, `dr_land` | a deep heave with the arms out; a heavy squash onto bent knees |
| Air dash (the class air dash) | `dr_hop` | arms flung wide, legs pumping, a heavy settle |
| Anchor Drop (E) | `dr_anchor` | fist hauled back, the hop up and forward, the fist driven down (0.38s), crouched follow-through, a small rebound |
| Anchor Drop in the air | `dr_dive` (hold), `dr_quake` | both fists locked overhead dropping like a stone; a huge squash on landing, a heave back up |
| Salvage stack | `dr_flex` | chest out, both fists flexed, a stomp |
| Brass Broadside (X) | `dr_blast` | hunched over the gun and his free fist through the 1.1s charge (deeper at the end), a shove with overshoot and a barrel kick at wave 1, a short rewind, the second shove at 1.7s, then he straightens up (2.1s) |

## Look and sound
- Effects (`scripts/arch/kits/ld_fx.gd`; `shaders/ld_fx.gdshader` alpha-blended bodies with `ld_fx_glow.gdshader` glow cores,
  `ld_anchor.gdshader`, `ld_rope.gdshader`): hot pink slug streaks that hang as solid violet dots with dark cores; a brass muzzle
  flash; the braided rope (a darker tarred strand, swelling taut on each haul) with a big brass claw, drawn through rocks; the brass
  and iron chain ring at his feet while he reels; the giant solid iron anchor with a seafoam rim, falling through the wind-up and
  planted for 0.25s; a seafoam crescent sweep, the dust cloud and seafoam stun spirals; the chain landing ring, brass sunburst and
  scorch of the air smash (he rides the anchor down); the red spiky burst and ember scorch where the barge sets off, iron and brass
  after-images along it.
- Weapon: `HeroGearPair.scattergun`: a fat iron barrel with a flared brass bell, a rope-wrapped pump, a slug drum, a glowing seam.
- Sounds (tools/sfx_linwick_dredge.py): `dr_shot`, `dr_throw`, `dr_grab`, `dr_reel`, `dr_barge`, `dr_anchor_wind`, `dr_dive`,
  `dr_quake`, `dr_hop`, `dr_blast_charge` (a rising brass hum), `dr_blast` (a heavy thump, pitched down for wave 2) (plus the older
  `dr_anchor`, `pay_salvage`).
- Brass Broadside (`scripts/arch/kits/dredge_blast.gd`): the growing fan, sparks arcing between his fists while charging, big
  teardrop slugs (LDFx rider "orb": brass gold for wave 1, violet for wave 2), a sunburst at the fists and a crescent sweep across
  the fan per wave, a violet flicker rising from each target.

## Engine notes
The reel moves the body in small steps toward wherever Dredge is now, with a weighted velocity (`SWING`), so it swings when he
moves. It is hauled over rock tiles (`World.T_BLOCK`) and props to the first clear spot, stopped by a cliff rise (`CLIFF`) or a
placed wall (`Verbs.wall_blocks`); the void is not special. The hook's shot carries `"rocks": true`, which the match's shot step
reads to let it fly over rocks (one condition in `match.gd`). Grounded on the caster uses `KitStatus` "gnd"; `Hunter.do_dash` lets a
reeling Dredge barge anyway (`DredgeKit.reeling`). A foe owned by another player's game (remote) takes the hit and Grounded only.
Holds dropped on a merge (`_drop_holds`): `wind`, `dive`, `flying`, `hook_sd`, `scoop`, `pull` (with the caster's own Grounded),
and `broadside.blast` (Brass Broadside's charge and waves).
The slugs are ordinary shots (`Match.spawn_shot` with a `kx` callback for the hit). No new sync shape.
