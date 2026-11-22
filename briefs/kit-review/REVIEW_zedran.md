# Review: Zedran (id `juggernaut`), branch origin/ext/kitfix-dancer-juggernaut @ beeb14f

**Verdict: PASS WITH FIXES.** The mechanics are right:
- The slashes alternate, and a hold fires the wave.
- The tap Finishing Slam has a magenta lane, and its sweet-spot crash is reachable at rank 1 (the Doomfall fold works).
- The Lunge hold grows a red lane that turns magenta with a flash at full; you can jump while charging, and it flings up to 7.5 m.
- Meteor Drop lands on a cursor disc.
- Rampage has 3 charges.
- The Warchain is steerable.

The owner's RMB-hold notes are met in code and mostly visible. The misses are VFX identity:
- **The Warchain** shows as a thin dotted white line in the shots, not the orange wavy chain or the striped link chain.
- **The Searing Wave** is a white-yellow blob, not a red flame crescent.
- **The slash crescents** don't show in any gameplay shot.
- **A large pale-yellow disc** sits under him in most shots.

## Ratings

1 = mechanic fidelity, 2 = animation, 3 = telegraph/reticle, 4 = VFX distinctness, 5 = bugs/oddities, 6 = clean room.

| Ability | 1 | 2 | 3 | 4 | 5 | 6 | Note |
|---|---|---|---|---|---|---|---|
| Passive: Rage / Enraged, knock heal | ok | ok | ok | fix | fix | ok | `juggernaut.png`: ENRAGED word. A large flat pale-yellow disc under him persists in `slam_windup`, `crash` and `sweetspot`: generic, and it hides his feet. |
| LMB slash | ok | ok | n/a | **fix** | ok | ok | `jug_slash` shows the blade sweeping. No two-tone magenta/yellow crescent is visible in any screenshot, and there's no tip-star shot. |
| LMB hold: Searing Wave | ok | ok | ok | **fix** | ok | ok | `wave_hold.png`: a body ring and a white cone, ok. `wave.png`: the projectile is a white-yellow oval blob, not a red flame crescent. |
| RMB tap: Finishing Slam | ok | ok | ok | ok | ok | ok | `slam_windup.png`: the magenta lane, blade cocked. `jug_slam`: a good coiled wind-up. |
| RMB sweet spot: crash | ok | ok | n/a | fix | ok | ok | `crash.png` shows CRASH and STUNNED with no distinct crash ring in the frame. |
| RMB hold: Lunge (owner note) | ok | ok | ok | ok | ok | ok | `lunge_lane_mid` (red) → `rmb_juggernaut_hold` (magenta) → `lunge_lane_full` (flash). `jug_lunge` frame 2 is a crouched coil. No screenshot of the jump-while-charging (owner note). |
| RMB air: Meteor Drop | ok | ok | ok | ok | ok | ok | `jug_meteor`: a purple disc, CRUSHED. |
| E: Warchain | ok | ok | n/a | **fix** | fix | ok | `e_juggernaut.png`: a dotted thin white line to the dummy. The wavy orange flight or striped link chain doesn't read. |
| Shift: Rampage | ok | ok | n/a | fix | ok | ok | `jug_dash`: a strong forward lean, TIP. Orange flame streaks aren't visible (white speed lines). |
| Base long dash (`jug_exdash`) | ok | ok | n/a | ok | ok | ok | Lumbers shoulder first. |
| Chain combos (spin, haul, chain lunge) | ok | ok | ok | ok | ok | ok | `jug_spin`, `jug_haul`, `jug_chainlunge` read. |
| Clean room | | | | | | ok | The horned helm, orange pauldrons and greatsword are our own. |

## FIX list (ranked by impact)

1. **Warchain look.**
   - Evidence: `e_juggernaut.png` and `e_juggernaut_recast.png` show a thin white dotted line.
   - Change, in DJFx (wavy and striped chains):
     - In flight: a 0.12 m wide orange zig-zag ribbon (sine offset, about 4 waves over the length).
     - Attached: alternating orange and dark link quads, about 0.1 m, with a yellow spark at the anchor and a barbed hook mesh at the end.
   - Make sure it isn't falling back to the generic `net_bolt` line, and retake the shot while attached.
2. **The Searing Wave must be a red flame crescent.**
   - Evidence: `wave.png`.
   - Change: in DJFx / `dj_fx.gdshader`, give the wave projectile a curved crescent mesh (about 140°, 1.4 m chord) in red #ff3a2a with an orange inner edge and a red glow trail, flying flat. Drop the white core.
3. **Slash crescents and the tip star must show.**
   - Evidence: no gameplay screenshot shows the two-tone crescent; `jug_slash` shows none.
   - Change: make the 175° crescent (magenta edge, flame-yellow fill) persist for 0.1 s at full alpha, at about 2.2 m radius, in DJFx `slash()`. Add a tip-hit screenshot with the white star.
4. **The large pale disc under him.**
   - Evidence: the white-yellow disc of about 1.6 m radius in `juggernaut.png`, `slam_windup.png`, `crash.png` and `sweetspot.png`.
   - Change: if it is the Enraged aura, replace it with a red heat-shimmer or ember aura on the body (source: a red aura with drips) and remove the flat ground disc. If it is a generic glow from `play()`, find the source and drop it.
5. **Jump-while-charging evidence.** Owner note. Add a screenshot with him airborne mid-charge with the lane up, and a strip of the release from the air (`jug_lunge` from air).
6. **Rampage flame streaks.**
   - Evidence: `jug_dash` frame 1 shows white lines.
   - Change: orange flame streaks behind (source), in the dash's `trail`.
7. **The crash needs its own ring.**
   - Evidence: `crash.png`.
   - Change: show a 3 m crash ring in a distinct colour (red-orange shock ring with cracks) at the impact; at present only words read.
8. **Execute red outline evidence.** No shot of the red outline on a foe below 35% while the Smash is ready. Add one.
