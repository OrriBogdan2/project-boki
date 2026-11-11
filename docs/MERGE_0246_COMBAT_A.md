# 0.24.6 wave combat-a (Wave 3, first 85 of docs/MERGE_PLAN_0246.md)

Branch ext/w0246-combat-a from ext/release-integ-0245 92df78ce4. Merged 70 (2 partly; ext/mob-design-1109 came with ext/mob-boss-sheets), held 10, superseded 5. Net.VERSION not bumped: ext/combat-xp-last-hit and ext/kael-riposte-knock change the sync shape, so the combine must bump it.

## Held

- `ext/albert-size-boop-rebased`: brings merge candidate mc-20261109-0503 (687 files) and 13 conflicted files/21 hunks + breaker.glb against the Albert appeal model already in 0.24.5; needs a rebase onto the appeal rig (also carried by ext/reset-cue-rebased, wave 7)
- `ext/combat-bots-downed`: tip 56abc8085 merges ext/soul-link-integ-rebased (INTEG T2 + merge candidate mc-20261110-0630: 1,605 commits, 1,598 files, 44 conflicted files); merged only its own bot commit 6ed22f37c (revive safety, Meeko carries, --bot-downed-check). The wisp-grab and enemy-area-rim parts land with soul-link-integ-rebased (wave 7)
- `ext/combat-summon-share`: stacked on ext/soul-link-integ-rebased (INTEG T2 + merge candidate mc-20261110-0630) and ext/ttk-matrix-rebased: 2,292 commits not on 0.24.5, 50 conflicted files. Its own commit ef71de124 (--summon-share-check, decision 0043) needs the soul-link summon line; merge after soul-link-integ-rebased (wave 7)
- `ext/cooldown-parity-verify`: sets every kit's cooldowns to 1.0x source (11-08/09); the line has the kits at 0.8x of data and the later rank parity (ext/combat-ranks-a/b/c, 11-10, merged here) and its checks build on those numbers (Knife 15 -> 10.7, Meteor 7.2 s, Warchain 12.8 s). Conflicts in 6 kit JSONs + dancer_jug_check: needs an owner call on the cooldown scale, then a rebase
- `ext/grimble-parity-verify`: Grimble cooldowns to the data's level 1 (hand 18 s, anchor 12 s): the same 1.0x-vs-0.8x cooldown call as ext/cooldown-parity-verify, and the line's newer Abyssal Hand wind-up / Anchor hop and rank texts conflict in dredge.json
- `ext/hunter-revamp-af`: binary model conflicts (glb + atlases, 16 files: breaker, cinder, claire, dredge) against the appeal/v95 model swaps already on 0.24.5; the retopos are of the older shipped scans, so it needs an art pick per hero (redo on the current models or drop)
- `ext/hunter-revamp-go`: same as revamp-af for hem, kael, ostra (12 binary conflicts)
- `ext/hunter-revamp-pz-rebased`: same for breaker, hem, pip, ryzz, sable, tarek, vex (33 conflicts, incl. audio/ways_warn.wav)
- `ext/kael-tap-ult-1108`: Kael tap strike + ult momentum (11-09) is built on the older Finishing Slam lane and a new Tuning "kael" reader; the line's Kael (cone Slam with a pinned aim, chain_deg lunge from ext/kael-rmb-unlock 11-10) conflicts in 3 juggernaut_kit hunks and tuning.json has a new shape (Loco). The auto-merge leaves a hybrid slam; needs a rebase by the Kael lane (also carried by ext/anim-arm-kael, wave 2)
- `ext/kit-parity-rows-a`: its new parity rows hold the kits at 1.0x source (cooldowns, damage ratios): 26 rows FAIL against the line's 0.8x kits; the same owner call as ext/cooldown-parity-verify, merge together after it
- `ext/combat-lace-wallclimb`: test + docs only: its --archer-combo-check assert "Lace climbs a double wall (4 terraces)" fails on the line (she tops out at the first terrace; climb_tall is not on 0.24.5). Merge with or after the branch that builds the tall climb

## Superseded

- `ext/cinder-sable-polish-rebased`: polishes the v2 Sable glb/atlas/paint scripts; 0.24.5 already swapped Sable to the owner's appeal3 v95 body (afc5a905e)
- `ext/armour-parity`: the 11-09 first armour parity pass (ArmorRules + armor.json); ext/combat-armour-xp (11-11, same wave) rebuilds the same tiers with ArmorXp thresholds, taken-damage levelling and Grimble's armor_k, and the two conflict in hunter.gd/armor_hud/equal_check
- `ext/body-hitbox-parity-rebased`: 11-08 hit_r parity table; ext/combat-hurtbox-parity (11-10, same wave) sets every Hunter's hit radius and height from the height chart with body collision separate, on the same JSON rows and checks
- `ext/combat-knock-resets`: owner item 159 (game-wide knock dash refresh with assists, kit duplicates out) is already on 0.24.5 as 398f4a9c5 DashReset + decision 0022-knock-dash-refresh-assists; its other DashReset/assist design conflicts in 6 files. Not carried: the per-hero audit docs/KNOCK_RESETS.md and --knock-reset-check (would need porting to the merged DashReset)
- `ext/kael-rmb-unlock-rebased`: its own work (ext/kael-rmb-unlock 44f5a64dc) is already on 0.24.5; the tip only adds a merge of merge candidate mc-20261110-1030 (2,700 commits, 111 conflicts) and a parse fix for that merge

## Resolution calls

- combat-ranks-a: kept owner 11-08 Rink Wall 200 HP over the source 70 (+40 at rank 3 kept)
- combat-xp-last-hit changes the sync shape (net.gd + an xp field): the final combine must bump Net.VERSION
- kael-lunge-length-rebased-rebased: merged its own commits to 00894cd16; the tip's sync merge of merge candidate mc-20261110-0630 (2,240 commits) left out
- kael-riposte-knock touches net.gd (hit extra 'box'): VERSION bump at the combine
- kael-lunge: Rampage stays on the owner item 113.8 (4.5 m / 0.17 s, x0.85/x1.15 feel, --move-feel-check) over the branch's footage gap 6 (3.6 m / 0.2 s, feel 1.0); its Lunge 5.4 m kept
- ext/combat-hurtbox-parity's hit radii and heights win over ext/body-hitbox-parity-rebased's; ext/combat-armour-xp's ArmorXp wins over ext/armour-parity; ext/combat-lace-spirit-ledges' pass-through Spirit Walk wins over the older climb; ext/combat-levelup-refill retires WeaponPath and keeps ext/combat-level-growth's straight lines.

## Checks

61 checks that the merged branches add or touch, run one at a time (headless, LP_NUM_THREADS=2); every red was rerun on release-integ-0245. health.py --strict OK. suite-fast.sh is not on rpc7.

- Red on 0.24.5 too (not counted): --bot-kit-use, --drop-feel-check, --music-leave-check, --ttk-check, --warden-clips-check, --warden-model-check.
- NEW-RED (9, not fixed): --bot-downed-check and --bot-summon-check (bot Summon/downed play without the held soul-link line), --camp-check (a mob home again does not notice a Hunter at 4 m), --mob-cc-check (Burrseed root on a Hunter control), --mob-tell-check (spitter tell vs hit shape, 1 of 6 probes), --swept-hit-check (Motley dash misses at 12 m), --kit-sweep-check (engine polygon error from ui_torn during Neve LMB), --mage-combo-check (Storm Rod 24 damage, was 39), --ostra-combo-check (rank-3 seed burn 15 over 1.2 s, wants ~10).
