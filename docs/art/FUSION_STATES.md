# Fusion states: what every merge form shows in every state

Owner priority 4: every state animated. `--fusion-states-check` plays each hero (all 12) merged into each built form
(`content/merge_forms`: Heavy Star `titan`, Stormwing `stormwing`, Prism Shell `tidal_shell`) and once unmerged, and
reads what the model shows from the hero's own clip picker (`WardenClips`) or, for a move with no clip, the keyed pose
(`HunterAnim.km_sample`). `--fusion-strips --shots-dir=<dir> [--fusion-hero=<id>]` renders one 5 fps strip per form.

## The sweep before this pass (origin/main d255acbee)

| State | What showed | Why |
|---|---|---|
| idle, walk, run | the hero's loco clips | (fine) |
| xform | the hero's `fusion`/`fuse` clip | (fine) |
| LMB | **home idle** for Kael, Cinder, Grimble and Sparkle | their kits still blocked or hid LMB for the whole merge, a leftover of 0003's kit swap (0004: you keep your own LMB) |
| RMB, E, dash | the hero's own clip | (fine once the stale pose below is gone) |
| any hero move | **home idle** for the whole merge in the clip picker's eyes | `MergeKit.anim_state` kept the finished `mf_xform` as the shown move for the whole merge, over the hero's own |
| hit | **no flinch** (loco), merged or not | `WardenClips._pick` returned "nothing" for any move that had played out, so the hit clip after it was never reached |
| ultimate | one generic pose (`mf_ult`: arms up, held) for every form, no key on the strike | |
| release | **nothing**: the body snapped back to loco | no move |

## Now

| State | Every form |
|---|---|
| idle, walk, run, LMB, RMB, E, dash, hit | exactly what the hero shows unmerged (its own clips; the check asserts equality) |
| xform | the hero's `fusion`/`fuse` clip (`mf_xform` keys for a rig with no clip) |
| ultimate | the form's own keyed move, a key on every beat of its `r.beats` (asserted): `mf_ult_stormwing` (dip, climb with arms gathered to 0.62, cocked, both arms thrown down on the 0.7 strike, hover), `mf_ult_tidal_shell` (curled behind crossed arms through the 0.55 crack, thrown open on the burst), `mf_ult_titan` (load, launch, tuck, both fists down on the 0.65 landing, up again, the big slam at 1.05) |
| release | `mf_release` (0.5 s: jolted back with arms flung open as the Boki springs out, a step back in), here and in other games (the owner sends it as the merge pose, `KinNet.hunter_extra`, only while the hero starts no move: the snapshot carrying the kit's next move id never carries the release); a move the hero starts after the merge ended wins |

The form ultimates and the release have no hand-keyed clip in any hero's `.glb`: they play on the retargeted rig
(the clip picker's "procedural" path), as `mf_ult` always did. Clips need Blender (docs/DEBT.md).

Two heroes show something other than `hit_*` in the hit window, merged and unmerged alike: Kibo's landing clip
(`dash_land`, the dash before it) and Ravyl's `spirit` move. That is their own order of states, not the merge.
