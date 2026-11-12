NEED OWNER: Celeste LMB reference

# Neve the Snowglide (`rimewright`) vs Celeste: owner playtest 11-08

## Part 1: LMB (Ice Darts): not pinned down, so Step 1 was skipped per the brief's guard

What could be found (trust D > wiki; notes and sources in `art-refs/source/celeste_lmb/README.md`):

- Kit text: "HOLD to fire a barrage of semi-homing Ice Darts (18 + 5%). At the end of the burst, fire 3
  larger darts that deal double damage, fly faster and travel further." Barrage cooldown 0.5 s.
- No text source gives dart speed, fire rate or dart count. The footage frames in the hero brief show a
  uniform stream while held; nothing in them shows "tap = bigger, hold = smaller".
- Hypothesis (unverified): the 3 large darts fire when the burst ends on release, so a quick tap gives the
  large darts at once and a long hold a stream of small ones first. That would read as "tap = bigger".
- No clip frames could be saved: the footage lives on YouTube and the owner's sheet, and this worker cannot
  download it (yt-dlp refused, no pip); namu.wiki, thebackdash and deltiasgaming blocked the fetch.

What the owner can settle in one line: dart speed (m/s or body heights/s), darts a second while held,
and whether the 3 large darts come on release (tap) or only after a full barrage. Alternative if no
answer comes: implement the hypothesis (release fires the 3 large darts, a hold streams the small ones)
and slow the small darts to roughly the footage's stream.

## Part 2: E Rink Wall vs Frozen Barricade

| | Celeste Frozen Barricade (source) | Neve Rink Wall before | after | note |
|---|---|---|---|---|
| Cooldown | 20 / 17.5 / 15 s by rank [D]; footage card 16.7 with CDR | 17 s | 17 s | kept: footage card matches |
| Wall health | 1750 [wiki], about 50 of her own darts (35 a dart) | 70 HP (17 of our darts) | 200 HP (50 of ours at 4) | changed: dart-ratio parity |
| Cast tell | short wind-up | 0.2 s sparkle, path shown | same | match |
| Width | grows as it slides | 1.8 m to 4.5 m | same | match |
| Slide speed | about 2.5 body heights/s [F] | 4.5 m/s (2.5 bh/s) | same | match |
| Travel / life | about 6 bh (10.8 m), about 3 s [F] | 16.2 m, 4.5 s | same | kept: owner item 13 asked for +50% |
| Recast freeze | 6 s | 6 s | same | match |
| Foes touched | pushed along | shoved | same | match |
| Blocks shots | yes | yes | yes | match |
| Look | solid translucent ice sheet, flashes when hit | a row of leaning pillars on a frosted footing, see-through gaps | a solid ice slab (2.2 m tall, 0.5 m deep, lit from inside, flashing on a block) is now the body of the wall, the pillars slimmer crystals on top of it, so the sheet reads from the gameplay camera | look stays ours; source quality |

Alternative not taken: travel 10.8 m / life 3 s (source parity) against owner item 13.

## Part 3: X Rimelock

| | source (Celeste Ice Crash) | before | after |
|---|---|---|---|
| Rink radius | 4 bh = 7.2 m [F]; no number in the data | 7.2 m | 8.3 m (+15%, hitbox and the drawn rink, one `radius`) |
| Statue slide (cast from a skate) | none in the source (our mechanic) | skate speed easing out over 0.8 s, about 6 m | 1.05x the skate speed, about 6.3 m (`carry_k`) |
| Hold / crack | 3.5 s | 3.5 s | 3.5 s (unchanged) |
| Her body | eight-point ice star | a frost bud of six ice petals closing over her (a shell) | her body is ice: every mesh of her model trades its material for `shaders/hero_ice.gdshader` |

Parity used for the size: Celeste's rink measured at 4 body heights (7.2 m) from the footage, then +15%.
Celeste's data gives no radius, so the footage number is the base.

The ice body (`scripts/arch/kits/ice_body.gd`): on the cast a frost front climbs from her feet to above her
head over the 0.2 s snap, every surface turning to translucent refractive ice (screen refraction, fresnel
rim, inner glow, Voronoi frost cracks, a sparkle) that keeps her own colour and atlas under the ice; the
front runs back down over 0.2 s when it ends, then her own materials return. It works on the procedural
model (one material_override a part) and on `claire.glb` (one override a surface); the toon outline stays
as the next pass. The frost bud is gone from `ult_look.gd`.

## Checks

`--rimewright-combo-check`: 95 checks, 0 failures (new: the wall slab row, the 8.3 m rink, carry 6.3 m, the ice body's swap,
freeze, thaw and restore on every surface).

## Clips

Before/after stills: `docs/art/wardens/neve_rink_wall_before_after.jpg` and `neve_rimelock_before_after.jpg`
(GPU renders via `--neve-shots`; see the report for whether they landed before the GPU queue cleared).
# Item 11: Kael (juggernaut) RMB / E / ult (owner 11-08)

Tuning lives in `content/rules/tuning.json` section `kael` (the file did not exist: created, with `Tuning.of`).

| item | status | what I tested |
|---|---|---|
| Live RMB aim during E | done | `--kael-tap-check`: strike goes where the cursor is at the blow, 90 and 180 deg off the E throw (36 dmg both) |
| Tap = overhead strike always available | done | check: tap with Smash resting lands a lighter hit (16 of 26), second tap blocked by `tap_cooldown_s`; hold unchanged |
| Ult keeps momentum | done | check: 6.0 m/s -> 4.8 (carry 0.8), still moving 0.1s in; debug `riposte.vel_before/after` |
| Ult vertical bonus | done | check: vy 3.0 -> 5.2; GPU log vy 6.0 -> 8.2 |
| Ult mid-mantle | partial | ledge rise rewrote vel.y every tick, so a ledge rise is now handed over to the boost; tested with a stub ledge state, not a real ledge |
| RMB aim past tether | done | Lunge backward past the length breaks the tether; sideways inside range keeps it |
| GPU clips | done | job 20261109-032347-06637: tap, hold, ult_sprint, ult_jump (a jump stands in for a mantle). Frame check only; no "before" clips |
| suite-fast | not run | no such command found here; ran `--kael-tap-check` (10/10) and `--juggernaut-combo-check` (183/183, covers kael_accuracy) |
