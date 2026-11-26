# Combat clarity: who, what, and what it did (2026-11-11)

Owner playtest 11-11 (0.24.4): "very unclear when fighting people who they are, what they're doing ... the combat
needs to be way more clear (doesn't mean more UI on the screen), just more clear abilities". This pass makes the
shared layer carry the read on the bodies and the ground, and takes clutter off the screen. The per-Hunter looks are
the per-Hunter jobs' (VFX_QUALITY.md); the audit below lists what is still theirs.

## How the source keeps a fight readable (and what we take)
`docs/DASHES_AND_ABILITY_FEEL.md` §5 has the research (REFERENCE, Battlerite, Riot, Overwatch). In short: the enemy
is red on the body and on the ground (outline + telegraph rim), your own and allies' looks are calmer; a cast reads on
the caster first; crowd control reads on the victim's body (a stun ring over the head, roots at the feet); floating
text is rare. Our looks stay ours: the signature colour is the body of every effect, the side colour is an edge.

## The shared rules (code)
| what | where | rule |
|---|---|---|
| who: the body | `SideRings` + `hero_toon` `side_rim` | every other Hunter's silhouette carries a band in the viewer's side colour (`SideColor`: ally blue, rival red), outside the signature band; none on your own body (your ring says it) |
| whose: the looks | `SideColor.fx` | other people's ground areas, telegraphs (ArchKit `tele_circle` / `tele_lane`, AimKit shapes with `all`), charge rings, shot halos and area landings lean to their side: a teammate's 30% to ally blue, a rival's 45% to hostile `#ff2d55`; the core of a shot keeps the shooter's colour |
| what: the cast | `BodyTell` | any ability (not the LMB or the dash) glints the caster's body in their signature colour (0.3 s) and rings their feet in the side colour; AbilityFx's own caster ring stays for Boki only |
| the true area | `AbilityFx.land` / `cast` | an area landing rings exactly its radius (was 1.15x), in the side lean; a zone cast rings its radius once (the extra 1.8x ring is gone) |
| the true area: lines | `AimKit.span` `width` | a placement line can carry the band it hits under it; Tenzo's X cracks sit on the 3.2 m band its rise slows (was a 0.16 m line), `docs/shots/combat-clarity/tenzo_x_tell_band.jpg` |
| the hit | `Ent.render` | the hit flash holds full white for 3 frames (`FLASH_FADE`), then fades |
| what it did: CC | `StatusLooks` + `BodyTell` | each status's own body look (`StatusLooks`, docs/STATUS_LOOKS.md: stars over the head for a stun, stakes at the feet for a root, rings down the legs for a slow, and Grounded, Dazed and the rest), the same from every source; and the body pulses that colour while it lasts (`BodyTell`). No floating CC words: a status is an icon with its time ring in the plate's status row (`HudPlate.row`), and the plate keeps the name (no word in its place) |
| less text | `Fx.word` | one floating word at a spot at a time (`WORD_ROOM` 3 m, `WORD_HOLD` 0.6 s), smaller (28 / 40 px) |
| less text: Boki | `BokiChatter.heard`, `Match.on_kin_ability` | while you or a squadmate fights (`BokiChatter.calm`) only your own Boki's speech bubble is drawn and no callout pin ("Behind you! · 3m"; `--clarity-shots` prints `CLARITYCHATTER n/20`, 0 is the rule); a Boki's ability name floats over your own Boki only (others' read from their looks) |
| less text: hover cards | `HudHover.draw_world_tip` | the card about a monster, Boki or Hunter under a resting cursor ("Lace / The Red Stitch", "Boki: Prismander") is not drawn while you or a squadmate fights (`BokiChatter.calm`): in a fight the cursor rests on whoever you aim at. `--clarity-check` budget `hud world_tip` 0 |

## Ground order (11-12): a melee is not one disc
A ground ring means gameplay, so in a pile the draw order and strength are one rule (`SideColor.ORDER_*`, a material's
`render_priority`; `SideColor.order(m, by)` picks the tier):
| tier | what | rule |
|---|---|---|
| top (3) | a rival's telegraphs and area rings (`Fx.telegraph_*`, `Fx.ring`, AimKit `all` entries; bosses and Boki enemy areas too) | drawn last; AimKit puts them in their own surface after yours |
| 1 | your own casts | over a teammate's |
| 0 | a teammate's casts | over the rings |
| -2 | ownership rings (`SideRings`: Hunter and Boki) | thinnest band (`THIN` 0.07), and `COVERED_K` 0.25 of their alpha while any telegraph, cast ring or AimKit shape covers the body |
One full-strength fill under a body: `Fx.stack_telegraphs` drops a telegraph whose centre lies inside a higher one (the
later on a tie) to `UNDER_A` 0.35 of its alpha until that one ends; AimKit fills are already faint (0.18). Checked in
`--clarity-check` (3v3 pile, Boki out) and `--aimkit-check`; stills `docs/shots/combat-melee-ring-stack/` (`before*.png` on the clarity branch tip 8c5cc0019, `after*.png` on this; `_close` is a 2x crop) from
`--ring-stack-shots`, GPU jobs 20261112-114315-11530 / -13824.

Checked by `--clarity-check` (side edges per viewer, the side lean, the shot halo, stars / tendrils / frost / tint on
and off, the cast glint and ring, Boki bubbles and ability names in and out of a fight); the X band by
`--dolm-combo-check` and `--aimkit-check`.

## Toasts on the right rail (11-23)
Toasts ("Fever is lit", "Bond full!") sit in the right rail under the alive counter and the kill feed (`TopStack.rail`), never in the top centre by the timer, level and HP. `--clarity-shots` pushes one on every fight frame and prints `CLARITYTOAST n/20`: n must be 0 (it was 20 before the rail).

## Downed screen: one line for who, the tip clear of the card (11-24)
Downed, the screen said who did it three times in the middle of the fight: "Knocked down by Kael", "You're down" and the card's "Downed by Kael with Warchain". The killcam line is now for a dead Hunter only (`Hud` draws `Match.killcam_text` when `p.out`); the downed screen is "You're down" plus the card. The "TIP" line was drawn through the card's two lines (and, moved under it, sat on your own wisp): it is now above "You're down" (`Hud._draw_downed`), where the screen is empty ground.
## First-time armour hint waits out the fight (11-24)
"Hits on Hunters build armour. XP comes from monster kills." (`ArmourHint`, drawn by `ArmorHud.note` just over the LV / XP row) comes from your first hit on a Hunter, so it always landed mid-fight: its box sat on the vitals and on the fight next to them. While `Hud.in_fight()` is true it now waits, keeping its whole 6 s for the next lull. `--armour-hint-check` holds it.

## Lace's Hail Wall laces (11-24, moved)
The wall's red threads used to part round a shown Hunter (`PinFx._part_laces`, `PinFx.LACE_CLEAR`). The wall is now
the laced `AimKit.arc_wall` (one pooled mesh, `archer_kit.gd`), so those per-lace nodes are gone and the parting with
them; threads cross bodies again until the pooled arc learns to skip a Hunter's box. Open item.

## What sits on a Hunter (11-20, stabilize sprint: declutter only)
`--clarity-shots` also plays a bot 3v3 of the slice Hunters on the Hollow Crown (`tools/clarity_fight.gd`: Vex, Kael,
Lace / Cinder, Vex, Kael and Cinder, Lace, Vex / Lace, Cinder, Kael), 10 frames a fight, and counts every element over
or within one body width of each Hunter's screen box (`HunterZone.rect_of`): world words, numbers, icons, rings and
effects, and the HUD's world marks recorded through `SafeArea.note_as` (plates, the glove row, combo badges, the merge
timer, Boki status). The Hunters' and Boki's own bodies (skinned meshes, model glows, the blob shadow) are not counted.
Frames covered of 20 (element-Hunter pairs), headless count, before -> after:
| element | before | after | gameplay? |
|---|---|---|---|
| nameplates | 20 (450) | 20 (414) | yes: health |
| glove + Boki-type icons under other Hunters' plates (`GripOverhead`) | 20 (322) | 15 (70) | no in a fight: only the merge-ready glow stays |
| ownership rings (`SideRings`) | 20 (240) | 20 (218) | yes |
| your damage numbers (`Fx.number`) | 17 (137) | 17 (130) | yes, already only yours |
| merge look's ground ring (`MergeLook`) | 13 (68) | 0 | no: cut, a ground ring means gameplay |
| merge form's name over the head (`BokiHud.form_overhead`) | 12 (68) | 0 | no: a floating word; the timer and shell bars stay |
| your Boki's ability name ("Stinger Hook") | 1 (3) | 1 (3) | kept (DECISIONS 11-11) |
`--clarity-check` holds the fight to `ClarityFight.BUDGET` (element-Hunter pairs a frame): no words but your own
Boki's ability name, no world icons, the glove row at most 6 (was 16), no merge ground ring.
The budget is unchanged (a fight frame measures 0 to 3.6 glow icons; with the row on, a frame is 9 to 18). What was
flaky was the sample, not the cost: the bot trio-vs-trio is not repeatable (the same seed gives a different fight each
run, a global `randf()` and timing outside `Match.rng`), and the bots often wander off for the 2 s combat window
(`InCombat`), where the row is meant to show. `ClarityFight.play` now marks your Hunter in combat on every counted frame,
so each one is a fight frame whatever the bots did. 11 of 19 runs failed on a loaded host before, 0 of 10 after.

## Films
`docs/shots/combat-clarity/fight_3v3_a.mp4` (Tenzo, Sparkle, Lace vs Kael, Cinder, Vex) and `fight_3v3_b.mp4` (Meeko,
Albert, Neve vs Grimble, Motley, Sable): the same seeded 3v3 before (left, main 272368589) and after (right), at the
match camera. Made with `--gameplay-media --media-clip=1 --media-fight=<a,b,c/d,e,f> --media-zoom=1.0 --media-secs=12
--media-size=1280x720` (a software render under xvfb-run here: the GPU queue was 50+ deep). The bots don't fight the
same way twice, so the two halves drift apart after the first seconds.

## Audit (game camera, match zoom, from the films and docs/parity_reel)
Grade: clear / unclear, worst first. "Shared" = fixed or helped by this pass; the rest is the Hunter's own job.

| Hunter | grade | why (what still reads badly) | owner |
|---|---|---|---|
| Grimble (dredge) | clear-ish | ult fixed: the fan is the true area in his gold (`#ffc832`) at AimKit's low fill, the crescent that swept the fan each wave is cut, each slug draws only its own orb (Match's plain sphere and its 3 m halo went under it), the wave flash at his fists 0.6 m (was 1.9 m) and a slug's hit glow 0.4 m (was 0.9 m); still four colours across the kit | ult on `ext/combat-grimble-ult-clarity` (stills `docs/shots/combat-grimble-ult-clarity/`), the rest per-Hunter |
| Motley (ostra) | unclear | several large violet well discs at once, no edge to tell whose (now leaning red/blue via shared telegraphs only where they go through ArchKit/AimKit); indigo vs teal signature | per-Hunter job |
| Meeko (tender) | unclear | big gold seed rings and teal ult dome fill the ground under everyone; heals and hurts look alike | ext/vfx-meeko-heal-hurt: heals leaf green rising, hurts embers falling; Hearthlight and root field at most 0.25 inside to the rim, the bloom a rim swirl (docs/shots/vfx-meeko-heal-hurt/) |
| Sable (thief) | unclear | LMB hits barely show; her X discs are pale | per-Hunter job |
| Albert (bulwark) | clear-ish | the gold box was his aegis: now gold plates with an ivory rim, no dark cubes; his E disc is an ivory rim with a soft centre, Meeko's rings are leaf green | `ext/vfx-albert-e-slab` (strips `docs/shots/vfx-albert-e-slab/`) |
| Sparkle (mage) | unclear | Kitefall's range disc washes the ground pink-violet; the Storm Rod lane is a thin cyan line next to pink orbs | fixed on READY `ext/vfx-sparkle-ult-local` (disc gone, lightning pink) and `ext/vfx-sparkle-casts`, not merged |
| Tenzo (dolm) | clear-ish | Stone Row rocks read as objects; Quakefall's slam ring is plain and the X spine's line is thin at match zoom | X: the cracks now sit on their true band (this pass); slam and the cracks' scorch on READY `ext/vfx-tenzo-data`, not merged |
| Vex (gunslinger) | clear-ish | the lime body reads; LMB tracers are faint | per-Hunter job |
| Neve (rimewright) | clear | shards and the shatter read; the dash ice path is flat boxes | per-Hunter job |
| Lace (archer) | clear | orchid threads and the Heavy Shot read | per-Hunter job |
| Kael (juggernaut) | clear | the bar: slash arcs, burning lanes | per-Hunter job |
| Cinder (ashwick) | clear | the bar: layered flame cone | per-Hunter job |

