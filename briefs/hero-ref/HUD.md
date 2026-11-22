# In-match HUD reference (clean-room study) and Boki gap list

Sources: `/home/claude/svvid/all.mp4` (ability showcase, older HUD, practice range) and the commentated
Earthbender guide (1.0 HUD, real fights). 55 full-res frames were pulled to
`/tmp/claude-0/-home-claude/8d7770c0-fbec-571e-85de-44fde799926f/scratchpad/hud/` (`a_*`, `f1_*` from the showcase,
`g_*`, `h_*` from the guide) and cropped 2-6x for the notes below. Useful moments: guide 183-198s
(self, rival and dummy plates, damage numbers), 186s "double knock", 259s (stun + slow on two plates,
huge yellow hit number), 265s (knock callout, +253 heal, status icon cards), 271s (self at 973/2304:
bar colour shift, many plates, low-health edge), showcase 30s (old plate with XP under the level).

Everything below is described by function, proportion (on 1920x1080) and colour *role*. Items marked
**[identity]** are distinctive art choices of the reference that we must restyle, not copy.

---

## 1. Overhead nameplate (per hunter)

**Placement and size.** Centred over the head, about 15-25 px above the top of the model. At the default
camera a hunter model is ~80-100 px tall; the plate is ~105-115 px wide and ~30 px tall in total, so
the plate is a little wider than the character is tall. It does not scale with distance much (top-down
camera, near constant zoom). Plates of nearby hunters overlap freely; there is no decluttering.

**Stack, top to bottom:**
1. **Name** (or a status word, see below): ~13 px bold sans, white-ish with a dark soft outline,
   centred. Shown for allies and rivals alike in the 1.0 HUD.
2. **Bar frame**: a dark backing that holds two bars:
   - **Health**: ~11-12 px tall, split into equal *segments* separated by 2 px dark gaps. Each segment
     is a fixed amount of health (a 2,500-health hunter shows ~10, a ~1,000-health hunter ~4), so a
     bigger pool reads as more segments, not longer segments. The last partly-filled segment is drawn
     partial.
   - **Armour**: a thin (3-4 px) bar *under* the health bar, full width, cool cyan, not segmented;
     a tiny numeric tag sits at its right end on the self plate. When armour is gone the strip is
     empty (dark), so you can see it can come back.
   - **Thin top strip**: a 2 px light line along the top edge of the health bar on some plates; it
     tracks a shield/overheal amount (bright white-blue when a shield is up, e.g. while being healed
     at 265s).
3. **Level chip**: the run level as a bold numeral in a small chip hanging off the bottom-left corner
   of the frame (old HUD: a square tile on the left with a thin XP strip under the number).
4. **Status icon cards**: small (~16x24) icon tiles stacked to the *right* of the frame for buffs and
   debuffs (at 265s: a red-framed card). A small numeric "stack" blob sometimes floats to the left.

**Colour roles.** Self = bright yellow-green fill; allies = blue; rivals = red. Empty health is a dark
desaturated version of the fill colour. On the *self* plate and bottom bar the fill shifts toward
orange as health drops (973/2304 reads orange). Armour is always cyan regardless of team. Downed /
knocked enemies flip to a pink-magenta accent.

**Damage chip (trail).** After a hit, the lost portion stays as a lighter, salmon/white chunk at the
right end of the fill (259s: red fill + pale orange tail), holds for roughly 0.3-0.5 s, then drains
quickly (~0.25-0.4 s) to the new value. Rapid hits keep the chip up and it drains once after the
last one. Heals snap up (no green preview seen).

**Hit flash.** The struck plate flickers lighter for a frame or two (hard to see at 30 fps; the
segments that were hit brighten before turning into chip).

**Status word.** Crowd control replaces/sits over the name with an all-caps word in the same font
("SLOWED", "STUNNED", "MIDAIR"), white with dark outline, for the duration.

**Knocked / downed.** On a knock, a large **burst callout** pops over the victim for ~1.5 s: the victim's
face inside a spiky starburst with a big "KNOCK" word and their name on a small tag (**[identity]**:
the portrait-in-splat art and word). Multi-knocks escalate the word ("DOUBLE KNOCK"). The downed body
then carries a small marker (pink star) and its plate turns into a bleed-out state.

**Overhead number tags.** "COINS +2,055" style reward chips appear beside a plate on a kill.

**[identity] to restyle:** the parallelogram/slanted frame and slanted chip, the yellow self colour
on a black slanted frame, the portrait-starburst knock callout, the card-shaped status tiles.

## 2. Bottom HUD

