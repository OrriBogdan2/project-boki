# Wall kick and bounce: what each Hero plays (audit, 2026-11-09)

All 12 Heroes play their hand-keyed clips (`content/rules/warden_anim/*.json`); none has a wall clip and none lists the
wall in `procedural`, so the HunterAnim fallback never shows here. During a kick (WallMoves.try_kick) or a bounce
(WallMoves.hit) each one kept playing its air clip (`rise`/`jump` going up, `fall` coming down). Gaps found, every Hero:

- **Air pose on the wall:** the kick and bounce have no pose of their own; the body reads as a plain jump next to a wall.
- **Feet not meeting the wall:** on the contact frame the nearer sole was 0.13-0.66 m off the wall face (table, "clips
  alone"); Ostra's floating hem crosses it instead (-0.22 m on a bounce).
- **Snap on the push-off:** none in the clips (they don't react at all); the new layer's release is eased (`LET_GO`).

Fix: `WardenWall` (`scripts/heroes/warden_wall.gd`), one shared layer in every Hero's Sync after the clips, fed by
WallMoves' contact frame (the face found once per kick or bounce). It solves the nearer leg onto the face with the Hero's
own leg lengths, holds the spot through the push and eases back to the clip; a bounce or push-off (body already leaving
fast) has the sole on the wall that frame, a kick eases it in over 0.05 s; a short leg (Pip, a facing kick 0.4 m off)
leans the body in. The move's timing is unchanged (`--wallmove-check` 0 failures).

`--wallpose-check` (sole within 0.10 m of the face on the contact frame, all 12, 0 failures). Sole to face on the
contact frame, clips alone / with the plant, and the frames it stays within 0.10 m:

| Hero | kick: clips alone / plant (frames on) | push-off | bounce |
|---|---|---|---|
| gunslinger (Vex) | 0.33 m / 0.020 m (10) | 0.47 m / 0.020 m (3) | 0.28 m / 0.020 m (5) |
| juggernaut (Kael) | 0.31 m / 0.027 m (10) | 0.45 m / 0.027 m (3) | 0.23 m / 0.027 m (6) |
| ashwick (Cinder) | 0.38 m / 0.026 m (10) | 0.52 m / 0.026 m (3) | 0.29 m / 0.026 m (5) |
| tender (Pip) | 0.43 m / 0.014 m (6) | 0.57 m / 0.014 m (1) | 0.37 m / 0.014 m (1) |
| dolm (Tarek) | 0.52 m / 0.017 m (8) | 0.66 m / 0.017 m (3) | 0.29 m / 0.017 m (5) |
| archer (Hem) | 0.39 m / 0.021 m (10) | 0.53 m / 0.021 m (3) | 0.37 m / 0.021 m (4) |
| dredge (Dredge) | 0.27 m / 0.034 m (10) | 0.40 m / 0.034 m (3) | 0.16 m / 0.034 m (6) |
| rimewright (Claire) | 0.48 m / 0.019 m (9) | 0.62 m / 0.019 m (2) | 0.44 m / 0.019 m (3) |
| mage (Ryzz) | 0.40 m / 0.021 m (9) | 0.54 m / 0.021 m (2) | 0.34 m / 0.021 m (4) |
| bulwark (Breaker) | 0.17 m / 0.053 m (9) | 0.31 m / 0.053 m (1) | 0.13 m / 0.053 m (2) |
| thief (Sable) | 0.43 m / 0.020 m (9) | 0.56 m / 0.020 m (2) | 0.34 m / 0.020 m (3) |
| ostra (Ostra) | 0.17 m / 0.016 m (12) | -0.03 m / 0.008 m (2) | -0.22 m / 0.018 m (3) |

Strips: `--wallpose-check --shots-dir=<dir>` on a GPU, `tools/wall_pose_sheet.py <dir> <out>` lays them out (one sheet
per Hero, each case clips above, plant below, every 2nd frame from the press or hit). The carved wall is drawn as a
stand-in block (the terrain mesh predates the carve).

Open: remote players (the other machines) still play the air clip on the wall: kicks and bounces run on the owner and
only the kick's scuff ("whop") goes over the wire. Pip's plant reads small in the side-on strips (her body hides the leg).
