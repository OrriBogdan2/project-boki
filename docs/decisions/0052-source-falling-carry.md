# 0052: Source falling carry, landing keeps the run

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** movement

## Problem
How fast a Hunter is moving when it lands decides whether movement flows. `HunterMove.air_steer` bled what
you carry at FallingLateralFriction 0.375/s whether or not keys were held, so a running 1 m hop landed at 0.93x
run and a 4-terrace drop at 0.89x. A let-go bled at half the source rate (1.15-1.28x too far). Letting go
of the glider kept glide speed and glide steering for 0.6 s ([est] FEATHER_KEEP), landing at 1.14x run.

## Options
1. Keep the linear 0.375/s bleed (simple, but not the source in any case).
2. UE's falling CalcVelocity: keys held under run speed only bend toward the keys; keys off or over run speed
   brake at FallingLateralFriction x BrakingFrictionFactor 2 = 0.75/s, and held keys stop it at run speed.
   Touchdown keeps the horizontal speed. A glider let-go falls by the same rule.

## Decision
Option 2. `air_brake` 0.75 joins `air_friction` in `content/rules/hunter_move.json`; `HunterMove.air_steer` is the
UE step (`OVER_RUN` 1.01 is UE's IsExceedingMaxSpeed slack, the same const as decision 0022's walk). The glider's
0.6 s keep after a let-go is removed; FEATHER_KEEP still marks "just off the glider" for ledges and wall climbs.
air_control (0.015) is unchanged: the owner's strong-air-control ruling (11-08) is its own job.

## Consequences
Every way down lands at the source's speed (`--move-feel-check` land_carry_*). A let-go jump carries
2.9 m instead of 3.4 m (air_carry_vs_source). Feathering over the abyss covers 108 m instead of 113 m
(feather_gain 2.42x, target >= 1.15x).
