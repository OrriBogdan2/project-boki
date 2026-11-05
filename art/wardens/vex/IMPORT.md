# Vex (gunslinger): import note, ART-1 final design (2026-11-05)

`vex.glb`: the owner's street-racer final design (briefs/art-refs/vex_FINAL_sheet.png, vex_turnaround_apose.png v3, vex_weapons.png), on the shared armature,
under 15k triangles with the cannon, eight material slots, one 2048 atlas, hand-keyed clips (docs/art/wardens/CLIPS.md, content/rules/warden_anim/vex.json). Raw files in ~/meshy/vex_f (never in git).

    python3 -I tools/meshy/meshy_task.py edit ...      # x4: hair, cannon, belt, coin out; right arm off; prompts in ~/meshy/vex_f/edit.sh
    python3 -I tools/meshy/meshy_task.py create ~/meshy/vex_f/runA in/front.png in/left.png in/back.png in/right.png --texture-refs in/*.png
    godot --headless -- --warden-rig-json --warden=gunslinger     # after any body change
    ~/meshy/vex_f/build.sh [source]                                # tools/art1/vex_source, vex_finish, vex_clips

Anatomy (owner): NO human right arm. `upper_arm.R` is the socket plate and strut, `forearm.R` the rigid cannon (hand.R follows it, unskinned), so aim = arm pose. `gatling` spins the barrels; `launcher` is the
makeshift tube on its post: it rests bell-up past the shoulder (the master sheet) and swings 178 degrees over the top, bell forward, for the RMB (clip key LN). The left forearm and hand are rigid machine parts.

FX points (empties on bones): `gatling_muzzle` (= `weapon_muzzle`), `launcher_muzzle` (on `launcher`, it travels with the swing), `launcher_fire` (the bell's forward place, fixed on `forearm.R`), `anchor_gatling_root`, `anchor_sleeve_mouth`, `anchor_grenade_drum`, `anchor_eye_glow` (= `anchor_lens`), `anchor_spine`, `anchor_coin`, `anchor_left_hand`, `anchor_pack`, `anchor_chest`, `anchor_head_top`.

Fine-detail pass: the head is a separate Meshy scan of briefs/art-refs/vex_head.png (~/meshy/vex_h, tools/art1/vex_headscan.py), placed on the body by its eye line and chin. `vex_normal.jpg` is baked from both scans onto the shipped mesh (use_nrm in hero_toon, from ext/art1-hem); rebuilt pieces stay flat. Cannon length 1.08 m = 57% of her height (the sheet: about 56%).
