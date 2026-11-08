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

48 clips, the same set as before, keyed in hem_clips.py (poses lifted with her hips). Rig: `legs` 2.35, `neck` -0.05 (`size` 0.922 keeps her 0.98 of a hunter) in content/archetypes/archer.json; regenerate with
`godot --headless -- --warden-rig-json --warden=archer`. The eyes stay the scan's paint; the lids are modelled, so blinks read.

Proportions against the sheet: the scan's body above the hips already fits the rig 1:1 (torso 0.62 m, head 0.295 m, `HEAD_K` 1.0);
`legs` 2.35 puts the rig's hips, shoulders and neck at the scan's (0.987/1.487/1.607 against 0.99/1.5/1.605), so the belt and
the head sit at the sheet's share of her height. Skin under the shoulder mask
is plain porcelain (the scan painted its own mask there, class 0.9 in `class_bake`).
