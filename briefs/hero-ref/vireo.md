# Vireo (`mage`): reference sheet from the Joule footage

Source: `/home/claude/svvid/hero/vireo/frames` (all.mp4 0 to 81 s, 5 fps, frame N = second (N-1)/5).
Key frames copied to `/home/claude/hero-ref/vireo/`. Compared against origin/main 4f82978 (a descendant
of 7881774; origin/main moved on while this pass ran) in the worktree `/home/claude/ref-vireo`.

Scale used: the hero is about 40 px tall (head to feet) in these frames. The training dummy stands about
215 px (about 5.5 body heights) in front of the hero in most shots. The camera is top-down with a slight
tilt, so vertical distances on screen are a little foreshortened. All times come from frame counts
(1 frame = 0.2 s, so every timing is ±0.1 s).

The clip ends with the in-game hero info panel (frames 0396 to 0403, `0398.jpg`). That panel uses a
different keymap: E = spear, SPACE = Surge, L SHIFT = javelin, Q = ult. It adds rules the slot cards
leave out:
- LMB applies 1 Static stack.
- The spear is HOLD and release, and it stuns if the target hits a wall.
- Surge reset: "Hitting Static Charged enemies resets Surge's cooldown and does bonus damage".
- The javelin applies 2 Static stacks.
- The ult is PRESS, then reactivate. It applies Static and spawns Lightning Orbs.

## 1. Source summary

| Slot (video) | Ability | Input | Aim type | Cooldown / cost | Effect |
|---|---|---|---|---|---|
| Passive | Gathering Storm | n/a | n/a | n/a | Attacks and spells apply Static. At 4 stacks the target is fully Static Charged. Dashing through a charged target consumes the charge for heavy damage. Spells can spawn Lightning Orbs; collecting one resets Surge's cooldown. |
| LMB | Lightning Bolt | tap or hold (auto-repeat) | skillshot along the cursor direction; always flies to **max range** | 0.8 s per bolt | A fast bolt that applies 1 Static. Damage 117 on the dummy (later 146). |
| RMB | Lightning Spear | hold, then release | skillshot along the cursor direction; flies to **max range** and stops on the first enemy hit | 7 s, 20 mana | Damage 472 (later 590) plus a knockback. Stuns if the target is knocked into a wall. Drops one Lightning Orb at the impact point. |
| L SHIFT | Surge | hold to charge, release to dash | direction from the cursor; length set by **charge time, not by cursor distance** | 6.7 s, 25 mana | Invulnerable lightning dash. Passing through a charged enemy detonates it (1078 / 1348 damage) and refunds Surge. Passing through an orb also refunds Surge. |
| E | Lightning Javelin | press to place, then aim a direction | ground spot **at the cursor**; direction set by the cursor after placement | 9.2 s, 25 mana | 0.8 s later lightning strikes the spot: 291 damage, 2 Static. Enemies (and orbs) are pulled along the chosen direction and become GROUNDED. |
| R | Eye of the Storm | press to launch, reactivate to land | landing spot **at the cursor**, clamped inside a large ring | 37.5 s, 50 mana | Leaps into the air, during which the camera zooms out. The hero then crashes down at the chosen spot: 115 damage AoE, applies Static, spawns Lightning Orb(s). |

## 2. Per-ability detail

### Passive: Gathering Storm (frames 0001 to 0025, card in `0003`; the info panel in `0398`)
- **Input:** none.
- **Stacks:** each LMB bolt adds 1 stack, the javelin adds 2, and the ult adds stacks too.
- **Stack display:** nothing clear shows for stacks 1 to 3 (at most a faint violet glow above the bar,
  `0005`, `0009`). On the 4th stack (`0016`):
  - A tall gold lightning bolt drops from the sky onto the target.
  - A yellow-lightning-on-violet-disc icon appears above its HP bar.
  - A glowing white-gold orb sits on its chest from then on (`0017` to `0025` and later).
  - The charge lasted at least the 8 frames shown (1.6 s or more). The decay time is not shown.
- **Detonation** (`0135`): dashing through a charged target shows a magenta damage number with a magenta
  bolt glyph (1078 at `0135`, about 1348 at `0336`) and briefly tints the target red. At the same moment a
  large green-yellow starburst flashes where the hero is (about 4 body heights across). After that,
  2 to 4 green vertical light columns stand on the hero for about 1.6 s (`0136` to `0142`), with green
  sparks. The Surge icon shows ready immediately (`0135`, `0142` HUD).
- **Orb collection** (`0165`) uses the same green starburst and green columns. Mark the green
  "refund" columns as `distinctive`: we keep the function but use our own colour and shape.
- **Sound:** no audio in the main video.

### LMB: Lightning Bolt (frames 0001 to 0040, card `0033`)
- **Input:** hold to auto-fire, one bolt every 4 frames (0.8 s). Damage numbers land at frames 4, 8,
  12 and 16. The card shows a 0.8 s cooldown, and the HUD icon counts it down ("0.3" at `0033`). There is
  no magazine and no reload.
