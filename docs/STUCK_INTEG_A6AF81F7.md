# stuck-integ-a6af81f7: the stuck READY list of 2026-11-12 02:30

Built 2026-11-12 by job 20261112-023032-a5 (rpc5) on `ext/stuck-integ-a6af81f7`, from `ext/mc-20261111-1706` 23e536f5f
(the newest mc; built on 0.24.4, so it lacks 0.24.5, which main took at 53e2fe7f3). 479 branches were listed.
No running `*-integ` job seen on rpc5 owns one of them; the 0.24.6 waves (`ext/w0246-*`, each READY, on 0.24.5) own most of them.

**Merged here** (resolutions in each merge commit):
- `vfx-neve-crash` 23d171858: 34 crash lances, brighter column, thin rink cracks, longer dart streak; the frost bud
  stays gone
  (owner 11-08, IceBody), so its petals and check rows are dropped.
- `anim-arm-sable` 96fc06cf4 (carries `anim-time-sable`, `anim-time-sable-rebased`): sable.glb is HEAD's with the
  branch's
  `glb_bone_retime.py` line run on vault_r/vault_l (the same line on the merge base gives the branch's glb byte for byte).
- `art1-clip-port` 9b9d93216 (carries `anim-react-audit` 807d9386e): hit_f/hit_b spliced into HEAD's breaker, claire,
  hem, ryzz and sable glbs with `glb_add_clips.py`; --react-audit FAIL 11 on the base glbs, 5 after.
- Not in a wave because MERGE_PLAN_0246 read the sha quoted inside their READY lines: the waves took the superseded
  a176bc764 (w0246-anim) and 0494c83a6 (w0246-audio-vfx). The 0.24.6 combine needs the two newer heads too.

**Base fixes** (the mc did not parse and failed health): hunter_anim.gd read the removed `down_k` (same line as
w0246-anim); the style ratchet (check_registry.gd 24 long lines, sfx/hunter/hud/title one or two each).

**Superseded, decided here** (not merged):
- `recast-buffer-expired` 83bed4bc3, `recast-hud-cue` 1fd9f80fb, `recast-marker-a` 87df6c5c2, `recast-marker-b`
  2e37a3309, `recast-sounds` 82a248d91: main's RecastCue (ext/recast-clarity-1108: slot pulse, KEY AGAIN,
  ring, EXPIRED, world markers, chime and ticks) and ArchKit.RECAST_BUFFER 0.15 s. One system, so no second layer.
- `sfx-heartspark` aed05a9fc: main's HeartSfx (via ext/sfx-ways-out) has its hum, take/reveal stings, heartbeat,
  extract.
- `sfx-pickups-gloves` d9a23794f: ext/sfx-pickups and ext/sfx-gloves are both in w0246-audio-vfx.
- `warden-check-heights` 84f9aa9d1: the base's warden_model_check already follows the hero-heights chart, with later
  rows.
- `menus-more` e4c3b9694: READY ext/ui-pause-more 9efb5baa6 (11-11, on 0.24.5, --pause-menu-check) redoes the
  same Esc menu and asks for one pick. Picked here: ui-pause-more (alternative: menus-more, then drop ui-pause-more).
- `ui-settings-trim` 789776b43: ext/ui-simplify (owner 11-10, in w0246-ui) redid Settings (7 tabs to 5); it also
  carries menus-more and keybinds-1108, which w0246-ui merged as SUPERSEDED.

**Not merged, owned elsewhere or already done:**

- In origin/main already (34): `anim-boki-home`, `anim-garden-actions`, `arrival-declutter`, `blight-damage-source`,
  `blight-edge-read`, `farm-favourite-toy`, `farm-perf-low`, `garden-away-card`, `garden-baby-parents`,
  `garden-base-demo`, `garden-base-life`, `garden-base-life-main`, `garden-chores`, `garden-come-look`,
  `garden-elder-mentor`, `garden-integrated`, `garden-journal`, `garden-lean-foods`, `garden-nav-sweep`,
  `garden-only-pace`, `garden-race`, `garden-seek`, `garden-snack-patch`, `garden-stump-shove`, `garden-train-post`,
  `garden-trust`, `garden-volley`, `garden-weekly-race`, `heartspark`, `heartspark-rebased`, `sfx-garden-ambience`,
  `sfx-garden-games`, `tut-garden-first-day`, `tutorial-garden-4`
