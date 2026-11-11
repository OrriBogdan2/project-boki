# Landing weight by fall speed (ext/anim-landing-weight, Nov 9)

The source (briefs/hero-ref; DECISIONS 11-07, parity first) lands three ways: a small dip after a hop, a deeper crouch
after a terrace drop or a glide's end, and no lockout anywhere: the Hunter is up and moving ~0.15 s after any touchdown.
Ours now picks one of three tiers at touchdown from the fall speed (`HunterAnim.land_tier`, shared by the procedural rig
and the hand-keyed clips in `WardenClips`):

| Tier | Fall speed at touchdown | What it is | Clips (`content/rules/warden_anim/<art>.json` `land`) |
|---|---|---|---|
| none | under 4.0 m/s | a kerb, a step down of ~0.5 m | nothing plays, the run goes on |
| hop | 4.0 m/s up (a plain jump lands at `JUMP_V` 6.8) | the small dip | the land clip at `w` 0.5 (heavy 0.6, Breaker 0.8, Sable 0.75), quicker (`rate` 1.4-1.5), 0.08-0.1 s on the run, 0.2-0.24 s standing |
| drop | 8.5 m/s up (a 2.5 m+ drop, a jump off a 1 m ledge), or any glide's end | the deep crouch | the full land clip at its own pace (`rate` 0.9-1.2), 0.12-0.13 s on the run, 0.33-0.4 s standing |

The poses stay each Hunter's own land clip: the tiers only change how much of it shows and for how long. The glide's end
lands at the canopy's 1.4 m/s sink, so it is the deep tier by the state, not the speed. The procedural rig (the fallback
when a Hero has no clips) lands the same way: hop `land_k` 0.35, drop 0.7-1.0, and a heavy's ground slam is the drop's only.

## Measured (`--clip-check` JL rows, 30 fps, the match camera's arcs from tools/jump_land_shots.gd)

Dip: how far the hips go under their run (or stand) height within 0.15 s of touchdown. Legs back: the last moment the
land clip owned the legs over the run (`act_w` > 0.5). Body back: the clip fully gone, standing. Motley's hips ride his
spring (`sway`), so his dip is not measured. Asserted per Hunter: hop dip >= 0.015 m, drop and glide dip >= 0.03 m and
1.25x the hop's, a kerb plays nothing, running the legs are never held (0 s since the land beat), standing the body within the data's
promise (never over 0.6 s).

| Hunter | hop dip run / still (m) | drop dip run / still (m) | glide dip run / still (m) | legs back run: hop / drop (s) | body back still: hop / drop (s) | kerb |
|---|---|---|---|---|---|---|
| Vex | 0.028 / 0.099 | 0.120 / 0.215 | 0.120 / 0.223 | 0.00 / 0.17 | 0.30 / 0.57 | none |
| Kael | 0.074 / 0.153 | 0.158 / 0.275 | 0.159 / 0.294 | 0.07 / 0.17 | 0.33 / 0.57 | none |
| Lace | 0.026 / 0.054 | 0.073 / 0.123 | 0.073 / 0.123 | 0.00 / 0.17 | 0.30 / 0.47 | none |
| Cinder | 0.018 / 0.077 | 0.095 / 0.155 | 0.081 / 0.162 | 0.07 / 0.17 | 0.33 / 0.57 | none |
| Breaker | 0.017 / 0.031 | 0.031 / 0.057 | 0.031 / 0.048 | 0.07 / 0.17 | 0.37 / 0.57 | none |
| Kibo | 0.149 / 0.155 | 0.337 / 0.373 | 0.336 / 0.371 | 0.00 / 0.17 | 0.30 / 0.57 | none |
| Grimble | 0.045 / 0.149 | 0.147 / 0.241 | 0.149 / 0.262 | 0.07 / 0.17 | 0.33 / 0.57 | none |
| Ryzz | 0.018 / 0.051 | 0.069 / 0.131 | 0.068 / 0.139 | 0.00 / 0.17 | 0.30 / 0.47 | none |
| Motley | sway | sway | sway | 0.00 / 0.17 | 0.30 / 0.57 | none |
| Nivi | 0.021 / 0.043 | 0.053 / 0.124 | 0.059 / 0.122 | 0.00 / 0.17 | 0.30 / 0.47 | none |
| Meeko | 0.020 / 0.029 | 0.055 / 0.114 | 0.055 / 0.106 | 0.00 / 0.17 | 0.30 / 0.47 | none |
| Sable | 0.018 / 0.092 | 0.053 / 0.135 | 0.052 / 0.134 | 0.07 / 0.17 | 0.33 / 0.47 | none |

Before (ext/anim-jump-land): every landing after 0.25 s airborne was the full clip, so a plain hop dipped Vex 0.11 m
on the run and Kibo 0.27 m (jump_land_run_after.jpg is that state), and eight Hunters held the body 0.47 s over the run.

## The land beat for every Hunter (ext/anim-land-beat, Nov 11)

- **Dive tier.** `HunterAnim.LAND_DIVE_V` 17 m/s: a glide dive (32.5 m/s, still ~25 m/s after the canopy's catch at the
  cancel height) or a long drop. The clips play the drop at `DIVE_SLOW` 0.8 of its rate over the same hold (lower for
  longer); the procedural rig the full crouch at `land_rate` 2.5. Hop < drop and glide's end < dive.
- **Running, the legs are never held.** The land clip less the idle's first frame rides the run as an additive over the
  whole body (`WardenClips._build_run_land`) for `moving` s, then fades in 0.1 s: the Rig drops and the knees bend under
  the stride. Standing, the clip owns the body as before. A move (a dash, a cast) is picked over the landing: it cuts it
  the frame it starts. Measured (JL rows, run): legs held 0.00 s for all 12 (was 0.17 on the drop), body back 0.07 s
  (was 0.27), dips bottom at 0.07-0.10 s, e.g. Vex hop/drop 0.100 / 0.278 m (was 0.054 / 0.147), Breaker 0.026 / 0.054.
- **No press waits for a landing.** The glider folds on the step its fall reaches the ground, before that step's presses
  are read (`AirLimits.fold_at_touchdown`, docs/decisions/0061): an LMB or a kit dash pressed on a glide or dive landing's
  step was refused under the open canopy and lost. `--dash-flow-check` asserts, per hero, that a dash, a jump and every
  slot pressed on the touchdown step of a hop, a fall, a glide's end and a dive, or 0.1 s into the absorb, act as soon
  as they do standing. `Hunter.land_t` (a "stagger" nothing read) is gone.
- **No effects.** The opening drop's touchdown rings are gone (DECISIONS: no rings on landings); landings keep the dust
  puff, squash and thud. `--move-feel-check` asserts no landing spawns a ring or burst, and each one's tier.

## Strips (GPU, `--jump-land-shots --way=`, tools/jump_land_strip.py)

- `landing_hop_run.jpg`, `landing_hop_still.jpg`: the plain jump (the hop tier) at the match camera.
- `landing_drop_run.jpg`, `landing_drop_still.jpg`: the 3 m terrace drop, touchdown to +15 frames.
- `landing_glide_run.jpg`, `landing_glide_still.jpg`: a glide's end at the canopy's sink.

Open: Breaker's land clip is shallow (0.031 m on the run at full weight), so his drop barely reads deeper than his hop;
a deeper absorb wants new keys in tools/art1 (not this change: the poses stay the art's). Sable's land clip rises
before it sinks, so her hop plays at the clip's own pace with 0.75 of the pose.
