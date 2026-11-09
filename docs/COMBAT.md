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
