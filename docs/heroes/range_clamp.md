# A cursor past max range: clamp, refuse or walk in?

This covers every ground-targeted RMB, E and R (our X) of the 12 Hunters, plus Motley's Trade on Shift. When the
cursor is past the slot's max range, the source can do one of three things: cast on the range edge along the cursor
line (**clamp**), refuse the cast, or walk you in until you are in range. Sources: `briefs/supervive-data/supervive_kits.md`
[D], the footage notes in the hero sheets [F], `docs/AIM_PREVIEWS.md` (ext/aim-preview-parity).

**The rule is clamp, for every slot.** Every slot the footage shows with a far cursor clamps: Kitefall's crown stays
inside its ring (f29, f36), Kael's air slam lands where you aim within 5 m (0263, 0286), and Mossy's hammer throw
never goes past about 7 bh (0408). No footage shows a refusal or a walk-in. The source moves on WASD, with no
click-to-move that could walk you in. The [?] rows have no far-cursor footage, so they follow that rule.

`--range-clamp-check` puts the cursor at 2x range east of the Hunter for each row and asserts the cast point and the
preview spot (where the slot shows one) against the edge, within 0.2 m.

| Hunter (id) | Slot | Source behaviour, cursor past range | Range (data) | Cast | Aim preview | Verdict |
|---|---|---|---|---|---|---|
| Vex (gunslinger) | X Cinderfall | clamp [?]: "napalm at target location" [D] | `x.range` 14 m | `AimMode.point` | disc `x%d` at the shell, after the tap | ok |
| Sparkle (mage) | E Skycall | clamp [?]: "strike target location" [D] | `e.reach` 11 m | `AimMode.point` | rim `e%d` + drag lane, after the press | ok |
| Sparkle (mage) | X Kitefall | clamp [F] f29/f36, crown inside the ring | `x.range` 14.4 m | `land_point` (limit_length) | crown `x_aim` = the landing | ok |
| Kael (juggernaut) | RMB in the air, Meteor Drop | clamp [F] 0263, 0286 | `rmb.drop.reach` 5 m | `JuggernautDrop.point` | `drop_aim` = the same point | ok |
| Lace (archer) | E Hail Wall | clamp [?]: the arc's radius stops at its reach | `e.reach` 9 m (`rmin` 2) | radius clamped | `e` arc wall, same radius | ok |
| Meeko (tender) | E again, Hearthlight throw | clamp [?]: "throw zone to target location" [D] | `e.reach` 9 m | `AimMode.point` | none (the source shows none either) | ok |
| Neve (rimewright) | RMB Ice Spear | clamp [?]: the landing ring at the cursor | `rmb.lance.range` 12 m | `AimMode.point`, travelled from her palms | ring `rmb` | **FIXED** |
| Neve (rimewright) | E Rink Wall | clamp [?]: it stops at the cursor | `e.reach` + `e.travel` 18 m | travel clamped | lane `e`, the same length | ok |
| Tenzo (dolm) | X Basalt Spine | clamp [?]: the wall at the press point [D] | `x.range` 11 m | `AimMode.point` on the press | span `x` at the centre | ok |
| Motley (ostra) | E Brimseed | clamp [?] (walls and the abyss shorten it) | `e.reach` 9 m | `HeroZones.walk` | ring `seed`, after the press | ok |
| Motley (ostra) | X Nightwell | clamp [?] (as the seed) | `x.range` 10 m | `HeroZones.walk` | dome `x`, after the press | ok |
| Motley (ostra) | Shift Trade | clamp [?]: owner note, a target circle at the cursor | `dash.reach` 12 m | `swap_spot` | `swap` far ring = `swap_spot` | ok |
| Sable (thief) | E Shadow Knife | clamp [?]: a skillshot that lies where you aimed | `e.range` 14 m | `AimMode.point` | `knife` ring where it lies | ok |

The fix: Neve's spear flew its distance from her palms, which sit `SPEAR_AHEAD` (0.9 m) out front, so a far
cursor landed it 12.9 m out, 0.9 m past the ring and the range. It now flies from her palms to the ring's
centre.

Not ground-targeted, so a far cursor only sets the direction: Vex RMB/E, Mossy RMB/E/X (E sits at the hammer),
Sparkle RMB, Kael tap/hold RMB, E and X, Lace RMB/X, Cinder RMB/E/X, Grimble RMB/E/X, Meeko RMB, Neve X, Tenzo
RMB/E, Motley RMB, Sable RMB/X. Grimble's Anchor Drop is the check's control: a 3 m cone at his feet whatever the
cursor distance. Meeko's Hearth Call is unit-targeted: X does nothing unless the cursor rests on a teammate within
its 12.6 m (`tender.md`).

Left as notes (no change): before Vex's X, the only line is the shared weapon line. It ends at 11 m while the
shell lands at 14 m (owner item 106b owns that line). Sable's E has no line of its own either, and the 12 m
pistol line shows before a 14 m knife.
