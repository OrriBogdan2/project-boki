# Rig / skin-weight test (owner 11-20)

Question: do better weights or a rig change fix the in-motion deformation the 11-20 region reviews score lowest (Tenzo legs web, Albert skirt shards, Cinder tail), with no Meshy regen, no mesh or texture edit? Models tested: live (origin/main) and the draft candidates (hunter-regen-tarek/breaker/cinder-1120). Tools: tools/art1/rig_test/ (README there). Weights are written into the original GLB's JOINTS/WEIGHTS only (textures, clips untouched); the export round trip alone changes nothing (Albert control: lower worst-edge 276.9 vs 276.9).

Metric = posed/rest edge length below the hips over all clips (p99.9 worst edge, share of edges over 2x), sampled 6 frames per clip.

| hunter model | variant | worst edge | edges >2x | REGION (my score) |
|---|---|---|---|---|
| Tenzo live | -- | 32.6 | 4.8% | legs 3.5 |
| Tenzo live | smooth2 | 78.6 | 1.5% | legs 3.5 |
| Tenzo draft #483 | -- | 4.4* | 0.8% (all clips) | legs 4.5 |
| Tenzo #483 | auto+smooth (A) | 4.6 | 1.3% | legs 5.0: black slit between thighs closes, baggy mass stays |
| Tenzo #483 | smooth2 | 4.4 | 0.6% | legs 4.5 (slit stays, ragged hem) |
| Tenzo #483 | voxel | 9.4 | 4.5% | legs 3.5 (web area x4) |
| Albert draft | -- | 276.9 | 4.3% | outfit 6.0 (black blob / shards in strafes) |
| Albert draft | auto+smooth (A) | 55.9 | 1.0% | outfit 7.0 |
| Albert draft | skirt chain bones (B) | 51.8 | 2.2% | outfit 6.5 |
| Albert draft | voxel (C) | 60.3 | 4.7% | outfit 6.5 |
| Albert draft | smooth2 | 98.7 | 1.8% | outfit 6.0 |
| Cinder live | -- | 25.3 | 5.3% | tail 5.5 |
| Cinder draft | -- | 4.4 | 0.8% | tail 3.0 (tail root 0.107 m off the body) |
| Cinder draft | auto+smooth | 3.2 | 0.15% | tail 3.0 (gap unchanged) |
| Cinder draft | tail root weights to hips | 4.4 | 0.8% | tail 3.0 (gap 0.099 m, 0.133 in crouch) |
| Cinder draft | auto+smooth + tail bind offset (A) | 3.2 | 0.15% | tail 7.0 (gap 0.029 m, live 0.062) |

(* worst-edge column for #483 is the lower-body value.)
Findings: weights fix Albert's skirt stretch (277 to 56). They do not fix Tenzo's web (modelled fabric bridging the thighs; only the slit closes) and cannot close Cinder's tail gap (rest-pose geometry); the tail needs a bind offset of its joint chain (moves the tail tube 9.4 cm forward, 2.3 cm up at rest = a placement change, owner call). Voxel-geodesic weights were worse than bone heat on all three.
