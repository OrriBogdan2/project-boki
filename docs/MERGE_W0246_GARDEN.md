# 0.24.6 wave 7 (garden): merge log

Branch ext/w0246-garden, from ext/release-integ-0245 92df78ce4, plan docs/MERGE_PLAN_0246.md (ext/merge-plan-0246), job 20261111-082512-a3 on rpc1.
Net.VERSION untouched (the final combine bumps it). Save stays v13: sleepovers and clans ride 0245's v12/v13 steps keyed by their own fields.

## Merged (34)

- `ext/garden-decor-tags`: clean
- `ext/garden-hub-perf0`: clean
- `ext/spec-chao-core-garden`: clean
- `ext/sfx-loot-open`: auto
- `ext/anim-garden-games`: manual (game gaits onto per-species STRIDE)
- `ext/cursor-confine`: manual
- `ext/extra-grounds-expanse`: manual (kept 0245 Training Grounds name)
- `ext/farm-boki-sex-rebased`: manual (_scene takes the path)
- `ext/farm-food-journal`: manual (on 0245 lean feeding)
- `ext/farm-home-hatch`: manual
- `ext/farm-homecoming`: manual
- `ext/farm-mood-icons`: manual
- `ext/farm-stat-causes`: manual (ported onto StatBudgetView)
- `ext/fsm-m1`: manual
- `ext/garden-kite-1`: manual (kite in 0245's games list)
- `ext/garden-kite-2`: manual
- `ext/garden-lantern-match`: manual (in games list; input stub)
- `ext/garden-path-meter`: manual
- `ext/garden-ridge`: manual (ported to 0245 zone build: ridge build entry, tracks with 0245 pace, relay on stretches())
- `ext/garden-rivals`: via ext/garden-tag
- `ext/garden-seasons`: manual
- `ext/garden-sleepovers`: manual (sleepovers ride v13; no second bump)
- `ext/garden-tag`: manual (BaseBoard reads MinigameHub results; no double record)
- `ext/garden-voice-ambience-rebased`: via its original ea25128ea (+ ext/sfx-boki-voices 9c51f0a84, ext/sfx-boki-wire dd32b83b4); the -rebased tip's 405870580 (voices for the candidate's caecilith/lilybara/umbrathere) left for after the merge candidate lands
- `ext/no-hardcoded-keys`: manual
- `ext/reset-cue-rebased`: via its original 1dd752d4d (ResetCue; 0245's Bulwark spent-only cue kept)
- `ext/sfx-hatch`: manual
- `ext/solo-drop-20261109-2319`: manual
- `ext/tut-first-breed`: manual (FirstBreed on NookRules.preview; NookPreview dropped as dup)
- `ext/ui-base-hud`: manual (BaseHud fed from ZoneAway.card)
- `ext/vfx-garden-games`: via ext/vfx-garden-games-2
- `ext/vfx-garden-games-2`: manual (cues beside 0245 GardenSfx)
- `ext/clans-slice-2`: manual (+ ext/clans-slice-1 f76a9e117; clan migration keyed into 0245's v12 step)
- `ext/garden-save-trip`: via ext/garden-tag (snack patch RIPE_KEY kept)

## Carried (inside a branch of another wave: it arrives with that one, not merged here) (16)

- `ext/duel-ring-online`: in `ext/tut-duel-ring` (wave 6)
- `ext/extra-photo-mode`: in `ext/feel-dash-off-ledge-rebased` (wave 1)
- `ext/farm-tut-batch-1108`: in `ext/anim-boki-cast-rebased` (wave 2)
- `ext/farm-tut-batch-1108-deep`: in `ext/anim-timing-gunslinger` (wave 2)
- `ext/farm-tut-tools-cam-rebased`: in `ext/anim-timing-gunslinger` (wave 2)
- `ext/garden-burrow-swap`: in `ext/anim-boki-cast-rebased` (wave 2)
- `ext/no-rolling-rebased`: in `ext/anim-timing-gunslinger` (wave 2)
- `ext/soul-link-integ-rebased`: in `ext/combat-bots-downed` (wave 3)
- `ext/stuck-integ-950a5444`: in `ext/anim-timing-gunslinger` (wave 2)
- `ext/stuck-integ-b7a5717c`: in `ext/meeko-root-rebased` (wave 3)
- `ext/stuck-integ-cb5c1c27`: in `ext/albert-size-boop-rebased` (wave 3)
- `ext/stuck-integ-e28956f8`: in `ext/albert-size-boop-rebased` (wave 3)
- `ext/train-moving-dummies-rebased`: in `ext/anim-boki-cast-rebased` (wave 2)
- `ext/trios-10x3-1108`: in `ext/anim-timing-gunslinger` (wave 2)
- `ext/types-standard-names-rebased`: in `ext/anim-timing-gunslinger` (wave 2)
- `ext/util-tonic-lamp`: in `ext/feel-utility-move` (wave 1)

## Superseded (12)

- `ext/farm-carry-boki`: (duplicates HomeCarry/--carry-boki-check already in 0245, 81dfabfcc)
- `ext/garden-cinderstep`: (0245 has its own Cinderstep 7b via ext/garden-hub-horizon: 3bfc9080b..305608ff4)
- `ext/garden-horizon`: (0245 has Hub horizon step 9 d61af373f..892050f70 via ext/garden-hub-horizon)
- `ext/garden-hub-theme`: (its Glasswater 7a is in 0245 as b8ce4816e/45f3db5ae; its ridge part merged via ext/garden-ridge)
- `ext/garden-integrated-rebased`: (ext/garden-integrated 58686d0b6 already in 0245; the rest is merge candidate mc-20261110-0630 + its fixups, which wave 1-3 -rebased branches carry)
- `ext/garden-nav-sweep-rebased`: (ext/garden-nav-sweep d583ba443 already in 0245; rest = mc-20261110-0630)
- `ext/garden-trait-drift`: (same commit re-applied in 0245: 6446c5990)
- `ext/garden-unlock`: (0245 has Garden zones step 6 Wayseeds fdb43f91a)
- `ext/grimble-hook-arm-v2-rebased`: (ext/grimble-hook-arm-v2 315cdf2af already in 0245; own commit = wiki regen only)
- `ext/sfx-garden-games-rebased`: (ext/sfx-garden-games d5aaad268 already in 0245; rest = mc-20261110-0630)
- `ext/tut-garden-first-day-rebased`: (ext/tut-garden-first-day 71eb276c0 already in 0245; rest = mc candidate)
- `ext/garden-snacks-all-types`: (snacks commit already in 0245 as 230fa6cc3; ridge part merged via ext/garden-ridge)

## Held (10)

- `ext/farm-feed-bowl`: (own bowl FSM + Evo.food_lean collide with 0245 BaseFeed/BaseLife Eat and the Evo.eat lean rewrite; needs a port onto BaseLife Eat, >30 min)
- `ext/farm-sick-recover`: (bundles a 2nd no-natural-death system: neglect.json + Econ.revive_neglected revives starved graves, vs 0245 care.json natural_death/starve_cap keeping graves; needs a design pick and a port of the nap/friend/Puffcorn recovery onto 0245 Care); PORTED as ext/farm-sick-recover-port: care.json stays the one system (natural_death false, DECISIONS 2026-11-08), neglect.json, Econ.revive_neglected and --neglect-check dropped; Care.RECOVER_FED/NAP/FRIEND, KinAiling.friend_near, the Puffcorn cure and --sick-recover-check carried. Not carried: the droop/slow-walk/perk-up look (KinAiling.pose/perk_up, Care.pace)
- `ext/garden-lantern-zone`: (contained in ext/garden-lantern-zone-hub, same reason)
- `ext/garden-lantern-zone-hub`: (Hushwood is built on ZoneLook = Save zones[id].layout + "look" data, a second zone-island system beside 0245's ZoneLayout/ZoneDress "build"; needs a port: hushwood build entry + moss/motes in ZoneDress, >30 min)
- `ext/kin-type-trail`: (brings ext/types-standard-names 8b43b206f, the type rename wave 2 merges via ext/anim-timing-gunslinger; merge it after wave 2 in the combine; note 0245-only content still says "lunar": moon_mark.json, base_shove.json, garden_visitor.json; it also carries wave 9's ext/boki-type-vfx)
- `ext/soul-link-t3-rebased`: (stacked on ext/soul-link-integ, 37 commits incl. Net/KinNet changes, which wave 3 brings via ext/combat-bots-downed; merge ext/soul-link-t4 410724c68 (contains t3) after wave 3 in the combine)
- `ext/soul-link-t4-rebased`: (same: on soul-link-integ/t3; after wave 3)
- `ext/spike-slam-rebased`: (its original f0b10ce78 adds Spike, a second airborne-spike path beside 0245's GlideSpike: Displace.spike(e, vy, by), dolm dunk/void tuning; needs a port of the spike bonus onto GlideSpike, >30 min)
- `ext/summon-kill-credit-rebased`: (its original 810a5976a sits on the wisp/soul-link-integ commits 1e433f875/bbfbf5d9b that wave 3 brings; merge after wave 3)
- `ext/train-rank-controls`: (built on the old Training Area 89fc2916b..1d2cd29f3 that wave 2 brings via ext/train-moving-dummies-rebased; against 0245's Training Grounds it conflicts in 13 files incl. deleted arena.json; merge after wave 2)
## Also taken

- `405870580` cherry-picked from the ext/garden-voice-ambience-rebased tip: voice sets for caecilith (0245's 22nd rigged
  species), lilybara and umbrathere, so --sfx-set-check's boki_voices passes on this line.

## Fixes made on the merged line (Integ fix commits)

- 0245 bug: `rec["loose"]` was an int from Care.ensure and a per-stat dict in StatBudget, so StatBudget.add failed on
  every new Boki (race-check and stat gains red on 0245). Now one per-stat dict; GardenItems' Loosen fills it; an old
  number migrates to Power.
- One writer per piece of data: StatCause writes CareJournal lines; the Games board (BaseBoard) shows MinigameHub's
  results and games send rival results to BaseRival; StatCard, NookPreview and a second KinVoice text bank dropped.
- Save stays v13: sleepovers, clans and the first-breed flag ride 0245's v12/v13 steps, keyed by their own fields.

## Suite (headless, one Godot at a time, against ext/release-integ-0245 92df78ce4)

`--check` and a load of every tools/*.gd pass (exit_signal_check fails to load on 0245 too). 50 check runs on the
head: the 27 new checks plus 23 existing ones for the touched systems. Red on 0245 and here: garden-items (form at
level 4). 0245 red, green here: race, garden-zones. NEW-RED:

- `--boki-rig-check`: caecilith.glb (0245) has no win/sulk/push clips; the glb needs the react-clip rebuild (Blender).
  The other 21 species pass.
- flaky, red on some runs only: `--chore-check` (0/3 red on 0245), `--carry-boki-check` (lead distance near its 3 m
  bar), `--homecoming-check` (Moss slowed round Ash by 0245's KinAvoid ties with Crag) and `--home-hatch-check` (one
  watcher sent when KinWelcome has the others), both new. Likely cause for chore: HomeVoice gates voices on wall-clock
  ms, so the count of Sfx pitch randf calls shifts the seeded stream.
