# Review: Venator (id `gunslinger`), branch origin/ext/kitfix-vireo-venator @ 2c83b4d

**Verdict: PASS WITH FIXES.** The mechanics follow the footage and the owner rule:
- **Rifle:** `aim: max` to 11 m, decaying over 10 rounds, and +90% with gold numbers on a Dazed foe.
- **Grenade:**
  - A held lane with an arrow tip that marks foes in it.
  - It flies past people and sticks to a wall or the ground at the lane's end.
  - A 6 m, 100° cone shows back toward Venator before the blast (owner note met).
- **Slipstep:** follows the movement keys, and he can shoot through it.
- **Longneedle:** a wide line narrowing to a core, then recoil.

What's weak:
- No grenade is held over the shoulder while aiming.
- The slide pose tips flat with the rifle floating loose.
- The beam is plain white.
- Several payoff shots are missing.

## Ratings

1 = mechanic fidelity, 2 = animation, 3 = telegraph/reticle, 4 = VFX distinctness, 5 = bugs/oddities, 6 = clean room.

| Ability | 1 | 2 | 3 | 4 | 5 | 6 | Note |
|---|---|---|---|---|---|---|---|
| Passive: Hot Streak | ok | n/a | n/a | fix | fix | ok | No knock shot. Orange octagon blobs (the Fever pips?) float over his face in `anim_e` and `anim_dash`, hiding the head. |
| LMB: Quill Rifle | ok | fix | ok | ok | ok | ok | `lmb_aim`: the line runs to full range. `lmb_dazed`: gold numbers not caught in frame. `anim_lmb`: 4 identical frames; the shoulder kick isn't visible. |
| RMB: grenade (owner note) | ok | **fix** | ok | ok | fix | ok | `rmb_aim`: a good lane and magenta foe rings. `anim_rmb`: no grenade above the shoulder, and the rifle stays at the hip (source: the grenade cocked overhead while aiming). `rmb_flight`: the grenade isn't visible in flight. `rmb_cone`/`rmb_wall_cone`: good ember cone. `rmb_blast`: DAZED and a spark ring. |
| Shift: Slipstep | ok | **fix** | ok | fix | **fix** | ok | `anim/venator/anim_dash.png` frame 2: the body lies flat and the rifle floats detached above it. Frame 5: the rifle points down and back (source: feet-first, rifle kept up and aimed). `dash.png`: the afterimage and start ring are barely visible. |
| E: Longneedle | ok | ok | ok | **fix** | fix | ok | `e_aim_start` → `e_aim_end`: the narrowing tell is right. `e_fire`: a plain white beam with no hero colour (owner: no white flashes). `skewer.png`: no SKEWERED word or number visible. |
| Clean room | | | | | | ok | Visored cap, scarf and drum rifle are our own. |

## FIX list (ranked by impact)

1. **Slide pose bug: tipped flat, rifle detached.**
   - Evidence: `anim/venator/anim_dash.png` frames 2-3 and 5.
   - Change, in `KMovesVV["gunslinger_dash"]`:
     - Cap `p` at about 0.45 (key 0.08 has `p` 0.62 with `lift` -0.38, plus the base dash lean).
     - Keep the rifle hand attached and aimed at the cursor: don't let `fl` pull the free hand while the gun hand IK stays on the aim.
   - Check that `HunterAnim` dash lean for "medium" (`roll`) isn't also rolling the body: Slipstep should override `dash_kind`.
   - Add an ember-tinted afterimage that is clearly visible for 0.4 s, and purple-free ribbons in our colour.
2. **Grenade held overhead while aiming.**
   - Evidence: `anim_rmb.png` and `rmb_aim.png`.
   - Change: spawn a spiked charge prop in the free hand during `gunslinger_rmb_hold` (hand at `fl` y 0.62, already keyed), and hide it on throw. The kit has no prop node today (no `prop` in `gunslinger_kit.gd`).
   - Make the in-flight grenade visible: a spiked bronze mesh with an ember smear, scale about 0.3 m.
3. **Longneedle beam colour.**
   - Evidence: `e_fire.png` and `skewer.png`.
   - Change: in `VVFx.beam()` from `_fire_needle`, an ember-orange outer glow with a hot-white core and a bronze edge shimmer, so it isn't a generic white bar. Make the muzzle orb ember.
4. **Fever pips occlude his face.**
   - Evidence: the orange hexagons over the head in `anim_e.png` and `anim_dash.png`.
   - Change: move `self_pips` above the cap (+0.4 m) and shrink them, or draw them as a small arc.
5. **Rifle firing animation.**
   - Evidence: `anim_lmb.png`.
   - Change: in `gunslinger_lmb`, a per-round shoulder kick of `p` 0.12 plus `gp` 0.3 with a 0.03 s snap, and a muzzle star in bronze/ember. Today it is invisible at zoom.
6. **Payoff evidence.** Retake `skewer.png` at the hit frame with SKEWERED and the gold number. Add `lmb_dazed` with the gold +90% numbers in frame, and a knock (Slipstep back, column) shot.
7. **Slide start feedback.**
   - Evidence: `dash.png`.
   - Change: make the white start ring and the ember afterimage brighter, and add a dust scrape disc under him (source).
