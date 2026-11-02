# Juggernaut (archetype id `juggernaut`, heavy)

Branch history: kits2 ported the kit from the source hero, kits2-nor (Nov 2) removed its R, ext/kitfix-dancer-juggernaut matched it to the footage. Player-facing
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
with tip 14, crash 24. Rank 2 is the shared step (cooldown -10%, damage +15%); rank 3 carries the level 2-4
specials.

## Per-slot table

Updated by ext/kitfix-dancer-juggernaut (server update 5) against the footage reference sheet
(`briefs/hero-ref/juggernaut.md`) and the owner's playtest notes.

| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive, Rage | none | Damage fills Rage (a Searing Wave 3x as fast); full = Enraged 6s: +15% damage, +12% dash recharge, +20% cooldown speed, a roar. A knock heals 20% of the knocked hunter's max health, with a green heal column and a red screen tint for you | Fighting Spirit: damage makes you Empowered; knocks heal | Duration is ours |
| LMB, Greatsword | tap, hold | Wide (175 degree) slashes of 8 every 0.34s, alternating, a two-tone crescent (magenta edge, flame-yellow fill), double at the tip with a white star; hold: a ring round the body fills, then a red crescent of flame (Searing Wave) flies past the cursor to max range (6 to 10m, 12 to 28) | Quick Attack: alternating 180 degree two-tone crescents, a tip star; hold: a red crescent bolt past the cursor | As the source |
| RMB tap, Finishing Slam | tap | A 0.6s aimed wind-up (blade cocked low behind) behind a short magenta strike lane everyone sees, then a 4m strike: 26, +50% under 35% (foes that low wear a red outline while the Smash is ready); its sweet spot (the far tip, 2.4 to 4.2m within 18 degrees) brings the **crash**: 3m, 24, push 7, heals you 60% of what it deals; rests 12s (8s at rank 3); a knock on anyone it hit within 2s makes it ready at once | Execution Slam: red outline on executable foes, a short magenta lane, about 2.4 bh, resets Retaliation on a knock | The crash is the old Doomfall, now reachable at every rank (see "Ult choice") |
| RMB hold, Lunge | hold, release | A crouched, coiled wind-up; a lane grows ahead (4.5 to 7.5m) with a fill and turns magenta with a flash and a ping at full (0.8s); a rising whine; the cursor ring fills; you can jump while charging; release flings you forward into the first foe: 14 to 20, a huge white burst and a red slash across them; striking nothing doubles the cooldown | Charge Dash: red lane growing, magenta at full, about 5m, 559 to 771 | Owner: fling far, so the length grows with the charge |
| RMB air, Meteor Drop | in the air | A purple disc under the cursor (5m at most) shows while it's ready; press to dive onto it: 2.6m, 18, slow 40%; the centre 1.2m +50% and stunned 0.8s | Air Slam: a disc at the cursor, slam lands there | As the source |
| RMB in the pull | during E | Cinder Spin, Haul Slam, Chain Lunge (below) | Anti-Heal Spin | As before |
| Dash, Rampage | Shift | 3 charges from rank 1, 3.6m in 0.3s: 7 along it, the tip 14 and a big knock, orange flame streaks; rank 3: the tip +25% | Quick Dash: 3 charges, about 2 bh | As the source; sync62's slower heavy dash kept (0.3s) |
| E, Warchain | tap, recast | 10m (9.5s cooldown): a barbed hook on a wavy orange chain; hooked (foe, blighted) or a wall: a straight striped link chain that stays on as you walk, 4s; recast pulls you | Tether Chain: wavy in flight, striped links attached, 9.4s | As the source |
| R | none | The Boki Merge | Retaliation | See "Ult choice" |

## Ult choice

