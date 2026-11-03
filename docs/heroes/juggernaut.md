# Zedran (archetype id `juggernaut`, heavy)

Display name Zedran (owner, Nov 2); the id, file names and code names stay `juggernaut`.

Branch history: kits2 ported the kit from the source hero, kits2-nor (Nov 2) removed its R, ext/kitfix-dancer-juggernaut matched it to the footage, and the ult pass (server update 6) gave him his own ultimate back on X. Player-facing
names and text are ours; the source is named only in this research section, in docs/ARCHETYPES.md and in
docs/wiki/Inspirations.md.

## Research summary

- **Source hero:** Brall, from SUPERVIVE (supervive.wiki.gg ability text, levels 2-4, patch history).
  Version chosen: the wiki's current page as read on Nov 1, with the patch notes' shapes where they differ.
- **Patches that shaped it:** *Leveling Rework + Big Balance Patch* (LMB hitbox -20%, sweet spot moved to the
  central tip, the 3rd/4th-hit bonus removed, Flame Step charges, R no longer resets on Wisp execution) and
  *Gold + Mobility + Discord Patch* (Adaptive Strike cast 0.35 -> 0.55s with a warning icon and free aim,
  Execution x2 -> x1.5 below 35%, the chain breaks on stun and cannot be thrown rooted or grounded, dash
  wind-down frames, turning restricted after RMB into Shift).
- **Disagreements:** two guides say "double damage" to the wounded and a "four-hit combo with later hits
  stronger"; both are pre-patch, so the wiki wins. The Flame Step cooldown is 13s in the header and 11/9/7/6 in
  the notes; we use the notes' shape.
- **Not reproduced:** mana, climbing double-height walls, dodges building Rage, Volcanic Rebuke sending a
  knocked hunter straight to the deathbox, the turn lock after RMB into the dash.

## Scaling