- **Aiming:** the bolt goes in the cursor's direction and **travels to max range no matter where the
  cursor is**:
  - At `0038` the cursor is only about 150 px away, yet the indicator and the bolt run on to about 300 px.
  - At `0032` and `0033` the bolt passes the cursor and keeps going.
  - Max range ≈ 300 px ≈ 7.5 body heights.
  - This matches Ghost's autos, not Myth's cursor-placed shots.
- **Reticle and indicator:**
  - The cursor is a small white **ring with a centre dot**, about 25 px across, drawn with a dark
    outline and 4 short gaps (`0016` zoom).
  - A thin white line at about 30% opacity runs from the hero, **through the cursor, to max range**,
    and ends in a small arrow tick (`0026` to `0040`).
  - The line is always shown while this hero aims, not only while firing.
- **Animation** (`0003` to `0020`, hero zoom): the hero alternates hands.
  - On each cast she twists her torso and flings one arm forward (`0003`, `0006`, `0010`, `0015`), then
    settles back to a wide stance with both arms out (`0004`, `0008`, `0012`).
  - Small gold sparks pop around her feet with every cast.
  - She faces the cursor.
  - She stood still in every LMB shot, so the footage doesn't show whether she can walk while firing.
- **VFX:**
  - The projectile is a short orange-gold comet streak (about 30 px) with a thin white tail.
  - It is fast, roughly 0.4 s to max range (about 700 to 800 px/s, or about 18 body heights per second).
  - On impact a fan of 3 to 5 gold lightning splinters sprays back toward the caster (`0012`, `0014`).
- **Numbers:** 117 damage (146 in later segments, likely a level or power difference). Applies 1 Static.

### RMB: Lightning Spear (frames 0041 to 0090, card `0060`)
- **Input:** hold, then release (info panel: "HOLD and release to throw"). Timing in all 3 casts:
  1. Press at `0043`, `0057` and `0078`: a flash, and a tall gold spear appears upright at her right side.
  2. Hold for 4 frames with the spear crackling in her hand (`0044` to `0047`).
  3. **Her whole body flashes white for 1 frame** (`0048`, `0062`, `0083`). This reads as the
     "fully charged" flash.
  4. The throw comes on the next frame (`0049`, `0063`, `0084`).
  5. So press to throw is about 1.2 s every time. The player may have released on the flash, or the
     throw may be automatic at full charge.
- **Aiming:**
  - The throw follows the cursor's direction and flies to **max range** unless it hits something. At
    `0049` to `0050` it passes the cursor and ends near the end of the lane.
  - The lane is the same length as the LMB line (about 300 px) and **does not grow while held**.
  - The target is not shown being slowed.
  - She did not walk during the hold, so the footage doesn't show whether moving is allowed.
- **Reticle:** the LMB's single line becomes a **narrow double-line lane** (two thin white rails about
  6 px apart, with small chevrons inside). It runs from the hero to max range and stays up for the whole
  hold (`0044` to `0048`). The cursor ring stays the same.
- **Animation:**
  - Press: the spear materialises in a burst (`0043`).
  - Hold: she stands side-on with the spear raised by her right shoulder. Gold arcs crawl over her and
    the spear.
  - Flash: a white body flash (`0048`).
  - Throw: an overarm throw. The spear leaves as a long gold lightning streak, and she recovers in
    about 0.4 s.
  - Mark the hand-summoned lightning spear as `distinctive`: keep the held-projectile idea, use our own
    shape.
- **VFX:**
  - Flight is nearly instant: a 200 px gold streak that reaches the dummy within 1 frame (`0063` to
    `0064`).
  - The impact is a white-gold explosion with a puff cloud about 2.5 body heights wide (`0064`, `0085`).
  - The target turns pink or magenta for about 2 s while displaced (`0065` to `0074`).
  - A white shock ring expands around it (`0068`).
- **Knockback:**
  - About 1 body height on open ground (`0064` to `0066`).
  - When the dummy hit the pillar (`0085` to `0090`) it was **STUNNED**: the label sits above the bar
    for more than 1 s.
- **Lightning Orb** (`0068`, `0087` to `0095`, `0151` to `0160`):
  - It appears at the impact point the frame after the hit, on the dummy as well as on hunters.
  - It is a crackling yellow sphere about 0.5 body heights across, hovering low.
  - Short yellow arcs jump between the orb and the nearby enemy.
  - It sat for at least 3 s (`0151` to `0163`) before being collected.
- **Numbers:** 472 damage (590 in a later segment), 7 s cooldown, 20 mana.

