## Vex timing on the native model (2026-11-28, branch ext/vex-native-timing)

Closes the "check cannot run" half of `1126-vex-recheck.md` row 9. `meshy_native` stays on (owner call).
`tools/vex_anim_time_check.gd` now times `Warden/Native` (WardenNative) when she has no `Warden/Sync`: the same rows,
the same tolerances (`BLEND_IN`, `CLIP_TOL`, `BACK_SLACK`), read off the native player (a swing or cast owns the body
while `attack_left` runs, the upper layer while she moves, the dash clip while she rolls). The contract path is
unchanged. It runs inside `--gunslinger-combo-check` (there is no separate flag).

What it reads on the native model: she has no `kmoves` rows, so every move (shot, RMB, E, R, knock, and a dash that
moves) plays the one `Attack` clip, 1.40 s at `attack_rate` 2.0 = 0.70 s; the dash plays `Dash_L` (0.53 s) while she rolls.

| Move | Clip starts | Ability | Native clip / hand-back | Row |
|---|---|---|---|---|
| LMB | press frame (0.03 s) | round on the press | Attack, repeats | PASS |
| RMB | press | coin on the press, flick 0.5 s | 0.70 s, back at 0.72 | FAIL: 0.2 s too long; and pressed standing, the full-body clip holds her legs while she walks off |
| Shift tap | roll | skid 0.47 s | Dash_L 0.53 s, back at 0.47 | the moving press also lays an Attack on the upper layer: 0.70 s, back at 0.85 (FAIL) |
| Shift held | roll | slide 0.73 s | Dash_L 0.53 s (no loop), back at 0.73 | FAIL: the clip ends 0.2 s before the slide |
| E | press | beam at 0.63 s, held until 1.23 s | Attack 0.70 s, back at 0.72 | FAIL: she is back on her legs 0.5 s before the hold lifts |
| R | press | shot at 0.15 s, 0.6 s | Attack 0.70 s (upper layer), back at 0.85 | FAIL |
| Knock | cue | 0.6 s | Attack 0.70 s | FAIL |

The red rows are real: one generic clip cannot match per-move lengths. The fix is her own `kmoves` rows (clips by move,
as Cinder's and Lace's), a model/clip task, not done here.
