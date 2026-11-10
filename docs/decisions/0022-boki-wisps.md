# 0022: Boki are wisps

- **Status:** accepted (owner decision of Nov 10 2026, DECISIONS.md on ext/agent-briefs)
- **Date:** 2026-11-10
- **Area:** combat / networking / UI (Boki on you, knockouts, capture)

## Problem
A Boki on your shoulder, your pack or under you is a body to pose, clip and read on every hunter, and the knocked-out
Boki was a body on the ground you had to run to and carry while it filled (the cradle). The owner wants Boki on you to
be small glowing wisps, summoned out into the full Boki, and a knockout to send the Boki back to you instead.

## Options
1. Keep the shoulder/perch/mount bodies and only restyle them. Rejected: the owner's call is wisps.
2. Wisps on you, a burst into the full body on summon, a dim wisp on you while knocked out, wisps on the ground for a
   beaten wild Boki, a limited box (decided).

## Decision
Code: `scripts/match/kin_wisp.gd` (orbit, burst, render), `scripts/kin/kin_downed.gd` (knockout), `scripts/match/capture.gd`
(the box). Numbers: `content/rules/boki_system.json` "wisp" and "down", `content/rules/capture.json`.
- **On you.** The on-you state is "wisp" (was "shoulder"): a small orb in the species colour orbiting you (`orbit_r` 0.9 m,
  `period_s` 3.2, `height`, `bob`, `size`). No shoulder, perch or mount body while idle. Carry passives (0002) still
  apply while it is a wisp on you by order. The carry style stays in the data (shoulder/perch/mount) for passives,
  sizes and the mount's movement.
- **Summon.** A throw (C), Sic or its ability bursts the wisp into the full Boki: a flash, a ring, sparks, and a
  scale-up over `summon_s` (0.22 s); a recall shrinks it back over `shrink_s`. Sent out by a throw with nothing to do for
  `auto_wisp_s` (5 s) it drifts back into a wisp. A mount summons out to be ridden: Return on a mount sets `Kin.ride`
  and you ride the full body; over a glide it rides along as a wisp; a jump order un-rides it.
- **Knocked out.** It falls back to you as a dim wisp (`dim` 0.35) and cannot be summoned by throw, E or Merge until it
  recovers: `recover_s` (45 s) or the end of the fight (`calm_s` 4 s out of combat), whichever comes first, back at
  `recover_hp` (35%). This replaces the carry-the-fallen-Boki rescue (the cradle, its slow walk, the scoop, the beacon).
  A fall into the abyss is the same knockout.
- **In the world.** A beaten wild Boki is a wisp hovering on the ground (`ground_h`); you scan it with the existing
  hold-to-pick-up ring (0002). A guarding Boki whose owner died (0008) is a ground wisp too: its owner scans it back
  (`KinLoss.reclaim`), teammates cannot, enemies capture it as before.
- **Capacity.** The box (the wisps you hold) has `box_capacity` 3. Full, the prompt says swap or leave it: holding
  `swap_hold_s` (1.2 s) instead of `hold_s` starts the scan and the oldest held wisp goes free for the new one. Your
  active Boki does not count toward the box.
- **Home.** Wisps are for the field and matches only: at home Boki stay full-bodied in the garden (no Kin there).

## Consequences
- Net.VERSION 0.24.3 to 0.24.4: state "wisp" replaces "shoulder"; the kin snapshot's extra carries the ride flag and the
  calm timer; the "scoop" kin event is gone ("round" stays).
- Removed: `KinLoss.cradled/tick_guard/rescuing`, `Capture.dissolve`, the rescue fields on Kin (rescue_t, rescue_on,
  rescue_block, down_void, beacon), the bot rescue goal, the rescue rows in the utility belt, bond HUD and merge moves,
  `KinMerge.rescue_text` (the plan is "down" now).
- Checks: `--kin-wisp-check` (orbit, summon to full body, no summon while knocked out until it recovers, capacity on
  scan) and `--kin-wisp-shots` (frames, xvfb); boki_system, kin_loss, capture, kin_regen, merge_form and match_audio checks
  updated for the new behaviour.
- Open (defaulted, change freely): box captures don't orbit you (only the active Boki does); `Sfx.loop_hold` has no
  game caller left (kept, tested directly); dazed ground wisps still collide as bodies.
