# Scrap King LMB, old vs new (NOT FOR MERGE)

Game camera, `--parity-reel --reel-hero=dredge`, parts `lmb_hold` (hold 2.4 s, then let go) then `lmb_tap`
(three taps 0.8 s apart), 60 Hz steps saved at 30 fps, software render on rpc3 (`--fixed-fps 60`).
Old = 272368589 (0.24.5 base), new = ext/scrapking-lmb-1111 281b1a82e.

- `scrapking_lmb_old.mp4`: the spammed fan, then the edge lines snap to one aim line; each tap is one slug-line.
- `scrapking_lmb_new.mp4`: the spammed fan, then the edge lines draw in smoothly to a tight cone; each tap is a pack of seven.
- `scrapking_lmb_old_vs_new_halfspeed.mp4`: old above, new below, at half speed.
