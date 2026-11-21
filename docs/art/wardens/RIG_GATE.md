# Rig gate (owner 11-21: rigging is its own gate, separate from the model)

`tools/meshy/rig_gate.py` grades the RIGGING of a hunter glb: PASS / WARN / FAIL per region with numbers. It reuses the
CPU skinning of `tools/hunter_mesh_check.py` (spike edges, far-bone vertices, stretched triangles) and poses the glb
through its own clips: walk (f, l, r), run (f, l, r), downed, death, glide and the primary attack (lmb*, strike-like
clips), 6 poses per clip. A glb with no clips of its own (gil: HunterAnim drives it) borrows `--clips-from`
(default: Albert's), and a candidate rig takes the shipped glb's clips the same way.

```
python3 tools/meshy/rig_gate.py art/wardens/{breaker,cinder,...}/*.glb --out build/rig_gate --json build/rig_gate/r.json
python3 tools/meshy/rig_gate.py cand.glb --clips-from art/wardens/breaker/breaker.glb
```

| region | measured | WARN / FAIL |
|---|---|---|
| legs | "see-inside" pixels: a z-buffer from 4 sides at every pose; a pixel in the thigh/knee box whose nearest surface is a leg triangle seen from behind (a hole: the black gap). Worst state, in points over the rest pose. Also the crotch bridge (triangles joining a left-leg to a right-leg vertex): worst stretch | 1.5 / 4.0 points; bridge 2 / 3.5 x |
| hands | hand/finger-bound vertices: largest move against the wrist in hand lengths; stretched hand triangles (edge > 2.5 x bind) | 1.0 / 1.5 lengths; 3 / 40 tris |
| arms | arm-torso fusion: triangles joining an arm vertex to a torso vertex below mid-upper-arm at rest, their worst stretch in motion, arm vertices weighted > 0.3 to the torso | 20 / 120 tris; 3 / 8 x; 0.4 / 2 % |
| spikes | needle triangles at rest, far-bone vertices, worst-pose stretched triangles (hunter_mesh_check shares) | 0.02 / 1 % tris; 0.05 / 2 % verts; 0.5 / 8 % tris |

Thresholds are first-pass, set on the 13 live hunters (the leg gap on the rest pose of Cinder/Claire/Ostra reads ~0,
Sable/Ryzz/Tenzo/Albert-downed are the clear holes). Eye-level and knee-level real-GPU frames come from
`--hunter-gpu-shots --rig-frames [--raid=day] --heroes=<arch ids>` (walk, run, attack; eye and knee level; in front
and behind; `jobq submit --needs gpu`); look at them for the regions the numbers flag.

## Table, 13 live hunters (main aba9ecce9e)

See `gens/rig-gate-1121/gate_table_13.md` (same text below). Worst pose is mostly glide (arms wide, legs swung) or death.

| hunter | legs | hands | arms | spikes | see-inside +% (state) | bridge x | hand move (len) / stretched | fused tris / x / wt | spikes / stretched tris |
|---|---|---|---|---|---|---|---|---|---|
| breaker | FAIL | PASS | FAIL | FAIL | 10.084 (downed) | 1.0 | 0.0 / 0 | 171 / 87.62 / 0.046 | 106 / 729 |
| cinder | PASS | FAIL | FAIL | WARN | 0.523 (death) | 1.0 | 2.34 / 16 | 244 / 127.05 / 0.202 | 11 / 725 |
| claire | PASS | PASS | WARN | WARN | -0.563 (attack) | 1.0 | 0.21 / 0 | 14 / 1.0 / 0.013 | 126 / 64 |
| dredge | WARN | PASS | FAIL | FAIL | 2.698 (glide) | 1.42 | 0.11 / 0 | 72 / 5.89 / 0.059 | 97 / 2266 |
| gil | WARN | WARN | FAIL | WARN | 3.879 (downed) | 3.29 | 0.47 / 5 | 147 / 8.82 / 0.036 | 436 / 158 |
| hem | FAIL | WARN | FAIL | WARN | 5.141 (glide) | 81.38 | 0.99 / 14 | 169 / 44.79 / 0.067 | 127 / 392 |
| kael | WARN | FAIL | FAIL | WARN | 1.52 (glide) | 1.0 | 0.39 / 72 | 32 / 128.93 / 0.058 | 46 / 156 |
| ostra | PASS | FAIL | WARN | WARN | 0.0 (walk) | 1.0 | 0.69 / 89 | 13 / 58.76 / 0.006 | 303 / 712 |
| pip | PASS | WARN | FAIL | WARN | -1.799 (glide) | 1.0 | 1.21 / 5 | 110 / 176.76 / 0.239 | 166 / 311 |
| ryzz | FAIL | FAIL | FAIL | WARN | 9.082 (glide) | 1.0 | 1.99 / 197 | 477 / 207.65 / 0.177 | 254 / 1509 |
| sable | FAIL | FAIL | FAIL | WARN | 16.312 (glide) | 76.45 | 1.55 / 1100 | 111 / 75.26 / 0.018 | 130 / 2212 |
| tarek | FAIL | FAIL | FAIL | WARN | 9.741 (glide) | 3.02 | 2.87 / 135 | 156 / 50.52 / 0.083 | 80 / 463 |
| vex | PASS | FAIL | FAIL | WARN | 0.746 (glide) | 1.0 | 3.12 / 97 | 270 / 43.63 / 0.060 | 188 / 452 |

Gil has no clips of its own: posed with Albert's (so its numbers are indicative). Across the 13: legs FAIL for Albert
(downed), Lace, Ryzz, Sable, Tenzo; hands FAIL for 7; arms FAIL for 10 (arm skin welded to the torso: 100+ triangles that
stretch 40 to 200 x when the arm leaves the body). Nothing passes all four.

## Two-rigger pilot on Albert (breaker)

Same mesh, same contract armature, same clips, same accessories: only the BODY skin weights differ
(`tools/meshy/rig_pilot.py`, `tools/blender/rig_pilot.py`). A = Blender heat-map automatic weights on the contract armature
including the finger bones (voxel-remeshed proxy, nearest-vertex transfer: bone heat fails outright on the raw Meshy mesh).
B = Meshy auto-rig, `include_fingers` on, input = the body without the hammer, +Z facing, 2 runs = 10 credits; its Mixamo
bones map onto the contract bones (fingers into `hand.*`), weights by nearest vertex.

| hunter | legs | hands | arms | spikes | see-inside +% (state) | bridge x | hand move (len) / stretched | fused tris / x / wt | spikes / stretched tris |
|---|---|---|---|---|---|---|---|---|---|
| live (shipped) | FAIL | PASS | FAIL | FAIL | 10.084 (downed) | 1.0 | 0.0 / 0 | 171 / 87.62 / 0.046 | 106 / 729 |
| A  Blender heat weights | WARN | WARN | FAIL | FAIL | 3.2 (glide) | 1.0 | 1.17 / 10 | 96 / 17.87 / 0.013 | 106 / 1190 |
| B  Meshy rig + fingers | FAIL | FAIL | PASS | FAIL | 27.766 (walk) | 298.3 | 0.66 / 694 | 0 / 1.0 / 0.000 | 106 / 6308 |

Meshy's skeleton did not land on the model: it put the hips at 62 % of the height and the feet 40 cm up (a normal-human
guess) on Albert's barrel body on stubby legs; joints sit 62 to 100 cm (mean 71 cm) from the contract heads, so its
weights tear the legs (298 x bridge stretch, 6308 stretched triangles). It gave 64 to 68 joints with finger chains
(fingers rig only on a fist input and the mesh fingers are fused: hands-test-kael-1120). Heat weights on the contract
armature are far closer to live; against the shipped weights they are better on the leg gap and arm fusion and worse
on hands and total stretch. Sheet: `gens/rig-gate-1121/albert_sheet.png` (grey = live, red = worse than live).

Other riggers (researched, not run): Tripo rig API (hosted, scriptable, humanoid/quadruped only, needs a Tripo
account: not opened, note only); UniRig (open source, Tripo/VAST, needs a CUDA GPU of 8 GB or more and weights: a pod
job, rpc8 has no GPU); Make-It-Animatable (research code, humanoid, GPU); Mixamo (Adobe login, no API). Blender Rigify
needs a hand-fitted metarig (our contract armature already is that fit).

**Which rigger for the other 12:** keep the contract armature and compute weights from it (Blender heat weights on a
proxy, as in fit_warden step 5) with the rig gate as the exit check; use Meshy's rig only as a joint reference on
human-proportioned models, never its weights. A UniRig pod run is the one worth trying next (GPU, no new account).
