# 0.24.6 wave misc (ext/w0246-misc)

Scope from docs/MERGE_PLAN_0246.md (ext/merge-plan-0246): Wave 4 boki (19), Wave 10 net/server (7), Wave 11 perf (7),
Wave 13 misc (31), 64 rows. The merges were done by job 20261111-064813-a5 (no report) on ext/release-integ-0245
92df78ce4; ext/w0246-audit-fix-misc added four audit fixes on top (BokiRig parses, Kin's on_you, Gil's telegraphs on
AimKit, telegraph-audit-b's ring cuts). Job 20261111-130024-a1 took that branch, sorted the 21 rows left and ran the
checks. The base has since moved to 272368589 (hero garden clips, meeko orbit, garden-zone draws, the 0.24.5 check
fixes); it is merged in (world.gd: FarRanges keeps the scatter, plus the base's scatter_chunk floor). Net.VERSION is not bumped here (the combine does it); the merged
net-rejoin, status-net, wisp-summon-net, wisp-cosmetics and wisp-pve-pvp change the sync shape.

## Counts

Merged 49, carried 1, superseded 5, held 9.

- Merged at the plan sha (43): everything in the four waves not listed below.
- Merged at the pre-rebase tip (6): wisp-merge-from-wisp b390a22d8, wisp-passive-stack e293ad7ce, wisp-summon-leash
  3c8ebb0c7, wisp-summon-net 5d4c33fc6 (each -rebased tip drags in mc-20261110-0630), and summon-killed-wisp
  25e86351f, wisp-steal 1e433f875 (inside the merged wisp line).
- Carried by ext/w0246-anim (1): wisp-guardian-rebased-rebased (its pre-rebase acacda191 is in w0246-anim).

## Superseded (5)

| Branch | Why |
|---|---|
| ext/grimble-nose-1109 5e98228d5 | 0245 swapped Grimble to the v95 master (449680294, 466f2d6ec); the nose belongs to the old v2 head |
| ext/grimble-stretch-v2-rebased 88c75bf31 | same v95 swap; 0245's d6e54648c already relaxes the skin and has --stretch-check |
| ext/split-exits 3687cf511 | 0245's Ways Out rework already took exits.gd from 1025 to 595 lines (exit_models, exit_signal) |
| ext/level-pace d0960b1c4 | decision 0048 (early-camps-core): XP is a kill reward from content/rules/xp.json; the time/damage gains it tuned are gone |
| ext/rank-paths-fit 18b081c64 | 0245 has per-kit rank_cd / rank_dmg tables in the kit JSON (archer dash 9.5 -> 8.5 -> 7.5 s, the same -1 s twice) |

## Held (9)

| Branch | Why |
|---|---|
| ext/perf-owner-hw 546cce212 | built on 0244 and 0245 already re-did the same hot spots its own way: DropMerge's gem pool vs gem_pool, SimLod.step_dt vs HunterPace, camps-core vs _spawn_mobs, cached-line bot steering vs replan_s, guarded camps in spawn_plan vs the share scheduler. 43 hunks in 14 files. Needs a port job that keeps one version of each and measures again. Worth porting: layered WarmUp, AnimLod, World.los one-read, gear_stat cache, far-bot beat |
| ext/perf-train-0245 3a49c8144 | inside perf-owner-hw; held with it |
| ext/fight-hitch 08712bc58 | inside perf-owner-hw; held with it |
| ext/expedition-fps-1108 62ad7d14f | inside perf-owner-hw; held with it |
| ext/telegraph-audit-c-rebased 32742080e | 0245 redrew the same telegraphs another way (vfx "swing" ring for the 360 Smash, thin AimKit rings with RING_W for Sable's ult); 10 files, 19 hunks of the same visuals. Port the Motley/Sable/Mossy/Sparkle drawn==hit rows onto 0245's code |
| ext/misc-ready-integ 55446e046 | an 11-08 integ: 29 conflicts, mostly binary portraits plus Training Grounds, NPC dialogue, Lace 2 charges and the Bulwark Guard cut, none of which is in 0245. Owner picks first (tutorial wave held the Training Area line too) |
| ext/wisp-gpu-ab-rebased e08c6817e | carries the soul-link integ line (KinNet index renumbering, Net 0.31.0, killed-summon flight home) under a 3-commit A/B bench. Merge after the combine, with soul-link-integ |
| ext/early-wisp-refund e0d1fbba6 | stacked on ext/soul-link-integ 3303c3b45, which no wave merges ("do not merge alone") |
| ext/landing-recovery b1927cf07 | stacked on drop-parity (in w0246-combat-a) and parity-jump-pads (in w0246-feel); merging it here would pull both into this wave. Merge at the combine, after both |

## Fixes on the merged tree

- zone1-batch1's six new kin (lunink, eclipsowl, gloamspire, seamwyrm, umbrink, chandelapi) take moon_mark, as 0245
  did for the rest; they failed grammar, so Data.KIN lacked them and new_kin threw wherever a zone pool rolled one
  (camps, demo-quick, status-net, drop-merge, snag, summon checks).
- BokiRig loops only the clips its glb has (LOOPED gained sulk/push); --boki-state-check's nap row expects settle first.
- Frostgate and Cinder heavy camps moved off 0245's uplink outposts (7.9 m, rule 20) and the Keep vault, a boulder for
  cover; map regenerated (only those islands' camps, bushes and one rock change). --camp-layout-check skips the
  docks/hatches Ways Out removed (it threw and hung).
- squad-intro-check reads DropFeel.plan_s; loading-check counts every Hunter (13); clip_check's floating-companion rule back.

## Checks (headless, one Godot at a time; a chosen set, not the full 246-check suite)

health --strict OK, gen_wiki --check OK, --check 0, --grammar-check 0. The 26 checks the merges added plus boki-rig, wisp,
air-limits, clip, dolm-combo, perf-throttle, cover. Green: check, grammar, clip, boki-cries, boki-state, camp-layout, camps,
clan, far-ranges, kin-form, mantle-press, passive-stack, rejoin, snag, squad-intro, status-net, step-smooth, summon-death,
summon-leash, summon-net, ttk-matrix, wisp-cosmetic, wisp-rules, wisp-steal, zone-pool, wisp, air-limits, dolm-combo,
drop-merge.

NEW-RED vs ext/release-integ-0245 272368589 (6):

| Check | Why |
|---|---|
| --boki-rig-check | caecilith, lilybara, umbrathere glbs have no win/sulk/push, which boki-react-clips now asks of every species (base passes: it did not ask). Blender rebuild (not on rpc6) |
| --perf-throttle-check | two rows perf-occluders/perf-fight-pools added: an occluder corner below an island's underside on the 2x map; the Fx flurry leaves one node. FIXED on ext/perf-occluder-pool-rows (stacked on this branch): the box bottom skipped a stair tile at a box corner (stairs are island ground in the terrain mesh); bolt() draws its 5 segments as beams since this merge (10 quads a bolt, bolt_pool gone) but beam_pool warmed 8, so a flurry built 26 beam nodes (now BEAM_WARM 40); the row compares nodes, not the count (a telegraph from the earlier match steps ends in the window) |
| --cover-check | Lark (meadow) cover 7.8-8.0%, floor 8.5%: the early-camps layout moves cut Lark's bushes 874 -> 741 |
| --demo-quick-check (new) | "every Boki evolved" short 6: 0245's evolve.json levels 14-40 with an art gate (DEBT: no launch species level-evolves) |
| --loading-check (new) | the bar jumps more than 25% in one frame once |
| --leave-match-check (new, hangs to timeout) | expects a Boki left in a deep match to be in the Ransom House at once; 0245 has it guard your box first |

Not in the chosen set: --merge-form-check fails 2 on f23d91db7 (and the same 2 with the fix above): "says 'Rescue
Gravadillo to fuse'" and "a tick ring each second" (it waits for the Fx child count to rise; rings are pooled since
perf-fight-pools, so a ring adds no node).
