# 0019: How NPCs talk, and how they read from the top-down camera

- **Status:** accepted
- **Date:** 2026-11-08
- **Area:** farm / UI

## Problem
Owner, Nov 7: from the top-down camera Hob reads as a hat, and talking to him opens a plain panel. Every
NPC needs a proper dialogue box (a large portrait in three moods, a name plate, typewriter text with voice
blips after a '...' bubble, tap or click to go on), the camera easing in on the speaker, and the tutorial
waiting while they talk. In the world they need an outline, a name tag, and an arrow when off screen.

## Options
1. Build it into FarmHob. Each later NPC would copy it.
2. Three small parts, keyed by a speaker id in `content/rules/npc_talk.json`: `NpcDialogue` (the box),
   `NpcBeacon` (the outline, the name tag and the edge arrow, riding on the model), and `FarmTalk`
   (home.gd's panel slot and the camera).

## Decision
Option 2. A new NPC adds a `speakers` entry, calls `NpcBeacon.attach(model, id)` and
`h.npc_talk.open(id, model, lines)`. The box sits in the panel slot, so movement stops and Esc closes
it. FarmGuide skips its poll while the box is open, so the tutorial waits. Until painted portraits exist
at `res://art/portraits/<id>_{mood}.png`, the portrait is a one-off render of the model's face, and the
mood shows as the frame colour. Hob's head and hat are bigger. The arrow shows only while he has
something for you (new blueprints, or the tutorial's "meet Hob" step); the alternative was always.

## Consequences
- home.gd gets three lines of wiring. No save or Net change. Hob's names move from farm_builder.json into npc_talk.json.
- `--farm-tutorial-check` covers the beacon, the box, the camera and the tutorial pause.
