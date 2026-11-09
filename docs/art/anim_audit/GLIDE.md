# Glide pose audit (2026-11-09, ext/anim-glide-pose)

All 12 Hunters, live training match, through one glide: open, hold, a quarter turn, the Ctrl dive (toward 32.5 m/s),
the glide catching again, the glider closing into a fall, a re-open and an air dash handed back to the glider.
`--glide-shots --shots-dir=<dir>` (match camera angle zoomed on the Hunter, plus a side view; it prints these numbers
each frame). Sheets, one row per Hunter, columns open, hold, turn (match), dive (side), dive (match), catch, fall,
air dash, re-glide: [before](glide_before.jpg) (origin/main d255acbee), [after](glide_after.jpg).

Numbers in the model's frame. Tilt: the hips-to-head line forward of upright (deg; past 90 the head is below the
hips). Hands: both hands over the head (body heights). Feet: the knees behind the hips (body heights; + trails).
Bank: the lean into a left glider turn (deg; + leans in). Dive: tilt in the Ctrl dive.

| Hunter (art) | hold tilt | hands | feet | turn bank | dive tilt |
|---|---|---|---|---|---|
| gunslinger (vex) | 13 → 25 | 0.29 → 0.30 | -0.04 → 0.11 | 0 → 22 | 13 → 107 |
| juggernaut (kael) | 11 → 23 | 0.32 → 0.37 | -0.19 → -0.08 | -0 → 22 | 11 → 116 |
| ashwick (cinder) | 6 → 18 | 0.29 → 0.32 | -0.12 → 0.00 | -0 → 23 | 6 → 109 |
| tender (pip) | 11 → 23 | 0.00 → 0.06 | -0.00 → 0.05 | -0 → 22 | 11 → 112 |
| dolm (tarek) | 32 → 32 | 0.23 → 0.23 | 0.08 → 0.08 | 0 → 21 | 29 → 112 |
| archer (hem) | 49 → 19 | -0.33 → -0.44 | -0.04 → -0.32 | 2 → 24 | 48 → 113 |
| dredge (dredge) | 13 → 25 | 0.71 → 0.76 | -0.16 → -0.05 | 0 → 22 | 13 → 113 |
| rimewright (claire) | 15 → 27 | 0.28 → 0.31 | -0.14 → -0.01 | 0 → 21 | 15 → 104 |
| mage (ryzz) | 31 → 31 | 0.49 → 0.49 | -0.14 → -0.14 | 1 → 21 | 30 → 104 |
| bulwark (breaker) | 14 → 26 | 0.30 → 0.29 | 0.06 → 0.08 | 0 → 21 | 14 → 110 |
| thief (sable) | 15 → 27 | 0.27 → 0.30 | -0.18 → -0.06 | -0 → 21 | 15 → 104 |
| ostra (ostra) | 17 → 29 | -0.19 → -0.17 | -0.06 → 0.04 | -13 → 9 | 79 → 115 |

## What was wrong, worst first, and the fix
1. **No dive pose for anyone.** WardenClips never read `air.dive`: the Ctrl dive (and the opening skydive) played the
   upright glide clip with the canopy folded. Now the plunge blends to the Hero's dive clip and WardenAirTilt pitches
   the whole .glb head-down about the hips (`dive_tilt`, default 105 deg; less where the clip already leans).
2. **No lean into turns.** The clips own the whole body, so HunterAnim's glide roll never reached a .glb (Motley,
   riding the rig, leaned out of the turn: -13). Now the body banks into the glider's turn (`glide_bank`).
3. **Kael's dive clip** was `exdash`: the greatsword stood straight up out of his back. He dives on his glide clip.
4. **Lace's hold** leaned 49 deg forward, detached from her canopy; `glide_tilt` -30 hangs her under it (her
   knees now sit ahead of the hips, -0.32: the clip's bent legs; the trade for hanging under the canopy).
   Every other Hero hangs 12 deg forward (`glide_tilt`), so the legs trail instead of dangling ahead.

Hand-offs: the tilt eases (1/s 9): dive to catch 116 -> 48 deg in 0.2 s, a pull-up; glide to fall and to the air
dash fade with the glide weight (0.12 s) and the dash clip owns the body meanwhile.

## Left as is
- Lace's hands stay at her chest on the bow (hands -0.44): her glide clip keys the bow in the left hand. A hands-up
  re-key needs Blender (tools/art1/hem_clips.py `GL`).
- Meeko's canopy sits on her head: the Glider hangs on the procedural torso, not her (smaller) .glb.
- The opening skydive is a plunge too, so it takes the same head-down dive (alternative: keep it chest-down, the
  procedural rig's skydive; it would need a state key to tell the two apart).
- Weapons stay in hand while gliding (skinned weapons; the procedural Gun is stowed). No canopy clipping seen.
