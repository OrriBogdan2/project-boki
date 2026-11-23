# 0004: Shared aim modes and pooled telegraphs (AimKit)

- **Status:** accepted
- **Date:** 2026-11-02
- **Area:** combat / UI

## Problem
The hero sheets (briefs/hero-ref) need cursor-placed shots on weapons other than `boom` ones, and a dozen telegraph shapes (lanes that grow or narrow, a closing V, cones, sweet-spot circles, arc walls, dotted lanes, swap markers) plus cursor states (charge ring, full flare, perfect star). Before this, `Hunter._emit_shot` clamped only `boom` rounds, and kits made one tweened node per telegraph.

## Options
1. Each kit builds its own: fast to start, six different looks, nodes per frame.
2. One shared kit: a per-shot or per-weapon aim mode, plus an immediate-style telegraph API drawn into one pooled mesh per match.

## Decision
Option 2. `AimMode` decides where a shot goes: the per-shot `Hunter.shot_aim` first, then the weapon's `"aim"`, then the old default (`boom` = cursor). `AimKit` draws every telegraph into one ImmediateMesh surface per match (`AimDraw`), and its cursor states on one Control. `ArchKit.drop_holds()` clears both on merge start.

## Consequences
- Files: scripts/match/aim/*. Wiring: hunter.gd (one var, the aim branch in `_emit_shot`), arch_kit.gd (`drop_holds`), bulwark_kit.gd (one call).
- Default behaviour is unchanged for every existing weapon.
- No Net change: shots already sync their life, and telegraphs are local visuals.
- Check: `--aimkit-check`.
- Debt: `ArchKit.tele_circle`/`tele_lane` remain until the kits move over (docs/DEBT.md).