### Shift: Surge (frames 0095 to 0172; card `0102`; combos `0128` to `0172`, `0277` to `0300`, `0361` to `0369`)
- **Input:** hold to charge, release to dash.
  - The cooldown starts on press: the HUD shows 7 at `0102` while she is still holding.
  - The charge from press to full length takes about 0.6 s (`0101` to `0104`).
  - Releasing early gives a shorter dash: at `0131` the end circle is on the dummy, at `0132` just past it.
- **Aiming:**
  - The direction follows the cursor and keeps tracking it while held.
  - **The length comes from the charge, not the cursor.** At `0102` the end circle sits about
    180 px out while the cursor is at about 290 px; at `0104` the circle has grown past the cursor.
  - Full length ≈ 310 px ≈ 7.5 to 8 body heights, about the same as the LMB range.
- **Reticle:**
  - The lane is a pair of faint white rails out to max range.
  - Its end is marked by a **large white circle**, about 2.5 body heights across, with 4 cardinal tick
    marks and a 4-point star glint at the centre (`0102`).
  - The circle slides outward along the lane as the charge grows (`0102`, `0103`, `0104`).
  - The cursor ring stays where the cursor is.
- **Animation:**
  - Press (`0101`): a vertical gold lightning bolt slams down onto her. Mark this as `distinctive` as
    an effect, though it is a useful "charging" tell.
  - Hold: a low crouch, leaning into the dash, with gold crackle around her (`0103`).
  - Release (`0105`): her body becomes a **yellow lightning silhouette**, labelled **INVULNERABLE**.
  - Travel (`0106` to `0108`, about 0.6 s for full length; the camera follows): a long gold streak
    with a 3 to 4 body-height trail.
  - Arrival (`0109`): a gold ring burst about 3 body heights across with radial spark needles.
  - She re-forms and recovers over about 0.4 s (`0110` to `0111`).
- **Combo and recast:**
  - Dashing through a charged dummy detonates it (`0133` to `0135`), and Surge is ready again at once
    (HUD `0135`, `0142`).
  - Dashing through a Lightning Orb also refunds it (`0161` to `0165`; the HUD shows Surge ready at
    `0165`). She then dashes straight back (`0168` to `0171`).
  - When the dashing body crosses the dummy but no detonation happens, it takes a 146 hit (`0165`, `0300`).
- **Numbers:** 6.7 s cooldown, 25 mana. Detonation 1078 to 1348. Pass hit 146 (probably the dash's own
  damage).

### E: Lightning Javelin (frames 0181 to 0226 and 0277 to 0285, card `0200`)
- **Input:** press to place, then aim a direction.
  - At `0184` the placement circle appears where the cursor was on the previous frame (`0183`).
  - The cursor then moves off to one side. A translucent arrow lane drawn from the circle shows the pull
    direction.
  - About 1 frame later (`0185` to `0186`) the strike is committed. This was either a release or a
    second click; the video can't tell which.
  - The committed disc carries a gold **chevron on its rim pointing toward the cursor**: the pull
    direction (`0186` to `0189`, and `0198`).
- **Aiming:** the area is placed **at the cursor** (clamped to range), and the pull goes **in the
  direction chosen after placing**. It is not the direction from the hero to the target: at `0186` the
  hero is below the disc but the chevron points left.
- **Reticle:**
  - Placement shows a white circle about 2 body heights across, with 4 tick marks, plus the direction
    arrow lane (`0184`).
  - Once committed (`0186` to `0189`) it becomes a dark blue-violet disc on the ground with an
    orange-gold crackling rim and the gold chevron.
  - Then a gold pillar of light descends onto it over 3 frames, narrowing as it lands (`0187` to
    `0189`). This is the countdown.
- **Timing:** from the disc appearing to the strike is 4 frames (0.8 s, `0186` to `0190`). The strike
  flash is white-gold, about 2 body heights across (`0190`). Lightning forks crackle at `0191`, and a
  dark scorch lingers about 0.4 s (`0192`).
- **Effect on targets** (`0197` to `0209`, `0212` to `0224`):
  - 291 damage.
  - The target flashes red and white and is labelled **GROUNDED**.
  - It slides along the ground (no launch arc) about 4 body heights over about 1 s, roughly toward the
    chosen direction.
  - It is wrapped in 2 to 3 spinning yellow electric rings (shackles) that last 1.5 s or more.
- **Orbs:** the javelin also flings a Lightning Orb. At `0278` to `0285` an orb sitting under the strike
  is thrown about 6 body heights to the left as a gold streak. She then Surges through it for the reset
  (`0287` to `0291`).
- **Animation:** a one-arm sweep or throw toward the spot with gold sparks (`0185` to `0186`). It is
  small, with no long wind-up.
- **Numbers:** 291 damage, 2 Static stacks, 9.2 s cooldown, 25 mana.

