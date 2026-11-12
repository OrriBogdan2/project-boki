# stuck-integ-fb4b4275: the stuck READY list of 2026-11-12 08:00

Built 2026-11-12 by job 20261112-075506-a3 (w2) on `ext/stuck-integ-fb4b4275`, from `ext/mc-integ-1112c2` e0429b758
(the newest mc, on 0.24.5 main 53e2fe7f3). 500 branches were listed. No running `*-integ` job on w2 owns one. No
branch on the list has posted a READY since ext/stuck-integ-a6af81f7 (02:30), so its calls stand
(docs/STUCK_INTEG_A6AF81F7.md on that branch); this list re-checks each newest READY sha against this base and the
READY 0.24.6 waves.

**Merged here** (resolutions in each merge commit; a6af81f7 had them on a 0.24.4 mc, so they stayed stuck):
- `vfx-neve-crash` 23d171858: 34 crash lances, taller column, longer dart bolt; HEAD's IceBody frost bud (six spikes)
  stays, the branch's six-petal bud is dropped.
- `anim-arm-sable` 96fc06cf4 (carries `anim-time-sable`, `anim-time-sable-rebased`): the branch's glb_bone_retime line
  run on HEAD's sable.glb (the same line on the merge base gives the branch's glb byte for byte); per-move fade keys.
- `art1-clip-port` 9b9d93216 (carries `anim-react-audit`): hit_f/hit_b spliced into HEAD's breaker, claire, hem, ryzz
  and sable glbs with glb_add_clips.py; --react-audit and the --react/--fov shot strips.

**Not merged here, and why** (do not put them back in the mc pool until the 0.24.6 combine):

- In this base already (main or the 1112 mc batches) (56): `airdash-rule-audit`, `anim-additive-flinch`,
  `anim-boki-home`, `anim-garden-actions`, `anim-time-cinder`, `anim-time-cinder-rebased`, `anim-time-grimble`,
  `anim-time-motley`, `arrival-declutter`, `blight-damage-source`, `blight-edge-read`, `combat-ranges-radii`,
  `dash-refresh-assist`, `farm-favourite-toy`, `farm-perf-low`, `garden-away-card`, `garden-baby-parents`,
  `garden-base-demo`, `garden-base-life`, `garden-base-life-main`, `garden-chores`, `garden-come-look`,
  `garden-elder-mentor`, `garden-integrated`, `garden-journal`, `garden-lean-foods`, `garden-nav-sweep`,
  `garden-only-pace`, `garden-race`, `garden-seek`, `garden-snack-patch`, `garden-stump-shove`, `garden-train-post`,
  `garden-trust`, `garden-volley`, `garden-weekly-race`, `heartspark`, `heartspark-rebased`, `hot-zone`,
  `idle-ashwick`, `idle-dolm`, `idle-rimewright`, `lace-tall-climb`, `map-2x-flat2`, `map-2x-flat2-rebased`,
  `mc-fix-1109b`, `meeko-carry-drop`, `parity-phasewalk`, `prematch-declutter`, `ravel-v2-pass3`,
  `sfx-garden-ambience`, `sfx-garden-games`, `telegraph-audit-a`, `tut-garden-first-day`, `tutorial-garden-4`,
  `ui-minimap-declutter`
- Carried by READY `ext/w0246-anim` (40): `air-cast-poses`, `airdash-anims-1108`, `anim-aim-lead`, `anim-arm-kael`,
  `anim-arm-motley`, `anim-blend-snap`, `anim-boki-cast`, `anim-boki-idle`, `anim-carry-pose`, `anim-dash-travel`,
  `anim-fusion-states`, `anim-glide-pose`, `anim-hand-albert`, `anim-hand-tenzo`, `anim-hand-tenzo-rebased`,
  `anim-hunter-swim`, `anim-idle-walk-gap`, `anim-idle-walk-gap-rebased`, `anim-jump-land`, `anim-key-pose-read`,
  `anim-landing-weight`, `anim-mantle-1`, `anim-mob-states`, `anim-prop-handoff`, `anim-result-poses`,
  `anim-rooted-legs`, `anim-stomp-drink-1`, `anim-stomp-drink-2`, `anim-stomp-drink-3`, `anim-time-kael`,
  `boki-wisp-proto`, `feel-trigger-edge`, `kael-tap-ult-1108`, `strike-reach-heights`, `tender-gait`,
  `tender-gait-rebased`, `vfx-evolve-moment`, `wisp-guardian`, `wisp-summon`, `wisp-summon-pop`