Brall's scale (slash 20 with tip +20, Execution Slam 70, Lunge 45, Obsidian Slam 52, Spin 54, Flame Step 18
with tip 36, R 130) is kept as ratios: slash 8 (tip 16), Slam 26, Lunge 14 to 22, Meteor 18, Spin 18, Rampage 7
with tip 14, Gilded Riposte 34 (the footage's 396 against a 94 slash, 4.2x; its 21.7s cooldown is about 2.3 Tether
Chains, so ours is 22s against the Warchain's 9.5s). Rank 2 is the shared step (cooldown -10%, damage +15%); rank 3 carries the level 2-4
specials. Data pass (SERVER_UPDATE7): the Meteor Drop has its own 7.2s slot (9s against the Smash's 2.5s, kept as the
ratio 3.6x of our 2s), 2.4s shorter at rank 3 (the -3s as a third of its cooldown); the Rampage tip no longer stuns into
a wall; the Rampage starts on 2 charges and takes the third at rank 2; the Warchain loses its refund for the data's
-2s three times (12.5% of its cooldown each, merged: 12.5% at rank 2, 37.5% at rank 3); every Smash gets +20% at rank 2 and
again at rank 3.

## Per-slot table

Updated by ext/kitfix-dancer-juggernaut (server update 5) against the footage reference sheet
(`briefs/hero-ref/juggernaut.md`) and the owner's playtest notes.

| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive, Rage | none | Damage fills Rage (a Searing Wave 3x as fast); full = Enraged 6s: +15% damage, +12% dash recharge, +20% cooldown speed, a roar. A knock heals 20% of the knocked hunter's max health, with a green heal column and a red screen tint for you | Fighting Spirit: damage makes you Empowered; knocks heal | Duration is ours |
| LMB, Greatsword | tap, hold | Wide (175 degree) slashes of 8 every 0.34s, alternating, a two-tone crescent (magenta edge, flame-yellow fill), double at the tip with a white star; hold: a ring round the body fills, then a red crescent of flame (Searing Wave) flies past the cursor to max range (6 to 10m, 12 to 28) | Quick Attack: alternating 180 degree two-tone crescents, a tip star; hold: a red crescent bolt past the cursor | As the source |
| RMB tap, Finishing Slam | tap | A 0.6s aimed wind-up (blade cocked low behind) behind a short magenta strike lane everyone sees, then a 4m strike: 26, +50% under 35% (foes that low wear a red outline while the Smash is ready); its sweet spot is the far tip (2.4 to 4.2m within 18 degrees): knock that foe within 2s and the Gilded Riposte (X) is ready again | Execution Slam: red outline on executable foes, a short magenta lane, about 2.4 bh, a sweet-spot knock resets Retaliation | As the source; the crash fold is gone (see "Ult choice") |
| RMB hold, Lunge | hold, release | A crouched, coiled wind-up; a lane grows ahead (4.5 to 7.5m) with a fill and turns magenta with a flash and a ping at full (0.8s); a rising whine; the cursor ring fills; you can jump while charging; release flings you forward into the first foe: 14 to 20, a huge white burst and a red slash across them; striking nothing doubles the cooldown | Charge Dash: red lane growing, magenta at full, about 5m, 559 to 771 | Owner: fling far, so the length grows with the charge |
| RMB air, Meteor Drop | in the air | A purple disc under the cursor (5m at most) shows while it's ready. Press: a 0.2s hang (blade hauled overhead, knees tucked, one turn) over a marker everyone sees (the 2.6m disc and the 1.2m stun core), a visible dive onto it with flame streaks (0.22 to 0.4s), then the landing: a crouch onto the knees, cracks in the ground, a shock ring at the stun's edge, dust and debris, a shake and a deep boom; 18, slow 40%; the core +50% and stunned 0.8s. 0.5s recovery rising from the crouch (planted 0.2s, Shift free after 0.25s). Its own 7.2s cooldown (4.8s at rank 3) | Air Slam: a disc at the cursor, ~0.85s airborne from the jump, ~0.5s recovery in a low crouch ([F] 412.0-413.9s) | As the source; press to impact 0.52s (the footage's apex to impact is ~0.55s) |
| RMB in the pull | during E | Cinder Spin, Haul Slam, Chain Lunge (below) | Anti-Heal Spin | As before |
| Dash, Rampage | Shift | 2 charges, a third at rank 2: a 0.15s crouch with the blade cocked high behind, then 4.5m in 0.3s (x the global dash feel), flat and stretched, and a low recovery with the blade dragging: 7 along it, the tip 14 and a big knock, orange flame streaks; rank 3: a shot dodged through it feeds Rage (+15) | Quick Dash: 3 charges, about 2 bh | As the source; sync62's slower heavy dash kept (0.3s) |
| E, Warchain | tap, recast | 13m (9.5s cooldown): a barbed hook on a wavy orange chain; hooked (foe, blighted) or a wall: a straight striped link chain that stays on as you move, 5s, pulling taut and hot as it stretches; recast hauls you in at 22 m/s, steerable sideways; Shift or a jump breaks off; you arrive still moving. See "Warchain: the state machine" | Tether Chain: wavy in flight, striped links attached, 7 bh in 0.4s, pulled 5 bh in 0.4s, 9.4s | As the source, plus our exits and leash |
| X, Gilded Riposte | tap (level 6) | A 0.65s guard: planted (no walk, jump or other button), blade upright, a gold glow and sparks; no damage and no crowd control get through, and each hit blocked (two at most, a metallic ting each) makes the answer 20% harder. A 1.8m x 3.6m strip ahead (it follows the aim) shows to everyone through the guard. Then he lunges 1.8m and cleaves up through it (an upward crescent in his gold, run hot at the edge, and a gold cloud): 34, he heals 80% of what it deals (less while blighted); a knock with it makes it ready at once. About 1.1s in all; 22s cooldown. Landing it on a rival hunter fills the bond | Retaliation: 0.65s invulnerable, then a heavy strike in a rectangle ahead (about 1 x 2 bh), heals 80%, reusable on a kill | As the source; our look (gold guard, upward gold cleave) replaces its red crescent |
| Merge (its own key, `ultimate`) | tap | The Boki Merge | (n/a) | The Merge is the same for every hero |

## Warchain: the state machine

The owner's review (items 21 and 22) asked for the source's level of control on E. Sources, by precedence:
**[O]** the owner's notes (OWNER_REVIEW items 21/22, the 14:07 ET "small mechanics" note), **[D]** the game data
(`supervive-data/supervive_kits.md`: "Feysteel Chain (16s, 15): tether that attaches to enemies or walls, 30 dmg;
reactivate to pull yourself to the target. Upg: -2s CD x3"), **[W]** the wiki's ability page and patch notes
(https://supervive.wiki.gg/wiki/Brall: tether 5s; the pull is an impulse of 1900 uu/s; the cooldown starts on the
second press or when the chain breaks; a stun breaks it; no throw while rooted or Grounded), **[F]** the footage
notes (`hero-ref/juggernaut.md` E and RMB sections, frames 0301-0366).

**Range.** Neither [D] nor [W] lists one. [F]: on the wall test the chain flies about 7 bh in about 0.4 s
(0303-0305) and bites the wall there, so 7 bh is a floor, not the cap: 7 x 1.8 m = 12.6 m. Ours: **13 m** (was 10 m),
flying at 32 m/s (7 bh / 0.4 s = 31.5 m/s). The pull: [W] 1900 uu/s = 19 m/s at 1 uu = 1 cm; [F] about 5 bh in
0.4 s = 22.5 m/s. Ours: 22 m/s, not scaled by the global dash feel (the pull is not a dash).

The numbers live in `e` in content/archetypes/juggernaut.json; the code is `JuggernautChain`
(scripts/arch/kits/juggernaut_chain.gd).

| State | Event | Next state and result | Source |
|---|---|---|---|
| Ready | E | Throwing: the hook flies toward the cursor (13 m) | [D] [F] |
| Ready | E while rooted, Grounded, stunned or on cooldown | stays Ready, the deny buzz | [W] 05.02.25 |
| Ready | E with the Lunge charging (RMB held) | Throwing; the charge is kept (release once hooked = Chain Lunge) | ours |
| Throwing | hits a foe (hunter, monster or foe Boki) | Hooked to a foe: 8 damage, blighted while tethered (healing barely takes) | [D] [W] anti-heal |
| Throwing | hits a wall or a block | Hooked to a wall | [D] |
| Throwing | passes an ally or your own Boki | keeps flying (it only bites foes and walls) | [D] "enemies or walls" |
| Throwing | reaches 13 m, or drops into the abyss | Missed: "MISS", the cooldown starts | [W] 07.01.25 |
| Throwing | E pressed in flight | remembered for 0.12 s: if it hooks in that time, the pull starts on the hook | ours (buffer) |
| Throwing | stunned | Missed (the chain breaks), the cooldown starts | [W] 05.02.25 |
| Hooked (foe or wall) | time | the link chain stays on while you walk, jump, glide or dash, 5 s, then breaks; the cooldown starts | [W] 5 s; [F] 0305-0317 |
| Hooked | the chain stretches | the links pull straight and glow hotter, a creak at the hook and as it tightens; past 1.5 x its range (19.5 m) it breaks | [F] tension; the break length is ours |
| Hooked | E | Pulling (the cooldown starts) | [D] [W] |
| Hooked | E with the Lunge charging | Pulling with a Haul Slam armed for the arrival | ours |
| Hooked | stunned, or the foe is downed or gone | Broken: "CHAIN BROKE", the cooldown starts | [W] 05.02.25 |
| Hooked | a Boki merge starts | Broken | ours |
| Pulling | each step | you fly at 22 m/s toward the anchor (a hooked foe is followed as it moves), height held, across gaps | [W] impulse; [F] 0333 |
| Pulling | movement held across the pull | the arrival point slides that way, up to 3 m aside (6 m/s); you curve in beside the anchor | [O] 14:07 note |
| Pulling | Shift | the pull ends and the Rampage goes the way you dash (exit) | ours (no source footage) |
| Pulling | jump | the pull ends in a jump that keeps 70% of its speed (a chain launch); the glider takes it too | ours |
| Pulling | E | ignored (no second pull, no stop) | ours |
| Pulling | stunned, rooted or knocked | the pull stops dead | [W] stun rule |
| Pulling | reaches the foe (contact) or the wall (0.7 m off it), or runs 0.25 s past its expected time | Arriving | [D] [F] |
| Arriving | (0.25 s window) | you keep 35% of the pull's speed along it (momentum into the next move); an armed Haul Slam lands | [O] "arrival keeps momentum" |
| Arriving | over the abyss | you fall from the pull's height (the glider works) | ours |
| Arriving | window over | Ready again (on cooldown) | |

Ranks: the cooldown is 12.5% shorter at rank 2 and 37.5% at rank 3 (the data's -2s three times, as shares of our
9.5 s; [D]). The wiki's older rank 4 refund on a hooked foe is not in the data, so it's not built.

## RMB: the interaction table

What a Smash press does, by state. "Press" fires on the press; "tap" fires on a release under 0.3 s; "hold" on a
release after it. A press while a heavy move runs (the Slam's wind-up, a Lunge, a Meteor Drop and its recovery)
is held for 0.12 s before it ends and goes off when it does; earlier presses are ignored, never doubled.

| State | RMB | Result | Source |
|---|---|---|---|
| Ground | tap | Finishing Slam: 0.6 s wind-up behind a magenta lane, then the 4 m strike | [D] [F] 0154-0158 |
| Ground | hold, release | Lunge: the lane grows (magenta at full), fling 4.5 to 7.5 m | [D] [F] 0121-0146 |
| Ground, Lunge charging | jump, release | the Lunge goes from the air along the aim | ours (owner note) |
| In the air (a jump, a ledge, a chain launch) | press | Meteor Drop at the cursor (5 m reach): 0.2 s hang over the marker, the dive, the impact, 0.5 s recovery; its own cooldown | [D] [F] 0251-0300 |
| Throwing (chain in flight) | any | as on the ground or in the air; the throw goes on | ours |
| Hooked, on the ground | tap | Finishing Slam; the chain stays on | ours |
| Hooked | hold, release | Chain Lunge along the chain to its anchor (x1.25, a short stun on the foe); the chain is spent | ours |
| Hooked, Lunge charging | E | Pulling, then a Haul Slam on arrival (2.8 m, stun 0.25 to 0.6 s) | ours |
| Pulling | press | Cinder Spin at once (2.6 m, blights 4 s); the pull goes on | [D] "DURING Feysteel Chain pull" |
| Arriving (0.25 s) | press | Cinder Spin | [F] 0333-0336 (RMB on arrival) |
| Arrived, window over | tap / hold | Finishing Slam / Lunge from where you stand, with the carried speed | |
| Arrived beside a foe | tap | the Slam hits as a body hit (you're 1.2 m off, inside the 2.4 to 4.2 m sweet spot); a wall pull or a steered pull that leaves them 2.4 to 4.2 m ahead gets the sweet spot | no special rule (source: edge hits) |
| Jumped out of a pull | press | Meteor Drop | ours |
| Rampage (its crouch counts) | any | ground: fires mid-dash, the drive carrying him into it; air dash: ends the dash and the Meteor Drop begins | content/dash_flow/juggernaut.json (docs/heroes/dash_interactions.md) |
| Slam wind-up, Lunge, Meteor Drop | Shift | held, goes when it's over (the Meteor Drop: 0.25s into its recovery) | dash_flow `into_dash.rmb` |

Differences from the source, and why:
- **The Haul Slam and the Chain Lunge** are ours (the source has only the spin in the pull); they give the hold
  a meaning while chained instead of a plain Lunge away from the chain.
- **During the pull a press spins at once** (the source's Scorching Spin) rather than waiting to tell a tap from a
  hold; a held Smash only becomes a Haul Slam when it was already charging before the pull.
- **Exits:** the footage never shows a dash or a jump in the pull; we let Shift cancel it and a jump launch out of
  it, so it never locks you in.
- **The leash** (1.5 x range) is ours; the source's tether length is not in the data.

## Ult choice

The Boki Merge is the same for every hero, on its own key; the hero's own ultimate is on the `hunter_ult` key (default X).
kits2-nor had folded the old Doomfall (crash, heal, reset on a knock) into the Finishing Slam's sweet spot. With the
Gilded Riposte on X that fold duplicated the ultimate (a big hit that heals you, re-armed by a knock), so it is
unfolded: the crash is gone and the Slam is back to the source's Execution Slam, whose sweet-spot knock resets the
ultimate (now the X cooldown).

## Body and movement (hero sheet "Body, scale and movement feel")

- Model about 1.12 of a medium (`body.size` 0.95 on the heavy build), hunched: about 0.35 rad run lean;
  hit radius unchanged (0.50).
- Nameplate height 2.75 m (`body.plate`, `Arch.plate_y`).
- Rampage: a 0.15 s crouch (planted), then 4.5 m in 0.3 s, then a low recovery with the blade dragging
  (keys end at 0.9 s). Its after-images are his own orange flame streaks.
- The Enraged look is embers and dark drips on his body; no ground disc or light under him.

## Assumptions (where the footage is silent; easy to change in content/archetypes/juggernaut.json)

1. **Quick Attack direction:** the slashes follow the aim (cursor), not the movement direction.
2. **0154-0158 was the tap** (Finishing Slam), not the hold on an executable target.
3. **Air Slam reach:** 5m from under you, clamped; height doesn't add damage.
4. **Empowered** is our Enraged (6s, the numbers above); the hold-blast range is 6 to 10m.
5. **Lunge length:** grows 4.5 to 7.5m with the charge (owner: release flings you far), against the footage's fixed 5m.
6. **Jumping while charging** keeps the charge, and the release lunges from the air along your aim.
8. **Retaliation, hit during the guard:** the strike still comes at the end of the 0.65s (no early strike); each
   hit blocked adds 20% to it, two at most. The footage's dummy deals no damage, so this is ours.
9. **The guard is committed:** no dash or other button cancels it; the strip follows the aim until the strike.
10. **The reset** counts a knock (down) on a rival hunter with the cleave; monsters don't reset it.
11. **Invulnerable means everything but the abyss:** a fall still counts; damage over time is blocked too.
12. **The bond:** paid when the cleave lands on a rival hunter (a hit, a knock or a kill, the best of the cast) by
    `HeroUlt.landed`, which calls the main session's `KinBond.from_ult` once it exists; a miss or a monster pays nothing.

## Small mechanics

From the wiki's ability page and patch notes (https://supervive.wiki.gg/wiki/Brall) and the owner's notes.
"Built" means it is in the kit and asserted in `--juggernaut-combo-check` / `--kit-combo-check`.

| Mechanic | Source | Footage | Ours |
|---|---|---|---|
| The tether pull can be steered sideways while you're pulled in | owner's playtest note | not visible | Built: movement held across the pull slides the arrival point up to 3m aside (7 m/s); asserted "sideways input shifts the arrival by at least 1.5m" (2.3m) |
| Chain cooldown starts on the pull or when the chain breaks, not on the throw | wiki patch 07.01.25 | n/a | Built (kits2), asserted |
| A stun on Brall breaks the tether; it can't be thrown rooted or Grounded | wiki patch 05.02.25 | n/a | Built (kits2), asserted |
| The chain's cooldown drops 2s three times | owner's game data | n/a | Built: 12.5% at rank 2, 37.5% at rank 3 (the hook refund is gone) |
| The tether stays attached while you walk (about 2.5s+) | footage 0305-0317; wiki 5s | yes | Built (5s), drawn as a link chain |
| The Fiery Lunge doubles its cooldown if nothing is struck | wiki RMB | n/a | Built, asserted |
| The Execution Slam aims freely during its cast, with a warning over the head | wiki patch 05.02.25 | yes (lane at 0157) | Built: free aim, and a strike lane everyone sees |
| Execution: x1.5 under 35% | wiki patch 05.02.25 | yes (red outline 0154) | Built, plus the red outline while the Smash is ready |
| The dash has wind-down frames: no glide straight out of it | wiki patch 05.02.25 | n/a | Built (kits2), asserted |
| A knock restores one dash charge (not all) | wiki Shift | n/a | Built |
| Flame Step's tip deals double | wiki Shift | yes (0401) | Built |
| Obsidian Slam's centre ring stuns and deals +50% | wiki RMB | yes | Built |
| The slam lands where you aim in the air | footage 0263, 0286 | yes | Built (5m reach), asserted |
| Brall climbs double-height walls by jumping while facing them | wiki passive | no | Not built: it needs a change to the shared movement (hunter.gd mantle); listed for the main session |
| Dodging shots during the dash builds Empowered (top rank) | owner's game data | no | Built at rank 3: the perfect-dodge hook feeds 15 Rage |
| The Obsidian Slam has its own cooldown slot (9s, -3s at the top) | owner's game data | n/a | Built: 7.2s, 4.8s at rank 3; the Smash stays ready |
| The Flame Step tip does not stun into walls | owner's game data | n/a | Built: the wall stun is gone |
| Turning is restricted when the dash follows an RMB | wiki patch 05.02.25 | no | Not built (a turn lock reads as lag in our camera); Assumption 7 |
| The ult: 0.65s of invulnerability, then the strike | wiki R | yes (ult f33-f39) | Built: blocks every hit and its crowd control; asserted |
| The ult heals for a share of the damage dealt (80% on the newer card) | wiki R, in-game card | n/a | Built (80%); asserted |
| No heal while anti-healed | wiki patch 08.21.2024 | n/a | Built through blight (healing barely takes); asserted |
| No jumping during the ult | wiki patch 08.21.2024 | yes (planted f33-f38) | Built: planted, no jump; asserted |
| Knocking a hunter with the ult resets it | wiki R, in-game card | yes (ult f99-f101) | Built; asserted |
| A sweet-spot Execution Slam knock resets the ult | wiki RMB | n/a | Built (within 2s of the sweet spot); asserted |
| No reset from monsters or wisps | wiki patch 22.01.25 | n/a | Built: hunters only |
| He lunges about 1 bh into the strike | footage ult f39 | yes | Built (1.8m); asserted |

Assumption 7: the dash after an RMB turns freely; the pull keeps 35% of its speed as you arrive (the owner: "arrival keeps momentum").
Also ours (no footage): the pull exits (Shift, a jump), the leash (1.5x range) and the 0.12s input buffer are ours; the footage shows none of them.

## Combinations

All are scripted in `--kit-combo-check` (also inside `--archetype-check`) and `--juggernaut-combo-check`
(tools/dancer_jug_check.gd).

| Sequence | Result | Check |
|---|---|---|
| E (hooked), E (pull), RMB tap | Cinder Spin | `combo jug: E > E > RMB tap = Cinder Spin` |
| E, hold RMB, let go | Chain Lunge along the chain | `combo jug: E > hold RMB = Chain Lunge` |
| E, hold RMB, E while holding | Haul Slam on arrival | `combo jug: E > hold RMB > E = Haul Slam on arrival` |
| E, E, hold RMB | the Cinder Spin on the press (no Haul Slam) | `combo jug: E > E > hold RMB = Cinder Spin on the press` |
| Every Warchain state and RMB row | as the two tables above | `jug chain:`, `jug pull:`, `jug RMB row:`, `jug buffer:`, `jug meteor:` (tools/zedran_feel_check.gd) |
| E attached, RMB tap | the normal Finishing Slam; the link chain stays drawn | `combo jug: E > RMB tap = Finishing Slam` |
| RMB sweet spot, then a knock on that foe (2s) | the Gilded Riposte is ready again; a heal; a Rampage charge back | `combo jug: RMB sweet spot > knock = Riposte reset + heal + a dash` |
| E, E (pulled in), X, their hit | blocked in the guard, then the cleave lands | `combo jug: E > E > X = pulled in, a hit blocked, the cleave lands` |
| X, two hits blocked | the cleave 40% harder | `juggernaut X small mechanic: two hits blocked make the answer 40% harder` |
| X knocks a hunter | ready again at once | `juggernaut X small mechanic: knocking a hunter with it resets it; ...` |
| X, then a merge | the guard drops, no cleave | `merge hold jug: the Riposte's guard drops, no cleave` |
| RMB hold, jump, full, release | lane, jump, flash, fling | `juggernaut RMB hold: you can jump while holding` and the lane/flash checks |
| RMB hold that strikes nothing | Smash cooldown doubles | `combo jug: RMB hold miss = cooldown x2` |
| In the air with the Smash ready, RMB | the disc at the cursor, the dive lands there | `juggernaut RMB air: Meteor Drop lands at the cursor (disc everyone sees)` |
| Rampage or Lunge, then glide | no glider for the wind-down | `combo jug: Rampage winds down (no instant glide)` |
| Rooted or Grounded, E | no chain | `combo jug: rooted = no Warchain`, `combo jug: Grounded = no Warchain` |
| A stun while chained | breaks the chain | `combo jug: stun breaks the Warchain` |
| Enraged | faster cooldowns | `combo jug: Enraged hastes the Smash` |

## Animation moves

`KMovesDJ` (scripts/match/kmoves_dj.gd): `jug_slash_r` / `jug_slash_l` (the body of each slash), `jug_wave_wind`
(held) / `jug_wave`, `jug_slam` (0.6s coiled wind-up, strike at 0.6, overshoot and settle), `jug_guard` (X: planted wide, the blade upright in front) / `jug_riposte` (the blade drops, then the lunge and
the upward cleave, settled by 0.45s),
`jug_lunge_wind` (held: sunk deep, blade dragged behind, coiled) / `jug_lunge`, `jug_meteor` (held: the hang's
gather and turn, then the dive) / `jug_meteor_land` (the crouch onto the knees and the 0.5s rise), `jug_dash`,
`jug_exdash` (his air dash: a hurled shoulder charge, knees tucked, blade trailing; no ground mark), `jug_chain` / `jug_reel`, `jug_spin`,
`jug_chainlunge`, `jug_haul_wind` / `jug_haulslam`, `jug_roar` (Enraged). Strips: `--arena-demo=anim_<move>`
(scripts/arch/dj_demo.gd).

## Look and sound (all ours)

Effects in scripts/arch/kits/dj_fx.gd and shaders/dj_fx.gdshader (pooled): the two-tone slash crescents, the
red flame crescent of the Searing Wave, the white impact bursts, the gold guard shell, the upward gold cleave, the purple dive ring, the
wavy and striped chains, the heal column. Sounds: tools/gen_dj_sfx.py (`jug_*`), synthesized, including the
rising Lunge whine (`jug_charge`) and its full ping (`jug_full`).

## Originality

Two of our names (Execution Slam, Scorching Spin) had matched the source hero's exactly; they are now the
Finishing Slam and the Cinder Spin everywhere the player can read them (content, UI, fx words, wiki).

## Engine notes

- The Gilded Riposte lives in `scripts/arch/kits/juggernaut_ult.gd` (`JuggernautUlt`, owned by the kit); X
  reaches it through `ArchKit.cast_ult()` on the `hunter_ult` action. Numbers: `x` in
  content/archetypes/juggernaut.json; the shared X base (gate, cooldown `cd["x"]`, HUD slot, bond) is `HeroUlt`. Sounds: `jug_guard`, `jug_ting` (a blocked hit), `jug_riposte` (the cleave).
- The guard is `JuggernautKit.incoming` (every hit blocked while guarding), `move_k` (planted) and `busy`.
- Net: the kit move id rides the hunter snapshot from Net 0.15.0, so remote players see the slams and lunges.

## Starting a Boki merge

Pressing R to merge drops everything the Juggernaut was holding or winding up, and none of it fires or is
left over when the merge ends: the Searing Wave charge (`lmb_t`, `lmb_buf`, `mel_hold`), the Finishing Slam's
wind-up (`slam_w`), an armed Haul Slam (`haul`) and the held Smash (`rmb_down`, cleared by the merge itself), a Meteor Drop in its dive (`drop`), the Lunge's full flag (`lunge_full`) and a running Gilded Riposte
(`riposte.st`, its guard or cleave; the gold glow hides).
Scripted in `--kit-combo-check` as the `merge hold jug:` checks.