### R: Eye of the Storm (frames 0349 to 0395, card `0360`)
- **Input:** press to launch, reactivate to crash down.
  1. Press (`0349`, `0372`): a large gold ring about 15 body heights across, centred on the hero,
     shows the landing range.
  2. About 0.4 s later she crouches and leaps with a white dust puff (`0352`, `0374`).
  3. In the air she is labelled MIDAIR, the **camera zooms out**, and the ground inside the ring
     darkens to a deep violet with lightning veins (`0353` to `0357`, `0375` to `0383`).
  4. She stayed up 1.2 to 1.8 s in the two casts. Then, labelled INVULNERABLE, she streaks as a
     lightning bolt to the spot (`0379` to `0383`).
  5. She lands with a white cloud and a small orange ring at the landing site (`0358`, `0384`).
  6. A gold pillar and radial starburst follow (`0360`, `0385`).
- **Aiming:** the landing spot is **at the cursor**, clamped inside the ring. A gold four-bracket
  crest marker sits at the cursor on the ground (`0376`).
- **Effect:** 115 damage on the dummy (`0385` to `0386`). An orb appears beside the dummy afterwards
  (`0387` to `0395`). It applies Static.
- **Numbers:** 37.5 s cooldown, 50 mana.
- **For us:** R is the Boki Merge, and the doc drops this ult. See gap 12.

## 3. The combo the kit is built around
1. Bolts (1 stack each), the javelin (2) or the ult build 4 Static on a target. When it reaches 4, a sky
   bolt and the charged icon show it.
2. Surge through the charged target: a magenta number of about 9 to 11 LMB hits (1078 / 1348), and
   Surge back at once.
3. The spear sets up the second dash. It knocks the target back (and stuns it against walls) and
   leaves an orb at the impact point. The javelin can fling that orb to a better spot. Dashing through
   the orb resets Surge again, so Joule chains dash, orb, dash (`0161` to `0171`, `0287` to `0300`).

## 4. Key frames (`/home/claude/hero-ref/vireo/`)
| File | Caption |
|---|---|
| 0016.jpg | 4th Static stack: a sky bolt hits the dummy and the charged icon appears above its HP bar |
| 0033.jpg | LMB: the white line runs from the hero, through the cursor ring, to max range; the bolt is past the cursor; Lightning Bolt card |
| 0038.jpg | LMB with the cursor close: the line still extends to the same max range |
| 0043.jpg | RMB press: the spear materialises upright at her side (flash) |
| 0048.jpg | RMB: the double-rail lane to max range, and the 1-frame white body flash just before the throw |
| 0064.jpg | Spear impact on the dummy: 472, white-gold blast |
| 0068.jpg | After the spear: the dummy knocked back (pink tint, shock ring), the Lightning Orb left at the impact point |
| 0088.jpg | Spear into a pillar: STUNNED label, orb on the ground |
| 0102.jpg | Surge held: the big end circle (4 ticks, star glint) partway along the lane, short of the cursor; Surge card; Shift icon already on 7 |
| 0105.jpg | Surge release: the hero as a lightning silhouette, INVULNERABLE |
| 0109.jpg | Surge arrival: gold ring burst with radial sparks |
| 0135.jpg | Detonation: magenta 1078 with a bolt glyph on the dummy, green-yellow flash on the hero, Shift icon ready |
| 0165.jpg | Surge through an orb: green flash and sky bolt, 146 pass hit, Shift ready |
| 0184.jpg | E placement: the circle at the previous cursor spot plus the direction lane |
| 0188.jpg | E committed: dark disc, crackling rim, chevron toward the cursor, gold pillar descending |
| 0203.jpg | E hit: 291, GROUNDED, dummy dragged inside yellow shackle rings |
| 0283.jpg | E flings a Lightning Orb left (the orb as a gold streak) |
| 0376.jpg | R airborne: camera zoomed out, darkened ring area, gold crest marker at the cursor |
| 0385.jpg | R landing: gold pillar and starburst, 115 |
| 0398.jpg | In-game info panel with the extra rules (HOLD spear, wall stun, Surge reset, javelin = 2 stacks, ult = reactivate) |

## 5. Gaps against ours, ranked by how much they change the feel

Our files: `scripts/arch/kits/mage_kit.gd` (the kit), `content/archetypes/mage.json`,
`content/weapons/coilcaster.json`, `scripts/match/hunter_anim.gd` (KMOVES `mage_*`),
`scripts/match/match.gd` `_update_aim()` (the global aim line) and `scripts/ui/hud.gd`
`_draw_crosshair()`.

1. **[mechanic] [numbers] Orbs drop on every spear hit, at once, and are the main reset engine.**
   - Source: the orb appears at the impact point the next frame, on any enemy including the dummy.
     The ult also spawns orbs.
   - Ours: `_coil_hit()` drops a mote only when `f is Hunter`, and only after `mote_t` 0.5 s.
   - The source loop is dash, orb, dash. Ours almost never offers the second dash outside a duel.
   - Change: in `_coil_hit()`, call `_drop_mote` on every foe hit (keep it from spawning on a miss), at
     the impact point, with `mote_t` at about 0.05.
   - If the merge keeps a flavour of the ult, let `add_spark` reaching Live also spawn a mote (see
     open question 3).
