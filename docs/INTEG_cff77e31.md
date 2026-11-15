# Integration cff77e31 (2026-11-14): the 584 conflict-skipped READY branches, again

Job 20261114-115509-a3 (w2, deep). Base: origin/main dc152f0665, not the newest `ext/mc-20261114-0620`: that branch
conflicts with main in 6 files (DEBT, gunslinger.md, loadout_panel, lobby, slot_drag, check_registry) and its own mc job
owns that merge. This list was triaged before by stuck-integ-b6204ee2 (11-13: none of 514 merges clean, archive them)
and stuck-integ-09e533a4 (11-14 04:23).

## Where the 584 are
- 133 are gone from origin; 60 are already in main.
- 378 have no commit since the b6204ee2 triage (11-13 16:55), which found every one in conflict with main. Re-merging
  them mechanically is what b6204ee2's first job tried and threw away. Archive them, or redo a wanted one as a fresh task.
- `agent-briefs` is the briefs channel and never merges into main.
- Owned by other work, so not merged here: `albert-size-boop` and `farm-tut-batch-1108-deep` (main merged into each
  at 11:34 and 11:58 today by running jobs); `airdash-anims-1108` and `heal-knock-source-rebased` (in
  stuck-integ-09e533a4 and f60f9dd7); `revive-source-numbers` and `vex-greenfire-1108` (in f60f9dd7);
  `sfx-listener-hunter` (in mc-20261114-0000).
- **Merged here (5):** `feel-mini-mantle` 84146e2020, `feel-stop-slide` 6798dcf2c, `feel-golden-determinism`
  b0aea5114, `lace-playtest-1108` 5b590e6aa5, `tenzo-playtest-1108` 5093900f9. Each merge commit lists its
  resolutions.