Shared things still noisy in the films: Boki ability names (`Stinger Hook`, `Prism Wall`) over other people's Boki
and other Boki's bubbles ("Echolope: behind you!") are now off in a fight (above). The "Hold F to
stomp" prompt is one short HoldPrompt ring in the prompt bar, for the one closest downed rival inside stomp reach
only (`StompTarget`; a teammate's Wisp never asks, no world text on the Wisp; `--stomp-check`). Boki rings and the
Hunters' cast rings stack under a melee (fixed: Ground order, above).

## Hunter against the ground (11-23)
Every Hunter in sight wears a dark ground rim: the OcclusionOutline overlay (`shaders/occlusion_outline.gdshader`)
draws its shell's fringe in ink (`rim_*`, >= 1.6 px of a 720 px view) wherever the scene behind it lies >= 0.25 m
farther away, so only the outer silhouette against the ground gets it, never a belt or fold over the model (a full ink
shell there read as speckle at the match camera). Off on Low with the cover outline.

`--clarity-shots` prints `CLARITYCONTRAST <rim on> over <k> frames (rim off <n>, +x%)` for the bot 3v3 on the Hollow
Crown (`tools/clarity_contrast.gd`). Each frame is drawn five ways with particles held still: as played, with the rim
off, the Hunters' bodies alone (a clean silhouette mask on their own render layer) and an empty pass, and with the
bodies out but their shadows kept. At each step across a silhouette the score is the strongest colour step (RGB, 0-100)
from the body's edge pixel or the one just outside it to the bare ground beyond. Both numbers come from the same
frames, so the bot fight's randomness (who is downed, which VFX cover whom) cancels out; two runs of one scene differ
by up to ~25% otherwise.

The first metric (the diff of the frame with and without the Hunters) counted their shadows, grass that moves with the
bodies and HUD toasts as Hunter pixels: 60% of its edge samples were those, which is why the ground recolours
(slate, teal-slate, sage, a whitened `rim_far`) never moved it. The fight harness (`tools/clarity_fight.gd`) also never
ran `OcclusionOutline.for_match` (`Match._process` is off there), so no outline showed in clarity shots before 11-23.
Results (rpg6, GPU, 4090, three runs): rim on vs off +35%, +48%, +20% (10, 12, 7 frames); pooled over the 29 frames
24.1 vs 17.6, +37%. The +30% goal (focus baseline 11-22) is met on the pooled number; a run of under ~10 frames swings
±15%.

## Smoke puffs part on screen too (11-24)
A smoke cloud (`Models.gear_smoke`: 14 opaque spheres up to 2.6 m, lit pink on the Hollow Crown) parted only round a
Hunter's feet on the ground (`FxHunterCap._part`, radius + `PUFF_CLEAR`). The camera looks down at a slant, so a puff
on its side of a Hunter still buried the body: the "pink sphere clusters" over a fight. A puff now also hides while its
disc on screen covers a shown Hunter's box (`HunterZone.rect_of`). Concealment (`Match.in_smoke`) is untouched.
`--fx-hunter-cap-check` holds it (a puff 3.6 m off on the ground, between the camera and the Hunter, parts).

## Own and ally telegraphs are a faint rim, a rival's is the strong one (11-25, baseline problem 8)
The baseline (`coord/focus-1122`, problem 8) had a red zigzag and a hatched striped lane round the player: the zigzag is
Lace's laced AimKit lane (`lace`: Heavy Shot bar, Hail Wall arc), the stripes are `telegraph.gdshader`'s hatching and
fill on your own charge ring, casts and ground warnings. One rule, by the side tier (`SideColor.order`):
| viewer sees | Fx telegraph (`telegraph.gdshader`, `quiet`) | AimKit shape (`AimShapes.for_viewer`) |
|---|---|---|
| your own or an ally's | `quiet` 1: no hatching, no inner glow, `QUIET_A` 0.4 of the alpha | plain lane or wall: no lace crossing, no chevrons, `QUIET_A` 0.5 of the alpha |
| a rival's, a monster's or a boss's | unchanged, rim lit more (hot 0.6) | lit to `FOE_HOT` 0.3: a brighter, thicker rim in the foe colour (`SideColor.fx`) |
`Fx.telegraph_circle` / `telegraph_rect` now default to the rival tier (a monster's or tutorial warning is a threat);
yours pass `SideColor.order(m, hunter)`. Hit shapes, radii and timings are untouched: the lead stays as in
`docs/TELEGRAPH_LEAD.md` (`--telegraph-lead-check` 64 checks, 0 failures). `--clarity-check` holds both halves.
`--clarity-shots` (GPU rp3g / rp2g, bot 3v3, 20 frames, same bots both runs) tags a quiet telegraph in its tally:
Fx telegraph element-Hunter pairs 8 loud -> 3 loud + 5 quiet; elements over a Hunter per frame 119.1 -> 114.8; AimKit
shapes over Hunters unchanged at 6 pairs but plain for yours. Stills: `docs/shots/combat-own-telegraph-quiet/` (before
over after).
