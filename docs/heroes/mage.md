# Sparkle the Storm Chaser (archetype id `mage`, Light)

Internal design note. This file may name the source hero for traceability; nothing in the game does.
Source behaviour reference: the hero named in the Inspired-by table in docs/ARCHETYPES.md (reference
sheet: briefs/hero-ref/vireo.md, from gameplay footage; owner playtest notes override the footage).
Our hero is an original character, the storm-kite runner: flight goggles, a cropped jacket, copper
coils at both wrists and a copper rod mast flying a pennant. Palette: teal and hot pink lightning, copper rod (the lightning, orbs and Static marks are teal + pink; not yellow). Payoff word: BLOWOUT.

## Kit card (L picker)
- Role: Ranged lightning skirmisher: charge one foe to 4 Static, then Wirerun through them.
- LMB, RMB, E, Shift, passive and the ultimate: one plain line each in `content/archetypes/mage.json` `card`
  (the ultimate's line is `card.x`; the kit card's last tile shows it on the hunter-ultimate key).

## Scaling
Source health is roughly 8 to 10 times ours (Light = 124 HP). Ratios kept against the basic attack:
bolt 12 every 0.648s (item 116; about 18.5 dps, unchanged from before); Storm Rod 18 to 30 (1.5 to 2.5 bolts; the
source is about 4, held lower because the rod also stuns and leaves an orb); Skycall 20 (source 2.5
bolts, ours 1.7); Wirerun pass 10, doubled through a full-Static foe, plus a Blowout of 16 + 18% of
their health (about 5.7 bolts on a Light; the source detonation is about 9). Cooldowns follow the
source ratio spear : Surge : javelin = 7 : 6.7 : 9.2, at our pace 8 : 8 : 10.5. Kitefall (the source's
landing is 40 + 22%, seen at about 115, so about 1 bolt at our scale; it is held at 22, 1.8 bolts, because
its worth is the escape and the Static) knocks back about 1 bh and adds 1 Static. Its cooldown follows the
source's 37.5 s at our pace, 42 s. Ranges use 1 body
height = 1.8 m: bolt and rod lane 13 m (about 7.5 bh), Wirerun 7.5 to 13 m (owner item 70; not scaled by the dash feel), Skycall circle 1.5 m radius.

