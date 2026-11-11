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
# Combat rules: status stacking

What happens when two casters put the same status on one body. Parity with the source first (DECISIONS
2026-11-07): owner > data > wiki > footage. The numbers are in `content/rules/status_stacking.json`, the code
is `scripts/combat/stacks.gd` (stack counts, merge rules) and `Ent.add_slow` / `Ent.add_burn` / `Ent.hurt`
(crowd control), and `--status-stacking-check` has one case per kind with two casters on one dummy.

## What the source says

The data and the footage are thin here. Nothing in `supervive-data` or the `hero-ref` strips shows two
casters on one body, and no source text gives a stacking or refresh rule for slows or stuns. What they do
settle:

- **Counts belong to the target.** Static, Shatter and Burning are statuses *on the body*: "Attacks and spells
  apply Static. At 4 stacks the target is fully Static Charged" (Vireo [D]); Thunderstorm "spreads its Static
  stacks to nearby enemies" ([D] kits); "hits add Shatter; at 8 stacks it detonates", the ult's slow "stacks
  for up to 3.5 s" (Tamsin [D]); "push Burning into Blazing" (Linwick [F]). One marker over the head, one
  count, whoever put it there [F].
- **Marks belong to the caster.** The Thief's passive is the caster's own: "deal +16 dmg for each Arcslinger
  hit (stacking)" ([D] kits, Malice and Resolve); the footage shows no counter on the target (Dancer [F]).
- **Stuns and slows show once.** One STUNNED word and one SLOWED word per body [F]; a stun reads about 1 s
  (Breah, Bjorn, Dredge [F]) and is not seen to grow when a second hit lands.

Where the source is silent (slow strength, stun time) we took the simplest rule that never makes two
casters stronger than one: the strongest wins. Alternative if the owner finds otherwise: add the
durations (stun) or multiply the speeds (slow); both are one word in the JSON (`combine`, `time`).

## The rules

| Kind | Two casters give | Count shared? | Time |
|---|---|---|---|
| Slow | the stronger slow; never added, never multiplied | one slow per body | the longer of what is left and the new time |
| Stun | (no strength) | one stun per body | the longer of the two: a stun **refreshes** to the longer, it never **extends** (1.0 s left + 1.5 s lands as 1.5 s) |
| Root | as stun | one per body | the longer |
| Burn | the stronger damage per second; the one who set the strongest is credited | one burn per body | the longer; a burn that ran out leaves no strength behind |
| Static (Sparkle) | counts add, up to 4 | **yes**, one count on the body | each hit resets it to 4.5 s |
| Shatter darts (Tamsin) | counts add, 8 bursts | **yes** | each dart resets it to 3 s |
| Chill (Tamsin) | one status | **yes** | each hit resets it to 4 s |
| Char (Cinder) | amounts add; at the top the foe is Ablaze and the Char is spent | **yes** | each add resets it |
| Ignite (Cinder) | the higher stage (Ablaze, Flashover); a stoke from either caster raises the shared stage | **yes** | the longer |
| Marks (Thief) | each caster's Marks add to her own | **no**, one count per caster | each hit refreshes hers |

Whoever lands the hit that completes a shared count gets its payoff (the sky bolt on the 4th Static, the
Shatter burst on the 8th dart, the Ablaze on the top Char).

Diminishing returns (`KinRules.DR_STEPS`) are per body, not per caster, and still apply on top for
ability crowd control; they are ours, not from the source (see DEBT).

## Net

The body's own game applies every status. A remote body is a proxy in the caster's game, so shared stack counts
are shared among the casters in *one* game; across two games each keeps its own view of a remote body until the
body's game sends the count. The Net shape is unchanged (`kst`, `hit`), so `Net.VERSION` is not bumped.
