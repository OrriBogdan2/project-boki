# Where a Boki or Hunter 3D model is built (11-23 audit)

Check: `godot --headless --path . -- --boki-everywhere-check` prints one `BOKI_EVERYWHERE <species>` line
(glb, has, models_kin, reveal, visitor: `rig` or `FALLBACK`) and one `HUNTER_EVERYWHERE <arch>` line per Hunter. It fails
when a species with data is not rigged (only `KNOWN_NO_MODEL` may be), or a Hunter does not wear its .glb.

## Boki: one builder, no caches

Every 3D Boki is `Models.kin(species, rec)` -> `KinModels.build` -> `BokiRig.has(species)` (enabled, a `FRAME` row,
`art/kin/<id>/<id>.glb` imported) ? `BokiRig.build` : the old primitive bodies. Evolved forms are species rows
(`content/rules/evolve.json` ids), so they go the same way. Two other callers only decide, they do not build:
`garden_visitor.gd` (a visitor must have a rig) and `kin.gd` (cast wind-up).

| Surface | Code |
|---|---|
| Match: companion, wild, bots, wisp pop | `kin_wisp.gd`, `boki_wisp_pop.gd` -> `Models.kin` |
| Farm, base, interior, garden, town | `home.gd`, `home_build.gd`, `home_work.gd`, `item_hold.gd`, `interior.gd`, `clan_base.gd`, `base_relay.gd`, `town.gd` |
| Hatch and starter reveal | `egg_hatch.gd`, `kin_reveal.gd`, `hatch.gd`, `prologue_boki.gd` |
| Bokidex, box, party portrait | `dex_view.gd`, `kinbox_view.gd`, `kin_portrait.gd` (portrait viewport cached per look) |
| Results stage | `results_stage.gd` |
| Shop | no 3D Boki |

## Hunter: `Models.hunter(..., arch)` -> `WardenGlb.dress`

An empty `arch` takes the look's arch, else the class default (`HeroKit.arch_for`), so it still wears a .glb, just maybe
not the right one. Passed the real arch: match (`hunter.gd`), home, interior, town (you, and other players: presence
sends `a` since 11-23; before that every peer showed its class's default Hunter, and an older client still does),
results (`results_stage.gd`), hunter select and lobby (`portraits.gd`, `preview_build.gd`), prologue Boki scene.
Without arch (procedural on purpose or by lack of data):

- `mask_moment.gd`: you, unmasked, shown with your own face.
- `look_locker.gd`: the look editor edits the procedural body's face and hair.
- `prologue.gd`: the sky crowd of class dummies.
