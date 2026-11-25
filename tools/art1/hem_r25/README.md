# Lace (hem) r25 tools: Crouch skirt no longer lifts into a disc; Attack slit closes (no "trouser" V)
(plan /home/boki/gens/hunter-round-1124/lace/PLAN-1124o.md; numbers + renders /home/boki/gens/hunter-round-1124/lace/r25/)
Cause (r24 review): sway24's closed-loop tilt hit 80 deg in Crouch (the thighs come up level, the only way to clear them was to
flare every sway bone), and the r21 skirt's slit wedge (~30 deg open at rest, -55..-25 deg) faces the camera when she aims.
`sway25.py` = sway24 plus:
- `capc=Jump_Run:25,Crouch:22,run:20`: per-clip tilt cap (first substring match wins, so Jump_Run before run).
- `folc=Jump_Run:0.5,Crouch:0.9,run:0.4`: in those clips the front sway bones also carry that share of each thigh's own swing
  (about the thigh head, split L/R by angle), so the panel drapes over a raised thigh instead of flaring; adds SkirtSw translation keys.
- `slit=1 psi=16 band0=12 band1=30`: two new joints SkirtSlitA/B (children of Hips, rest = Hips) take the slit edge band (weight
  fades 12->30 deg from the gap centre -40 deg and from y 0.86 down to 0.60); each rides the sway at its edge angle and yaws
  +-psi*clo about the hip axis. `cloc=Attack:1.0,lace_:1.0`: closed in Attack and the bow kit moves, open elsewhere.
- `exslit=Crouch exw=35`: in Crouch the right thigh may pass through the open slit (the design), not counted as a poke.
`wb_preview.py`: Blender workbench preview (game camera / eye / knee) for quick A/B; proof renders stay on the GPU (jobq).
r24 -> r25: Crouch mean hem drop min 0.05 -> 0.39 m, hem width 1.70 -> 1.26 m (live 1.18); poke22 Crouch 3 v 2.0 cm -> 1 v 1.4 cm.
