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
  Old records get an empty map in `Care.ensure`.
- Night: every Boki naps till dawn except `Work.NOCTURNAL` species.
- Readout: `BaseLife.readout()` (state, seconds in it, refusals, last transition, bonds per Boki, printed by the
  check). Each machine registers in `Fsm.live` as `boki:<name>`, so the F7 FsmReadout lists them once ext/fsm-m1
  lands.
- Toys: placed layout items whose id is in `toys` (today only the Training post; GARDEN.md 9.3 adds more).
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