**1.0 layout (guide).** Everything sits bottom-left; the centre-bottom is empty play space.
- **Portrait**: ~130x150 character bust at (15-150, 800-950) breaking out of its frame (**[identity]**:
  the cut-out illustrated bust). A small speech-bubble token next to it shows the equipped
  consumable/emote.
- **Vitals block** under the portrait (~(55-300, 960-1050)):
  - a small secondary readout above the bar (icon + number, e.g. "1,233"),
  - a **thick segmented health bar** (~230x22 px, ~10 segments), slanted frame,
  - the **armour bar** directly under it (thin cyan, ~5 px) with its number at the right end
    ("208" with a drop icon),
  - **"2,691 / 2,691"** under the bars: current health ~28 px bold, max ~16 px, dimmer,
  - the **level number** (purple) at the far left on a dark strip, with a long **XP bar** (purple) and
    a second meter (pink) under it at low health moments.
- **Ability row** to the right of the vitals (~x 330-640, y 980-1060): the basic attack drawn as a big
  white glyph (no frame), then four square slots ~52x52 with 10-12 px gaps.
  - a **rank badge** on top of each slot (roman numerals in a magenta tab; **[identity]**),
  - a **base-cooldown tab** under each slot (small number in a cyan-outlined box: 20, 15, 15, 25),
  - a **key label** pill under that (white text on black: L SHIFT, SPACE, E, 8),
  - **on cooldown**: the icon is replaced by a dark slot, a large red-pink countdown number fills the
    centre (5, 9, 30), and the frame turns red. No radial sweep in 1.0 (the older HUD used a
    sweep plus the number),
  - **charges**: small pink pips under the slot (old HUD); "upgrade available" shows glowing beams
    and an orb over the slots after a level-up.
- **Right side** (~x 1150-1900, y 1000-1060): item slots (consumables with counts and number keys
  2-6), quick-use icons, a utility/compass tile. This is where our other workstream's gloves, Boki box
  and 1/2/3 belt go.

**Old layout (showcase).** Centre-bottom: coins, crystal count, 4 item tiles, a stat column
(health, armour, power, haste numbers with icons, green/blue for health/armour), a round portrait
with a **level ring** and a big level number in a coin, six ability squares with key labels, cost
pips and a circular dash/glider gauge.

## 3. Minimap and timers
Minimap: circular, top-left, ~260 px across, with the day/phase label and a countdown plus a level
progress line under it. Squad list under the minimap on the left: small portrait, name, a mini health
bar and armour line per teammate. Top-right: kill / assist / damage counters and currency; kill feed
and "SQUAD ELIMINATED" cards under that; a vertical stack of small buff/stat icons along the right edge.

## 4. Floating damage numbers
- Normal hits: white/cream bold numerals ~26-34 px with a thick dark outline, spawned at the target's
  upper body, slightly randomised horizontally.
- Big or critical hits: much larger (~60-90 px on screen at 259s), **yellow** fill with a dark outline,
  readable over effects.
- Heals: green with a "+" ("+250", "+253"), ~36 px. XP: small purple "+17 XP".
- A small purple/magenta blob number to the left of a plate tracks stacks of a debuff.
- Motion: pop in at ~130% scale, settle in ~0.1 s, rise ~30-50 px and fade over ~0.6-0.9 s; rapid hits
  on one target accumulate into one growing number.

## 5. Hit feedback
- Plate flash on the struck target (see above) and the chip.
- Low health: a red wash creeping in from the screen edges (strongest where the damage came from),
  pulsing; the self bar shifts colour toward orange.
- Knock and kill moments get big centre-screen-adjacent callouts (see knocked state).

---

## 6. Ours (origin/main 18fab56, on top of sync62 4f82978) before this work

Screens: `/home/claude/shots/hudref/before_*.png`. Code: plates and vitals in `scripts/ui/hud.gd`
(`_nameplate`, `_vitals`, `_seg_bar`, `_draw_overhead`, `_draw_vitals`, `_ab_slot`, `_skill_slot`),
dash strip `scripts/ui/dash_strip.gd`, damage numbers `scripts/match/fx.gd` (`number`), colours picked
in `match.gd` (`_apply_damage`).

What we already had: segmented health in 25-point chunks, a chip trail, armour over health, team vs
hostile colour, status icon row, dash pips, a portrait with a level ring, ability slots with sweep +
seconds, aggregated floating numbers with outline, a pulsing low-health edge and hurt flash.

## 7. Ranked gap list (most visible first)

1. **Rival/ally plates are tiny.** 54 px wide, 5 px health, 2 px armour (reference ~110 px / 11 px /
   4 px). They don't read in a fight. Name at 11 px.
2. **Armour sits on top and reads like a second health bar.** Reference: thin cool strip *under*
   health, empty when broken. No break moment on plates.