2. **[mechanic] Surge's cooldown starts on press.**
   - Source: the cooldown starts on **press** (HUD 7 at `0102`), not on release. The detonation refund
     already matches (`_blowout()`).
   - Change: in `on_dash()`, spend the charge when the hold starts. Today `spend_dash` runs in `_run()`.
   - If you do this, make `_end_wire()` on a cancel (stun, root or Grounded) refund the spent charge,
     or accept the loss the way the source does.
3. **[aim] [reticle] LMB: the line and the bolt go to max range, past the cursor.**
   - Our bolt already flies its full `range` (`hunter.gd` primary fire, `life = rng / spd`).
   - But `match.gd _update_aim()` clamps the aim line to `min(cursor distance, range)`, so ours reads
     as cursor-placed.
   - Source: a thin white line about 30% opacity, always out to max range, ending in a small arrow
     tick.
   - Change: in `_update_aim()`, read a weapon flag (say `"aim_full": true` in `coilcaster.json`) that
     draws the line at the full `range` and adds an end tick.
4. **[numbers] LMB cadence and ammo.**
   - Source: one bolt every 0.8 s, no magazine, no reload. A bolt is worth about 1/4 of a spear and
     about 1/9 of a detonation.
   - Ours: `coilcaster.json` fires every 0.42 s with `mag` 12, `reload` 1.3 and `pierce` true. The
     footage never shows a bolt pierce; the info panel just says "Fire a bolt of lightning".
   - Change: set `rate` to about 0.8, scale `dmg` up so the DPS stays where it is (about 15), and drop
     the mag (or make it huge). Consider `pierce: false`, a design call.
   - With a 0.8 s cadence, each Spark matters, and it takes about 2.4 s of bolts to make a foe Live,
     as in the source.
5. **[anim] [vfx] RMB is a held, summoned spear, not a coil palm-thrust.**
   - Source: a flash, then a tall spear upright in her right hand, held about 1 s with crackle. A
     1-frame white full-body flash, then an overarm throw that leaves a long lightning streak.
   - Ours: `mage_rmb` has the coil drawn back, a lunge and a palm thrust, with no held prop.
   - Changes:
     - A new KMOVES `mage_rmb_hold` (hold: arm raised by the shoulder, side-on stance) and
       `mage_rmb` (overarm release).
     - A visible held prop in `rmb_hold_tick`, which is a natural home for our own copper-rod javelin
       look.
     - When `rmb_t` reaches `hold`, a body flash (`m.fx.flash` on `h`) as the "full" tell.
6. **[mechanic] [reticle] RMB: fixed max-range lane, and charge does not change range.**
   - Source: the lane is about 7.5 body heights from the press and does not grow while held.
   - Ours: `coil.range` lerps 6 to 13 m with the hold, and the telegraph shows only the max range.
   - Change: a fixed `range` in `mage.json` and `_coil()`, keeping the damage and push lerp if wanted.
   - The lane should be the double-rail look, narrower than the dash lane: `tele_lane` width about 0.3,
     not 0.5.
   - Also check `min_t` 0.33. The source shortest press to throw seen was 1.2 s every time (see open
     question 1).
7. **[reticle] Surge end marker.**
   - Source: a big end circle about 2.5 body heights across with 4 tick marks and a star glint,
     sliding out along faint twin rails. The cursor plays no part in the length.
   - Ours: `on_dash()` creates `telegraph_circle(h.pos, 0.7, ...)` (radius 0.7, much smaller) and a
     lane of width 0.9.
   - Ours already ignores cursor distance, so that part matches.
   - Change: radius about 1.5, add ticks and a centre glint in `fx.telegraph_circle` (or a new
     `fx.end_marker`), and thin the lane to rails.
8. **[vfx] [anim] Surge look.**
   - Source:
     - A sky bolt onto the hero on press.
     - A crouch while held (ours `mage_dash` matches).
     - On release the body becomes a lightning silhouette with an INVULNERABLE label, and a long
       3 to 4 body-height trail.
     - On arrival, a ring burst about 3 body heights wide with radial needles.
   - Ours: a `bolt` line from start to end and the "roll" trail.
   - Changes:
     - In `_run()`, hide or tint the model as an emissive silhouette for `time`.
     - Add an arrival `m.fx.ring` plus `burst` at the end point (`m.later(time, ...)`).
     - Add a vertical `m.fx.bolt` onto `h` in `on_dash()`.
