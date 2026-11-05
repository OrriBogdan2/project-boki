# INBOX for S3 (cloud session). ext (the coordinator) posts orders here; check every 30 min.

## 2026-11-05 06:30 UTC (ext): ABILITY VFX for all 12 Hunters (owner: max pace)
Combat clarity (96) is merged, thanks. New job.
- **Agents:** up to 4 (Opus for VFX).
- **Branches:** one per Hero, `ext/vfx-<hero>` from origin/main.
- **Read per Hero:** `briefs/art-refs/<hero>_FINAL_sheet.png` (+ `_weapons`), plus the kit in `content/archetypes`. Names: Lisette = the archer (files `hem_*`); Motley = ostra; Grimble = dredge.
- **Each ability:** telegraph → impact → linger in the Hero's palette.
  - Shader-based (GPU particles, mesh trails, dissolve/noise); no flat rings.
  - Follow your item-96 colour rule; stay within the perf budget (particle caps, LOD).
- **Signature moments:**

| Hero | Signature VFX |
|---|---|
| Lisette | red-thread needle shots |
| Kael | white-hot blade + scarf embers |
| Breaker | sea-path ult + anglerfish lure flare |
| Motley | ground void vortex + burning cards |
| Cinder | flamethrower + tank jets in the ult |
| Grimble | coin/nail blunderbuss spray |
| Claire | frost trail + freeze |
| Pip | starlight heals |
| Sable | violet pistol shots + smoke |
| Ryzz | finger-gun lightning + rod arcs |
| Tarek | Rock Hop rocks + eye-stones |
| Vex | green tracers + makeshift grenades |

- **Attach points:** S2 is rebuilding the 3D models. Attach FX to hand/weapon bones by name per `docs/RIG_STANDARD.md` so they carry over to the new models.
- **Report:** post READY per Hero in `briefs/EXT_TO_MAIN.md`; S5 merges.
- **Rules:** as before (fresh XDG, `timeout 1200`, big files wiring-only, reserved files untouched, health --strict).

## 2026-11-05 06:35 UTC (ext): OWNER REQUIREMENT: every READY report must include the hero's rows from `briefs/art-refs/FIDELITY_CHECKLIST.md` as a ✅/❌ table with proof screenshots (e.g. Vex's cannon IS her right arm, Ryzz fires PINK lightning from her fingertips). Check your in-flight work against it now.
