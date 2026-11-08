# Grimble the Scrap King (archetype `dredge`, heavy)

Internal design doc. Source behaviour: the hero named in the Inspired-by table in docs/ARCHETYPES.md (traceability only; none of its names, text
or looks appear in the game). Everything the player sees and hears is ours. The kitfix pass (Nov 2026) rebuilt the kit against the reference
sheet made from gameplay footage (kept outside the repo), the wiki's fine print and the owner's playtest notes.

## Research summary
Sources (gameplay facts only, written in our own words):
- The reference hero's public kit page and guides (see the Inspired-by table in docs/ARCHETYPES.md); patch notes on that page.
- The footage reference sheet (frames kept on the local machine): timing, aiming, telegraphs, animation beats.
- Owner notes: E in the air smashes straight down with the anchor (sync61 playtest); the grab goes through rocks (Nov 2 relay).

## Scaling
Source hero 1531 HP against our heavy 193 HP: damage about x0.13. The data pass (SERVER_UPDATE7, owner's tooltip data) copies
durations and counts as they are (the 0.2s stun step, the 50% cooldown cut, the +100% over the abyss) and leaves the damage
and cooldown numbers that already follow the ratios below. Numbers follow the source's ratios, not its raw values:
- the gun fires every 0.5s (the footage and card), with each slug's damage halved so the damage per second holds;
- the Anchor hits about 1.8x a point-blank volley (25 vs 7 x 2 = 14), stuns about 1.1s (the footage shows 1.2-1.4s);
- cooldowns keep the source's order and ratios: Abyssal Hand 12s : Anchor 7s : Barge 5s per charge (3 charges at 10s, chained a beat apart).

## Per-slot table
| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive, Salvage | none | Knocks and assists stack Salvage (+2.5% health each, max 10); being downed costs one; hits on a hunter's back +50%; a knock heals 16% | stacks of max health per knock/assist, lose one on death, +50% backstab, heal on knock | heal as a share of health |
| LMB, scattergun | hold/tap | 7 slugs in a 20 degree fan that stop at 6.3m and hang there as violet dots for 0.3s; a shot every 0.5s; each shot kicks the fan +10 degrees (to +15 at most) and it breathes back at 24 degrees/s from 0.1s after the shot, so held fire swings 25-35 degrees and a patient shot is back at 20; while firing the spread's two edge lines lie on the ground at the real fan, springing wide on each shot and breathing back in, brass (#e0b040) when the next shot will be at its tightest; idle one aim line to the cursor; the body rocks back each shot; the barge resets the bloom only at dash rank 3 | 7 slugs, sharp bloom, a fixed stop range, cone edge lines and an idle aim line (footage), 0.5s | the no-spread armour bonus is not reproduced |
| RMB, Abyssal Hand | tap | his arm cocks back for 0.1s, then whips out 11.5m to the first foe (45.5 m/s slowing as the arm runs out, there in 0.4s; the arm's middle trails on a spring, bows and settles; the hook is 0.36m, a 0.84m catch corridor either side of the line on a hunter): on a catch a bone ring, a sludge burst, a short shake and the arm swells on the heavy first yank; it pierces terrain (rocks, props and cliff faces) and drags the foe over it (only a placed wall stops it); the foe is stunned and reeled to your feet (11 m/s, up to 3s) with weight; he stands braced while he reels, shuffling at 20% of his walk, which still swings them round him; you are Grounded while you reel (no jump or glide, the barge still works). From the throw until the miss or the end of the reel he holds his height (no fall mid-air or over the abyss; `CastHold.hover_slow`), and while the hook flies out he can only walk at 20% speed (`rmb.fly_slow`). Rank 3: a foe it hits takes half the cooldown off. It also catches an ally (reeled in to safety) and scoops up wisps on the way. 12s | the arm pierces terrain, grabs the first target (enemy or ally), physics pull that swings, scoops wisps, only dash castable; rank 4: -50% cooldown on an enemy hit | heavy bodies (wardens) can't be pulled; a placed wall stops it |
| Shift, Barge | tap | a quick, short lunge the way you move (3.2m in 0.16s before the global dash feel, about 2.7m in 0.18s after it; 3 charges at 10s that chain 0.22s apart): a monster's low lunge, both hands clawing at the ground ahead and hauling him along, clods of turf thrown back (no burst: the owner's no-explosions-on-dashes rule); it touches nobody (the source's Brute Dash has no hit); in the air (the class air dash) a pounce, claws raked forward, 35% further (3.7m in 0.18s, the dash feel applied once); turn limited to 35 degrees for 0.8s after the Anchor | ground and air dash with separate cooldowns, further in the air, turn limit after the slam | one pool of ground charges plus the class air dash. The footage's red burst at the start point is dropped (owner item 8/35) |
| E, Anchor Drop | tap | on the ground, planted: the free fist raised high and glowing brass while the exact 3m, 110 degree cone fills on the ground in front (everyone sees it; the direction locks at the press), then at 0.38s the fist slams down into it: the damage lands on that frame, cracks under the fist and across the area, a crescent sweep, dust and a shake there, a recoil and a slow recovery: 25 damage, stun 1.1s, slammed down and Grounded. In the air: you smash straight down at once with the anchor falling beside you, a landing ring shows, and the 3.2m ring hits at the landing with up to +50% damage by the height fallen (owner note). Rank 3: double damage on a foe over the abyss and +0.2s stun more. 7s | fist slam: damage, stun, ground slam, pushes you down (not over the abyss), dunks foes over the abyss; rank 4: +100% damage vs foes over the abyss and +0.2s stun | owner note: the air cast is a straight-down smash with a height bonus (the source's rank 4 height bonus stays base). Owner item 33: one clear fist slam with a ground telegraph; the footage's forward hop and the ghost anchor are gone (the hop moved the area the telegraph promised) |
| X, Brass Broadside (ult, level 6) | tap | a 1.1s charge while a 105 degree, 5.9m fan grows on the ground in front (everyone sees it; it is the exact area, and it turns with his aim), then two waves 0.6s apart; he walks at 30% speed through the charge and 20% while the waves go (`x.charge_move`, `x.fire_move`, through `CastHold`), always turning to the cursor of six heavy brass slugs each (real shots): 4 a slug and Anti-Heal 3s. Point blank all twelve land, at 4.6m two a wave. A stun in the charge stops it (back in 8s). 21s | one press, two waves 0.6s apart, 6 slugs each with Anti-Heal, a fan telegraph, planted | 4 a slug, no back bonus: the burst cap (see Ult) |
| R | | the Boki Merge (not a hero ability) | | |

Rank 2 / 3: -10% cooldown steps (barge -15%). Rank 3 specials follow the source's last tier: the Abyssal Hand takes half its
cooldown off when it hits a foe; the barge's pellet hits trim 0.25s off the recharge and a dash resets the gun's spread; the
Anchor does double damage on a foe over the abyss and adds 0.2s of stun (on top of its +15% damage and +0.1s stun a rank).
Mismatch: the source's tiers 2 and 3 are each -2.5s on the Abyssal Hand (-1.25s on the barge, -2.5s +20% damage +0.1s stun on the
Anchor), and ours has one shared step, so rank 3 stands for the source's tiers 3 and 4 together.

## Parity pass (owner 18:45, PARITY_BRIEF)

Source (Kingpin) vs ours per slot, LMB first. [D] game data (supervive_kits.md), [F] footage (hero-ref/dredge.md,
5 fps), [O] owner notes. The parity asserts are `_parity_gun` in `tools/dredge_combo_check.gd` ("parity gun ...");
the rest are the existing asserts named in "Combinations".

| Slot | Beat | Source | Ours | Status |
|---|---|---|---|---|
| LMB | animation | [F] 0041-0045, 0080: one-handed hip fire, a 1-frame white-hot muzzle flash, the barrel kicks up, the torso rocks back side-on, back on the aim in ~1 frame (0.2 s) | `dr_shot`: kick at 0.05 s (pitch back, yaw side-on, gun up), back on the aim by 0.24 s, settled 0.36 s, inside the 0.5 s cycle; a white muzzle flash | matches |
| LMB | tracking | [F] he turns to the cursor and walks between shots | each volley is fanned on the cursor's direction at its shot; he walks on at the shared firing walk (0.8 of run) | matches ([D] has no firing slow for him; the shared rule stays) |
| LMB | cadence | [F] shots 2-3 frames apart; card 0.5 s | a volley every 0.5 s while held | matches |
| LMB | shape | [F] ~7 slugs in a ~30 degree fan (20 rested) that stop at ~3.5 bh whatever the cursor distance and hang as violet dots 0.2-0.4 s; two cone-edge lines, one aim line when idle | 7 slugs, 20 degrees rested, +10 a shot to +15, breathing back 24 degrees/s; stop at 6.3 m (cursor at 2 m asserted), hang 0.26 s as violet dots; the edge lines at the real fan, breathing, folding to one line idle | matches (it rested at 30 and never recovered while held: fixed Nov 8) |
| RMB | all | [D] pierces terrain, first target (ally too), scoops wisps; [F] caster Grounded while reeling | as the source (item 31: height held from the throw) | matches |
| E | all | [F] 0221-0236: wind-up, a hop ~1 bh forward, the slam at ~0.4 s, stun ~1.1 s; ~1.8x a volley | 0.38 s wind-up with the hop, stun 1.1 s, 25 against a 14 volley (1.8x) | matches |
| Dash | all | [O] 23:40: short, fast, visible dashes in a row (not a blink) | 3.2 m in 0.16 s, a short gap between charges | matches the owner note |
| X | all | [F] f22-f43: a 1.1 s charge behind a 105 degree fan, two waves 0.6 s apart; [O] item 36: a slow walk through it | as the source with the owner's walk | matches |

## Audit (Nov 3 23:40)

Every Grimble row of briefs/specs/kit-audit/cinder_dredge_moosh.md (it audited main 200effce): (a) already done on
this branch, (b) fixed now, (c) not applicable or we disagree. Checks are `--dredge-combo-check`.

| Row | Sev | Verdict | Where / why |
|---|---|---|---|
| RMB name and look (Abyssal Hand) | HIGH | (b) | renamed everywhere (data, card, kit text, docs, checks, wiki); the look is his mutated bone-hook arm stretching out (LDFx `arm`: bruised-purple flesh, a bone ridge, bone at the end; the `hook` prop), purple sludge dripping off it, snapping back after a miss or the reel; no rope, chain or claw (Nov 7 owner decision) |
| RMB pulling online (`remote`) | HIGH | (c) | owned by ext/online-displace; not touched here |
| RMB walking while reeling | MED | (b) | braced: he shuffles at 20% (`fly_slow`) instead of walking at full speed, between the owner's fallback (rooted) and the wiki's physics pull (the shuffle still swings the body). "reel audit: braced, he shuffles at a fifth of his walk ..." |
| RMB cooldown | LOW | (c) | fine (the kit's scale) |
| Shift: 3 chained charges | HIGH | (c) | the owner's 23:40 dash note: "several short, fast dashes in a row (charges with a short gap between them), each a quick visible burst". Owner > data |
| Shift shoves foes | MED | (b) | it touches nobody (the source's Brute Dash). "barge: it shoves and hurts nobody ..." |
| Shift turn lock after the slam | LOW | (c) | kept, wiki-sourced; it limits only the turn, Shift still acts at once (item 51) |
| Shift distance / time | LOW | (c) | DECISIONS: slower and shorter |
| Air dash cooldown | LOW | (c) | the class long-dash slot is shared by every hunter (the dash slot's air-dash diamond); a per-kit value is main's call |
| Shift rank 3 | ok | (c) | matches |
| E cooldown | ok | (c) | fine |
| E walk in the wind-up, stale docstring | LOW | (b)+(c) | the docstring is fixed; the 70% walk stays (item 51 combos and his barge out of it need him free to move) |
| E Grounded on the slammed foe | LOW | (c) | ours, noted in "Assumptions" (1 s after a 1.1 s stun) |
| E / X self-shake | MED | (c) | ext/no-shake; none added |
| E air smash, E rank 3 | ok | (c) | owner / data |
| LMB mag and reload | LOW | (c) | owner call (the footage never shows a reload); left as it is |
| Passive cap and heal | LOW | (c) | wiki-sourced, owner call |
| Passive stack ring | LOW | (b) | no ground ring on a stack: the word, the sound and the flex |
| X | ok | (c) | matches |
| X stop refund | LOW | (c) | ours, noted |
| Dash -> ability rows | LOW | (a) | item 51 (2f302eba): E and X combine; the ground LMB buffer text corrected per ext/dash-buffer-source (26bcd138) |

## Ultimate on X: Brass Broadside
Built as its own ultimate on X (owner decision, SERVER_UPDATE6). It was never folded into another slot, so nothing is unfolded.
- Cooldown 21s against the Abyssal Hand's 12s (source 20.8s : 11.7s).
- Damage: the source's two point-blank waves hit about 2.2x the slam each. Ours are 4 a slug (24 a wave against the Anchor's 25),
  lower than the ratio, because an ult straight into a merge must not one-shot anyone: at level 10 the twelve slugs deal 65 and
  the merge's burst after them leaves a full-health light hunter (124) standing (`--dredge-combo-check`, "burst"). For the same
  reason the slugs take no Salvage back bonus.
- Bond: a slug that hits an enemy hunter fills the Boki bond (a hit; a knock or a kill counts higher), the best event of the cast
  once, not per slug or wave (`HeroUlt.landed`, then `KinBond.from_ult` with one cast id per cast).

## Small mechanics
| Mechanic | Ours | Source | Footage |
|---|---|---|---|
| The grab pierces terrain and drags the target over it | built for rocks, props and cliff faces (a placed wall still stops it) | owner data, [wiki](https://supervive.wiki.gg/wiki/Kingpin), owner | yes (0141, 0147) |
| The grab takes the first target, enemy or ally; an ally is pulled to safety | built | [wiki](https://supervive.wiki.gg/wiki/Kingpin), [guide](https://deltiasgaming.com/?p=298298) | no |
| The pull follows physics: a target you don't let reach you swings round you | built (weighted reel; his braced shuffle still swings it) | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | partly (0147: the pull follows the hunter) |
| The pull lasts until arrival or 3s | built | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | yes |
| It scoops up wisps along its path | built (downed hunters it passes are reeled in too) | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | no |
| Only the dash and the air dash can be used while pulling | built | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | no |
| He holds his height from the throw to the end of the reel; slow walk while the hook flies out | built (20%, `CastHold`) | owner item 31 | no |
| The caster is Grounded while reeling; the target is stunned for the pull | built | footage | yes (0127) |
| Enemies are briefly Grounded on arrival | not built (the owner's tooltip data has no such rule; the Anchor still grounds) | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | yes |
| The dash goes further in the air and has its own cooldown there | built (class air dash x1.35) | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | no |
| The slam then a dash limits the dash's turn | built (35 degrees for 0.8s) | [wiki](https://supervive.wiki.gg/wiki/Kingpin), patch 05.02.25 | no |
| The slam pushes you down, never over the abyss | built (owner: the air cast smashes straight down) | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | no |
| Height adds slam damage (rank 4 in the source) | built for every rank (+50%) (owner note); the rank-3 bonus is the abyss damage | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | no |
| The scattergun's accuracy drops sharply with each shot; a dash resets it only at rank 4 | built (a dash resets it at rank 3) | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | yes (0040 vs 0112) |
| Rank 4 dash: pellet hits cut the dash recharge, a dash resets the bloom | built at rank 3 | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | no |
| Backstab +50% | built | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | no |
| Bonus armour damage when fired without spread | not built (our armour rules differ) | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | no |
| The ult is one press that fires two waves 0.6s apart, 6 slugs a wave | built | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | yes (ult 0034, 0040) |
| Every slug applies Anti-Heal | built (3s, as the cloak's) | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | yes (green streaks) |
| A fan grows on the ground over the 1.1s charge and is the exact hit area | built (AimKit cone, everyone sees it) | footage | yes (ult 0026, 0033) |
| He stands planted through the charge | replaced (owner item 36): a slow walk (30% charging, 20% firing) and the aim follows the cursor; still no gun, Abyssal Hand, Anchor or barge until it ends | footage | yes (ult 0022-0041) |
| Up close every slug of both waves connects | built (slugs leave his fists, so at 1.6m all six hit) | footage | yes (ult 0034, 0040) |
| Best after a stun (the reel or the slam covers the charge) | built (the reel combo is asserted) | [guide](https://deltiasgaming.com/?p=298298) | yes |
| Explosive: more damage to destructibles | not built (we have no destructible cover) | [wiki](https://supervive.wiki.gg/wiki/Kingpin) | no |

## Assumptions
Where the footage and the wiki are silent, we picked the most likely behaviour (the owner can correct these):
- "Through terrain" means rocks, trees, props and cliff faces: the hook flies through them and the body is hauled up and over
  (lifted onto a cliff face, carried to the first clear spot past a rock). A placed ability wall still stops the hook and the reel
  ("SNAGGED" / "WALLED"). The abyss is not special: a body dragged over it falls (the knock rules).
- The reel can't be cancelled by the caster; he can shuffle (20%) and barge during it (the shuffle is what swings the body).
- Hook hold (owner item 31): the source data has no number for walking while the arm is out, so the out-flight walk is the owner's default band (20%). During the reel he stands braced (the footage: side-on through the pull) and shuffles at the same 20%, between the owner's fallback of rooting him and the wiki's physics pull (the shuffle still swings the body). His height is held only while he is off the ground (on the ground there is nothing to hold); only his vertical speed is held, so a mid-air drift is the same 20% walk and knocks still shove him.
- The grab's hitbox is the hook's own size; with no target it flies its full 11.5m.
- An ally caught by the hook is neither damaged, stunned nor Grounded; a wisp is pulled like an ally.
- The glider wins over the Anchor Drop (owner bug 26 pattern): a fresh glide press during the air smash ends it with no landing hit (the source has no slam-then-glide, so the smash is dropped rather than kept) and he glides on at the normal sink; a glide key already held when he casts it doesn't reopen the glider. A low ground cast never pushes down an open glider.
- The air smash needs at least 1.2m of height; lower casts use the ground slam (with the old small downward push).
- Owner (23:40): several short, fast barges in a row, each a visible burst, not a blink. Three charges with a 0.22s gap.
  The air barge is the same quick shove with 35% more distance (faster, not longer); the footage doesn't show it. Out of
  either he keeps at most 3 m/s, so he arrives planted.
- The scattergun keeps a magazine (12 rounds, 6s of fire) and reload; the source spends mana instead.
- Backstab and Salvage values follow the wiki; the footage doesn't show them separately.
- Brass Broadside: the fan and the waves turn with his aim the whole time (owner item 36; the footage locks it at the press). The source data gives no move speed for it, so the owner's defaults are used (30% charging, 20% firing). A stun in the charge stops it with a short cooldown
  (8s); a stun between the waves stops the second. The second wave is a different colour (violet) like the footage's bluer one.
- Only enemy hunters count for the bond (the slugs still hit monsters and Boki).
- Body and movement (hero-ref "Body, scale and movement feel"): a heavy's height, 1.3x as broad across the chest and shoulders;
  slower, longer, planted steps (0.9x the step rate, stride 0.7).
- Not in the footage, built from his character: a plain jump is a deep heave off planted feet with the arms out, landing on a
  heavy squash (`dr_land`); the idle fidgets are a shoulder roll, a neck crack and a stretch. His barge leaves dark iron
  after-images with a brass rim instead of the shared pill.

## Combinations (all scripted in `--dredge-combo-check`)
| Do this | You get | Asserted by (check line) |
|---|---|---|
| Hold the gun | a shot every 0.5s, the spread's edge lines out to 6.3m, the body rocks back; idle, one aim line | "gun: a shot every half second"; "gun: the spread's edge lines lie on the ground out to the slug range"; "gun: each shot rocks the body back (dr_shot)"; "gun: idle, the cone folds into one aim line" |
| Abyssal Hand hit | reel begins; you are Grounded, they are stunned; the stretched arm shows | "abyssal hand: hooks the first foe, reel begins"; "reel: Grimble is Grounded while he reels, the foe is stunned"; "reel: the stretched arm is drawn (through rocks)" |
| Wait for the arrival | foe lands at your feet (not Grounded), "HAULED"; your Grounded ends | "abyssal hand: foe arrives at your feet and does not land Grounded"; "reel: Grimble's own Grounded ends with the reel" |
| During the reel: RMB, E, the gun | denied (only the barge works) | "reel: a second Abyssal Hand is denied"; "reel: E is denied while reeling"; "reel: the gun is locked" |
| During the reel: barge | works; the reel continues | "reel: the barge still works" |
| Reel, then Anchor Drop | the fist raised over the filling cone, the slam at ~0.38s: damage, a long stun with a spiral, Grounded | "anchor: planted, the damage lands on the slam frame (~0.38s), not at the cast"; "anchor tell: the hit cone is drawn for everyone, the slam's own radius, angle and direction"; "anchor tell: the slam hits inside the drawn cone and nothing outside it"; "combo: reel > Anchor Drop = damage, stun, Grounded"; "anchor: the stunned foe shows a stun spiral"; "anchor: E cooldown set" |
| Anchor Drop, then barge within 0.8s | barge turns at most 35 degrees | "combo: Anchor > barge turns at most 35 degrees" |
| Abyssal Hand at a cliff face | the hook pierces it and the foe is hauled up and over it | "cliff: the hook pierces a cliff face and hooks the foe behind it"; "cliff: a reel hauls the foe up and over a cliff face to your feet" |
| Abyssal Hand thrown mid-air, or a walk while it flies | no fall until it misses or the reel ends; a 15-25% walk | "hook hold: while the hook flies out he walks at 15-25% speed"; "hook hold: mid-air his height holds while the hook flies (a slow drift), and he falls once it misses"; "hook hold: a knock during the hold still shoves him, height held"; "hook hold: mid-air his height holds from the throw to the end of the reel" |
| Abyssal Hand past a rock | the foe is dragged over it | "rocks: the hook goes over a rock and drags the foe over it" |
| Strafe while reeling | braced, he shuffles at 20%; the body still swings round | "reel audit: braced, he shuffles at a fifth of his walk (not full speed), and that still swings the arrival"; "reel: the body still swings on an arc, not a straight line" |
| Hook an ally | reeled to safety, no damage, no stun, no Grounded | "ally: the hook catches an ally in its path and reels them in"; "ally: they arrive safe (not Grounded)" |
| Hook a wisp | it is scooped up and reeled in | "wisp: a downed hunter the hook passes is scooped up with the catch" |
| Anchor Drop in the air | straight down, the landing ring and the falling anchor, a ring of damage and stun, height adds damage | "air smash: straight down at once"; "air smash: the landing ring shows while you fall, the anchor falls with you"; "air smash: it lands where you land, a ring of damage and stun"; "air smash: height adds damage (6m: about +50%)"; "air smash rank 3: the height bonus stays at +50% (the abyss is the rank's bonus)" |
| Anchor Drop rank 3 | stun 1.5s; double damage on a foe over the abyss | "anchor rank 3: stun 1.5s (+0.1 a rank, and the rank's own +0.2)"; "anchor rank 3: a foe over the abyss takes double damage" |
| Anchor over the abyss | no downward push, no smash | "abyss: the Anchor never pushes you down over the void" |
| Barge on the ground / in the air | his own `dr_lunge` / `dr_pounce`, no other hero's, landing by the end of the 0.18s dash | "dash moves: his own low lunge and air pounce, no other hero's, each fitting the dash" |
| Barge timing | short and fast, seen travelling, then he stops | "barge: a short, fast shove you see travel (about half way at half its time), then he stops" |
| A run of barges | three, a short gap between | "barge: three in a row, a short gap between (a press inside the gap does nothing)" |
| Barge into a foe; barge at rank 3 with spread built up | it touches nobody (no shove, no damage); the spread resets (rank 3 only) | "barge: it shoves and hurts nobody (the source's Brute Dash), and rank 1 keeps the gun's spread"; "barge rank 3: a dash resets the gun's spread" |
| Barge in the air | the same quick time, 35% further | "barge: in the air the same quick time, 35% further" |
| A hit from behind | +50% | "passive: from behind +50%, from the front none" |
| Knock or assist | +1 Salvage (+2.5% health); a knock also heals | "passive: a knock = 1 stack, +2.5% health, a heal"; "passive: an assist stacks but does not heal"; "passive: capped at 10 stacks (+25%)" |
| Downed | -1 Salvage | "passive: being downed costs a stack" |
| Rank 3 Abyssal Hand hit / pellet hit | half the cooldown off / barge recharge trimmed | "abyssal hand rank 3: a hit takes half the cooldown off (12s -> 9.6s -> 4.8s)"; "barge rank 3: a pellet hit trims the recharge" |
| Reel over a gap in the island | the body is carried over the void and falls | "abyss: a foe reeled over the void falls (knock rules)" |
| A Boki merge mid-reel, mid-wind-up or mid-charge | the rope goes, no landing; no slam; no wave | "merge hold: dredge's reel ends with the merge, the rope is freed, nobody lands Grounded"; "merge hold: dredge's Anchor wind-up is dropped, no slam mid-merge"; "merge hold: dredge's Broadside is dropped, no wave mid-merge" |
| X below level 6 | nothing | "ult: no cast below level 6" |
| X | a slow walk, the charge move, a growing fan everyone sees that turns with the aim, 21s cooldown | "ult cast: the charge move plays, its own cooldown starts (21s)"; "ult telegraph: a 105 degree fan everyone sees, growing over the charge"; "ult: he walks slowly through the charge (about 30% of his speed)"; "ult: he walks slower still while the waves go (about 20%), and keeps turning to the cursor" |
| X, then wait | wave 1 at 1.1s, wave 2 at 1.7s, six slugs each (spawn_shot) | "ult: one press, two waves of six slugs through spawn_shot"; "ult beats: wave 1 at the end of the 1.1s charge, wave 2 0.6s later" |
| X point blank / at 4.6m | all twelve slugs and Anti-Heal / two a wave | "ult payoff: point blank, all six slugs of each wave land"; "ult payoff: 4 a slug, no back bonus"; "ult payoff: the slugs leave Anti-Heal"; "ult payoff: at 4.6m fewer slugs land" |
| X at nobody / into a hunter | no bond / a hit, once per cast | "ult bond: nothing for waves that hit nobody"; "ult bond: 12 slugs land, the cast still counts once (a hit: 0.6)" |
| Reel, then X | the hauled foe takes every slug | "ult combo: reel the foe in, then the Broadside lands (10+ slugs)" |
| RMB or E while it runs; Shift; a stun in the charge | denied; the barge goes at once and the Broadside runs on (its pose and fan follow him, both waves still go); stopped, back in 8s | "ult: RMB and E are locked while it runs; Shift barges at once and it runs on"; "ult: barged out of in the charge, both waves still go"; "ult: a stun in the charge stops it, back in 8s" |
| X, then the merge and its ultimate | a full-health light hunter survives | "burst: Brass Broadside then the merge never one-shots a full-health light hunter" |

## Animation moves
Keyed full-body moves live in `scripts/match/kmoves_pair.gd` (`KMovesPair.MOVES`, sampled through `HunterAnim.km_sample`).
| Ability | KMOVES ids | Pose idea |
|---|---|---|
| Scattergun (LMB, each shot) | `dr_shot` | the barrel kicks up, the torso rocks back and turns side-on, back to the aim in about 0.2s |
| Abyssal Hand (RMB) | `dr_throw`, `dr_reel`, `dr_pullend` | the gun to the off side, the free arm coils back then punches out; side-on and braced, hauling hand over hand while reeling (held up to 3s); a last yank and a settle |
| Barge (Shift) | `dr_lunge` | owner item 35: a monster's lunge, pitched low over the ground, both arms reaching far ahead and clawing the turf (0.04), hauling the bulk after them (0.11), landing on his knuckles in a squat at the dash's end (0.18), back up by 0.38 for the next barge |
| Plain jump / landing | `dr_jump`, `dr_land` | a deep heave with the arms out; a heavy squash onto bent knees |
| Air dash (the class air dash) | `dr_pounce` | a beast's pounce: arms cocked up, raked forward with the claws out (0.05), dragged down through the air with the legs tucked (0.14), a heavy drop onto his feet (0.24-0.38) |
| Anchor Drop (E) | `dr_anchor` | planted: the free fist raised high, shoulder turned away (0.12), up on the toes at the top (0.3), the fist driven down into the ground in front (0.38, the slam frame), a recoil bounce (0.48), a slow recovery (1.0) |
| Anchor Drop in the air | `dr_dive` (hold), `dr_quake` | both fists locked overhead dropping like a stone; a huge squash on landing, a heave back up |
| Salvage stack | `dr_flex` | chest out, both fists flexed, a stomp |
| Brass Broadside (X) | `dr_blast` | hunched over the gun and his free fist through the 1.1s charge (deeper at the end), a shove with overshoot and a barrel kick at wave 1, a short rewind, the second shove at 1.7s, then he straightens up (2.1s) |

## Look and sound
- Effects (`scripts/arch/kits/ld_fx.gd`; `shaders/ld_fx.gdshader` alpha-blended bodies with `ld_fx_glow.gdshader` glow cores,
  `ld_anchor.gdshader`, `ld_arm.gdshader`): hot pink slug streaks that hang as solid violet dots with dark cores; a brass muzzle
  flash; the stretched bone-hook arm (purple flesh swelling on each haul, a bone hook at its end, sludge drips, snapping back), drawn through rocks; the brass
  and iron chain ring at his feet while he reels; the ground slam's seafoam telegraph cone filling under his raised, glowing
  brass fist, then cracked ground under the fist and across the area; a seafoam crescent sweep, the dust cloud and seafoam stun spirals; the chain landing ring, brass sunburst and
  scorch of the air smash (he rides the anchor down); clods of turf torn up where the lunge sets off, iron and brass
  after-images along it.
- Weapon: `HeroGearPair.scattergun`: a fat iron barrel with a flared brass bell, a rope-wrapped pump, a slug drum, a glowing seam.
- Sounds (`tools/gen_sfx_grimble.py`, set `content/sfx/dredge.json`, docs/AUDIO.md): the junk blunderbuss `dr_shot` (three
  takes), the gaff hook on its chain (`dr_throw`, `dr_grab`, the winch ratchet `dr_reel`), the scrap fist (`dr_anchor_wind`,
  `dr_anchor`, the air smash `dr_dive`/`dr_quake`), the barge `dr_barge` with his hoard's `dredge_junk_clatter`, the pounce
  `dr_hop`, Brass Broadside (`dr_blast_charge`: junk crammed in and a crank ratcheting; `dr_blast`, pitched down for wave 2),
  coins for every Salvage stack and a hauled foe (`dredge_coin_jingle`) and for loot he pockets (`dredge_pickup`, with a wheezy
  chuckle), skittery claw footsteps and a wheezy, creaturely wordless voice (`dredge_hurt`, `_down`, `_death`).
- Brass Broadside (`scripts/arch/kits/dredge_blast.gd`): the growing fan in saturated brass, sparks arcing between his fists
  while charging, six big orbs per wave with a dark core and a smear (`LDFx.volley`: saturated brass for wave 1, violet for wave
  2) that fly the whole fan in the shot's 0.2s and hang at its edge fading for 0.35s as the source's orbs do (f35-f38), a
  sunburst at the fists and a crescent sweep across the fan per wave, a violet flicker rising from each target.

## Engine notes
The reel is a Displace "haul" tow (`scripts/combat/displace.gd`, decision 0016): the body moves in small steps toward wherever
Grimble is now, with a weighted velocity (`SWING`), so it swings when he moves. It is hauled over rock tiles (`World.T_BLOCK`) and
props to the first clear spot, stopped by a cliff rise (`Displace.CLIFF`) or a placed wall (`Verbs.wall_blocks`); the void is not
special. A player online is reeled on their own game the same way; the kit ends the reel when that game says it arrived. The hook's shot carries `"rocks": true`, which the match's shot step
reads to let it fly over rocks (one condition in `match.gd`). Grounded on the caster uses `KitStatus` "gnd"; `Hunter.do_dash` lets a
reeling Grimble barge anyway (`DredgeKit.reeling`).
Holds dropped on a merge (`_drop_holds`): `wind`, `dive`, `flying`, `hook_sd`, `scoop`, `pull` (with the caster's own Grounded),
and `broadside.blast` (Brass Broadside's charge and waves).
Dash flow (item 32): `content/dash_flow/dredge.json`; LMB waits for the lunge's end, the rest fire from it; Shift barges at once out of everything (item 51): out of the slam's wind-up the raised fist rides the barge and slams where it arrives, out of the air smash the pounce goes and the smash drops from where it ends, out of the Broadside the charge and waves follow him. Only a jump is refused from the hook's throw to the end of the reel (owner item 31, the source's Grounded while reeling: `into_jump.rmb`).
The slugs are ordinary shots (`Match.spawn_shot` with a `kx` callback for the hit). No new sync shape.