9. **[mechanic] [aim] E: place, then pick the direction.**
   - Source: the circle locks at the cursor, then the cursor sets the pull direction, shown by an
     arrow lane and a rim chevron. Targets are dragged along the ground about 4 body heights, without
     a launch.
   - Ours: `cast_e()` takes the direction from hero to spot, and `_strike()` uses `impulse(dir*push,
     lift 6.5)`, which tosses them up.
   - Changes:
     - Make E a hold. Press locks `at`, holding draws `tele_lane` from `at` toward the cursor, and
       release fixes `dir = (cursor - at)`.
     - A plain tap keeps today's direction.
     - Set `lift` to about 0.5 so it is a slide, not a fling.
     - The doc's note "our E has no hold-to-place" should become "hold to aim the pull".
10. **[numbers] E: delay, stacks and Grounded.**
    - Source: 0.8 s from the commit to the strike, 2 Static, GROUNDED with shackle rings for 1.5 s or
      more, and a 9.2 s cooldown.
    - Ours: `delay` 0.55, 1 Spark (`add_spark(f)`), `grounded` 1.2, `cooldown` 12.
    - Change: `delay` to 0.8, `add_spark(f, 2)` in `_strike()`, and `grounded` to about 1.5.
    - Cooldown: keep the source's ratio to the spear and dash, which is E < spear×1.3 and
      dash ≈ spear.
11. **[numbers] Cooldown ratios.**
    - Source: spear 7, Surge 6.7, javelin 9.2 (about 1 : 1 : 1.3).
    - Ours: RMB 10, dash 9, E 12.
    - Keep our absolute pacing if needed, but the source lets Surge come back as often as the spear
      even without resets. Consider 8 / 8 / 10.5.
12. **[vfx] Telegraph for E.**
    - Source: a dark disc, a crackling gold rim and a light pillar descending as the countdown.
    - Ours: a filling circle (`tele_circle`), and the strike is a `bolt` from 9 m up.
    - Change: add a narrowing vertical beam over the delay, using `fx` in `cast_e()` and `_strike()`.
    - The descending pillar is generic enough to keep; give it our teal and copper.
13. **[vfx] Static display.**
    - Source: stacks 1 to 3 are nearly invisible. At 4, a sky bolt, an icon over the HP bar and a
      chest glow.
    - Ours: a pip ring that grows from the first Spark. Ours is more readable, so keep it.
    - Add the sky bolt (ours has `m.fx.bolt` arcs to the ground while Live; add one bolt from above at
      the moment of going Live in `add_spark()`).
14. **[anim] LMB alternating hands.**
    - Source: each bolt is thrown from alternating hands with a torso twist, with sparks at the feet.
    - Ours: KMOVES has no mage LMB move (stock firing pose; the cast pose in `hunter_anim.gd` around
      line 1824 is one palm out).
    - Change: a light additive `mage_lmb_l` / `mage_lmb_r` alternating per shot, played from
      `on_fire`, or the hunter's shot hook.
15. **[mechanic] Spear knockback size.**
    - Source: about 1 body height on open ground, then a stun against walls. The "pink" displaced
      state lasts about 2 s.
    - Ours: push 8 to 14 (impulse) with an instant collision check along the throw.
    - Verify in-game that our push lands about 1.5 to 2 m and not much more.
16. **[sfx]** No audio in the main video. Nothing to copy.
17. **[mechanic] R (dropped).**
    - The source ult is a long-range relocate that spawns orbs and applies Static.
    - Under the Merge rule it stays dropped.
    - Possible fold: the dash refund already covers mobility. If the merge wants a hook, "landing
      spawns a mote" fits `_drop_mote`.

## 6. Rename
Vireo is not one of the renamed heroes in this pass, so there is nothing to list.

## 7. Open questions
1. **Spear charge:** is the throw automatic at full charge? Every cast was 1.2 s from press to throw,
   with the white flash 1 frame before. Does charge scale damage or knockback (472 vs 590 were at the
   same distance)?
2. **Detonation:** does it also spawn an orb? Surge was ready at `0135` with no orb visible. The info
   panel says detonation resets the cooldown directly. Ours resets it directly too.
3. **Orb duration, and the zap:** does an orb expire, and does it zap nearby enemies? Short arcs from
   the orb to the dummy appear at `0066` to `0074`.
4. **Static decay time:** the charge was still up after about 2 s. The decay time isn't shown.
5. **Movement while casting:** can she move while holding the spear or Surge, or while firing the LMB?
   The hero never walked during a cast in the footage.
6. **E input:** is the commit a release of E or a second click? In both cases about 1 frame passed
   between placing and committing.
7. **Static from the spear:** does the spear apply a stack? It isn't shown, and the info panel doesn't
   say.

## Ultimate (on X)

**Source:** Joule, Eye of the Storm. Card: "Launch into the air, then pick a location on the ground to forcefully land", 37.5 s, 50 mana (training-range numbers). Ult study frames are in `/home/claude/svvid/ult/vireo/` (10 fps; frame N = 67 s + (N-1)/10). Two casts: f28→f49 and f81→f97.

