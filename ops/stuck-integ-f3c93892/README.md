# Stuck-integ f3c93892 (job 20261118-205427-a6, worker w2, main 91589227da, 2026-11-18)

Same skipped-READY list as stuck-integ-8a30c285 (708 names, 547 still on the remote and not in main).
The 524 already in ops/stuck-integ-8a30c285/triage.tsv are unchanged since that pass: same verdict (superseded or
port-from-intent, nothing to merge). This pass only covers the 23 branches new to the list and the 5 with commits
since 11-17 19:00.

Base: origin/main, not ext/mc-20261118-0540 (the newest mc). That mc is 173 behind main and conflicts with it in 59
files, so a union built on it could not land.

Dropped (owned by a running lane job, merged or regated today):
- ui-overload-1115, fsm-m1, hud-g-armor-1111: uihud lane 11-18 merged main into them at 15:36-15:52; they merge clean.
- stuck-integ-be6ffab8 (#169), mantle-port-a (#135): open PRs on the regate path.

Superseded (main already has the change, the conflict only touches older text):
- fix-vex-walk-1115: vex.json, warden_clips, FOOT_SLIDE are on main; main's gameplay_media already has clip 16 walk.
- polish-panel-close, ui-tab-scoreboard: merge adds nothing (all hunks already on main).
- integ-1113-A1/D2/D3, merge-lane-uihud-1114-b, stuck-integ-38a28c4e, stuck-integ-c14ccd66: older union trains
  of branches already triaged in 8a30c285 (10-89 conflict files, 761-10952 behind).
- gil-motley-v95-1116: the conflicts are on gil/ostra glbs. Main has newer v95 swaps (3D CURRENT rule), so keep main's.
- loading-title-1115: the conflicts are on splash jpgs and loading.gd. Main has newer splash art; keep main's.
- feel-glide-sink-heat, ui-stale-text-pass, ui-inventory-pass, farm-hatch-name, ui-clutter-zone-1116,
  levelup-clear-1111, ui-tab-board-stats: 11k-17k behind. Main has rewritten the files (HUD split, kin names,
  level cue in results/home, loadout panel), so taking either side would drop the other's work.

Port backlog (the feature is NOT on main; port it from the intent, don't merge):
- ui-self-cc-timer: a self_cc_line under the vitals that counts down your own stun/root. Main has no equivalent.
- ui-knock-feed: a separate knock feed (knock_feed.gd + check). Main has the kill feed (hud_reveal "feed"), so first
  decide whether knocks belong in that feed.
- egg-hover-1111: egg_hover.gd card. Main's hatch.gd has hover pick and the mystery-egg card, so only the hover
  card text is missing.

Next: retire this list from merge-candidate. Every name is merged, superseded, owned or in the port backlog.
