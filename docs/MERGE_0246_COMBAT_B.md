# 0.24.6 wave combat-b (Wave 3, last 85 of docs/MERGE_PLAN_0246.md)

Branch ext/w0246-combat-b from origin/main 53e2fe7f3 (0.24.5), then origin/ext/w0246-combat-b-wip 29b85a325 merged
(only conflict: docs/DEBT.md, both sides kept). The wip merged 71 of the 85 branches (from ext/release-integ-0245
92df78ce4, like ext/w0246-combat-a) but had no report and never posted READY; this finishes it. Net.VERSION not
bumped here (combine bumps it, see docs/MERGE_0246_COMBAT_A.md).

The three parity fixes that were only on the wip (docs/KIT_PARITY.md rows) are in and checked:

- ext/parity-no-riders-grimble-tenzo 7b130d5c7: Grimble's Anchor Drop no longer Grounds (no `gnd_t`, no ANCHORED
  word); Tenzo's punch is flat 10.6 damage / kb 10 (no charge scaling).
- ext/parity-motley-float f48366abc: Motley floats over ground hazards, tags in `ostra.json` `passive.float_tags`.

## Held (13 of the 85; 1 more already in)

- `ext/hunter-regen-meshy`: 8 conflicts, Vex glb/atlas + Albert atlas import, against the 0.24.5 appeal models;
  needs an art pick (same as the revamp branches held in combat-a)
- `ext/sable-appeal4`: 12 conflicts incl. sable.glb/atlas against 0.24.5's appeal3 v95 Sable and ext/hunter-fix-1112
  (READY, edits sable.glb); art lane picks one body, then rebases
- `ext/sfx-hunter-wisp-hum`: 5 conflicts (wisp_hum.wav, hunter_wisp.gd, gen_wisp_sfx.py, check_registry) against
  the wisp rules merged here (ext/combat-wisp-hit-rules); rebase on this line
- `ext/split-warden-glb`: god-file split of warden_glb.gd, 2 conflicts (warden_glb.gd, style_baseline.json); the
  split must be redone on the current file
- `ext/vex-coin-palm-1108`, `ext/vex-greenfire-1108`, `ext/vfx-vex-kit`: one stacked Vex line, 12/16/16 conflicts
  (vex.glb, gunslinger.json, tuning.json, Vex docs) against ext/vex-yawlock-1109-2248 merged here; Vex lane rebases
  the stack once
- `ext/vfx-kael-kit`: 3 conflicts in juggernaut_kit.gd / juggernaut_drop.gd / vfx/juggernaut.json; Kael lane rebase
  (ext/kael-tap-ult-1108 is held for the same code in combat-a)
- `ext/vfx-motley-kit`, `ext/vfx-quality-motley`: 6/7 conflicts in ostra_kit.gd, kit_looks.gd, tether_lantern.json
  against ext/vfx-motley-nightwell + the float passive merged here; one VFX rebase of both
- `ext/meeko-rmb-verify-rebased-rebased`, `ext/meeko-root-rebased`, `ext/vfx-meeko-weight-rebased-rebased`: each
  carries a merge candidate (2,250-2,737 commits not on the line, 65-157 conflicts); only their own commits should
  land, cherry-picked onto the line (Meeko lane)
- `ext/utility-parity`: already in (no-op)

## Fixes on top of the wip (this wave's own reds)

- Grimble Anchor hop: Hunters now pass through Hunters (ext/parity-body-collision, decision 0027), so no foe stops
  the hop and the ground slide after it carried him 2.6 m instead of ~1 bh. The hop now ends planted at its 1.8 m,
  and stops short at a lip, so the Anchor cast at an edge leaves him on the island (the abyss row from
  ext/parity-ability-abyss was written before the hop came back; source silent, [?] in docs/heroes/dredge.md).
- --dredge-combo-check `reset` clears the Anchor's barge turn lock: with pass-through, the earlier step left him facing
  back and the lock turned the next "plain" barge round (two barge rows red).
- MageKit.combo_read still read the pre-Stacks sparks dict (`s["n"]` on a Hunter, a script error in --ttk-check
  mage rows); it reads Stacks "static" now, like combo_marks.

## Checks (rpc7, headless, LP_NUM_THREADS=2, one at a time; combat-a = origin/ext/w0246-combat-a c557d3f1c)

| Check | combat-b | combat-a | NEW-RED |
|---|---|---|---|
| --dredge-combo-check | 118, 1 fail | 120, 1 fail | none (same row: hand braced running back, red on main too). Was 5 before the fixes above |
| --dolm-combo-check | 174, 0 | 178, 0 | none (the 4-row gap is combat-a's own merges: rank parity, Molten Guard rows) |
| --ostra-combo-check | 223, 1 fail | 220, 1 fail | none (same row: rank-3 seed burn 14.9 over 1.2 s, combat-a's NEW-RED too) |
| --kit-parity-check | 0 fail | 0 fail | none |
| --ttk-check | 38 rows, 21 fail | 38 rows, 22 fail | none (no row red here that is ok there; mage combo rank 0 ok here) |
| tools/health.py --strict | OK | | |
| tools/gen_wiki.py --check | 50 unchanged (after regenerating Maps/Rules and 13 class pages the merges left stale) | | |

No GPU shots or perf: no art, shader or scene change in the fixes.