3. **Chip drains immediately and slowly** (0.6 of the bar per second from the moment of the hit).
   Reference: hold ~0.4 s, then drain fast. No hit flash on the plate.
4. **Downed state is a word.** A 5 px amber bar plus "DOWN" under it; no knock callout. Reference has a
   big knock burst and a distinct downed plate.
5. **Shield overlay is wrong-shaped**: a translucent wash from the left edge scaled by shield/120, so it
   hides health instead of adding to it.
6. **Levels not shown to everyone** (owner priority, effectively #2): allies show a class letter,
   your own plate has none, and online the level is never synced, so remote hunters read level 1.
   Reference: every plate carries the run level in a chip at the frame's lower-left (see below).
7. **No status word.** CC shows as 14 px icons under the bar only; reference shows the word over the
   bar and icons to the side.
8. **Colour roles muddled.** Your own plate and allies use team colours (orange for team 0), the same
   as rivals' hues on other teams; no self / ally / rival roles; low health only flickers.
9. **Bottom vitals**: health 13 px tall, numbers above the bar; the reference puts a thick bar under
   the portrait with the big "current / max" under it and armour as a thin strip with its number.
10. **Ability slots**: cooldown number is plain white 22 px over a 52% sweep; no unready tint on the
    frame, no base-cooldown tab, rank pips are bars above. Key caps are fine.
11. **Damage numbers**: crits are only yellow and 12 px bigger; no punch, no outline colour change.
    Otherwise close (aggregation, pop, outline, heal "+").
12. **Low-health vignette** exists (pulsing red edges under 35%). Fine; could tie to the hit direction
    (already have `hurt_dirs` arrows).
13. Out of scope here: minimap and timers (already close), kin speech bubbles cluttering the plates.

### Added on owner request: everyone's level on the plate

**Reference.** Every plate, self, allies *and rivals*, carries the run level. In the 1.0 HUD it is a
bold white numeral in a small dark chip pinned to the **lower-left corner of the bar frame**, hanging
slightly below and left of where the bars start (guide 190s "3"/"2", 259s "7"/"1", 265s "7", 271s
"10"). The chip is about as tall as the health bar plus the armour line (~14-16 px at 1080p) and
widens for two digits ("10" at 271s is a wider tab, not a smaller font). It sits in the frame's
colour family (slanted tab, **[identity]**) and the numeral stays white at every level we saw (1-15).
The old showcase HUD put it in a square tile left of the bar with a thin XP strip under it. On a
level-up the number simply changes at 30 fps; no plate animation is visible in the footage, though the
self HUD plays an "upgrade available" beam over the ability slots.

**Ours before.** Rivals: a 6 px level circle left of the bar (gold rim at 6+). Allies: a class letter
instead of the level. Self: no level on the plate. Online, the level was **not synced** at all, so
remote hunters always read level 1 on everyone else's screen.

**Gap 6 (raised to 2nd).** Show every hunter's level on every screen, in the reference's place and
size, and pulse it when it rises.

## 8. What changed (ext/hudref)

| Gap | Done |
|---|---|
| 1 tiny plates | 100 px x 9 px health, 3 px armour, 13 px name (108 px for yours), in a framed backing |
| 2 armour on top | armour is a strip under health in its tier colour, empty track when broken, white crack when it breaks |
| 3 chip timing, no flash | chip holds 0.4 s after the last hit, then drains in ~0.2 s; frame and bar flash white 0.14 s on a hit |
| 4 downed | amber bleed-out plate (red while being stomped), revive progress, "DOWN" / "X reviving 40%" under it, and a ray burst with a popping "DOWN" over them when they go down |
| 5 shield shape | shield is a pale fill past the end of health (overlaying the end when full) |
| 6 level everywhere | a level tab at the frame's lower-left on every plate (self, allies, rivals, downed), pill at 10+, gold rim at 6+, a swell + gold ring when it rises; the run level now rides the Net snapshot (0.15.4) |
| 7 status word | CC word (STUNNED, ROOTED, SLOWED, BURNING, WEAKENED) replaces the name; icon tiles to the right of the frame |
| 8 colour roles | SELF leaf green, ALLY sky blue, FOE coral; yours and allies' warm toward orange under 55% and pulse under 30% |
| 9 bottom vitals | 26 px health number, thick 16 px segmented bar sharing the plate's chip/flash, armour strip under it with its own trail, shield and shell in place |
| 10 slots | state frames (ready / cooling coral / off), dimmed icon, sweep clipped to the slot, big outlined countdown (tenths under 1 s in coral), charge pips on the bottom edge, key pills |
| 11 numbers | crits pop at 2.2x with a thicker ember outline; colours come from HudStyle roles |
| 12 vignette | unchanged (already pulses red under 35%) |