- Carried by READY `ext/w0246-anim` (39): `air-cast-poses`, `airdash-anims-1108`, `anim-aim-lead`, `anim-arm-kael`,
  `anim-arm-motley`, `anim-blend-snap`, `anim-boki-cast`, `anim-boki-idle`, `anim-carry-pose`, `anim-dash-travel`,
  `anim-fusion-states`, `anim-glide-pose`, `anim-hand-albert`, `anim-hand-tenzo`, `anim-hand-tenzo-rebased`,
  `anim-hunter-swim`, `anim-idle-walk-gap`, `anim-idle-walk-gap-rebased`, `anim-jump-land`, `anim-key-pose-read`,
  `anim-landing-weight`, `anim-mantle-1`, `anim-mob-states`, `anim-prop-handoff`, `anim-result-poses`,
  `anim-rooted-legs`, `anim-stomp-drink-1`, `anim-stomp-drink-2`, `anim-stomp-drink-3`, `anim-time-cinder`,
  `anim-time-cinder-rebased`, `anim-time-kael`, `feel-trigger-edge`, `kael-tap-ult-1108`, `strike-reach-heights`,
  `tender-gait`, `tender-gait-rebased`, `vfx-evolve-moment`, `wisp-guardian`
- Carried by READY `ext/w0246-audio-vfx` (33): `boki-type-vfx`, `cancel-matrix-b`, `cancel-matrix-c`,
  `hit-spark-targets`, `legendary-spawns`, `loot-rarity-vfx`, `perf-model-drawcalls`, `sfx-ambience`,
  `sfx-armour-break`, `sfx-boki-type-cues`, `sfx-boki-types`, `sfx-boki-voices`, `sfx-boki-wire`, `sfx-downed-muffle`,
  `sfx-fusion-evolve`, `sfx-gloves`, `sfx-hit-targets`, `sfx-legendary-presence`, `sfx-low-hp`, `sfx-mix-pass`,
  `sfx-pickups`, `sfx-reverb-zones`, `sfx-strike-sync`, `sfx-warnings-boki`, `side-cue-telegraphs`,
  `types-standard-names`, `types-standard-names-rebased`, `ui-sfx-set`, `vfx-armour-break`, `vfx-fusion-event`,
  `vfx-miss-impacts`, `vfx-rescore`, `vfx-tenzo-impacts`
- Carried by READY `ext/w0246-combat-a` (27): `ability-bar-charges`, `albert-parity-verify`, `bot-boki-summon`,
  `camp-parity`, `combat-boss-tells`, `combat-cc-mobs`, `combat-friendly-fire`, `combat-revive-diminish`,
  `cooldown-start-parity`, `damage-ratio-audit`, `docs-heroes-sweep`, `drop-parity`, `edge-knock-parity`,
  `fire-on-run-layer`, `gaps-juggernaut`, `hero-docs-sync-a`, `hero-docs-sync-b`, `kael-lunge-length`,
  `kael-lunge-length-rebased`, `kael-riposte-knock`, `kit-error-sweep`, `kit-number-sources`, `kit-parity-refresh-1`,
  `kit-parity-refresh-2`, `motley-seed-fizzle`, `parity-downed-numbers`, `parity-no-riders-meeko`
- Carried by READY `ext/w0246-combat-b` (65): `boki-wisp-proto`, `bot-kit-use`, `bot-kit-use-b`, `heal-shield-parity`,
  `kit-parity-rows-b`, `kit-text-clear-fixes`, `kit-text-numbers`, `knock-mass-parity`, `lace-hawk-sense`,
  `level-growth-parity`, `lmb-range-parity`, `meeko-rmb-motion-rebased-rebased-rebased`, `move-sfx-positional`,
  `move-sfx-positional-rebased`, `parity-ability-abyss`, `parity-ability-elevation`, `parity-ability-pierce`,
  `parity-ability-speeds-a`, `parity-ability-speeds-b`, `parity-abyss-fall`, `parity-ally-effects`, `parity-antiheal`,
  `parity-armour`, `parity-body-collision`, `parity-bulwark-crush`, `parity-bulwark-guardcut`, `parity-cc-lockouts`,
  `parity-dot-ticks`, `parity-iframes`, `parity-interrupts-a`, `parity-interrupts-b`, `parity-knock-credit`,
  `parity-motley-float`, `parity-no-riders-grimble-tenzo`, `parity-passives-a`, `parity-passives-b`,
  `parity-recast-windows`, `parity-reel-a`, `parity-status-stacking`, `sable-bola-instant`,
  `sable-bola-instant-rebased`, `sable-marks-resets`, `sable-v2-art`, `secondary-motion-settle`, `sfx-belt-items`,
  `sfx-kit-placeholders`, `sfx-mob-alert`, `sfx-move-weight`, `sfx-step-surfaces`, `sfx-weapon-fire`,
  `slam-follow-through`, `status-body-looks`, `summon-killed-wisp`, `ui-ability-text-one`, `ult-ranks`,
  `utility-parity`, `vex-yawlock-1109-2248`, `vfx-cinder-polish`, `vfx-lace-impact`, `vfx-meeko-kindle`,
  `vfx-motley-nightwell`, `warden-bob-damp`, `warden-bob-damp-rebased`, `wisp-pve-pvp`, `wisp-summon`
