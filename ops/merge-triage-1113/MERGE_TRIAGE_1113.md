# Merge-gap triage 11-13 (job 20261113-160524-a3, w2, deep)

Baseline (reconstructed on w2, which has no merge-gap/branch-archive): READY lines in EXT_TO_MAIN.md + its 11-06 archive,
branch live on origin, head not an ancestor of origin/main f851f083bf. **1614 unmerged READY branches**. The task's 1710 came from
hetzner `merge-gap`. The prior job found it overstated by about 195 (lstrip=4). Main also merged batch 1113 since then.

## Counts per class

| class | rule | found | archived |
|---|---|---|---|
| (a) on main | every touched file equals main, or its hunks reverse-apply on main (per file; `git cherry` was too slow) | 2 | 2 |
| (b) superseded | newer same-family branch (-rebased/-vN/-2/-date) whose head contains it (ancestor or no-op merge-tree), or a newer READY saying "supersedes ext/X" with X's files a subset (27 "supersedes nothing / the parts of" lines dropped) | 166 | 164 |
| (c) art/data already live | 16 art/docs-only branches found, all committed 11-11..11-13 and differing from main; w2 has no dex/site, so "already used live" can't be checked | 16 | 0 |
| (d) unique work | the rest (minus ext/agent-briefs) | 1445 | 0 |

