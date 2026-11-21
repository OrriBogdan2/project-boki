# 0098: An explicit kit-move re-time reaches the other games

- **Status:** accepted
- **Date:** 2026-11-12
- **Area:** networking

## Problem
`ArchKit.apply_net_move` resyncs a remote copy's move only when the wire age is off by over 0.3 s (latency and the 0.05 s age snap must not restart it). A kit that moves the clock on purpose by less than that, like Cinder's ram hit jumping `as_leap` 0.19-0.23 s onto its squash key, never shows on the other game: the squash lands late there.

## Options
1. A re-time count as a new field after the move (clean, but a Net shape change and a Net.VERSION bump; collides with ext/feel-remote-move-clear's play count at the same index).
2. Carry the count in the age's hundredths: the age stays snapped to 0.05 s, the count (mod 5) adds 0.00-0.04 s. Same shape; an older peer reads an age off by at most 0.04 s.
3. Lower the tolerance: resends then jitter the clip every snapshot.

## Decision
Option 2. `ArchKit.retime(at)` moves `anim_at` and counts it in `anim_rt`; `net_move` adds the count to the age, `apply_net_move` resyncs when the count changes, at any size. Plain resends keep the 0.3 s `NET_RESYNC`.

## Consequences
`scripts/arch/arch_kit.gd`, `ashwick_kit.gd` (`_bash_impact` uses `retime`). No Net.VERSION bump (shape unchanged). `--remote-anim-check` gains an "ashwick ram hit" row (fails with the count ignored). Other per-frame clock writes (Archer/Pin draw, Bulwark, Gunslinger slide) keep plain `anim_at` and the resync. A restart of the same move within 0.3 s (Vex's rapid LMB, DEBT "Remote kit moves" (2)) is a play, not a re-time, and stays open here.
