# Hunter regen (owner 11-10): the hero LOD at 60-80k, 4096² atlas, normal map ×0.6

The owner's order, after the [DETAIL_PILOT.md](DETAIL_PILOT.md) GPU numbers: every Hunter rebuilt from its best
Meshy run, the hero LOD at 60-80k triangles, the normal map toned for the toon ramp, 4k textures where the GPU
allows, the lower LODs below it. Spend is fine. The budget and texture rules are in RIG_CONTRACT "Budget and checks".

## The rules every rebuild follows
- **Source:** the Hunter's kept Meshy run (best of at least two, by the face sheet). A new run is only worth it
  when the kept run is from an old design or its face misses the sheet. The `~/meshy/<name>_v8` runs (11-09,
  `_v8/run_all.sh`) were made from `~/meshy/<name>/front.png`, which for Vex is the art from before the v2
  redesign (11-04): check the date of the inputs before using one.
- **Triangles:** the build's own budgets by part, raised so the total lands at 60-80k. Face, hands and hair get
  the biggest raises (that is where the pilot saw the gain); welding only the seams (Vex's `VEX_HEAD_WELD=seam`).
- **Textures:** the atlas at 4096² (the Meshy paint is 8k, so the larger atlas keeps detail the 2048² one
  dropped); the normal map baked at the atlas size and imported at 2048² (`process/size_limit=2048`).
- **Normal strength:** `"painted": {"normal_k": 0.6}` in `warden_look.json`.
- **LODs:** `meshes/generate_lods=true`. Cinder and Kael keep them off until their rebuild checks their hair cards
  at the match camera with them on.
- **Checks:** `--warden-glb-check`, `--warden-model-check`, `--warden-clips-check`, then GPU renders (face,
  three-quarter, full, match zoom) against the shipped model, and `--hunter-gpu-bench` once several are in.

## Status
| Hunter | Art | Build | Kept Meshy run | Status |
|---|---|---|---|---|
| gunslinger | vex | `vex_source/headscan/finish/clips.py` (`VEX_*` budgets, `VEX_ATLAS`) | `vex_v2/runA` + head `hrunA` | done |
| ashwick | cinder | `cinder_source/finish/clips.py` (`CINDER_*` budgets) | `cinder_v2` | to do: retune `cinder_finish.py`'s face paint at the new density first (pilot) |
| bulwark | breaker | `breaker_*` | `breaker_v2` | to do |
| others | claire, dredge, hem, kael, ostra, pip, ryzz, sable, tarek | `<name>_*.py` or `tools/meshy/recipe.py` | per IMPORT.md | to do: give the build budgets from the environment, as Vex's |

Three 25k revamp branches (`ext/hunter-revamp-af`, `-go`, `-pz`) rebuilt most Hunters at about 25k on 11-09 and are
not merged yet. Each rebuild here starts from main after they land, so it keeps their fixes.

## Vex at 70k (11-10)
`VEX_LOW_TRIS=44000 VEX_HEAD_TRIS=24000 VEX_FACE_TRIS=9000 VEX_ATLAS=4096 VEX_HEAD_WELD=seam`, steps as in the pilot
(`~/meshy/vex_v2/hr/build.sh`).
[regen/vex_closeup.jpg](regen/vex_closeup.jpg): shipped | pilot 40k | 70k (GPU shots, 11-10). The 70k reads cleaner in
hair locks, face and bandolier; its skin and sky read paler than the shipped shot, which looks like the render
worker's light rather than the model: check it at the match camera before the next Hunter.