R is the Boki Merge for every hero (owner, Nov 1). kits2-nor folded the old Doomfall (crash, heal, reset on a
knock) into the Finishing Slam's sweet spot at rank 3; the owner found the payoff did nothing in play, so it
now works from rank 1: landing the slam's far tip is the kit's big hit at every level, and a knock re-arms it
(as the source's Execution Slam re-arms Retaliation on a knock). Rank 3 shortens its rest to 8s. The source's
Retaliation stance itself is not ported.

## Assumptions (where the footage is silent; easy to change in content/archetypes/juggernaut.json)

1. **Quick Attack direction:** the slashes follow the aim (cursor), not the movement direction.
2. **0154-0158 was the tap** (Finishing Slam), not the hold on an executable target.
3. **Air Slam reach:** 5m from under you, clamped; height doesn't add damage.
4. **Empowered** is our Enraged (6s, the numbers above); the hold-blast range is 6 to 10m.
5. **Lunge length:** grows 4.5 to 7.5m with the charge (owner: release flings you far), against the footage's fixed 5m.
6. **Jumping while charging** keeps the charge, and the release lunges from the air along your aim.

## Combinations

All are scripted in `--kit-combo-check` (also inside `--archetype-check`) and `--juggernaut-combo-check`
(tools/dancer_jug_check.gd).

| Sequence | Result | Check |
|---|---|---|
| E (hooked), E (pull), RMB tap | Cinder Spin | `combo jug: E > E > RMB tap = Cinder Spin` |
| E, hold RMB, let go | Chain Lunge along the chain | `combo jug: E > hold RMB = Chain Lunge` |
| E, hold RMB, E while holding | Haul Slam on arrival | `combo jug: E > hold RMB > E = Haul Slam on arrival` |
| E, E, hold RMB | Haul Slam where you land | `combo jug: E > E > hold RMB = Haul Slam` |
| E attached, RMB tap | the normal Finishing Slam; the link chain stays drawn | `combo jug: E > RMB tap = Finishing Slam` |
| RMB sweet spot (rank 1) | the crash | `combo jug: RMB sweet spot (rank 1) = crash` |
| RMB sweet spot (rank 3) | the crash; you heal 60% of its damage; rests 8s | `combo jug: RMB sweet spot (rank 3) = crash + heal` |
| The crash, then a knock on a foe it hit (2s) | the crash is ready again; a heal; a Rampage charge back | `combo jug: crash > knock = crash reset + heal + a dash` |
| RMB hold, jump, full, release | lane, jump, flash, fling | `juggernaut RMB hold: you can jump while holding` and the lane/flash checks |
| RMB hold that strikes nothing | Smash cooldown doubles | `combo jug: RMB hold miss = cooldown x2` |
| In the air with the Smash ready, RMB | the disc at the cursor, the dive lands there | `juggernaut RMB air: Meteor Drop lands at the cursor (disc everyone sees)` |
| Rampage or Lunge, then glide | no glider for the wind-down | `combo jug: Rampage winds down (no instant glide)` |
| Rooted or Grounded, E | no chain | `combo jug: rooted = no Warchain`, `combo jug: Grounded = no Warchain` |
| A stun while chained | breaks the chain | `combo jug: stun breaks the Warchain` |
| Enraged | faster cooldowns | `combo jug: Enraged hastes the Smash` |

## Animation moves

`KMovesDJ` (scripts/match/kmoves_dj.gd): `jug_slash_r` / `jug_slash_l` (the body of each slash), `jug_wave_wind`
(held) / `jug_wave`, `jug_slam` (0.6s coiled wind-up, strike at 0.6, overshoot and settle), `jug_crash`,
`jug_lunge_wind` (held: sunk deep, blade dragged behind, coiled) / `jug_lunge`, `jug_meteor`, `jug_dash`,
`jug_exdash` (the shared long dash, lumbering, shoulder first), `jug_chain` / `jug_reel`, `jug_spin`,
`jug_chainlunge`, `jug_haul_wind` / `jug_haulslam`, `jug_roar` (Enraged). Strips: `--arena-demo=anim_<move>`
(scripts/arch/dj_demo.gd).

## Look and sound (all ours)

Effects in scripts/arch/kits/dj_fx.gd and shaders/dj_fx.gdshader (pooled): the two-tone slash crescents, the
red flame crescent of the Searing Wave, the white impact bursts, the crash ring, the purple dive ring, the
wavy and striped chains, the heal column. Sounds: tools/gen_dj_sfx.py (`jug_*`), synthesized, including the
rising Lunge whine (`jug_charge`) and its full ping (`jug_full`).

## Originality

Two of our names (Execution Slam, Scorching Spin) had matched the source hero's exactly; they are now the
Finishing Slam and the Cinder Spin everywhere the player can read them (content, UI, fx words, wiki).

## Engine notes

- The crash lives in `JuggernautKit._crash`; numbers in content/archetypes/juggernaut.json `rmb.crash`
  (rank, radius, damage, push, heal share, rest, reset window). It is kept in its own `crash_cd`, not the
  old `cd["r"]`.
- No `"r"` in the JSON: `ArchKit.use_r` refuses the press, the kit card's R page is the Merge, and the wiki
  generator shows "Boki Merge" for the R slot.
- Net: the kit move id rides the hunter snapshot from Net 0.15.0, so remote players see the slams and lunges.

## Starting a Boki merge

Pressing R to merge drops everything the Juggernaut was holding or winding up, and none of it fires or is
left over when the merge ends: the Searing Wave charge (`lmb_t`, `lmb_buf`, `mel_hold`), the Finishing Slam's
wind-up (`slam_w`), an armed Haul Slam (`haul`) and the held Smash (`rmb_down`, cleared by the merge itself), a Meteor Drop in its dive (`drop`) and the Lunge's full flag (`lunge_full`).
Scripted in `--kit-combo-check` as the `merge hold jug:` checks.
