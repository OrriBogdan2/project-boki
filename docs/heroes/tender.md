# Moosh Moosh, the Tender (`tender`, medium support)

Internal design doc (was "Linnet"; the id and file names stay `tender`). Source behaviour reference: the hero named in the Inspired-by table in docs/ARCHETYPES.md (gameplay only; nothing of its names, look or text is used in the game). The fidelity pass (ext/kitfix-moosh-tamsin) worked from the footage reference sheet (`briefs/hero-ref/mooshmoosh.md`), the public wiki page and the owner's notes. Scale: 1 body height (bh) = 1.8 m.

## Our kit
| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive Bearer | run into a downed teammate | Carry up to 2 downed teammates behind a 40 (+6/level) shield; they don't bleed and can't be stomped; you move 30% slower; crouch sets them down; shield break, stun, root or hex drops them (0.6s stun, 4s lockout). Never one a rival is standing on. Embers Kindle foes (up to 5, 4s): +0.72 damage per stack (about +45% at 5), and an ember into a Kindled foe winds Hearthlight back 0.2s (0.4s Empowered) | Soulpack + Moon Burn | Mana return becomes cooldown wind-back (no mana here) |
| LMB Lantern Crook | hold | An ember every 0.4s that flies its full 9m, past the cursor (`"aim": "max"`). After 1s without firing, the next ember is Empowered: 40% further, double wind-back, its own bigger flick and chime | Crescent Bolt | Same |
| RMB Burrseed | hold to aim, release to throw | Held: a faint dotted lane (0.4 bh wide) to the seed's 11m (AimKit `dotted`) and a coiled pose. Released: a fast seed (30 m/s) sticks to the first foe (9 damage). A violet disc the size of the burst shows under them at once for everyone, filling. 0.7s later it flares: 32 damage and a 1.1s root in 2.2m, with root beams, and Kindles all. 8s cooldown | Darkside Binding / Bound by Fate | Footage timing (a fast orb, 0.6-0.8s) over the wiki's 2s |
| Shift Relay Step | tap (in the air: the long dash) | A 4.2m hop where you move. Through a teammate: half a dash back and 1s off Hearthlight. Rank 3: picking up a teammate refreshes the air dash | Lunar Dash | Goes in the movement direction (footage); the "Dash toward the cursor" setting covers the other preference |
| E Hearthlight | tap, tap again to throw | A 2.6m (1.4 bh) ring of light on you for 2.5s heals teammates 10 over its life, then flares for 22; you at a third, a downed teammate five times over. E again throws it to the cursor (up to 9m) at 45 m/s: it lands almost at once as a brighter 2.9m disc, heals 50% more for 1s (2s at rank 3), and latches onto the first teammate it passes (or onto the one you carry, aimed at yourself). A stun on you puts it out | Rejuvenating Aura / Moonlight Blessing | Radius from the footage (1.3-1.6 bh). Rank 3 is the source's level 4 again (the doubled throw boost); the revive it borrowed went back to the X ultimate |
| X Hearth Call (level 6) | X with the cursor on a teammate (tap) | While it is ready and the cursor rests on a teammate in reach, a gold ring of 12.6m (7 bh) round her shows the reach and a line runs onto them. X starts a lantern tether that heals them 7 a second for 5s while she walks and casts freely. At the end a downed teammate is pulled to her side and stood up (a green arrival burst). While they are down the healing goes to her. It breaks if she is knocked or stunned or they leave the ring. 46s cooldown. Solo (no teammate in the match): it lights on her | Divine Intervention | Our own lantern tether and arrival look (no crescent motif) |
| R | none | The Boki Merge | (Merge) | Merge stays on R |

Scaling: HP 145 (medium). Hearth Call heals 35 over 5s (7/s, about a quarter of a medium health bar); cooldown 46s against Hearthlight's 11s (source card 41.6 : 10). Ratios kept: an ember is 8, rising to about 11.6 at 5 Kindle (+45%; footage 64 -> 93). The seed burst is 32 (4x an ember). Hearthlight is 10 + 22 per squadmate. Cooldown ratio: Burrseed 8s against Hearthlight 11s (source about 7.2 : 10).

