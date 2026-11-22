# 0062: Stomp styles and the stomp slot

- **Status:** accepted
- **Date:** 2026-11-19
- **Area:** cosmetics, save format, animation

## Problem
The stomp lock (DECISIONS 2026-11-11, life.gd `stomp_time` 2.4 s) asked for per-Hunter stomp styles and a stomp cosmetic slot. The old branches (ext/ui-stomp-picker, 1.7k commits behind) built 13 procedural styles, one per Hunter. Since then 12 of 13 Hunters got their own baked stomp clip (warden_anim `states.stomp`); only Gil has none.

## Options
1. Port all 13 procedural Hunter styles. Cons: 12 would never show (the clip owns the body).
2. Keep the clips as each Hunter's own stomp; data styles only for a rig without a clip (Gil: Fin Slap) and for styles bought with gems (Thunder Stomp, 300). A worn style plays on the rig in place of the clip.

## Decision
Option 2. `content/rules/stomps.json` + `StompLook`; the picker is `StompPick` on the Hunters screen under the Wisp pick. Every style keeps Life's timing. The wire carries no style (Net unchanged): other games show a remote stomper's own stomp.

## Save
`Save.d.look.stomp` (worn id, "" = own) and `Save.d.stomps` (bought ids). Both are optional and read with a default, like `look.wisp`, so old saves load unchanged and no version bump or migration step is needed.

## Check
`--stomp-style-check`.
