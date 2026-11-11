# stuck-integ-e6ae8a2c: the branches merge-candidate kept skipping

Built 2026-11-11 (job 20261111-094525-a3, rpc1) on `ext/stuck-integ-e6ae8a2c`. The base is `ext/mc-20261110-1030`, plus the 10 merges from the earlier run of this job (085524-a1), plus `ext/stuck-integ-42241ff1` 28a4b79ef. That run's 86b base did not parse, and 42241ff1 repairs it.

Dropped, not merged here: every branch that `docs/MERGE_PLAN_0246.md` (ext/merge-plan-0246) assigns to a 0.24.6 wave. Each wave has its own integ job building on release-integ-0245. Those jobs are w0246-feel (wave 1), w0246-combat-a (3), w0246-misc (4, 10, 11, 13), w0246-ui (5), w0246-tutorial (6) and w0246-garden (7, running on rpc1 now), plus the anim, sfx and vfx jobs. Merging the same branches here onto the mc line would mean resolving every conflict a second time, on a base that lacks 0245. Plan rows marked Held, Stale or Superseded are left out as the plan says. The alternative was to merge all 145 remaining branches onto this line; that was not done.

| branch | READY sha | where it is |
|---|---|---|
| `ability-bar-charges` | 82671deed | merged here |
| `agent-briefs-rebased` | 347830615 | plan 0246: Wave 5: ui |
| `agent-briefs` | af480ffa8 | briefs branch, never merged |
| `aim-height` | 3e886ea08 | merged here |
| `air-cast-a` | c5f1e3899 | merged here |
| `air-cast-b` | 0d6243446 | merged here |
| `air-cast-poses` | cf02665e7 | plan 0246: Wave 2: anim |
| `airdash-anims-1108` | 2d9f67946 | plan 0246: Wave 2: anim |
| `albert-parity-verify` | b69c6ca3b | plan 0246: Wave 3: combat |
| `albert-size-boop-rebased` | dc95e0d18 | plan 0246: Wave 3: combat |
| `albert-size-boop` | 3d7539d7b | plan 0246: Superseded |
| `anim-arm-kael` | 7707b024c | merged here |
| `anim-arm-motley` | b450797ad | merged here |
| `anim-arm-sable` | 96fc06cf4 | plan 0246: Wave 2: anim |
| `anim-blend-snap` | e84d7794c | plan 0246: Wave 2: anim |
| `anim-boki-cast` | a9e410abe | plan 0246: Wave 2: anim |
| `anim-boki-home` | 622d926fc | on ext/w0246-feel (running wave job) |
| `anim-boki-idle` | 8a82fd243 | merged here |
| `anim-dash-travel` | bf0ee5b7c | plan 0246: Wave 2: anim |
| `anim-downed` | 44555b467 | plan 0246: Wave 2: anim |
| `anim-foot-plant` | 78034f12e | plan 0246: Wave 2: anim |
| `anim-garden-actions` | 50869956b | on ext/w0246-feel (running wave job) |
| `anim-glide-pose` | 6a1a62f0f | merged here |
| `anim-hand-albert` | 2182efdc5 | plan 0246: Wave 2: anim |
| `anim-hand-tenzo-rebased` | f3e36f0ec | merged here |
| `anim-hand-tenzo` | f44d76294 | merged here |
| `anim-idle-walk-gap-rebased` | bed93d5dc | merged here |
| `anim-jump-land` | 7cf104460 | merged here |
| `anim-key-pose-read` | c2d9b1d83 | plan 0246: Wave 2: anim |
| `anim-mantle-1` | 218d107f8 | plan 0246: Wave 2: anim |
| `anim-mantle-2` | 097e80540 | plan 0246: Wave 2: anim |
| `anim-mantle-3` | c55ef02ea | plan 0246: Wave 2: anim |
| `anim-prop-handoff` | 98b984dd5 | plan 0246: Wave 2: anim |
| `anim-react-2` | 2eea0e098 | plan 0246: Wave 2: anim |
| `anim-react-audit` | 807d9386e | plan 0246: Wave 2: anim |
| `anim-stomp-drink-1` | 26c04bc16 | plan 0246: Wave 2: anim |
| `anim-stomp-drink-2` | 197cb1d63 | plan 0246: Wave 2: anim |
| `anim-stomp-drink-3` | fb4769a73 | plan 0246: Wave 2: anim |
| `anim-stop-start` | 6e24c8d29 | plan 0246: Wave 2: anim |
| `anim-strafe-back` | 5f53bb1ca | plan 0246: Wave 1: feel |
| `anim-time-kael` | bfe9512dc | merged here |
| `armour-parity` | 254af75c8 | plan 0246: Wave 3: combat |
| `arrival-declutter` | f0414bdea | on ext/w0246-feel (running wave job) |
| `art1-clip-port` | 9b9d93216 | plan 0246: Wave 2: anim |
| `art1-kael-2` | fd33d204 | held for the owner (its READY note) |
| `barrier-block-parity` | e77b75102 | plan 0246: Superseded |
| `blight-damage-source` | 894e1f293 | merged here |
| `blight-edge-read` | 08afe2d7b | merged here |
| `boki-downed-pose` | 8a2487d76 | plan 0246: Wave 2: anim |
| `boki-gait` | 7caa9f112 | plan 0246: Wave 2: anim |
| `boki-react-clips` | 5aa0b8d70 | on ext/w0246-misc |
| `boki-state-clips` | 6791e0ddc | on ext/w0246-misc |
| `boki-type-vfx` | 22a8ddb56 | merged here |
| `bot-boki-summon` | f34f48ce5 | merged here |
| `bot-kit-use-b` | a2dc282d1 | merged here |
| `bot-kit-use` | 12d904a0d | merged here |
| `camp-parity` | b761adb77 | plan 0246: Wave 3: combat |
| `cancel-matrix-b` | 107436fd0 | merged here |
| `cancel-matrix-c` | b5679fb88 | merged here |
| `cast-move-a` | d2c555182 | on ext/w0246-feel (running wave job) |
| `checks-out-of-main` | 26941068c | merged here |
| `cinder-sable-polish-rebased` | f3bf0403b | plan 0246: Wave 3: combat |
| `cinder-sable-polish` | 6952af96d | plan 0246: Wave 3: combat |
| `clip-cadence-check` | 9e3438417 | on ext/w0246-ui |
| `combo-marks-b` | 0bd68fb6d | merged here |
| `cooldown-parity-verify` | 2be9877c2 | plan 0246: Wave 3: combat |
| `cooldown-start-parity` | ef38f084b | merged here |
| `creator-polish` | c35dcbe30 | on ext/w0246-ui |
| `creator-trim` | 532aad479 | merged here |
| `cursor-confine` | 0610255d3 | plan 0246: Wave 7: garden |
| `damage-ratio-audit` | a89a84bed | merged here |
| `dash-curves-b` | d7e924199 | merged here |
| `dash-glide-all` | 07957d143 | on ext/w0246-feel (running wave job) |
| `dash-interactions-refresh` | 9577cce44 | merged here |
| `dash-nd-rows-a` | 34fe36678 | merged here |
| `dash-nd-rows-b` | 7b951f8f9 | merged here |
| `docs-heroes-sweep` | 19fb5b69b | merged here |
| `drop-parity` | 8a7cbce24 | plan 0246: Wave 1: feel |
| `duel-ring-online` | 2d6734699 | merged here |
| `edge-knock-parity` | 0286f0cf | merged here |
| `egg-picker-preview` | eeea08d25 | merged here |
| `farm-boki-sex` | e29a16728 | merged here |
| `feel-facing-turn` | d5333f969 | plan 0246: Wave 1: feel |
| `feel-first-cast-warm` | 27d6f01f4 | merged here |
| `feel-hurt-dir-wash` | 984776b91 | merged here |
| `feel-jump-forgive` | 6811e055c | merged here |
| `fight-hitch` | 08712bc58 | plan 0246: Wave 13: misc |
| `fire-on-run-layer` | d733b077b | merged here |
| `first-hints-check` | 123f1800d | merged here |
| `flow-hold-rows` | 125245956 | merged here |
| `flow-rows-source` | dd2c83be5 | merged here |
| `fps-feel` | cbdde0a86 | on ext/w0246-feel (running wave job) |
| `fsm-m1` | be74f3daa | plan 0246: Wave 7: garden |
| `game-rules-nov8` | 14a02c652 | plan 0246: Wave 5: ui |
| `gaps-juggernaut` | b4f362a74 | merged here |
| `gaps-thief` | 61390af6d | merged here |
| `garden-away-card` | b0d474805 | on ext/w0246-feel (running wave job) |
| `garden-baby-parents` | 48888089b | on ext/w0246-feel (running wave job) |
| `garden-base-demo` | 0d6500d04 | on ext/w0246-feel (running wave job) |
| `garden-base-life-main` | ebde0fac5 | on ext/w0246-feel (running wave job) |
| `garden-base-life` | fa2f391bd | merged here |
| `garden-chores` | 1f3b648c1 | merged here |
| `garden-come-look` | 2b6c114d2 | merged here |
| `garden-elder-mentor` | bb12fbcb2 | on ext/w0246-feel (running wave job) |
| `garden-integrated` | 58686d0b6 | on ext/w0246-feel (running wave job) |
| `garden-journal` | a9369b3d6 | on ext/w0246-feel (running wave job) |
| `garden-lean-foods` | fe4476cf3 | on ext/w0246-feel (running wave job) |
| `garden-race` | 248a5e90f | on ext/w0246-feel (running wave job) |
| `garden-seek` | 416ace5e5 | on ext/w0246-feel (running wave job) |
| `garden-snack-patch` | 50d7e539e | on ext/w0246-feel (running wave job) |
| `garden-stump-shove` | 01fff216e | on ext/w0246-feel (running wave job) |
| `garden-train-post` | f7a0c83bd | on ext/w0246-feel (running wave job) |
| `garden-trait-drift` | 04173974a | plan 0246: Wave 7: garden |
| `garden-trust` | c2cf2a8f8 | merged here |
| `garden-volley` | b22001305 | on ext/w0246-feel (running wave job) |
| `glide-cast-rules` | f8f23597f | on ext/w0246-feel (running wave job) |
| `glide-dive-land` | e4081da34 | on ext/w0246-feel (running wave job) |
| `glide-text-fix` | d0a0d906f | merged here |
| `glider-heat-parity` | e8de9552e | plan 0246: Wave 1: feel |
| `grimble-fist-vfx` | 48466a85f | plan 0246: Wave 9: vfx |
| `grimble-hook-arm-v2-rebased` | bac62de38 | merged here |
| `grimble-nose-1109` | 5e98228d5 | plan 0246: Wave 13: misc |
| `grimble-parity-verify` | d94bc7769 | plan 0246: Wave 3: combat |
| `grimble-stretch-v2-rebased` | 88c75bf31 | plan 0246: Wave 13: misc |
| `grimble-stretch-v2` | ba158402c | plan 0246: Wave 13: misc |
| `heal-shield-parity` | 42dced79c | merged here |
| `hero-docs-sync-a` | 40512360c | merged here |
| `hero-docs-sync-b` | 03f75a8fd | merged here |
| `hit-feedback-pass` | d6b86ff8d | on ext/w0246-ui |
| `hit-spark-targets` | 01303bff4 | merged here |
| `hitstop-parity` | c9315676d | plan 0246: Superseded |
| `hot-zone` | 4fd803ae8 | on ext/w0246-feel (running wave job) |
| `hunter-first-hints` | ed9725355 | plan 0246: Wave 6: tutorial |
| `hunter-revamp-af` | fa0c9320b | plan 0246: Wave 3: combat |
| `hunter-revamp-go` | 4efad09ea | plan 0246: Wave 3: combat |
| `hunter-revamp-pz` | fb240baa2 | plan 0246: Wave 3: combat |
| `idle-archer-rebased` | a94bdd7da | plan 0246: Wave 2: anim |
| `idle-archer` | 8437593bb | plan 0246: Wave 2: anim |
| `idle-bulwark-rebased` | ccea3879a | plan 0246: Wave 2: anim |
| `idle-bulwark` | 53c963ec5 | plan 0246: Wave 2: anim |
| `idle-dredge-rebased` | b217d2ec2 | plan 0246: Wave 2: anim |
| `idle-dredge` | b3fdeeeff | plan 0246: Wave 2: anim |
| `idle-gunslinger-rebased` | 4b0767ca7 | plan 0246: Wave 2: anim |
| `idle-gunslinger` | fa16ce7ef | plan 0246: Wave 2: anim |
| `idle-mage-rebased` | 3e4ac3e0d | plan 0246: Wave 2: anim |
| `idle-mage` | 9d6d41c02 | plan 0246: Wave 2: anim |
| `idle-ostra` | 2a99a0912 | plan 0246: Wave 2: anim |
| `idle-tender-rebased` | 8cec53574 | plan 0246: Wave 2: anim |
| `idle-tender` | be19bd8bf | plan 0246: Wave 2: anim |
| `idle-thief-rebased` | 97945e282 | plan 0246: Wave 2: anim |
| `idle-thief` | 619b8dc32 | plan 0246: Wave 2: anim |
| `input-latency-check` | 7618748a5 | merged here |
| `kael-lunge-length` | b4ffaa6ed | merged here |
| `kael-riposte-knock` | bf1f1f2a6 | merged here |
| `kit-error-sweep` | 577c21ec0 | merged here |
| `kit-number-sources` | eb424bbb1 | merged here |
| `kit-parity-refresh-1` | 4791eb5c9 | merged here |
| `kit-parity-refresh-2` | f1efc51af | merged here |
| `kit-parity-rows-a` | a39c3ec6b | merged here |
| `kit-parity-rows-b` | 61200ccc6 | merged here |
| `kit-text-clear-fixes` | d18df02c4 | merged here |
| `kit-text-numbers` | 9cc9fe9ff | merged here |
| `knock-mass-parity` | 294a1ad1e | merged here |
| `lace-hawk-sense` | f67042371 | merged here |
| `lace-playtest-1108` | b79ec35c5 | plan 0246: Wave 7: garden |
| `landing-recovery` | b1927cf07 | plan 0246: Wave 1: feel |
| `legendary-spawns` | a2607c39d | merged here |
| `level-growth-parity` | 051b53e20 | merged here |
| `level-pace` | d0960b1c4 | merged here |
| `lmb-range-parity` | d1aa84b8d | merged here |
| `loot-rarity-vfx` | 2c7798f17 | merged here |
| `map-2x-flat2-rebased` | d200abbfe | on ext/w0246-feel (running wave job) |
| `map-2x-flat2` | 269d12017 | on ext/w0246-feel (running wave job) |
| `mc-fix-1109` | da033386b | plan 0246: Stale |
| `meeko-rmb-motion-rebased-rebased-rebased` | 14f79f40d | plan 0246: Wave 3: combat |
| `meeko-rmb-motion-rebased-rebased` | e5587292a | plan 0246: Wave 3: combat |
| `meeko-rmb-motion-rebased` | d2fa02fa6 | plan 0246: Wave 3: combat |
| `meeko-rmb-motion` | 8801461cc | plan 0246: Superseded |
| `meeko-rmb-verify-rebased` | 7c1762cf5 | plan 0246: Wave 3: combat |
| `meeko-rmb-verify` | eba7147eb | plan 0246: Superseded |
| `menus-more` | e4c3b9694 | plan 0246: Wave 5: ui |
| `misc-ready-integ` | 55446e046 | plan 0246: Wave 10: net/server |
| `motley-seed-fizzle` | 9f521695a | merged here |
| `move-sfx-positional-rebased` | 0e4199c4f | merged here |
| `move-sfx-positional` | 0e4199c4f | merged here |
| `no-dash-bursts-audit-rebased` | 76cd0bbac | on ext/w0246-feel (running wave job) |
| `no-dash-bursts-audit` | 9ef878c5f | on ext/w0246-feel (running wave job) |
| `no-hardcoded-keys` | 41597c5f9 | merged here |
| `no-reload-path` | 94833fb55 | on ext/w0246-ui |
| `online-feel-100ms` | 0bf60cf97 | merged here |
| `ostra-gait-rebased` | b19403935 | plan 0246: Wave 2: anim |
| `ostra-gait` | 89acba32b | plan 0246: Wave 2: anim |
| `overlay-typed-calls` | f2da08d28 | merged here |
| `parity-ability-abyss` | 880f7c907 | merged here |
| `parity-ability-elevation` | 27befb05e | merged here |
| `parity-ability-pierce` | 76de01e1 | merged here |
| `parity-ability-speeds-a` | db9d8235d | merged here |
| `parity-ability-speeds-b` | 1398826f9 | plan 0246: Wave 3: combat |
| `parity-abyss-fall` | d8f415ad7 | plan 0246: Wave 3: combat |
| `parity-ally-effects` | a106b5f15 | merged here |
| `parity-antiheal` | 55a5d0dfc | plan 0246: Wave 3: combat |
| `parity-armour` | ac78146f4 | plan 0246: Wave 3: combat |
| `parity-body-collision` | 81bbacb1a | merged here |
| `parity-bulwark-guardcut` | b2e942eb4 | plan 0246: Wave 10: net/server |
| `parity-cc-lockouts` | 123ec0cb8 | merged here |
| `parity-dot-ticks` | d211db733 | merged here |
| `parity-downed-numbers` | daad5a0f5 | merged here |
| `parity-iframes` | 583b7cfd4 | plan 0246: Wave 3: combat |
| `parity-interrupts-a` | a65a3b102 | merged here |
| `parity-interrupts-b` | 1d8cccab7 | merged here |
| `parity-jump-hold` | 3df495034 | on ext/w0246-feel (running wave job) |
| `parity-jump-pads` | a2715040e | on ext/w0246-feel (running wave job) |
| `parity-kael-clips` | abacc4d18 | plan 0246: Superseded |
| `parity-knock-credit` | 846c1e170 | plan 0246: Wave 3: combat |
| `parity-motley-float` | f48366abc | merged here |
| `parity-no-riders-grimble-tenzo` | 7b130d5c7 | merged here |
| `parity-no-riders-meeko` | 0d6177875 | merged here |
| `parity-passives-a` | 2d4ecc486 | plan 0246: Wave 3: combat |
| `parity-passives-b` | 278596890 | merged here |
| `parity-recast-windows` | bb46589c0 | merged here |
| `parity-reel-a` | 3dad29706 | plan 0246: Wave 3: combat |
| `parity-snowglide-rebased-rebased` | 4a2175eec | plan 0246: Held |
| `parity-snowglide-rebased` | 0e6c6ee69 | plan 0246: Superseded |
| `parity-status-stacking` | bafa3ff4c | plan 0246: Wave 3: combat |
| `particle-budget` | 3d9f8186a | plan 0246: Wave 9: vfx |
| `perf-actors-1108-rebased` | 1fe0f809d | plan 0246: Superseded |
| `perf-fight-pools` | 907d1f4e4 | on ext/w0246-misc |
| `perf-model-drawcalls` | 411b9d481 | plan 0246: Wave 9: vfx |
| `perf-occluders` | 352163646 | merged here |
| `portraits-unified` | 51c79fc89 | superseded by misc-ready-integ |
| `recast-buffer-expired` | 83bed4bc3 | plan 0246: Wave 5: ui |
| `recast-hud-cue` | 1fd9f80fb | merged here |
| `recast-marker-a` | 87df6c5c2 | merged here |
| `recast-marker-b` | 2e37a3309 | plan 0246: Wave 5: ui |
| `recast-sounds` | 82a248d91 | merged here |
| `release-integ-0243-rebased-rebased` | f9a818e77 | plan 0246: Superseded |
| `release-integ-0243-rebased` | 517a0d109 | plan 0246: Superseded |
| `remove-hex` | 16e00c03d | on ext/w0246-feel (running wave job) |
| `reset-cue-rebased` | 0fc62a451 | plan 0246: Wave 3: combat |
| `reset-cue` | 1dd752d4d | plan 0246: Wave 3: combat |
| `revive-source-numbers` | 6c27f4f57 | merged here |
| `rimewright-skate-rebased` | 4012ef0c3 | plan 0246: Wave 2: anim |
| `rimewright-skate` | 9e4710f64 | superseded by rimewright-skate-rebased |
| `sable-marks-resets` | 4061d74e4 | merged here |
| `sable-v2-art` | d8d2fce70 | plan 0246: Wave 3: combat |
| `secondary-motion-settle` | 362c30a08 | merged here |
| `sfx-ambience` | 7012c20f6 | merged here |
| `sfx-belt-items` | 4a9e8d6d7 | plan 0246: Wave 8: sfx |
| `sfx-boki-type-cues` | ebb7c17d6 | plan 0246: Wave 8: sfx |
| `sfx-boki-types` | feedefebb | plan 0246: Wave 8: sfx |
| `sfx-boki-voices` | 9c51f0a8 | merged here |
| `sfx-boki-wire` | dd32b83b4 | merged here |
| `sfx-downed-muffle` | 4d04d2f50 | merged here |
| `sfx-extract-cues` | d8e785a5c | merged here |
| `sfx-fusion-evolve` | 9e270ce2 | plan 0246: Wave 8: sfx |
| `sfx-garden-games` | d5aaad268 | on ext/w0246-feel (running wave job) |
| `sfx-gloves` | ae71a7811 | plan 0246: Wave 8: sfx |
| `sfx-hit-targets` | 03ecb2fcb | merged here |
| `sfx-kit-placeholders` | 7725b94da | plan 0246: Wave 3: combat |
| `sfx-low-hp` | 44dfb9f3f | plan 0246: Wave 8: sfx |
| `sfx-mix-pass` | 0591bb141 | plan 0246: Wave 8: sfx |
| `sfx-mob-alert` | 30e6a701c | merged here |
| `sfx-move-weight` | 366c29d3f | on ext/w0246-feel (running wave job) |
| `sfx-pickups-gloves` | d9a23794f | plan 0246: Wave 8: sfx |
| `sfx-pickups` | 0bb0bffab | merged here |
| `sfx-step-surfaces` | 92976bde2 | merged here |
| `sfx-strike-sync` | 61619d99d | merged here |
| `sfx-warnings-boki` | 83bb59a92 | merged here |
| `sfx-weapon-fire` | 0efbf33a2 | merged here |
| `sfx-wisps` | 6baa2d6b7 | merged here |
| `shadow-renames-arch` | 17737fb9f | merged here |
| `side-cue-telegraphs` | 11f0ce0bf | plan 0246: Wave 9: vfx |
| `slam-follow-through` | 95a835c7e | plan 0246: Wave 3: combat |
| `snag-audit` | 0ea717354 | merged here |
| `sneak-speed-source` | 178d0d384 | on ext/w0246-misc |
| `split-exits` | 3687cf511 | merged here |
| `split-kmoves-pin-bjorn` | 89302ce30 | merged here |
| `split-lairs` | 1605c9185 | merged here |
| `split-models` | fc0129e7d | plan 0246: Wave 9: vfx |
| `split-ui` | be393e41d | plan 0246: Wave 5: ui |
| `split-warden-glb` | cdad2bfe4 | merged here |
| `status-body-looks` | bfddc6570 | plan 0246: Wave 9: vfx |
| `status-net-check` | 8051a4361 | merged here |
| `step-smooth` | 0a96e4b98 | on ext/w0246-misc |
| `strike-reach-heights` | 75a9a854e | plan 0246: Wave 2: anim |
| `stuck-integ-950a5444` | c3b547945 | plan 0246: Wave 7: garden |
| `stuck-integ-cb5c1c27` | da83863db | plan 0246: Wave 7: garden |
| `stuck-integ-e2561d23` | 7e87fcf67 | plan 0246: Superseded |
| `stuck-integ-e28956f8` | 73b2cdcee | plan 0246: Wave 7: garden |
| `supervive-impact` | ac32fb465 | plan 0246: Superseded |
| `telegraph-audit-c-rebased` | 32742080e | plan 0246: Wave 13: misc |
| `telegraph-audit-c` | 498b60d09 | plan 0246: Wave 13: misc |
| `telegraph-one-system` | f24474927 | merged here |
| `tender-gait-rebased` | cdeada2b2 | merged here |
| `tenzo-cone-grow` | dafcc39dc | merged here |
| `tenzo-playtest-1108` | - | superseded by stuck-integ-d4379965 |
| `train-rank-controls` | ca6395264 | merged here |
| `tut-skip-check` | f617c7e8e | plan 0246: Wave 6: tutorial |
| `tut-start-here` | 5bf8865de | plan 0246: Wave 6: tutorial |
| `tut-try-relic` | 0a05c817e | merged here |
| `tutorial-beats-5-6` | d844c0aed | plan 0246: Superseded |
| `tutorial-garden-4` | b67e1bc66 | on ext/w0246-feel (running wave job) |
| `tutorial-idle-check` | 19a355ea6 | plan 0246: Wave 6: tutorial |
| `ui-ability-text-one` | 603d2e4af | plan 0246: Wave 3: combat |
| `ui-base-hud` | 467239ce8 | plan 0246: Wave 7: garden |
| `ui-boki-box-summon` | b5c1b6fa1 | merged here |
| `ui-death-recap` | 82d663574 | merged here |
| `ui-dex-summon-row` | 510395653 | merged here |
| `ui-extract-widget` | 67842fb47 | merged here |
| `ui-gear-reveal` | fbbb0f062 | merged here |
| `ui-knock-callout` | 154328e01 | on ext/w0246-ui |
| `ui-loot-panel` | 1121df7ce | merged here |
| `ui-minimap-declutter` | e59334cb2 | on ext/w0246-feel (running wave job) |
| `ui-safe-area` | a75769391 | merged here |
| `ui-settings-trim` | 789776b43 | plan 0246: Wave 5: ui |
| `ui-sfx-set` | 8661028ec | plan 0246: Wave 8: sfx |
| `ult-ranks` | a48ec55a0 | plan 0246: Wave 3: combat |
| `utilities-shops-rebased` | f8af39fa2 | on ext/w0246-ui |
| `utilities-shops` | e94360ee6 | on ext/w0246-ui |
| `utility-parity` | df96e53c3 | on ext/w0246-ui |
| `vex-coin-palm-1108` | 0478765f6 | plan 0246: Wave 3: combat |
| `vex-greenfire-1108` | 4e67fbbfc | plan 0246: Wave 3: combat |
| `vfx-armour-break` | 5123a0898 | plan 0246: Wave 9: vfx |
| `vfx-dredge` | 794ca0e37 | plan 0246: Wave 9: vfx |
| `vfx-evolve-moment` | 0307b4627 | plan 0246: Wave 9: vfx |
| `vfx-fusion-event` | 323211c75 | merged here |
| `vfx-gunslinger-strips` | 516916a3f | shots only, not for merge |
| `vfx-lace-impact` | 2199382e1 | merged here |
| `vfx-lowpreset-read` | e0dc73584 | plan 0246: Wave 9: vfx |
| `vfx-meeko-kindle` | 2a9130278 | merged here |
| `vfx-meeko-weight` | 9c4ad7800 | plan 0246: Wave 3: combat |
| `vfx-motley-nightwell` | a7c31da62 | plan 0246: Wave 3: combat |
| `vfx-neve-crash` | 23d171858 | plan 0246: Wave 9: vfx |
| `vfx-origin-v2-rebased` | 82998a018 | plan 0246: Wave 2: anim |
| `vfx-origin-v2` | 53e5acdc4 | plan 0246: Wave 2: anim |
| `vfx-pass` | b7d8bf3c0 | plan 0246: Wave 2: anim |
| `vfx-quality-motley` | 06b960779 | plan 0246: Wave 3: combat |
| `vfx-rescore` | 13b167304 | merged here |
| `vfx-tenzo-impacts` | 7b34673dc | plan 0246: Wave 9: vfx |
| `warden-bob-damp-rebased` | 92882bf31 | merged here |
| `wisp-guardian` | a75873697 | plan 0246: Superseded |
| `wisp-summon-pop` | a9f367d43 | on ext/w0246-misc |