## Small mechanics
| Mechanic | Source | Footage confirms | Built | Check |
|---|---|---|---|---|
| A teammate being stomped can't be picked up | [wiki](https://supervive.wiki.gg/wiki/Elluna) | no | yes | "a teammate being stomped can't be scooped up" |
| The shield refills on each pickup; a break or crowd control drops them, stuns you, 4s no pickup | [wiki](https://supervive.wiki.gg/wiki/Elluna) | no | yes (existing) | `--support-check` Bearer rows |
| The Empowered shot after a pause: more range, double return | [wiki](https://supervive.wiki.gg/wiki/Elluna), card | card only | yes | "after a pause the next ember is Empowered" |
| Embers fly to max range, past the cursor | footage | yes | yes | "the ember flies its full range past the cursor" |
| Bound by Fate shows a lane to max range while aiming and fires on release | footage | yes | yes | "held, a dotted lane..."; "nothing leaves while it is held" |
| Its area shows at once and roots about 0.6-0.8s later | footage (the wiki says 2s) | yes | yes, 0.7s | "it roots about 0.7 s after it sticks" |
| The aura's recast throws it to a spot, and it sticks to the first ally it passes | [wiki](https://supervive.wiki.gg/wiki/Elluna), footage | the spot, yes | yes | "thrown, it lands on the cursor"; `--support-check` latch |
| A stun on you puts out the aura riding on you | [wiki](https://supervive.wiki.gg/wiki/Elluna) | no | yes | `--support-check` |
| Dashing through an ally refunds half a dash and 1s of the aura | [wiki](https://supervive.wiki.gg/wiki/Elluna), card | no | yes | `--support-check` |
| Rank 3 (source level 4): picking up a wisp refreshes the air dash | [wiki](https://supervive.wiki.gg/wiki/Elluna) | no | yes | `--support-check` |
| Healing is x5 on wisps and x0.33 on yourself | [wiki](https://supervive.wiki.gg/wiki/Elluna) | no | yes | `--support-check` |
| Relay Step goes where you move, not at the cursor | footage | yes | yes | "Relay Step goes where you move" |
| X: she can move while the tether channels | footage (f41-f72) | yes | yes | "mm X: she walks while it channels" |
| X: other abilities can be cast during the channel | [wiki](https://supervive.wiki.gg/wiki/Elluna) | no | yes | "mm X: other abilities still cast during the channel" |
| X: it ends if she is knocked or stunned, or moves too far from the teammate | [wiki](https://supervive.wiki.gg/wiki/Elluna) | no | yes (break range = the 7 bh ring) | "mm X: it breaks when the teammate leaves the ring, and pays nothing" |
| X: on a downed teammate (wisp) the heal goes to her, and at the end they are resurrected and teleported to her | [wiki](https://supervive.wiki.gg/wiki/Elluna), footage f74-f75 | the teleport, yes | yes | "mm X: while they are down the tether heals her instead", "... pulled to her side and stood up" |
| X: unit-targeted, an aim line onto the ally first | footage f19-f24 | yes | yes (a tap; the line and ring show while the cursor is on a teammate) | "mm X: with the cursor on a teammate, the 7 bh reach ring and a line onto them" |

## Assumptions
Where the footage and the wiki are silent, this is the most likely behaviour, and each is easy to change in `content/archetypes/tender.json`:
- The Burrseed area **sticks to the foe** and moves with them (the dummy in the footage doesn't move).
- The root lasts 1.1s (wiki). Damage is 32 (4x an ember), down from 35, because the shorter window is more reliable.
- The Hearthlight keeps its heal amount and duration when thrown. The throw reach is 9m.
- Kindle: 5 stacks, 4s, refreshed per hit, no per-stack decay (the wiki says up to 5).
- The Empowered pause is 1s.
- **Hearth Call:** it can't be ended early (no recast in the source); X again is ignored. Damage on her does not break it (the wiki lists only knocked, stunned and range). The break range is the same 12.6m as the cast range. A downed teammate in our game is the source's wisp. Its healing does not scale with ranks (no X ranks); it grows with level (LevelGrowth). The cooldown starts on the cast. With no teammate in the match at all it lights on her (healing at a third) so the key is never dead in solo play.
- **Hearth Call and the bond:** a completed tether counts as a "hit" for `HeroUlt.from_ult` (`KinBond.from_ult` once ultbond lands), a rescue (a downed teammate stood up) as its top event ("kill"); a broken one pays nothing. The sheet's +0.2 on the teammate's own meter is not built (the amounts are the main session's, in boki_system.json).
- Kindle readability is a foot glow that warms from violet to ember per stack. Tinting damage numbers by stack (sheet gap 9, optional) is not done: the numbers come from the shared damage path.

## Combinations
| Interaction | Implemented in | Check (`--tender-combo-check` unless noted) |
|---|---|---|
| Ember into a Kindled foe winds Hearthlight back | `on_deal` | "an ember into a Kindled foe winds Hearthlight back" |
| Kindle adds damage to embers (+45% at 5) | `outgoing` | "Kindle ramps embers about +45% at 5 stacks" |
| Idle crook: the next ember is Empowered | `_tick`, `_tick_look` | "after a pause the next ember is Empowered" |
| Burrseed: a lane while held, sticks, the area at once, roots at 0.7s, Kindles | `rmb_hold_tick`, `_stick`, `_tick_burrs`, `_burst` | the four "mm RMB" rows |
| Relay Step through a teammate: half a dash + 1s off Hearthlight | `on_dash` | `--support-check` |
| Hearthlight thrown to the cursor; latches onto the first teammate it passes | `e_recast`, `_tick_hearth` | "thrown, it lands on the cursor"; `--support-check` |
| Hearthlight thrown at yourself lands on the one you carry | `e_recast` | `--support-check` |
| Hearthlight on a downed teammate (5x), rank 3 revive on the flare | `_pulse`, `_hearth_end` | `--support-check` |
| A merge start ends the Burrseed aim with no throw (`seed_aim`, `rmb_down`) | `_drop_holds` | "drop_holds ends the Burrseed aim" |
| Hearth Call: the aim telegraph (ring, line) on a teammate under the cursor, X to tether; heals while she walks; pulls a downed teammate home and stands them up | `_call_preview`, `cast_ult`, `_tick_call`, `_call_home` | the "mm X" rows |
| Hearth Call + Hearthlight thrown on the arrival spot (the sheet's pairing) | both run at once | "mm X: other abilities still cast during the channel" |
| Hearth Call pays the bond only on a completed tether or a rescue | `_call_end` -> `HeroUlt.from_ult` | "mm X: no bond is paid for the cast alone", "... pays the bond as a hit", "a rescue pays ... (kill)", "it breaks ... and pays nothing" |
| A merge start ends Hearth Call (no pull, no bond; `hearth_call`) | `_drop_holds`, `ArchKit.drop_holds` | "mm merge: drop_holds ends Hearth Call" |

## Animation moves
The moves live in `scripts/match/kmoves_care.gd` (`KMovesCare.MOVES`, read by `HunterAnim.km_sample`). The kit plays them with `play()` for abilities, or `play_soft()` for procs (it waits for the current move to finish). `wa` / `wo` are the weapon pivot channels added for this pair, so the crook swings in the hand.

| Ability | Move | Beats (s) | Shape |
|---|---|---|---|
| LMB ember | `mm_shot` | 0.06 coil, 0.10 release, 0.17 overshoot, 0.34 settle | the crook cocked over the shoulder and flicked down at the cursor; a swirl ring at the hand |
| LMB Empowered | `mm_shot_emp` | 0.09 / 0.14 / 0.26 / 0.5 | up on the toes, a big flick, the free arm thrown back |
| RMB held | `mm_seed_aim` (hold) | 0.12 | side-on, the seed cupped by the ear |
| RMB release | `mm_seed` | 0.05 deeper coil, 0.10 whip, 0.22 overshoot, 0.5 | an overhand whip into a lunge; the cast flare round her |
| RMB root goes off | `mm_tug` | 0.05 / 0.11 / 0.36 | a tug back on the free hand |
| E lit | `mm_hearth` | 0.08 crouch, 0.18 up, 0.34 hold, 0.6 | gathers low, then thrusts the lantern hand high (the plus and rising rays) |
| E thrown | `mm_toss` | 0.06 / 0.11 / 0.24 / 0.48 | an underhand fling at the cursor |
| E flare (payoff) | `mm_flare` | 0.07 / 0.15 / 0.3 / 0.6 | both arms flung up |
| Shift Relay Step | `mm_dash`, `mm_relay` | 0.05 stretch, 0.14, 0.2 landing squash, 0.42 | a crouch, a stretched tucked hop, a squash on landing; the relay variant waves over the teammate |
| Air dash | `mm_dash_air` | 0.06 tuck, 0.16 roll, 0.24 catch | a tucked forward roll |
| Bearer pickup | `mm_pickup` | 0.12 squat, 0.3 heave, 0.55 | a scoop and a heave onto the pack |
| Kindled to 5 | `mm_kindled` | 0.08 / 0.2 / 0.34 | the crook spun once in the fingers |
| X cast (f25) | `mm_call` | 0.05 coil, 0.1 thrust high, 0.2 overshoot, 0.35 into the channel | the hand pulled back low, then thrust up as the plus bursts on the teammate |
| X channel (f26-f73) | `mm_call_hold` (hold) | 0 / 0.3 | one hand held high over the tether; the legs keep walking |
| X end (f74-f77) | `mm_call_end` | 0.07 sweep down, 0.14 arms open, 0.3 | the raised hand swept down to her side (the pull home), open on the arrival burst |

The dash leaves after-images in her lantern colour (CareLook "aft").

Strips: `--arena=thief --arena-demo=care_tender_<lmb|emp|rmb|e|dash|air|carry|payoff|pose|ultaim|ultkey|ult> --arena-shot=<png>` (scripts/match/care_demo.gd) saves the frame and a 6-frame strip.

## Look and sound
- Pooled looks (`scripts/arch/kits/care_look.gd`, shaders `care_disc` and `care_glow`): the ember comet with its tail and a violet-star impact, the burr orb, the Burrseed root disc with thorns, the light column and root beams, the lantern plus and rising rays, the ring on her and the brighter thrown disc, the Kindle foot glow, and the dash after-images. Nothing is created per shot. Hearth Call's tether (a braid of warm light with two twisting strands) is pooled in `UltLook` (`ult_look.gd`, extends CareLook); its reach ring, pick ring and aim line are AimKit circles and a line.
- The Lantern Crook model: a knotted staff, brass collars, a caged lantern with a glass glow, ribbons and a bell (`hero_gear_care.gd`).
- Sounds (`tools/gen_care_sfx.py`, all synthesized): `tend_ember`, `tend_ember_emp`, `tend_seed_aim`, `tend_seed`, `tend_stick`, `tend_root`, `tend_hearth`, `tend_toss`, `tend_land`, `tend_flare`, `tend_hop`, `tend_relay`, `tend_pickup`, `tend_kindled`, and for Hearth Call `tend_call` (a soft choir swell and chime), `tend_call_hum` (the channel's hum) and `tend_arrive` (a whoosh and two bells). They load through `SfxKits.NAMES`. Before this pass none of the pair's sounds were loaded at all.

## Engine notes
- Kit: `scripts/arch/kits/tender_kit.gd`, with helpers in `care_util.gd`. Data: `content/archetypes/tender.json`, `content/weapons/lantern_crook.json`.
- Merge-start hold fields: `seed_aim` and `rmb_down` (the Burrseed aim), the carry (set down, unbroken), and `hearth_call` (the X channel).
- X: the shared ult base `HeroUlt` (`scripts/arch/hero_ult.gd`, byte-identical across the six ult branches) routes the `hunter_ult` key (the level gate, the cooldown in `cd["x"]`, the bond stub); the kit overrides `cast_ult`, `ult_running`, `ult_recast`. Numbers are under `"x"` in `content/archetypes/tender.json`. A downed online teammate rides home on the existing "carry" event and stands up through "rev".
- Net: unchanged (0.16.0, main's); the ult adds no sync shape. The carry uses the existing "carry" event; heals and revives reuse "heal" and "rev". The Burrseed area and the thrown disc are local looks; remote players see the existing Net rings.
- Checks: `--support-check` (all), `--tender-combo-check` (support + combos, `tools/care_combo_check.gd`).
