# Combat: how ability shapes reach across height

Code: `AimMode.REACH_Y` and `AimMode.in_reach(shape_y, body_y)` (scripts/match/aim/aim_mode.gd). Check: `--ability-height-check`
(tools/ability_height_check.gd); basic shots stay in `--shot-vertical-check`.

## What the sources say

Nothing in the data, the wiki cards or the footage states a vertical reach for any ability, so the rule follows the terrain tiers the
source does show (owner > data > wiki > footage; the tiers are in briefs/supervive-data/LAYOUT_RULES.md):
- Walking steps are 0.8 m (`World.LEVEL`, one tier); a mantle ledge is 1.5 to 1.6 m (two tiers, "single-high"); a wall or a plateau
  edge is 3 m and up ("double-high ground can't be reached by jumping alone").
- Lines that pass through terrain (Ion Cannon, Kaiju Grasp, Railgun; footage venator 0176-0189, dredge 0141) cross chasms and
  islands, so a lane ignores what stands between and cares only about where the body is.
- Placed shapes land where the cursor meets the ground, so aiming at a Hunter on a ledge puts the circle on the ledge. That is
  how a top-down cursor works, and it is why the tests below aim at a spot beside the dummy on the caster's level.

[inference] Where the source is silent we take the reach that makes every ledge a Hunter can stand on (up to two tiers) count as
"the same fight", and a wall top or a plateau (three tiers and up) a different one.

## The rule

One number for every shape: a body is hit when its feet are less than `REACH_Y` = 2.2 m (two tiers plus 0.6 m of jump slack) from the
shape's own level. Up and down are the same. What differs per shape is the level it is measured from:

| Shape | Measured from | Examples |
|---|---|---|
| Circle (slam, burst, pull) | the ground at the circle's centre (the cursor's ground, or the caster's feet for a self-centred one) | Grimble's Anchor Drop, Tenzo's Quakefall, Kael's landing |
| Zone (standing field, wall, arc) | the ground at the zone's centre or wall base, fixed at the cast | Vex's Cinderfall, Lace's Hail Wall, Neve's Rink Wall, traps |
| Lane (beam, fissure, charge) | the caster's feet (the lane's start cell for a laid-out lane) | Albert's Faultline, Vex's Longneedle, Kael's chain |
| Cone (swing, blast) | the cone's point (the caster's feet, or where the charge stuck) | Vex's Burr blast, Cinder's cone, kin cones |

Consequences:
- A Hunter one or two tiers up or down is hit by all four shapes; three tiers (2.4 m) is out.
- A cone or lane does not need a line of sight, so it does not stop at a low cliff face; it stops at a cliff face because the foe
  above is three or more tiers away (a plateau or a wall top).
- A circle aimed at a ledge sits on the ledge, so the whole ledge is in it; one aimed below a plateau edge does not reach up onto the plateau.
- Contact tests (a shield's touch, a kin bite, a hook's catch, projectiles) are not shapes and keep their own height checks.

## Where it lives

The shared hit tests (`Effects`, `KinExec`, `Fields`, `Abilities`, `Verbs`, `MergeAugment`, `ArchKit.foes_in`) and the hero kits' own
loops all call `AimMode.in_reach`; no kit carries a private height number for a shape.
# Combat rules: what crowd control forbids

How long each status lasts is in `docs/KIT_PARITY.md` (Crowd control). This file covers **what each status
forbids**. The rule is data: `content/rules/cc_lockouts.json`, read by `CcLockout.blocks()`
(`scripts/combat/cc_lockout.gd`). The gates that ask it: `Hunter.do_jump`, `do_dash`, `can_glide` and the
held-glide opener, the crouch and walking lines, `can_fire` (LMB), `ArchKit.busy()` (RMB, E, R), the belt
press (`UtilityBelt.press`), Ryzz's dash and wire, and Zedran's chain pull (a move that travels).

Sources: `[D]` the game card text (`briefs/supervive-data/supervive_kits.md`), `[W]` the wiki table in
`docs/SUPERVIVE_DATA.md` §4, `[F]` the hero-ref footage (5 fps). Order: owner > data > wiki > footage.

| Status | Source rule | Walk | Dash | LMB | RMB/E/R | Jump | Glide | Crouch | Drink | Was (main d255acbee) |
|---|---|---|---|---|---|---|---|---|---|---|
| Stun (also Spike, Dunk) | "No movement, no air control, no abilities" [W] | no | no | no | no | no | no | **no** | **no** | crouch and belt items were allowed |
| Daze | "Ghost's version of stun", 1.2 / 2.0 s [W]; card: "dazes", bonus damage [D] | **no** | **no** | **no** | **no** | **no** | **no** | **no** | **no** | a damage window only, nothing forbidden |
| Root | "Can't move" [W] | no | no | yes | yes | **no** | **no** | yes | yes | Space still jumped; a held glide opened in a fall |
| Grounded | "no jumping/dashing up" [D]; "can't use movement abilities" [W] | yes | no | yes | yes (not a move that travels) | no | **no** | yes | yes | a held glide still opened in a fall |
| Slow | movespeed only [W] | slower | yes | yes | yes | yes | yes | yes | yes | match |
| Knock-up / knockback | "you can steer it with WASD" [W] | steer | yes | yes | yes | yes | after 0.4 s (ours, glider feel) | n/a | yes | match |
| Static | stacks to a charge, no lockout [D,F] | yes | yes | yes | yes | yes | yes | yes | yes | match |
| Chill | stacks for Shatter, no lockout [D] (our 15% slow is an ours-only rider, KIT_PARITY #19) | yes | yes | yes | yes | yes | yes | yes | yes | match |
| Silence | "No abilities, powers or consumables" [W] | | | | | | | | | not in our game (no kit applies it) |

Bold = changed on 11-09; each change has one assert in `--air-limits-check` (section 4).

Notes and calls made without the owner:
- **Drink under a stun.** The wiki's stun row lists abilities, not consumables; Silence, a lighter status,
  already forbids consumables, so a stun forbids the belt too. Alternative: allow the belt under a stun.
- **Daze.** The card only says "dazes" with a damage bonus; the wiki defines it as Ghost's stun, and its
  1.2 / 2.0 s durations match ours (1.4 s, +0.6 s on a wall). Wiki outranks a silent card, so a Daze now
  locks like a stun (no slow). A Daze already running doesn't cancel a cast in progress (a stun does).
  Alternative: the old damage-window-only Daze; delete the `daze` row in the JSON.
- **Root and glide.** "Can't move" covers opening a glider; a rooted glider closes like a stunned one.
- **Grounded and abilities that move.** "Movement abilities" are blocked by the `travel` act; only Ryzz's
  dash and Zedran's chain pull ask it today. Other kits' moving abilities are in `docs/DEBT.md`.
- Hex (ours) and a Dredge's own reel are not source CC; they keep their own gates.
