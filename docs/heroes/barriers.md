# Placed barriers: what each one blocks, passes or destroys

Parity first (briefs/DECISIONS.md 2026-11-07). Sources: `briefs/supervive-data/supervive_kits.md`, the wiki rows quoted in
each hero doc, `briefs/hero-ref/tamsin.md` (footage at 5 fps: "blocks an enemy beam with a flash", 0334 and 0352) and the
DECISIONS rows (allies hop Tenzo's rocks, enemies are blocked; the Abyssal Hand goes through terrain, "placed walls still
stop it"). The footage sheets were read as text, not re-watched frame by frame. Pinned by `--dolm-combo-check` (rocks) and
`--rimewright-combo-check` (a Rink Wall's flags), both through `tools/barrier_rule_check.gd`.

## The rule (one place: `Verbs.barrier_at` / `Verbs.is_wall_at`, scripts/combat/verbs.gd)
A placed barrier (Stone Row and Basalt Spine rocks, the Rink Wall, a raised shield, a gear wall) is a wall to everything of
another team that would stop on terrain. Its own team's things pass it unless it blocks "all". "Pierces terrain" never means
"pierces a placed barrier". Dolm's rocks are the one standing exception for bodies: his allies hop them (`StoneStand`).

## Barrier x interaction (ours now; S = source says, I = inferred from the rows above)
| Interaction | Rock / Spine (Tenzo) | Rink Wall (Claire) | Basis |
|---|---|---|---|
| Foe's projectile (every kit's shots, launched rocks, Heavy Shot, Spear, Hand) | stopped, wall takes the damage | stopped, wall takes the damage | S "blocks projectiles" |
| Own team's projectile | passes | passes | I (flag "enemy") |
| Foe's beam (Longneedle, goes through terrain) | cut at the barrier, it takes the hit | same | S footage 0334/0352, I Hand row; **fixed** |
| Abyssal Hand (pierces terrain) and its reel | stopped; the reel stops at it | same | S DECISIONS; already so |
| Sable's dagger | queued separately (ext/sable-dagger-barriers) | same | left |
| Coin Blast / Spike Grenade | sticks to it, wall blast; **fixed** | same | S wiki patch 20.11.24 (sticks to dynamic objects) |
| Bola (Sable) | passes (only terrain stops it) | same | left: belongs to the dagger work |
| Foe knocked or punched into it (Punch, Storm Rod, Bash, grenade cone, Heavy Shot pin) | wall stun and pin payoff; **fixed** | same; the Rink Wall's own push is its touch knock | S "knocked into a wall", Heartpiercer "terrain" |
| Walking, dashes, skate, Skycall slide, reel, Cinder pull | blocked (movement flag) | blocked | S |
| Allies' movement | hop it by jumping against it | blocked (no source either way) | S Tetra row; Rink Wall open |
| Spirit Walk (phase through) | passes ("ability barriers", owner row) | passes | owner row, left |
| Shield push / wall carry (Breaker, Claire) | ignores it (`Displace._push`) | ignores | not fixed: the carried wall is a barrier itself |
| Melee swings, slams, cones, zones | not stopped | not stopped | source silent, left |
| Sight (`World.los`) | blocks | blocks | S ult "line of sight blocks it" |
| Destroys | rock breaks at 0 hp, a punch or slam launches it | 0 hp, or its timer | S |

## Fixed here (4 call sites, one rule)
1. `ArchKit.terrain_behind` (Punch, Storm Rod, grenade cone, Crushing Blow): a rock or Rink Wall behind a knocked foe stuns it.
2. `ArcherKit._wall_behind` (Heavy Shot's wall pin): the same.
3. Coin Blast sticks to an enemy barrier instead of flying through it.
4. The Longneedle stops at the first enemy barrier and damages it.
(Not changed on purpose: a thrown Bulwark hammer, Sable's bola, Displace `_push`: no source row.)

## Ideas of ours, not built
Rink Wall passing its own team's movement; melee striking through a barrier only for the owner.
