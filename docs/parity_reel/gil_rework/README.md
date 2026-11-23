# Gil rework (owner playtest 11-11): before / after, game camera

`tools/parity_reel.gd` (`--parity-reel --reel-hero=gil`) in the Training Grounds against a dummy, cut per part
(960 px, 30 fps). Before: 272368589 (0.24.5 gate). After: ext/gil-rework-1111 db0230d4c.

| part | before | after |
|---|---|---|
| LMB taps (thrusts) | before_lmb_tap.mp4 | after_lmb_tap.mp4 |
| LMB held (after: the Tide Lunge) | before_lmb_hold.mp4 | after_lmb_hold.mp4 |
| RMB (Grab Bag) | before_rmb.mp4 | after_rmb.mp4 |
| E (Riptide, spin then spout) | before_e.mp4 | after_e.mp4 |
| X (Tidal Wave; the reel's "R" key cap) | before_r.mp4 | after_r.mp4 |
| Shift on the ground (Ground Swim) | before_dash_ground.mp4 | after_dash_ground.mp4 |
| Shift in the air | before_dash_air.mp4 | after_dash_air.mp4 |

The reel casts the ult standing still, so the old wrong-way push (a cast while moving) doesn't show in
before_r; `--gil-kit-check` covers it (casts while running back and sideways).
