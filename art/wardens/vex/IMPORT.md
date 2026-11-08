# Vex (gunslinger): import note, v2 design (2026-11-06)

`vex.glb`: the owner's locked v2 redesign (briefs/art-refs/vex_v2/: index.md, master_sheet, turnaround), on the shared armature, under 15k
triangles (10.7k), six material slots, one 2048 atlas plus its normal map, hand-keyed clips (docs/art/wardens/CLIPS.md, content/rules/warden_anim/vex.json).
Raw files in ~/meshy/vex_v2 (never in git); the Meshy tasks and credits are in docs/art/wardens/PIPELINE.md.

    python3 -I tools/meshy/meshy_task.py edit ...      # body views: bald, minigun and coin chain out; head views from a head sheet; prompts in ~/meshy/vex_v2/edit.sh
    python3 -I tools/meshy/meshy_task.py create ~/meshy/vex_v2/runA in/front.png in/left.png in/back.png --texture-refs in/*.png
    python3 -I tools/meshy/meshy_task.py create ~/meshy/vex_v2/hrunA hin/front.png hin/left.png hin/back.png hin/tq.png --pose ""
    godot --headless -- --warden-rig-json --warden=gunslinger     # after any body change
    ~/meshy/vex_v2/build.sh [source|shape]                         # tools/art1/vex_source, vex_headscan, vex_finish, vex_clips

Anatomy (owner): her right forearm IS the minigun from the elbow down, no hand. `upper_arm.R` is her own arm in the jacket sleeve; `forearm.R`
carries the whole gun rigid (hand.R follows it, unskinned), so aim = arm pose: the brass cuff over the elbow, the receiver with its side boss,
six barrels on `gatling` (spins), the ammo drum under the receiver, the ribbed belt loop over the top, the chain with the bullet charm. The left
forearm and hand are brass machine parts, rigid per bone, with the gold coin on `coin`. The stickers, the trousers' green splatter and tally marks,
the shoulder tattoos and freckles are texture. The gold coin hip chain is rigid on `hips`.

v2 has no launcher tube: the `launcher` bone stays for the clip set and carries no mesh (the clips no longer swing it); `launcher_muzzle`
and `launcher_fire` stay at the drum's mouth but nothing leaves from them now. Coin Blast (the flicked coin) and Palm Lance (the charge and
beam) leave from `palm_emitter` on `hand.L`, 4 cm to the palm side and 7.5 cm along the hand from the wrist (tools/art1/vex_finish.py).
The game reads that point as the `palm` anchor in content/vfx/gunslinger.json (`hand.L` plus the same offset, off the skeleton's live
pose: the empty's BoneAttachment3D lags the clip); --gunslinger-combo-check holds the two together.

FX points (empties on bones): `gatling_muzzle` (= `weapon_muzzle`), `palm_emitter`, `launcher_muzzle`, `launcher_fire`, `anchor_gatling_root`, `anchor_sleeve_mouth`
(the cuff's top), `anchor_grenade_drum`, `anchor_eye_glow` (= `anchor_lens`: her mechanical left eye; nothing glows there), `anchor_spine`,
`anchor_coin`, `anchor_left_hand`, `anchor_pack` (her left shoulder blade), `anchor_chest`, `anchor_head_top`.

Head: a separate Meshy scan of a v2 head sheet, placed on the body by its eye line and chin (H_EYE, H_CHIN in build.sh, read on the scan's
gridded front render); the scan's braid is cut and rebuilt on the spring chain. Gun length elbow to muzzle 0.55 m = 31% of her height
(the turnaround: about 30%).
