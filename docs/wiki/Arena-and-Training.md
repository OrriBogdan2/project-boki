# Training Area

One place to practise, and it costs you nothing: nobody dies and nothing is lost. (The name "Arena" is kept for
the 4v4 team mode to come.)

Open it from the title screen ("Training Area", no save needed), the portal's Expedition menu ("Training Area")
or the farm's Esc menu. You play the Hunter you picked, built exactly as in a real match: same model, outfit,
kit, effects, tuning and HUD. Leaving puts you back where you came from.

## The areas

- **Ability Ring**, where you start: a round floor ringed by low ruined walls with four gates, four pillars to slam
  people into, a raised dais and two patches of tall grass. Three dummies (one stands and watches you, one
  strafes, a heavy one waits by a pillar) and the sparring bot.
- **Range**, through the east gate: still dummies at 10, 20 and 35 m, for falloff and aim.
- **Movement Lane**, over the bridge from the range: a low wall to vault, a gap, ledges at 0.8, 1.6 and 2.4 m
  (step, jump, mantle), a gap to dash, then a ramp up to 4.8 m and a drop off its end with the Landing islet out
  in front for air control.
- **Practice Wing**, over the south bridge: the gear rack, crates to smash, a few target monsters and the pad to
  the **duel room**.

Signs on posts name each area and each piece of the lane.

## What you can do

- **Dummies** are real hunters, so Marks, wall slams and every ability work on them. Each shows damage per
  second, last hit and total over its head, and heals up when left alone.
- **A sparring bot** you switch between Off, Idle, Moving and Fighting (**N**), with any Hunter.
- **Backspace** resets. **O** turns cooldowns off (dash, RMB, E, R and the glove). **U** unlocks the ultimate.
- **2-9** swap to the first eight Hunters on the spot. **L** opens the loadout (Hunter, weapon, Boki, gloves,
  toggles). **K** shows the kit card.
- **A checklist** (top right, **H** shows or folds it) walks you through every button: walk, dash, glide, shoot,
  E, your ultimate, right click (tap, then hold), your glove (take one from the rack first), sneak, throw your
  Boki, land a combo, heal, stagger a big dummy, break a crate, take a found weapon off the ground, and dash off
  an edge and float back up.
- A downed player or bot is back up after a beat.

## Hunters here are the match's Hunters

The Training Area is a `Match` started with `Match.arena_opts`, and picking a Hunter in its loadout is
`Arena.set_arch` (a `Hunter.reclass` and the match's pass over small shadow casters). There is no second spawn
path. `--hunter-parity-check` (in the suite) builds every Hunter in a real match and in the Training Area, started as
them and swapped in place, with no save, a fresh one and after the title screen, and fails on any difference in
model file, kit script, node tree, bone scales or mesh surfaces (shader, uniforms, visibility range, shadows).
`--training-area-shots` (GPU) screenshots every Hunter here, front and back. See [Checks](Checks.md).

## The duel room

You against one sparring bot on an empty island. Pick its Hunter, weapon, glove, difficulty and behaviour (fight,
dodge only, stand still), reset whenever you like, and watch your numbers: damage dealt and taken, how many of
your shots land, how many of its shots you dodge, and knocks. A knock resets the round.

## The tutorial

**First Flight**, played once after your first egg hatches: three small islands with nothing random on them. See
[Getting started](Getting-Started.md).
