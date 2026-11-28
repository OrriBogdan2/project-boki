## HUD CPU per frame, measured by zone (11-26)

`--perf-bench --bench-fight` prints `BENCH fight zones`: every `Prof.begin/end` zone's ms per frame (Prof sums them
while the bench runs; Tracy builds still get the zones). `--bench-nopanels` hides the 20 Hz panel canvas.
On rp2g-0 (1920x1080, medium) the HUD's script cost was spread thin: Hud.c's draw 1.7 ms (world labels 0.9, plates'
key 0.4 and repaint 0.35, crosshair 0.2, buffs 0.2), the panels 1.0 ms a frame (abilities 0.3, minimap 0.3,
weapon 0.25, vitals 0.13), and `_clear_under_toasts` 0.5 ms in the Hud's `_process`. Panels hidden: process
rest -1.1 ms, draws unchanged (the HUD's ~200 draws are Hud.c and the plates).
Cut here: a world label's text is measured once (`MsgLane.label_rect`, was a full shaping per label per
frame), each label's box once per frame, vector icon glyphs recorded once per id, size and colour
(`Icons.Rec`), key caps kept until a binding changes, and the buff stack moved onto the 20 Hz panel canvas.
