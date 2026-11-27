## Glide after an attack or ability, every Hunter (`--glide-after-attack-check`, 2026-11-26)

Asked (owner 11-26): "if i lmb, then let go then try to glide it doesn't work sometimes". In the air each Hunter does one
action (LMB held 6 steps then released, RMB, E, Q, X, Shift), waits 0, 50, 100 or 200 ms, then presses glide: a second
Space held, or a 50 ms tap. Pass: the glider is open within 0.1 s of the press when only a recovery pose is left; while the
action itself holds (a charge, a channel, a planted cast, a knock) a held press opens within 0.1 s of its end, and a tap
inside `Loco.press_buffer` of that end does too (a longer lock refuses a tap). Cause: `AirLimits.move_running` shut the
glider for a kit move's whole pose (an LMB tap ~0.35 s), and an arm let go inside it was forgotten. Fix: a fresh press cuts the
pose short and stays armed `Loco.press_buffer` (0.15 s) after it is let go (decision 0180).

| Hunter | trials | glide dropped before | after |
|---|---|---|---|
| Lace (archer) | 48 | 11 | 0 |
| Kael (juggernaut) | 48 | 7 | 0 |
| Vex (gunslinger) | 48 | 12 | 0 |
| Albert (bulwark) | 48 | 7 | 0 |
| Neve (rimewright) | 48 | 10 | 0 |
| Cinder (ashwick) | 48 | 6 | 0 |
| Tenzo (dolm) | 48 | 8 | 0 |
| Sparkle (mage) | 48 | 8 | 0 |
| Grimble (dredge) | 48 | 11 | 0 |
| Meeko (tender) | 48 | 14 | 0 |
| Sable (thief) | 48 | 17 | 0 |
| Motley (ostra) | 48 | 13 | 0 |
| Gil (gil) | 48 | 7 | 0 |
| **all 13** | 624 | **131** | **0** |
Held ults and channels (Neve X, Motley X, Vex E hold, Tenzo's Quakefall) still wait for the action's end.
