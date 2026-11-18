# Hit reaction audit

How every Hunter takes a hit, measured by `godot --headless --path . -- --react-audit [--wardens=a,b] [--json=f]`
(tools/react_audit.gd). It poses the real model through Warden/Sync and reads the bones, no renderer. It is the gate: a
FAIL line and exit 1 for anything below the bar; known, filed cases go in its `OPEN` table.

A chip hit is only WardenFlinch's spring on the torso plus the additive flinch layer; a stagger (`hit_k` at
`Oomph.HEAVY_FLINCH`) also plays the hit clip. The audit feeds a stagger, since that is the clip. A knock (a hit under
0.6 s old, a body faster than 1.4x run or in the air) tips the hips where it sends him (WardenKnockLean).

- **Reads within 0.1 s:** how far the farthest of hips, head, hands and feet has moved 0.1 s after the hit, as a share
  of the Hunter's height. Bar: 0.03.
- **Weight suits the body:** when the flinch has settled back under a quarter of its peak. Light snaps back (0.14 to
  0.30 s), heavy carries the hit (0.24 to 0.45 s), medium between (0.18 to 0.38 s).
- **Loop seam clean:** the stun loop's and the fall loop's last frame against the first, share of height, at most 0.02.
- **Landing squash:** the hips dip in the landing's first 0.1 s by at least 0.02 of height.
- **Weapon stays attached:** the weapon bone keeps its rest offset to its hand within 3 cm (Albert, Lace, Grimble,
  Sparkle, Vex).
- **No T-pose:** no frame has both arms straight, raised past 60 degrees and pointing sideways.

## The v95 glbs, 2026-11-18

Before: FAIL 10 on the v95 glbs. The hit clips of Lace, Neve, Tenzo, Meeko and Sable took the whole 0.42 s (or 0.33 to
0.40 s) to settle: a light or medium body never settled back before the hit ended.

The fix is in the .glb, with no Blender (`tools/art1/glb_retime.py`, `glb_react.py anchor`; both resample the clip at
60 fps and leave the old keys unused):

1. `hit_f` and `hit_b` of hem, claire, sable, pip, tarek re-timed `0:0,0.07:0.07,0.24:0.42`: the pose the clip had at
   0.42 s arrives at 0.24 s and holds.
2. Clips that end off the idle pose never settle back, so they are anchored on the idle's first key (`glb_react.py
   <glb> <clip> anchor idle`): claire and tarek both clips, hem `hit_b`, sable `hit_f`, pip both.

A Blender rebuild from tools/art1 must apply these two steps again (the clip scripts still carry the old keys).

Left open (the gate's `OPEN`): Lace's `hit_b` still settles at 0.42 s. Scaled 1.8x it reads 0.07 -> 0.12 of her height,
but the clip ends off her idle pose and no anchor of the first key fixes the end. It needs a re-key in Blender. Result:
12 Hunters, FAIL 0 once that row is counted as open (before: FAIL 10).
