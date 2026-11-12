# Hit reactions: the react-2 port (Nov 12)

ext/react-2-port takes the useful part of held ext/anim-react-2 (docs/MERGE_0246_ANIM.md) onto 0.24.5's additive
flinch (WardenClips: the hit clip less its first frame over the spine and arms, `flinch_w`). Its Add2 layer
(`_make_flinches`) is not ported: one flinch system, the same hit rhythm as before (hit_t from the state).

- **Knock lean** (`scripts/heroes/warden_knock_lean.gd`, WardenKnockLean): a hit under 0.6 s old and a body faster
  than 1.4x his run speed, or moving in the air, tips the hips toward where he is sent (0.5 rad at 8 m/s, eased at
  14 /s): back from a hit on the front, forward from one behind, sideways from the flank. It reads only the state
  HunterAnim fills (hit_t, vel, face, grounded), so a remote copy leans the same way at the same time. Pose only:
  stun and knock numbers are untouched.
- **Stun loops** that barely moved (0.041-0.069 of the height), scaled with `tools/art1/glb_react.py <glb> stun
  scale <k>`: hem 2.4, vex 2.3, tarek 1.7, claire 2.3, ryzz 1.7, sable 2.3, ostra 2.1 (seam 0.016, bar 0.02).
  Now 0.085-0.117.
- **Light hits re-timed** (`tools/art1/glb_retime.py <glb> hit_f|hit_b 0:0,0.07:0.07,0.24:0.42`): ryzz (Sparkle)
  and sable settle in 0.20 / 0.23 s (were 0.33 / 0.37). Hem (Lace) and claire (Neve) were not re-timed: their
  11-10 hit clips sit off the idle the whole hit, so a retime only holds the off pose longer (OPEN in the audit,
  docs/DEBT.md). react-2's Mossy hips nudge and Lace's 1.8x back hit are not needed any more: the 11-10 clips
  already read 0.18 / 0.19 at 0.1 s.

Not ported: react-2's flinch over a cast (a kit move still wins the pick, as on 0.24.5).

## How it is measured

`godot --headless --path . -- --react-audit [--wardens=a,b] [--json=f]` (tools/react_audit.gd, from
ext/anim-react-audit): per Hunter, the hit's read at 0.1 s and settle time against the weight band, a hit over a run,
the knock lean in four directions (head against hips along the knock, bar 0.04 of height), the stun loop's motion
(bar 0.08) and seam, fall seam, land squash, weapon grip and T-pose. Known fails go in its OPEN table.
Strips: `godot --path . -- --anim-shots --react --close --shots-dir=<dir>` (hit, stun, knock), through
`jobq submit --needs gpu`.

| Hunter | stun move before -> after | hit settle before -> after | knock lean b/f/l/r |
|---|---|---|---|
| archer | 0.042 -> 0.101 | 0.42/0.42 -> 0.42/0.42 s | 0.205 0.199 0.200 0.201 |
| juggernaut | 0.114 -> 0.114 | 0.42/0.42 -> 0.42/0.42 s | 0.251 0.231 0.242 0.243 |
| gunslinger | 0.045 -> 0.102 | 0.42/0.42 -> 0.42/0.42 s | 0.203 0.189 0.197 0.197 |
| bulwark | 0.164 -> 0.164 | 0.36/0.36 -> 0.36/0.36 s | 0.295 0.314 0.307 0.307 |
| ashwick | 0.200 -> 0.200 | 0.42/0.42 -> 0.42/0.42 s | 0.223 0.223 0.222 0.222 |
| tender | 0.189 -> 0.189 | 0.37/0.33 -> 0.37/0.33 s | 0.315 0.312 0.313 0.313 |
| dolm | 0.063 -> 0.107 | 0.40/0.40 -> 0.40/0.40 s | 0.205 0.212 0.208 0.208 |
| dredge | 0.217 -> 0.217 | 0.37/0.37 -> 0.37/0.37 s | 0.254 0.238 0.246 0.246 |
| rimewright | 0.045 -> 0.106 | 0.42/0.42 -> 0.42/0.42 s | 0.217 0.218 0.218 0.218 |
| mage | 0.069 -> 0.117 | 0.33/0.33 -> 0.20/0.20 s | 0.222 0.223 0.219 0.225 |
| thief | 0.046 -> 0.107 | 0.37/0.37 -> 0.23/0.23 s | 0.220 0.221 0.221 0.221 |
| ostra | 0.041 -> 0.085 | 0.27/0.27 -> 0.27/0.27 s | 0.233 0.225 0.223 0.224 |

(Knock lean before the port: none, the base had no lean; numbers are the head against the hips along the knock, share
of height. Juggernaut, bulwark, ashwick, tender and dredge clips are unchanged.)
