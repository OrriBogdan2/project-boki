# Cinder (ashwick): import note, ART-1 final design (2026-11-05)

`cinder.glb`: the owner's final design (briefs/art-refs/cinder_FINAL_sheet.png, cinder_turnaround_apose.png), on the shared armature,
one 2048 atlas plus the head texture, hand-keyed clips (docs/art/wardens/CLIPS.md, content/rules/warden_anim/cinder.json). Raw files in ~/meshy/cinder_f (never in git).

    python3 -I tools/meshy/meshy_task.py edit ...   # x4: hair, tail, tank, hoses and vials out; prompts in edit_*/request.json
    python3 -I tools/meshy/meshy_task.py edit ...   # the frontal face plate from the portrait and sheet (edit_face)
    python3 -I tools/meshy/meshy_task.py create ~/meshy/cinder_f/runA in/front.png in/right.png in/back.png in/left.png --texture-refs in/front.png in/right.png in/back.png in/left.png
    godot --headless -- --warden-rig-json --warden=ashwick      # after any body change
    tools/art1/cinder_build.sh source                           # fit, pieces, paint, skin, clips, copy here

`cinder.glb.import`: `generate_lods=false`, `force_disable_compression=true`, `remove_immutable_tracks=false`.
Second pass (FINE-DETAIL): the head has its own surface `skin-cinderhead-hot` and 1024 texture (`cinder_head.jpg`, about 2x the body's density): plates edit_f2 and edit_s2, Meshy image edits of briefs/art-refs/cinder_head.png, projected front and profile. Hair is broad curtains on spring chains, tongues off the crown.

From the scan: torso, corset, shorts, apron, belt, arms, legs, feet. Rebuilt as geometry: head (SDF sculpt, the painted plate projected flat; brows, lids,
jaw, fins on bones), goggles, tail, tank and stacks, gauge, hoses, the nozzle gun (skinned to hand.R, item 76b), hands, vial rack. Fire is strips with raw UV on
shaders/hero_flame.gdshader (`flame` slot), no atlas: hair on spring chains, the tail's fringe and tip, the stacks' jets on `jet.*` bones (the flight clip scales them).
Fuel in the tank and vials: the same shader's `liquid` mode.
