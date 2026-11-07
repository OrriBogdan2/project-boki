# Hem (archer; shown as Ravyl): import note, ART-1 rebuild for Ravel v2 (2026-11-07)

`hem.glb`: one Meshy multi-view scan of `ravel_v2_turnaround.jpg` (brief: briefs/art-refs/ravel_v2/ on ext/agent-briefs) plus scripted parts, on the
shared armature, the ids and file names kept. Raw files in ~/meshy/ravel_v2 (never in git). 13.9k triangles with the bow, one 2048 atlas (`hem_atlas.jpg`,
the pieces on flat cells at its right edge) and a 512x256 RGBA card atlas (`hem_cards.png`). No normal map. Slots: skin, hair, cloth (corset), leather (skirt, belt, boots, bow), metal, card.

Scripted (tools/art1/hem_pieces.py): the closed bow hand, the bow (1.6 m), the two back needles (1.21 m, 0.67 of her height, as on the sheet) lashed in an X,
severed strings, thread spools and pins on the belt, bun pins, the arrow. Cards (hem_finish.py): the frayed thread hem, on the skirt chains, and the smoke at her hair's ends.

    ~/meshy/ravel_v2/build.sh source    # source (hem_source.py: scan -> rig rest pose, heel flattened, Low), finish (hem_finish.py), clips (hem_clips.py)
    INSTALL=1 ~/meshy/ravel_v2/build.sh # copies stage/c/hem_out.glb here

48 clips, the same set as before, keyed in hem_clips.py (poses lifted with her hips). Rig: `legs` 2.05, `neck` -0.05 in content/archetypes/archer.json; regenerate with
`godot --headless -- --warden-rig-json --warden=archer`. The scan's eyes are painted, so `lid.*` blinks move nothing visible.
