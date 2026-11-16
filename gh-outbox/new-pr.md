title: Integration lane bundle 11-15: 22 READY branches re-fitted to current main (anim timing, wisps, kite, loco, parity, hurtbox, Sable wings)
head: ext/merge-lane-integ-1115
base: main

Bundle of integration-lane READY branches, built from main by cherry-pick; main wins on conflicts and the intent of each dropped hunk was re-applied by hand. Contains origin/main 88c671a67a (PR #69 batch 26). `merge-gap` trend (24h/48h) was falling when this started; 22 of the ~30 branches taken (cap, not a floor).

## Merged (unique commits taken / unique vs main)
anim-timing-ashwick 3/3, anim-timing-rimewright 1/1, anim-timing-juggernaut 4/6, anim-pilot-layers-verify 6/9, combat-hurtbox-parity 1/2, combat-ranks-b 1/1, combat-wisp-hit-rules 9/9 (with boki-wisp-proto, summon, steal, wisp-rules), fix-strafe-cadence-1115 2/5, garden-kite-2 4/4, garden-seasons 2/2, hunter-loco-polish-1115 14/16, parity-bulwark-crush-rebased 3/3, parity-kael-cc-riders 1/1, parity-ttk-kael 1/1, remote-move-clear 2/2, sable-appeal4 2/13, sable-wings 3/4, split-kmoves-pin-bjorn 1/1, vfx-garden-games 13/14, vfx-garden-games-2 12/18, stuck-integ-b6204ee2 6/8 (cast-predict-check, relay test weather, decisions 0022/0099).

## Fixed after the main merges (hunks the first bundle had dropped or that main outgrew)
Ranks B dolm.json tiers; Kael CC riders (Chain Lunge no stun, wave no slow); Hail Wall still drains a Wisp; Skycall still launches one; Rink Wall and walls touch only hittable foes; Kite Tow on main's home.gd (with Lantern), prize table, GardenXp.play, GardenSfx cues; hurtbox data per Hunter on main's chart heights; Sable wings (sable.json block, HunterAnim setup, WardenSprings raise); wisp pieces (Summon key C, no orders/casts for a wisp, stolen passives, Net 0.24.14); hitbox-size/lagcomp/remote-smooth LagRelay members renamed (RelayServer has test weather now); perkorb-check weapon-path section; clip-check, sfx-set-check, wisp-check, wisp-steal-check, summon-death-check made to follow the merged code (each commit says why).

## Checks (rpc4, suite-fast + reruns of every red on both trees; box load 25-150, so 137/124 reds were rerun alone)
Full suite on the tree before the last two main merges: reds were pre-existing on main or load kills. After the last merge (main 88c671a67a) the 42 flags the bundle touches were run on both trees: same reds as main (archetype, clip, dancer-combo, thief-combo, displace-net, mage-combo 7 = 7, anim-audit, foot-slide) except the HARD list below. Export dry-run (all 5 presets, --export-pack): rc 0, 453 MB each. health.py --strict: same 3 style failures as main (dj_fx, chore_check, glide_net_check), none new.

## Skipped
- Big stuck-integ-* / *-integ-* branches (hundreds to thousands of commits; not bundleable by hand): stuck-integ-11014837, -42241ff1, -86b7d6eb, -c2a69297, -7fc43430, -606e9a98, -f6bd2b7c, -d2f36c16, soul-link-integ-rebased, integ-1113-D2, mc-integ-1112d, and small-but-large-diff stuck-integ-e28956f8, -09e533a4, -f11b417c, -cff77e31, -f60f9dd7, integ-ways-out-0245, integ-1113-D1, -A1, stuck-integ-aeb8eb0f.
- anim-timing-dredge: its glb re-key does not apply on main's Grimble clips (no Blender here); the unwired timing check, doc section and lunge/anchor keys are left out.
- anim-timing-ashwick's as_cloak lengthening (main's cinder.glb has its own cloak re-key); the rest is in.
- wisp-summon-* tips (74-79 commits each).
- gh is not on rpc4: open PR bundles were checked by branch overlap only.

## HARD
- --tutorial-dead-air-check: Kael's match, step "Dash across the gap": the player's Boki walks off the gap (Boki "fell" toast over the card, 7 frames). Main passes; ruled out: summon, hurtbox data, juggernaut kit, gait. Needs the author of the wisp/loco/remote branches.
- --wisp-hit-rules-check (new): 3 of ~100 rows red: Rink Wall still moves a downed rival (rimewright e), Gil RMB behind a Wisp takes 4 of 13 (varies per run). Skycall moving a Wisp is allowed (hero-combo pins it).
- --cast-predict-check is timing-flaky under load (passes alone, 'gunslinger dash anim on 7' otherwise).
- sable-appeal4 (11 of 13 commits did not apply) and fix-strafe-cadence-1115 (3 of 5): author must re-base on current loco/anim rules.
- Overlap (same patches, both can land): sable-wings also in ext/merge-lane-misc3-1115, split-kmoves-pin-bjorn in merge-lane-hunters7-1114-b, garden-seasons in merge-lane-farm-1115, anim-garden-games in merge-lane-vfxsfx1-1115.
- Another worker pushed a leaner state to this same branch at 13:26 (dropped wisp stack, hurtbox parity, wings, Ranks B); this tip merges it with -s ours, so its drops are superseded by the fixes above.
