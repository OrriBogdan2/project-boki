# Sparkle the Storm Chaser (archetype id `mage`, Light)

Internal design note. This file may name the source hero for traceability; nothing in the game does.
Source behaviour reference: the hero named in the Inspired-by table in docs/ARCHETYPES.md (reference
sheet: briefs/hero-ref/vireo.md, from gameplay footage; owner playtest notes override the footage).
Our hero is an original character, the storm-kite runner: flight goggles, a cropped jacket, copper
coils at both wrists and a copper rod mast flying a pennant. Palette: hot pink lightning (#ff5ab4 body, #ffd6ee core, docs/VFX_QUALITY.md), copper rod (the lightning, bolts, orbs and Static marks are all her pink since 11-08: not teal, not yellow; only the Kitefall ult keeps gold). Payoff word: BLOWOUT.

## Kit card (L picker)
- Role: Ranged lightning skirmisher: charge one foe to 4 Static, then Wirerun through them.
- LMB, RMB, E, Shift, passive and the ultimate: one plain line each in `content/archetypes/mage.json` `card`
  (the ultimate's line is `card.x`; the kit card's last tile shows it on the hunter-ultimate key).

## Scaling
Source health is roughly 8 to 10 times ours (Light = 124 HP). Ratios kept against the basic attack:
bolt 12 every 0.648s (item 116; about 18.5 dps, unchanged from before); Storm Rod 18 to 30 (1.5 to 2.5 bolts; the
source is about 4, held lower because the rod also stuns and leaves an orb); Skycall 20 (source 2.5
bolts, ours 1.7); Wirerun pass 20 (1.7 bolts; was 10 before the audit), doubled through a full-Static foe, plus a Blowout of 16 + 18% of
their health (about 5.7 bolts on a Light; the source detonation is about 9). Cooldowns follow the
source ratio spear : Surge : javelin = 7 : 6.7 : 9.2, at our pace 8 : 8 : 10.5. Kitefall (the source's
landing is 40 + 22%, seen at about 115, so about 1 bolt at our scale; it is held at 22, 1.8 bolts, because
its worth is the escape and the Static) knocks back about 1 bh and adds 1 Static. Its cooldown follows the
source's 37.5 s at our pace, 42 s. Ranges use 1 body
height = 1.8 m: bolt and rod lane 13 m (about 7.5 bh), Wirerun 5.6 to 9.75 m (owner item 70, then a quarter off on 11-10; not scaled by the dash feel; it ends at run speed, in the air too, and carries at most a run's drift), Skycall circle 1.5 m radius.

## Upgrade parity (rank 2 = source tier II, rank 3 = tiers II+III+IV)
Source: Joule, `Upg:` lines. Cooldown cuts keep the source's fraction of its own cooldown (ours stay as the owner set them);
damage steps add up. Numbers live in `rank_cd` / `rank_dmg` (the shared 10% / 15% step is not used). The ultimate takes no
upgrade in our kit (the source's R: +50% impact damage -7.5s, then -7.5s; our X has a fixed cooldown), so it is not changed.

| Slot | Source upgrade | Ours before (rank 2 / 3) | Ours after (rank 2 / 3) |
|---|---|---|---|
| RMB Storm Rod | +20% damage, -1s x2; tier IV +50% damage | 7.2s / 6.4s, damage +15% / +30%, then x1.5 on top (x1.95) | 7.2s / 6.4s, damage +20% / +90% (+40%, +50% on top) |
| Shift Wirerun | -0.75s x2; tier IV +100% non-passive dash damage | 7.2s / 6.4s, damage +15% / +30% on the Blowout and run | 7.3s / 6.7s; no shared damage step; the run's own hit x2 at 3 (Blowout unchanged) |
| E Skycall | +25% x2; tier IV -3s | 9.5s / 5.4s (3s off the shared 8.4s), damage +15% / +30% | 10.5s / 7.9s (a quarter off, the source's 3 of 12), damage +25% / +50% |

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
| Shift Surge | hold crouch, a streak at a constant ~32 m/s (ours: 34 m/s building from 35% over 0.15 s, owner item 70 then 11-08: 40 wound up too fast), an arrival burst [footage] | Wirerun: the same; **the arrival ring and spark spray and the press flash are gone** (owner: no rings or bursts on dashes; the hits are along the way), a dust puff instead | owner rule over footage |
| X Eye of the Storm | launch, hang, reactivate to crash at the cursor; a large ring with a glowing centre and a marker at the cursor [footage] | Kitefall: the same; the range shows as the edge ring with a glowing centre (no dark fill, no dome) and the cursor marker is the strike's 2.7 m hit area (`--mage-combo-check`) | matches |

## Footage gaps, Nov 9 re-check
The ranked gap list of briefs/hero-ref/vireo.md (section 5, rows 1 to 17) against main d255acbee. Status: closed (code or
check on main), open, in flight (unmerged branch), owner override (briefs/DECISIONS.md, owner items). Nothing was built in
this pass: `mage_kit.gd`, `mage_sky.gd`, `mage_ult.gd`, `content/archetypes/mage.json` and `tools/hero_combo_check.gd` are changed
by in-flight Sparkle branches (ext/sparkle-dash-feel, ext/vfx-mage, ext/anim-time-sparkle, ext/trial-ryzz-116, ext/sparkle-e-verify),
so any edit here would conflict. Suggestions for after they merge are in the last column.

| # | Gap | Status | Where / suggestion |
|---|---|---|---|
| 1 | Orbs drop on every spear hit, at once | closed | `_coil_hit()` drops one at the impact after `mote_t` 0.05 on any foe, dummies too; check "an orb at the impact the moment it hits". Orbs are pickups that give Wirerun back (owner items 71, 74) |
| 2 | Surge cooldown starts on press | closed | `on_dash()` spends the charge on the press (22ceca1e1), `_end_wire(false)` keeps it spent on a cut; check "Wirerun: the cooldown starts on the press" (dashes 1.00 to 0.00) |
| 3 | LMB line and bolt to max range, arrow tick | closed | `coilcaster.json` `"aim": "max"`, 13 m past the cursor; check "LMB: aim line to full range past a near cursor" |
| 4 | LMB cadence, ammo, pierce | owner override (cadence), closed (rest) | 0.648 s not 0.8 s (owner items 70, 116); mag 99; no pierce (audit 0ea0810, asserted) |
| 5 | RMB is a held, summoned spear | closed | `mage_rmb_hold` and `mage_rmb`, rod in hand, body flash at full (`rmb_hold_tick`); checks "the rod is in the hand", "full at 1s: the body flash" |
| 6 | RMB fixed max-range lane | closed | `_coil()` reads one fixed `range` 13 m (charge only scales damage and push), lane `width` 0.3 with rails (22ceca1e1); check "a fixed 13m double-rail lane (no growth)" 13.0 / 13.0 |
| 7 | Surge end marker | closed | `_tick_wire()`: end circle `end_r` 2.25 m (4.5 m across, about 2.5 bh) with ticks and star, rails lane 0.35 wide; check "rails lane and the ticked end ring show". Lane length 7 to 11 m (owner 11-08, ext/sparkle-dash-feel) |
| 8 | Surge look | closed, owner override (arrival ring) | sky bolt on the press and the lightning body (model hidden, pink-teal after-images, invulnerable) are in `on_dash()` and `_run()`. `_run()` now prints the INVULNERABLE word at the release, as the source does (vireo.md: label over the silhouette), through `m.fx.word` like Kitefall; check "Wirerun: the INVULNERABLE word shows on the run". The arrival ring and burst are an owner override (DECISIONS: no bursts, rings or discs on dashes; 6d0546330) |
| 9 | E: place, then pick the direction | closed | hold, drag, release (audit); checks "Skycall held 0.6s ... still dragging", "the release commits the drag" |
| 10 | E delay, stacks, Grounded | closed, one owner call | delay 0.8, Grounded 1.5 s in `mage.json` `e`; 1 Static follows the game data, the footage info panel says 2 (audit; ext/sparkle-e-verify notes it). Owner call: keep 1 |
| 11 | Cooldown ratios | closed | spear 8 : Surge 8 : E 10.5 (data, scaling section); ext/sparkle-e-verify asserts E : rod = 9.2 : 7 |
| 12 | E telegraph: dark disc, rim, descending pillar | closed on main, in flight (look) | `MageSky._commit()`: violet disc with copper rim plus a pillar that narrows over the 0.8 s (`fx.pillar`, `mage_sky.gd:85`), ticked rim with chevron, committed arrow. ext/vfx-mage re-builds the look as HeroVfx data. No check asserts the pillar: add one after that merge |
| 13 | Static display, sky bolt at 4 | closed | `add_spark()` drops a bolt from 9 m onto them with a LIVE word on the 4th stack |
| 14 | LMB alternating hands | closed | `mage_lmb_l` / `mage_lmb_r` (parity f99f03c7); check "alternating hands, each a quick fling" |
| 15 | Spear knockback size | closed | `rmb.coil.push` is [4.4, 6.6] (was [6, 9]); a standard-mass foe is knocked 1.77 m on open ground through the shared `Ent.impulse` path (no special case), the source is about 1 bh = 1.8 m (vireo.md item 15). Check "Storm Rod: a standard-mass foe is knocked about 1.8 m" asserts 1.5 to 2.1 m |
| 16 | Sfx | nothing to copy | no audio in the footage |
| 17 | R (ult relocate) | owner override | X is Kitefall, R is the Boki Merge (SERVER_UPDATE6; "Ultimate choice" below) |

Open after this check: row 8 (INVULNERABLE word) and row 15 (knockback size), both small, both blocked on the in-flight branches
above; rows 10 (Static count) and 4 (cadence) are owner calls already recorded.
| Shift Surge | hold crouch, a streak at a constant ~32 m/s (ours: 40 m/s, owner item 70), an arrival burst [footage] | Wirerun: the same; **the arrival ring and spark spray and the press flash are gone** (owner: no rings or bursts on dashes; the hits are along the way), a dust puff instead | owner rule over footage |
| R Eye of the Storm | launch, hang, reactivate to crash at the cursor [footage] | Kitefall: the same | matches |
| X Eye of the Storm | launch, hang, reactivate to crash at the cursor [footage] | Kitefall: the same | matches |
| Allies | Surge damages enemies passed through; Static and the Thunderstorm strike hit enemies; no ally effect [data] | no slot hurts, stuns, roots or slows a teammate; Kitefall's strike and knock count foes only | matches; asserted (`mage ally: ...`) |

## Audit (Nov 3 23:40)
Rows of briefs/specs/kit-audit/vex_vireo_sable.md. (a) done on this branch, (b) fixed now, (c) not applied, with the
reason. Asserts: `--mage-combo-check` (`Skycall ...`, `small: ...`, `Kitefall (data) ...`).

| Row (sev) | Verdict | Where / why |
|---|---|---|
| E input: hold, drag, release (HIGH) | (b) | held E keeps the drag open (up to 1 s), the release commits; a tap drags away (asserted: still dragging at 0.6 s, the release starts the countdown) |
| E numbers re-measured (KIT_PARITY) | (a) | countdown 0.8 s = 4 frames at 5 fps (briefs/hero-ref/vireo.md, E: Lightning Javelin, 0186 to 0190); 1 Static and 12 s from briefs/supervive-data/supervive_kits.md (Joule E). The source states no drag window ("hold and drag before release"; the footage shows the commit one frame after placing), so the 1 s cap is ours; asserted: held with no release it commits at 1 s. Enemies see the all-player rim circle from the placement and the pillar for the 0.8 s. Open: the footage info panel says the javelin adds 2 Static (kept at the data's 1), and the cooldown is 10.5 at our 8 : 8 : 10.5 pace (data 12 / 10 / 9) |
| Wirerun arrival ring (HIGH) | (a) | 6d054633 (and the press flash) |
| Blowout ground ring (MED) | (b) | removed (the shared payoff ring too: `payoff_fx(..., rings := false)`); the copper pillars stay |
| Other cosmetic rings; strike rings bigger than the hit (MED) | (b) | rod summon, Live and take-off rings removed; Skycall's ring at its 1.5 m radius (was 2.3), Kitefall's at its 2.7 m (the 1.45x ring removed), the landing marker at the radius |
| Kit VFX pass: bursts that are not gameplay (MED) | (b) | out: the per-shot ground sparks, the Static pop's second bolt and flash, the Wirerun pass burst (a crackle instead), the rod's end and hit bursts, the SLAMMED ring, Skycall's strike spray, Kitefall's take-off spray (dust). Kept: the source's rod shock ring, the strike rings at the hit size, the copper refund pillars |
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
| Passive: reset cue on Live, knock heal (LOW) | (b) | the misleading reset cue and the knock heal are gone (the stale card line "Knocking a hunter down heals you for 15%" too, asserted in `--hero-combo-check`) |
| RMB / E / X self-shake (LOW/MED) | (c) | ext/no-shake owns item 50 |
| X Static spread (MED) | (b) | the highest Static among the foes the strike hits goes to every foe it hits, then the ult's own stack (owner item 72); asserted |

## Per-slot table
| Slot | Input | Aim | What it does | Telegraph / reticle | Move (KMovesVV) | Sound |
|---|---|---|---|---|---|---|
| LMB Coilcaster (finger gun) | hold, 0.8s per bolt | max range (13 m) past the cursor, `"aim": "max"` | a crackle from the fingertip, left hand then right, the bolt a hot head with a crackling pink trail; stops on the first foe (data); 1 Static per hit | a thin line through the cursor to full range with an arrow tick (always up) | `mage_lmb_l` / `mage_lmb_r`: twist, arm flung out, snap, settle | `vv_bolt` |
| RMB Storm Rod | hold, release (full at 1.0s, throws itself at 1.2s, 0.33s minimum) | max range, a fixed 13 m lane | summons a copper rod; the throw knocks the first foe back about 1 bh (stun on a wall or another foe), 1 Static, leaves a charge orb at the impact at once | double-rail lane with chevrons for the whole hold; cursor charge ring; a white body flash and flare at full | `mage_rmb_hold` (rod by the shoulder), `mage_rmb` (overarm) | `vv_rod_summon`, `vv_rod_full`, `vv_rod_throw` |
| Shift Wirerun | hold, release (full at 0.9s, auto at 1.2s) | direction from the cursor, length from the charge only | the charge is spent on the press; while held you can't steer, you keep your height and your momentum drifts you; release: a lightning streak (shots pass through) that builds over 0.15 s and carries the drift, then ends at run speed (DashExit: capped at 1.5x run, eased down over 0.25 s, no glide handoff); every foe crossed takes 10, a 4-Static foe takes double and Blowout, Wirerun back at once (the only early reset) | rails to max range, a big ticked end ring with a star sliding out (everyone sees the ring); cursor charge ring | `mage_dash` (crouch), `mage_dash_go` (stretched streak), `mage_dash_land` (re-form, overshoot); no tumble: spent, Shift is denied | `vv_surge_charge`, `vv_surge_go` |
| E Skycall | press, hold and drag, release (data) | at the cursor (11 m) | drops a circle; while E is held (up to 1 s) the drag follows the cursor from the circle (toward you pulls in, away throws out; a tap = away); the release commits it, then 0.8s countdown; lightning: 20, 1 Static (data), everyone inside slid about 3.4 m along the ground that way (peak 6.2 m/s, easing to a stop over 1.1 s) and Grounded 1.5s; flings orbs (steals a rival's) | ticked circle with a rim chevron + a drag arrow during the flick; then sparks gathering in the circle under a thin bolt from the sky (everyone sees it) | `mage_e` (one-arm sweep, snap down) | `vv_sky_place`, `vv_sky_count`, `vv_sky_strike` |
| Passive Static | | | hits add Static (4 max, 4.5s); a marker over the head shows pips and the count, with sparks on the body that grow per stack; the 4th calls a sky bolt (Live) | marker, sky bolt, arcs to the ground while Live | `mage_live` (finger flicked to the sky) | `vv_static_full`, `hero_blowout` |
| X Kitefall (ultimate, level 6) | press, then press again (X or LMB) | the cursor, clamped inside a 14.4 m (8 bh) ring round the take-off | a 0.3 s crouch, then straight up 5 m and hangs invulnerable (shots pass through, no damage) up to 1.7 s, the camera pulled back; the second press (from 0.25 s into the hang) or the hover running out strikes down at the cursor in 0.2 s: 22, a knockback (about 1 bh), 1 Static to everyone within 2.7 m; she is free to attack at once; 42 s cooldown | a pale range ring with ticks round the take-off (everyone sees it; no fill under it), a pink bolt up her climb and sparks round her while she hangs; a small crown (ticked ring and star) at the landing spot (hers); a filled landing circle for 0.2 s before the strike (everyone); then a white-hot core bolt inside a wide pink one from the sky, a flare, a shock wall and a scorch the size of the hit, debris, and pink sparks settling for 1.5 s (content/vfx/mage.json) | `mage_x` (crouch, squash), `mage_x_air` (stretched up, then arms flung wide), `mage_x_dive` (head first, fists down), `mage_x_land` (one knee and a fist, up into the stance) | `vv_ult_rise`, `vv_ult_hum`, `vv_ult_slam` |
| Shift Wirerun | hold, release (full at 0.6s, auto at 0.9s) | direction from the cursor, length from the charge only | the charge is spent on the press; while held you can't steer, you keep your height and your momentum drifts you; release: a lightning streak (shots pass through) that carries the drift; every foe crossed takes 20, a 4-Static foe takes double and Blowout, Wirerun back at once; a run that came back (Blowout or orb, used within 5s) goes 1.5x further and charges in 0.45s (the only early reset) | rails to max range, a big ticked end ring with a star sliding out (everyone sees the ring); cursor charge ring | `mage_dash` (crouch), `mage_dash_go` (stretched streak), `mage_dash_land` (re-form, overshoot); air press with no charge: `mage_dash_ex` tumble | `vv_surge_charge`, `vv_surge_go` |
| E Skycall | press, hold and drag, release (data) | at the cursor (11 m) | drops a circle; while E is held (up to 1 s) the drag follows the cursor from the circle (toward you pulls in, away throws out; a tap = away); the release commits it, then 0.8s countdown; lightning: 20, 1 Static (data), everyone inside slid about 3.4 m along the ground that way (peak 6.2 m/s, easing to a stop over 1.1 s) and Grounded 1.5s; flings orbs (steals a rival's) | ticked circle with a rim chevron + a drag arrow during the flick; then a dark violet disc with a crackling copper rim and a narrowing pillar (everyone sees it) | `mage_e` (one-arm sweep, snap down) | `vv_sky_place`, `vv_sky_count`, `vv_sky_strike` |
| Passive Static | | | hits add Static (4 max, 4.5s); a marker over the head shows pips and the count, with sparks on the body that grow per stack; the 4th calls a sky bolt (Live); the data passive text says a knock heals 15%, but `on_knock` only blows gum: that heal is removed (audit) | marker, sky bolt, arcs to the ground while Live | `mage_live` (finger flicked to the sky) | `vv_static_full`, `hero_blowout` |
| X Kitefall (ultimate, level 6) | press, then press again (X or LMB) | the cursor, clamped inside a 14.4 m (8 bh) ring round the take-off | a 0.3 s crouch, then straight up 5 m and hangs invulnerable (shots pass through, no damage) up to 1.7 s, the camera pulled back; the second press (from 0.25 s into the hang) or the hover running out strikes down at the cursor in 0.2 s: 22, a knockback (about 1 bh), 1 Static to everyone within 2.7 m (if any has Static, all take the highest count among them first); landing on an enemy hunter fills the Boki bond; she is free to attack at once; 42 s cooldown | a gold range ring with ticks round the take-off (everyone sees it) over a dark violet disc with a gold rim, gold crackle on the rim; a small gold crown (ticked ring and star) at the landing spot (hers); a filled gold landing circle for 0.2 s before the strike (everyone); then a sky-to-ground gold pillar, two shock rings, a spark spray, and copper-gold crackle at her feet for 0.5 s | `mage_x` (crouch, squash), `mage_x_air` (stretched up, then arms flung wide), `mage_x_dive` (head first, fists down), `mage_x_land` (one knee and a fist, up into the stance) | `vv_ult_rise`, `vv_ult_hum`, `vv_ult_slam` |
| Shift Wirerun | hold, release (full at 0.6s, auto at 0.9s) | direction from the cursor, length from the charge only | the charge is spent on the press; while held you can't steer, you keep your height and your momentum drifts you; release: a lightning streak (shots pass through) that carries the drift; every foe crossed takes 10, a 4-Static foe takes double and Blowout, Wirerun back at once (the only early reset) | rails to max range, a big ticked end ring with a star sliding out (everyone sees the ring); cursor charge ring | `mage_dash` (crouch), `mage_dash_go` (stretched streak), `mage_dash_land` (re-form, overshoot); air press with no charge: `mage_dash_ex` tumble | `vv_surge_charge`, `vv_surge_go` |
| E Skycall | press, hold and drag, release (data) | at the cursor (11 m) | drops a circle; while E is held (up to 1 s) the drag follows the cursor from the circle (toward you pulls in, away throws out; a tap = away); the release commits it, then 0.8s countdown; lightning: 20, 1 Static (data), everyone inside slid about 3.4 m along the ground that way (peak 6.2 m/s, easing to a stop over 1.1 s) and Grounded 1.5s; flings orbs (steals a rival's) | ticked circle with a rim chevron + a drag arrow during the flick; then a dark violet disc with a crackling copper rim and a narrowing pillar (everyone sees it) | `mage_e` (one-arm sweep, snap down) | `vv_sky_place`, `vv_sky_count`, `vv_sky_strike` |
| Passive Static | | | hits add Static (4 max as the data; 4.5s refresh is ours [?], the data gives no duration; no knock heal, as the data; the Blowout's +16 and 18% are ours [?]); a marker over the head shows pips and the count, with sparks on the body that grow per stack; the 4th calls a sky bolt (Live) | marker, sky bolt, arcs to the ground while Live | `mage_live` (finger flicked to the sky) | `vv_static_full`, `hero_blowout` |
| X Kitefall (ultimate, level 6) | press, then press again (X or LMB) | the cursor, clamped inside a 14.4 m (8 bh) ring round the take-off | a 0.3 s crouch, then straight up 5 m and hangs invulnerable (shots pass through, no damage) up to 1.7 s, the camera pulled back; the second press (from 0.25 s into the hang) or the hover running out strikes down at the cursor in 0.2 s: 22, a knockback (about 1 bh), 1 Static to everyone within 2.7 m; she is free to attack at once; 42 s cooldown | a gold range ring with ticks round the take-off (everyone sees it) over a dark violet disc with a gold rim, gold crackle on the rim; a small gold crown (ticked ring and star) at the landing spot (hers); a filled gold landing circle for 0.2 s before the strike (everyone); then a sky-to-ground gold pillar, two shock rings, a spark spray, and copper-gold crackle at her feet for 0.5 s | `mage_x` (crouch, squash), `mage_x_air` (stretched up, then arms flung wide), `mage_x_dive` (head first, fists down), `mage_x_land` (one knee and a fist, up into the stance) | `vv_ult_rise`, `vv_ult_hum`, `vv_ult_slam` |
| R / T | | | the Boki Merge (the Boki system's key, see below) | | | |
| R Kitefall (ultimate, level 6) | press, then press again (R or LMB) | the cursor, clamped inside a 14.4 m (8 bh) ring round the take-off | a 0.3 s crouch, then straight up 5 m and hangs invulnerable (shots pass through, no damage) up to 1.7 s, the camera pulled back; the second press (from 0.25 s into the hang) or the hover running out strikes down at the cursor in 0.2 s: 22, a knockback (about 1 bh), 1 Static to everyone within 2.7 m; she is free to attack at once; 42 s cooldown | a gold range ring with ticks round the take-off (everyone sees it) over a dark violet disc with a gold rim, gold crackle on the rim; a small gold crown (ticked ring and star) at the landing spot (hers); a filled gold landing circle for 0.2 s before the strike (everyone); then a sky-to-ground gold pillar, two shock rings, a spark spray, and copper-gold crackle at her feet for 0.5 s | `mage_x` (crouch, squash), `mage_x_air` (stretched up, then arms flung wide), `mage_x_dive` (head first, fists down), `mage_x_land` (one knee and a fist, up into the stance) | `vv_ult_rise`, `vv_ult_hum`, `vv_ult_slam` |
| X | | | Fuse with your Boki (the Boki system's key, see below) | | | |

Charge orb: hovers 4s and adds Static to nobody (owner item 74). Walking over it, a Wirerun through it, or Skycall dragging it toward her within 9 m (it flies to her), picks it up and gives Wirerun back (owner items 71/74); any other Skycall fling is 6 m.

## In the air (parity pass `ext/air-cast-b`: what each slot does mid-jump, mid-fall and out of a glide)

Measured by casting every slot at 2 m (rising from a jump), at 9 m (falling) and in an open glide, on a flat floor; the glider column is what the glider did over the next 0.6 s with the glide key held. The glider never *opens* during an ability animation (owner 162b; `--air-limits-check`) and an open one is never folded by that rule. Where the source is silent the slot works as on the ground (DECISIONS: the source decides these interactions; owner item 51). LMB while the glider is open fires nothing for every Hunter (`Hunter.can_fire`); the source does not document attacking while gliding (docs/WEAPON_FIRING_DATA.md, [gap]), so that is left as it is.

| Slot | Mid-jump / mid-fall | Out of a glide | Source |
|---|---|---|---|
| LMB | bolts fire as on the ground | no shot, glider stays open | gap (no air or glide rule) |
| RMB Storm Rod | the same hold and throw | the same, glider stays open | [D] Joule: no air rule |
| Shift Wirerun | the same Surge; with a charge it holds her height, with none it is the plain air dash (`mage_dash_ex`) | the glider folds for the dash; a held glide key reopens it as it ends | [D] Joule: no air rule; footage: air Surge not shown |
| E Skycall | the same cast | the same cast, glider stays open | [D] Joule: no air rule |
| X Kitefall | the same launch, from where she is; invulnerable in the air | the same, glider stays open | [D] "PRESS to launch into the air"; thebackdash list: invulnerable |

## Cancels (ability to ability)

What a second press does during the first action's wind-up, active part and recovery: **cancels** it (the first
ends), **both** (the second goes now and the first runs on), **waits** (buffered, and for how long) or **ignored**.
Dash rows (Shift either way) are in [dash_interactions.md](dash_interactions.md), not repeated here. Sources: [D]
briefs/supervive-data/supervive_kits.md, [F] the footage sheet (5 fps: one frame is 0.2 s, so a buffer shorter than
that can't be seen, and each ability's frames are a separate stretch of the clip, so no pair is shown back to back),
[W] the wiki page linked above (ability text and patch history), owner = DECISIONS / OWNER_REVIEW_1103. Ours is
origin/main d255acbee, read in the code (cancel-matrix-b pass, 11-09). **Unsettled** means no frame, card line or wiki
line shows the pair: ours stays as it is and nothing was guessed. Any pair not in the table: both (ArchKit has no
shared cast lock), except that every press is ignored, not buffered, while stunned or downed, and the attack key does
nothing from a glide (`Hunter.can_fire`).

| First (phase) | Second | Source | Ours | Verdict | Evidence |
|---|---|---|---|---|---|
| LMB bolt (0.648 s cadence) | LMB | one bolt per 0.8 s held | next bolt on the cadence while held | owner (items 70, 116: faster than the 0.8 s card) | `LMB: ...` lines |
| LMB held | RMB, E | not shown ("she stood still in every LMB shot") | both: the bolts keep leaving while the rod is held | unsettled | [F] 0003-0020, open question 5 |
| RMB tap (under 0.33 s) | RMB | "Cast time increased from 0.25 >>> 0.33 seconds"; earlier "minimum cast time 0.2 >>> 0.4" | the throw **waits** to 0.33 s; a second press is denied (one charge), no queue | match | [W] patches 05.03.25, 20.11.24; `small: ...` |
| RMB held (rod) | LMB, E | not shown | both | unsettled | |
| RMB held | X | not shown | the cast is refused while the rod is held; the hold goes on | unsettled | `MageUlt.cast` |
| Storm Rod throw | any | spear flight is nearly instant | free at once | unsettled | [F] 0063 |
| Wirerun charge (to 0.9 s, press to release) | LMB, RMB, E | not shown | both: the bolts, the rod and Skycall go while she charges | unsettled | [F] open question 5 |
| Wirerun charge | X | not shown | **ignored** (refused, not buffered) | unsettled | `MageUlt.cast` |
| Wirerun charge | jump | not shown | **ignored**: the walk and the jump are zeroed while she holds it | unsettled | [F] open question 5 |
| Wirerun charge | stun, root, ground | "Stuns, Roots, Grounds, and Glider cancel the state" | the charge is cut and stays spent | match | [W] patch 05.03.25; `a stun mid-hold cancels Wirerun` |
| Wirerun charge or run | glide | "Glider cancel the state" (ignore projectiles) | the glider stays shut until the dash ends | **mismatch, not fixed**: the wiki says the glider ends the state, so a glide opens inside it; what the dash does then is not stated | [W] patch 05.03.25 |
| Wirerun through a full-Static foe | Wirerun | "Surge is ready again at once"; "dashes straight back" | back at once | match | [F] 0133-0171; the dash rows |
| E Skycall flick (held up to 1 s) | E release | "the video can't tell which" (release or second click) | the release commits; a tap commits away | match (the input is the data's "HOLD AND DRAG") | [D]; [F] 0184-0186 |
| E flick or countdown (0.8 s) | any | not shown | free: LMB, RMB, X all go | unsettled | [F] 0181-0226 |
| X Kitefall crouch (0.3 s) and climb | X | "REACTIVATE to crash down" | the second press is **queued** and lands her when the hang starts | match | [D]; [F] 0349-0395 |
| X hang (from 0.25 s, up to 1.7 s) | X | reactivate crashes down | lands at the cursor in 0.2 s | match | [D]; [F] "stayed up 1.2 to 1.8 s" |
| X hang | LMB | not shown | **an attack press also lands her** (from 0.25 s in; a button already down at the cast does not) | ours (the source names only the reactivate) | `MageUlt._wants_down` |
| X crouch to strike | RMB, E | not shown | **ignored** (`busy`), not buffered | unsettled | `MageKit.busy` |
| X crouch to strike | jump, Shift | not shown | the crouch combines (owner item 51); in the hang a jump or Shift does nothing | owner | #51; content/dash_flow `into_jump.x` |
| X hang | glide | "Glider cancel the state" | shut (`h.gliding` cleared) | **mismatch, not fixed**: same wiki line as the Wirerun row, what ends is not stated | [W] patch 05.03.25 |
| X strike (0.5 s crackle) | any | not shown | free at once | unsettled | |

Fixes made: none. Two rows are mismatches the wiki shows but doesn't finish (a glider ending Wirerun or Kitefall's
invulnerable state): the wiki gives the state change, not what the dash or the hang does next, so no guess was built.
Suggestions (not built): the LMB landing in Kitefall's hang is ours (the source names only the reactivate); if the
owner wants strict parity, X would be the only landing key.

## Combinations
| Combination | What fires | Check |
|---|---|---|
| 3 bolts + Storm Rod / Skycall | the 4th Static: sky bolt, Live | `--mage-combo-check` |
| Wirerun through a Live foe | double hit + Blowout, Static spent, Wirerun back | `--mage-combo-check` |
| Wirerun through a foe under 4 Static | plain hit, no reset | `--mage-combo-check` |
| Shift spent (ground, air, buffered mid-run) | denied: no class dodge, no tumble | `--sparkle-dash-check` |
| Wirerun then jump + glide held | 0.3 s after it ends she is at run speed (glider cruise at most), peak at most 1.5x run | `--sparkle-dash-check` |
| Storm Rod held | 82% pace after 0.3 s | `--sparkle-dash-check` |
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
| Lightning Strike can launch Wisps | [wiki](https://supervive.wiki.gg/wiki/Joule) | not shown | built: rival downed hunters in the circle slide with the strike (no Static, no Grounded); `--mage-combo-check`. Spec: docs/specs/DOWNED_ABILITIES.md |
| Static Charged detonation restores mana | [wiki](https://supervive.wiki.gg/wiki/Joule) | not shown | not built (no mana) |
| Eye of the Storm: invulnerable while in the air | [thebackdash hunter list](https://thebackdash.com) (pre-1.0 wording) | INVULNERABLE tag (f45) | yes: "invulnerable in the air" |
| Eye of the Storm: landing spot at the cursor within a range ring, two presses | reference sheet (both casts) | ring f29, crown reticle f36 | yes: "clamped inside the ring", "the second press brings her down" |
| Eye of the Storm: landing damage in an area, knockback, 1 Static stack each | thebackdash (pre-1.0 wording) | light pillar and shock ring f49 | yes: "a knockback and 1 Static each" |
| Free to attack right after landing | reference sheet | LMB at f51 | yes: "free again at once" |

## Moving while casting (RMB and E)

Source = the hero sheet (briefs/hero-ref) and supervive_kits.md; the footage is mostly a hero standing in front of a dummy, so 'not shown' means no body displacement can be read (the frames are not on this worker; sheet text used). Ours = the kit's `move_k()` / `CastHold` through `Hunter._chase_mod` (`ak.pace()`), and `Hunter` facing (`face` follows `aim_dir()` at 20/s unless a kit locks it). Facing follows the cursor in every row unless the row says otherwise. Audit of 2026-11-09 (ext/cast-move-b); no value changed.

| Move and phase | Source | Ours | Verdict |
|---|---|---|---|
| RMB hold (press to throw about 1.2 s) | She did not walk during the hold; side-on, spear at the shoulder, body flash at full charge | Free at full speed (no `move_k`), faces the cursor, throws at release (0.33 s earliest) or auto at 1.2 s | unmeasured: the footage cannot tell if moving is allowed (sheet open question 5) |
| RMB throw and recovery (about 0.4 s) | Overarm throw, recovers in about 0.4 s | Free | unmeasured |
| E place and strike (0.8 s) | One-arm sweep, no long wind-up; body not shown moving | Free at full speed, faces the cursor; the pull direction is chosen with the cursor | unmeasured, no data to change |

## Assumptions (the video is silent; the owner can correct these)
- The throw comes on release; holding past full (1.2s) throws by itself. Charge scales the rod's damage and knock, not its range (the footage's fixed lane; the wiki's older text scales range).
- The rod applies 1 Static.
- Orbs: 4s life, no Static (item 74); a pickup that refunds Wirerun, as the source data says (items 71/74 replace the older owner rule that only a Live foe resets it).
- Static lasts 4.5s, refreshed by every hit.
- Wirerun: a stun, root or Grounded mid-hold cancels it and the charge stays spent (cooldown started on the press); a Boki merge refunds it.
- An airborne Shift with a charge is a Wirerun too (height held). Spent, Shift does nothing but the deny cue, on the ground or in the air: she never has the class dodge or the long air dash (`--sparkle-dash-check`).
- Skycall: press places, holding E drags (up to 1 s), the release commits; a tap drags away from Sparkle.
- She can move while firing bolts and holding the rod (the footage only shows her standing).
- Momentum: the drift during the Wirerun hold bleeds off at 6 m/s², and whatever is left is added to the streak. The streak hands none of its speed on: a jump or glide out of it starts from run speed (`scripts/match/dash_exit.gd`).
- Storm Rod: holding RMB slows her 18%, ramping in over 0.3 s (4.65 to 3.81 m/s); the throw clears it.
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

## Animation timing (Nov 8)

Every move in content/rules/warden_anim/ryzz.json measured in game (`--mage-combo-check`,
tools/mage_anim_time_check.gd, lines `TIME ...` and `Sparkle timing ...`): when the kit plays the move, when the
clip owns the body (blend in), the release or hit frame, and when the body is back with the legs (blend out),
against the footage frames in briefs/hero-ref/vireo.md (one frame = 0.2 s, so anything under 0.2 s is inside its
resolution) and the numbers above. Blend in is 0.1 s and blend out 0.16 s (WardenClips.FADE, FADE_LOCO): both
under one footage frame. Seconds from the press.

| Move | Source (s) | Ours before | Ours after |
|---|---|---|---|
| LMB | a bolt every 0.8 s (owner: 0.648) | bolt and beat on the press (0.02), clip 0.33, arm back 0.53 | unchanged |
| RMB held | spear in hand, white flash, throw: ~1.2 s press to throw; recovery ~0.4 | flash 1.0, release throws at once, beat on the same frame, clip 0.70, arm back +0.85 | unchanged |
| RMB tap (min_t 0.33) | not seen (the footage always held) | the beat played on the release (0.13) and the rod left at 0.35: the arm threw 0.22 s early | the beat plays as the rod leaves (0.35) |
| Wirerun | charge ~0.6 to full length, travel ~0.6 (owner: speed 40), recover ~0.4 | crouch on at 0.10, streak and beat at the full charge 0.62, landing beat after the arrival | unchanged |
| Skycall | disc to strike 0.8 s (4 frames), strike committed ~1 frame after the disc | arm up on the press (0.02); a drag released late (1.0 s, strike at 1.8) dropped the arm at 1.55 (clip 1.4), then the snap popped up from rest | the arm holds its raised pose (`hold_at` 1.15, `hold_until` 1.9) until the snap |
| Kitefall | crouch then leap ~0.4, up 1.2-1.8, streak down | windup 0.3, hover 1.7 (inside 1.2-1.8) | unchanged |
| mage_live, gum, fusion, dash_ex | not in the footage | | unchanged |

Owner overrides left as they are: the 0.648 s LMB cadence, Wirerun's travel speed, the Skycall pull.

Clip re-keys for origin/ext/ryzz-v2-model (not done here: the GLB and tools/art1 are that branch's):

| Clip | Re-key |
|---|---|
| sky | the raised pose (SK) holds 0.3-1.15 and drops to rest by 1.4, but the move lasts up to 1.8 s (1.0 s drag + 0.8 s); a hold key at the end of SK would let `hold_at`/`hold_until` go |
| rmb | the throw's release key is 0.16; a tap now plays it at the launch (0.33) so it reads right as is |

Suggestions (ours, not built): keep the rod in her hand until it leaves on a tap (the tick hides it on the release,
0.2 s early); a Wirerun recovery lock of ~0.4 s like the source's re-form.

## Engine notes
- Kit `scripts/arch/kits/mage_kit.gd`; LMB, Storm Rod, Skycall and Kitefall looks are HeroVfx data
  (`content/vfx/mage.json`); the Wirerun, Static marker, orbs and Grounded shackle are pooled `scripts/arch/kits/vv_fx.gd`;
  moves `scripts/match/kmoves_vv.gd`; the finger-gun hold `"finger"` in `HunterAnim.HOLDS`; the wrist
  coil `scripts/match/hero_arms_vv.gd`; sounds `tools/gen_sfx_ryzz.py` listed in `VVSfx.NAMES` and content/sfx/mage.json.
- Telegraphs and cursor states through AimKit (docs/AIMKIT.md). No Net change.
- Kitefall: `scripts/arch/kits/mage_ult.gd` (MageUlt), on the shared ult base `scripts/arch/hero_ult.gd` (HeroUlt: the
  cooldown in `cd["x"]`, the recast, one bond id per cast, KinBond.from_ult on a land). R reaches
  it through main's HunterKeys.ult_pressed (the level gate) and `MageKit.cast_ult()`; numbers in `mage.json` `x`.
- Merge cleanup: `_drop_holds()` ends `wire` (refunded), `rmb_down`/`rmb_t` and the rod prop, any
  Skycall in `strikes` still in its `"flick"` phase, and Kitefall's `ult.leap` (she drops at the take-off).
- Screenshots: `--vv-shots --shots-dir=<dir> --vv-hero=mage` (tools/vv_shots.gd).

## Ability shot rules (parity: what each ability's shot or lane stops on)

PARITY FIRST (owner decision 2026-11-07): the source decides, owner notes override it. One row per ability projectile or lane (not LMB); the rules every shot shares are in [docs/KIT_PARITY.md](../KIT_PARITY.md) "Ability shot and lane rules". What placed walls (Tenzo's rocks, Neve's ice) block is the placed-walls job's, not repeated here. "Not determinable" rows keep ours (data and footage are silent).

| Ability | Source | Ours |
|---|---|---|
| RMB Storm Rod (Voltaic Spear) | Data: a spear, damage and knockback on the first enemy hit. Footage briefs/hero-ref/vireo.md:27: flies to max range and stops on the first enemy hit. | Stops on the first foe (hunter, Boki or monster), passes allies, ends on walls. Matches. |
| E Skycall (Lightning Strike) | Data: a strike at the target location. | Hits the cursor point, over walls and bodies; no shot. Matches. |
| Shift Wirerun (Surge) | Data: 153 to enemies passed through. | Hits every foe it passes (two in a line), passes allies. Matches (`Wirerun hits every foe it passes`). |

## Interrupts (crowd control on wind-ups, holds, channels and recasts; parity pass Nov 9)
What each kind of crowd control does to a move that is still running. Kinds: stun, knockback (shoves and pulls),
root, Grounded, and knocked (downed, a Wisp). Sources: [D] the tooltip data (briefs/supervive-data), [F] the
5 fps footage sheet. The data states one interrupt rule in the whole roster (the support's channelled ult ends if
she is stunned, knocked or moves too far), and the footage never shows this Hunter crowd-controlled mid-move, so
most rows stay [?]. Settled: a knocked Hunter is a Wisp (the data's hook scoops up Wisps, the healer's burst
resurrects them), so whatever has not yet left the hand ends; whether its cooldown is spent stays [?].
Invulnerable moves ignore crowd control from hits ([D]/[F] say so per row). "Ours" reads the kit code;
stun, root and Grounded arrive through `Ent.hurt` opts or `KitStatus`, knockback through `Hunter.impulse`
(`knock_t`), a knock through `Match.knock` (`downed`); none reaches a kit by itself, each kit checks.

| Slot | CC kind | Source | Ours | Verdict |
|---|---|---|---|---|
| RMB Storm Rod hold | stun | [?] | the base hold releases: the rod is thrown | [?] |
| RMB Storm Rod hold | knocked | ends | **was: the rod was thrown. Fixed: nothing thrown, the charge kept** (`fire_rmb`), asserted "knocked mid Storm Rod hold" in --mage-combo-check | fixed (cooldown [?]: kept, the smaller change) |
| RMB hold | knockback, root | [?] | no check: goes on | [?] |
| Shift Wirerun charge (hold) | stun, root, Grounded | [?] | cut, the charge spent on the press is gone | [?] |
| Shift Wirerun charge | knocked | ends | cut | match (cooldown [?]) |
| Shift Wirerun streak | any | ignore: [F] "Invulnerable lightning dash", INVULNERABLE label `0105` | `invuln` for the streak | match |
| E Skycall drag (hold) | stun, knocked | [?] (placed at the press, [D] "PRESS to strike target location") | the strike commits with the drag so far | [?] |
| X Kitefall crouch (0.3 s) | stun | [?] | no check: she takes off | [?] |
| X Kitefall crouch | knocked | ends | **was: she took off. Fixed: dropped, no take-off** (`MageUlt.tick`), asserted "knocked in the Kitefall crouch" in --mage-combo-check | fixed (cooldown spent, [?]) |
| X Kitefall airborne, recast to land | any hit | ignore: [D] "immune to projectiles", [F] INVULNERABLE tag (f45) | `inv_t` while up; recast lands as [D] "REACTIVATE to crash down" | match |