1. **Input:** two presses. The first press launches her straight up. A second press (or click) picks the landing spot, and she crashes down there. The airborne phase lasted about 1.6–2.0 s in both casts. The video doesn't show whether there is a maximum hover time with an auto-land; see the open questions.
2. **Aim:** the landing point is **at the cursor**, clamped inside a large range ring centred on the take-off point (ring radius about 8–9 bh at the zoomed-out camera). She is self-cast on take-off and cursor-placed on landing. While she is airborne the camera **zooms out** (f30→f36) so that the whole ring fits on screen.
3. **Reticle / telegraph:**
   - On press (f28), a thin **gold range ring** snaps out around her.
   - Within about 0.4 s the ring's interior is shaded **dark blue-violet**, and the rim gains gold lightning crackle (f34–f45).
   - The cursor becomes a **small gold bracket reticle**, two curved arcs like a crown, `distinctive`, on the ground (f36).
   - On landing, a small **gold landing ring** about 1.3 bh in radius flashes at the spot for about 0.1–0.2 s (f47).
4. **Animation beats (10 fps):**
   - f28–f31 (0.3 s): crouch, then take-off. A dust puff is left on the ground at the take-off spot (f32).
   - f32–f46 (about 1.4 s): airborne. Her body is shown up high with an **INVULNERABLE** tag (f45). The world below is dimmed inside the ring.
   - f47 (0.1 s): the landing marker.
   - f49 (impact): a **vertical gold light pillar** slams down onto the marker, with a gold shock ring about 1.5 bh and spark spray (f49–f50).
   - f51+: orange lightning stays on the ground at her feet for about 0.5 s. She is immediately free to fire LMB again (f51 shows a normal shot).
5. **VFX (functional):** a range ring, a dark interior and a cursor bracket; then a sky-to-ground pillar of light plus a shock ring. The pillar-from-the-sky with a crown reticle is `distinctive`. Ours should keep "a thunder strike from above at the cursor" in our own palette.
6. **Sound feel:** none audible. It suggests a rising whoosh on launch, an electric hum while airborne and a thunder crack on landing.
7. **Numbers:**
   - Card: 37.5 s and 50 mana.
   - Fine print, from thebackdash.com hunter list (pre-1.0 wording): on landing it deals 40 + 22% damage in an area, Knockback, and **1 Static stack** on each enemy hit. She is **Invulnerable** while she is a storm in the air.
   - gameleap lists "Thunderstorm [R] 60 s" (an older cooldown).
   - The earlier sheet saw 115 on a landing.
8. **Ends / combo:**
   - It ends on landing.
   - Combo: land in the middle of a group to give Static and knock them about, then Surge (Shift) through the Static-charged targets.
   - It also serves as a full-invulnerability dodge and a repositioning tool across gaps.

**Fine print not found:** the max hover time, whether you can cancel, how she treats allies (no ally effect is mentioned), and whether a knock-up versus a knock-back happens. The supervive.wiki.gg page was blocked during research.

**Key frames:** `vireo/ult_0027.jpg` (before cast), `ult_0029.jpg` (range ring snaps out), `ult_0034.jpg` (take-off dust, interior shading), `ult_0036.jpg` (gold bracket reticle), `ult_0045.jpg` (airborne, INVULNERABLE), `ult_0047.jpg` (landing marker), `ult_0049.jpg` (light-pillar impact), `ult_0051.jpg` (recovery, LMB right after).

**Build notes:**
- **What to build:** X = press to leap and become invulnerable (about 2 s max, with an auto-land at the cursor when time runs out), with a camera zoom-out and a range ring of about 8 bh. Press again (or LMB) to slam at the clamped cursor. The slam is an AoE of about 1.5 bh radius, a knockback and +1 Static (our `mage` charge stacks).
- **Bond:** each enemy hunter hit by the slam adds 0.35 bond, capped at **0.75** per cast (`Bond.add(h, …)`). Landing on 2 or more enemies fills about 75% of the bar, so the Merge on R follows straight after the slam.

## Body, scale and movement feel

Method and units are as in venator.md's section of the same name: the hunter's ground motion comes from tracking the bar plus the camera pan. Distances are in 960 px units, 1 px ≈ 0.0375 m, 1 bh = Ghost's height ≈ 48 px ≈ 1.8 m. Zoom is the same in every clip; the training dummy is an Oath-model hunter, ~107-120 px tall at 1080p (0050, standing on the jump pad).

### 1. Height and bulk
- **Joule:** ~90-100 px at 1080p from head to sole (0190: 100; 0020: ~90 in a wide-legged stance).
  - **The upper body is wide**, ~70 px across the shoulders and sleeves, with thin legs below.
  - The bar's cyan line sits ~100-110 px above the soles (~1.05-1.15 bh).
- **Against Ghost:** ~0.95-1.0x as tall and ~1.3x as wide at the shoulders. Against the Oath dummy: ~0.85x as tall and ~0.6x as wide.
- **Ours:** mage is light, 0.855x medium.
- **Target scale factor ~0.96** (×1.12 on now). Keep the light leg build but give the shoulders/upper body ~1.15 width.

