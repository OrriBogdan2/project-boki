# SALVAGE: ext/merge-batch-24-1113 (PR #60), retired 2026-11-16

Why: 578 commits behind main; merging main in conflicts in 10 files (merge_kit, merge_moves, merge_xform,
ashwick_kit, juggernaut_kit, warden_clips, Rules.md, DEBT.md, check_registry, plus main deleted
fusion_states_check/fusion_strips/FUSION_STATES.md that this batch edits). Main reworked the merge-form
code (KinMerge.active) after this batch was built; resolving 10 semantic conflicts blind would risk the
merge forms. Each source branch is still on origin, so nothing is lost; re-gate them one at a time.

Already on main (nothing to do): armour-parity 254af75c8, tree-fade-1111 accb6a691, boss-gate-1111 89db22fb3,
friendly-bodies d36df6784.
Reverted inside the batch itself (do not requeue as is): home-dash-one (branch deleted), char-creator-v2-1111.

Still-live source branches (tip on origin) to requeue singly, each = merge origin/main + gate:
- ext/gate-speed-1111 214ea64d87   (~1100 lines: faster gate)
- ext/polish-panel-close a6c2b8555f   (panel close polish, 8 files)
- ext/combo-payoff-audit 7c41d119c1   (13 files)
- ext/main-checks-registry-b 7031c14f17   (~1800 lines of checks)
- ext/fusion-states-fix 098c4cf258   (main deleted the fusion-states files: probably obsolete)
- ext/teach-hold c51efc80f6   (14 files)
- ext/momentum-1111 144c5ebbe2   (8 files)
- ext/levelup-clear-1111 2b9c7c7069   (13 files)
Batch-only fixes worth re-checking after those land: warden_clips keyed-move fall-through (71004288cd),
move-feel Gil dash 4.5 m/0.55 s (c34e878466), TurnCost reads MoveRules (03566430ff).
