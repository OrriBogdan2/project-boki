# Combat UI declutter

Owner, 2026-11-11: remove words like SWEET SPOT and key letters on world objects; a timer shows as a pure
visual (a flash, a pulse, a ring). Damage and heal numbers stay.

Rule: **in a fight nothing floats or sits on the world as a word or a key letter.**

| What | Now |
|---|---|
| Floating callout words (`fx.word`) | gone; only farm gains, readouts (Gil's count, Bjorn's distance) and a summoned Boki's name remain |
| Key letter on a recast object (Sable's dagger, the hammer) | a plain ring that empties with the window (`RecastCue._marker`) |
| Crosshair ready words (`ArchKit.ready_label`, 8 kits) | gone; the resource arc and the slot's ready dot carry it |
| Combo badges over foes (`RecastCue._badge`, `ComboMark.draw`) | one icon in the foe's plate status row (`HudPlate.row`) |
| STAGGERED / STAGGERABLE over monsters | a yellow / pulsing purple ring |
| DRINKING / REPAIRING under your bars | the filling ring beside your head stays |
| DOWN word in the knock burst | the rays stay; the downed plate shows the fall |

Kept: nameplates and the worst-status word, the ability bar with key caps and "<KEY> AGAIN" on the slot, damage
and heal numbers, objective markers, interaction prompts, one-time teaching toasts.
Checks: `--plate-status-check`, `--recast-cue-check`, `--clarity-check`, `--hudref-check`.