### 2. Locomotion
- **Run speed:** 110 px/s ≈ 4.1 m/s (0154-0160: 120, 0270-0274: 101), the same as everyone. Ours: light 5.0.
- **Start and stop:**
  - Start: 9 → 117 px/s in one 30 fps frame (30.63 s).
  - Stop: 89 → 29 → 7 px/s (32.0-32.07 s).
- **Cadence:**
  - A 30 fps close-up (30.6-31.6 s) shows short, quick steps: a stride cycle of ~0.43 s ≈ 2.3 Hz, ≈4.6 steps/s.
  - The steps are short, under the body. The legs barely leave the ground.
  - Ours: light 1.71 Hz.
- **Lean and bob:**
  - **Fully upright, no lean.** The arms are held out wide to the sides and a little forward, palms down, the whole time she runs. She glides along with the trailing ribbons swaying (30.6-31.6 s, 0154-0158).
  - No visible bob.
  - Ours: mage lean -0.03 and +0.05 when running ("glides upright"), and a hover offset. **Correct, but add the arms-out carriage while running.**

### 3. Idle
- Upright with the arms a little out and the legs apart (0020, 0190).
- No visible loop. Our slow sway and half-float idle fits.

### 4. Ground dash (Shift: Surge)
- **Body (32.10-33.0 s, 0161-0166):**
  - Hold, ~0.2 s: a crouch with crackling sparks (32.10-32.30).
  - Release at 32.35 s: the body turns into a golden lightning silhouette (an INVULNERABLE label over her) and streaks.
  - Arrival at ~32.6 s: an abrupt stop, then a big flash burst at the end point (32.75-33.0 s).
- **Speed:** **a flat curve with no ease.**
  - The speed jumps 132 → 631 → 899 px/s in two frames, holds ~770-980 px/s (≈29-37 m/s), and drops to near zero in 1-2 frames at the end.
  - Covered: ~215 px ≈ 8 m in ~0.3 s (0162-0164); ~150 px ≈ 5.6 m in ~0.2 s (0168-0169, 0288-0289); 396 px ≈ 14.8 m in 0.53 s (0297-0299).
  - **So the duration grows with the length at a constant ~30-35 m/s.**
- **Ours (kitfix-vireo-venator):** Wirerun is 4.5-12.6 m in a fixed 0.4 s (11-31 m/s). `mage_dash` holds the crouch, `mage_dash_go` streaks flat, and `mage_dash_land` re-forms in ~0.42 s.
  - The poses match. **Difference: the source keeps the speed fixed (~32 m/s) and lets the time vary. Ours keeps the time fixed, so a short run is slow.**

### 5. Air dash
- Not shown. Surge is only cast from the ground in the clip.

### 6. Jump and landing
- Not shown. She stands on the jump pad around the dummy (0050) but isn't seen using one.

### 7. Cast and attack body language
- **Budget:** moderate.
  - Finger bolts: an arm flung straight out, alternating hands.
  - The spear: an overarm throw with a stretch into the release.
  - The ult: a lift of the whole body.
  - Between casts she goes back to the upright arms-out carriage.
- **Squash and stretch:** most of it is in Surge (crouch, streak, re-form).
- **Timing:** about 0.2 s per bolt, a 0.2 s Surge hold, and ~0.3-0.4 s of arrival flash.

### 8. Build notes
- **Model scale:** ~0.96, with a wider upper body.
- **Collision:** hit_r 0.35. The wider shoulders reach ~0.65 m across at the new scale. Raise to ~0.37 so shots on the sleeves register. That's fair to attackers, and Joule stays a light.
- **Camera and nameplate:** her anchor is ~1.1 bh ≈ 2.0 m. Use **~2.2 m** instead of 2.35.
- **KMOVES and locomotion:**
  - Cadence about `spd*2.9` with a short stride (~60% of ours) and little knee lift.
  - Arms out to the sides while running (both hands ~45° out, a little forward). No lean.
- **Dash curve:**
  - Wirerun: constant ~32 m/s along the lane, time = length / 32 (5 m → 0.16 s, 12.6 m → 0.4 s), with no ease in or out. The stop is a hard cut into `mage_dash_land`.
  - Keep the 0.2 s pre-crouch.
  - `mage_dash_ex` (air) has no footage. Keep it.
- **Sound:**
  - Footsteps: very soft, almost none, with an electrical hum or crackle on the body instead.
  - Surge: a sharp electric crack at release, a sizzling zip along the lane, and a thunder pop at the arrival burst.

### 9. Unclear
- Air Surge and the jump. Settle them with a clip of Surge cast mid-jump or off a pad.
- Whether the Surge speed really is constant at full length. 0297-0299 shows a slight dip mid-run; settle it with a full-length Surge on open ground.
- Run cadence at 60 fps on a straight run.
