## Neve Rimelock early recast: already on main (c78b7cba28, 2026-11-28, branch ext/neve-ult-early)

The reference catalog's gap "ult can be re-pressed to end early, paying about 67%" is already in the kit; no code moved.

| Reference | Ours | Where | Status |
|---|---|---|---|
| Re-press in the closing window finishes early at about 67% | X again in the last `late` 0.75 s of the 3.3 s hold cracks open at `late_k` 0.67 (damage and stun share) | `content/archetypes/rimewright.json` `x.late`, `x.late_k`; `RimewrightKit.ult_recast` | match (since `068fe04225`) |
| Re-press earlier cancels the ult | Earlier X (or Shift) breaks the shell: no damage, no stun, no bond | `ult_recast` -> `_rime_cancel` | match |
| Recast window is readable | `RecastCue.window("x", ...)` ring cue in the last 0.75 s, no key letters | `RimewrightKit` recast cue | match |

Rows: `--rimewright-combo-check` (`tools/care_ult_check.gd` `_rime_recasts`): "X early ends it with no damage, no stun and no bond" and "X in the last 0.75 s cracks it open early at two thirds". The 67% share is data, not code.
