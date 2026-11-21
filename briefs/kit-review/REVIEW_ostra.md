# Review: Ostra, branch origin/ext/kitfix-breah-ostra @ c26758e

**Verdict: PASS WITH FIXES**

The owner overrides are met.
- Shift is hold-to-aim, release to lob. A press in flight is ignored and a press with no charge is refused, so there are no random dashes. She keeps her height and momentum.
- RMB has 1 charge and visibly stuns the training dummy: STUNNED plus stars (`ostra_snap_hit.png`).

Other source details carried over:
- the permanent aim line, which switches to the two width rails for Snap
- a 0.2 s Snap wind-up
- a stun of 0.8-1.8 s by distance
- Swap shows both ends and a high lob over 1.7 s, and sends whoever is at the landing spot to the origin
- the seed grows over 6.5 s with a light column, recast from 0.3 s, then implodes

The gaps are visual.
- Her projectiles never show in frame: the orb, the Settled bolt and the Snap bundle.
- The lob orb, the Snap wind-up orb and the Swollen sphere render white. The reference has a dark star-orb, a black orb with a white rim and a magenta sphere.
- The arrive animation is invisible.
- No full-growth seed is shown.

Ratings: 1 mechanic, 2 animation, 3 telegraph/reticle, 4 VFX distinctness, 5 bugs/oddities, 6 clean room. Scores are 1-5, with ok or fix.

| Ability | 1 Mech | 2 Anim | 3 Tele | 4 VFX | 5 Bugs | 6 Clean | Note |
|---|---|---|---|---|---|---|---|
| Passive Swell / Swollen | 4 ok | 4 ok | n/a | 2 fix | 4 ok | 5 ok | The full turn in the air reads (`anim/os_empower.png`). The Swollen sphere is a pale white bubble (`ostra_swollen_key.png`), where the reference has a magenta sphere. |
| Aim line (always on) | 5 ok | n/a | 4 ok | 4 ok | 4 ok | 5 ok | Present, with the arrowhead. |
| LMB orb | 5 ok | 3 ok | 4 ok | 1 fix | 4 ok | 5 ok | The hand flick reads (`anim/os_orb.png`). No orb is visible in flight in any frame (`ostra_orb_key.png` shows only a white muzzle star): the violet teardrop is 0.32 m (`kit_looks.gd:78`). |
| LMB Settled bolt | 5 ok | 3 ok | 3 ok | 2 fix | 4 ok | 5 ok | The charge light at the hand is white, and a grey ring flash shows (`ostra_hot_key.png`). The long blue-violet bolt isn't visible. |
| RMB Shard Snap (owner: 1 charge, visible stun) | 5 ok | 3 ok | 4 ok | 2 fix | 3 fix | 5 ok | The two rails show. The stun reads on the dummy. The wind-up orb is a white glow (`ostra_snap_tele.png`), where the reference is a black sphere with a white rim (`0115`). The crystal-spear bundle appears in no frame. `ostra_snap_tele.png` is mislabelled: it already shows STUNNED. |
| Shift Lantern Trade (owner: no random dash, keeps height) | 5 ok | 3 fix | 4 ok | 2 fix | 3 fix | 5 ok | Both rings and the chevron link show (`ostra_swap_tele.png`). The lobbed lantern is a plain white glowing ball, where the reference has a dark blue star-orb with a purple trail. The landing "sigil" is concentric rings, not a rune that fills. `ostra_arrive` shows 6 identical frames (`anim/os_arrive.png`). The swapped dummy shows "DIZZY", but the effect is a slow, so the word is misleading. |
| E Brimseed | 4 ok | 3 ok | 3 fix | 2 fix | 4 ok | 5 ok | Only an early pop is shown: a small pale bubble, then GROUNDED and a white flash (`ostra_seed_*.png`). There's no shot of the indigo swirling drum at full size, the light column, or the implosion. |

## FIX list (ranked by impact)

1. **Projectiles must be visible: the orb, the Settled bolt and the Snap bundle.**
   - Evidence: `ostra_orb_key.png`, `ostra_hot_key.png`, `ostra_snap_key.png`. No projectile shows.
   - Change, in `kit_looks.gd` `_build`:
     - The orb: scale the violet glass teardrop to about 0.28 m radius and 0.8 m long, with a magenta trail of 1.2 m.
     - The Settled bolt: about 1.6 m long, blue-violet with a white core.
     - The Snap bundle: about 1.5 h (2.7 m) long, dark violet crystal prisms with a bright rim.
   - Check that `skin()` actually replaces the shared sphere every frame.
   - Retake mid-flight frames (`pair_demo.gd`).
2. **White where the reference is dark or saturated: the Snap wind-up, the lob orb, the Swollen sphere.**
   - Evidence: `ostra_snap_tele.png`, `ostra_swap_tele.png`, `ostra_swollen_key.png`.
   - Change:
     - Make the `hold_on` wind-up orb black (`0a0012`), opaque, with a thin white fresnel rim (`glass_mat`, not `glow_mat` white).
     - Give the lob a dark indigo star-orb with a violet trail.
     - Raise the Swollen sphere's alpha and saturation (`glass_mat(2a0020, ff4fd8, 0.45)` → rim `ff4fd8` at full strength, alpha about 0.6) so it reads magenta on bright grass.
   - Where: `kit_looks.gd:93`, `:112-113`, and the swap lob look.
3. **Lantern Trade arrival and destination.**
   - Evidence: `anim/os_arrive.png` (static).
   - Change:
     - Give `ostra_arrive` an appear-squash: `sq` -0.4 → +0.3, a robe flare, a 0.15 s scale-pop.
     - Add an implode-in burst at the destination.
     - Make the destination marker a rune sigil (an inscribed polygon or glyph ring) that fills over the 1.7 s, not concentric rings.
   - Where: `kmoves_stone.gd`, `ostra_kit.gd` (swap tick), `kit_looks.gd`.
4. **Show the Brimseed at full growth.** Add shots of the seed at about 4.5 s (the light column) and the full implosion pop (COLLAPSE), with the indigo swirl drum (`HeroZones.seed_visual`, `void_glass.gdshader`). Today only a 0.6 s pop is shown (`ostra_seed_hit.png`). Make sure the drum reads indigo, not pale blue-white.
5. **Status word.** A swapped foe shows "DIZZY", but the Trade applies a 40% slow. Use "SLOWED", or our own slow word (`ostra_kit.gd`, where it applies the slow).
6. **Retake the mislabelled shots:** `ostra_snap_tele.png` should show the rails and the black wind-up orb before release, not the STUNNED result. See also the HUD caption printed twice (REVIEW_breah FIX 7).
