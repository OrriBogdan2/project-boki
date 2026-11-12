# 0.24.6 wave 2 (anim): merge notes

Branch ext/w0246-anim on ext/release-integ-0245 (92df78ce4). Plan: docs/MERGE_PLAN_0246.md (ext/merge-plan-0246), 103 rows.
Net.VERSION untouched: anim-summon-call brings the Boki wisp and summon (KinWisp, KinSummon, BokiWispPop, behind the
boki_wisps setting, default off) and anim-guardian-stance the guardian summon; both change the sync shape, so the
combine must bump it.

Counts: 73 in (65 merged, 8 carried by a merged branch), 17 held, 13 superseded (anim-stop-start moved to superseded by ext/anim-stop-on-stride).
anim-boki-cast-rebased and anim-react-2-rebased tips merge ext/mc-20261110-0630 (2,200+ commits): their own commits
were merged (a9e410abe, 2eea0e098) without it.

GLB conflicts: a clip both sides re-keyed goes to the side with the newer non-merge edit of that clip (a fix commit
re-applied 18 clips the first pass had given by file date). Most idle, gait and hit re-keys from 11-08/09 lose to the
11-10 appeal3/v95 model swaps, which re-baked every clip: those branches are superseded below.

## Held
- ext/anim-timing-bulwark: bul_guard starts on the host press before the wall, the guest copy lags it (remote-anim-check red 2 of 3 runs; reverted)
- ext/anim-flinch-layer: WardenFlinch duplicates the base additive flinch layer; its stagger-only hit clip turns clip-check red on all 12 (reverted)
- ext/anim-fusion-states-rebased-rebased: remote-anim-check: guest copies of Grimble/Vex/Motley play mf_release on a dash (reverted; WardenClips._move_clip split kept)
- ext/anim-cancel-blend: WardenClips Layer rewrite (56ee146a1) conflicts with the base's two-channel upper layer, flinch layer and per-move fade/lead picks; needs a rebase on the wave
- ext/anim-downed: its fall/rise (hit clip over pop_in, rise backwards) conflicts with the base's same-day Wisp redesign 563a1d5b1 (puff pop-in, hero grows back with a squash); a design merge, not a text fix
- ext/anim-elim-beat: built on the pre-redesign Wisp (lacks 563a1d5b1 round heavy Wisp); the 0.6 s beat needs a re-port onto the new hunter_wisp (states, constants, check, shots)
- ext/anim-gait-speed: its walk/run rings and sole-speed loop rate are a second gait-rate system next to 0.24.5's WardenGait.plan (foot_mps, stride); needs a port onto WardenGait, not a text merge
- ext/anim-pilot-loops-cm-v2: merged, then its 8 pip loops put back (Integ commit): its rings are not one length (walk f 0.42 s vs l/r 0.25 s), so the blended diagonals drift; needs a re-bake at one length (its IMPORT/script edits stay)
- ext/anim-react-2-rebased: its react Add2 flinch layer (_make_flinches) is a second hit-flinch system next to 0245's additive flinch (the hit clip's pose over the upper body, flinch_w; same reason as anim-flinch-layer); the knock lean and the re-keyed hit/stun clips need a port onto it (the 11-10 appeal3/v95 swaps re-baked those clips in 8 glbs)
- ext/anim-summon-clips: built on wisp-summon before wisp-summon-pop: its scale bloom/shrink and faint-on-knock-down clash with BokiWispPop's burst and fold (in via anim-summon-call), and its Boki hit flinch (HIT_LEAN/SQUASH) duplicates 0245's BokiRig _flinch; the faint and summon clips need a port onto both
- ext/anim-timing-gunslinger: its timing pass (364c76459) runs on the 11-08 green-fire Vex (WardenClips clip_warp, Palm Lance, lime: 4e67fbbfc) that 0245 replaced (ember, Longneedle, no clip_warp); the branch tip drags 2,700 commits of an old main. Needs a re-port onto 0245's Vex
- ext/boki-downed-pose-rebased: its Boki hit flinch (KinFlinch hit count, HIT_WINDOW/_hit_k, sad face) duplicates 0245's BokiRig _flinch and pose faces (same as anim-summon-clips); the downed faint (sleep clip at DOWN_SPEED, get-up hop) needs a port onto 0245's nap/settle clips and kin.gd's kstate
- ext/boki-gait: its per-species gait table (content/rules/boki_gait.json, play_scale) is a second Boki stride system next to 0245's BokiRig.STRIDE + MAX_CADENCE + size-roll scale, and RUN_SPEED 3.2 vs 0245's 2.2: one needs picking and the other ported (data over code favours its json)
- ext/anim-mantle-2: a parallel ledge-climb system (data "climb", WardenClips._climb, climb_t; hunter.mantle_k) next to anim-mantle-1's (data "mantle", _mantle, Hunter._rise_k) for the same feature; its Lace/Tenzo/Grimble/Neve clips need a port onto mantle-1's data
- ext/anim-mantle-3: a third ledge-climb system (WardenClips._climb(st, s) on the states' "mantle"/"ledge" clips) next to anim-mantle-1's (data "mantle", _mantle); its Sparkle/Albert/Sable/Motley clips need a port onto mantle-1's data
- ext/anim-strafe-back: stacked on ext/feel-facing-turn (0a8e3f09d 'the body turns onto the cursor at the footage rate'), which the feel wave held for an owner pick (FACE_TURN 5400 deg/s vs 0245 HunterMove.turn_rate); merge after that pick
- ext/vfx-origin-v2-rebased: carries ext/vfx-pass (13 READY 11-08 VFX branches, 53 commits): 31 conflicted files incl. match.gd, hero_vfx.gd and four shaders, a VFX-lane merge over the 0245 HeroVfx rework, far past a 30-min fix; no wave has it yet

## Superseded
- ext/anim-stop-start: the run stop has one owner, WardenStride (anim-run-start-stop, merged); ext/anim-stop-on-stride ports what stop-start added that WardenStride lacked as rows in content/rules/warden_stride.json, not a second path: the feet stay pinned after the step-in until the loops stand in the idle and then hand over over `settle_s` (its stand_k settle; heavy Kael/Albert/Tenzo 0.3-0.32 s, its stop_rate 5 vs 8), and the step-in rises for `lift_p` before it travels (no skate on the last step). Its stop_rate blend, WardenGait.plan-by-blend/follow API and stand_k layer are dropped. --stride-check planted-foot slide through the stop, old -> new (m): Vex 0.015 -> 0.007, Kael 0.150 -> 0.025, Lace 0.039 -> 0.019, Cinder 0.033 -> 0.013, Albert 0.014 -> 0.014 (--anim-audit STOP: 9/10/6/10/10 % -> 7/4/4/6/10 %); table in docs/art/ANIM_QUALITY_AUDIT.md
- ext/anim-pilot-albert-neve: AI-motion pilot loops (run_f/walk_f) keyed on the pre-v95 breaker/claire; the base's newer v95 clips win both, so none of it survives
- ext/idle-archer-rebased: Lace idle+stance rework re-baked on the Ravel v2 hem: the newer 11-10 appeal3 swap and 11-11 pilot idle (anim-pilot-idle-slice) win every clip, theirs' model edits were on the old body
- ext/idle-bulwark-rebased: idle rework re-baked on the pre-swap model: the newer 11-10 appeal3/v95 swaps (and 11-11 pilot idles) win every clip, its model edits were on the old body
- ext/idle-dredge-rebased: idle rework re-baked on the pre-swap model: the newer 11-10 appeal3/v95 swaps (and 11-11 pilot idles) win every clip, its model edits were on the old body
- ext/idle-gunslinger-rebased: idle rework re-baked on the pre-swap model: the newer 11-10 appeal3/v95 swaps (and 11-11 pilot idles) win every clip, its model edits were on the old body
- ext/idle-mage-rebased: idle rework re-baked on the pre-swap model: the newer 11-10 appeal3/v95 swaps (and 11-11 pilot idles) win every clip, its model edits were on the old body
- ext/idle-ostra: idle rework re-baked on the pre-swap model: the newer 11-10 appeal3/v95 swaps (and 11-11 pilot idles) win every clip, its model edits were on the old body
- ext/idle-tender-rebased: idle rework re-baked on the pre-swap model: the newer 11-10 appeal3/v95 swaps (and 11-11 pilot idles) win every clip, its model edits were on the old body
- ext/idle-thief-rebased: idle rework re-baked on the pre-swap model: the newer 11-10 appeal3/v95 swaps (and 11-11 pilot idles) win every clip, its model edits were on the old body
- ext/ostra-gait-rebased: Ostra gait loops re-baked on the pre-swap ostra: the newer swap wins every clip; its audit tool edits only measured those loops
- ext/rimewright-skate-rebased: Claire skate loops lose all 8 run/walk loops to the newer v95 claire loops
- ext/anim-react-audit: its re-keyed hit_f/hit_b lose to the newer 11-10 appeal3/v95 swaps in all 5 glbs (as react-2); nothing else of it survives

## Merged with a side picked or a part left out
- ext/anim-idle-walk-gap-rebased (merged on its own: its container anim-stop-start is superseded)
- ext/anim-nook-moment (its Nook preview card commit 119c5630e left out: the garden wave resolved it to 0245 NookRules.preview)
- ext/anim-prop-handoff (dr_throw THROW_SKIP left out: 0245 Dredge hook has a coil-back wind-up, the hook no longer leaves on the press)
- ext/anim-relic-puton (mask_moment.json deleted as it does; the new 1.5 s beat has no whispers, so 0245 Gil whisper line goes with it)
- ext/anim-result-poses (its own one-Hunter results island left out: results-pose ResultsStage (squad, results_pose.json) kept; WardenBeats win/lose/board beats, the skiff board beat and checks in. Follow-up: ResultsStage could play the win/lose beats)
- ext/anim-stomp-drink-3 (its new stomp/revive/drink tools/anim_shots.gd clashed with the existing --anim-shots: renamed --action-shots, tools/action_shots.gd)
- ext/anim-summon-call (brings the Boki wisp + summon system KinWisp/KinSummon (ext/wisp-summon, wisp-summon-pop) behind boki_wisps, default off; sync shape changes: the combine bumps Net.VERSION)
- ext/anim-timing-ashwick (its 11-frame walk/run re-key lost to the 0245 Cinder appeal4 loops; 0245 RAM_IMPACT_KEY 0.36 kept over its 0.3, its check reads it)
- ext/anim-timing-dolm (its constant loco "cadence" folded into time-cinder's run-share cadence: Dolm's value scales the run, the walk keeps 1)
- ext/anim-timing-rimewright (its 0.34 s run re-key lost to the newer v95 claire loops: the run assert and the claire_clips gait edit left out, doc row marked open)
- ext/anim-utility-poses (rift_key.json stays deleted as in 0245; DRINK_TIME/KIT_TIME read from the utility channel data, which also fixes stomp-drink's checks)
- ext/feel-trigger-edge (archer cd_k override left out: 0245 rank parity removed it)
- ext/strike-reach-heights (its re-keyed lmb_slam lost to the newer breaker swap; the reach data and check kept)
- anim-key-pose-read: its lance/freeze/shot_r/lmb_l re-keys lose to newer edits of the same clips.
- anim-pilot-loops-gs: Vex and Tarek loops come from its set; Lace's walk_f/run_f stay 0245's (one length per ring).

## Suite
Fast suite on the final tree (each check alone, headless, vs the same run on 0245; numbers stripped): import and
--check clean, --remote-anim-check, --kit-parity-check, --boki-rig-check no new red, health OK.
NEW-RED: 27 rows, all in --clip-check and --warden-clips-check, all cross-branch (one branch's check against another
branch's clips or 0245's data):
- drink clip length (8 Hunters): stomp-drink keyed the drink at 1.1 s (the old DRINK_TIME); 0245's tonic channel is
  1.0 s. The clip plays by phase, so it fills the drink either way; a 1.0 s re-key (Blender) closes it.
- hand-over pops: dredge dr_lunge, mage mage_lmb_l (anim-blend-snap's 0.05 s blend-in over dash-travel's rate and the
  0245 upper-body crossfade; bisected to blend-snap), juggernaut jug_riposte.
- rooted feet (juggernaut jug_lunge_wind, thief thf_vault_r): rooted-legs' row against the timing passes' clips.
- landing dips (archer, mage jump run), swim strokes (juggernaut, ostra), tender's weapon in the water, thief's
  carry_drop mesh, the Boki carry socket on Albert, Dolm's breah_throw snap, Ashwick's as_cloak length.
- gil: plays its clips (a check that walks every Hero; Gil has no keyed clips in 0245).

    clip-check: CLIP FAIL archer jump run: the landing dips  m (the hop's dip, at least ), lowest at  s
    clip-check: CLIP FAIL ashwick: every clip lasts as long as its kit move (worst  s, as_cloak, clip  s, keys  s)
    clip-check: CLIP FAIL bulwark: its drink clip lasts the game's  s
    clip-check: CLIP FAIL bulwark: the Boki rides in front of the chest, not in it ( m clear)
    clip-check: CLIP FAIL dolm:  moves snap inside the  s blend, each at full weight on its key (breah_throw  at  s)
    clip-check: CLIP FAIL dolm: its drink clip lasts the game's  s
    clip-check: CLIP FAIL dredge: its drink clip lasts the game's  s
    clip-check: CLIP FAIL dredge: moves hand over without a pop (worst  m over the clip's own, dr_lunge @; limit )
    clip-check: CLIP FAIL juggernaut: its free hand strokes at the swim pace ( strokes/s swimming,  treading)
    clip-check: CLIP FAIL juggernaut: moves hand over without a pop (worst  m over the clip's own, jug_riposte @; limit )
    clip-check: CLIP FAIL juggernaut: rooted, feet planted over every move (worst , jug_lunge_wind @; idle )
    clip-check: CLIP FAIL mage jump run: the landing dips  m (the hop's dip, at least ), lowest at  s
    clip-check: CLIP FAIL mage: its drink clip lasts the game's  s
    clip-check: CLIP FAIL mage: moves hand over without a pop (worst  m over the clip's own, mage_lmb_l @; limit )
    clip-check: CLIP FAIL ostra: its drink clip lasts the game's  s
    clip-check: CLIP FAIL ostra: its free hand strokes at the swim pace ( strokes/s swimming,  treading)
    clip-check: CLIP FAIL rimewright: its drink clip lasts the game's  s
    clip-check: CLIP FAIL tender: its drink clip lasts the game's  s
    clip-check: CLIP FAIL tender: the weapon stays in its hand in the water ( m off the tip,  m off the hand)
    clip-check: CLIP FAIL thief: its drink clip lasts the game's  s
    clip-check: CLIP FAIL thief: rooted, feet planted over every move (worst , thf_vault_r @; idle )
    clip-check: CLIP FAIL thief: the weapon modelled into the hand leaves the shown mesh
    warden-clips-check: CLIPS FAIL breaker: the drink clip is  s (the game's )
    warden-clips-check: CLIPS FAIL gil: plays its clips
    warden-clips-check: CLIPS FAIL ostra: the drink clip is  s (the game's )
    warden-clips-check: CLIPS FAIL ryzz: the drink clip is  s (the game's )
    warden-clips-check: CLIPS FAIL sable: the drink clip is  s (the game's )