- Carried by READY `ext/w0246-audio-vfx` (35): `boki-type-vfx`, `cancel-matrix-b`, `cancel-matrix-c`,
  `hit-spark-targets`, `legendary-spawns`, `loot-rarity-vfx`, `perf-model-drawcalls`, `sfx-ambience`,
  `sfx-armour-break`, `sfx-belt-items`, `sfx-boki-type-cues`, `sfx-boki-types`, `sfx-boki-voices`, `sfx-boki-wire`,
  `sfx-downed-muffle`, `sfx-fusion-evolve`, `sfx-gloves`, `sfx-hit-targets`, `sfx-legendary-presence`, `sfx-low-hp`,
  `sfx-mix-pass`, `sfx-pickups`, `sfx-reverb-zones`, `sfx-strike-sync`, `sfx-warnings-boki`, `side-cue-telegraphs`,
  `status-body-looks`, `types-standard-names`, `types-standard-names-rebased`, `ui-sfx-set`, `vfx-armour-break`,
  `vfx-fusion-event`, `vfx-miss-impacts`, `vfx-rescore`, `vfx-tenzo-impacts`
- Carried by READY `ext/w0246-combat-a` (33): `ability-bar-charges`, `albert-parity-verify`, `bot-boki-summon`,
  `bot-kit-use-b`, `camp-parity`, `combat-boss-tells`, `combat-cc-mobs`, `combat-friendly-fire`,
  `combat-revive-diminish`, `cooldown-start-parity`, `damage-ratio-audit`, `docs-heroes-sweep`, `drop-parity`,
  `edge-knock-parity`, `fire-on-run-layer`, `gaps-juggernaut`, `heal-shield-parity`, `hero-docs-sync-a`,
  `hero-docs-sync-b`, `kael-lunge-length`, `kael-lunge-length-rebased`, `kael-riposte-knock`, `kit-error-sweep`,
  `kit-number-sources`, `kit-parity-refresh-1`, `kit-parity-refresh-2`, `level-growth-parity`, `motley-seed-fizzle`,
  `parity-armour`, `parity-bulwark-guardcut`, `parity-downed-numbers`, `parity-no-riders-meeko`, `vfx-ostra-abilities`
- Carried by READY `ext/w0246-combat-b` (56): `bot-kit-use`, `kit-parity-rows-b`, `kit-text-clear-fixes`,
  `kit-text-numbers`, `knock-mass-parity`, `lace-hawk-sense`, `lmb-range-parity`,
  `meeko-rmb-motion-rebased-rebased-rebased`, `move-sfx-positional`, `move-sfx-positional-rebased`,
  `parity-ability-abyss`, `parity-ability-elevation`, `parity-ability-pierce`, `parity-ability-speeds-a`,
  `parity-ability-speeds-b`, `parity-abyss-fall`, `parity-ally-effects`, `parity-antiheal`, `parity-body-collision`,
  `parity-bulwark-crush`, `parity-cc-lockouts`, `parity-dot-ticks`, `parity-iframes`, `parity-interrupts-a`,
  `parity-interrupts-b`, `parity-knock-credit`, `parity-motley-float`, `parity-no-riders-grimble-tenzo`,
  `parity-passives-a`, `parity-passives-b`, `parity-recast-windows`, `parity-reel-a`, `parity-status-stacking`,
  `sable-bola-instant`, `sable-bola-instant-rebased`, `sable-marks-resets`, `sable-v2-art`, `secondary-motion-settle`,
  `sfx-kit-placeholders`, `sfx-mob-alert`, `sfx-move-weight`, `sfx-step-surfaces`, `sfx-weapon-fire`,
  `slam-follow-through`, `summon-killed-wisp`, `ui-ability-text-one`, `ult-ranks`, `utility-parity`,
  `vex-yawlock-1109-2248`, `vfx-cinder-polish`, `vfx-lace-impact`, `vfx-meeko-kindle`, `vfx-motley-nightwell`,
  `warden-bob-damp`, `warden-bob-damp-rebased`, `wisp-pve-pvp`
