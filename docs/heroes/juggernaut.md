# Juggernaut (archetype id `juggernaut`, heavy)

Branch history: kits2 ported the kit from the source hero, kits2-nor (Nov 2) removed its R. Player-facing
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

| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive, Rage | none | Damage fills Rage (a Searing Wave 3x as fast); full = Enraged 6s: +15% damage, +12% dash recharge, +20% cooldown speed. A knock heals 20% of the knocked hunter's max health | Blazing Spirit | Duration is ours (the wiki gives none) |
| LMB, Greatsword | tap, hold | Slashes of 8 every 0.34s, double at the tip; hold to charge a Searing Wave (6 to 10m, 12 to 28) | Quick melee, tip bonus; hold: a charged ranged fireblast | Shotgun and minigun stay as the other weapons |
| RMB, Smash | tap | A 0.5s aimed wind-up (a red "!"), then a 3.2m cone: 26, +50% under 35%; its sweet spot (the far tip, 1.9 to 3.4m within 22 degrees) is the SWEET SPOT payoff. **Rank 3: it also brings a crash down on the foe (3m, 24, push 7) that heals you 60% of the damage it deals; it rests 12s, and a knock on anyone it hit within 2s makes it ready at once** | Execution Slam (sweet spot resets R) | The R's crash and reset rule moved into the sweet spot (see "Ult choice") |
| RMB hold | hold, release | Lunge: charge 0.3 to 0.9s, a 3 to 7m dash attack, 14 to 22; striking nothing doubles the cooldown | Fiery Lunge | As the source |
| RMB air | in the air | Meteor Drop: 2.6m, 18, slow 40%; the centre 1.2m takes +50% and is stunned 0.8s | Obsidian Slam | As the source |
| RMB in the pull | during E | Scorching Spin 2.6m, 18, blight 4s (plus owner combos, below) | Scorching Spin | As the source |
| Dash, Rampage | Shift | 2 charges, 4.4m: 7 along it, the tip 14 and a big knock; a knock gives a charge back; rank 3 a third charge | Flame Step | As the source |
| E, Warchain | tap, recast | 10m, hooks a foe (8, blighted while tethered) or a wall, 4s; recast to pull yourself; a stun breaks it; not while rooted or Grounded | Feysteel Chain | As the source |
| R | none | None. Press R for the Boki Merge | Volcanic Rebuke | See "Ult choice" |

## Ult choice

R is the Boki Merge for every hero (owner, Nov 1). The Smash's sweet spot already was the old R's reset
trigger, so the Rebuke's crash, heal and reset-on-knock fold into the rank-3 sweet spot: the strongest play of
the kit (a full 0.5s aimed slam landing its far tip) now pays out the big hit, and nothing is lost but a button.

## Combinations

All are scripted in `--kit-combo-check` (which also runs inside `--archetype-check`).

| Sequence | Result | Check |
|---|---|---|
| E (hooked), E (pull), RMB tap | Scorching Spin | `combo jug: E > E > RMB tap = Scorching Spin` |
| E, hold RMB, let go | Chain Lunge along the chain | `combo jug: E > hold RMB = Chain Lunge` |
| E, hold RMB, E while holding | Haul Slam on arrival | `combo jug: E > hold RMB > E = Haul Slam on arrival` |
| E, E, hold RMB | Haul Slam where you land | `combo jug: E > E > hold RMB = Haul Slam` |
| E attached, RMB tap | the normal Execution Slam | `combo jug: E > RMB tap = Execution Slam` |
| RMB sweet spot at rank 1 or 2 | the payoff only, no crash | `combo jug: RMB sweet spot (rank 1) = payoff, no crash` |
| RMB sweet spot at rank 3 | the payoff and the crash; you heal 60% of its damage | `combo jug: RMB sweet spot (rank 3) = crash + heal` and `juggernaut Smash rank 3: the sweet spot also crashes, and it rests` (--archetype-check) |
| The crash, then a knock on a foe it hit (2s) | the crash is ready again; the knock heals 20% and gives a Rampage charge | `combo jug: crash > knock = crash reset + heal + a dash` |
| RMB hold that strikes nothing | Smash cooldown doubles | `combo jug: RMB hold miss = cooldown x2` |
| Rampage or Lunge, then glide | no glider for the wind-down | `combo jug: Rampage winds down (no instant glide)` |
| Rooted or Grounded, E | no chain | `combo jug: rooted = no Warchain`, `combo jug: Grounded = no Warchain` |
| A stun while chained | breaks the chain | `combo jug: stun breaks the Warchain` |
| Enraged | faster cooldowns | `combo jug: Enraged hastes the Smash` |

## Animation moves

`HunterAnim.KMOVES`: `jug_wave`, `jug_slam` (0.5s rearing wind-up, the crash on the hit; also the
rank-3 crash), `jug_lunge_wind` / `jug_lunge`, `jug_meteor`, `jug_dash`, `jug_chain` / `jug_reel`, `jug_spin`,
`jug_chainlunge`, `jug_haul_wind` / `jug_haulslam`. `jug_doom` went with the R. Strips:
`--arena-demo=anim_<move>`.

## Engine notes

- The crash lives in `JuggernautKit._crash`; numbers in content/archetypes/juggernaut.json `rmb.crash`
  (rank, radius, damage, push, heal share, rest, reset window). It is kept in its own `crash_cd`, not the
  old `cd["r"]`.
- No `"r"` in the JSON: `ArchKit.use_r` refuses the press, the kit card's R page is the Merge, and the wiki
  generator shows "Boki Merge" for the R slot.
- Net: the kit move id rides the hunter snapshot from Net 0.10.1, so remote players see the slams and lunges.