- Carried by READY `ext/w0246-feel` (28): `aim-height`, `cast-move-a`, `dash-buffer-window`,
  `dash-buffer-window-rebased`, `dash-curves-b`, `dash-glide-all`, `dash-interactions-refresh`, `dash-nd-rows-a`,
  `dash-nd-rows-b`, `feel-held-fire-resume`, `feel-hitstop-input`, `feel-hurt-dir-wash`, `feel-jump-forgive`,
  `feel-same-frame`, `feel-step-up`, `feel-wall-slide`, `fps-feel`, `glide-cast-rules`, `glide-dive-land`,
  `glide-text-fix`, `input-latency-check`, `no-dash-bursts-audit`, `no-dash-bursts-audit-rebased`,
  `online-feel-100ms`, `parity-jump-hold`, `parity-jump-pads`, `remove-hex`, `split-kmoves-pin-bjorn`
- Carried by READY `ext/w0246-garden` (9): `cursor-confine`, `farm-boki-sex`, `farm-home-hatch`, `fsm-m1`,
  `garden-save-trip`, `no-hardcoded-keys`, `reset-cue`, `solo-drop-20261109-2319`, `ui-base-hud`
- Carried by READY `ext/w0246-misc` (31): `air-cast-a`, `air-cast-b`, `boki3d-lilybara`, `boki-react-clips`,
  `boki-react-clips-rebased`, `demo-record-ready-1109`, `flow-hold-rows`, `flow-rows-source`, `gaps-thief`,
  `heal-knock-source`, `heal-knock-source-rebased`, `leave-match-warning-1108`, `mantle-press-rules`,
  `perf-fight-pools`, `perf-occluders`, `shadow-renames-arch`, `snag-audit`, `sneak-speed-source`, `split-lairs`,
  `status-net-check`, `step-smooth`, `telegraph-audit-b`, `telegraph-audit-b-rebased`, `telegraph-one-system`,
  `tenzo-cone-grow`, `wisp-cosmetics`, `wisp-merge-from-wisp`, `wisp-passive-stack`, `wisp-summon-leash`,
  `wisp-summon-net`, `wisp-summon-pop`
- Carried by READY `ext/w0246-tutorial` (6): `feel-first-cast-warm`, `tut-context-tips`, `tut-move-drills`,
  `tut-resume`, `tut-skip-check`, `tut-try-relic`
- Carried by READY `ext/w0246-ui` (21): `cc-stacking-rule`, `checks-out-of-main`, `clip-cadence-check`,
  `combo-marks-b`, `creator-polish`, `creator-trim`, `egg-picker-preview`, `hit-feedback-pass`, `keybinds-1108`,
  `no-reload-path`, `overlay-typed-calls`, `revive-source-numbers`, `ui-boki-box-summon`, `ui-death-recap`,
  `ui-dex-legendary-order`, `ui-dex-summon-row`, `ui-gear-reveal`, `ui-knock-callout`, `ui-loot-panel`,
  `ui-safe-area`, `ui-stolen-wisps`
- owner picks, docs/OWNER_PICKS_0246.md (ext/owner-picks-0246) (5): `cooldown-parity-verify`, `glider-heat-parity`,
  `grimble-parity-verify`, `hunter-first-hints`, `kit-parity-rows-a`
- held or superseded in `ext/w0246-anim`'s report (19): `anim-downed`, `anim-elim-beat`, `anim-mantle-2`,
  `anim-mantle-3`, `anim-stop-start`, `anim-strafe-back`, `boki-gait`, `idle-archer-rebased`, `idle-bulwark-rebased`,
  `idle-dredge-rebased`, `idle-gunslinger-rebased`, `idle-mage-rebased`, `idle-ostra`, `idle-tender-rebased`,
  `idle-thief-rebased`, `ostra-gait-rebased`, `rimewright-skate-rebased`, `vfx-origin-v2-rebased`, `vfx-pass`
- held or superseded in `ext/w0246-audio-vfx`'s report (1): `grimble-fist-vfx-rebased`
- held or superseded in `ext/w0246-combat-a`'s report (7): `albert-size-boop-rebased`, `armour-parity`,
  `body-hitbox-parity-rebased`, `cinder-sable-polish-rebased`, `hunter-revamp-af`, `hunter-revamp-go`,
  `reset-cue-rebased`
- held or superseded in `ext/w0246-combat-b`'s report (4): `split-warden-glb`, `vex-coin-palm-1108`,
  `vex-greenfire-1108`, `vfx-quality-motley`
