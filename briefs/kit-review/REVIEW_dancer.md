# Review: Dancer (id `thief`), branch origin/ext/kitfix-dancer-juggernaut @ beeb14f

**Verdict: PASS WITH FIXES.** The biggest change landed. The LMB is now ranged Arc Bolts:
- From alternating hands every 0.45 s.
- Cursor-placed with `AimMode.CURSOR`, clamped to 12 m.

The rest follows the source:
- Vault, then an empowered 3.5x bolt that resets the Vault on a hit.
- The Bola has a 0.4 s chevron lane, grounds the first foe, stuns two, and bounces off walls.
- The dagger sticks or lands, and a recast blinks through cyan afterimages.
- The R is removed, with Jackpot folded onto 5 Marks.

The weak points are the animations of the throw, the bola whirl and the knife, which barely move. The bolt's own look is also thin.

## Ratings

1 = mechanic fidelity, 2 = animation, 3 = telegraph/reticle, 4 = VFX distinctness, 5 = bugs/oddities, 6 = clean room.

| Ability | 1 | 2 | 3 | 4 | 5 | 6 | Note |
|---|---|---|---|---|---|---|---|
| Passive: Marks + knock heal | ok | n/a | ok | ok | ok | ok | Gold diamonds over the target are readable (`thief.png`). No shot of the crimson knock star or the green pillar. |
| Passive trigger: Jackpot (5 Marks) | ok (fold) | fix | ok | ok | ok | ok | `jackpot_ring.png`: the cyan ring and inner rim read well. `thf_volley`: no visible arm snaps. |
| LMB: Arc Bolts | ok | **fix** | ok | fix | ok | ok | Aim line ends at the cursor with a tick. `anim/thf_lmb.png`: frames 4-6 barely move. The arm whip and the 30° torso twist aren't readable; the bolt is a thin pale streak. No shot of the fizzle at the cursor. |
| LMB empowered | ok | fix | fix | ok | ok | ok | `thf_primed` frames 1-2: a good gold lightning streak. `primed.png`: the aim line is barely gold (pale yellow, thin). |
| Shift: Vault (cartwheel) | ok | ok | n/a | ok | ok | ok | `thf_vault` frames 2-4: a real sideways cartwheel. The arc trail is visible. |
| Base long dash (`thf_exdash`) | ok | fix | n/a | ok | ok | ok | Reads as a stumble into the dummy. The flick or tumble isn't clear. |
| RMB: Bola | ok | **fix** | ok | ok | ok | ok | `bola_lane.png`: a good chevron lane. `bola.png`: GROUNDED/STUNNED/TANGLED on two. `thf_bola`: no overhead whirl visible, only the arm forward with a flash at frames 4-5. |
| E: Shadow Knife | ok | fix | ok | ok | fix | ok | `knife_marker.png`: the white circle. `thf_knife`: no visible spin into a side-arm throw. `e_thief_recast.png`: no afterimage chain in the shot (`thf_blink` does show cyan rings). |
| Clean room | | | | | | ok | The design (orange hood, ring blades) is our own. |

## FIX list (ranked by impact)

1. **Make the alternating throw readable.**
   - Evidence: `anim/anim/thf_lmb.png` frames 3-6 are near-identical; the arms are hidden under the hood.
   - Change, in `KMovesDJ["thf_lmb_r"/"thf_lmb_l"]` (kmoves_dj.gd):
     - Add an anticipation key at 0.03 s, with the arm back past the shoulder (`fr`/`fl` z +0.3).
     - Whip to full extension at 0.08 s (z -0.6) with a 30° torso twist (`y` ±0.5).
     - Overshoot at 0.15, settle by 0.35.
     - Widen the stance (`legs`).
   - Add a small gold muzzle star at the throwing hand.
2. **The bola whirl overhead during the lane.**
   - Evidence: `thf_bola.png` frames 1-3 show no overhead arm.
   - Change: in `thf_bola`, raise the throwing hand above the head (`fr` y +0.7) and circle it: key the arm through 3 positions per 0.13 s, or drive it from the kit with a hand IK target.
   - Show the two bola weights orbiting the hand (DJFx) during `_tick_bola_cast`, then a forward lunge at the sling.
3. **Knife throw spin and blink chain evidence.**
   - Evidence: `thf_knife.png` and `e_thief_recast.png`.
   - Change: in `thf_knife`, add a 180-270° body spin (`fy`) before the side-arm release at 0.12 s. Confirm the 5 cyan ghosts persist about 0.3 s along from → to (`DJFx` ghost chain), and retake the recast shot one frame after the blink.
4. **The bolt projectile looks thin.**
   - Evidence: `thief.png` and `before_dancer_lmb`.
   - Change, in DJFx: make the chakram 0.45 m (about 0.25 bh) with a bright gold comet head and a short orange flame tail, not a hairline.
   - Add the blue-violet fizzle puff at the cursor and a screenshot of it (cursor short of the dummy).
5. **The empowered aim line must be clearly gold.**
   - Evidence: `primed.png`.
   - Change: in `ThiefKit._tick_aim_line()`, set `alpha` to about 1.0, `lw` 0.09, and the colour #ffc23a, with a glow. Today it reads pale cream.
6. **Knock feedback evidence.** There's no screenshot of the crimson 4-point star on the knocked foe or the green heal pillar on her (`on_knock`). Add one: it is the payoff moment.
7. **Jackpot volley pose.**
   - Evidence: `thf_volley`.
   - Change: alternate free-arm snaps out to each side every 0.2 s (`fl`/`fr` alternate x ±0.4), so the volley reads as her throwing.
8. **Base long dash.**
   - Evidence: `thf_exdash`.
   - Change: a light hero should flick or tumble. Add an `fz` side-roll or a crouched skid with a cyan streak, instead of the upright slide.
