# 0020: Source ground brake, air control and dash exit (KIT_PARITY 2-4)

- **Status:** accepted
- **Date:** 2026-11-07
- **Area:** movement

## Problem
docs/KIT_PARITY.md items 2-4 (all heroes): our ground stop braked at 110 m/s² (source BrakingDecelerationWalking
22.2 m/s² plus GroundFriction 1 × BrakingFrictionFactor 2), air control was 0.3 (source AirControl 0.015,
20x less), and every dash ended in a hard stop (15% carry on the ground, 30% in the air). The source has no hard stop.

## Options
1. Full source exit: keep the whole dash speed and let the UE brake take it. That adds ~2.5 m to every dash
   and breaks the footage-measured kit distances.
2. Source brake and air control, and a dash that hands over at run speed (`dash_exit_run` 1.0), so the run
   carries on and a let-go slides the source's ~0.4 m.

## Decision
Option 2. All four numbers live in `content/rules/hunter_move.json` `physics` (brake, ground_friction,
dash_exit_run, air_control), read by `HunterMove.brake/dash_exit/air_steer`. Speed over a run (a kit step, a knock) sheds under the same brake, keys held or not, as UE's walking
braking does (`HunterMove.brake_rate`; it was a kit-tuned 110 m/s² with no keys and 30 with keys until the
2026-11-09 movement pass, so a 10 m/s shove now slides 1.4 m, not 0.7). `Hunter._lunge` solves its push from
that brake (`HunterMove.slide_speed`), so swing steps keep their lengths. A kit step with a measured total takes the exit slide off its dash (`HunterMove.slide`, Bjorn's
swing step). A CastHold hover (`ArchKit.hovering`: Dredge's hook and broadside, Ostra's swap) steers like
the ground, as the owner asked (items 31, 75), not with the near-nil air control.

## Consequences
A jump now keeps its run-up and barely steers, as in the source. `--move-feel-check` asserts the source
numbers. The source's dash curves are still undecoded, so the run-speed hand-over is our call (docs/DEBT.md).