- held or superseded in `ext/w0246-feel`'s report (1): `vex-dash-parity-rebased`
- held or superseded in `ext/w0246-garden`'s report (12): `duel-ring-online`, `farm-feed-bowl`, `farm-sick-recover`,
  `farm-tut-batch-1108`, `farm-tut-batch-1108-deep`, `farm-tut-tools-cam-rebased`, `garden-trait-drift`,
  `no-rolling-rebased`, `stuck-integ-950a5444`, `stuck-integ-cb5c1c27`, `stuck-integ-e28956f8`, `train-rank-controls`
- held or superseded in `ext/w0246-misc`'s report (9): `expedition-fps-1108`, `fight-hitch`, `grimble-nose-1109`,
  `grimble-stretch-v2-rebased`, `landing-recovery`, `level-pace`, `misc-ready-integ`, `split-exits`,
  `telegraph-audit-c-rebased`
- held or superseded in `ext/w0246-tutorial`'s report (3): `prologue-canon-2`, `tutorial-idle-check`,
  `tutorial-prologue-rebased-rebased`
- named in a wave's READY line (audio-vfx or ui holds) (12): `particle-budget`, `scrapking-lmb`, `sfx-extract-cues`,
  `sfx-summon`, `sfx-wisps`, `split-ui`, `ui-extract-widget`, `vfx-dolm`, `vfx-gunslinger`, `vfx-lowpreset-read`,
  `vfx-summon-side`, `vfx-tender`
- MERGE_PLAN_0246 Superseded (72): `agent-briefs`, `albert-size-boop`, `anim-react-2`, `anim-time-mossy`,
  `anim-time-sparkle`, `anim-time-tenzo`, `barrier-block-parity`, `body-hitbox-parity`, `cinder-sable-polish`,
  `farm-tut-tools-cam`, `feel-facing-turn`, `feel-summon-press`, `first-hints-check`, `fix-cinder-art-check`,
  `game-rules-nov8`, `grimble-fist-vfx`, `grimble-stretch-v2`, `hitstop-parity`, `hunter-revamp-pz`, `idle-archer`,
  `idle-bulwark`, `idle-dredge`, `idle-gunslinger`, `idle-mage`, `idle-tender`, `idle-thief`, `kael-ult-reset`,
  `kael-ult-reset-rebased`, `lace-dash-charges`, `lace-playtest-1108`, `meeko-rmb-motion`, `meeko-rmb-motion-rebased`,
  `meeko-rmb-verify`, `meeko-rmb-verify-rebased`, `mossy-narrow`, `no-rolling`, `ostra-gait`, `parity-kael-clips`,
  `parity-snowglide-rebased`, `perf-actors-1108`, `prologue-canon`, `rank-parity-b`, `release-integ-0243-rebased`,
  `release-integ-0243-rebased-rebased`, `soul-link-integ`, `soul-link-t3`, `soul-link-t4`, `sparkle-dash-feel`,
  `split-models`, `stuck-integ-e2561d23`, `summon-kill-credit`, `supervive-impact`, `telegraph-audit-c`,
  `training-area-1108`, `train-moving-dummies`, `tut-dodge-dummy`, `tut-first-heartspark`, `tutorial-beats-5-6`,
  `tutorial-beats-7-8`, `tutorial-combat-v2`, `tutorial-prologue`, `tutorial-prologue-rebased`, `tut-start-here`,
  `ui-text-chat`, `vex-dash-parity`, `vfx-mage`, `vfx-meeko-weight`, `vfx-origin-v2`, `vfx-revive-read`,
  `vfx-stolen-wisps`, `vfx-telegraph-lead`, `wisp-gpu-ab`
- MERGE_PLAN_0246 Held (3, built on ext/agent-briefs history, docs only): `agent-briefs-rebased`,
  `meeko-rmb-motion-rebased-rebased`, `parity-snowglide-rebased-rebased`
- No READY line (21): `art1-kael-2`, `boki3d-umbrathere`, `expedition-fps-1108-r2`, `feel-cast-predict`,
  `grimble-hook-arm-v2-rebased`, `islands-deeper-1108`, `kit-kael-113`, `no-natural-death-1108`,
  `perf-actors-1108-rebased`, `perf-render-presets-1108b`, `portraits-unified`, `rimewright-skate`,
  `tenzo-playtest-1108`, `trios-10x3-1108`, `tutorial-dialogue`, `tutorials-cut`, `tut-station-goals`, `vfx-dredge`,
  `vfx-gunslinger-strips`, `vfx-ostra-abilities`, `wisp-steal`
- `mc-fix-1109`: its READY sha is not on origin (plan: Stale).

The merge candidate will keep skipping all of these: they conflict with an mc built on 0.24.4 because their owners
built them on 0.24.5. Drop them from its pool (`~/bin/merge-exclude.txt` on its host) until the 0.24.6 combine lands.
