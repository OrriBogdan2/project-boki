# Pin (id `archer`, Light) - fidelity pass (hero sheet pin.md)

Behaviour reference: the hero named in the Inspired-by table in docs/ARCHETYPES.md (internal note; nothing of the source's names or look ships). Player-facing names are our own. Display name Pin (was Archer); the id, files and save keys stay `archer`.

## Research summary
Sources (gameplay only; notes in our own words, nothing of the source ships):
- The hero sheet `briefs/hero-ref/pin.md`, written from 5 fps gameplay footage of the newer version of the source kit (one footage frame = 0.2 s). Its ranked gap list drove this pass.
- The earlier accuracy pass (the public kit page and guides, patch history) for the parts the footage doesn't show.

What the newer source does: a two-stage bow draw (Empowered at about 0.6-0.8 s, Supercharged at about 1.2-1.4 s) with a V reticle that closes at each stage; Empowered shots land at the cursor, Supercharged ones fly past it to a longer range; releasing right as a stage comes up makes the next charge faster; holding about 0.5 s past full draw overdraws the arrow (about half damage). A charged impaling arrow with a gold V and bar telegraph. Shift is Spirit Walk: a dodge roll, then 2.8 s walking through walls and objects. E is a curved arc wall of rain at the cursor distance, about 120 degrees wide. The ultimate (three empowered piercing beams) is back on X as Starpiercer (R stays the Merge).

Where the footage and our older doc disagree, the footage (the newer version) wins, except where the owner notes override it.

## Per-slot table (slot, input, our behaviour, source behaviour, difference and why)
| Slot | Input | What it does now (our words) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive | always | Focus (fills standing still or sneaking, from snares and pins) + Hawk Sense (foes under half health show through cover within 22 m) + a knock heals 18 (and, as for every hero, the takedown reset returns a dash charge) | Soul Hunter: injured hunters seen through fog; tall-ledge climb | Focus/Deadeye stays as our own loop. The ledge climb has no heightmap equivalent and is left out |
| LMB | tap | Released before Empowered: 15 damage, lands at the cursor | Weak tap shot (not isolated) | Assumed to land at the cursor too |
| LMB | hold | Empowered at 0.6 s (30, lands at the cursor up to 12 m); Supercharged at 1.15 s (60, flies past the cursor to 16 m). V reticle, stage flashes, white body flash, thick white line and target ring at Supercharged | Same stages and reticle | Timings at the low end of the footage's ranges (ratio 1 : 1.9) |
| LMB | perfect | Let go within 0.15 s of a stage coming up: no extra damage, the next draw runs 1.6x until Empowered; a gold four-point star with a ring beside the bow hand, the cursor star, `arc_perfect` | The next Empowered charge is faster; a gold star by the bow hand | The 1.6x is our pick (not measurable at 5 fps) |
| LMB | overdraw | Held 0.5 s past Supercharged: the line and star dim, the arm shakes (`arc_over`); the arrow does half | About 50% (263 vs 505) | Matches the ratio |
| RMB | tap | Snare (root 0.6, a Tripwire on a miss) | Impaling Shot tap (uncharged) | Kept as our extension: it feeds Focus, which drives the Deadeye |
| RMB | hold | Heavy Shot: the V tinted gold plus a gold bar from the bow that grows to 2 body heights with the charge; full at 1.1 s; pierces, knocks back; into a wall within 3 m: a wall hit and a 1.2 s stun (PINNED). Thick gold arrow with violet fins; red-white burst, dust and a white ring on impact; a pink crescent at the feet on release | Same telegraph, arrow and impact | The 1.2 s wall stun stays from the earlier pass |
| Shift | tap | Spirit Walk: a 2.6 m dodge roll (0.16 s, invulnerable), then 2.8 s walking 15% faster through rocks, trees, pillars and ability barriers (not cliffs). Damage ends it; ending inside something costs 30 Focus and puts her back where she went in. Her screen tints dark blue while inside; a green shell over her | Spirit Walk: dodge roll, 2.8 s through walls and objects; damage ends it; ending inside a wall costs 30 mana and teleports back | Mana is Focus here. Cooldown 6 s on our charge system instead of the source's mana gate |
| Shift | long dash | In the air or out of charges: a 4.2 m flick with a sideways tumble (`pin_flick`) and a green streak | (base dash) | Our per-hero base dash variant |
| E | tap | Hail Wall: lobbed up (0.35 s, everyone sees the arc), then 4.4 s of rain on an arc round her, 120 degrees, at the cursor distance (2-9 m), 1.8 m deep: 5 per 0.5 s, slow 35%, blight (healing barely takes) with blue burn flames. Seven translucent green panels with fletch posts, a ground glow, arrows streaking down | Rain of Arrows: an arc concentric to the hunter, about 120 degrees, at the cursor distance, about 4.4 s | Cooldown 9 s (source 8.3 s with RMB 9 s: the same ratio to our RMB) |
| X | tap (level 6) | Starpiercer: no cast lock; the next 3 bow shots within 6 s need no draw. Each LMB press nocks 0.3 s, then looses a beam that pierces every foe to 18 m (1.5x Empowered), knocks back 4 and strips 10 armor: 18, 18, then 25 on the last, which finishes a hunter it leaves under 12%. Cooldown 36 s. Telegraph: the beam's lane and a ticked ring at her feet; three pips and a glowing bow everyone sees | Primal Forces: next 3 shots empowered (no charge, 6 s, piercing, longer range, knockback, armor shred, the final shot executes) | Damage scaled down from the source's ratio (a beam is about a Supercharged arrow there; here 0.3x, final 1.39x the beam as the source's 1.41x) so the ult then a merge never takes a full-health light hunter down. Deadeye stays: it is the Focus payoff on a rooted foe, not a three-shot window, so nothing is unfolded |
| R | - | the Boki Merge | - | R is the Merge for every hero |

## Assumptions (the footage is silent; the owner can correct these)
- A Supercharged shot with no target flies its full 16 m (not a longer clamp past the cursor).
- The quick draw after a perfect release is 1.6x until Empowered, then normal speed; the next release consumes it, perfect or not.
- The perfect window is 0.15 s from each stage coming up (about one footage frame).
- A tap shot (before Empowered) does 15 and lands at the cursor.
- The Impaling Shot's wall stun stays 1.2 s and its full charge 1.1 s (the earlier pass).
- "Cremating" a burning enemy with a knock is flavour, not a mechanic: not built.
- During Spirit Walk she can still shoot and cast, and moves 15% faster (35% inside something).
- The spirit orb lasts 4 s and gives anyone who touches it (ally or foe) one 2.8 s Spirit Walk; they get no roll and no snap-back.
- Cremation is +10 damage and a longer burn on a foe knocked by the Heavy Shot while it stands in her burning Hail Wall.
- Not built: the double-wall climb (no heightmap equivalent) and Hail Wall damaging wisps (our downed hunters take no ability damage).
- Starpiercer: the beam is stopped by walls and terrain (the source pierces "destructibles"; ours has no destructible walls on the shot line), and a breakable prop ends it.
- Starpiercer: the cooldown starts on the cast; unused shots are lost when the 6 s run out; a merge ends the window.
- Starpiercer: each beam nocks for 0.3 s (the footage shows a short draw; the fine print says no charge) and the next nock waits 0.6 s, so all three fit the window at about 0.9 s each.
- Starpiercer's execute is "finish a hunter left under 12% of max health" (the card's "execution damage" isn't defined anywhere we found).
- Starpiercer beams don't spend Focus and can't be Deadeyes (the two payoffs stay separate).
- "Inside something" means a rock, tree or pillar tile, or a movement-blocking ability barrier; terrain cliffs and ledges are never passable.

## Small mechanics (fine print; source, footage, ours)
| Mechanic | Source | Footage | Ours | Check |
|---|---|---|---|---|
| Stage 1 lands at the cursor, stage 2 flies past it | sheet pin.md | confirms (0117, 0168-0169) | built | `pin aim:` lines |
| A perfect release makes the next charge faster | sheet pin.md (newer kit) | card text only | built, 1.6x to Empowered | `combo pin: perfect > ...` |
| Perfect shots ease the self-slow of drawing | [wiki: Greenwood Bow](https://supervive.wiki.gg/wiki/Myth) | not visible | built: the draw after a perfect slows you to 0.85, not 0.7 | `pin small: after a perfect...` |
| Overdraw halves the shot | sheet pin.md | confirms (0252-0256) | built | `pin bow: overdrawn` |
| Spirit Walk: dodge roll, then 2.8 s through walls and objects, not terrain | [wiki: Phase Walk](https://supervive.wiki.gg/wiki/Myth), sheet | confirms (0360) | built | `combo pin: Spirit Walk passes...` |
| +50 move speed while inside terrain | [wiki: Phase Walk](https://supervive.wiki.gg/wiki/Myth) | not measurable | built: x1.35 inside (x1.15 elsewhere) | `pin small: faster inside...` |
| Walking into a wall leaves a phase orb; allies or enemies touching it also phase | [wiki: Phase Walk](https://supervive.wiki.gg/wiki/Myth) | not shown | built: a 4 s spirit orb at the entry; anyone touching it walks as a spirit for 2.8 s | `pin small: anyone touching the orb...` |
| Taking damage ends it; ending inside a wall costs 30 mana and teleports back | [wiki](https://supervive.wiki.gg/wiki/Myth), sheet | card text | built (30 Focus) | `pin: damage ends...`, `combo pin: ... ending inside a rock` |
| Knocking an enemy restores a dash charge | [wiki: Phase Walk](https://supervive.wiki.gg/wiki/Myth) | not shown | built (now main's takedown reset for every hero) | `combo archer: knock > heal + dash charge` |
| Heartpiercer can be held 3 s after cast before it fires | [wiki patch 20.11.24](https://supervive.wiki.gg/wiki/Myth) | not shown | built: auto-release at 3 s | `pin small: the Heavy Shot can be held 3 s` |
| Short Heartpiercer charges push harder | [wiki patch 20.11.24](https://supervive.wiki.gg/wiki/Myth) | not shown | built: minimum push 6 -> 8 | same |
| Into terrain: 1.2 s stun and extra damage | [wiki: Heartpiercer](https://supervive.wiki.gg/wiki/Myth) | not clean in footage | built (earlier pass) | `combo archer: Heavy Shot > wall` |
| Knocking back a burning enemy Cremates it | [wiki: Rain of Arrows](https://supervive.wiki.gg/wiki/Myth), sheet | flavour text | built: a Heavy Shot knock on a foe in the burning wall: +10 and a longer burn, CREMATED | `pin small: Heavy Shot into a foe burning...` |
| Rain of Arrows: a cone/arc wall, slow and anti-heal | [wiki](https://supervive.wiki.gg/wiki/Myth), sheet | confirms (0457, 0498) | built: 120 degree arc at the cursor distance | `pin E:` lines |
| Climb double-high walls by jumping while facing them | [wiki: Spectral Hunter](https://supervive.wiki.gg/wiki/Myth) | not shown | not built: our heightmap mantle has no double-wall case (Assumptions) | - |
| Ult: empowered arrows need no charge, 6 s, the next 3 shots | [wiki: Virideth's Fury](https://supervive.wiki.gg/wiki/Myth), sheet | confirms (f33-f78) | built | `pin ult cast`, `pin ult small: the beam needs no draw`, `... the 6s window ends` |
| Ult: pierces enemies, longer range, knocks back | [wiki](https://supervive.wiki.gg/wiki/Myth) | confirms the long beam (f48) | built: 18 m, pierce, push 4 | `pin ult payoff: the beam pierces both foes, 16m out`, `... knocks back` |
| Ult: the final shot hits harder and executes; shots shred armor | [wiki](https://supervive.wiki.gg/wiki/Myth), card text | final number not legible | built: 25 vs 18, execute under 12%, -10 armor per beam | `pin ult payoff: the last beam finishes...`, `pin ult small: armor shredded` |
| Ult: she walks and dodges between shots | sheet | confirms (walks f50-f62) | built: no slow, Spirit Walk keeps the shots | `pin ult small: she can move...`, `... Spirit Walk between shots keeps them` |
| Ult: a wall stops the beam | ours | - | built | `pin ult small: a wall stops the beam` |
| Affects wisps (downed hunters) | [wiki](https://supervive.wiki.gg/wiki/Myth) | not shown | not built: our downed hunters aren't hit by ability damage (Assumptions) | - |

## Scaling
Light class, 124 HP: tap 15, Empowered 30, Supercharged 60, overdrawn 30, tap snare 8, full Heavy Shot 30 (+12 wall hit), Hail Wall 5 per 0.5 s, Deadeye +18, Starpiercer 18 / 18 / 25 per beam (36 s cooldown, 4x the E cooldown as in the source). Source numbers were used only as ratios (overdraw half of Supercharged, E cooldown about RMB's).

## Cross-ability interactions (combos)
| Combination | Result | Check |
|---|---|---|
| Release Empowered right on its flash | No extra damage; the next draw reaches Empowered in about 0.38 s | `--archer-combo-check` |
| Draw past Supercharged + 0.5 s | Overdrawn: half damage, the drooping release | same |
| Empowered / tap with no target | Lands at the cursor; the spent arrow stays stuck there for 4 s | same |
| Supercharged with a foe under the line | The foe ringed at its feet; a teal X-star on the hit | same |
| Heavy Shot into a wall | Wall hit, 1.2 s stun, PINNED, Focus filled | same |
| Wall pin, then a shot | Deadeye (gold second hit, hitstop, `pin_deadeye`) | same |
| Hail Wall, then snare tap | Longer root (1.0) | same |
| Hail Wall arc | A foe on the arc burns; one inside the arc's radius does not | same |
| Spirit Walk into a rock column | Passes through; ending inside puts her back, 30 Focus | same |
| Knock | Heal 18, +1 dash charge, RUN DOWN, `pin_rundown` | same |
| Rival under half health | Shown through cover (Hawk Sense) | same |
| A Boki merge mid draw / Heavy Shot / Spirit Walk | Each dropped with no shot; Spirit Walk ends | same |
| Starpiercer, then Snare or a wall pin, then three beams | The rooted foe eats every beam; lined-up foes behind it are pierced too | `--archer-combo-check` |
| Starpiercer during Spirit Walk | Shots kept; she can roll between beams | same |
| Starpiercer's last beam on a hurt hunter | EXECUTED under 12% (a knock: the cast's best bond event) | same |
| A Boki merge mid nock | No beam; the empowered window ends | same |
| Starpiercer then a merge on a full-health light hunter | Standing (burst cap) | same |

## Animations (KMovesPinBjorn ids per ability; timed to 5 fps footage frames)
| Ability | Move id(s) | Notes |
|---|---|---|
| LMB draw | `arc_draw` (held) | side-on to the cursor in 0.2 s, string hand to the chest, deeper by Empowered |
| LMB tap / Empowered / Supercharged | `arc_tap`, `arc_loose`, `arc_super` | a snap; a one-frame string snap; a hard kick back with a half step |
| LMB perfect | `arc_perfect` | a flourish of the string hand, overshoot and settle |
| LMB overdraw | `arc_over` (held), `arc_over_loose` | the draw arm shakes and sags; a drooping release |
| RMB hold (Heavy Shot) | `arc_heavy_wind` (held), `arc_heavy` | sunk low; thrown back by the shot |
| RMB tap (Snare) / air (Plunge) | `arc_snare`, `arc_plunge` | |
| Shift (Spirit Walk) | `pin_roll`, then `pin_walk` (held) | one forward roll in 0.16 s, then light-footed, arms trailing |
| Long dash | `pin_flick` | a sideways tumble |
| E (Hail Wall) | `arc_hail` | bow raised high, the volley lobbed up |
| Payoffs / procs | `pin_deadeye`, `pin_rundown` | locked low with the bow thrust out; a pumped fist and skip |
| X (Starpiercer), 10 fps beats | `pin_ult_cast`, `pin_ult_nock` (held), `pin_ult_loose`, `pin_ult_final` | a one-frame flash with the bow swept across the chest; string to the cheek, sunk low; a one-frame kick back with the hand flung behind; the last one lifts her off her feet into a hard crouch |
Strips: `--arena-demo=anim_<id> --arena-shot=<png>` (scripts/match/arena_demo.gd ANIM_DEMO).

## Engine notes
- Kit: `scripts/arch/kits/archer_kit.gd` (wiring), `pin_draw.gd` (draw stages, reticle, perfect, overdraw), `pin_spirit.gd` (Spirit Walk), `pin_fx.gd` (pooled effects), `kit_shaders.gd` / `kit_meshes.gd` (our shaders and meshes), `scripts/match/pin_bjorn_weapons.gd` (the recurve bow model), `scripts/match/kmoves_pin_bjorn.gd` (moves). Data: `content/archetypes/archer.json`, `content/weapons/longbow.json` (`draw`, `overdraw_t`, `overdraw_k`, `quick_k`, `aim`).
- Hunter hooks: `ArchKit.draw_rate()` scales the bow's draw; `draw_bonus(t)` sets `h.shot_aim` (AimMode: stage 1 cursor, stage 2 max) and the damage factor; `Hunter.spirit_t` makes `World.occupy(..., ghost)` and the block push-out skip rocks, trees and barriers.
- Telegraphs are AimKit: `draw_rest` (line), `draw` (vee, then line), `draw_tgt` (circle), `rmb_v` + `rmb_bar`, `e` (arc_wall, all, for the tell). Cursor: `AimKit.charge`, `flare`, `perfect`.
- Sounds: `tools/gen_pin_bjorn_sfx.py` writes `audio/pin_*.wav` (Sfx loads them on first use).
- Merge: `_drop_holds()` clears the draw (`h.draw_t`), the Heavy Shot hold (`rmb_down`, `pin_aim`), Spirit Walk (`h.spirit_t`), and Starpiercer (`PinUlt.left`, `PinUlt.nock_t`, `window`).
- Ult on X: `scripts/arch/ult_slot.gd` (UltSlot: the `hunter_ult` press, the level gate, the cooldown in `ArchKit.cd["x"]`, the bond hook), `scripts/arch/kits/pin_ult.gd` (PinUlt: the window, nock, beams, execute, pooled ribbons and pips). Data: `content/archetypes/archer.json` `x`. Sounds: `pin_ult_cast`, `pin_ult_nock`, `pin_ult_beam`, `pin_ult_final`. Bond: `UltSlot.on_land` sends `KinBond.from_ult(h, "hit" / "knock" / "kill")` (a stand-in with the same amounts until the hook lands on main).
- No Net shape change: remote players see the shots and the existing fx events (rings, bolts).

## Payoff
Deadeye: gold second hit with T4 hitstop and shake, its own sound, "DEADEYE" word and `pin_deadeye`. Pins say "PINNED"; knocks say "RUN DOWN".
