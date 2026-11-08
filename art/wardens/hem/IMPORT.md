# Hem (archer; shown as Ravyl): import note, ART-1 rebuild for Ravel v2 (2026-11-07)

`hem.glb`: one Meshy multi-view scan of `ravel_v2_turnaround.jpg` (brief: briefs/art-refs/ravel_v2/ on ext/agent-briefs) plus scripted parts, on the
shared armature, the ids and file names kept. Raw files in ~/meshy/ravel_v2 (never in git). 14.4k triangles with the bow, one 2048 atlas (`hem_atlas.jpg`,
the pieces on flat cells at its right edge) and a 512x256 RGBA card atlas (`hem_cards.png`). No normal map. Slots: skin, hair, cloth (corset), leather (skirt, belt, boots, bow), metal, card.

Scripted (tools/art1/hem_pieces.py): the closed bow hand, the bow (1.6 m), the two back needles (1.21 m, 0.67 of her height, as on the sheet) lashed in an X,
severed strings, thread spools and pins on the belt, bun pins, the lit red strings round her right hand (`hand_strings`: three loops and two tails, glow slot, rigid on `hand.R`), the arrow, and her eyelids (`eyelids`: a shell per eye on `lid.R`/`lid.L`, pivot 13 mm under
the painted eye, that comes out over it when a clip turns the bone down; open it hides in the face but for its dark lash rim). Cards (hem_finish.py): the frayed
thread hem, on the skirt chains, and the smoke at her hair's ends (dark root to grey-violet).

    ~/meshy/ravel_v2/build.sh source    # source (hem_source.py: scan -> rig rest pose, heel flattened, Low), finish (hem_finish.py), clips (hem_clips.py)
    INSTALL=1 ~/meshy/ravel_v2/build.sh # copies stage/c/hem_out.glb here

48 clips, the same set as before, keyed in hem_clips.py (poses lifted with her hips). Rig: `legs` 2.05, `neck` -0.05 in content/archetypes/archer.json; regenerate with
`godot --headless -- --warden-rig-json --warden=archer`. The eyes stay the scan's paint; the lids are modelled, so blinks read.

Proportions against the sheet: the head is fitted at 1:1 (hem_source.py `HEAD_K`; pass 2 had 1.06). Her belt sits about 8 cm under the sheet's because the
shared rig's shoulders do too (shoulder to belt matches, 0.40 m); lifting it would shorten the corset, so it stays with the rig. Skin under the shoulder mask
is plain porcelain (the scan painted its own mask there, class 0.9 in `class_bake`).
