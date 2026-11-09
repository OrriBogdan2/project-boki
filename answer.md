# Item 11: Kael (juggernaut) RMB / E / ult (owner 11-08)

Tuning lives in `content/rules/tuning.json` section `kael` (the file did not exist: created, with `Tuning.of`).

| item | status | what I tested |
|---|---|---|
| Live RMB aim during E | done | `--kael-tap-check`: strike goes where the cursor is at the blow, 90 and 180 deg off the E throw (36 dmg both) |
| Tap = overhead strike always available | done | check: tap with Smash resting lands a lighter hit (16 of 26), second tap blocked by `tap_cooldown_s`; hold unchanged |
| Ult keeps momentum | done | check: 6.0 m/s -> 4.8 (carry 0.8), still moving 0.1s in; debug `riposte.vel_before/after` |
| Ult vertical bonus | done | check: vy 3.0 -> 5.2; GPU log vy 6.0 -> 8.2 |
| Ult mid-mantle | partial | ledge rise rewrote vel.y every tick, so a ledge rise is now handed over to the boost; tested with a stub ledge state, not a real ledge |
| RMB aim past tether | done | Lunge backward past the length breaks the tether; sideways inside range keeps it |
| GPU clips | done | job 20261109-032347-06637: tap, hold, ult_sprint, ult_jump (a jump stands in for a mantle). Frame check only; no "before" clips |
| suite-fast | not run | no such command found here; ran `--kael-tap-check` (10/10) and `--juggernaut-combo-check` (183/183, covers kael_accuracy) |