- Carried by READY `ext/w0246-feel` (28): `aim-height`, `cast-move-a`, `dash-buffer-window`,
  `dash-buffer-window-rebased`, `dash-curves-b`, `dash-glide-all`, `dash-interactions-refresh`, `dash-nd-rows-a`,
  `dash-nd-rows-b`, `feel-held-fire-resume`, `feel-hitstop-input`, `feel-hurt-dir-wash`, `feel-jump-forgive`,
  `feel-same-frame`, `feel-step-up`, `feel-wall-slide`, `fps-feel`, `glide-cast-rules`, `glide-dive-land`,
  `glide-text-fix`, `input-latency-check`, `no-dash-bursts-audit`, `no-dash-bursts-audit-rebased`,
  `online-feel-100ms`, `parity-jump-hold`, `parity-jump-pads`, `remove-hex`, `split-kmoves-pin-bjorn`
- Carried by READY `ext/w0246-garden` (11): `boki-react-clips`, `boki-react-clips-rebased`, `cursor-confine`,
  `farm-boki-sex`, `farm-home-hatch`, `fsm-m1`, `garden-save-trip`, `no-hardcoded-keys`, `reset-cue`,
  `solo-drop-20261109-2319`, `ui-base-hud`
- Carried by READY `ext/w0246-misc` (29): `air-cast-a`, `air-cast-b`, `boki3d-lilybara`, `boki3d-umbrathere`,
  `demo-record-ready-1109`, `flow-hold-rows`, `flow-rows-source`, `gaps-thief`, `heal-knock-source`,
  `heal-knock-source-rebased`, `leave-match-warning-1108`, `mantle-press-rules`, `perf-fight-pools`, `perf-occluders`,
  `shadow-renames-arch`, `snag-audit`, `sneak-speed-source`, `split-lairs`, `status-net-check`, `step-smooth`,
  `telegraph-audit-b`, `telegraph-audit-b-rebased`, `telegraph-one-system`, `tenzo-cone-grow`, `wisp-cosmetics`,
  `wisp-merge-from-wisp`, `wisp-passive-stack`, `wisp-summon-leash`, `wisp-summon-net`
- Carried by READY `ext/w0246-tutorial` (6): `feel-first-cast-warm`, `tut-context-tips`, `tut-move-drills`,
  `tut-resume`, `tut-skip-check`, `tut-try-relic`
- Carried by READY `ext/w0246-ui` (21): `cc-stacking-rule`, `checks-out-of-main`, `clip-cadence-check`,
  `combo-marks-b`, `creator-polish`, `creator-trim`, `egg-picker-preview`, `hit-feedback-pass`, `keybinds-1108`,
  `no-reload-path`, `overlay-typed-calls`, `revive-source-numbers`, `ui-boki-box-summon`, `ui-death-recap`,
  `ui-dex-legendary-order`, `ui-dex-summon-row`, `ui-gear-reveal`, `ui-knock-callout`, `ui-loot-panel`,
  `ui-safe-area`, `ui-stolen-wisps`
