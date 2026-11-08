# Lace the Red Stitch (id `archer`, Light) - fidelity pass (hero sheet pin.md)

Behaviour reference: the hero named in the Inspired-by table in docs/ARCHETYPES.md (internal note; nothing of the source's names or look ships). Player-facing names are our own. Display name is the class title Red Stitch; the id, files and save keys stay `archer`.

## Research summary
Sources (gameplay only; notes in our own words, nothing of the source ships):
- The hero sheet `briefs/hero-ref/pin.md`, written from 5 fps gameplay footage of the newer version of the source kit (one footage frame = 0.2 s). Its ranked gap list drove this pass.
- The earlier accuracy pass (the public kit page and guides, patch history) for the parts the footage doesn't show.

What the newer source does: a two-stage bow draw (Empowered at about 0.6-0.8 s, Supercharged at about 1.2-1.4 s) with a reticle that fills along the aim line toward a perfect-timing circle (owner item 55b); Empowered shots land at the cursor, Supercharged ones fly past it to a longer range; releasing right as a stage comes up makes the next charge faster; holding about 0.5 s past full draw overdraws the arrow (about half damage). A charged impaling arrow with a gold V and bar telegraph. Shift is Spirit Walk: a dodge roll, then 2.8 s walking through walls and objects. E is a curved arc wall of rain at the cursor distance, about 120 degrees wide. The ultimate (three empowered piercing beams) is back on X as Starpiercer (R stays the Merge).

Where the footage and our older doc disagree, the footage (the newer version) wins, except where the owner notes override it.

## Parity pass (owner 18:45: animation and ability parity, LMB first)
Source vs ours per slot; [data] = the game data (supervive-data), [footage] = hero-ref/pin.md at 5 fps. Asserted in
`--archer-combo-check` (`parity pin: ...`, tools/parity_pvb.gd) unless noted.

| Slot | Source | Ours | Status |
|---|---|---|---|
| LMB beats | hold: side-on draw pose held; release a 1-frame snap, little recoil; Supercharged flashes the body and kicks harder [footage 0102-0124, 0167-0169] | `arc_draw` (held), `arc_loose` out at 0.05 s and settled by 0.42 s; `arc_super` with the body flash at the stage | matches; asserted |
| LMB tracking | turns to the cursor throughout, walks slowly while drawing [footage f111-116] | the body faces a moved cursor within 0.1 s mid-draw; the arrow leaves along the new aim while walking; drawing walks at 0.7 of the run | matches; asserted |
| LMB cadence | 0.5 s cooldown [data card] | **was 0.35 s**: the next draw now starts 0.5 s after the release (`longbow.json` rate 0.5) | fixed; asserted |
| LMB stages and range | Empowered 0.6-0.8 s, lands at the cursor; Supercharged 1.2-1.4 s, past the cursor; overdraw halves [footage] | 0.6 s / 1.15 s (the low end, kept for ranged TTK), cursor / 16 m, overdraw x0.5 | matches (Supercharged 0.05 s early, deliberate) |
| RMB Heartpiercer | hold to charge, release; 16 s, 1 charge [data]; the newer footage also fires a tap uncharged | hold only, 16 s, 1 charge, gold bar | data wins over footage |
| E Rain of Arrows | an arc at the cursor distance, about 120 degrees, 4.4 s [footage] | the same | matches |
| X Primal Forces | 3 empowered no-draw shots, the 3rd executes [data] | Starpiercer: the same rules | matches |
| Shift Spirit Walk | a dodge roll of about 3 m in 0.27 s (peak 17 m/s at 0.13 s), straight into the crouched walk [footage 655.55-655.65] | **was 2.55 m in 0.18 s** (the owner found Lace's Shift fast): now 3.0 m in 0.28 s (`roll` 3.5, `roll_t` 0.24, with the dash feel); `pin_roll` retimed to match; the start burst and ring are gone (owner: no rings or bursts on dashes), a dust puff instead | fixed |

## Audit (Nov 3 23:40)
Rows of briefs/specs/kit-audit/zedran_bjorn_pin.md (it audited main 200effce). (a) done on this branch, (b) fixed now,
(c) not applied, with the reason. Asserts: `--archer-combo-check` (`audit pin: ...`, `pin early release: ...`, `combo archer: ...`).

| Row (sev) | Verdict | Where / why |
|---|---|---|
| LMB draw through Shift / jump (HIGH) | (a) | fb92ee1c: the draw carries and charges on through the roll, the flick and a jump. `dash.*.lmb` stays buffer (coordinator: the source-buffering finding keeps modes, a10d678a) |
| Spirit Walk roll feel (HIGH) | (a) | 24a34e21: 3 m in 0.27 s (footage), `pin_roll` retimed |
| Spirit Walk cooldown 6 vs 9.5 (MED) | (b) | 9.5 s (data) |
| Shift fx: roll ring and bursts, flick bursts (MED) | (a)+(b) | 24a34e21 (roll); the air flick's four bursts removed now |
| Shift through raised walls (MED) | (c) | the heightmap has no passable ledge faces; recorded as an Assumption (the walk passes rocks, trees, pillars and barriers) |
| Passive: Focus/Deadeye invented; instant full draw; knock heal (MED) | (b) partly, (c) | the knock heal (and its RUN DOWN ring and move) is gone; a full Focus no longer skips the draw stages (it is spent on the arrow loosed, `Hunter.focus_draw` removed). Focus and Deadeye are now cut entirely (owner decision 2026-11-07): no meter, no +20% range, no Deadeye hit, no `pin_deadeye` move, no HUD arc; Hawk Sense stays |
| LMB (-) | (a) | parity 24a34e21: cooldown 0.5 s (card) |
| Heavy Shot wall payoff ~5x, pierce invented (MED) | (b) pierce, (c) the ratio | it stops on the first foe (asserted). PARITY FIRST (owner 2026-11-07): the wall hit is 4.94x the shot (`pin.wall_mult`, the data's 173 extra on 35), so 80 to 148 on top of 16 to 30; a full pin is 178 and takes any 124 HP light in one. Asserted (`parity lace`) |
| RMB hold 0.5 s dead zone, auto-release (LOW) | (c) | PARITY FIRST: `rmb.hold` 0.15 s is only a tap guard; the charge counts from the press and is full at 1.1 s. Asserted (`parity lace`) |
| RMB self-recoil (LOW) | (b) | removed |
| E cooldown 9 vs 15, DPS (MED) | (b) cd, (c) DPS | 15 s (data). DPS kept: 10/s is 8% of a light's HP a second, the source's 61/s is 5.5% of Myth's |
| X cooldown 36 vs 60, beam damage (MED) | (b) cd, (c) damage | 60 s (data). Beams stay 18/25: the burst cap (the ult then the merge never one-shots a full-health light) |
| Self-shake (MED) | (c) | ext/no-shake owns item 50 |

## Per-slot table (slot, input, our behaviour, source behaviour, difference and why)
| Slot | Input | What it does now (our words) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive | always | Hawk Sense (foes under half health show through cover within 22 m) (as for every hero, the takedown reset returns a dash charge; no kit knock heal) | Soul Hunter: injured hunters seen through fog; tall-ledge climb | Focus/Deadeye were cut (owner decision 2026-11-07). The ledge climb is built (`climb_tall` in hunter_move.json: a jump into a double-high face mantles up, as for a normal ledge) |
| LMB | tap | Released before Empowered: 15 damage, lands at the cursor | Weak tap shot (not isolated) | Assumed to land at the cursor too |
| LMB | hold | Empowered at 0.6 s (30, lands at the cursor up to 12 m); Supercharged at 1.15 s (60, flies past the cursor to 16 m). The reticle (owner item 55b) is a thin line to the cursor that a bright fill runs along from near Lace like a progress bar, full at Supercharged, with one small circle on the line at the next perfect point: it flashes gold from the frame the fill reaches it to the end of the perfect window, then moves on to the end of the line. Nothing else: no V, no glints, no cursor ring. At Supercharged: a body flash, a thick white line past the cursor to 16 m and a target ring | Same stages; the owner's filling line overrides the footage's V | Timings at the low end of the footage's ranges (ratio 1 : 1.9) |
| LMB | perfect | Let go within 0.15 s of a stage coming up: no extra damage, the next draw runs 1.6x until Empowered; a brief gold fletch burst (her own motif: feathers radiating from a core, 1.1 m, 0.13 s) with a ring at the bow, on the aim line, a higher-pitched shing, `arc_perfect` | The next Empowered charge is faster; a gold star by the bow hand | The 1.6x is our pick (not measurable at 5 fps) |
| LMB | overdraw | Held 0.5 s past Supercharged: the line dims to a thin pale one, the arm shakes (`arc_over`); the arrow does half | About 50% (263 vs 505) | Matches the ratio |
| RMB | tap | Nothing: a tap before the draw starts looses no arrow and costs nothing (no snare, no Tripwire, no air Plunge) | Heartpiercer is hold only | Data: hold only |
| RMB | hold | Heavy Shot (one charge, 16 s cooldown): a great silver needle nocked on the bow (PinNeedle, seen by everyone), drawn back and glowing red with the charge, its red thread trailing; she moves at 38% speed while she holds it (`pin.hold_move`); a red bar from the bow that grows to 2 body heights with the charge; full at 1.1 s; pierces, knocks back; into a wall within 3 m: a wall hit and a 1.2 s stun (PINNED). The bow's arrow made much bigger and red, 6 times a normal one (a bright core, a 6 m trail); a release burst on the aim line at the bow, a screen kick and a deeper thump; a hit flash, a red-white burst, dust and a white ring on impact, and a wall pin leaves a stake in the wall for 7 s; a pink crescent at the feet on release | Same telegraph, arrow and impact | The 1.2 s wall stun stays from the earlier pass. Data: 16 s, 1 charge |
| Shift | tap | Spirit Walk: a 3 m dodge roll (0.28 s, invulnerable; the footage's 0.27 s) that flows straight into the crouched spirit run, then 2.8 s walking 10% faster through rocks, trees, pillars and ability barriers (not cliffs); rank 3: 0.5 s longer, 33% faster inside something (fading over the walk), allies within 6 m walk too. Damage ends it; ending inside something costs 30 Focus and puts her back where she went in. Her screen tints dark blue while inside; a green shell over her | Spirit Walk: dodge roll, 2.8 s through walls and objects; damage ends it; ending inside a wall costs 30 mana and teleports back | Mana is Focus here. Cooldown 6 s on our charge system instead of the source's mana gate |
| Shift | long dash | In the air or out of charges: a 4.2 m flick with a sideways tumble (`pin_flick`) and a green streak | (base dash) | Our per-hero base dash variant |
| E | tap | Hail Wall: lobbed up (0.35 s, everyone sees the arc), then 4.4 s of rain on an arc round her, 120 degrees, at the cursor distance (2-9 m), 1.8 m deep: 5 per 0.5 s, slow 35%, blight (healing barely takes) with blue burn flames. Seven translucent green panels with fletch posts, a ground glow, arrows streaking down | Rain of Arrows: an arc concentric to the hunter, about 120 degrees, at the cursor distance, about 4.4 s | Cooldown 9 s (source 8.3 s with RMB 9 s: the same ratio to our RMB) |
| X | tap (level 6) | Starpiercer: no cast lock; the next 3 bow shots within 6 s need no draw. Each LMB press nocks 0.5 s, then looses a big arrow (head as wide as its hit, a red thread trail, 90 m/s so 18 m takes 0.2 s like the source's beam) that pierces every foe to 18 m (1.5x Empowered), knocks back 4 and strips 10 armor: 18, 18, then 25 on the last, which finishes a hunter it leaves under 12%. Cooldown 36 s. Telegraph: the arrow's lane and a ticked ring at her feet; three pips and a glowing bow everyone sees; the cast sound carries the whole map | Primal Forces: next 3 shots empowered (no charge, 6 s, piercing, longer range, knockback, armor shred, the final shot executes) | Damage scaled down from the source's ratio (a beam is about a Supercharged arrow there; here 0.3x, final 1.39x the beam as the source's 1.41x) so the ult then a merge never takes a full-health light hunter down. Deadeye stays: it is the Focus payoff on a rooted foe, not a three-shot window, so nothing is unfolded |
| R | - | the Boki Merge | - | R is the Merge for every hero |

## Assumptions (the footage is silent; the owner can correct these)
- Spirit Walk passes rocks, trees, pillars and ability barriers but not terrain ledges: the data lets Phase Walk cross a raised-platform wall, which our heightmap has no way to do (audit, Nov 3).
- A Supercharged shot with no target flies its full 16 m (not a longer clamp past the cursor).
- The quick draw after a perfect release is 1.6x until Empowered, then normal speed; the next release consumes it, perfect or not.
- The perfect window is 0.15 s from each stage coming up (about one footage frame).
- A tap shot (before Empowered) does 15 and lands at the cursor.
- The Impaling Shot's wall stun stays 1.2 s and its full charge 1.1 s (the earlier pass).
- "Cremating" a burning enemy with a knock is flavour, not a mechanic: not built.
- During Spirit Walk she can still shoot and cast, and moves 10% faster (the sheet measures +5-10% outside); at rank 3, 33% more inside something, fading over the walk.
- The spirit orb lasts 4 s and gives anyone who touches it (ally or foe) one 2.8 s Spirit Walk; they get no roll and no snap-back.
- Cremation is +10 damage and a longer burn on a foe knocked by the Heavy Shot while it stands in her burning Hail Wall.
- Not built: Hail Wall damaging wisps (our downed hunters take no ability damage).
- Starpiercer: the beam is stopped by walls and terrain (the source pierces "destructibles"; ours has no destructible walls on the shot line), and a breakable prop ends it.
- Starpiercer: the cooldown starts on the cast; unused shots are lost when the 6 s run out; a merge ends the window.
- Starpiercer: each beam nocks for 0.5 s (the footage shows a 0.4-0.8 s draw; the fine print says no charge) and the next nock waits 1.0 s: 1.5 s a shot like the footage (f48/f63/f78), all three inside the 6 s window.
- Starpiercer's execute is "finish a hunter left under 12% of max health" (the card's "execution damage" isn't defined anywhere we found).
- "Inside something" means a rock, tree or pillar tile, or a movement-blocking ability barrier; terrain cliffs and ledges are never passable.

## Body and movement (hero sheet: Body, scale and movement feel)
- Scale ~0.98 of a medium to the top of the head (`--warden-model-check`), slim build kept; hit radius 0.392 (`body.hit_r`, docs/HITBOX_SIZE.md). The Warden model (concept sheet, `scripts/heroes/warden_archer.gd`) is long-legged with a smaller head: `body.legs` 1.62, `body.head` 0.72, `body.neck` 0.03, so `body.size` is 1.05.
- Quick, short steps: stride rate `spd*2.9` (HunterAnim.STRIDE); the tall run stays.
- Her dash after-image is her own: three green fletch streaks at hip, chest and shoulder height (PinFx.afterimage), not the shared ghost.
- Nameplate height: the shared 2.35 m fits at the new scale (ArchKit.plate_height, read by the HUD branch).

## Small mechanics (fine print; source, footage, ours)
| Mechanic | Source | Footage | Ours | Check |
|---|---|---|---|---|
| Stage 1 lands at the cursor, stage 2 flies past it | sheet pin.md | confirms (0117, 0168-0169) | built | `pin aim:` lines |
| A perfect release makes the next charge faster | sheet pin.md (newer kit) | card text only | built, 1.6x to Empowered | `combo pin: perfect > ...` |
| Perfect shots ease the self-slow of drawing | [wiki: Greenwood Bow](https://supervive.wiki.gg/wiki/Myth) | not visible | built: the draw after a perfect slows you to 0.85, not 0.7 | `pin small: after a perfect...` |
| Overdraw halves the shot | sheet pin.md | confirms (0252-0256) | built | `pin bow: overdrawn` |
| Spirit Walk: dodge roll, then 2.8 s through walls and objects, not terrain | [wiki: Phase Walk](https://supervive.wiki.gg/wiki/Myth), sheet | confirms (0360) | built | `combo pin: Spirit Walk passes...` |
| +150 decaying move speed while inside terrain (rank IV) | in-game data, [wiki: Phase Walk](https://supervive.wiki.gg/wiki/Myth) | not measurable | built at rank 3: +33% (150 on the data's 455 base) inside something, fading to nothing over the walk; x1.1 elsewhere | `pin small: no extra speed inside...`, `pin rank 3: +33% inside something, fading` |
| Walking into a wall leaves a phase orb; allies or enemies touching it also phase | [wiki: Phase Walk](https://supervive.wiki.gg/wiki/Myth) | not shown | built: a 4 s spirit orb at the entry; anyone touching it walks as a spirit for 2.8 s | `pin small: anyone touching the orb...` |
| Taking damage ends it; ending inside a wall costs 30 mana and teleports back | [wiki](https://supervive.wiki.gg/wiki/Myth), sheet | card text | built (the 30 mana has no equivalent: we have no mana, so it costs nothing) | `pin: damage ends...`, `combo pin: ... ending inside a rock` |
| Knocking an enemy restores a dash charge | [wiki: Phase Walk](https://supervive.wiki.gg/wiki/Myth) | not shown | built (now main's takedown reset for every hero) | `combo archer: knock > heal + dash charge` |
| Heartpiercer can be held 3 s after cast before it fires | [wiki patch 20.11.24](https://supervive.wiki.gg/wiki/Myth) | not shown | built: auto-release at 3 s | `pin small: the Heavy Shot can be held 3 s` |
| Short Heartpiercer charges push harder | [wiki patch 20.11.24](https://supervive.wiki.gg/wiki/Myth) | not shown | built: minimum push 6 -> 8 | same |
| Into terrain: 1.2 s stun and extra damage | [wiki: Heartpiercer](https://supervive.wiki.gg/wiki/Myth) | not clean in footage | built (earlier pass) | `combo archer: Heavy Shot > wall` |
| Knocking back a burning enemy Cremates it | [wiki: Rain of Arrows](https://supervive.wiki.gg/wiki/Myth), sheet | flavour text | built: a Heavy Shot knock on a foe in the burning wall: +10 and a longer burn, CREMATED | `pin small: Heavy Shot into a foe burning...` |
| Rain of Arrows: a cone/arc wall, slow and anti-heal | [wiki](https://supervive.wiki.gg/wiki/Myth), sheet | confirms (0457, 0498) | built: 120 degree arc at the cursor distance | `pin E:` lines |
| Climb double-high walls by jumping while facing them | [wiki: Spectral Hunter](https://supervive.wiki.gg/wiki/Myth) | not shown | built: `climb_tall` in content/rules/hunter_move.json (Lace and Brall only, the data's bCanWallJump); the shared mantle takes 0.9 m more reach | `combo archer: tall climb, ...` |
| Ult: empowered arrows need no charge, 6 s, the next 3 shots | [wiki: Virideth's Fury](https://supervive.wiki.gg/wiki/Myth), sheet | confirms (f33-f78) | built | `pin ult cast`, `pin ult small: the beam needs no draw`, `... the 6s window ends` |
| Ult: pierces enemies, longer range, knocks back | [wiki](https://supervive.wiki.gg/wiki/Myth) | confirms the long beam (f48) | built: 18 m, pierce, push 4 | `pin ult payoff: the beam pierces both foes, 16m out`, `... knocks back` |
| Ult: the final shot hits harder and executes; shots shred armor | [wiki](https://supervive.wiki.gg/wiki/Myth), card text | final number not legible | built: 25 vs 18, execute under 12%, -10 armor per beam | `pin ult payoff: the last beam finishes...`, `pin ult small: armor shredded` |
| Ult: she walks and dodges between shots | sheet | confirms (walks f50-f62) | built: no slow, Spirit Walk keeps the shots | `pin ult small: she can move...`, `... Spirit Walk between shots keeps them` |
| Ult: a wall stops the beam | ours | - | built | `pin ult small: a wall stops the beam` |
| Affects wisps (downed hunters) | [wiki](https://supervive.wiki.gg/wiki/Myth) | not shown | not built: our downed hunters aren't hit by ability damage (Assumptions) | - |

## Kit data pass (SERVER_UPDATE7, in-game data wins over the footage)
| Item | Before | After | Conversion |
|---|---|---|---|
| RMB tap | a rooting snare arrow (11 m, 8 damage, root 0.6) and a Tripwire on a miss, with a 2-charge pool shared with the Heavy Shot; Plunge in the air; longer root during the Hail Wall | removed: a tap before the draw starts looses nothing and costs nothing; the draw works in the air too | none |
| Heavy Shot charges and cooldown | 2 charges, 9 s each (shared with the snare) | 1 charge, 16 s | 16 s is the data's cooldown and the work list's "about 1.8x the old 9 s" (the E-relative ratio would be 9.6 s; kept 16 on purpose, one number in `rmb.cooldown`) |
| Heavy Shot ranks | rank 2 cooldown -10%, rank 3 -20% and 3 Tripwires | rank 2: 13 s, rank 3: 10 s (-3 s a rank), plus at rank 3 +3 m range and a wall stun gives a dash charge | the data's -3 s twice and its range and dash-charge upgrade; the +3 m is our pick (the data says "more range"). The data's III and IV fold into our rank 3 |
| Spirit Walk rank 3 | +0.6 s | +0.5 s, +33% move speed inside something fading over the walk, allies within 6 m walk too | +0.5 s taken directly; 150 on the data's 455 base speed = 0.33 (`dash.inside_boost`); the 6 m ally reach is our pick |
| Spirit Walk base speed | x1.35 inside something from rank 1 | x1.1 everywhere; the inside bonus is rank 3 only | the data lists the terrain speed as the last upgrade |
| Focus from snares | a snare that roots gave 40 Focus | none: Focus is cut | none |

Rank paths that do not fit our system: the dash recharge is shared code (Hunter.dash_regen, -15% a rank: 6 -> 5.1 -> 4.2 s) where the data's -1 s twice would be 6 -> 5.4 -> 4.7 s; the data's tiers II/III/IV fold into our two upgrades (II -> rank 2, III and IV -> rank 3); the shared +15% damage a rank is below the data's +20% on the Heavy Shot; the Hail Wall's rank cuts are the shared -10% a rank where the data has -2 s on the E.

Skipped, with reasons: the Hail Wall stays the arc wall at the cursor distance (the data's own upgrade says "arc width", so the arc is right and the "cone from you" note is the comparison's wording); R (Starpiercer on X) untouched.

## Scaling
Light class, 124 HP: tap 15, Empowered 30, Supercharged 60, overdrawn 30, full Heavy Shot 30 (+148 wall hit, 4.94x), Hail Wall 5 per 0.5 s, Starpiercer 18 / 18 / 25 per beam (36 s cooldown, 4x the E cooldown as in the source). Source numbers were used only as ratios (overdraw half of Supercharged, E cooldown about RMB's).

## Cross-ability interactions (combos)
| Combination | Result | Check |
|---|---|---|
| Release Empowered right on its flash | No extra damage; the next draw reaches Empowered in about 0.38 s | `--archer-combo-check` |
| Draw past Supercharged + 0.5 s | Overdrawn: half damage, the drooping release | same |
| Empowered / tap with no target | Lands at the cursor; the spent arrow stays stuck there for 4 s | same |
| Supercharged with a foe under the line | The foe ringed at its feet; a silver burst on the hit | same |
| Heavy Shot into a wall | Wall hit, 1.2 s stun, PINNED | same |
| Wall pin, then a shot | a plain arrow (no Deadeye) | same |
| Hail Wall arc | A foe on the arc burns; one inside the arc's radius does not | same |
| Spirit Walk into a rock column | Passes through; ending inside puts her back (no cost) | same |
| Knock | +1 dash charge (DashReset); no kit heal (audit: the source has none) | same |
| Rival under half health | Shown through cover (Hawk Sense) | same |
| A Boki merge mid draw / Heavy Shot / Spirit Walk | Each dropped with no shot; Spirit Walk ends | same |
| Starpiercer, then a wall pin, then three beams | The pinned foe eats every beam; lined-up foes behind it are pierced too | `--archer-combo-check` |
| Starpiercer during Spirit Walk | Shots kept; she can roll between beams | same |
| Starpiercer's last beam on a hurt hunter | EXECUTED under 12% (a knock: the cast's best bond event) | same |
| A Boki merge mid nock | No beam; the empowered window ends | same |
| Starpiercer then a merge on a full-health light hunter | Standing (burst cap) | same |
| Draw, then Shift (the roll or the air flick) or a jump (item 51) | The draw carries through and charges on; let go mid-roll and it looses as the roll ends, let go in the air and she keeps her speed. The source shows nothing ending a draw on the roll, so it combines (content/dash_flow/archer.json) | `--archer-combo-check` (`pin early release: a dash keeps the draw...`, `pin item 51: ...`), `--dash-flow-check` |

## Animations (KMovesPinBjorn ids per ability; timed to 5 fps footage frames)
| Ability | Move id(s) | Notes |
|---|---|---|
| LMB draw | `arc_draw` (held) | side-on to the cursor in 0.2 s, string hand to the chest, deeper by Empowered |
| LMB tap / Empowered / Supercharged | `arc_tap`, `arc_loose`, `arc_super` | a snap; a one-frame string snap; a hard kick back with a half step |
| LMB perfect | `arc_perfect` | a flourish of the string hand, overshoot and settle |
| LMB overdraw | `arc_over` (held), `arc_over_loose` | the draw arm shakes and sags; a drooping release |
| RMB hold (Heavy Shot) | `arc_heavy_wind` (held), `arc_heavy` | sunk low; thrown back by the shot |
| Shift (Spirit Walk) | `pin_roll`, then `pin_walk` (held) | one forward roll in 0.28 s (footage 655.55-655.65), then light-footed, arms trailing |
| Long dash | `pin_flick` | a sideways tumble |
| E (Hail Wall) | `arc_hail` | bow raised high, the volley lobbed up |
| Payoffs / procs | `pin_rundown` | locked low with the bow thrust out; a pumped fist and skip |
| X (Starpiercer), 10 fps beats | `pin_ult_cast`, `pin_ult_nock` (held), `pin_ult_loose`, `pin_ult_final` | a one-frame flash with the bow swept across the chest; string to the cheek, sunk low; a one-frame kick back with the hand flung behind; the last one lifts her off her feet into a hard crouch |
Strips: `--arena-demo=anim_<id> --arena-shot=<png>` (scripts/match/arena_demo.gd ANIM_DEMO).

## Animation timing (Nov 8: parity pass against the 5 fps footage; 10 fps for the ult)
Measured offline through `WardenClips` (hem.glb clips seeked to the kit's own move clock, `kmove_t`; blend in 0.1 s,
blend out to locomotion 0.16 s, under one footage frame) and in `--archer-combo-check`. "Hit" is the release or contact
key, "end" when the hand settles. Source times from briefs/hero-ref/pin.md (one frame = 0.2 s).

| Move | Source (s) | Ours before (start / hit / end) | Ours after | Status |
|---|---|---|---|---|
| `arc_draw` | pose up within one frame, held [f102-107] | 0.05 nock / stages 0.6, 1.15 / held from 1.15 (clip FULL 1.25) | same | matches (the hold loops the last 0.1 s) |
| `arc_tap` `arc_loose` | release a 1-frame snap, little recoil [f69] | snap 0.04-0.05 / settled 0.36-0.43 | same | matches (the snap sits inside the 0.1 s blend) |
| `arc_super` | body flash and a harder kick [f167-169] | kick 0.05, hip back 0.3 / 0.6 | same | matches |
| `arc_perfect` `arc_over_loose` | one-frame star / a drooping release | 0.06 / 0.55 (overshoot to 0.6) | same | matches |
| `arc_over` | held 0.4-0.6 s past Supercharged | from 1.65 s of draw, shakes every 0.08 s | same | matches (0.5 s past) |
| `arc_heavy_wind` | charge pose from the hold start [f264] | pose at 0.15 s of hold, clip full-draw at 1.25 (charge full 1.1) | clip on the hold's clock: full-draw and full charge both at 1.1 | fixed; asserted |
| `arc_heavy` | release frame f268, hit f271 | release 0.06 / 0.6 | same | matches |
| `arc_hail` | lob f456, rain f458 | raise 0.12, lob 0.33-0.36, rain at tell 0.35 / 0.6 | same | matches |
| `pin_roll` | 0.27 s roll, peak at 0.13, straight into the crouched walk [655.55-655.65] | peak 0.2, clip stands up 0.24-0.36, walk pose only from 0.4 | hands to `pin_walk` at roll_t 0.24 (the standing tail never shows) | fixed; asserted |
| `pin_walk` | crouched run | hold from 0.2 | same | matches |
| `pin_flick` `pin_deadeye` | not in the footage | 0.17 / 0.43; 0.45 / 0.73 | same | no source |
| `pin_ult_cast` | flash f33 (0.1 s) | flash 0.1, swept 0.25 / 0.45 | same | matches |
| `pin_ult_nock` | a 0.4-0.8 s draw a shot | nock 0.3 (held from 0.3) | nock 0.5 | fixed; asserted |
| `pin_ult_loose` `pin_ult_final` | 1.5 s a shot [f48/f63/f78] | release 0.1 / 0.5-0.65, next nock at 0.9 | recover 1.0: beam to beam 1.5 s | fixed; asserted |
| `mf_xform` | - | 0.33 / 0.8 | same | no source |

Clip re-keys for the model (tools/art1/hem_clips.py, on the unmerged ravel-v2 rebuild; none needed for parity now):
- `roll`: its last key (0.36 standing READY) could end in the crouched walk pose; the kit now hides it either way.
- `heavy_wind`: HW at 1.1 is right once the clip runs on the hold's clock (done kit-side, no re-key).

Suggestions (ours, not built): the release snap keys (0.04-0.06 s) land inside the 0.1 s blend-in, so the string hand
snap is about half weight on screen; a 0.05 s FADE for `arc_tap`/`arc_loose`/`arc_super` would show the full snap.

## Engine notes
- Kit: `scripts/arch/kits/archer_kit.gd` (wiring), `pin_draw.gd` (draw stages, reticle, perfect, overdraw), `pin_spirit.gd` (Spirit Walk), `pin_fx.gd` (pooled effects), `pin_needle.gd` (the Heavy Shot's held needle), `kit_shaders.gd` / `kit_meshes.gd` (our shaders and meshes), `scripts/match/pin_bjorn_weapons.gd` (the recurve bow model), `scripts/match/kmoves_pin_bjorn.gd` (moves). Data: `content/archetypes/archer.json`, `content/weapons/longbow.json` (`draw`, `overdraw_t`, `overdraw_k`, `quick_k`, `aim`).
- Hunter hooks: `ArchKit.draw_rate()` scales the bow's draw; `draw_bonus(t)` sets `h.shot_aim` (AimMode: stage 1 cursor, stage 2 max) and the damage factor; `Hunter.spirit_t` makes `World.occupy(..., ghost)` and the block push-out skip rocks, trees and barriers.
- Telegraphs are AimKit: `draw_rest` (line), `draw` (line to the cursor, then the thick max-range line), `draw_fill` (the bright fill), `draw_mark` (the one perfect-timing circle), `draw_tgt` (circle), `rmb_bar`, `e` (arc_wall, all, for the tell). Lace's draw uses no cursor states; only Heavy Shot uses `AimKit.charge`.
- Sounds: `tools/gen_sfx_lisette.py` writes `audio/pin_*.wav` and `archer_*` (Sfx loads them on first use).
- Merge: `_drop_holds()` clears the draw (`h.draw_t`), the Heavy Shot hold (`rmb_down`, `pin_aim`), Spirit Walk (`h.spirit_t`), and Starpiercer (`PinUlt.left`, `PinUlt.nock_t`, `window`).
- Ult on X: `scripts/arch/hero_ult.gd` (HeroUlt, the shared X base: main's `HunterKeys.ult_pressed` takes the `hunter_ult` press and the level gate, then `cast_ult` returns `HeroUlt.press(self, ult.cast)`: the cooldown in `ArchKit.cd["x"]`, the recast, a cast id), `scripts/arch/kits/pin_ult.gd` (PinUlt: the window, nock, beams, execute, pooled ribbons and pips). Data: `content/archetypes/archer.json` `x`. Sounds: `pin_ult_cast`, `pin_ult_nock`, `pin_ult_beam`, `pin_ult_final`. Bond: `HeroUlt.landed` sends `KinBond.from_ult(h, "hit" / "knock" / "kill", cast_id)`, the best event of a cast.
- No Net shape change: remote players see the shots and the existing fx events (rings, bolts).

- Looks: her moments are recipes in content/vfx/archer.json (docs/HERO_VFX.md): silver needles with red thread, missed needles left in the ground with their threads, a glowing thread string, seams across the ground.

## Payoff