## Ranks (kit data pass)
Rank 2 is the shared step (cooldown -10%, damage +15%). Rank 3 is the hero's own: Storm Rod throw +50% damage
(`rmb.rank3_mult`; the source's rank IV is +50%), Wirerun's own hit doubles (`dash.rank3_mult`; the source's rank IV is
+100% on the non-passive dash damage, so the Blowout does not grow), Skycall cooldown -3s. The source has three
upgrades before the last one (+20% damage and -1s on the spear, -0.75s on Surge, +25% on the strike); our rank system has
one shared step and one special, so those collapse into the shared step.

## Parity pass (owner 18:45: animation and ability parity, LMB first)
Source vs ours per slot; [data] = the game data, [footage] = hero-ref/vireo.md at 5 fps. Asserted in `--mage-combo-check`
(`parity vireo: ...`, tools/parity_pvb.gd, plus the existing `LMB: ...` lines).

| Slot | Source | Ours | Status |
|---|---|---|---|
| LMB beats | alternating hands: a torso twist and one arm flung out, back to the wide arms-out stance; gold sparks at the feet [footage 0003-0020] | `mage_lmb_l` / `mage_lmb_r`: out at 0.03 s, settled by 0.35 s; sparks at the feet; a fan of splinters back toward her on impact | matches; asserted |
| LMB tracking | faces the cursor [footage] | each bolt leaves along the cursor of its step and the body faces it, while walking and with the cursor sweeping 60 deg/s | matches; asserted |
| LMB cadence | one bolt every 0.8 s held, no magazine [data card, footage] | 0.648 s (owner items 70, 116), mag 99 | matches; asserted |
| LMB range and speed | always to max range (about 7.5 bh) past the cursor, about 18 bh/s [footage]; one target [data] | 13 m past the cursor, 37 m/s, stops on the first foe (audit fix) | matches; asserted |
| RMB spear | hold, summoned spear by the shoulder, body flash at full, overarm throw; fixed lane [footage] | Storm Rod: the same beats, fixed 13 m lane | matches |
| E Lightning Strike | place, then pick the pull direction; 0.8 s countdown; Grounded slide [footage] | Skycall: place, hold and drag, release (audit: was a 0.3 s flick), 0.8 s countdown, slide and Grounded 1.5 s | matches |
| Shift Surge | hold crouch, a streak at a constant ~32 m/s (ours: 40 m/s, owner item 70), an arrival burst [footage] | Wirerun: the same; **the arrival ring and spark spray and the press flash are gone** (owner: no rings or bursts on dashes; the hits are along the way), a dust puff instead | owner rule over footage |
| R Eye of the Storm | launch, hang, reactivate to crash at the cursor [footage] | Kitefall: the same | matches |

## Audit (Nov 3 23:40)
Rows of briefs/specs/kit-audit/vex_vireo_sable.md. (a) done on this branch, (b) fixed now, (c) not applied, with the
reason. Asserts: `--mage-combo-check` (`Skycall ...`, `small: ...`, `Kitefall (data) ...`).

| Row (sev) | Verdict | Where / why |
|---|---|---|
| E input: hold, drag, release (HIGH) | (b) | held E keeps the drag open (up to 1 s), the release commits; a tap drags away (asserted: still dragging at 0.6 s, the release starts the countdown) |
| Wirerun arrival ring (HIGH) | (a) | 6d054633 (and the press flash) |
| Blowout ground ring (MED) | (b) | removed; the copper pillars stay |
| Other cosmetic rings; strike rings bigger than the hit (MED) | (b) | rod summon, Live and take-off rings removed; Skycall's ring at its 1.5 m radius (was 2.3), Kitefall's at its 2.7 m (the 1.45x ring removed), the landing marker at the radius |
| E Static 2 vs 1 (MED) | (b) | 1 (data); asserted |
| E numbers (-) | (a) | already per items 9/9b |
| Shift pass damage 10 vs ~20 (MED) | (b) | 20 (1.7 bolts, the data's ratio); asserted |
| LMB pierce invented (MED) | (b) | removed; a bolt stops on the first foe (asserted) |
| LMB cadence / aim / anim (-) | (a) | parity f99f03c7 |
| Dash -> LMB / R rows (MED) | (a) | a10d678a (buffer, with source text) |
| Shift input / feel, Shift reset (-) | (a) | matches the owner; the orb-reset question is closed (owner rule: only a full-Static foe resets) |
| Passive: reset cue on Live, knock heal (LOW) | (b) | the misleading reset cue and the knock heal are gone |
| RMB / E / R self-shake (LOW/MED) | (c) | ext/no-shake owns item 50 |
| R Static spread (MED) | (b) | the highest Static among the foes the strike hits goes to every foe it hits, then the ult's own stack (owner item 72); asserted |

## Per-slot table
| Slot | Input | Aim | What it does | Telegraph / reticle | Move (KMovesVV) | Sound |
|---|---|---|---|---|---|---|
| LMB Coilcaster (finger gun) | hold, 0.8s per bolt | max range (13 m) past the cursor, `"aim": "max"` | a jagged bolt from the fingertip, left hand then right; stops on the first foe (data); 1 Static per hit | a thin line through the cursor to full range with an arrow tick (always up) | `mage_lmb_l` / `mage_lmb_r`: twist, arm flung out, snap, settle | `vv_bolt` |
| RMB Storm Rod | hold, release (full at 1.0s, throws itself at 1.2s, 0.33s minimum) | max range, a fixed 13 m lane | summons a copper rod; the throw knocks the first foe back about 1 bh (stun on a wall or another foe), 1 Static, leaves a charge orb at the impact at once | double-rail lane with chevrons for the whole hold; cursor charge ring; a white body flash and flare at full | `mage_rmb_hold` (rod by the shoulder), `mage_rmb` (overarm) | `vv_rod_summon`, `vv_rod_full`, `vv_rod_throw` |
| Shift Wirerun | hold, release (full at 0.6s, auto at 0.9s) | direction from the cursor, length from the charge only | the charge is spent on the press; while held you can't steer, you keep your height and your momentum drifts you; release: a lightning streak (shots pass through) that carries the drift; every foe crossed takes 10, a 4-Static foe takes double and Blowout, Wirerun back at once (the only early reset) | rails to max range, a big ticked end ring with a star sliding out (everyone sees the ring); cursor charge ring | `mage_dash` (crouch), `mage_dash_go` (stretched streak), `mage_dash_land` (re-form, overshoot); air press with no charge: `mage_dash_ex` tumble | `vv_surge_charge`, `vv_surge_go` |
| E Skycall | press, hold and drag, release (data) | at the cursor (11 m) | drops a circle; while E is held (up to 1 s) the drag follows the cursor from the circle (toward you pulls in, away throws out; a tap = away); the release commits it, then 0.8s countdown; lightning: 20, 1 Static (data), everyone inside slid about 3.4 m along the ground that way (peak 6.2 m/s, easing to a stop over 1.1 s) and Grounded 1.5s; flings orbs (steals a rival's) | ticked circle with a rim chevron + a drag arrow during the flick; then a dark violet disc with a crackling copper rim and a narrowing pillar (everyone sees it) | `mage_e` (one-arm sweep, snap down) | `vv_sky_place`, `vv_sky_count`, `vv_sky_strike` |
| Passive Static | | | hits add Static (4 max, 4.5s); a marker over the head shows pips and the count, with sparks on the body that grow per stack; the 4th calls a sky bolt (Live) | marker, sky bolt, arcs to the ground while Live | `mage_live` (finger flicked to the sky) | `vv_static_full`, `hero_blowout` |
| R Kitefall (ultimate, level 6) | press, then press again (R or LMB) | the cursor, clamped inside a 14.4 m (8 bh) ring round the take-off | a 0.3 s crouch, then straight up 5 m and hangs invulnerable (shots pass through, no damage) up to 1.7 s, the camera pulled back; the second press (from 0.25 s into the hang) or the hover running out strikes down at the cursor in 0.2 s: 22, a knockback (about 1 bh), 1 Static to everyone within 2.7 m; she is free to attack at once; 42 s cooldown | a gold range ring with ticks round the take-off (everyone sees it) over a dark violet disc with a gold rim, gold crackle on the rim; a small gold crown (ticked ring and star) at the landing spot (hers); a filled gold landing circle for 0.2 s before the strike (everyone); then a sky-to-ground gold pillar, two shock rings, a spark spray, and copper-gold crackle at her feet for 0.5 s | `mage_x` (crouch, squash), `mage_x_air` (stretched up, then arms flung wide), `mage_x_dive` (head first, fists down), `mage_x_land` (one knee and a fist, up into the stance) | `vv_ult_rise`, `vv_ult_hum`, `vv_ult_slam` |
| X | | | Fuse with your Boki (the Boki system's key, see below) | | | |

Charge orb: hovers 4s and adds Static to nobody (owner item 74). Walking over it, a Wirerun through it, or Skycall dragging it toward her within 9 m (it flies to her), picks it up and gives Wirerun back (owner items 71/74); any other Skycall fling is 6 m.

## Combinations
| Combination | What fires | Check |
|---|---|---|
| 3 bolts + Storm Rod / Skycall | the 4th Static: sky bolt, Live | `--mage-combo-check` |
| Wirerun through a Live foe | double hit + Blowout, Static spent, Wirerun back | `--mage-combo-check` |
| Wirerun through a foe under 4 Static | plain hit, no reset | `--mage-combo-check` |
| Storm Rod, then an orb next to the foe | the orb adds no Static (it is only a pickup) | `--mage-combo-check` |
| Walking over a resting orb | picks it up, the dash is back; an orb out of reach stays | `--mage-combo-check` |
| Wirerun through an orb | 2 Static on everyone near it, no reset | `--mage-combo-check` |
| Storm Rod into a wall / another foe | stun (both) | `--mage-combo-check` |
| Skycall dragged toward you | foes pulled in, Grounded (no dashing), 1 Static | `--mage-combo-check` |
| Skycall over a rival's orb | flung, now yours | `--mage-combo-check` |
| Skycall Grounded on you | no Wirerun | `--mage-combo-check` |
| Boki merge mid-hold | Wirerun refunded, Rod and an unflicked Skycall dropped, nothing fires | `--mage-combo-check` |
| Kitefall into a crowd, then Wirerun | 1 Static each plus the knockback; foes already at 3 go Live, so the Wirerun through them is a Blowout | `--mage-combo-check` (Static from the strike) |
| Kitefall on an enemy hunter, then the Merge | the strike fills the bond (KinBond.from_ult, a hit); the merge straight after never one-shots a full-health light hunter | `--mage-combo-check` (burst) |
| Kitefall as a dodge | invulnerable from the take-off to the strike; a strike on nobody pays no bond | `--mage-combo-check` |
| Boki merge while she hangs | she drops where she took off, nothing strikes, the cooldown stays spent | `--mage-combo-check` |
| Shift in Kitefall's crouch (item 51) | the Wirerun charges at once; the crouch waits, starts over where the run ended, and she launches from there (the ring moves with her) | `--mage-combo-check` (`Kitefall + Shift ...`) |
| Jump in Kitefall's crouch (item 51) | the jump goes at once and she launches from up there; the climb starts at her height (no drop first) | `--mage-combo-check` (`Kitefall + jump ...`) |
| Shift or a jump while Kitefall has her up | nothing: the flight is the ult's own move, held over the ring (the recorded exception in content/dash_flow/mage.json) | `--dash-flow-check` |

## Small mechanics
| Mechanic | Source | Footage | Built and checked |
|---|---|---|---|
| The bolt passes through every target it strikes | [wiki: Joule](https://supervive.wiki.gg/wiki/Joule) (Jolt) | not shown | no (audit): the game data says one bolt; it stops on the first foe ("a finger bolt stops on the first foe") |
| Surge passes through targets and hits each one | [wiki](https://supervive.wiki.gg/wiki/Joule) (Surge) | shown (pass hit 146) | yes: "Wirerun hits every foe it passes" |
| Surge ignores projectiles; stuns, roots, grounds cancel it | [wiki](https://supervive.wiki.gg/wiki/Joule) patch 05.03.25 | INVULNERABLE label shown | yes: phase while running; "a stun mid-hold cancels Wirerun" |
| Knocking an enemy does not reset Surge | [wiki](https://supervive.wiki.gg/wiki/Joule) (Surge) | not shown | the kit adds no knock reset; since sync65 the game-wide takedown reset (DashReset) gives every hero their dash back on a knock, which overrides this |
| Spear has a minimum cast time (0.33 to 0.4s) | [wiki](https://supervive.wiki.gg/wiki/Joule) patch notes 20.11.24, 05.03.25 | only 1.2s casts seen | yes: "Storm Rod's 0.33s minimum cast" |
| Spear stuns on terrain or another target | [wiki](https://supervive.wiki.gg/wiki/Joule) (Voltaic Spear) | stun on a pillar | yes: wall and foe stuns |
| Lightning Strike flings enemy orbs, which can then be stolen | [wiki](https://supervive.wiki.gg/wiki/Joule) (Lightning Strike) | orb flung (`0283`) | yes: "flings a rival's orb, now yours" |
| Lightning Strike can launch Wisps | [wiki](https://supervive.wiki.gg/wiki/Joule) | not shown | not built (we have no wisps; Boki are not moved) |
| Static Charged detonation restores mana | [wiki](https://supervive.wiki.gg/wiki/Joule) | not shown | not built (no mana) |
| Eye of the Storm: invulnerable while in the air | [thebackdash hunter list](https://thebackdash.com) (pre-1.0 wording) | INVULNERABLE tag (f45) | yes: "invulnerable in the air" |
| Eye of the Storm: landing spot at the cursor within a range ring, two presses | reference sheet (both casts) | ring f29, crown reticle f36 | yes: "clamped inside the ring", "the second press brings her down" |
| Eye of the Storm: landing damage in an area, knockback, 1 Static stack each | thebackdash (pre-1.0 wording) | light pillar and shock ring f49 | yes: "a knockback and 1 Static each" |
| Free to attack right after landing | reference sheet | LMB at f51 | yes: "free again at once" |

## Assumptions (the video is silent; the owner can correct these)
- The throw comes on release; holding past full (1.2s) throws by itself. Charge scales the rod's damage and knock, not its range (the footage's fixed lane; the wiki's older text scales range).
- The rod applies 1 Static.
- Orbs: 4s life, no Static (item 74); a pickup that refunds Wirerun, as the source data says (items 71/74 replace the older owner rule that only a Live foe resets it).
- Static lasts 4.5s, refreshed by every hit.
- Wirerun: a stun, root or Grounded mid-hold cancels it and the charge stays spent (cooldown started on the press); a Boki merge refunds it.
- An airborne Shift with a charge is a Wirerun too (height held); with no charge left it is the plain air dash.
- Skycall: press places, holding E drags (up to 1 s), the release commits; a tap drags away from Sparkle.
- She can move while firing bolts and holding the rod (the footage only shows her standing).
- Momentum: the drift during the Wirerun hold bleeds off at 6 m/s², and whatever is left is added to the streak.
- Kitefall: the footage shows no auto-land; ours comes down at the cursor after 1.7 s of hanging (about 2 s in
  the air with the climb), the sheet's build note. The 0.3 s crouch is not invulnerable (a fair window to punish
  it); the climb, the hang and the drop are. She hangs over the take-off spot (no drifting). The attack key also
  brings her down, but only a fresh press (a held attack from before the cast does not). A press during the
  climb waits for the hang. The landing backs off a wall or a gap toward the take-off until it is standable
  ground. No cancel and no ally effect (the sources mention neither). The knock is a push away from the centre
  with a little lift (the sources say knockback, not knock-up). A Boki merge mid-cast drops her where she took
  off with no strike.

## Ultimate choice
R is her own ultimate, Kitefall (owner decision, SERVER_UPDATE6): the source's Eye of the Storm, built from the
reference sheet's "Ultimate (on R)" section. It was never folded into another slot during the kit pass, so no
slot changes. Fuse is on X.

## Engine notes
- Kit `scripts/arch/kits/mage_kit.gd`; pooled looks `scripts/arch/kits/vv_fx.gd` + `shaders/vv_fx.gdshader`;
  moves `scripts/match/kmoves_vv.gd`; the finger-gun hold `"finger"` in `HunterAnim.HOLDS`; the wrist
  coil `scripts/match/hero_arms_vv.gd`; sounds `tools/gen_sfx_ryzz.py` listed in `VVSfx.NAMES` and content/sfx/mage.json.
- Telegraphs and cursor states through AimKit (docs/AIMKIT.md). No Net change.
- Kitefall: `scripts/arch/kits/mage_ult.gd` (MageUlt), on the shared ult base `scripts/arch/hero_ult.gd` (HeroUlt: the
  cooldown in `cd["x"]`, the recast, one bond id per cast, KinBond.from_ult on a land). R reaches
  it through main's HunterKeys.ult_pressed (the level gate) and `MageKit.cast_ult()`; numbers in `mage.json` `x`.
- Merge cleanup: `_drop_holds()` ends `wire` (refunded), `rmb_down`/`rmb_t` and the rod prop, any
  Skycall in `strikes` still in its `"flick"` phase, and Kitefall's `ult.leap` (she drops at the take-off).
- Screenshots: `--vv-shots --shots-dir=<dir> --vv-hero=mage` (tools/vv_shots.gd).
