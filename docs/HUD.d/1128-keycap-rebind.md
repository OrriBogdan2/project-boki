## Key caps follow rebinds (`--keycap-rebind-check`)

Every slot's key text comes from `Settings.key_cap(action)`, never a letter. The check moves each slot's action (LMB,
RMB, E, R, Q, V, Shift, the Boki key, belt 1 to 4) to a new key, mouse 4, mouse 5 and an alternate (first key cleared),
then reads the bar's key pill, the tooltip, the recast "<KEY> AGAIN" cue, hint and drill call-out and the tutorial
cap. It also asserts old saves' custom bindings survive `KeyMigrate`. Tutorial and hint wording is `--tut-rebind-check`.
