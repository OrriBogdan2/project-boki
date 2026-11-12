# Base life (Boki living on their own)

GARDEN.md section 4 and 9.2 (draft for owner approval). On only with `content/rules/farm_build.json` `base_mode`
(default off: the farm is unchanged). Code: `scripts/home/base_life.gd`; tuning: `content/rules/base_life.json`;
check: `--base-life-check`.

- One explicit machine per farm Boki (`Fsm`, briefs/STATE_MACHINES.md), kept on the kin entry as `k["life"]`:
  Roam, Eat, Nap, Play (a toy), PlayWith (tag with another Boki), Watch (a rival, or whoever took its toy),
  React (a newcomer). The table is `BaseLife.TABLE`; guards: Play needs a placed toy, PlayWith needs it awake,
  Nap ends only when its nap clock runs out. Every non-Nap state has a cap in `max`; a Boki that roamed `max.roam`
  seconds is bored and picks something (tag, a toy, else a nap).
- home.gd keeps its own drivers (whistle, petting, jobs, baths, the house, feeders, walking to bed). While one has a
  Boki its machine waits. home.gd asks `choose()` after its care and job picks, in place of the old wander/tag/nap
  choices; `step()` ticks every machine at 10 Hz; `pile()` lets napping friends lie close in `_separate_kin`.
- Bonds: `rec["bonds"] = {uid: -1..1}`, the same both ways (`BaseLife.add_bond`). Tag catches and napping side by
  side raise it; a squabble (two hot tempers meeting at a toy or in tag, or a rival at the toy) lowers it. Friends
  (`friend_at`) greet with a heart and walk over to a napping friend to pile up; rivals (`rival_at`) stare and huff.
  Old saves get an empty map per Boki in the v11 -> v12 save migration (`Save._migrate_11_to_12`).
- Night: every Boki naps till dawn except `Work.NOCTURNAL` species.
- Readout: `BaseLife.readout()` (state, seconds in it, refusals, last transition, bonds per Boki, printed by the
  check). Each machine registers in `Fsm.live` as `boki:<name>`, so the F7 FsmReadout lists them once ext/fsm-m1
  lands.
- Toys: one system, `HomeToys` (home_toys.gd, k["play"], toys.json). It picks, walks, plays, squabbles and shares;
  `BaseLife.choose` asks `HomeToys.pick(k, true)` when a Boki is bored or curious, and the machine shows Play while
  HomeToys owns the Boki (so the history never says Roam while a Boki plays). A squabble at a toy adds
  `bond_squabble`, sharing one `bond_share` (base_life.json). `BaseLife.toy_spots()` lists the toys for chores.
- Feeding itself (GARDEN.md section 2, `scripts/home/base_feed.gd`): a hungry Boki (food under `Econ.HUNGRY_AT`)
  goes to a feeder with food first (HomeEcon), else picks the ripe snack patch and eats one snack (the rest go to
  the pantry), else fetches a snack from the pantry (Save.d crops) at the house door or the landing. The walk is
  the Eat state (k["life_eat"]); the meal is `Care.feed`, so the journal and lean see it.
- Sulky, never sick (care.json `sulky`, `Care.sulky()`): on base_mode every need bottoms out at its floor in both
  `Care.tick` and `Care.change`, and the starve clock never builds (`starve_step`, `starve_stage`, `starve_cap`),
  so a Boki left alone gets hungry and glum and feeds itself, never weak or sick.
