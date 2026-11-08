# Cinder the Ashen Kiss (archetype `ashwick`, heavy; display name was Ashwick)

Lore sync (Nov 2026): Cinder is the court alchemist who drank the Wyrm's blood and pours fire from her bare hands. The goggles, apron and fuel tank in the notes below describe the model and gear code as built; the art pass that removes them is pending, and no player text mentions them.

Internal design doc. Source behaviour: the hero named in the Inspired-by table in docs/ARCHETYPES.md (traceability only; none of its
names, text or looks appear in the game). Everything the player sees and hears is ours. The kitfix pass (Nov 2026) rebuilt the kit
against the reference sheet made from gameplay footage (kept outside the repo) and the wiki's fine print.

## Research summary
Sources (gameplay facts only, written in our own words):
- The reference hero's public kit page (see the Inspired-by table in docs/ARCHETYPES.md), patch notes on that page.
- The footage reference sheet (frames kept on the local machine): timing, aiming, telegraphs, animation beats.

Where they disagreed: one guide attributes the pull, Anti-Heal and shield to the bolt; the wiki puts them on the shield ability,
which is what we follow. Latest version chosen.

## Scaling
Source hero 1367 HP against our heavy 193 HP: damage about x0.13 (flamethrower 205/s -> 27/s). Cooldowns about x0.8. The
ability damages keep the source's ratios to each other: bolt : ram : cloak = 248 : 279 : 117 (footage) -> 14 : 16 : 7.
The data pass (SERVER_UPDATE7, owner's tooltip data) converts like this: the ram's rank-3 +40 base damage against its 150.4 base
becomes +4.3 on our 16 (the same ratio); the ram's 150 shield is a share of source health (150 of 1290 = 11.6%), so it is 11.6% of
our health; the +75 move speed is a share of 465 (16%). The Ignite bonus sizes are our pick (the data names no number): +25% is
the footage's 29 -> 36, +40% on Flashed over, and the health chip is sized to about a tenth of the stream on a 193 health foe.
Durations (slow 1.5s, boost and shield 2s) and counts (+1 charge) copy the data.

## Per-slot table
| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive, Flashover | none | Every hit builds Char; at 31 the foe is Ablaze (3s, 2% of their health a second, one flame pip over the head); fed to 31 again they Flash over (4%, three pips and a glow). Anything that stokes a burning foe upgrades it. Char falls off all at once after 5s. A burning foe takes 25% more from the stream and the cinder (40% when Flashed over), and the stream also takes 1.5% (2.5%) of its health a second. A knock heals 16%, resets the cloak and gives back one ram charge | two burn levels, 3s, 31 stacks, refresh on any source, excess discarded, knock heal, knock restores 1 dash charge, bonus damage from the stream and the bolt against an Ignited foe | food removing the burn not reproduced |
| LMB, Torch Lance | hold | a hose of fire 7m long (it doesn't stop at the cursor): a cyan pilot flame for 0.2s, then puffs leave the nozzle and keep their own velocity, so a sweep bends the stream; 0.5m wide at the nozzle, 2.2m at the end; walls stop it; 27 damage a second, +25% (+40% Flashed over) and 1.5% (2.5%) of max health a second on a burning foe; Char 30/s whether or not the foe burns; the fire stops at once on release; 0.35s before it can relight and a 0.35s self-slow | hold flamethrower, 2 burns every 65ms, 0.35s between uses, 0.35s self-slow after release; the stream lags like a hose (footage) | own weapon (`flamethrower`); 8s of fuel kept (the source shows none) |
| RMB, Cinder Shot | hold to aim, release | a thin lane of its full 14m while held, then a red-pink fireball that always flies its full 14m whatever the cursor distance, and fizzles at its end on a miss; 14 damage, a 30% slow for 1.5s, sets the foe Ablaze; on a burning foe it does 25% (40%) more, upgrades the burn and spreads it (at the old level) to foes within 4m. 7s. Rank 3 holds two charges | bolt applies Ignite and a slow; bonus damage on an Ignited foe; it spreads (initial level) and upgrades; no knockback; rank 4 +1 charge | always its full range (owner review item 19) |
| Shift, Soot Ram | tap, 2 charges | a quick, short head-first dash toward the cursor (3.4m in 0.28s before the global dash feel, about 2.9m in 0.32s after it, fastest at the start) that stops on the first foe: 16 damage, a heavy shove (7), 17 Char, and Cinder bounces back a little. Two charges chain right away. Rank 3: +4.3 damage, and a hit gives +16% speed and a shield of 11.6% health for 2s | dash in flames, knocks struck targets back and the hero slightly back, 17 burns, 2 charges, rank 4 (owner data): +40 base damage, +75 move speed and a 150 shield for 2s on a hit | none (the folded lava carpet went back to the ult on X) |
| E, Furnace Cloak | tap (fires on the press) | the blast goes off at once round him, never at the cursor, with a quick arms-out flare (0.24s) and a thin ring at its exact 4.5m that everyone sees: 7 damage, 16 Char, Anti-Heal 3s, foes in sight dragged to you (walls stop them), a swirling 3s fire shield of 6.4% + 5.1% per foe hit. A knock resets it. 10.5s | spin: damage, Anti-Heal, pull, shield by foes hit, knock reset, blocked by line of sight; a 0.2s edge ring before it (footage) | instant on the press, no 0.2s ring first (owner review item 11) |
| X, Flue Flight (ult, level 6) | tap; X again lands | a ring of embers (2.2m, everyone sees it), then 1.8s of low flight (12.6 m/s, about 22.7m) toward the cursor that steers with the aim at up to 120 degrees a second. A 1.8m molten carpet forms under him and lasts 5.2s (the oldest end fades first): 4.5 damage a second, a 30% slow and 4 Char every 0.3s (Ablaze in about 2.4s). Only the Furnace Cloak works mid-flight (no RMB, Shift, gloves or items); a knockback speeds the flight up; a stun ends it; the carpet never forms over the abyss. 32s | flight forward that steers, a fire trail that slows and builds Ignite (4 stacks every 0.3s), 4s, recast ends it, Heat Shield castable mid-flight, impulses speed it up, no trail over abyss | no flamethrower mid-flight (owner item 66: LMB is ignored, not buffered, with a soft tick on a press; back the moment the flight ends); only E works (owner decision: RMB, Shift, gloves and items are dropped too); the flight and the carpet's linger are 30% longer (owner review item 20) |
| R | | the Boki Merge (not a hero ability) | | |

Rank 2 / 3: the shared steps (-10% cooldown, +15% damage a rank; the ram recharges 15% faster a rank). Rank 3 specials follow
the source's last tier: Cinder Shot holds a second charge; the Soot Ram does +4.3 damage and a hit gives +16% speed and a shield
of 11.6% health for 2s; the Furnace Cloak's shield is 30% bigger. Mismatch: the source's tiers 2 and 3 are each -1.5s and +25%
damage on the bolt (-0.75s on the ram, -2s and +25% on the cloak), and ours has one shared step, so rank 3 stands for the source's
tiers 3 and 4 together and the in-between numbers differ.

## Parity pass (owner 18:45, PARITY_BRIEF)

Source (Felix) vs ours per slot, LMB first. [D] game data (supervive_kits.md, the wiki), [F] footage
(hero-ref/linwick.md, 5 fps), [O] owner notes. Asserts: the "lance ..." rows of `--ashwick-combo-check` named in
"Combinations".

| Slot | Beat | Source | Ours | Status |
|---|---|---|---|---|
| LMB | animation | [F] 0021-0047: a one-frame cyan pilot at the nozzle, then the roar; the body barely moves, nozzle at the hip; the fire stops at once on release, the pilot staying | `as_lance`: braced at the hip, kicked back by the roar, bucking at 8 Hz while held; the cyan pilot for 0.2 s first; the stream snuffs within 0.08 s on release, `as_lance_end` recoils off the hose | matches |
| LMB | tracking | [F] 0016: the stream lags a sweep and curves (puffs keep their own velocity) | puffs leave along the aim every 0.033 s and keep their velocity (half of his own carried), so a sweep bends the stream | matches |
| LMB | cadence / reach | [F] ~4 bh past a close cursor; narrow at the nozzle, billowing at the end; [D] a hold, 0.35 s between uses | 7 m past any cursor, 0.5 -> 2.2 m wide, 10 ticks a second, 0.35 s relight after a release (not after a dash: item 51) | matches |
| LMB | walk | [F] no slow visible at 5 fps; the wiki has only a 0.35 s slow after release | full walk while firing, 0.6 for 0.35 s after | matches (the 0.8 while firing was ours: removed in the audit) |
| RMB | all | [F] a white aim lane ~0.4 s, a quick forward arm thrust; [O] item 19: always flies its full range | `as_aim` / `as_shot`, the 14 m lane, always 14 m | matches the owner note |
| E | all | [F] arms flung wide ~0.2 s, then the blast; [O] item 11: instant, centred on him | instant, centred, `as_cloak` arms flung wide | matches the owner note |
| Dash | all | [F] head-first ~3.4 m in 0.33 s, stops on the first foe | 3.4 m in 0.28 s, stops on the first foe, flame skull | matches |
| X | all | [F] f25-f139: low steerable flight ~7 bh/s, lava behind, recast lands; [O] item 20: a bit longer | 12.6 m/s for 1.8 s, steering 120 deg/s, carpet 5.2 s, recast lands | matches |

## Audit (Nov 3 23:40)

Every Cinder row of briefs/specs/kit-audit/cinder_dredge_moosh.md (it audited main 200effce): (a) already done on
this branch, (b) fixed now, (c) not applicable or we disagree. Checks are `--ashwick-combo-check`.

| Row | Sev | Verdict | Where / why |
|---|---|---|---|
| E pull online (`remote`) | HIGH | (c) | owned by ext/online-displace (all kits); not touched here |
| Knock reset ring | MED | (b) | the "CLOAK READY" reset keeps its word, sound and HUD ready flash; no ground ring, no net ring |
| LMB fuel (8 s, 1.6 s refill) | MED | (b) | no fuel: the data's Flamethrower is a plain hold. "lance audit: 10 s of roaring with no fuel to run out ..." |
| LMB self-slow while firing | MED | (b) | full walk while firing; only the wiki's 0.6 for 0.35 s after release. Same assert |
| RMB cooldown, input | LOW / ok | (c) | fine per the audit (0.78x, the kit's scale) |
| Shift distance / time | LOW | (c) | DECISIONS: dashes slower and shorter |
| Shift direction text | LOW | (b) | the card and the dash text say the way you move (DECISIONS: WASD by default) |
| Shift hit ring | LOW | (b) | the ram's impact keeps its flash on the foe; no ground ring |
| Shift / E / lift-off self-shake | MED | (c) | ext/no-shake; none added |
| Air poof | ok | (c) | owner-requested |
| E cooldown | ok | (c) | fine |
| E pose length | LOW | (b) | CLOAK_POSE_T 0.25 s (item 11's 0.15-0.25 s) |
| X cooldown | LOW | (b) | 36 s (the data's 45 s at the kit's 0.8x). "ult cast: its own cooldown starts (36s ...)" |
| X casting in flight | MED | (b) | only E works mid-flight (owner item 66 decision: no lance, Cinder Shot, Shift, gloves or items). "ult: the Cinder Shot goes mid-flight ...", "ult 66: ..." |
| X lift-off ring | LOW | (b) | the ember puffs and wave stay (footage f25); the AimKit disc shown to everyone is gone (it hit nothing). "ult cast: lifts off in its ember puffs, no aim disc" |
| X aim / recast | ok | (c) | matches |
| Passive Flashover | ok | (c) | matches |
| Passive knock heal and ram charge | LOW | (c) | wiki-only (no tooltip line); kept, flagged as ours in "Assumptions" |
| Dash -> ability rows | MED | (a) | the hose keeps its hold through the ram (item 51, 15ca4857); the ground dash -> LMB buffer text corrected per ext/dash-buffer-source (26bcd138) |

## Ultimate on X: Flue Flight
The source's flight is back as its own ultimate on X (owner decision, SERVER_UPDATE6), so the rank-3 Soot Ram no longer lays the
carpet: that fold would have duplicated the X ult, and the ram's rank 3 follows the owner's data (more damage, speed and a shield).
- Numbers keep the source's ratios: cooldown 32s against the cloak's 10.5s (source 25s : 8.3s); the carpet ticks far below the
  hose (about 1/6 of its damage a second, as in the footage), and its value is the slow and the Ignite build-up.
- Bond: an enemy hunter the carpet burns fills the Boki bond (a hit; a knock or a kill counts higher), the best event of the cast
  once, never the cast alone (`HeroUlt.landed`, then `KinBond.from_ult` with one cast id per cast).
- Burst: Flue Flight plus the cloak, then straight into a merge and its ultimate, leaves a full-health light hunter standing
  (`--ashwick-combo-check`, "burst").

## Small mechanics
| Mechanic | Ours | Source | Footage |
|---|---|---|---|
| The flame stream lags behind a sweep (a hose, not a cone) | built | footage only | yes (0016) |
| The stream runs its full length whatever the cursor distance | built | footage | yes (0012) |
| Cyan pilot flame for one beat before the fire, and while idle | built | footage | yes (0021, 0047) |
| Fire stops at once on release | built | footage | yes (0047) |
| 0.35s before the flamethrower can be used again; 0.35s self-slow after release | built | [wiki](https://supervive.wiki.gg/wiki/Felix), patch 20.11.2024 | the slow is not visible at 5 fps |
| Flame and bolt hit harder on a burning foe, and the flame chips max health | built (+25%, +40% Flashed over; 1.5% / 2.5% of max health a second) | owner data (the sizes are ours), footage (29 -> 36) | yes (219-220 s) |
| Char above 31 is discarded; it all falls off after 5s | built | [wiki](https://supervive.wiki.gg/wiki/Felix) | no |
| Any new burn refreshes the duration | built | [wiki](https://supervive.wiki.gg/wiki/Felix) | no |
| Cinder spread uses the first foe's level before its upgrade | built | [wiki](https://supervive.wiki.gg/wiki/Felix) | no (one dummy) |
| Cinder Shot doesn't knock back | built | [wiki](https://supervive.wiki.gg/wiki/Felix), patch 18.12.24 | yes |
| Cinder Shot always flies its full range in the aim direction | built | owner review (wins over the one footage miss that ended near the cursor) | one sample (0133) |
| Ram stops on the first foe; the foe is knocked back and Cinder slightly too | built | [wiki](https://supervive.wiki.gg/wiki/Felix), footage | yes (0141-0145) |
| A knock restores only one ram charge | built | [wiki](https://supervive.wiki.gg/wiki/Felix) | no |
| The cloak is blocked by line of sight; a knock resets it | built | [wiki](https://supervive.wiki.gg/wiki/Felix) | no |
| The carpet can't form over the abyss; builds burns every 0.3s | built | [wiki](https://supervive.wiki.gg/wiki/Felix) | no |
| The flight steers toward the cursor while flying (curved trails) | built: 120 degrees a second at most | footage | yes (ult 0034, 0038) |
| Reactivating ends the flight early | built (X again lands) | [wiki](https://supervive.wiki.gg/wiki/Felix), card | no |
| The trail forms under him whatever his height or speed and grows with the distance flown | built (a piece every metre) | [wiki](https://supervive.wiki.gg/wiki/Felix) | yes |
| The trail slows and builds Ignite quickly: 4 stacks every 0.3s, Ignited after about 2.4s | built (4 Char every 0.3s, Ablaze at 31) | [wiki](https://supervive.wiki.gg/wiki/Felix) | no |
| The trail lasts 4s and fades from the oldest end | built (5.2s: owner review, +30% with the flight) | [wiki](https://supervive.wiki.gg/wiki/Felix), footage | yes (ult 0072) |
| The trail can't form over the abyss | built | [wiki](https://supervive.wiki.gg/wiki/Felix) | no |
| The shield ability can be cast mid-flight | built (Furnace Cloak) | [wiki](https://supervive.wiki.gg/wiki/Felix) | yes (ult 0137) |
| Knockback impulses greatly increase the flight's speed | built (up to +10 m/s, bent the way he was pushed) | [wiki](https://supervive.wiki.gg/wiki/Felix) | no |
| A red-orange ember ring at lift-off, no big landing | built | footage | yes (ult 0025, 0039) |

## Assumptions
Where the footage and the wiki are silent, we picked the most likely behaviour (the owner can correct these):
- Cinder Shot is "hold to aim, release to fire" (the lane shows about 0.4s before each shot); a tap fires at once. It always
  flies its full 14m (owner review; one footage miss looked cursor-clamped).
- The bolt slows (owner data, which wins over the footage): 30% for 1.5s. The data gives no numbers; the 30% is the carpet's.
- The ram can't be steered once it starts and has no wind-up; it goes toward the cursor (the footage shows the cursor side).
- The pull of the cloak reaches the whole 4.5m ring and needs line of sight; dragged foes stop at walls.
- The shield's size follows the wiki numbers (the footage doesn't show them); it lasts 3s.
- Ablaze lasts 3s on its own; a fresh stoke refreshes it.
- The hose has no fuel and nothing reloads (the source shows no fuel bar; no reload exists in the game). The 0.35s relight gap and the self-slow after release are the only limits.
- The pilot flame is cyan in our palette too (it reads as cool against warm fire); the burn pips use our own flame shape.
- Flue Flight: he is not crowd-control immune; a stun ends the flight where he is. He flies over the abyss at the height he had
  (only the carpet is missing there). The lance is off for the whole flight (owner item 66): the key is ignored, not buffered, a press
  ticks softly, and the idle pilot flame goes out; it is back the frame the flight ends. Owner: in the flight ONLY E (the cloak) works, and X again lands.
  RMB, Shift (no poof), the glove and utility slots, gear, the Boki's C and a throw are dropped, not buffered (AshwickJet.lock_inputs).
  Steering and a jump stay (movement, not abilities).
- The flight's telegraph for the player is a heading lane with chevrons as long as the flight still has to go; foes see only the
  ember ring and the carpet, as in the footage.
- Only enemy hunters count for the bond (the carpet still burns monsters and Boki).
- Body and movement (hero-ref "Body, scale and movement feel"): 0.76 of a heavy's size and a little broad, the tall hat kept;
  quick short steps (1.8x the step rate, stride 0.45); the hitbox stays the heavy 0.5 (the ring under him shows it).
- Owner (23:40): the air dash is a long, fast "poof" (8m in 0.24s before the global dash feel) from a cloud of smoke and
  flame blown out behind him (no blast: owner review item 35), balled up for one roll, then sailing spread-eagled; he
  keeps half its speed after it.
- Not in the footage, built from his character:
  a plain jump is a quick crouch and a springy tuck, landing on a light squash (`lw_land`); the idle fidgets are a restless
  bounce, a bob and a check of the nozzle. His dashes leave ember puffs that burn out behind him instead of the shared pill, burst and ring
  (`own_dash_trail`), and his ram and poof moves are the whole dash pose (`dodge_anim` "kit": no shared heavy charge pose
  under them; owner review item 35).

## Combinations (all scripted in `--ashwick-combo-check`)
| Do this | You get | Asserted by (check line) |
|---|---|---|
| Hold the lance | a cyan pilot, no fire for 0.2s, then a 7m stream past a close cursor | "lance: the cyan pilot shows, no fire for the first 0.2s"; "lance: the stream runs its full ~7m past a close cursor" |
| Sweep while firing | the old fire keeps flying its own way (the stream bends) | "lance: a sweep bends the stream (old fire keeps its own heading)" |
| Look at the stream | narrow at the nozzle, billowing at the end | "lance: narrow at the nozzle, billowing at the far end" |
| Let go, press again at once | the fire stops at once; 0.35s before it relights; a short slow | "lance: letting go stops the fire at once"; "lance: 0.35s before it can roar again" |
| Hold the lance through a ram (or a poof) / a jump | the stream goes out for the dash and roars again the step it ends (no pilot, no relight gap: the gap is after a release); it keeps burning through a jump | "lance: held through a ram it goes out, then roars again within 0.1s of its end (item 51)"; "lance: it keeps burning through a jump" |
| Keep the lance on a foe about 1s | Ablaze, one pip | "lance: ~1s on the foe = Ablaze (level 1)"; "burn stage: one flame pip over a foe Ablaze" |
| Keep holding on a burning foe | Flashover, three pips and a glow | "lance: kept on a burning foe it Flashes over (level 2)"; "burn stage: three flame pips and a glow over a Flashover" |
| Lance a burning foe | +25% and 1.5% of health a second (Flashed over: +40% and 2.5%); Char at the full rate | "lance: +25% and 1.5% of health a second on an Ablaze foe (per tick)"; "lance: +40% and 2.5% of health a second on a Flashed-over foe (per tick)"; "lance: a burning foe builds Char at the full rate" |
| Hold RMB | the full 14m lane; release fires; it always flies 14m; a miss fizzles at its end | "cinder: holding shows the aim lane at its full fixed length (cursor at 2 m)"; "cinder: a miss flies its full length and fizzles at its end"; "cinder: cursor at 2 m and at 20 m travel the same distance, the max" |
| Cinder Shot on an unburnt foe | Ablaze and a 30% slow | "cinder: a hit sets the foe Ablaze"; "cinder: the hit slows the foe 30%" |
| Cinder Shot on a burning foe | 25% more damage, upgrade + spread at the old level | "cinder: 25% more on an Ablaze foe"; "combo: lance burn > Cinder Shot = upgrade + spread" |
| Cinder Shot rank 3 | a second charge | "cinder: one charge at rank 1"; "cinder: a second charge at rank 3" |
| Soot Ram into a foe | stops on them with the flame skull: damage, 17 Char | "ram: the flame skull wraps his front while it flies"; "ram: stops on the first foe and shoves it hard (doesn't pass through)"; "ram: impact damage and 17 Char" |
| Ram, then the air poof | his own moves (no shared pose), each covering its dash, no ring | "dash moves: the ram and the poof play his own moves, no shared pose under them"; "dash moves: each covers its dash and settles soon after"; "dash moves: no other kit plays them"; "dash moves: no ring on the ram or the poof" |
| Two rams in a row | chained within 0.4s | "ram: toward the cursor, two charges chain within 0.4s" |
| Knock with no charges | one ram charge back | "passive: a knock gives back one ram charge, not both" |
| Soot Ram rank 3 | +4.3 damage; a hit gives +16% speed and an 11.6% health shield for 2s; no instant burn, no carpet (that is the X ult) | "ram rank 3: +4.3 damage (before the rank's own +30%)"; "ram rank 3: a hit gives +16% speed and a 11.6% shield, and no instant burn"; "ram rank 3: the boost ends after 2s" |
| X below level 6 | nothing | "ult: no cast below level 6" |
| X | the ember ring, the lift-off move, a heading lane, 32s cooldown | "ult cast: lifts off with the ember ring everyone sees"; "ult cast: its own cooldown starts (32s)"; "ult telegraph: the heading lane shows while flying" |
| X, then X again | lands early | "ult recast: X again lands early" |
| Shift, RMB, gloves, items in the flight | nothing: no cooldown or charge spent, no projectile, no item used; E still works | "ult 66: RMB mid-flight ..."; "ult 66: Shift (dash), Q/V gloves ..."; "ult 66: the utility slots use no item"; "ult 66: E still works after all that" |
| Jump in the flight | he leaps off it at once: the flight ends (the carpet stays), a jump-out-of-a-dash share of its speed carried into the air and on into a glide | "ult: a jump in the flight leaps off it within 0.1s, keeping its speed into the air" |
| X and steer | the flight curves, at most 120 degrees a second | "ult steer: the heading turns toward the cursor, capped at 120 deg/s"; "ult steer: the flight curves (it ends well to the side)" |
| X | a 1.8s flight of about 22.7m | "ult: the flight lasts 1.8s (+25-35% on 1.4s) and covers about 22.7m" |
| X through foes | a 5.2s carpet that burns, slows 30% and builds Char; Ablaze in about 2.4s | "ult payoff: a molten carpet along the flight that lingers 5.2s (the flight's +30%)"; "ult payoff: the carpet burns, slows and builds Char"; "ult payoff: standing in it, Ablaze after about 2.4s" |
| X over nobody / through hunters / knocking one | no bond / a hit (once per cast) / a knock | "ult bond: nothing for a cast that lands on nobody"; "ult bond: burning a hunter fills it once per cast"; "ult bond: a knock with the carpet counts as the cast's best event (0.7)" |
| X, then E mid-flight | the cloak goes off, the flight goes on (pull foes into the carpet) | "ult: the Furnace Cloak works mid-flight (the flight goes on)" |
| X, then RMB | the Cinder Shot goes, the flight goes on | "ult: the Cinder Shot goes mid-flight and the flight goes on" |
| X, then LMB (held or tapped) | nothing: no flame, nothing queued, a soft tick on each press; held, the lance lights the frame the flight ends (its usual 0.2s pilot, then the roar) | "ult 66: LMB held through the whole flight: no flame, no pilot, no lance damage, Char or burn"; "ult 66: a tap in the flight is ignored, not buffered (nothing fires on landing)"; "ult 66: LMB works on the first frame after the flight (the lance lights)" |
| X over a gap | he flies across, no carpet over the void | "ult abyss: the carpet never forms over the void, he flies across" |
| A knockback or a stun mid-flight | faster / the flight ends | "ult: a knockback mid-flight speeds it up"; "ult: a stun ends the flight" |
| X, then the merge and its ultimate | a full-health light hunter survives | "burst: Flue Flight then the merge never one-shots a full-health light hunter" |
| Furnace Cloak | on the press, round him whatever the cursor: damage, Char, Anti-Heal, drag, swirling shield | "cloak: fires on the press frame (no hold-to-aim, no delay)"; "cloak: the ring is centred on him at the blast's exact radius (cursor ignored)"; "cloak: a quick arms-out flare (0.15-0.25 s)"; "cloak: no cursor dependence (cursor far away or on the foe: the same pull)"; "cloak: damage, Char, Anti-Heal and a shield"; "cloak: foes in sight are dragged toward you"; "cloak: the swirling fire shield shows while it holds" |
| Lance or cloak behind a wall | nothing | "wall: the lance does not burn through a wall"; "wall: the cloak does not reach behind a wall" |
| Knock | heal and the cloak resets | "passive: a knock resets the cloak and heals" |
| Furnace Cloak rank 3 | shield 30% bigger, no refund | "cloak rank 3: shield +30%"; "cloak: rank 3 no longer refunds on a stoke" |
| Char past 31; Char left alone | discarded; falls off after 5s | "passive: Char past 31 is discarded (burn, then 0)"; "passive: Char falls off all at once after 5s" |
| Carpet over the abyss | never forms | "abyss: the carpet never forms over the void" |
| A Boki merge mid-lance or mid-flight | the hose and the flight drop, nothing fires or is laid | "merge hold: linwick's lance is dropped, no fire mid-merge"; "merge hold: linwick's flight is dropped, nothing more is laid" |

## Animation moves
Keyed full-body moves live in `scripts/match/kmoves_pair.gd` (`KMovesPair.MOVES`, sampled through `HunterAnim.km_sample`), timed
to the sheet's beats: anticipation, release (with an overshoot key), follow-through, recovery.
| Ability | KMOVES ids | Pose idea |
|---|---|---|
| Torch Lance (LMB, held) | `as_lance` (hold, looped), `as_lance_end` | sets his feet and drops the nozzle to the right hip during the 0.2s pilot, kicked back hard as the roar starts, then braced leaning in with the hose bucking (an 8 Hz loop); a little recoil off the hose on release |
| Cinder Shot (RMB) | `as_aim` (hold), `as_shot` | gun hand cocked at the shoulder sighting down the lane; release: the arm thrusts out (overshoot), the body kicked back by the shot |
| Soot Ram (Shift) | `as_leap` (0.55s over a 0.32s ram) | a coil, then head first like a battering ram, balled up compact in the flame skull (arms swept back, knees folded up behind), held through the ram; squashes on impact, springs upright with the gun on the aim (footage 0159-0161) |
| Air poof (the air dash) | `lw_hop` (0.7s over a 0.28s poof, then the kept speed) | balled up as the bellows blow a cloud of smoke and flame out behind him (no blast), one fast roll forward, then sailing out spread-eagled while the speed bleeds off |
| Furnace Cloak (E) | `as_cloak` | 0.24s on the press: a quick tuck, then chest out and the arms flung wide with the blast (up on his toes, the flamer swung up on its strap), held a beat, settle |
| Flashover payoff, a knock | `lw_stoke`, `lw_stoke_lance` (mid-roar) | the off fist punches up over his head, a lean back, a bounce; mid-roar the nozzle stays on the foe and the hold goes on |
| Plain jump / landing | `lw_jump`, `lw_land` | a quick crouch and a springy tuck; a light squash |
| Flue Flight (X) | `lw_jet` (held), `lw_land` | a crouch as the ember ring bursts (0.08s), then he springs up and leans into the jet, the free arm swept back to the bellows strap, the nozzle held low (the gun hand stays on it), legs trailing; on landing a squash onto his feet |

## Look and sound
- Effects: `scripts/arch/kits/ld_fx.gd` (pooled; `shaders/ld_fx.gdshader` draws each look's body alpha-blended so colour and
  soot hold on bright grass, `ld_fx_glow.gdshader` adds only the hot cores): the hose as pooled fire puffs (an orange body with a
  deep red band and a sooty rim, a white-hot core near the nozzle), the big cyan pilot, the Cinder Shot fireball (red-pink body,
  yellow core, violet halo, dark smoke tail; a red jagged flash, red orb and embers on hit, a violet fizzle ring on a miss), the
  flat flame skull with long ember tails on the ram and ember-puff after-images, the jagged 14-ray sunburst and cracked scorch of
  the cloak, the deep orange two-ring fire shield, the molten carpet with charred edges, and the flame pips over burning foes.
- Weapon: `HeroGearPair.flamer`: ribbed brass barrel, flared bell nozzle with a pilot cage, fuel canister, hose to the pack.
- Sounds (`tools/gen_sfx_cinder.py`, set `content/sfx/ashwick.json`, docs/AUDIO.md): the lance's pilot and roar (`lw_pilot`,
  `lw_roar`, three takes, one every 0.4 s while held), the tank hiss on release (`ashwick_tank_hiss`), `lw_bolt`/`lw_bolt_hit`,
  `as_ignite` (Ablaze), `lw_blaze` (Flashover), `lw_bash`/`lw_bash_hit`, the bellows poof `lw_hop`, `lw_shield` and
  `ashwick_cloak_hit` (Furnace Cloak), `lw_jet`/`lw_jet_land`/`lw_trail` (Flue Flight), and her own dash, footsteps
  (a light patter, the pack clinking every other step) and wordless voice (`ashwick_hurt`, `_down`, `_death`).
- Flue Flight (`scripts/arch/kits/ashwick_jet.gd`): the ember ring, scorch and sunburst at lift-off, a hot core and embers blown
  out of the bellows while flying, and the carpet as pooled LDFx lava strips drawn with their own alpha-blended shader
  (`shaders/ld_lava.gdshader`), so the charred rim stays dark on bright ground.

## Engine notes
The hose is simulated on the match step (`scripts/arch/kits/ashwick_hose.gd`); a puff stops at a wall (`World.occupy`) and hurts
only with line of sight from the puff. The burn uses the engine's own burn status (credit to Cinder); remote bodies get it through
a hit with a burn option. The cloak's drag is a Displace "step" tow (decision 0016): foes move in steps against the world's occupancy test, a player online
on their own game.
Flue Flight rides the hunter's own dash movement (`Hunter.dash_with`, kind "jet"), re-aimed every step, so walls stop it as they
stop a dash; the kit holds him a little off the ground. Other players see the ember ring and carpet as Net fx rings and the moves
through the kit move id; no new sync shape.
The Furnace Cloak fires on the key's press: `e.on_press` in the data, read through `ArchKit.e_on_press` by Match's input loop,
so E skips the hold-to-aim preview (there is nothing to aim).
Holds dropped on a merge (`_drop_holds`): `hose` (the stream), `spool`, `was_held`, `after_t`, `flame_acc`, `bash`, `aiming`,
and `jet.flight` (Flue Flight).