## Unchanged since b6204ee2 (378)
`agent-briefs-rebased`, `aim-height`, `air-cast-poses`, `albert-parity-verify`, `albert-size-boop-rebased`, 
`anim-aim-lead`, `anim-arm-kael`, `anim-arm-motley`, `anim-arm-sable`, `anim-blend-snap`, `anim-boki-cast-rebased`, 
`anim-boki-idle`, `anim-dash-travel`, `anim-downed`, `anim-elim-beat`, `anim-evolve-moment`, `anim-garden-games`, 
`anim-glide-pose`, `anim-hand-albert`, `anim-hand-tenzo-rebased`, `anim-hunter-swim`, `anim-hymotion`, 
`anim-idle-breaks`, `anim-idle-walk-gap-rebased`, `anim-jump-land`, `anim-key-pose-read`, `anim-landing-weight`, 
`anim-mantle-1`, `anim-mantle-2`, `anim-mantle-3`, `anim-prop-handoff`, `anim-react-2-rebased`, `anim-react-audit`, 
`anim-result-poses`, `anim-stomp-drink-1`, `anim-stomp-drink-2`, `anim-stomp-drink-3`, `anim-stop-start`, 
`anim-strafe-back`, `anim-summon-clips`, `anim-time-c`, `anim-time-kael`, `anim-time-sable-rebased`, 
`anim-timing-gunslinger`, `anim-wild-boki`, `armour-parity`, `art1-clip-port`, `art1-kael-2`, `barrier-block-parity`, 
`body-hitbox-parity-rebased`, `boki3d-lilybara`, `boki3d-umbrathere`, `boki-downed-pose-rebased`, `boki-gait`, 
`boki-react-clips-rebased`, `boki-state-clips`, `boki-type-vfx`, `boki-wisp-proto`, `bot-boki-summon`, `bot-kit-use`, 
`bot-kit-use-b`, `camp-parity`, `cancel-matrix-b`, `cast-move-a`, `cc-stacking-rule`, `checks-out-of-main`, 
`cinder-sable-polish-rebased`, `clip-cadence-check`, `combat-boss-tells`, `combat-cc-mobs`, `combat-in-combat-rule`, 
`combat-revive-diminish`, `combo-marks-b`, `cooldown-parity-verify`, `cooldown-start-parity`, `creator-polish`, 
`creator-trim`, `cursor-confine`, `damage-ratio-audit`, `dash-buffer-window-rebased`, `dash-glide-all`, 
`dash-nd-rows-a`, `demo-record-ready-1109`, `drop-parity`, `duel-ring-online`, `egg-picker-preview`, 
`expedition-fps-1108`, `expedition-fps-1108-r2`, `farm-boki-sex`, `farm-carry-boki`, `farm-feed-bowl`, 
`farm-food-journal`, `farm-homecoming`, `farm-home-hatch`, `farm-sick-recover`, `farm-stat-causes`, 
`farm-tut-batch-1108`, `farm-tut-tools-cam-rebased`, `feel-aim-steady`, `feel-cast-predict`, `feel-dash-slopes`, 
`feel-facing-turn`, `feel-first-cast-warm-rebased`, `feel-held-fire-resume`, `feel-hurt-dir-wash`, 
`feel-jump-forgive`, `feel-same-frame`, `feel-step-up`, `feel-trigger-edge`, `fight-hitch`, `fire-on-run-layer`, 
`first-hints-check`, `first-hints-check-rebased`, `flow-rows-source`, `fps-feel`, `fsm-m1`, `gaps-juggernaut`, 
`garden-cinderstep`, `garden-horizon`, `garden-hub-move`, `garden-hub-theme`, `garden-trait-drift`, `garden-unlock`, 
`garden-zone-cinderstep`, `glide-cast-rules`, `glide-dive-land`, `glider-heat-parity`, `glide-text-fix`, 
`grimble-fist-vfx-rebased`, `grimble-hook-arm-v2-rebased`, `grimble-nose-1109`, `grimble-parity-verify`, 
`grimble-stretch-v2-rebased`, `heal-shield-parity`, `hit-feedback-pass`, `hit-spark-targets`, `hitstop-parity`, 
`hunter-first-hints`, `hunter-regen-meshy`, `hunter-revamp-af`, `hunter-revamp-go`, `idle-archer-rebased`, 
`idle-bulwark-rebased`, `idle-dredge-rebased`, `idle-gunslinger-rebased`, `idle-mage-rebased`, `idle-ostra`, 
`idle-tender-rebased`, `idle-thief-rebased`, `islands-deeper-1108`, `kael-riposte-knock`, `kael-rmb-dash-turn`, 
`kael-tap-ult-1108`, `kael-ult-reset-rebased`, `keybinds-1108`, `kin-type-trail`, `kit-error-sweep`, `kit-kael-113`, 
`kit-number-sources`, `kit-parity-refresh-1`, `kit-parity-rows-a`, `kit-parity-rows-b`, `kit-text-clear-fixes`, 
`kit-text-numbers`, `knock-mass-parity`, `lace-hawk-sense`, `landing-recovery`, `leave-match-warning-1108`, 
`legendary-spawns`, `level-growth-parity`, `level-pace`, `lmb-range-parity`, `mantle-press-rules`, 
`mc-20261109-2230`, `mc-20261110-0630`, `mc-fix-1109`, `meeko-rmb-motion-rebased-rebased`, 
`meeko-rmb-motion-rebased-rebased-rebased`, `meeko-rmb-verify-rebased`, `meeko-rmb-verify-rebased-rebased`, 
`menus-more`, `misc-ready-integ`, `motley-seed-fizzle`, `move-sfx-positional-rebased`, 
`no-dash-bursts-audit-rebased-rebased`, `no-hardcoded-keys`, `no-natural-death-1108`, `no-reload-path`, 
`no-rolling-rebased`, `ostra-gait-rebased`, `overlay-typed-calls`, `parity-ability-abyss`, 
`parity-ability-elevation`, `parity-ability-pierce`, `parity-ability-speeds-a`, `parity-ability-speeds-b`, 
`parity-abyss-fall`, `parity-ally-effects`, `parity-antiheal`, `parity-body-collision`, `parity-bulwark-guardcut`, 
`parity-cc-lockouts`, `parity-dot-ticks`, `parity-iframes`, `parity-interrupts-a`, `parity-interrupts-b`, 
`parity-jump-hold`, `parity-jump-pads`, `parity-kael-clips`, `parity-knock-credit`, `parity-motley-float`, 
`parity-no-riders-grimble-tenzo`, `parity-passives-a`, `parity-passives-b`, `parity-recast-windows`, `parity-reel-a`, 
`parity-snowglide-rebased-rebased`, `parity-status-stacking`, `particle-budget`, `perf-actors-1108`, 
`perf-actors-1108-rebased`, `perf-fight-pools`, `perf-model-drawcalls`, `perf-occluders`, 
`perf-render-presets-1108b`, `portraits-unified`, `prologue-canon-2`, `recast-buffer-expired`, `recast-hud-cue`, 
`recast-marker-a`, `recast-marker-b`, `recast-sounds`, `release-integ-0243-rebased-rebased`, 
`release-integ-0244-a4alt`, `remove-hex`, `reset-cue-rebased`, `rimewright-skate`, `rimewright-skate-rebased`, 
`sable-bola-instant-rebased`, `sable-marks-resets`, `sable-v2-art`, `scrapking-lmb`, `secondary-motion-settle`, 
`sfx-ambience`, `sfx-belt-items`, `sfx-boki-types`, `sfx-boki-wire`, `sfx-downed-muffle`, `sfx-extract-cues`, 
`sfx-fusion-evolve`, `sfx-garden-games-rebased`, `sfx-garden-react`, `sfx-gloves`, `sfx-hatch`, `sfx-heartspark`, 
`sfx-hit-targets`, `sfx-hunter-foley`, `sfx-hunter-wisp-hum`, `sfx-legendary-presence`, `sfx-lobby-pick`, 
`sfx-low-hp`, `sfx-mix-pass`, `sfx-mob-alert-rebased`, `sfx-move-weight-rebased`, `sfx-pickups`, 
`sfx-pickups-gloves`, `sfx-ready-cues`, `sfx-ready-cues-summon`, `sfx-reverb-zones`, `sfx-strike-sync`, `sfx-summon`, 
`sfx-summon-end`, `sfx-warnings-boki`, `sfx-weapon-fire`, `sfx-wisp-proc`, `sfx-wisps`, `side-cue-telegraphs`, 
`slam-follow-through`, `sneak-speed-source`, `solo-drop-20261109-2319`, `sparkle-dash-feel`, `split-exits`, 
`split-kmoves-pin-bjorn`, `split-lairs`, `split-models-rebased`, `split-ui`, `split-warden-glb`, `status-body-looks`, 
`status-net-check`, `strike-reach-heights`, `stuck-integ-950a5444`, `stuck-integ-b7a5717c`, `stuck-integ-cb5c1c27`, 
`stuck-integ-d4379965`, `stuck-integ-e2561d23`, `stuck-integ-e28956f8`, `supervive-impact`, 
`telegraph-audit-b-rebased`, `telegraph-audit-c-rebased`, `telegraph-one-system`, `tenzo-cone-grow`, 
`training-area-1108`, `train-rank-controls`, `trios-10x3-1108`, `tut-beat-retry`, `tut-context-tips-rebased`, 
`tut-dive-hint`, `tut-event-hints`, `tut-first-evolve`, `tut-first-fuse`, `tut-first-games`, `tut-first-heartspark`, 
`tut-first-race`, `tut-hot-zone-line`, `tutorial-combat-v2`, `tutorial-idle-check`, 
`tutorial-prologue-rebased-rebased`, `tutorials-cut`, `tut-station-goals`, `tut-summon-station`, `tut-try-relic`, 
`types-standard-names-rebased`, `ui-ability-text-one`, `ui-banner-queue`, `ui-base-hud`, `ui-boki-box-summon`, 
`ui-dex-legendary-order`, `ui-dex-summon-row`, `ui-extract-widget`, `ui-gear-reveal`, `ui-knock-callout`, 
`ui-loot-panel`, `ui-safe-area`, `ui-settings-trim`, `ui-sfx-set`, `ui-stolen-wisps`, `ui-text-size`, 
`ult-ready-glow`, `utilities-shops-rebased`, `vex-coin-palm-1108`, `vex-dash-parity-rebased`, 
`vex-yawlock-1109-2248`, `vfx-armour-break`, `vfx-bulwark`, `vfx-cinder-polish`, `vfx-dolm`, `vfx-dredge`, 
`vfx-evolve-moment`, `vfx-fusion-event`, `vfx-gunslinger`, `vfx-gunslinger-strips`, `vfx-heal-shield-read`, 
`vfx-kael-kit`, `vfx-lowpreset-read`, `vfx-meeko-kindle`, `vfx-miss-impacts`, `vfx-motley-kit`, 
`vfx-motley-nightwell`, `vfx-neve-crash`, `vfx-origin-v2-rebased`, `vfx-ostra-abilities`, `vfx-pass`, 
`vfx-quality-motley`, `vfx-revive-read-rebased`, `vfx-stolen-wisps-rebased`, `vfx-summon-ring`, `vfx-summon-side`, 
`vfx-tender`, `vfx-tenzo-impacts`, `vfx-utility-read`, `vfx-vex-kit`, `warden-bob-damp-rebased`, 
`warden-check-heights`, `wisp-cosmetics`, `wisp-pve-pvp`, `wisp-steal`, `wisp-summon`, `wisp-summon-pop`
