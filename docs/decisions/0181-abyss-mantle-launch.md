# 0181: The abyss edge is a one-shot mantle launch

- **Status:** accepted
- **Date:** 2026-11-27
- **Area:** movement

## Problem
Owner 11-27: falling in the abyss, the bounce on the edge and the momentum out of it must match the target feel.
Ours floated you up a face (a side caught you only 4.5 m down), pulled a glider up with our own estimated lift
and spring, and flung you off a ledge on guessed numbers. The data has one law for all of it.

## Options
1. Retune our float and fling to the data's numbers: keeps two systems, still a different motion.
2. Port the data's law: over the abyss a side you touch launches you once by depth (mini under 3 m), the glider's
   floor pull lifts you and lets go at the lip; keep our climb on dry-ground terraces (map rule).

## Decision
Option 2, in `MantleCarry` (the existing mantle-momentum file), numbers in hunter_move.json `edge_mantle`.

## Consequences
hunter.gd wiring only (net -30 lines: the dead float-up and our lift/brake/spring go). A side now saves you at
any depth (17.5 m); open air still kills. No save or Net change. `--abyss-edge-check` proves it against the
data's law; old abyss/mantle checks retargeted where they held our estimates.