- Duo bonus (`scripts/home/base_duo.gd`, `content/rules/base_duo.json`): friends at bond 0.6 or more wake +6 joy from a shared nap (8 s asleep side by side), hand off cleanly in the Dash (x1.06 pace into a stretch with the friend alongside), show a heart pair and "Duo with X" on the Boki card in the Burrow view, and get one journal line the first time. The Show Ring joint trick waits for the Show Ring. Check: `--duo-check`.
- Soak: `--garden-soak` (tools/garden_soak.gd) lives six Boki 30 in-game days (friends, rivals, baby, retired elder, three toys, snack patch, Dash and Shove each third day, the player feeds three of the six daily and picks the patch every other day) at 0.25 s steps without frames (about 10 s), fails on a stuck state, a need outside 0..100 or under its sulky floor, any starve stage, a NaN or out-of-range trait, a bond outside -1..1, a toy held 60 s, the save over 2x, an engine error, or an unfed Boki that never ate on its own, and writes every state change to user://garden_soak.json.
- Legacy (GARDEN.md section 3, `scripts/core/mentor.gd`): an Elder (stage 16) retires from its card ("Retire as
  mentor", one-line confirm, `scripts/home/mentor_card.gd`; needs the Soul Shrine, not your partner). `rec["mentor"]
  = {gifted}`. In `BaseLife` it is the MENTOR state: slow steps (`Mentor.PACE`, `mentor`/`mentor_radius` in the
  rules) near the shrine, eating and napping with the rest, no jobs. At the next egg laid in the Nook
  (`home.gd _make_egg`) the first mentor with a gift left gives ONE: a trait (the baby's pulled toward the
  mentor's strongest), a habit (its quirk) or a memory line, kept on `egg["gift"]`, applied on hatching and shown
  on the hatch card (`baby["gift"]`). Nothing resets; old saves lack the keys and need no migration.
  `--mentor-check` covers it. Not done: a mentor can still be made your partner; only one gift per retirement.
- Trait drift (GARDEN.md 3, lever 3; `scripts/home/base_drift.gd`, `content/rules/base_drift.json`, check
  `--trait-drift-check`): when the farm's day clock wraps, `BaseLife.step` calls `BaseDrift.day`. Each Boki's four
  traits close `step` of the gap to the average of its friends (bond at or above `friend_at`; rivals and strangers
  do not pull). A trait moves at most `week_cap` per drift week (`rec["drift"] = {day, moved}`, optional, no
  migration). Crossing a band in `bands` writes one journal line ("is getting braver", same shape as
  `CareJournal.note`).
- Parents (GARDEN.md section 6): `Care.breed` saves who gave what in `rec["gifts"]` (`Parentage`; the parents' uids
  are already `rec["lineage"]["parents"]`; old babies have no gifts: read with `.get`, no migration). A young (not
  yet Grown) Boki adds `parent_weight` to its liking for a parent when it picks whom to greet and whom to nap beside
  (`BaseLife.regard`), so a parent it fell out with still loses. The first time goes in its journal (kind "parent").
  The hatch card (home.gd `_name_baby`, base_mode only) lists the gifts in words; `egg_hatch.gd` stays quiet.
  Check: `--baby-parents-check`.
- Family tab (GARDEN_MODERN 5 rank 8): the Boki card's Family tab (`scripts/ui/family_view.gd`) shows parents and
  grandparents (portrait, name, type), the mentor's gift (`rec["gift"]`) and the nest items used
  (`rec["lineage"]["nest"]`, written by `NestItems.hatched`). It only reads lineage and the roster: a Boki with none
  recorded is "wild", a parent you no longer have shows by name, and an owned ancestor opens its card. Check:
  `--family-tree-check`.
- Looks (rigged Boki): `HomeToys.pose` sets the `kact` meta from what a Boki is doing: `munch` at a feeder, and the
  toy's `clip` (toys.json: nudge, climb, splash) at a toy; Tumble's rush, brace and dodge and Echo Steps' stonehop and spin play on the same rigs. A napping Boki (`kstate` sleep) settles, naps and wakes (`scripts/match/boki_home_clips.gd`). A rigged Boki
  poses its own body, so the Body squash and toy bounce stay for the primitive ones only.
- Wading (`scripts/home/boki_wade.gd`, `content/rules/wade.json`, base_mode only; the Bramblebank stream and the
  Glasswater pools): a Boki in pond or stream water sinks into it, walks at `wade_speed` (shallow) or `deep_speed`
  (middle) of its dry pace, leaves a ripple and a splash going in and shakes off coming out. Water, Ice and Crystal
  types (`HomeToys.lean_of`: lean, else species theme) paddle: a free roaming one lingers 4 to 8 s playing the
  `splash` clip and gains `joy_per_sec`. Fire types hurry out at `out_speed` to the nearest dry ground and shake off.
  The rest wade through. Check: `--wade-check`; `--garden-nav-check` has a stream in the sweep. **Clips for the anim
  lane** (none exist yet; the walk just slows and the shake is a Body wobble): `wade` (a slow knee-high walk loop),
  `shake` (a shake-off, 0.6 s), `paddle` (a longer water-play loop; `splash` stands in).
- Walking on the farm (`--garden-nav-check`: 6 Boki, every toy and a house, 600 s of game time at 0.25 s a step, logs
  stuck (3 s wanting to move with no progress), overlap (3 s) and standing inside a block; zero stuck and zero inside
  is the bar). What keeps them moving: `scripts/home/kin_avoid.gd` bends a walker round parked Boki (asleep, in the
  tub, held, at a toy or bowl; they also hold their ground in `_separate_kin`), steps a boxed-in walker out and
  drops its errand (toy walk, chore) if that repeats; `HomeToys.stand` keeps a toy's standing place off anyone parked
  or on their way there, and a toy with a sleeper beside it is left alone; `HomeBuild.steer` cuts corners only where
  0.5 m either side is clear. Overlaps are printed and counted, not failed: a runner cornered at an island rim in
  tag is caught on top of (a rim-flee fix made tag catches rarer and `--base-life-check` flaky, so it was left).
