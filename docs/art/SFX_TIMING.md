# Ability sounds against the beat (11-12)

Does each Hero's own sound land on what it belongs to? Measured by `--sfx-strike-check`
(tools/sfx_strike_check.gd) on ext/sfx-beat-resync: main 88b06b9e7 plus ext/w0246-anim 1ebf4587d, the wave whose
anim-time passes moved the beats. Every move of the 12 kits (LMB tap, LMB held 0.5 s, RMB tap, RMB held 0.5 s, E, R)
is pressed once in a real match at a dummy 3 m away, 60 steps a second. Every fire, cast, impact and signature
sound of the Hero's set (content/sfx/<arch>.json) is timed.

- **strike**: the frame the faster hand moves fastest in the skeleton, as the clip is played in the match
  (blends included). A Hero with no clip on that move, or a hand slower than 8 m/s (a rifle's aim), has none.
- **release**: the frame a shot of the Hero's own first appears (a throw, a bolt, a swing's reach), and the first
  rock of a Stone Row or a Basalt Spine rising.
- **hit**: every frame the dummy takes damage (the gameplay hit).
- **heard**: a sound counts from its play plus its lead-in, the first 10 ms of its file at 30% of its peak. Most
  cues start at once; a few are built to lead in (jug_riposte 100 ms, br_spine 150 ms) and are on the beat that late.
- Wind-up sounds (a name part: wind, aim, draw, overdraw, charge, tell, summon, place, count, whirl, hum, creak,
  shield_up, pilot, spin, leap, prime, and Stone Row's tell br_crack) belong before the beat and are not timed.
- A sound heard more than 50 ms from every event of its move fails its kit's row, unless it is listed below as
  right where it plays (`KNOWN` in the check). Re-run it for fresh numbers:
  `godot --headless --path . -- --sfx-strike-check [--strike-only=<arch>]` prints one `ROW` line per move.

## Fixed (sound now played by the event itself, asserted)

| Hero | Move | Sound | Was | Now | Change |
|---|---|---|---|---|---|
| Albert (bulwark) | LMB hammer throw | bjorn_throw | -67 ms (at the press) | +17 ms | 11-09: plays when the hammer leaves his hand (`THROW_WIND`), so it follows the hand however long the wind-up |
| Tenzo (dolm) | E Stone Row | br_raise | own `m.later(tell)` timer | +0 ms on the first rock up | 11-09: played by the first rock that rises; no sound when no rock rose |
| Grimble (dredge) | RMB hook, tap and held | dr_throw | at the press, 217 ms before the arm shoots out | +0 ms on the launch | 11-12: plays in `_launch_hook`, when the 0.2 s coil-back (`rmb.windup`) ends; a throw a stun cancels in the coil makes no fling sound |

## The beats the anim-time passes moved

| Beat | Sound on this base |
|---|---|
| Sparkle RMB tap: the rod leaves at `min_t` 0.35 s; the throw clip starts 0.06 s earlier so its key is the bolt | vv_rod_throw plays in `_coil` with the rod: +0 |
| Albert LMB: the hammer leaves `THROW_WIND` after the press (0.08 here, 100 ms with the queued step; 0.16 on the held ext/anim-timing-bulwark) | bjorn_throw plays as it leaves: +17 here, and it moves with `THROW_WIND` |
| Tenzo X Basalt Spine: cracks 0.2 s, the rocks rise centre-out 0.2-0.6 s, the clip ends at 1.0 | br_spine is heard from 0.15 s and its column cracks run to 0.69 s: on the rise. ext/anim-time-tenzo (not in the wave) stretches the rise to 0.8 s; if it lands, br_spine's column run ends about 0.2 s before the ridge stands |
| Tenzo LMB boulder | br_throw +0 on its release (the boulder leaves on the press here); ext/anim-tenzo-boulder-sync moves the release and the sound together |
| Meeko E, Motley E | the hearth and the seed appear on the press with their sounds; ext/anim-release-sync-meeko-motley moves the gesture there |

## Over 50 ms, right where they play

| Hero | Move | Sound | Off | Why |
|---|---|---|---|---|
| Lace (archer) | E | pin_rain | +73 | the rain bed starts with the rain and swells in (90 ms); pin_patter marks each hit |
| Cinder (ashwick) | LMB held | ashwick_tank_hiss | +100 | the fire gutters out as she lets go: on the let-go, which this check has no event for |
| Cinder (ashwick) | E | lw_shield | +147 | plays on the cast; its file is near silent for its first 180 ms |
| Cinder (ashwick) | R | lw_jet, lw_jet_land | -83, -67 | the lift-off flame and its roar come on the press; the clip skips to its fly key (`LIFT_LEAD`); the landing sound starts with the landing clip |
| Tenzo (dolm) | LMB held | br_punch | +60 | plays on the hit (the punch lands on the let-go); its file rushes in for 60 ms before the impact |
| Tenzo (dolm) | R | br_spine | -83 | heard at 0.15 s, the rocks rise from 0.2 s; the dummy stands where the centre rock would rise, so the first rock in this set-up comes later |
| Grimble (dredge) | RMB | dredge_coin_jingle | +293 | the HAULED payoff when the reel ends |
| Vex (gunslinger) | RMB | gunslinger_grenade_thunk | -83 | the Burr leaves the launcher on the press; the clip's recoil peaks at 83 |
| Vex (gunslinger) | R | vn_nuke_fire | +100 | fires on the clip's kick key (`FIRE_T` 0.14 s); the strike found at 33 ms is the arm going up |
| Kael (juggernaut) | R | juggernaut_heal | +100 | plays on the heal; its file is silent for its first 100 ms |
| Motley (ostra) | E | os_seed | -83 | the seed is planted on the press (see the moved beats above) |
| Meeko (tender) | E | tender_lantern_chime | -83 | rings with the hearth on the press (same) |

Travel time (a shot's fire sound before its hit) is right: the fire sound is meant for the release, which the
release event now catches.

## Not measured this way

Lace R, Albert RMB tap and E, Sparkle R and Meeko R played none of their own timed sounds in this set-up (they need a
mark, a held state, an ally or a target in their area). Read in the code instead: Lace R's cast, nock and beam
sounds ride its vfx events (pin_ult.gd), Sparkle R plays vv_ult_slam on the slam, Meeko R plays tend_call with the
tether and tend_arrive when it lands; none is keyed to the press ahead of a later release.
