# Garden zone budget: measured (2026-11-10)

GARDEN.md 10.6 sets the budget; `content/rules/garden_zones.json` holds it (`budget`, `budget_hub`) and the
held ceilings (`ratchet`). Candidate stack: origin/main + `ext/garden-cinderstep-zone` (carries hub-zones and
Glasswater) + `ext/garden-hub-horizon`. Hushwood and Kitewind Ridge are not in it: their branches
(`ext/garden-lantern-zone-hub`, `ext/garden-ridge`) conflict heavily with the shared `ZoneLayout`/`ZoneDress`
build, so they have no numbers yet; bench them with `--bench-zone=<id>` once ported.

## Run
`jobq submit --needs gpu --only <worker> --tree <tree> --out bench -- --perf-bench --bench-secs=5 --bench-farm=10 --bench-zone=all --quality=<medium|low>`
Each built zone runs with 9 Boki out (6 residents, the partner, 2 visitors) and the hub. Draws and objects are read with
the screen UI hidden. `base_life` is the cost of one 10 Hz step with all 9 out. The run exits 1 on any FAIL.

## Numbers (draws / objects / nodes / emitting emitters / frame ms / base_life ms)
| part | M5 Medium (jobq 20261110-135258-04622) | rp1-0 Low, RTX 4090 (20261110-135308-11669) | target |
|---|---|---|---|
| hub | 689 / 689 / 1005 / 2 / 3.4 / - | 358 / - / - / - / 4.1 / - | 200 / 500 / 2000 / 6 / 0.5 ms script |
| Bramblebank | 740 / 740 / 1558 / 2 / 15.1 / 0.02 | 348 / - / - / - / 13.2 / - | 350 / 800 / 3000 / 12 / 16.7 (33 on rp1-0) / 1.5 |
| Glasswater | 375 / 400 / 1374 / 5 / 15.1 / 0.03 | 236 / - / - / - / 8.3 / - | same |
| Cinderstep | 513 / 524 / 1497 / 11 / 18.3 / 0.02 | 264 / - / - / - / 9.4 / - | same |

Over target: every M5 draw figure (Glasswater 375, Cinderstep 513 and 18.3 ms, Bramblebank 740, hub 689) and the hub on rp1-0 (358).
Within target: nodes, emitters, base_life everywhere, objects in every zone, all zone frames on rp1-0.

## Where the draws are
- Boki: each rig is about 14 meshes, so 9 Boki is roughly 150 draws.
- Fixtures: Stall about 44 meshes, Burrow 40, house about 86, hub Deco about 52. These are static and unmerged.
- The hub horizon is 5 draws (hub 358 vs hub without horizon 353 on rp1-0).
- The M5 counts more draws than the 4090 for the same scene (gl_compatibility, shadow passes at Medium).
- Cinderstep costs about 160 draws and 6 emitters more than Glasswater on the M5 for the same Boki; not yet explained.

## Held, not fixed
Draws did not come down in this change: the way to the target is merging the static fixtures (the `World._merge_static`
pattern, which frees its roots and needs `material_override` on every mesh, so each fixture has to be checked for
outside references first) and shrinking the Boki rig's mesh count at Low and Medium. `ratchet` fails the bench
if any held number gets worse.
