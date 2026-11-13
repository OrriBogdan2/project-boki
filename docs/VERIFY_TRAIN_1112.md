# Ship-train smoke, 1112 (ext/verify-train-smoke)

Base: origin/main 53e2fe7f3 + ext/mc-integ-1112c2 d32681bdc (a fast-forward; the newer tip supersedes
47f1b58275 and contains it). Run on rpc4, headless, one temp XDG_DATA_HOME per run.

## Gate pieces the batch posts did not run
| Item | Result |
|---|---|
| `godot --headless --export-pack "Linux"` | rc 0, 0 errors, 484 MB pck |
| `--simtest --seed=N --teams=10 --squad=3` (10 trios), seeds 5, 1, 2 | ran to the ending each time (sim 106 s / 92 s / 124 s, "team wiped": the player's trio died; no extraction), no `SCRIPT ERROR` |
| Drop: `--drop-check`, `--drop-launch-check`, `--drop-feel-check` | green |
| Extract/Gate: `--extract-check`, `--exit-signal-check`, `--cc-exit-buffer-check`, `--ways-out-{map,hud,vfx,sfx}-check`, `--results-ways-check` | green (see parse error below) |
| Heart: `--heart-check` | 0 failures |
| Quest exits: the Uplink seat inside `--check`, `--ways-out-map-ui-check`, `--lair-lock-check` | 0 failures |
| Garden: `--base-demo-check`, `--demo-check` (farm preset), `--garden-soak` | demos 0 failures; soak red, see below |

Parallel runs must not share one XDG dir: `--base-demo-check` and `--demo-check` "real save untouched" fail when
another run writes the save at the same time.

## Errors in the logs (all also on origin/main 53e2fe7f3, none new from the batch)
| First frame | Seen in | Brought by |
|---|---|---|
| `ui_theme.gd:72 _states`: OptionButton cannot be a variation of Button | every run | main (already in DEBT as the bench startup flake's lead-in) |
| `boki_dna.gd:124 _stick` (via `spawn_plan._spawn_rare` -> `spawn_wild` -> `models.kin` -> `unique.dress`): `get_bone_global_rest(-1)`, a rig with no `hips` bone, bone_size 31 | `--simtest` seed 5/1/2; `--demo-check` (bone_size 27) | main; boki_dna.gd and spawn_plan.gd are untouched by the batch |
| `ui_torn.gd:62/64 _draw`: `canvas_item_add_polygon` triangulation failed | `--garden-soak` (its "no errors in the log" row) | main; ui_torn.gd untouched by the batch |
| `home.gd:793` / `:3042`: `Could not resolve external class member "big"` / `"body"` (UI.big, UI.body) | `--results-ways-check` (check passes, 0 failures; home.gd fails to load there) | main |
| `Parameter "material" is null` (`material_get_instance_shader_parameters`) at the end of a 10-trio run | `--simtest` seed 5 | the exit-hang family already in DEBT |
| `--demo-check` "care: six grown Boki, hungry only in care" | one parallel run on main, not on the branch | flake |

Integration slips fixed on this branch: none. Nothing here blocks the train.
