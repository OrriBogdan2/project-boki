# Re-review (round 2): Dredge, origin/ext/kitfix-linwick-dredge @ 7d96b6df

**Verdict: FIX.** The round-1 list is essentially done:
- The anchor is a solid iron shape with a cyan rim.
- The rock grab is shown.
- Status words now stack.
- The barge is three quick, visible bursts.

But Brass Broadside (X) fails at its key moment. The fan telegraph reads, but the two waves of six slugs are not visible at gameplay zoom. The impact frames show only thin streaks and a small flash, nothing like the six big orbs per wave of the reference.

## Round-1 FIX items
| # | Item | Status | Evidence |
|---|---|---|---|
| 1 | A visible anchor, landing with him | Done. A dark iron anchor with a cyan rim, planted on impact. In the air he rides it down. | v2/polish/dr_anchor_slam_game.png, dr_anim_air_anchor.png |
| 2 | Overlapping status words | Done. `fx.word` stacks along the camera's up axis (fx.gd `_word_lift`): HAULED above GROUNDED. | v2/polish/dr_anim_grapnel_reel.png |
| 3 | Evidence of the grab through rocks | Done. | v2/polish/dr_grapnel_over_rock_game.png, dr_anim_grapnel_over_rock.png |
| 4 | Wrong Grounded toast during the reel | Done. `KitStatus.apply(..., toast)` gives "reeling: no jump or glide (the barge still works)", with no overhead word on the caster. | kit_status.gd diff; v2/polish/dr_anim_grapnel_reel.png |
| 5 | Palette on bright ground (slugs, barge, quake, rope) | Done. A red spiky barge burst, violet rest slugs, and a thicker braided rope. | v2/polish/dr_anim_barge.png, dr_gun_slugs_hang_close.png |
| 6 | Static reel and throw | **Partly done.** The reel strip still shows very similar frames; the rope pulse and the hand alternation are subtle. | v2/polish/dr_anim_grapnel_reel.png |
| 7 | `dr_flex` and shot recoil | Done. | v2/polish/dr_anim_salvage.png, dr_anim_gun.png |
| 8 | Mislabelled shots, pink sphere | Done. | v2/polish/dr_gun_idle_line_game.png |

## New checks
- **Ultimate (Brass Broadside).**
  - Mechanics match the reference: a 1.1 s planted charge with a 105° fan locked at the press, then 2 waves 0.6 s apart of 6 slugs, with Anti-Heal and a per-cast bond.
  - **Telegraph:** good. A brass fan grows on the ground (v2/ult/dredge_ult_telegraph.png).
  - **Payoff:** the waves don't read. In v2/ult/dredge_ult_wave1.png, v2/polish/dr_ult_wave_game.png and the strip v2/ult/dredge_ult_strip.png you see two faint lines and a small spark at the gun.
    - The slugs are `spawn_shot` projectiles at size 0.45, moving at 29.5 m/s over 5.9 m, so they live about 0.2 s and are tiny.
    - There are no six orbs, and no wave-wide flash or crescent at gameplay zoom.
  - The fan is a pale cream at low alpha. It is close to white on bright grass; give it more brass saturation.
- **Body and dash.**
  - Body: `size` 1.0 and `bulk` 1.3 (as tall as a heavy, 1.3× as wide).
  - Barge (owner note): 3.2 m in 0.16 s per charge with a 0.22 s gap, seen travelling with a red burst at each start. It goes through `travel()`, so the dash feel applies.
  - The main-session tuning change is flagged in the docs and commits.
- **Readability.** Good, except the ult waves and the reel.
- **Effects.** In brass, violet and red, with the ult as the exception.
- **Bugs.** None new.
- **Clean room.** OK. The diving-bell helm, the rope drum and the scattergun are our own.

## FIX list
1. **Make the Broadside waves read** (`scripts/arch/kits/dredge_blast.gd`).
   - Draw each slug as a large (about 0.6–0.7 m) brass teardrop orb with a dark core, alpha-blended, with a 1 m smear, alive long enough to be seen. Either slow the visual or add a 0.12 s hold at the fan edge.
   - Add a brass sunburst at his fists and a crescent sweep across the whole fan on each wave. The code comments say this exists (line 143), but it doesn't show in any frame.
   - Retake wave 1 and wave 2 at the release frame.
2. Raise the fan fill's saturation and alpha (`FAN_COL` ffcf70 reads cream), so the telegraph isn't near-white on grass.
3. **Pair-level text (must fix).**
   - `content/archetypes/dredge.json:8` card `x`: "Ultimate (X, level 6)".
   - Remove the key letter, as for Linwick.
4. Nit: make the reel more visible (round-1 item 6). Swing the hands ±0.5 and make the rope width pulse on each haul.
