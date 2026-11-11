# Demo presets (for recording gameplay video)

`--demo=<name>` skips the menus and drops straight into a ready state, for filming. Code: `scripts/core/demo.gd`.

- **Your real save is never touched.** The presets play on a made-up save held in memory only (nothing is read from or written to your save files, and the settings file is left alone). Quit and nothing is kept. The demo save: a grown farm with six level 8 Boki, every Hunter open, axe and pickaxe, ripe crops, 12 expeditions and 9 extractions behind it (so the Hollow is open).
- **Debug overlays are hidden.** Recording mode is on at "clean HUD" (no perf, debug or test text, no tips or hint banners, smoother camera). Add `--record=2` for no HUD at all, or press F10 in game to cycle; F9 (no HUD) turns on the slow camera orbit.
- **Pick the Hunter** for the match presets with `--hunter=<id>`. Ids: `archer ashwick bulwark dolm dredge gunslinger juggernaut mage ostra rimewright tender thief` (default `gunslinger`). An unknown id falls back to the default with a warning.

## The presets

| Preset | You land in |
|---|---|
| `farm` | The farm in the morning: grown Boki walking around, crops ripe, farm buildings up, tools unlocked |
| `match` | The title screen's Demo match: a full 20-hunter bot lobby on The Dusk Isles, clear weather, your Hunter dropping in with a Boki |
| `training` | The Training Area, your Hunter picked, dummies out |
| `care` | The farm with every Boki hungry: they walk to the trough and eat, the care and feeding scene |
| `tier2` | An expedition on the highest tier (The Hollow), full bot lobby, your Hunter picked |

## Launch commands (exported Windows build)

Run from a terminal in the folder with the exe (the exe name is whatever the export is called, here `ProjectBoki.exe`). The `--` hands the flags to the game:

```
ProjectBoki.exe -- --demo=farm
ProjectBoki.exe -- --demo=match --hunter=mage
ProjectBoki.exe -- --demo=training --hunter=gunslinger
ProjectBoki.exe -- --demo=care
ProjectBoki.exe -- --demo=tier2 --hunter=thief
```

Extras that combine with any preset: `--record=2` (no HUD), `--quality=ultra` (video preset for this run only).

From the editor build on Linux: `godot --path . -- --demo=match --hunter=mage`.

## Check

`godot --headless --path . -- --demo-check` boots every preset for a few seconds and asserts the state above, that the demo save is never written and that your save file is byte for byte unchanged. Errors print as `SCRIPT ERROR`.
