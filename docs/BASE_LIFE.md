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
- Toys: placed layout items whose id is in `toys` (today only the Training post; GARDEN.md 9.3 adds more).
- Coming home (GARDEN.md section 2; `BaseLife.come_home`, check `--homecoming-check`): `Game` sets `BaseLife.returning`
  when a run ends and the base is on; the next farm that opens runs `come_home()` once. Every free Boki on the
  portal's island (napping ones only at `home.nap_trust`) goes into React with `life_home` on its kin entry, one
  `home.stagger` after the one before it, highest trust first. It runs to the portal, then greets by trait (bravery
  at `bound_at` bounds in, under `shy_at` peeks from afar, else waves) and goes back to what it was doing (Nap
  naps again, Play returns to its toy, others Roam). A whistle, pet or job ends it early. The "while you were away"
  card is untouched. Boki on other islands are not sent for.
