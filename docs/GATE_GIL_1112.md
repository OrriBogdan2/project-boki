# Gil train gate (ext/gil-train-1112)

Base: origin/main fb360f614. Built by job 20261112-145022-a6: the 19 Gil branches folded into one branch.
Not tagged; Net.VERSION unchanged.

## Merged (first-parent order: merge, branch tip, branch)
- 6d924006e ddd859b96 ext/sfx-gil-set (carries ext/gil-rework-1111 1eb7d007b and ext/sfx-gil-kit 4b39823df)
- 623762b42 e6202dc18 ext/vfx-gil-bar (rider: ext/vfx-rescore)
- 59c77d5d5 7481e5b96 ext/vfx-gil-aimkit
- 62327748b 2b0a2e98e ext/anim-gil-grabbag (carries ext/anim-gil-clips a437b2a17)
- 7c53035b2 caf3b252d ext/feel-gil-sweeps (carries ext/feel-gil-flow a5a1f5b63; riders: feel-cast-lock-buffer,
  feel-one-buffer, feel-low-fps-input)
- 717178e12 942d3c719 ext/combat-gil-sweeps
- 9537a2afa a128b42ee ext/tut-gil-howto (carries ext/tut-gil-howto-card 355f02bee and ext/tut-gil-howto-drill 0c729a8e0)
- 0d94b92cc 4113135df ext/ui-gil-keys (ext/ui-gil-everywhere has the same tip)
- f586ac960 5024f4146 ext/gil-kit-doc, in part: the --gil-kit-check to --gil-combo-check rename (the old name still
  works) and the dash-flow rows. Its gil.md and table checks were left out because they describe the kit before the
  rework. Follow-up: write gil.md again from the reworked kit.
- 0c16ccf34 a63502c45 ext/combat-gil-ttk (rider: ext/combat-ttk-parity-1112 5f01e4cf3). Conflicts with main's text
  were merged word by word: main's wording, parity's numbers. docs/TTK.md and the wiki were regenerated.
- 510b784b1: the style ratchet fix (a history_comment in tools/gil_combo_check.gd)

## Dropped (superseded)
- ext/vfx-gil-colour 4489183fc: ext/gil-rework-1111 redoes the colours.
- ext/sfx-gil-dash-air 50396951c: the rework already has gil_dash and gil_dash_air (content/sfx/gil.json, dash.json).

## Gate
- Static checks: `tools/health.py --strict` gives HEALTH OK and STYLE OK. `tools/gen_wiki.py --check` reports
  50 unchanged.
- Not run yet: the import, suite-fast vs main, the Gil sweeps, the bot match, the export dry-run and the match played
  as Gil. Every Godot run waits on the shared /usr/local/bin/godot queue. At 15:25Z its 14 slots were all held, most
  by checks hung for 1 to 3 days (for example clip-check, warden-glb-check, mage-combo-check and online-displace
  servers). The oldest queued tickets had waited 7.5 hours, and the queue had served no run since 09:12Z. Both of
  this job's imports were queued at places 15 and 16. Bypassing the queue was refused, so no gate run happened.

## Rough so far (from reading the code; not played yet)
- Three moves have no hand-keyed clip in content/rules/warden_anim/gil.json, so on the 3D model they fall back to the
  procedural rig pose from KMovesGil: gil_tide_wind, gil_tide_lunge and gil_dive. The fix needs new clips in
  tools/art1/gil_clips.py, so it is not a quick fix.
- Bots never use the tide (lmb_override: `held and not bot`). A bot holding LMB only thrusts, so bot matches never
  exercise the tide lunge.
- A dash pressed during Riptide's spin or the wave is swallowed without a cue (content/dash_flow/gil.json: lock). This
  is by design, but it may feel like a dead input.
- The air long dash (the class dash off the ground) plays no Gil clip; only the dust trail shows.
- Open risks to check first once the queue frees: --ttk-check Gil may sit outside the 0.85 to 1.15 bar (the
  combat-gil-ttk READY measured LMB at 1.22 before the rework changed the LMB), the clip_check timing, and
  warden_glb_check with the KMovesGil keys.
- tools/bot_kit_use_check.gd has no Gil MUST row (only ALWAYS). A candidate is ["rmb hold"], plus a new tally for an E recast
  (the spout). It was not added because it could not be run.