The 2 (b) not archived: `ext/sparkle-dash-feel` (open PR #21) and `ext/vfx-cel-ring-bursts` (named in a merge-batch-1113 commit, gate job left alone).
Archive = tag `archive/<branch>` at the tip, confirm the tag on origin, then delete the branch with `--force-with-lease=<sha>`
(the BRANCH_AUDIT pattern). 3 names already had an archive tag at an older sha, so they were tagged `archive/<branch>@<sha9>`. Every
line has its restore command in `merge-triage-1113-archive.log`. Restore one: `git push origin 'archive/<branch>^{commit}:refs/heads/<branch>'`.

**New merge-gap: 1614 - 166 = 1448** (my count, incl. agent-briefs and the 2 held). Hetzner's `merge-gap` will differ: 230 of the (d)
branches already carry an archive tag at their exact head but are still live (a pass tagged without deleting, or a restore). If
merge-exclude.txt lists them, hetzner shows about 1218. The exclude lines for today's 166 are in `merge-exclude-add-1113.txt`.
w2 can't reach ~/bin/merge-exclude.txt. Six new ext branches appeared during the run (one is `merge-rush-1113-batchb`).

## Why (d) is not 1445 merges: 981 merge units

464 of the 1445 are ancestors of another (d) branch, so they land when their tip merges. **981 tips** = 946 lane tips + 35 integ/stack tips.
Lanes (tips): kits 151, anim 129, farm 104, audio 103, ui 98, vfx 91, feel 87, tutorial 85, tech 43, integ 35, misc 35, docs 20.
969 of the 981 conflict with main (`git merge-tree`). Only 22 conflict on docs/registry/generated files alone, so a union merge
driver or regeneration would not fix the bulk. Hot conflict files (all 1614): tools/check_registry.gd 634, docs/wiki/Rules.md 515,
docs/DEBT.md 489, scripts/match/match.gd 355, scripts/home/home.gd 307, scripts/match/hunter.gd 291, docs/AUDIO.md 285,
scripts/core/settings.gd 247, scripts/core/net.gd 244, tools/style_baseline.json 243.

Integ tips are the big levers, and they overlap. stuck-integ-11014837 carries 141, stuck-integ-42241ff1 133, stuck-integ-86b7d6eb 115,
PR #45 mc-integ-1112d 69, stuck-integ-606e9a98 54, a6af81f7 45, PR #43 mc-demo-1112 28. Merging #45 and #43 drops up to 97 carried
branches from the gap with no other work. Picking ONE stuck-integ line and archiving the other stuck-integ tips is the largest single cut
(about 140-250 branches). That is an owner call (each READY lists failing checks), so I archived nothing on that basis.

## Open CONFLICTING PRs

| PR | branch | in main/#45/#43? | action | conflict files vs main |
|---|---|---|---|---|
| #6 | heroart-pass2 | superseded on main: archer is dressed by `WardenArcher.dress`; the procedural bow/half-cape it edits is gone | **closed** with a comment (reopenable) | 2: hero_gear.gd, models.gd |
| #33 | training-area-1108 | no (0 of 30 files) | (d) tutorial | 16: content/maps/arena.json docs/DEBT.md docs/wiki/Arena-and-Training.md docs/wiki/Classes.md docs/wiki/Maps.md docs/wiki/The-Farm.md |
| #32 | albert-size-boop | 70/104 files on main; READY successor albert-size-boop-rebased (not merged, not literally containing it) | (d) kits; close when -rebased lands | 9: art/wardens/breaker/breaker.glb content/archetypes/bulwark.json content/weapons/tower_shield.json docs/DEBT.md docs/heroes/bulwark.md scripts/arch/kits/bulwark_kit.gd |
| #25 | reticle-style-1108 | no | (d) feel | 8: content/archetypes/dolm.json content/archetypes/gunslinger.json content/archetypes/mage.json content/rules/tuning.json docs/AIMKIT.md scripts/match/aim/aim_reticle.gd |
| #24 | hunter-screen-name | no; READY successor hunter-screen-name-v2 (unmerged) | (d) ui; switch to -v2 | 1: scripts/home/hunter_pick_row.gd |
| #23 | farm-tut-batch-1108-deep | no (farm-tut-spotlight part is on main via 8c24581c05) | (d) tutorial | 8: content/rules/tuning.json docs/decisions/0011-farm-builder-tutorial.md scripts/core/care.gd scripts/home/farm_guide.gd scripts/home/hob_model.gd scripts/ui/build_catalog.gd |
| #21 | sparkle-dash-feel | no; READY says stuck-integ-d4379965 supersedes it | (d)/(b) held: open PR | 11: content/archetypes/mage.json docs/heroes/mage.md docs/wiki/Class-Storm-Chaser.md scripts/arch/kits/mage_kit.gd scripts/arch/kits/mage_sky.gd scripts/arch/kits/mage_ult.gd |
| #20 | farm-tut-batch-1108 | 10/17 files reverse-apply on #23's head; #23 is the deep redo | (d) tutorial; merge #23 instead | 9: docs/decisions/0011-farm-builder-tutorial.md scripts/core/care.gd scripts/home/farm_guide.gd scripts/home/farm_spotlight.gd scripts/home/hob_model.gd scripts/ui/build_catalog.gd |
| #19 | scrapking-lmb | no; READY successor scrapking-lmb-1111 (owner 11-11 top priority, unmerged) | (d) kits; switch to -1111 | 10: content/archetypes/dredge.json content/weapons/shotgun.json docs/KIT_PARITY.md docs/heroes/dredge.md docs/wiki/Class-Scrap-King.md docs/wiki/Weapons.md |

The rule was "close only if the work is in main/#45/#43". So #32/#24/#21/#20/#19 stay open. Each has a named successor: close it when that successor merges.

## Top risks (HARD / BLOCKS)

1. 969/981 tips conflict with main and main moves about 50 merges a day: every batch needs a rebase-and-gate run first. About 26 runs at 40 per run. HARD 8, BLOCKS 9.
2. The parallel stuck-integ lines (11014837, 42241ff1, 86b7d6eb, 606e9a98, ...) carry the same READY heads with different conflict calls. Merging two of them double-resolves. Owner pick needed. HARD 7, BLOCKS 8.
3. God-file conflicts (match.gd 355, home.gd 307, hunter.gd 291) concentrate in kits/feel/farm batches; merge those lanes one batch at a time. HARD 6, BLOCKS 6.
4. check_registry.gd / Rules.md / DEBT.md conflict in most branches. Regenerate Rules.md and union DEBT.md in each batch: mechanical, but it fills every gate run. HARD 3, BLOCKS 5.
5. The impact scores below are a heuristic: owner +2, fix/bug +1, log10 of changed .gd/.json lines, +1 for carrying 5 or more. The 1-9 ranking is only for ordering. HARD 2, BLOCKS 2.
6. 230 pre-tagged live (d) branches: unknown whether they are excluded on hetzner. Check `merge-gap --list` against `ops/merge-triage-1113/pretagged_live.txt`. HARD 1, BLOCKS 3.

## Top 15 non-integ tips by impact (I=impact, H=hard, cf=conflict files)

- `ext/combat-wisp-hit-rules` I9 H3 9cf kits: supersedes the 62ec8ba05 line, same feature: a downed Hunter Wisp is no target. origin/mai
- `ext/wisp-summon-key-c` I9 H8 38cf kits: base ext/summon-killed-wisp-rebased fe8e089df1, the newest integrated summon head. WISP OW
- `ext/meeko-rmb-verify-rebased` I9 H8 32cf kits: supersedes ext/meeko-rmb-verify eba7147eb; deep job 20261109-173121-a3, escalated from 202
- `ext/tut-revive-hint` I9 H9 49cf tutorial: first downed teammate within 15 m in a real match shows FirstTimeHint 'Hold {interact} to 
- `ext/tutorial-beats-5-6-rebased-rebased` I9 H10 81cf tutorial: deep job 20261111-000029-a1 on w2, escalated from 20261110-233042-a1; SUPERSEDES READY ext
- `ext/parity-stranded-0246` I9 H10 114cf kits: SUPERSEDES f1a4a1437, fast-forward push: merged the newer READY ext/w0246-combat-b 51cf2bd
- `ext/meeko-rmb-verify-rebased-rebased` I9 H10 83cf kits: SUPERSEDES ext/meeko-rmb-verify-rebased 7c1762cf5; deep job 20261110-124808-a4 on w2, esca
- `ext/kael-rmb-unlock-rebased` I9 H10 176cf kits: SUPERSEDES READY ext/kael-rmb-unlock 44f5a64dc; build job 20261111-045711-a6 on rpc1. orig
- `ext/kael-lunge-length-rebased-rebased` I9 H10 51cf kits: SUPERSEDES 0f1cd8c71; build job 20261112-181513-a3 on rpc7. Fast-forward of 0f1cd8c71: mer
- `ext/hud-g-armor-1111` I8 H1 1cf ui: owner-direct, top priority: G only on the Boki slot (duplicate beside utility belt removed
- `ext/feel-cast-into-cast-rest` I8 H1 2cf feel: CONTAINS ext/feel-cast-into-cast-slice 6db5bfd80 as cherry-pick 97afb33ef, never READY-pos
- `ext/vfx-kael-hold-arc` I8 H2 9cf vfx: re-merge of origin/main 18402df5b3 into the branch, supersedes the 8cdbded35 entry; same c
- `ext/vfx-albert-slab` I8 H2 6cf vfx: PARITY docs/heroes/bulwark.md gap 8, base origin/main 88b06b9e7. Width re-measured on orig
- `ext/vex-rmb-1111` I8 H2 6cf kits: SUPERSEDES a796f3a38: origin/main merged in, fast-forward push. Same Vex RMB fix: a miss i
- `ext/momentum-1111` I8 H2 5cf misc: OWNER-DIRECT, top priority next train; base 272368589 (0.24.5 gate), ext/gill-rework-1111 

## Proposed merge batches (<=40 merges each, dependency order)

Order: B00 clean, then lanes tech, kits, feel, anim, vfx, audio, ui, tutorial, farm, misc, docs, integ (last: owner call).
Within a lane: READY "STACKED on/BASED ON/builds on" bases first, then impact desc, hard asc. Each line: I/H, conflict-file count,
stacked branches it carries, "pre-tagged" = an archive tag already sits at its head.

### B00 clean merges (no conflict with main): 12 merges (+2 stacked branches carried), avg impact 4.4/10, avg hard 1.0/10

- `ext/combat-lace-spirit-ledges-rebased` I5 H1 0cf
- `ext/tenzo-arm-slate` I3 H1 0cf
- `ext/anim-timing-dolm` I4 H1 0cf
- `ext/art-keepers` I3 H1 0cf
- `ext/vfx-albert-smash` I3 H1 0cf
- `ext/creator-sex-distinct` I5 H1 0cf
- `ext/tut-first-echo` I5 H1 0cf
- `ext/tut-first-ult` I5 H1 0cf
- `ext/tut-first-zone` I5 H1 0cf
- `ext/tut-first-egg-line` I4 H1 0cf
- `ext/farm-garden-soak` I6 H1 0cf
- `ext/pitch-reel-exit-1112` I5 H1 0cf +2 carried

### B01 tech: 40 merges (+155 stacked branches carried), avg impact 5.5/10, avg hard 3.3/10; god-file conflicts: match.gd x11, hunter.gd x8, home.gd x6

- `ext/perf-owner-hw-rebased` I8 H7 16cf +7 carried
- `ext/bot-hazard-route` I8 H10 57cf +26 carried
- `ext/perf-train-0245-rebased` I7 H7 16cf +7 carried
- `ext/split-models-rebased` I7 H9 35cf +13 carried
- `ext/verify-tut-starters-0246` I7 H9 32cf +7 carried
- `ext/perf-occluder-pool-rows` I7 H10 70cf +21 carried
- `ext/verify-ttk-0246` I7 H10 101cf +54 carried
- `ext/fix-0245-reds` I6 H1 4cf +1 carried
- `ext/save-chain-0245` I6 H2 6cf +2 carried
- `ext/bot-stomp-1111` I6 H3 8cf
- `ext/verify-solos-pacing` I6 H3 8cf
- `ext/no-dash-bursts-audit-rebased-rebased` I6 H8 34cf +13 carried
- `ext/split-ui` I6 H9 33cf
- `ext/bot-kit-lands` I5 H1 4cf
- `ext/net-rejoin` I5 H1 3cf
- `ext/perf-anim-distance-rate` I5 H1 4cf
- `ext/perf-mob-cap` I5 H1 3cf
- `ext/remote-smooth-reds` I5 H1 2cf
- `ext/split-rimewright-spear` I5 H1 3cf
- `ext/status-net-per-caster` I5 H1 3cf +1 carried
- `ext/verify-camera-ab` I5 H1 2cf +1 carried
- `ext/verify-felt-dash-0245` I5 H1 1cf
- `ext/verify-hitbox-rest` I5 H1 2cf
- `ext/verify-kael-guard-ult` I5 H1 2cf
- `ext/bots-human-1111-feel` I5 H2 9cf
- `ext/checks-out-of-main-c` I5 H2 3cf +1 carried
- `ext/perf-1111` I5 H2 5cf
- `ext/perf-skip-proc-body` I5 H2 4cf
- `ext/perf-tracy-1112` I5 H2 4cf
- `ext/perf-visibility-ranges-rebased` I5 H2 2cf
- `ext/remote-move-clear` I5 H2 4cf
- `ext/split-home-system` I5 H2 1cf
- `ext/split-hud` I5 H2 2cf
- `ext/split-match-system` I5 H2 2cf
- `ext/bot-kael-1111` I5 H3 10cf +1 carried
- `ext/split-hunter` I5 H3 5cf
- `ext/verify-stomp-break-sweep` I5 H3 9cf
- `ext/bot-kit-lead-casts` I4 H1 2cf
- `ext/no-squad-hint-1111` I4 H1 3cf
- `ext/perf-assets-1111` I4 H1 1cf

### B02 kits+tech: 40 merges (+719 stacked branches carried), avg impact 7.3/10, avg hard 6.8/10; god-file conflicts: hunter.gd x21, home.gd x19, match.gd x18

- `ext/perf-heart-final` I4 H1 2cf
- `ext/remote-anim-timeout` I4 H1 1cf
- `ext/remote-smooth-reds-b` I4 H1 3cf
- `ext/combat-wisp-hit-rules` I9 H3 9cf +3 carried
- `ext/meeko-rmb-verify-rebased` I9 H8 32cf +2 carried pre-tagged
- `ext/wisp-summon-key-c` I9 H8 38cf +15 carried
- `ext/kael-lunge-length-rebased-rebased` I9 H10 51cf +14 carried
- `ext/kael-rmb-unlock-rebased` I9 H10 176cf +40 carried
- `ext/meeko-rmb-verify-rebased-rebased` I9 H10 83cf +13 carried
- `ext/parity-stranded-0246` I9 H10 114cf +60 carried
- `ext/kael-owner-1111` I8 H2 9cf +1 carried
- `ext/vex-rmb-1111` I8 H2 6cf +3 carried
- `ext/kael-tap-ult-port` I8 H8 42cf +26 carried
- `ext/mantle-port-b` I8 H8 57cf +43 carried
- `ext/wisp-passive-stack-rebased` I8 H8 37cf +14 carried
- `ext/combat-bots-downed` I8 H10 56cf +21 carried
- `ext/combat-hazard-ward-stack` I8 H10 126cf +26 carried
- `ext/combat-motley-swept` I8 H10 68cf +26 carried
- `ext/grimble-v95-rebased` I8 H10 188cf +40 carried
- `ext/meeko-root-rebased` I8 H10 198cf +47 carried
- `ext/wisp-summon-leash-rebased` I8 H10 48cf +13 carried
- `ext/wisp-summon-net-rebased` I8 H10 48cf +13 carried
- `ext/motley-1111` I7 H1 3cf
- `ext/blight-nests` I7 H2 5cf
- `ext/recast-art-dedupe` I7 H2 6cf
- `ext/combat-steal-boss-bonus` I7 H4 13cf +1 carried
- `ext/physics-unify-1111` I7 H4 5cf
- `ext/meeko-loops-rebake` I7 H8 57cf +43 carried
- `ext/summon-kill-credit-rebased` I7 H8 38cf +16 carried
- `ext/combat-mage-rod-dmg` I7 H10 68cf +26 carried
- `ext/combat-mob-camp-root` I7 H10 68cf +26 carried
- `ext/combat-summon-share` I7 H10 91cf +21 carried
- `ext/herovfx-mode-clash` I7 H10 105cf +28 carried
- `ext/parity-rider-sweep-0246` I7 H10 115cf +60 carried after ext/parity-stranded-0246
- `ext/parity-sable-cartwheel-curve` I7 H10 54cf +27 carried
- `ext/vex-dash-charge-port` I7 H10 61cf +27 carried
- `ext/wisp-gpu-ab-rebased` I7 H10 114cf +22 carried
- `ext/albert-hold-cinder-orb` I6 H1 2cf
- `ext/combat-armour-xp` I6 H1 3cf +2 carried
- `ext/combat-blockers` I6 H1 1cf

### B03 kits: 40 merges (+55 stacked branches carried), avg impact 5.5/10, avg hard 2.2/10; god-file conflicts: match.gd x4, hunter.gd x4, home.gd x3

- `ext/parity-neve-crash-recovery` I6 H1 3cf
- `ext/wisp-look-1112` I6 H1 3cf
- `ext/combat-ttk-five` I6 H2 8cf +1 carried
- `ext/combat-zone-stage-dmg` I6 H2 5cf +2 carried
- `ext/dredge-auto-rebased` I6 H2 5cf +1 carried
- `ext/grimble-stretch-v2-rebased` I6 H2 6cf
- `ext/lace-playtest-1108` I6 H2 5cf +1 carried
- `ext/predictable-camps-1111` I6 H2 7cf
- `ext/rocket-drop-1111` I6 H2 3cf
- `ext/combat-utility-verify` I6 H3 7cf
- `ext/squad-intro-skyship` I6 H3 5cf
- `ext/summon-pve-rules-rebased` I6 H3 6cf +3 carried
- `ext/combat-raid-balance` I6 H4 6cf +1 carried
- `ext/combat-sable-lmb-hits` I6 H4 18cf +1 carried
- `ext/grimble-fist-vfx-rebased` I6 H4 12cf +1 carried
- `ext/combat-ttk-parity-1112` I6 H7 32cf +3 carried
- `ext/parity-verify-0245-slice` I6 H7 22cf +1 carried
- `ext/meeko-rmb-motion-rebased-rebased` I6 H8 34cf pre-tagged
- `ext/ult-ranks-rebased-rebased` I6 H9 44cf +40 carried
- `ext/cinder-flue-clips` I5 H1 2cf
- `ext/combat-albert-aegis-input` I5 H1 3cf
- `ext/combat-boss-parity` I5 H1 3cf
- `ext/combat-bots-ring` I5 H1 2cf
- `ext/combat-glove-band` I5 H1 2cf
- `ext/combat-hurtbox-parity` I5 H1 3cf
- `ext/combat-lair-prize` I5 H1 2cf
- `ext/combat-level-growth` I5 H1 2cf
- `ext/combat-meeko-carry-drop` I5 H1 2cf
- `ext/combat-perk-orbs-rebased` I5 H1 1cf
- `ext/combat-ranks-a` I5 H1 1cf
- `ext/combat-ranks-c` I5 H1 1cf after ext/combat-ranks-a
- `ext/combat-steal-window-tell` I5 H1 4cf
- `ext/combat-swept-hits` I5 H1 1cf
- `ext/combat-vex-cone-net` I5 H1 3cf
- `ext/grimble-nose-1109` I5 H1 3cf
- `ext/kael-black-red` I5 H1 3cf
- `ext/meeko-call-noself` I5 H1 2cf
- `ext/sable-dash-lmb-1111` I5 H1 3cf
- `ext/scrapking-arm-1111` I5 H1 4cf
- `ext/scrapking-lmb-1111` I5 H1 2cf pre-tagged

### B04 kits: 40 merges (+89 stacked branches carried), avg impact 5.0/10, avg hard 2.5/10; god-file conflicts: hunter.gd x9, match.gd x6, hud.gd x2

- `ext/scrapking-lmb-1111-clips` I5 H1 2cf
- `ext/tenzo-ridge-bursts` I5 H1 4cf +1 carried
- `ext/ttk-kael` I5 H1 4cf
- `ext/uplink-tour-stall` I5 H1 1cf
- `ext/vex-greenfire-1108` I5 H1 1cf
- `ext/wisp-look-net` I5 H1 3cf
- `ext/base-tp-hold-wheel` I5 H2 4cf
- `ext/boss-bot-focus-1111` I5 H2 5cf
- `ext/combat-blight-endgame` I5 H2 7cf
- `ext/combat-fusion-band` I5 H2 5cf
- `ext/combat-grimble-ult-clarity` I5 H2 6cf
- `ext/combat-levelup-refill-rebased` I5 H2 1cf +1 carried
- `ext/combat-melee-ring-stack` I5 H2 6cf
- `ext/combat-motley-dead-kit` I5 H2 4cf +1 carried
- `ext/duel-ring-port` I5 H2 1cf
- `ext/kael-drop-down` I5 H2 9cf +1 carried after ext/kael-owner-1111
- `ext/kael-rmb-line-1111` I5 H2 5cf
- `ext/kit-card-1111` I5 H2 5cf
- `ext/lace-cancels-1111` I5 H2 7cf +1 carried
- `ext/neve-1111` I5 H2 5cf pre-tagged
- `ext/neve-cancels-1111` I5 H2 5cf
- `ext/parity-albert-blow-stun` I5 H2 6cf
- `ext/parity-kael-clips` I5 H2 8cf
- `ext/parity-tenzo-ridge` I5 H2 5cf
- `ext/parity-ttk-kael` I5 H2 6cf
- `ext/sable-wings` I5 H2 1cf
- `ext/clarity-1112` I5 H3 9cf
- `ext/combat-in-combat-rule` I5 H3 5cf
- `ext/combat-mob-boss-fsm` I5 H3 5cf
- `ext/kael-cancels-1111` I5 H3 11cf +2 carried
- `ext/kael-chainlunge-cleanup` I5 H3 11cf +1 carried
- `ext/parity-bulwark-crush-rebased` I5 H3 8cf +1 carried
- `ext/sable-appeal4` I5 H3 6cf
- `ext/stomp-1111-rules` I5 H3 8cf pre-tagged
- `ext/stomp-lock-1111` I5 H3 9cf
- `ext/landing-recovery` I5 H4 7cf +2 carried
- `ext/combat-neve-lmb-torn` I5 H8 41cf +26 carried
- `ext/combat-ostra-seed-burn` I5 H8 41cf +26 carried
- `ext/lace-climb-tall` I5 H8 41cf +26 carried
- `ext/combat-lace-wallclimb` I4 H1 2cf

### B05 kits: 32 merges (+26 stacked branches carried), avg impact 3.8/10, avg hard 1.7/10; god-file conflicts: hunter.gd x1

- `ext/combat-ranks-b` I4 H1 4cf
- `ext/grimble-barge-chain` I4 H1 2cf
- `ext/grimble-parity-verify` I4 H1 3cf
- `ext/jobq-logcap` I4 H1 1cf
- `ext/kael-albert-size-1111` I4 H1 2cf
- `ext/kael-riposte-crescent` I4 H1 3cf
- `ext/meeko-call-sparkles` I4 H1 3cf
- `ext/motley-hover-hum` I4 H1 2cf
- `ext/parity-albert-crush-stun` I4 H1 3cf
- `ext/parity-albert-mending` I4 H1 3cf
- `ext/parity-kael-cc-riders` I4 H1 2cf
- `ext/parity-kael-chain-states` I4 H1 4cf
- `ext/sable-vault-exit` I4 H1 4cf
- `ext/vex-zone-tick` I4 H1 4cf
- `ext/mantle-look-one-home` I4 H2 5cf
- `ext/meeko-crook-range` I4 H2 5cf
- `ext/meeko-crouch-stride` I4 H2 5cf
- `ext/parity-neve-rimelock-ramp` I4 H2 5cf
- `ext/parity-ttk-motley` I4 H2 6cf
- `ext/sable-vault-riders` I4 H2 6cf
- `ext/tarek-appeal` I4 H2 6cf
- `ext/vex-body7-1111` I4 H2 5cf
- `ext/parity-neve-dart-burst` I4 H3 10cf
- `ext/parity-ttk-cinder-neve` I4 H3 10cf
- `ext/ttk-five-cast-share` I4 H3 10cf
- `ext/parity-sable-e-range` I4 H8 43cf +26 carried
- `ext/lace-ranges-source` I3 H1 3cf
- `ext/motley-tune-rebased` I3 H1 1cf
- `ext/neve-r-size` I3 H1 3cf
- `ext/parity-ranges-footage` I3 H1 3cf
- `ext/parity-ranges-slice` I3 H1 3cf
- `ext/cinder-sable-polish-rebased` I3 H2 5cf

### B06 feel: 40 merges (+381 stacked branches carried), avg impact 6.4/10, avg hard 4.3/10; god-file conflicts: hunter.gd x16, home.gd x14, match.gd x14

- `ext/feel-cast-into-cast-rest` I8 H1 2cf
- `ext/feel-cinder-cancel-rows` I8 H2 2cf
- `ext/feel-air-casts` I7 H1 1cf
- `ext/feel-air-ring-boost` I7 H1 4cf +1 carried
- `ext/feel-grimble-reel` I7 H1 1cf
- `ext/feel-hold-stand` I7 H2 5cf +1 carried
- `ext/feel-vex-e-recovery` I7 H2 9cf
- `ext/feel-yaw-lock-12-rebased` I7 H2 5cf +1 carried
- `ext/hitstop-parity` I7 H2 8cf +1 carried
- `ext/feel-buffers-leftovers` I7 H3 7cf
- `ext/cooldown-gate-1111` I7 H9 31cf +6 carried
- `ext/feel-dash-wall-slide-rebased` I7 H9 36cf +41 carried
- `ext/dash-no-rings-reel` I7 H10 56cf +27 carried
- `ext/feel-cam-mode` I7 H10 55cf +28 carried
- `ext/feel-cinder-poof-cancel` I7 H10 56cf +29 carried
- `ext/feel-first-cast-warm-rebased` I7 H10 88cf +13 carried
- `ext/feel-glide-state` I7 H10 55cf +27 carried
- `ext/feel-landing-recovery` I7 H10 101cf +53 carried
- `ext/feel-reversal-2` I7 H10 55cf +27 carried
- `ext/feel-sparkle-wirerun-glide` I7 H10 56cf +29 carried
- `ext/feel-tenzo-hop-glide` I7 H10 56cf +29 carried
- `ext/feel-wisp-orbit-follow` I7 H10 70cf +22 carried
- `ext/feel-fall-no-carry` I6 H1 3cf
- `ext/feel-glide-wall` I6 H1 1cf +1 carried
- `ext/feel-train-inertia` I6 H1 4cf
- `ext/feel-rocket-fall` I6 H2 3cf pre-tagged
- `ext/feel-rocket-online` I6 H2 3cf
- `ext/feel-summon-on-g` I6 H2 5cf +3 carried
- `ext/feel-chain-sweep-1111` I6 H3 9cf +1 carried
- `ext/feel-one-tuning-home` I6 H3 6cf +1 carried
- `ext/carry-two-in` I6 H4 5cf
- `ext/feel-home-mantle-shared` I6 H4 5cf
- `ext/feel-dash-off-ledge-rebased` I6 H9 37cf +40 carried
- `ext/dash-momentum-1111` I5 H1 3cf
- `ext/feel-ally-safe` I5 H1 2cf
- `ext/feel-camera-lead` I5 H1 3cf
- `ext/feel-dash-jump` I5 H1 2cf
- `ext/feel-lace-cancel-rows` I5 H1 2cf
- `ext/feel-mantle-timing` I5 H1 4cf
- `ext/feel-one-profile-check` I5 H1 1cf

### B07 feel: 40 merges (+117 stacked branches carried), avg impact 4.8/10, avg hard 2.6/10; god-file conflicts: hunter.gd x16, home.gd x13, match.gd x6

- `ext/feel-ranges-on-screen` I5 H1 4cf +2 carried
- `ext/feel-scout-cam` I5 H1 3cf
- `ext/feel-ult-exit-buffer` I5 H1 3cf
- `ext/feel-unsourced-dash-scale` I5 H1 4cf
- `ext/feel-wasd-screen` I5 H1 2cf
- `ext/glide-smooth-1111` I5 H1 2cf
- `ext/feel-aim-raw` I5 H2 2cf
- `ext/feel-aim-steady` I5 H2 2cf
- `ext/feel-camera-frame` I5 H2 5cf
- `ext/feel-glide-mantle` I5 H2 2cf
- `ext/feel-haste-stack` I5 H2 7cf
- `ext/feel-hit-marker` I5 H2 2cf
- `ext/feel-home-dash-one` I5 H2 2cf
- `ext/feel-knock-moment` I5 H2 2cf pre-tagged
- `ext/feel-knock-override-rebased` I5 H2 1cf
- `ext/feel-online-kitefall` I5 H2 5cf
- `ext/knock-banners-1112` I5 H2 2cf
- `ext/knock-moment` I5 H2 4cf
- `ext/move-feel-1111` I5 H2 6cf
- `ext/feel-cast-lock-buffer` I5 H3 9cf +2 carried
- `ext/glider-heat-parity` I5 H3 5cf
- `ext/carry-out-slot` I5 H4 7cf after ext/carry-two-in
- `ext/carry-two-1111` I5 H4 7cf
- `ext/feel-dash-jump-keep` I5 H4 9cf
- `ext/feel-glide-sink-heat` I5 H4 8cf
- `ext/feel-golden-determinism` I5 H4 7cf
- `ext/feel-town-fixed-step` I5 H4 7cf pre-tagged
- `ext/feel-home-fixed-step` I5 H4 7cf after ext/feel-town-fixed-step
- `ext/feel-mini-mantle` I5 H4 7cf
- `ext/feel-stop-slide` I5 H4 8cf
- `ext/move-parity-1-rebased` I5 H4 8cf pre-tagged
- `ext/move-speed-1111` I5 H4 8cf
- `ext/feel-ui-focus` I5 H5 7cf
- `ext/feel-lace-tall-climb-rebased` I5 H9 71cf +113 carried
- `ext/feel-brake-cast` I4 H1 3cf
- `ext/feel-dash-no-input-rebased` I4 H1 2cf pre-tagged
- `ext/feel-fire-slow-sable` I4 H1 2cf
- `ext/feel-remote-move-clear` I4 H1 3cf
- `ext/feel-wall-bounce-angles` I4 H1 2cf
- `ext/dash-curves-c` I4 H2 6cf

### B08 anim+feel: 40 merges (+563 stacked branches carried), avg impact 6.5/10, avg hard 5.3/10; god-file conflicts: home.gd x15, match.gd x8, hunter.gd x7

- `ext/feel-cinder-dash-curve` I4 H2 5cf
- `ext/feel-dashflow-rows` I4 H2 7cf
- `ext/feel-hold-dash-slice` I4 H2 5cf
- `ext/feel-buffers-tuning` I4 H3 5cf
- `ext/feel-dive-net` I4 H3 5cf
- `ext/feel-dash-exit-shed` I3 H1 1cf
- `ext/feel-glide-entry-fit` I3 H1 1cf
- `ext/anim-loco-dir-grimble-sparkle` I8 H5 24cf +5 carried
- `ext/anim-loco-dir-kael-crouch` I8 H5 24cf +5 carried
- `ext/anim-loco-starts` I7 H5 24cf +5 carried
- `ext/anim-loco-snap-startstop` I8 H6 26cf +5 carried after ext/anim-loco-starts
- `ext/anim-fusion-remote` I8 H8 71cf +43 carried
- `ext/anim-tenzo-boulder-sync` I8 H8 58cf +43 carried
- `ext/anim-timing-vex-port` I8 H8 72cf +43 carried
- `ext/anim-land-beat` I8 H9 59cf +44 carried
- `ext/anim-fusion-states-rebased` I8 H10 87cf +13 carried pre-tagged
- `ext/anim-hazard-moves` I8 H10 63cf +27 carried
- `ext/anim-swim-reds` I8 H10 63cf +27 carried after ext/anim-hazard-moves
- `ext/anim-dirloops-pelvis` I7 H1 3cf +2 carried
- `ext/anim-timing-thief` I7 H1 1cf
- `ext/anim-loco-dir-albert` I7 H5 24cf +5 carried
- `ext/anim-meeko-stride` I7 H5 24cf +5 carried
- `ext/anim-loco-dir-last` I7 H6 27cf +5 carried
- `ext/body6-picks-apply` I7 H6 25cf
- `ext/anim-grimble-hook-prop` I7 H8 57cf +43 carried
- `ext/anim-react-2-rebased` I7 H8 42cf +14 carried
- `ext/anim-results-stage-beats` I7 H8 57cf +44 carried
- `ext/anim-stop-on-stride` I7 H8 57cf +45 carried
- `ext/anim-boki-react-three` I7 H9 124cf +21 carried
- `ext/anim-downed-wisp` I7 H9 73cf +43 carried
- `ext/anim-boki-cast-rebased` I7 H10 80cf +13 carried
- `ext/anim-guardian-stance` I7 H10 49cf +14 carried
- `ext/anim-timing-gunslinger` I7 H10 190cf +46 carried
- `ext/anim-aim-pitch` I6 H1 1cf
- `ext/anim-boss-remote` I6 H1 3cf +1 carried
- `ext/anim-fusion-states-rebased-rebased` I6 H1 4cf
- `ext/anim-dash-clips-motley-grimble` I6 H2 6cf
- `ext/anim-mantle-3` I6 H2 7cf
- `ext/anim-pilot-layers-verify` I6 H2 6cf +1 carried
- `ext/anim-stop-start` I6 H2 7cf +1 carried

### B09 anim: 40 merges (+15 stacked branches carried), avg impact 5.3/10, avg hard 1.6/10; god-file conflicts: match.gd x5, hunter.gd x4, home.gd x1

- `ext/anim-summon-clips` I6 H2 9cf +3 carried
- `ext/anim-time-d-rebased` I6 H2 5cf
- `ext/anim-cc-body` I6 H3 8cf
- `ext/anim-heartspark-carry` I6 H3 8cf +1 carried
- `ext/anim-summon-call` I6 H3 11cf +3 carried
- `ext/anim-utility-poses-2` I6 H3 8cf +1 carried
- `ext/anim-empty-garden` I6 H4 12cf
- `ext/anim-remote-stomp` I6 H4 10cf
- `ext/anim-skydive` I6 H4 6cf
- `ext/anim-stomp-per-hunter` I6 H4 10cf
- `ext/anim-rocket-ride` I6 H5 14cf
- `ext/anim-albert-hammer-scale` I5 H1 3cf +1 carried
- `ext/anim-boki-contact` I5 H1 2cf
- `ext/anim-boki-dash-lean` I5 H1 2cf
- `ext/anim-boki-fish-watch` I5 H1 2cf
- `ext/anim-boki-hit-faint` I5 H1 2cf +1 carried
- `ext/anim-boki-nap` I5 H1 2cf
- `ext/anim-boki-stop-turn` I5 H1 2cf
- `ext/anim-clip-checks-data` I5 H1 1cf
- `ext/anim-dash-clips-cinder-lace` I5 H1 2cf
- `ext/anim-dirloops-cinder-sable` I5 H1 4cf +2 carried after ext/anim-dirloops-pelvis
- `ext/anim-flinch-data` I5 H1 1cf
- `ext/anim-gun-recoil-rebased` I5 H1 4cf
- `ext/anim-kael-ult-recovery` I5 H1 1cf
- `ext/anim-look-at` I5 H1 3cf
- `ext/anim-motley-legs-arm` I5 H1 4cf
- `ext/anim-pick-lockin` I5 H1 2cf
- `ext/anim-run-aim-twist` I5 H1 3cf
- `ext/anim-run-start-stop` I5 H1 2cf
- `ext/anim-slide-sweep` I5 H1 4cf
- `ext/anim-sparkle-sky-hold` I5 H1 3cf
- `ext/anim-start-gap-slice` I5 H1 4cf pre-tagged
- `ext/anim-tenzo-on-rocks` I5 H1 4cf +1 carried
- `ext/anim-tenzo-upper-body` I5 H1 2cf
- `ext/anim-timing-dredge` I5 H1 3cf
- `ext/anim-timing-juggernaut` I5 H1 1cf +1 carried
- `ext/anim-timing-mage` I5 H1 1cf
- `ext/anim-turn-in-place` I5 H1 3cf
- `ext/anim-wall-kick` I5 H1 2cf
- `ext/customize-look-1` I5 H1 1cf +1 carried

### B10 anim: 40 merges (+13 stacked branches carried), avg impact 4.6/10, avg hard 2.1/10; god-file conflicts: hunter.gd x4, match.gd x2, home.gd x1

- `ext/idle-thief-rebased` I5 H1 3cf
- `ext/anim-albert-land` I5 H2 5cf +1 carried
- `ext/anim-boki-fly` I5 H2 6cf
- `ext/anim-boki-seams` I5 H2 7cf
- `ext/anim-boki-swim` I5 H2 9cf
- `ext/anim-cancel-blend` I5 H2 9cf
- `ext/anim-dirloops-albert-neve` I5 H2 9cf +3 carried
- `ext/anim-dirloops-lace-kael` I5 H2 7cf +2 carried
- `ext/anim-emote-gestures` I5 H2 8cf
- `ext/anim-mantle-2` I5 H2 9cf
- `ext/anim-meeko-loops-length` I5 H2 6cf
- `ext/anim-race-beats` I5 H2 7cf
- `ext/anim-slice-cast-pops` I5 H2 7cf
- `ext/anim-start-gap-rest` I5 H2 5cf after ext/anim-start-gap-slice
- `ext/gait-speed-port` I5 H2 8cf
- `ext/icons-props-1112` I5 H2 8cf
- `ext/anim-downed` I5 H3 9cf
- `ext/anim-elim-beat` I5 H3 6cf
- `ext/anim-empty-care` I5 H3 6cf
- `ext/anim-bul-guard-remote` I5 H4 6cf
- `ext/anim-gait-speed` I5 H4 15cf
- `ext/anim-react-settle-neve-tenzo` I5 H4 15cf +4 carried
- `ext/anim-revive-12` I5 H4 15cf
- `ext/anim-stomp-starters` I5 H5 16cf pre-tagged
- `ext/anim-strafe-back` I5 H6 20cf +3 carried
- `ext/anim-albert-jog-blend` I4 H1 3cf
- `ext/anim-cinder-cloak-peak` I4 H1 1cf
- `ext/anim-meeko-tiptoe` I4 H1 3cf
- `ext/anim-neve-run-v95` I4 H1 2cf
- `ext/anim-neve-spear-keys` I4 H1 3cf
- `ext/anim-neve-stride` I4 H1 3cf
- `ext/anim-pilot-loops-cm-v2` I4 H1 2cf
- `ext/anim-pilot-loops-sm` I4 H1 3cf
- `ext/anim-tenzo-spine-rekey` I4 H1 3cf
- `ext/anim-timing-ashwick` I4 H1 3cf
- `ext/anim-timing-rimewright` I4 H1 1cf
- `ext/idle-bulwark-rebased` I4 H1 2cf
- `ext/idle-tender-rebased` I4 H1 4cf
- `ext/anim-boki-run-reach` I4 H2 9cf
- `ext/anim-hand-pop` I4 H2 6cf

### B11 vfx+anim: 40 merges (+421 stacked branches carried), avg impact 5.7/10, avg hard 4.4/10; god-file conflicts: hunter.gd x15, match.gd x12, hud.gd x11

- `ext/anim-skin-relax-b` I4 H2 6cf
- `ext/anim-skin-relax-slice` I4 H2 6cf
- `ext/anim-stretch-starters` I4 H2 5cf
- `ext/anim-vex-rekeys` I4 H2 5cf
- `ext/skin-relax-slice` I4 H2 6cf
- `ext/anim-pilot-idle-slice` I3 H1 2cf
- `ext/anim-pilot-slice3` I3 H1 2cf
- `ext/idle-archer-rebased` I3 H1 4cf
- `ext/idle-dredge-rebased` I3 H1 3cf
- `ext/idle-gunslinger-rebased` I3 H1 2cf
- `ext/idle-mage-rebased` I3 H1 2cf
- `ext/idle-ostra` I3 H1 4cf
- `ext/anim-pilot-four` I3 H2 5cf +1 carried
- `ext/stretch-reds` I3 H3 13cf
- `ext/vfx-albert-slab` I8 H2 6cf
- `ext/vfx-kael-hold-arc` I8 H2 9cf +1 carried
- `ext/vfx-origin-v2-rebased` I8 H9 59cf +7 carried
- `ext/vfx-meeko-weight-rebased-rebased` I8 H10 198cf +47 carried
- `ext/vfx-vex-tracer-0246` I8 H10 109cf +28 carried
- `ext/vfx-team-marker-cel` I7 H1 4cf
- `ext/vfx-lace-spirit-walk-on-lace` I7 H2 8cf +1 carried
- `ext/vfx-pass-triage` I7 H2 9cf
- `ext/vfx-vex-precast-slab` I7 H2 6cf
- `ext/vfx-summon-ring` I7 H4 13cf +10 carried
- `ext/vfx-revive-read-rebased` I7 H8 35cf +13 carried
- `ext/vfx-spitter-tell` I7 H8 41cf +27 carried
- `ext/telegraph-drawn-hit-port` I7 H10 72cf +22 carried
- `ext/vfx-carry-wisps` I7 H10 74cf +21 carried
- `ext/vfx-dash-no-rings` I7 H10 55cf +28 carried
- `ext/vfx-grimble-data` I7 H10 106cf +28 carried
- `ext/vfx-grimble-fist-port` I7 H10 107cf +28 carried
- `ext/vfx-motley-port` I7 H10 112cf +58 carried
- `ext/vfx-sable-encore` I7 H10 113cf +28 carried
- `ext/vfx-telegraph-timing-rebased` I7 H10 120cf +42 carried
- `ext/vfx-tenzo-punch-hold` I7 H10 112cf +28 carried
- `ext/vfx-cat-colour-fence` I6 H1 1cf
- `ext/vfx-garden-games-2` I6 H1 4cf +2 carried
- `ext/vfx-hawk-sense` I6 H1 3cf
- `ext/vfx-last-hit-colour` I6 H1 2cf +1 carried
- `ext/vfx-meeko-weight-rebased` I6 H1 1cf pre-tagged

### B12 vfx: 40 merges (+65 stacked branches carried), avg impact 5.3/10, avg hard 2.2/10; god-file conflicts: match.gd x8, hunter.gd x4, home.gd x2

- `ext/vfx-mob-death-anim-rebased` I6 H1 3cf
- `ext/vfx-motley-kit` I6 H2 7cf
- `ext/vfx-motley-orb-hit` I6 H2 5cf
- `ext/vfx-air-rings-read` I6 H3 7cf +1 carried
- `ext/vfx-cc-body-reads` I6 H3 5cf +2 carried
- `ext/vfx-rocket-drop` I6 H3 6cf after ext/rocket-drop-1111
- `ext/vfx-utilities-2` I6 H3 9cf +1 carried
- `ext/vfx-vex-kit` I6 H4 17cf +1 carried after ext/vex-greenfire-1108
- `ext/vfx-vex-data` I5 H2 6cf
- `ext/vfx-vex-tracer-data` I6 H4 10cf after ext/vfx-vex-data
- `ext/vfx-stomp` I6 H5 12cf
- `ext/vfx-utility-read` I6 H7 19cf +1 carried
- `ext/vfx-neve-rimelock-area` I6 H8 28cf +28 carried
- `ext/vfx-kael-smash-lane-on-slam-lane` I6 H9 31cf +30 carried
- `ext/vfx-armour-tier-up` I5 H1 2cf
- `ext/vfx-capture-read` I5 H1 2cf
- `ext/vfx-dot-body` I5 H1 2cf
- `ext/vfx-fusion-topdown` I5 H1 3cf
- `ext/vfx-garden-item-apply` I5 H1 3cf
- `ext/vfx-gil-aimkit` I5 H1 3cf
- `ext/vfx-gil-bar` I5 H1 4cf
- `ext/vfx-gil-colour` I5 H1 2cf
- `ext/vfx-heal-read-1111` I5 H1 3cf
- `ext/vfx-kael-kit` I5 H1 3cf
- `ext/vfx-lace-heavy-impact` I5 H1 3cf +1 carried
- `ext/vfx-motley-data` I5 H1 4cf
- `ext/vfx-particle-budget-fight` I5 H1 3cf
- `ext/vfx-ring-audit` I5 H1 4cf
- `ext/vfx-sparkle-ult-local` I5 H1 2cf
- `ext/vfx-telegraph-lead-rebased` I5 H1 2cf
- `ext/vfx-telegraph-net` I5 H1 4cf
- `ext/vfx-vex-scorch-rim` I5 H1 2cf
- `ext/vfx-vex-tracer` I5 H1 2cf
- `ext/vfx-vex-tracer-strips` I5 H1 2cf
- `ext/vfx-ways-out-read` I5 H1 2cf
- `ext/vfx-colour-audit` I5 H2 9cf
- `ext/vfx-grimble-anchor` I5 H2 5cf
- `ext/vfx-hit-flash-kind` I5 H2 2cf
- `ext/vfx-meeko-ult-field` I5 H2 6cf
- `ext/vfx-motley-trade-teal` I5 H2 5cf after ext/vfx-motley-data

### B13 vfx+ui: 25 merges (+67 stacked branches carried), avg impact 4.8/10, avg hard 3.0/10; god-file conflicts: match.gd x4, hud.gd x2, home.gd x2

- `ext/vfx-quality-motley` I5 H2 7cf +1 carried
- `ext/vfx-shield-break` I5 H2 3cf
- `ext/vfx-sparkle-casts` I5 H2 9cf
- `ext/vfx-stolen-wisps-rebased` I5 H2 7cf +3 carried
- `ext/vfx-tenzo-data` I5 H2 5cf
- `ext/vfx-tenzo-dust-thin` I5 H2 5cf
- `ext/vfx-vex-lance-beam` I5 H2 6cf
- `ext/vfx-gold-ground-rings` I5 H3 12cf
- `ext/vfx-lace-sparkle-trails-strips` I5 H3 8cf +1 carried
- `ext/squad-frames` I5 H3 5cf
- `ext/vfx-last-man-aura` I5 H3 5cf after ext/squad-frames
- `ext/vfx-meeko-kindle-numbers` I5 H3 6cf
- `ext/vfx-meeko-palette` I5 H3 13cf
- `ext/vfx-sparkle-skycall-cast` I5 H3 12cf +1 carried
- `ext/vfx-meeko-hit-hearth` I5 H4 16cf
- `ext/vfx-garden-games` I5 H5 21cf +2 carried
- `ext/vfx-lowpreset-read` I5 H6 19cf +3 carried
- `ext/vfx-albert-ivory-arcs` I5 H9 31cf +28 carried
- `ext/vfx-ground-ring-hitbox` I5 H9 31cf +28 carried
- `ext/vfx-albert-slam-fill` I4 H1 1cf
- `ext/vfx-cinder-ignite-orb` I4 H1 4cf
- `ext/vfx-gold-to-slot` I4 H1 2cf
- `ext/vfx-sable-ring-grow` I4 H1 2cf
- `ext/vfx-zone-fill-meeko-sable` I4 H1 1cf
- `ext/vfx-zone-rims` I4 H2 5cf

### B14 audio: 40 merges (+537 stacked branches carried), avg impact 6.4/10, avg hard 5.5/10; god-file conflicts: match.gd x21, home.gd x14, hunter.gd x14

- `ext/sfx-beat-resync` I8 H8 70cf +43 carried
- `ext/sfx-garden-games-rebased` I8 H10 85cf +13 carried
- `ext/sfx-swim-ice-moves` I8 H10 63cf +27 carried after ext/anim-hazard-moves
- `ext/summon-share-port` I8 H10 70cf +21 carried
- `ext/sfx-steals` I7 H4 12cf +3 carried
- `ext/sfx-summon-end` I7 H4 12cf +10 carried
- `ext/sfx-wisp-proc` I7 H8 34cf +10 carried
- `ext/hushwood-port` I7 H9 116cf +19 carried
- `ext/sfx-boki-voices-3` I7 H9 89cf +19 carried
- `ext/sfx-ability-ready` I7 H10 107cf +28 carried
- `ext/sfx-boki-state-cues` I7 H10 186cf +46 carried
- `ext/sfx-boki-state-cues-wisp` I7 H10 70cf +22 carried
- `ext/sfx-dash-per-hunter-rebased` I7 H10 79cf +13 carried
- `ext/sfx-match-shop` I7 H10 58cf +27 carried
- `ext/sfx-strike-resync` I7 H10 156cf +72 carried
- `ext/sfx-terrain-hazards` I7 H10 57cf +27 carried
- `ext/summon-kill-credit-port` I7 H10 112cf +58 carried
- `ext/utility-parity-0246` I7 H10 77cf +25 carried
- `ext/sfx-boki-landings` I6 H1 2cf
- `ext/sfx-boss-windups` I6 H1 3cf +1 carried
- `ext/sfx-last-alive` I6 H1 3cf
- `ext/sfx-ui-controls` I6 H1 2cf
- `ext/sfx-voice-priority` I6 H1 4cf
- `ext/sfx-air-rings` I6 H2 6cf +1 carried
- `ext/sfx-creator-clans` I6 H2 7cf +2 carried
- `ext/sfx-rocket-drop` I6 H2 4cf
- `ext/sfx-garden-items` I6 H3 8cf +2 carried
- `ext/sfx-boon-cue` I6 H4 14cf +1 carried
- `ext/sfx-camp-idle` I6 H4 14cf
- `ext/sfx-raid-cues` I6 H4 8cf +2 carried
- `ext/sfx-stomp-break` I6 H4 10cf
- `ext/sfx-utilities-2` I6 H5 13cf +3 carried
- `ext/sfx-garden-games-3` I6 H6 23cf
- `ext/step-sounds-unified-rebased` I6 H9 43cf +42 carried
- `ext/sfx-abyss` I5 H1 2cf
- `ext/sfx-abyss-fall` I5 H1 2cf
- `ext/sfx-boki-life-wire` I5 H1 2cf
- `ext/sfx-bus-ducking` I5 H1 3cf
- `ext/sfx-bus-sliders` I5 H1 4cf
- `ext/sfx-cc-on-you` I5 H1 2cf

### B15 audio: 40 merges (+11 stacked branches carried), avg impact 5.0/10, avg hard 1.7/10; god-file conflicts: home.gd x3, match.gd x3, hunter.gd x1

- `ext/sfx-closing-zone` I5 H1 4cf
- `ext/sfx-combo-payoffs` I5 H1 2cf
- `ext/sfx-enemy-tells` I5 H1 3cf
- `ext/sfx-glint-fishing` I5 H1 4cf
- `ext/sfx-held-fire-cadence` I5 H1 3cf
- `ext/sfx-knock-confirm` I5 H1 3cf
- `ext/sfx-mixing-bowl` I5 H1 3cf
- `ext/sfx-quest-exits` I5 H1 2cf
- `ext/sfx-rank-pick` I5 H1 4cf
- `ext/sfx-ready-cues` I5 H1 4cf pre-tagged
- `ext/sfx-silence-audit` I5 H1 3cf
- `ext/sfx-status-cues` I5 H1 3cf
- `ext/sfx-voice-cap` I5 H1 4cf
- `ext/sfx-ways-out-ticks` I5 H1 2cf
- `ext/sfx-whistle-answer` I5 H1 4cf
- `ext/sfx-biome-beds` I5 H2 5cf
- `ext/sfx-type-cues-19` I4 H2 6cf
- `ext/sfx-boki-ability-impacts` I5 H2 7cf after ext/sfx-type-cues-19
- `ext/sfx-boki-steps` I5 H2 5cf
- `ext/sfx-breakables` I5 H2 5cf
- `ext/sfx-coverage-world` I5 H2 6cf
- `ext/sfx-falloff-wide-cam` I5 H2 7cf +2 carried
- `ext/sfx-fusion-forms` I5 H2 8cf +1 carried
- `ext/sfx-hunter-wisp-hum` I5 H2 5cf
- `ext/sfx-incoming-hit-dir` I5 H2 5cf +2 carried
- `ext/sfx-interrupt-cut` I5 H2 6cf
- `ext/sfx-kit-placeholders-2` I5 H2 7cf +1 carried
- `ext/sfx-listener-hunter` I5 H2 4cf
- `ext/sfx-loot-open` I5 H2 3cf
- `ext/sfx-mix-pass` I5 H2 6cf
- `ext/sfx-mob-attacks` I5 H2 4cf
- `ext/sfx-neve-skate` I5 H2 5cf
- `ext/sfx-pick-taken` I5 H2 7cf +1 carried
- `ext/sfx-ready-cues-summon` I5 H2 8cf +2 carried
- `ext/sfx-step-surfaces-2x` I5 H2 5cf
- `ext/sfx-training-grounds` I5 H2 6cf
- `ext/sfx-garden-events` I5 H3 9cf
- `ext/sfx-garden-zone-music` I5 H3 5cf
- `ext/sfx-hunter-barks` I5 H3 7cf after ext/sfx-voice-cap
- `ext/sfx-hunter-foley` I5 H3 9cf +2 carried

### B16 audio+ui: 40 merges (+180 stacked branches carried), avg impact 5.4/10, avg hard 3.1/10; god-file conflicts: hud.gd x10, home.gd x9, hunter.gd x8

- `ext/sfx-inventory-actions` I5 H3 8cf
- `ext/sfx-low-hp-filter-rebased` I5 H3 8cf +1 carried
- `ext/sfx-nook` I5 H3 5cf
- `ext/sfx-xp-steal` I5 H3 5cf
- `ext/sfx-garden-visitors-cups` I5 H4 11cf
- `ext/sfx-solos-quiet` I5 H4 13cf
- `ext/sfx-stomp-1111` I5 H4 10cf
- `ext/sfx-water` I5 H4 10cf +2 carried
- `ext/sfx-carry-cues` I5 H5 12cf
- `ext/sfx-steps-dirloops` I5 H5 16cf +3 carried
- `ext/sfx-armour-tier-up` I4 H1 2cf
- `ext/sfx-chop-mine` I4 H1 3cf
- `ext/sfx-hostile-casts` I4 H1 3cf
- `ext/sfx-level-rank` I4 H1 3cf
- `ext/sfx-loudness-0245` I4 H1 2cf
- `ext/sfx-meeko-channel-loop` I4 H1 1cf
- `ext/sfx-rarity-stings` I4 H1 3cf
- `ext/sfx-shield-break` I4 H1 2cf
- `ext/sfx-sparkle-ult-beats` I4 H1 3cf
- `ext/sfx-hit-tick-family` I4 H2 6cf
- `ext/sfx-garden-react` I4 H3 5cf
- `ext/infra-usage-plan` I3 H1 0cf
- `ext/infra-usage-remote-source` I3 H1 0cf
- `ext/hud-g-armor-1111` I8 H1 1cf
- `ext/ui-bonus-column` I8 H3 8cf
- `ext/ui-loading-bar-steady` I8 H10 70cf +22 carried
- `ext/creator-preview` I7 H1 2cf
- `ext/ui-self-shield-strip` I7 H1 3cf
- `ext/ui-text-chat-rebased` I7 H2 9cf +3 carried
- `ext/hud-ref-copy-2` I7 H3 7cf
- `ext/ui-banner-queue-calm` I7 H3 9cf +26 carried
- `ext/ui-summon-card` I7 H9 38cf +16 carried
- `ext/ui-aspect-sweep` I7 H10 56cf +26 carried
- `ext/ui-boki-box-carry` I7 H10 56cf +26 carried
- `ext/ui-loot-compare` I7 H10 56cf +26 carried
- `ext/ui-card-numbers` I6 H1 3cf
- `ext/ui-key-caps` I6 H1 3cf
- `ext/ui-hud-reveal-1110` I6 H2 8cf +3 carried
- `ext/ui-label-spacing` I6 H2 2cf
- `ext/ui-next-form-port` I6 H2 8cf +26 carried

### B17 ui+misc: 40 merges (+13 stacked branches carried), avg impact 5.6/10, avg hard 2.9/10; god-file conflicts: match.gd x12, hud.gd x11, home.gd x7

- `ext/ui-quest-race-pips` I6 H2 5cf
- `ext/ui-rocket-hud` I6 H2 3cf after ext/rocket-drop-1111
- `ext/ui-safe-area-one` I6 H2 4cf
- `ext/ui-simplify` I6 H2 5cf +1 carried
- `ext/ui-squad-killer` I6 H2 4cf
- `ext/ui-hazard-map` I6 H3 6cf
- `ext/ui-hudref-verify` I6 H3 7cf
- `ext/ui-pro-1111` I6 H3 9cf
- `ext/ui-ride-pick` I6 H3 5cf +2 carried
- `ext/ui-shop-panel` I6 H3 7cf +1 carried pre-tagged
- `ext/ui-banner-queue` I6 H4 8cf
- `ext/ui-level-gap` I6 H4 11cf
- `ext/ui-overhead-ref` I6 H4 10cf
- `ext/ui-raid-boss-bar-online` I6 H4 6cf +1 carried
- `ext/ui-stomp-picker` I6 H4 10cf
- `ext/ui-trios-only-text` I6 H4 5cf +1 carried
- `ext/ui-belt-six-rebased` I6 H5 13cf +1 carried
- `ext/ui-simplify-1111` I6 H5 11cf after ext/ui-pro-1111
- `ext/ui-stomp-ring` I6 H5 11cf
- `ext/ui-boki-box-hazard` I6 H6 12cf
- `ext/modes-solos-1111` I5 H3 9cf
- `ext/ui-solos-hud` I6 H6 19cf after ext/modes-solos-1111
- `ext/hunters3d-0246` I6 H8 31cf
- `ext/hunter-first-hints` I6 H10 95cf +2 carried
- `ext/creator-empty-marks` I5 H1 1cf +2 carried
- `ext/intro-hold-skip-1111` I5 H1 1cf
- `ext/ui-dex-filters` I5 H1 2cf +1 carried
- `ext/ui-drop-plan-first` I5 H1 4cf
- `ext/ui-fusion-hud` I5 H1 4cf
- `ext/ui-hunter-stats` I5 H1 1cf
- `ext/ui-keybind-conflicts` I5 H1 3cf
- `ext/ui-meeko-channel-ally` I5 H1 4cf
- `ext/ui-minigame-picker-0245` I5 H1 2cf
- `ext/ui-pause-more` I5 H1 2cf
- `ext/ui-results-first` I5 H1 2cf +1 carried
- `ext/ui-ult-ready` I5 H1 2cf
- `ext/ui-ways-out-colourblind` I5 H1 4cf
- `ext/ui-wisp-picker` I5 H1 2cf
- `ext/ui-zone-cards` I5 H1 1cf
- `ext/ui-buff-stack` I5 H2 1cf

### B18 ui: 40 merges (+7 stacked branches carried), avg impact 4.7/10, avg hard 2.7/10; god-file conflicts: hud.gd x16, home.gd x7, match.gd x3

- `ext/ui-counter-overlap` I5 H2 1cf
- `ext/ui-edge-markers-one` I5 H2 2cf
- `ext/ui-expedition-first` I5 H2 2cf
- `ext/ui-garden-result-card` I5 H2 6cf
- `ext/ui-glossary-pass` I5 H2 7cf
- `ext/ui-loot-feed` I5 H2 3cf
- `ext/ui-mask-preview-warm` I5 H2 3cf
- `ext/ui-match-phase` I5 H2 3cf
- `ext/ui-relics-grid` I5 H2 3cf
- `ext/ui-tab-board-stats` I5 H2 3cf +1 carried
- `ext/ui-world-ping` I5 H2 2cf
- `ext/ui-font-wght-tag` I5 H3 7cf
- `ext/ui-hud-groups-verify` I5 H3 5cf
- `ext/ui-waysout-safe-area` I5 H3 5cf +1 carried
- `ext/ui-hud-scale` I5 H3 5cf +1 carried after ext/ui-waysout-safe-area
- `ext/ui-inventory-pass` I5 H3 5cf
- `ext/ui-knock-feed` I5 H3 5cf +1 carried after ext/ui-waysout-safe-area
- `ext/ui-mode-cards` I5 H3 8cf
- `ext/ui-portal-boki-card` I5 H3 5cf +2 carried
- `ext/ui-quest-tracker` I5 H3 6cf +1 carried
- `ext/ui-garden-text-size` I5 H4 8cf
- `ext/ui-stomp-state` I5 H4 11cf
- `ext/ui-zone-next` I5 H4 10cf
- `ext/ui-declutter-1111` I5 H5 15cf
- `ext/ui-plate-status-row` I5 H5 15cf
- `ext/ui-rebind-everywhere` I5 H5 16cf
- `ext/ui-text-size` I5 H5 13cf
- `ext/ui-tooltip-from-data` I5 H5 23cf
- `ext/ui-first15-0245` I4 H1 2cf
- `ext/ui-first15-leftovers` I4 H1 4cf
- `ext/ui-prematch-margin` I4 H1 3cf
- `ext/ui-results-plain` I4 H1 1cf
- `ext/ui-self-cc-timer` I4 H1 2cf
- `ext/ui-stale-text-pass` I4 H1 4cf
- `ext/ui-start-here-port` I4 H1 3cf
- `ext/hunter-regen-meshy` I4 H2 8cf
- `ext/ui-kit-panel-fight` I4 H2 3cf
- `ext/ui-words-cut-match` I4 H2 9cf
- `ext/hunter-revamp-go` I4 H3 13cf
- `ext/hunter-revamp-af` I3 H5 21cf

### B19 tutorial: 40 merges (+322 stacked branches carried), avg impact 6.5/10, avg hard 6.3/10; god-file conflicts: home.gd x28, match.gd x26, main.gd x9

- `ext/tut-revive-hint` I9 H9 49cf +5 carried
- `ext/tutorial-beats-5-6-rebased-rebased` I9 H10 81cf +14 carried
- `ext/tut-event-hints-rebased` I8 H10 182cf +41 carried
- `ext/tut-seat-grace-hint` I7 H2 9cf +6 carried
- `ext/tut-farm-old-steps-cut` I7 H4 11cf
- `ext/tut-first-proc` I7 H6 24cf +16 carried
- `ext/tut-beat-retry-port` I7 H9 30cf +6 carried
- `ext/tut-dive-hint` I7 H9 49cf +5 carried
- `ext/tut-duel-hint-port` I7 H9 33cf +6 carried
- `ext/tut-first-utility` I7 H9 62cf +6 carried
- `ext/tut-no-ripe-timer-1111` I7 H9 30cf +6 carried
- `ext/tut-retry-port` I7 H9 31cf +6 carried
- `ext/tut-wall-kick-hint` I7 H9 48cf +5 carried
- `ext/tutorial-banner-1111` I7 H9 34cf +6 carried
- `ext/tut-duel-ring-rebased` I7 H10 182cf +41 carried
- `ext/tut-first-fuse` I7 H10 52cf +14 carried
- `ext/tut-first-shop` I7 H10 56cf +27 carried
- `ext/tut-garden-first-day-rebased` I7 H10 86cf +13 carried
- `ext/tut-summon-pad` I7 H10 92cf +28 carried
- `ext/tut-air-rings` I6 H1 4cf +1 carried
- `ext/hob-clear-spot` I6 H2 4cf
- `ext/tut-first-hour-order` I6 H2 4cf
- `ext/tut-first15-reshoot` I6 H2 5cf
- `ext/tut-rocket-hint` I6 H2 3cf
- `ext/tutorial-idle-check` I6 H2 4cf
- `ext/tut-hazard-hint` I6 H3 7cf
- `ext/tut-hud-pointers` I6 H3 9cf
- `ext/tut-drop-old-farm-steps` I6 H4 12cf
- `ext/tut-garden-no-gather` I6 H4 14cf
- `ext/tut-heart-raid-hints` I6 H4 6cf
- `ext/tut-first-camp` I6 H5 15cf
- `ext/tut-wisp-beats` I6 H5 11cf +3 carried
- `ext/tut-first-games-port` I6 H7 26cf +19 carried
- `ext/tut-dodge-dummy-rebased` I6 H8 21cf +4 carried
- `ext/tut-solo-words` I6 H8 20cf
- `ext/tut-stomp-hints` I6 H8 24cf
- `ext/tut-summon-station` I6 H8 24cf +3 carried
- `ext/tut-hints-blight-camp-box` I6 H10 37cf +40 carried
- `ext/training-time-trial` I5 H1 4cf +1 carried
- `ext/tut-beat-retry` I5 H1 4cf

### B20 tutorial+farm+docs+misc: 40 merges (+22 stacked branches carried), avg impact 4.9/10, avg hard 2.0/10; god-file conflicts: match.gd x14, home.gd x5, hunter.gd x2

- `ext/tut-creator-first-pass` I5 H1 3cf
- `ext/tut-first-capture` I5 H1 1cf
- `ext/tut-first-race-rebased` I5 H1 1cf
- `ext/tut-first-tumble` I5 H1 2cf
- `ext/tut-hatch-skip` I5 H1 2cf
- `ext/tut-human-pace` I5 H1 2cf
- `ext/tut-kael-starter` I5 H1 2cf +1 carried
- `ext/tut-last-hit-xp` I5 H1 3cf +1 carried
- `ext/tut-recast-drill` I5 H1 2cf
- `ext/tut-shelter-pointer` I5 H1 2cf
- `ext/tut-words-page-rebased` I5 H1 4cf
- `ext/tut-xp-share` I5 H1 4cf +2 carried
- `ext/tut-armour-not-xp` I5 H2 2cf
- `ext/tut-context-tips-rebased` I5 H2 3cf
- `ext/garden-nook-preview` I5 H2 2cf
- `ext/tut-first-breed` I5 H2 4cf after ext/garden-nook-preview
- `ext/tut-first-evolve` I5 H2 3cf +2 carried
- `ext/tut-first-knock-tip` I5 H2 1cf
- `ext/tut-first-recast` I5 H2 3cf after ext/tut-context-tips-rebased
- `ext/tut-fresh-run` I5 H2 5cf
- `ext/tut-vision-hint` I5 H2 2cf
- `ext/match-cam-wide-1112` I6 H4 10cf +2 carried
- `ext/tut-wide-cam` I5 H2 5cf +2 carried after ext/match-cam-wide-1112
- `ext/br-zone-1111` I5 H1 2cf
- `ext/tut-zone-first` I5 H2 5cf after ext/br-zone-1111
- `ext/tut-belt-hint-rebased` I5 H3 7cf +3 carried
- `ext/tut-crouch-hint` I5 H3 4cf after ext/tut-context-tips-rebased
- `ext/tut-keycap-audit` I5 H3 8cf
- `ext/tut-live-keys` I5 H3 7cf
- `ext/tut-zoom-hint` I5 H3 5cf +2 carried
- `ext/tut-carry-hints` I5 H5 8cf pre-tagged
- `ext/tut-first-games` I5 H5 24cf +2 carried
- `ext/tut-first-heartspark-rebased` I5 H5 16cf +5 carried
- `ext/tut-lead-swap-hint` I5 H5 8cf after ext/carry-two-1111
- `ext/npc-hero-1112` I4 H1 4cf
- `ext/tut-first-visitor` I4 H1 2cf
- `ext/tut-first-wayseed` I4 H1 1cf
- `ext/tut-hatch-beat` I4 H1 1cf
- `ext/tut-one-prompt` I4 H1 4cf
- `ext/tut-recast-hint` I4 H1 1cf

### B21 farm+tutorial: 40 merges (+349 stacked branches carried), avg impact 6.4/10, avg hard 5.4/10; god-file conflicts: match.gd x25, home.gd x14, hunter.gd x10

- `ext/tut-start-here-rebased-rebased` I4 H1 4cf
- `ext/tut-vex-starter` I4 H1 2cf +1 carried
- `ext/tut-hot-zone-line` I4 H2 5cf
- `ext/tut-glide-double-press` I4 H3 4cf
- `ext/farm-sick-recover-port` I8 H9 122cf +19 carried
- `ext/garden-sick-recover` I8 H9 119cf +19 carried after ext/farm-sick-recover-port
- `ext/farm-minkee-name` I8 H10 70cf +21 carried
- `ext/garden-snacks-all-types-rebased` I8 H10 87cf +14 carried
- `ext/garden-race-ghost` I7 H2 4cf
- `ext/garden-bramble-dupes` I7 H3 8cf
- `ext/early-xp-readout` I7 H4 11cf
- `ext/early-camps-0244` I7 H6 16cf
- `ext/early-camps-bots-c` I7 H6 18cf
- `ext/early-wisp-refund` I7 H6 19cf +10 carried
- `ext/garden-play-0246` I7 H7 25cf +19 carried
- `ext/farm-build-polish-1111` I7 H9 31cf +6 carried
- `ext/farm-feed-bowl-port` I7 H9 116cf +19 carried
- `ext/garden-deflake` I7 H9 123cf +19 carried
- `ext/garden-items-form` I7 H9 122cf +19 carried
- `ext/farm-demo-evolve-gate` I7 H10 70cf +22 carried
- `ext/farm-leave-match-order` I7 H10 70cf +22 carried
- `ext/farm-soul-echo` I7 H10 112cf +58 carried
- `ext/farm-stolen-homecoming` I7 H10 72cf +22 carried
- `ext/garden-care-prompt` I7 H10 63cf +29 carried
- `ext/soul-link-t4-rebased` I7 H10 114cf +22 carried
- `ext/clans-slice-3-tag` I6 H1 2cf
- `ext/extra-clan-breeding-loans` I6 H2 6cf +2 carried
- `ext/extra-kin-v2-dedupe` I6 H2 9cf
- `ext/garden-balance-apply` I6 H2 9cf +2 carried
- `ext/garden-breed-preview` I6 H2 2cf
- `ext/garden-soak-zones` I6 H2 6cf
- `ext/relic-preview-hitch` I6 H2 4cf after ext/ui-mask-preview-warm
- `ext/early-drop-height` I6 H3 7cf
- `ext/farm-hazard-counter-card` I6 H3 6cf
- `ext/fold-feel-dash-1112` I6 H3 9cf +2 carried
- `ext/garden-tag` I6 H3 5cf +2 carried
- `ext/early-camps-bots` I6 H4 13cf
- `ext/early-guarded-boki` I6 H4 10cf
- `ext/early-hard-landing` I6 H4 12cf
- `ext/early-steal-window` I6 H4 12cf

### B22 farm: 40 merges (+118 stacked branches carried), avg impact 5.3/10, avg hard 2.7/10; god-file conflicts: home.gd x8, match.gd x4, hunter.gd x4

- `ext/fold-anim-boki-1112` I6 H4 15cf +3 carried
- `ext/fold-meeko-rmb-1112` I6 H4 13cf +1 carried
- `ext/early-camps-bots-a3` I6 H5 15cf
- `ext/fold-anim-time-1112` I6 H5 20cf +3 carried
- `ext/fold-tut-first-1112` I6 H5 14cf +2 carried
- `ext/garden-cinderstep-zone-rebased` I6 H5 18cf
- `ext/early-camps-map-ui` I6 H6 15cf +2 carried
- `ext/farm-boki-xp-curve` I6 H6 22cf +1 carried
- `ext/garden-fresh-hour` I6 H6 23cf +5 carried
- `ext/garden-ridge-rebased` I6 H8 39cf +14 carried
- `ext/farm-mood-icons-rebased` I6 H9 36cf +40 carried
- `ext/garden-voice-ambience-rebased` I6 H9 98cf +41 carried
- `ext/boki-gait` I5 H1 4cf
- `ext/clans-roles` I5 H1 2cf
- `ext/clans-weekly-board` I5 H1 2cf
- `ext/egg-hover-1111` I5 H1 2cf
- `ext/extra-grounds-expanse` I5 H1 3cf +1 carried
- `ext/farm-clip-1111` I5 H1 2cf
- `ext/farm-games-picker-base` I5 H1 2cf
- `ext/farm-hand-feed` I5 H1 2cf
- `ext/farm-hatch-name` I5 H1 3cf
- `ext/farm-loot-nudge-card` I5 H1 4cf
- `ext/farm-respec` I5 H1 3cf
- `ext/farm-rival-beats` I5 H1 1cf
- `ext/farm-soak-full-loop` I5 H1 4cf
- `ext/farm-transfer-transport` I5 H1 2cf
- `ext/fold-vfx-vex-1112` I5 H1 3cf +1 carried
- `ext/garden-nap-spots` I5 H1 1cf
- `ext/garden-seasons` I5 H1 1cf
- `ext/garden-sleepovers` I5 H1 2cf
- `ext/hatch-mask-polish-1111` I5 H1 3cf
- `ext/map-clear-1111` I5 H1 2cf
- `ext/ways-out-sim` I5 H1 3cf
- `ext/boki-gait-plant` I5 H2 5cf
- `ext/farm-base-only-breed` I5 H2 8cf
- `ext/farm-boki-pronouns` I5 H2 6cf
- `ext/farm-friend-chase` I5 H2 3cf
- `ext/farm-new-toy` I5 H2 5cf
- `ext/farm-pet-personality` I5 H2 3cf
- `ext/fold-feel-glide-1112` I5 H2 4cf +4 carried

### B23 farm: 25 merges (+7 stacked branches carried), avg impact 4.6/10, avg hard 2.7/10; god-file conflicts: home.gd x14, hunter.gd x1, main.gd x1

- `ext/fold-sfx-boki-1112` I5 H2 8cf +2 carried
- `ext/garden-trait-drift` I5 H2 8cf
- `ext/farm-feed-bowl` I5 H3 5cf
- `ext/farm-garden-default` I5 H3 10cf +1 carried
- `ext/farm-greet-home` I5 H3 5cf
- `ext/farm-incubator-verify` I5 H3 9cf +1 carried after ext/garden-bramble-dupes
- `ext/garden-horizon` I5 H3 14cf +1 carried
- `ext/garden-hub-theme` I5 H3 10cf
- `ext/garden-lantern-match` I5 H3 8cf
- `ext/garden-lantern-zone-hub-rebased` I5 H3 5cf
- `ext/farm-carry-arrival` I5 H4 8cf
- `ext/farm-sick-recover` I5 H4 5cf
- `ext/garden-cinderstep` I5 H4 12cf
- `ext/garden-hub-move` I5 H4 11cf
- `ext/garden-kite-2` I5 H4 13cf
- `ext/garden-zone-cinderstep` I5 H4 13cf
- `ext/kin-type-trail` I5 H4 13cf +2 carried
- `ext/boki-key-c-main` I4 H1 3cf
- `ext/farm-breed-pace-table` I4 H1 4cf
- `ext/farm-toys-joy-tune` I4 H1 3cf
- `ext/farm-unmasked-feet` I4 H1 2cf
- `ext/boki-gait-rekey` I4 H2 7cf
- `ext/farm-carry-boki-trail` I4 H2 4cf
- `ext/farm-carry-trail-0245` I4 H2 4cf
- `ext/farm-arrival-rank-0245` I3 H1 2cf

### B24 misc: 33 merges (+249 stacked branches carried), avg impact 5.9/10, avg hard 4.4/10; god-file conflicts: match.gd x9, home.gd x8, hunter.gd x8

- `ext/fusion-states-fix` I8 H2 5cf
- `ext/levelup-clear-1111` I8 H2 4cf
- `ext/momentum-1111` I8 H2 5cf
- `ext/summon-clips-port` I8 H8 57cf +43 carried
- `ext/pick-relic-1111` I7 H9 32cf +6 carried
- `ext/belt-move-port` I7 H10 56cf +26 carried
- `ext/hires-splash-rotation` I7 H10 57cf +26 carried
- `ext/impact-castlock-port` I7 H10 56cf +27 carried
- `ext/impact-strike-port` I7 H10 58cf +27 carried
- `ext/spike-slam-rebased` I7 H10 200cf +47 carried
- `ext/friendly-bodies` I6 H1 1cf
- `ext/online-displace-reds` I6 H1 2cf +2 carried
- `ext/boss-gate-1111` I6 H2 5cf
- `ext/char-creator-v2-1111` I6 H2 5cf
- `ext/main-checks-registry-b` I6 H2 3cf
- `ext/teach-hold` I6 H3 9cf
- `ext/rename-guin-1112` I6 H7 785cf
- `ext/rename-tessaram-1111` I6 H7 789cf
- `ext/review-design-1110` I6 H7 691cf
- `ext/review-design-1110-fun` I6 H7 689cf
- `ext/reset-cue-rebased` I6 H8 31cf +3 carried
- `ext/land-squash-lean-rebased` I6 H9 39cf +40 carried
- `ext/combo-payoff-audit` I5 H1 4cf +2 carried
- `ext/polish-panel-close` I5 H1 3cf
- `ext/tree-fade-1111` I5 H1 3cf
- `ext/gate-speed-1111` I5 H2 9cf
- `ext/home-dash-one` I5 H2 3cf
- `ext/series-boki-1112` I5 H2 4cf
- `ext/armour-parity` I5 H3 5cf
- `ext/agent-briefs-rebased` I4 H1 1cf
- `ext/skin-relax-four` I4 H1 3cf
- `ext/ostra-gait-rebased` I4 H2 6cf
- `ext/rimewright-skate-rebased` I3 H1 4cf

### B25 docs: 19 merges (+145 stacked branches carried), avg impact 5.2/10, avg hard 3.6/10; god-file conflicts: home.gd x3, match.gd x2, world.gd x1

- `ext/cancel-blend-port` I8 H8 58cf +43 carried
- `ext/select-loading-1111` I7 H1 3cf
- `ext/gil-train-1112` I7 H8 49cf +12 carried
- `ext/react-2-port` I7 H8 69cf +43 carried
- `ext/balance-sim-1111` I6 H2 7cf
- `ext/spike-on-glidespike` I6 H7 29cf +19 carried
- `ext/gil-rework-1111` I5 H1 2cf
- `ext/barrier-block-parity` I5 H2 7cf
- `ext/stairs-smooth-1111` I5 H2 2cf
- `ext/sv-private-1112` I5 H6 29cf
- `ext/docs-kit-parity-names` I5 H6 26cf after ext/sv-private-1112
- `ext/online-dash-sweep` I5 H7 20cf +27 carried
- `ext/load-map-stall` I4 H1 2cf
- `ext/prematch-safe-720` I4 H1 2cf
- `ext/revive-source-numbers` I4 H1 4cf
- `ext/riders-round3` I4 H1 3cf
- `ext/docs-decision-numbers` I4 H2 5cf
- `ext/women-body-1111` I4 H4 18cf
- `ext/ranges-sable-motley-albert` I3 H1 3cf +1 carried

### B26 integ: 35 merges (+1081 stacked branches carried), avg impact 7.1/10, avg hard 8.9/10; god-file conflicts: match.gd x30, home.gd x27, hud.gd x20

- `ext/anim-w0246-blender-rows` I9 H10 58cf +44 carried
- `ext/soul-link-integ-rebased` I9 H10 59cf +21 carried
- `ext/stuck-integ-11014837` I9 H10 265cf +141 carried
- `ext/stuck-integ-a6af81f7` I9 H10 260cf +45 carried
- `ext/ui-w0246-boki-reds` I9 H10 56cf +26 carried
- `ext/feel-input-batch` I8 H5 8cf +2 carried
- `ext/anim-release-sync-meeko-motley` I8 H10 58cf +44 carried
- `ext/combat-w0246-bot-reds` I8 H10 70cf +26 carried
- `ext/farm-w0246-flakes` I8 H10 124cf +19 carried
- `ext/ui-w0246-layout-reds` I8 H10 56cf +26 carried
- `ext/wisp-merge-from-wisp-rebased` I8 H10 48cf +13 carried
- `ext/combat-w0246-support-reds` I7 H10 55cf +27 carried
- `ext/feel-w0246-camera` I7 H10 55cf +27 carried
- `ext/feel-w0246-combo-reds` I7 H10 56cf +28 carried
- `ext/feel-w0246-frame-reds` I7 H10 56cf +27 carried
- `ext/feel-w0246-glide-reds` I7 H10 55cf +27 carried
- `ext/feel-w0246-knock-reds` I7 H10 55cf +27 carried
- `ext/feel-w0246-move-reds` I7 H10 56cf +27 carried
- `ext/garden-integrated-rebased` I7 H10 48cf +13 carried
- `ext/mc-demo-1112` I7 H10 77cf +28 carried
- `ext/mc-fix-1109` I7 H10 21cf +1 carried
- `ext/mc-integ-1112d` I7 H10 119cf +69 carried
- `ext/stuck-integ-42241ff1` I7 H10 182cf +133 carried
- `ext/stuck-integ-606e9a98` I7 H10 107cf +54 carried
- `ext/stuck-integ-86b7d6eb` I7 H10 159cf +115 carried
- `ext/stuck-integ-d2f36c16` I7 H10 78cf +25 carried
- `ext/stuck-integ-f6bd2b7c` I7 H10 91cf +40 carried
- `ext/merge-anim-1111-clips` I6 H3 4cf
- `ext/zone1-batch1` I6 H4 4cf
- `ext/anim-stomp-batch-a` I6 H8 21cf
- `ext/anim-stomp-batch-b` I6 H8 24cf +1 carried
- `ext/integ-ways-out-0245` I6 H9 20cf +1 carried
- `ext/merge-anim-1111` I5 H3 4cf pre-tagged
- `ext/stuck-integ-fb4b4275` I5 H5 14cf +4 carried
- `ext/training-merge-1111` I5 H8 10cf