- Held or superseded, decided before (159; reason per branch in docs/STUCK_INTEG_A6AF81F7.md: MERGE_PLAN_0246
  superseded/held, a wave report, OWNER_PICKS_0246, or one system already on main such as RecastCue and HeartSfx):
  `agent-briefs`, `agent-briefs-rebased`, `albert-size-boop`, `albert-size-boop-rebased`, `anim-downed`,
  `anim-elim-beat`, `anim-mantle-2`, `anim-mantle-3`, `anim-react-2`, `anim-stop-start`, `anim-strafe-back`,
  `anim-time-mossy`, `anim-time-sparkle`, `anim-time-tenzo`, `armour-parity`, `barrier-block-parity`,
  `body-hitbox-parity`, `body-hitbox-parity-rebased`, `boki-gait`, `cinder-sable-polish`,
  `cinder-sable-polish-rebased`, `cooldown-parity-verify`, `duel-ring-online`, `expedition-fps-1108`,
  `farm-feed-bowl`, `farm-sick-recover`, `farm-tut-batch-1108`, `farm-tut-batch-1108-deep`, `farm-tut-tools-cam`,
  `farm-tut-tools-cam-rebased`, `feel-facing-turn`, `feel-summon-press`, `fight-hitch`, `first-hints-check`,
  `fix-cinder-art-check`, `game-rules-nov8`, `garden-trait-drift`, `glider-heat-parity`, `grimble-fist-vfx`,
  `grimble-fist-vfx-rebased`, `grimble-nose-1109`, `grimble-parity-verify`, `grimble-stretch-v2`,
  `grimble-stretch-v2-rebased`, `hitstop-parity`, `hunter-first-hints`, `hunter-revamp-af`, `hunter-revamp-go`,
  `hunter-revamp-pz`, `idle-archer`, `idle-archer-rebased`, `idle-bulwark`, `idle-bulwark-rebased`, `idle-dredge`,
  `idle-dredge-rebased`, `idle-gunslinger`, `idle-gunslinger-rebased`, `idle-mage`, `idle-mage-rebased`, `idle-ostra`,
  `idle-tender`, `idle-tender-rebased`, `idle-thief`, `idle-thief-rebased`, `kael-ult-reset`,
  `kael-ult-reset-rebased`, `kit-parity-rows-a`, `lace-dash-charges`, `lace-playtest-1108`, `landing-recovery`,
  `level-pace`, `meeko-rmb-motion`, `meeko-rmb-motion-rebased`, `meeko-rmb-motion-rebased-rebased`,
  `meeko-rmb-verify`, `meeko-rmb-verify-rebased`, `menus-more`, `misc-ready-integ`, `mossy-narrow`, `no-rolling`,
  `no-rolling-rebased`, `ostra-gait`, `ostra-gait-rebased`, `parity-kael-clips`, `parity-snowglide-rebased`,
  `parity-snowglide-rebased-rebased`, `particle-budget`, `perf-actors-1108`, `prologue-canon`, `prologue-canon-2`,
  `rank-parity-b`, `recast-buffer-expired`, `recast-hud-cue`, `recast-marker-a`, `recast-marker-b`, `recast-sounds`,
  `release-integ-0243-rebased`, `release-integ-0243-rebased-rebased`, `reset-cue-rebased`, `rimewright-skate-rebased`,
  `scrapking-lmb`, `sfx-extract-cues`, `sfx-heartspark`, `sfx-pickups-gloves`, `sfx-summon`, `sfx-wisps`,
  `soul-link-integ`, `soul-link-t3`, `soul-link-t4`, `sparkle-dash-feel`, `split-exits`, `split-models`, `split-ui`,
  `split-warden-glb`, `stuck-integ-950a5444`, `stuck-integ-cb5c1c27`, `stuck-integ-e2561d23`, `stuck-integ-e28956f8`,
  `summon-kill-credit`, `supervive-impact`, `telegraph-audit-c`, `telegraph-audit-c-rebased`, `train-moving-dummies`,
  `train-rank-controls`, `training-area-1108`, `tut-dodge-dummy`, `tut-first-heartspark`, `tut-start-here`,
  `tutorial-beats-5-6`, `tutorial-beats-7-8`, `tutorial-combat-v2`, `tutorial-dialogue`, `tutorial-idle-check`,
  `tutorial-prologue`, `tutorial-prologue-rebased`, `tutorial-prologue-rebased-rebased`, `ui-extract-widget`,
  `ui-settings-trim`, `ui-text-chat`, `vex-coin-palm-1108`, `vex-dash-parity`, `vex-dash-parity-rebased`,
  `vex-greenfire-1108`, `vfx-dolm`, `vfx-gunslinger`, `vfx-lowpreset-read`, `vfx-mage`, `vfx-meeko-weight`,
  `vfx-origin-v2`, `vfx-origin-v2-rebased`, `vfx-pass`, `vfx-quality-motley`, `vfx-revive-read`, `vfx-stolen-wisps`,
  `vfx-summon-side`, `vfx-telegraph-lead`, `vfx-tender`, `warden-check-heights`, `wisp-gpu-ab`
- No READY line, or its sha is not on origin (20): `art1-kael-2`, `expedition-fps-1108-r2`, `feel-cast-predict`,
  `grimble-hook-arm-v2-rebased`, `islands-deeper-1108`, `kit-kael-113`, `loading-screen-1108`, `mc-fix-1109`,
  `no-natural-death-1108`, `perf-actors-1108-rebased`, `perf-render-presets-1108b`, `portraits-unified`,
  `rimewright-skate`, `tenzo-playtest-1108`, `trios-10x3-1108`, `tut-station-goals`, `tutorials-cut`, `vfx-dredge`,
  `vfx-gunslinger-strips`, `wisp-steal`

The 0.24.6 combine (all READY w0246-* waves on main) is what lands the carried ones; merging a wave into an mc here
would be that combine. No `-s ours` merges were made: an ours-merge of a branch a wave still carries would make the
wave's later merge drop that branch's changes.
