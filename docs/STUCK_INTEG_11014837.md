# stuck-integ-11014837: the stuck READY list of 2026-11-11 16:00

Built 2026-11-11 (job 20261111-155513-a3, rpc4) on `ext/stuck-integ-11014837`: `ext/mc-20261110-1030` (newest mc)
+ `ext/stuck-integ-e6ae8a2c` 09b156b8f (fast-forward) + the merges below. 412 branches were listed.

**Merged here** (resolutions in each merge commit):
- `anim-arm-sable` 96fc06cf4: sable.glb = ours (props) with the branch's glb_bone_retime.py run on it (byte-identical on the base).
- `vfx-neve-crash` 23d171858: lances + brighter pillar kept next to HEAD's true-radius spikes; the frost bud stays gone (owner 11-08, IceBody).
- `sfx-heartspark` aed05a9fc (its base heartspark-rebased is already in).
- `ui-settings-trim` 789776b43, carrying `menus-more` e4c3b9694: menus behind More, with HEAD's Training Grounds, Practice ranks, Controls, Photo mode, LeaveMatch.

**Merged as superseded** (the tree stays ours; HEAD already has one system for it):
`recast-marker-b` 2e37a3309 and `recast-buffer-expired` 83bed4bc3 (RecastCue: world marker, 0.15 s buffer, EXPIRED);
`sfx-pickups-gloves` d9a23794f (ext/sfx-pickups is on HEAD, ext/sfx-gloves is in w0246-audio-vfx).

**Not merged:**
- 137: their newest READY commit is already in e6ae8a2c.
- 151: inside a READY `ext/w0246-*` wave branch or `release-integ-0245`.
- Plan 0246 Superseded/Held rows: agent-briefs agent-briefs-rebased albert-size-boop anim-react-2 barrier-block-parity boki-downed-pose cinder-sable-polish feel-facing-turn feel-summon-press game-rules-nov8 grimble-fist-vfx grimble-stretch-v2 hitstop-parity hunter-revamp-pz idle-archer idle-bulwark idle-dredge idle-gunslinger idle-mage idle-tender idle-thief lace-playtest-1108 meeko-rmb-motion meeko-rmb-motion-rebased meeko-rmb-motion-rebased-rebased meeko-rmb-verify meeko-rmb-verify-rebased ostra-gait parity-kael-clips parity-snowglide-rebased parity-snowglide-rebased-rebased release-integ-0243-rebased release-integ-0243-rebased-rebased soul-link-integ soul-link-t3 soul-link-t4 split-models stuck-integ-e2561d23 summon-kill-credit supervive-impact telegraph-audit-c tut-dodge-dummy tut-first-heartspark tutorial-beats-5-6 tut-start-here ui-text-chat vfx-meeko-weight vfx-origin-v2 vfx-revive-read vfx-telegraph-lead wisp-gpu-ab 
- Held by their finished wave (named in that wave's report or READY line): garden-trait-drift fight-hitch anim-mantle-2 reset-cue-rebased tutorial-idle-check armour-parity sfx-summon idle-ostra cooldown-parity-verify telegraph-audit-c-rebased anim-elim-beat particle-budget idle-mage-rebased rimewright-skate-rebased anim-downed idle-gunslinger-rebased hunter-revamp-go farm-sick-recover misc-ready-integ grimble-nose-1109 anim-strafe-back anim-stop-start stuck-integ-e28956f8 farm-feed-bowl boki-gait vfx-origin-v2-rebased grimble-stretch-v2-rebased idle-tender-rebased idle-thief-rebased idle-archer-rebased vfx-summon-side landing-recovery ostra-gait-rebased idle-dredge-rebased vfx-pass split-ui stuck-integ-950a5444 anim-mantle-3 idle-bulwark-rebased grimble-parity-verify stuck-integ-cb5c1c27 albert-size-boop-rebased vfx-lowpreset-read glider-heat-parity hunter-first-hints cinder-sable-polish-rebased hunter-revamp-af 
- Wave 3 combat leftovers, likely owned by the combat-b wave (`ext/w0246-combat-b-wip` exists): vex-coin-palm-1108, vfx-quality-motley, vex-greenfire-1108.
- `art1-clip-port` 9b9d93216: stacked on anim-react-audit, which lives in w0246-audio-vfx; it belongs on that line.
- `grimble-fist-vfx-rebased`: held by w0246-audio-vfx (old Dredge rework).
- No READY line: art1-kael-2 feel-cast-predict grimble-hook-arm-v2-rebased no-natural-death-1108 perf-actors-1108-rebased portraits-unified rimewright-skate tenzo-playtest-1108 tut-station-goals vfx-dredge vfx-gunslinger-strips wisp-steal ; `mc-fix-1109` is the merged mc base line.

The alternative, merging all of these onto the mc line, was not done because it would resolve every wave conflict a second time on a base without 0245.
