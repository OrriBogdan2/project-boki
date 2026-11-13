# Early game = camps, and a bigger drop (spec + build list)

Job 20261110-171956-a4 (design lead, docs only), owner order 11-10 ~12:30 PM EST, for 0.24.4. Extended by job 20261110-174036-a4 (owner orders 11-10 ~12:45 and ~1:15 PM EST): section 6, "Levels as strategy". Where an older line and section 6 differ, section 6 wins.
Read against: release candidate `origin/ext/release-integ-0244-fix` ec3c9dafb, the 2x map `origin/ext/map-2x-0245` 2bd777c00, `briefs/specs/LIMITED_WAY_OUTS.md` rev 2 on `origin/ext/spec-ways-out-zone` 31c118f4f (12:00 match, four seats, the Blight closes on five beats: 2:00, 4:00, 6:00, 8:00, 10:00), DECISIONS.
Build list: `briefs/specs/EARLY_CAMPS_DROP_TASKS.jsonl`.

## Owner summary (10 lines)
1. Today a camp pays almost nothing and standing still levels you. That is why the early game feels random.
2. New rule: XP comes only from kills. Nothing over time, nothing for damage. Hitting Hunters builds your armor, as it does now, and nothing else.
3. A monster's XP goes to whoever lands the last hit, and in full to their squadmates within 30 m. Steal the last hit and you take the XP and the reward, and both squads get a callout.
4. Every camp is on the drop map from the first second with its size: Small Camp 60 XP, Camp 110, Great Camp 190. The first decision is "which camps do we land on". 28 camps on the 2x map; the hot zone's are one size bigger.
5. The level cap stays 10. Every level: 6% more health, 5% stronger abilities, one ability point. Even levels: a weapon upgrade. Level 6: the ultimate. Level 9: the stronger ultimate.
6. The pace: level 3 to 4 when the Blight first closes (2:00), 5 at 4:00, the ultimate for the Heart fight at 5:15, 8 to 9 at the end. Camps level you early, Camp Chiefs and bosses in the middle, Hunters late.
7. Catching up without free XP: behind the pace, monsters pay you up to 75% more; a higher-level Hunter is worth 30 more per level of gap; a revived Hunter comes back at most 2 levels under their squad. Two levels ahead of the pace, camps pay you less: go and fight.
8. You always see it: your level and an XP bar bottom-left that pops on every kill, and every enemy's level on their nameplate, coloured by the gap to you.
9. A cleared camp comes back once, one size bigger, after 2.5 minutes, so there is a reason to return or to steal.
10. The drop: the ship flies at 110 m (70 today), the dive is half again as fast, you punch through a cloud layer, camps send up smoke to steer at, and holding the dive to the ground is a Hard Landing that staggers the monsters you land on.

## Owner calls (3, each with the default we build)
| # | Call | Default (built unless you say otherwise) | Alternative |
|---|---|---|---|
| 1 | Ship height | **110 m**, about 7 s straight down in a dive, 22 s if you glide the whole way | 140 m: grander, but 9 s and 28 s; one number in `content/rules/drop.json` |
| 2 | Hard Landing hits | **Monsters only** (stagger 1.5 s, 30 damage). Hunters are never hurt or staggered by a landing | Also shove Hunters 2 m: funnier, but landing on a squad becomes the meta |
| 3 | Monster XP bends with the pace | **Yes**: a Hunter behind the match's pace level gets +25% monster XP per level behind (up to +75%); 2 ahead gets 75%, 3 or more ahead 50% (section 6.5) | Flat XP for everyone: purer, but a squad that lost its first fight stays behind until it wins one |

Decided by the owner 11-10 ~1:15 PM (was call 3): **no XP over time at all**, and no level XP for damage.

## 1. What is wrong today (numbers from the release candidate)
XP to reach a level (`hunter.gd` XP_TO): L2 70, L3 170, L4 300, L5 460, L6 650 (ultimate), L7 870, L8 1120, L9 1400, L10 1710.

| Source today | Pays | Problem |
|---|---|---|
| Trickle (`hunter.gd` ~1918) | 1.2 XP/s = 72 a minute, to everyone | Standing still reaches L4 at 4:10 and L6 at 9:00. It is the biggest source in a quiet match |
| Damage to monsters (`match.gd` ~1783) | 0.35 per damage, to the one who dealt it | A Great Camp (Brute 170 + Sentinel 70 + Spitter 44 + Skitter 34 = 318 hp) pays 111 XP in total, split by who hit what: about 37 each. A Small Camp pays 24 |
| Damage to Hunters | 0.6 per damage, to the dealer | Poke trades level you; who gets it depends on who landed the stray shot |
| Knock (`match.gd` ~1850) | 90 to the knocker | Last hit takes it all |
| Boss lair (`lairs.gd` ~712) | 260 shared by share of the fight | Squads that did not land the kill are paid for it; replaced by the last-hit rule (section 6.3) |

Camps exist (`world.camp_spots`, kinds light/normal/heavy, spawned in `Match._spawn_mobs`, 19 on the 2x map) but pay nothing on a clear, drop loot by per-monster dice, are not on the map, and come back only in the cut rolling mode (`rolling.gd` CAMP_RESPAWN).

## 2. Camps
One new module, `scripts/match/camps.gd`, owns camps: it takes over `_spawn_mobs` (out of `match.gd`), the clear, the pay, the reward and the comeback, and deletes the rolling copy. All numbers in `content/rules/camps.json`. The genre's structure, our names and numbers.

### 2.1 Sizes
| Size (player text) | Layout kind | Monsters | XP in the camp, to each squadmate in range (the sum of its monsters, section 6.3) | Reward, dropped once where the last monster fell | Clear time, 3 Hunters at L1-2 |
|---|---|---|---|---|---|
| **Small Camp** | light | 2 small (Skitter, Puffbomb, Spitter) | **60** | Armor 25 | 8-12 s |
| **Camp** | normal | 3: two small + a Sentinel | **110** | Armor 50, a perk orb 50% of the time | 15-25 s |
| **Great Camp** | heavy | 4: the region's Brute + 3 small | **190** | Armor 50, one perk orb (always), one gear piece at the region's rarity | 30-40 s |
| **Camp Chief** (hot zone and comeback Great Camps) | heavy + chief | A Great Camp whose Brute is an Elite, the Chief | **260** | Great Camp's, with the gear piece one rarity step up | 40-50 s |

- **Pay rule (owner 11-10):** XP is a kill reward, paid per monster the moment it dies, to the Hunter who landed the last hit and in full to each of their squadmates, alive or downed, within 30 m of the kill. Not split, nothing for damage. The camp's number above is just the sum of its monsters (section 6.3). A squadmate more than 30 m away gets nothing: stay together.
- **Steal rule:** a rival squad that lands the last hit on a monster takes that monster's XP. The squad that lands the camp's **last** kill takes the reward bundle: it is theirs alone for 8 s, then anyone's. Third-partying a half-dead Great Camp is a real play, the Hard Landing (section 3) is the tool for it, and section 6.6 is how both sides read it and answer it.
- **Loot rule:** camp monsters stop rolling their own drops (the Brute's 50% orb, 25% valuable, the 12% and 35% seeds in `match.gd` ~2236). The camp pays one fixed bundle, merged in one spot (the perf order: fewer, bigger drops). Monsters outside camps (the Blight's, lair broods, elites) keep theirs.
- **Region flavour:** which small monsters is still the region's biome table (`BiomeRun.camp_comp`); the size fixes the count and the big one. Camp monsters are always common rarity, bar the Chief, so a camp's size is its XP and the map never lies.

### 2.2 How many, where (2x Hollow Crown, 10 trios)
28 camps (19 today), 79 camp monsters (59 today; 82 when the hot zone makes its camps bigger). Sizes follow how close a region is to the centre, because the Blight closes on the Heart: the rim is eaten first, the Crown last.

| Ring | Regions | Camps per region | First-clear XP each | Role |
|---|---|---|---|---|
| Rim (corners) | Larkhollow, Highwatch, Duskmoor, Saltmere | 2 Small + 1 Camp | 230 (L3) | The quiet drop. Safe, small, and the first land the Blight takes, so it forces a move inward |
| Mid | Frostgate, Cinder Steps, Stormbreak, Thornwood | 1 Small + 1 Camp + 1 Great | 360 (L4) | The standard drop. One squad levels fully; two squads fight over the Great Camp |
| Crown | The Crown (not the Gaols: those are lairs) | 1 Camp + 3 Great | 680 (L6) | The greedy drop: most XP, most squads, the Sealed Lair next door at 2:00 |
| Hot zone | One non-Crown region per match (existing `HotZone`) | Every camp one size up; Great becomes Camp Chief | Rim 410, Mid 560 | The fight drop. Loot is already +1 rarity there |

- Placing rules for the map task: camps in a region at least 30 m apart and at most 70 m (a clear path, small to great); at least 14 m from a train halt and 20 m from a lair gate or quest seat; each within 12 m of cover; the Great Camp nearest the region's inner edge (it pulls squads the way the Blight will push them).
- Supply check: first clears hold 3,040 squad-XP for 10 squads, about 300 each (L4). There is not enough for everyone to be L5 off camps: the rest comes from knocks, comebacks and the lair, which is the point.

### 2.3 Coming back
- A cleared camp comes back **once**, **150 s** after its clear, **one size up** (Small to Camp, Camp to Great, Great to Camp Chief), if no Hunter is within 30 m, the spot is outside the Blight and will still be outside it for 60 s. No comebacks after 7:00: the end is about Hunters.
- The map shows it: a cleared camp is a dim icon with a ring that fills until it returns (to a squad that has been within 60 m of it since the clear; others still see it live until they get eyes on it).
- Why once and bigger: it pays a squad for holding or returning to its region mid-game (L6 for the Heart fight), gives a beaten squad something to catch up on, and caps the monster count.

### 2.4 XP sources after the change
One rules file, `content/rules/xp.json`, read by a small `scripts/match/xp_rules.gd`; the inline numbers in the god files go. Full tables in section 6.

| Source | Today | New | Why |
|---|---|---|---|
| Monster kill | 0 (only damage XP, 24-111 for a whole camp) | The monster's XP (Skitter 30 to Brute 100, section 6.3) to the last hit's squad in range. Camps sum to 60 / 110 / 190 / 260 | The core |
| Damage to monsters | 0.35 per damage | **0** | Owner: the kill pays, not the damage |
| Damage to Hunters | 0.6 per damage | **0** (armor progress only, unchanged) | Owner: hitting players never levels you |
| Knock | 90, knocker only | **40 + 15 x the victim's level**, to the knocker's squad in range, bent by the level gap (section 6.5) | Shared; a levelled squad is worth a camp each |
| Trickle | 1.2 XP/s | **Removed** | Owner: no passive XP |
| Boss lair | 260 by share of the fight | **300** to the squad that lands the kill, nothing to the others | Same kill rule as every monster |
| The Watcher | damage XP | **250** to the last hit's squad | The mid-game prize at the Heart |
| Blight monsters | damage XP | **8** (Skitter) and **20** (Watcher) per kill | Not worth farming |

### 2.5 Level pace (targets; the sim gate in the task list asserts them)
On the zone spec's clock: the Blight closes at 2:00, 4:00, 6:00, 8:00 and 10:00; Sealed Lair 2:00, Heart wakes 4:00, Heartspark 5:15, final seat 10:00. XP to reach a level is the new curve in section 6.1 (L4 290, L6 640).

| Squad | 2:00 | 4:00 | 5:15 | 8:00 | 10:00 |
|---|---|---|---|---|---|
| Quiet rim drop, then moves inward | L3 | L4-5 | L5-6 | L7 | L8 |
| Mid drop, uncontested | **L4** | L5 | **L6 (ultimate)** | L7-8 | L8-9 |
| Hot zone, won the fight | L5 | L6-7 | L7 | L8-9 | L10 |
| Hot zone, lost, revived and ran | L2 | L4 | L5 | L7 | L8 |
| Crown, uncontested (rare) | L5 | L6-7 | L7 | L8-9 | L9-10 |
| Never kills anything | L1 | L1 | L1 | L1 | L1 |

Rules of thumb for tuning: nobody has an ultimate before 2:30; a squad that plays camps has it for the Heartspark fight; the hot-zone winner is one to two levels up at 4:00, never three. What a level gives is in section 6.1.

### 2.6 Hot drop vs quiet camp, side by side
| | Hot zone | Quiet mid region | Quiet rim |
|---|---|---|---|
| XP on the table | 560 + about 255 per squad wiped | 360 | 230 |
| Loot | Camp Chief gear +1 step, chests +1 rarity | 1 orb, 1 gear piece, armor 125 | Armor 100, an orb half the time |
| Risk | 2-3 squads land there | A second squad on the Great Camp | Almost none, but the Blight arrives first |
| Ultimate at | about 3:00 | about 5:00 | about 5:15 |

### 2.7 On the drop map and the minimap
- Camps become a `SpawnPlan` category `camp`, **announced** (live for everyone from 0:00, like vaults and lairs). Icon: a campfire with 1, 2 or 3 flames for the size, a small crown on a Camp Chief. Cleared: dim. Coming back: dim with a filling ring.
- The drop map (the planning phase, `DropSquad.PLAN_T` 8 s to **12 s**) adds one line under each region's name: "3 camps: to level 4" (the sum of its first-clear XP turned into a level), and the hot zone's ring reads "HOT: bigger camps, better loot". The legend gets one row: "Camps: clear them to level up".
- First three matches only (`first_match_guide.gd`): the single highlighted prompt is "Pick a camp and ping it", with the nearest mid region's Small Camp pulsing. After landing: "Clear the camp to level up", then it points at the next camp.
- Minimap: the same icons inside its range, nothing else new. No new HUD group (clarity rule: about 5).
- From the air: every camp sends up a thin smoke column (1, 2 or 3 strands by size, orange in the hot zone), visible within 160 m during your drop and gone 5 s after you land. That is what you steer at.

### 2.8 Bots
- A bot squad leader with no human ping picks a **camp**, not a spot: hot zone first at the existing 35% (if no other squad is headed there), else a rim or mid region no more than one other squad has pinged; it pings that region's Small Camp (rim) or Camp (mid). Never two bot squads on one region; bot squads take the Crown at most once a match.
- After landing they clear smallest to biggest inside their region, skip a camp a stronger squad is fighting on, and leave a camp when the Blight is within 40 m. From 2:00 they follow the Limited Way Outs objectives, and detour to a live camp within 60 m whenever they are at or below the pace level (section 6.8).
- Bots Hard Land half the time when their landing camp is live. Par: bot squads average L3.5 to L4.5 at 2:30, the same band as the human targets. How bots farm, fight, rotate and steal by level is section 6.8.

### 2.9 Boki wisps
- 0.24.4: nothing new to build. The wisp's carry passive is always on, which is what makes a Small Camp safe at level 1; the Bond meter still fills from the damage you deal to camp monsters.
- Later, when the summon button ships (DECISIONS 11-09): clearing a camp refunds summon cooldown (Small 10%, Camp 20%, Great 35%), so a squad that farmed arrives at its first fight with the Boki ready. And two of the five rare Boki spots move inside Great Camps as "guarded" (a paw on the icon): clear the camp, the Boki wisp floats free, scan it. Both are `[early]` tasks.

### 2.10 What the Blight zone redesign must keep (job 20261110-171438-a4)
Camps feed the phase before and during the first shrinks. Handed to that spec as constraints, in order of weight:
1. No rim camp is covered before **1:45**, no mid camp before **4:00**, the Crown's last. (The zone spec rev 2 does: the first close starts at 2:00 from a 184 m ring.)
2. The first shrink should take the rim between about 1:45 and 4:00: that is the push that turns "farm" into "rotate and fight".
3. `Camps` needs one question answered by the zone: "is this point safe for the next 60 s". It gates comebacks and bot camping.
Checked against the zone spec rev 2 (31c118f4f): the far rim goes 2:15 to 2:45, the lean-side rim about 4:10, the mid ring 4:10 to 6:20, the Crown from 8:50. All three hold. If its beats move, only the pace table in `xp.json` (section 6.2) and the clock columns in 2.5 move; the camp numbers stand.

## 3. The drop
All numbers move to `content/rules/drop.json` (read by `DropFeel`; the `Hunter` and `Match` constants they replace are deleted).

### 3.1 Height, glide, dive
| | Today | New | Result |
|---|---|---|---|
| Ship height (`SHIP_Y`) | 70 m | **110 m** | The 305 m map reads as a map from up there |
| Ship speed | 11 m/s (33 s to cross the 2x map) | **14 m/s** (26 s) | Less waiting |
| Launch: speed / lift / lock | 14 m/s, 6 m/s, 2.5 s | **18 m/s, 8 m/s**, 2.5 s | A bigger arc out of the hatch, 45 m carried |
| Dive: fall / flat speed | 13 / 14 m/s | **20 / 16 m/s** | 110 m to the canopy in 5.0 s; 80 m of reach |
| Canopy: sink / flat speed | 4.2 / 8 m/s | **5.0 / 9 m/s** | 22 s if opened at the top, 198 m of reach |
| Canopy opens by itself at | 8 m | **10 m** | Same last-second catch at the higher speed |
| Flare | below 4 m, down to 2.2 m/s | unchanged | |

- Straight down in a dive: about **7 s** (5.0 dive + 2.0 under the canopy). The far glide: up to **22 s**. So the hot camp under the ship costs 7 s and a far quiet camp costs 15 to 22 s: that time is the price of quiet.
- Reach rule for the map check: every camp lies within 190 m (flat) of every possible ship line, so no camp is ever out of reach.
- `DropReticle` keeps projecting with the same numbers (it reads the same file).

### 3.2 What you see and hear on the way down
- **Camera:** on the dive the view widens 10 degrees over 0.4 s and tilts 12 degrees further down, so the ground and the camp smoke fill the screen; it eases back as the canopy opens.
- **Cloud layer at 60 m:** one scrolling translucent sheet. Passing through it is 0.3 s of haze and a whoosh, then the map snaps into view. This is the cheapest thing that makes height read.
- **Speed:** wind streaks at the screen edges that scale with fall speed (one full-screen shader pass, local player only, no particles); the wind loop's pitch rises from 0.8 to 1.3 with speed; a sharp canopy snap when it opens.
- **Squad:** the existing formation is unchanged; each squadmate trails a thin team-colour ribbon in the dive (one trail mesh each) so you can read where other squads are going.

### 3.3 Landing
Two landings, chosen by what you do in the last 10 m.

| | Soft landing (default) | **Hard Landing** (hold the dive key through the last 10 m) |
|---|---|---|
| How | The canopy opens at 10 m, flares at 4 m | No canopy. You hit at 20 m/s |
| Gameplay | None. You can act at once | A 6 m shock ring: monsters inside are **staggered 1.5 s and take 30 damage** (kills a Puffbomb, leaves a Skitter on 4). Hunters are untouched (owner call 2). You are slow (half speed, no attacks or abilities) for **0.4 s** |
| Camera | A 0.25 m dip, back in 0.2 s | A 0.5 m dip that springs back in 0.22 s, plus 60 ms of hit-stop (yours only). One kick, not a shake: the no-self-shake rule (item 50) stands |
| VFX | Dust (14 particles). **No ring** | The ring at its true 6 m radius in team colour for 0.35 s, 36 dust particles, 6 debris chunks, a 2 m crack decal for 4 s |
| Sound | The existing thud | A low boom and falling grit, heard to 60 m; rivals within 60 m get the existing minimap sound ping |

- Why it earns a gameplay effect: it makes "land on the camp" literal. A Hard Landing on a Small Camp starts the fight half won; on a Great Camp it buys the opening burst; onto a camp another squad is fighting it is the steal. The price is noise and 0.4 s.
- Rule fix that comes with it: today every landing draws two rings (`DropFeel.land`), against DECISIONS ("no rings on landings; a ground ring means gameplay"). The soft landing loses them; the Hard Landing's ring is its real area.
- Only the opening drop can Hard Land. Mid-match glider dives are unchanged.

### 3.4 Perf budget (DECISIONS 11-08 budgets: under 4k particles, 2 shadow lights, 1500 draws)
| Thing | Cost | Bound |
|---|---|---|
| Camp smoke columns | 28 unshaded quads, no light, no particles | Drop phase only; freed 5 s after the local landing |
| Cloud layer | 1 quad, local player only | Freed on landing |
| Wind streaks | 1 screen pass | Dive only; off at very low |
| Hard Landing | 1 ring mesh, 36 pooled particles, 6 chunks without physics, 1 decal | Worst case on screen: 3 squads = 9 landings = 324 particles, 0 lights |
| 9 more camps | 20 more monsters (79; 82 with the hot zone) | Far monsters already step at 20 Hz (`Mob._far_step`); comebacks never raise the total above 85 alive |
| Camp reward bundles | Fewer pickups than today's per-monster rolls | One merged drop per camp |

Gate: `--perf-bench` on the GPU box before and after, average within +0.5 ms and p99 within +3 ms of the base; `--perf-budget-check` green.

## 4. What ships when
- **Base (decided):** the 0.24.4 work sits on the release candidate plus the 2x map. A test merge of `origin/ext/map-2x-0245` into `origin/ext/release-integ-0244-fix` on 11-10 was clean, so task W0 makes `ext/early-base` from the two and every other task starts there. Alternative if the 2x map is held back: the same tasks run on the release candidate alone with today's camps; only the map task (W1 map) waits, because the camp counts are data.
- **Waves:** W0 base (1 h), W1 levels core + map + drop (3 h, three workers), then camps core on top of levels core (3 h), W2 Hard Landing + map display + level HUD + steals + bots (4 h, five workers), W3 one gate (3 h). Each task names the branches it needs on origin before it starts.
- **0.24.4 (tasks `[early-0244]`, about 14 h):** the level rules (kill XP, sharing, catch-up, no trickle); the XP bar, nameplate level colours and steal callouts; the camps module (sizes, reward, one comeback); 28 camps on the 2x map; camps on the drop map and minimap with the region line and smoke; bots; the drop numbers, dive view and cloud layer; the Hard Landing; one verify gate (pace sim, perf, shots).
- **Later (tasks `[early]`):** a boss boon for the squad that lands a boss kill; wisp summon refund; guarded Boki in Great Camps; Camp Chief art and per-region camp dressing; a pace readout on the results screen for tuning; a retune after the owner's first playtest.

## 5. Risks
| Risk | Guard |
|---|---|
| The hot-zone winner snowballs | Section 6.5: monsters pay less above the pace, a knock on a higher-level Hunter pays more, growth halves from level 7; the sim caps the lead at two levels at 4:00 |
| With no free XP a beaten squad never recovers | Section 6.5: up to +75% monster XP behind the pace, comeback camps, the gap bonus on knocks, the revive floor; the sim asserts a squad wiped to one Hunter at 2:00 is within 2 levels of the median at 6:00 |
| Last-hit steals feel unfair | Section 6.6: the same low-health tell for everyone, a reel that lets the fighting squad pick its burst, a named callout with a direction, and the bundle sits in the camp where the thief must come and get it |
| Every squad lands quiet and nobody fights early | The rim is 60 XP short of L4 and is taken by the Blight first; the Sealed Lair opens at 2:00 |
| Clearing camps is a chore | Small Camp 10 s, a full region about 90 s including the walk; the Hard Landing opens the first one |
| Net: clients grant their own XP | The clear is decided per client from monsters it already sees die; if camp membership cannot be derived without a sync change, bump `Net.VERSION` (the 2x map already takes it to 0.24.5) |
| Blight spec lands with different shrink times | Section 2.10: only the clock columns move |

## 6. Levels as strategy
Owner orders 11-10 ~12:45 PM (level caps, XP by match point, XP per monster, catch-up: "level management is a part of the game") and ~1:15 PM (the genre's model, our names: no passive XP, no XP for damage, XP is a kill reward for the last hit and nearby squadmates, steals are real and readable, a clear XP tracker bottom-left). One answer for each; alternatives are named once.

The whole rule in three lines: **you level by killing, together.** Monsters pay the squad that lands the last hit; Hunters pay the squad that knocks them. Nothing else pays, so every level a squad has was a choice it made: which camp, which fight, when to leave.

### 6.1 The cap, the curve, what a level gives
Cap **10** (kept: the abilities, the weapon path and the ultimate ranks are built on it; alternative, 15 smaller levels, means redoing all three for no new decision).

| Level | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|
| Total XP | 60 | 160 | 290 | 450 | 640 | 860 | 1,110 | 1,390 | 1,700 |
| This step | 60 | 100 | 130 | 160 | 190 | 220 | 250 | 280 | 310 |
| Health / ability power, total | +6% / +5% | +12 / +10 | +18 / +15 | +24 / +20 | +30 / +25 | +33 / +27.5 | +36 / +30 | +39 / +32.5 | +42 / +35 |
| Also | Weapon step 1 | | Weapon step 2 | | **Ultimate**, weapon step 3 | | Weapon step 4 | **Ultimate rank 2** | Weapon capstone |

- The curve is today's, moved down by 10 so the first Small Camp is exactly level 2: the first kill of the match teaches the rule.
- **Every level:** one ability point (you start with one), +6% health and +5% ability power (half that from level 7). Points buy ranks in the secondary, the dash and the Boki ability (3 ranks each; each rank past the first is a 10% shorter cooldown and a stronger effect) and the ultimate (2 ranks, opened at levels 6 and 9). Ten points for eleven ranks: at the cap you still leave one out.
- **Even levels:** the next step of your weapon's path (five steps, per hero, `content/rules/weapon_path.json`, unchanged).
- **How a gap feels:** two levels is about 12% health, 10% ability power, one weapon step and two ability ranks. One level is a nudge, two is an edge, three is "do not take this fight even". The spikes are **2, 4, 6 and 9**: a squad that just hit 6 has ultimates and the squad at 5 does not.
- Growth halves from 7 on purpose: late levels are worth having, not worth more than aim.
- All of these numbers are unchanged from the release candidate except the curve. They move into the one rules file (6.9).

### 6.2 The pace: what a squad should be, and where XP comes from
The match has a **pace level**: the level a squad that plays camps and objectives well has at that minute. It is one table in the rules file, the same for everyone, read off the match clock. It drives catch-up (6.5), the bots (6.8) and the sim gate.

| Pace level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|
| From | 0:00 | 0:45 | 1:45 | 2:45 | 4:00 | 5:15 | 6:40 | 8:10 | 10:00 |

| Beat (zone spec rev 2) | A squad should be | Where the XP is | The choice |
|---|---|---|---|
| Drop to 2:00, the Blight's first close | 3 (rim) to 4 (mid) | Your region's first clears: 230 to 360. Nine tenths of all XP earned so far is camps | Which region; clear it all or leave early for the Crown |
| 2:00 to 4:00, far rim falls 2:15 to 2:45 | 5 at 4:00 | The Sealed Lair boss (300, no steals once the gate seals), the next ring's camps, the first knocks (85 to 100 each) | Lair for the squad that wants a level and a half in one kill; camps for the squad that is behind |
| 4:00 to 6:00, the Heart wakes | **6 at 5:15**: the ultimate for the Heartspark fight | Comeback camps one size up and Camp Chiefs (260), the Watcher at the Heart (250), knocks | Return to your region for the comebacks, or contest the Watcher and risk the steal |
| 6:00 to 8:00, the Uplink | 7 to 8 | Knocks (130 to 160 each), the last comebacks (none after 7:00), the Glimmerkin (120) | From here Hunters are the main XP. A squad at 6 hunts a squad at 8 only as a third party |
| 8:00 to 10:00, the Crown | 8 to 9 | Knocks only; a few Blight monsters at 8 each | No farm left. Your level is what you bring to the end |
| 10:00 to 12:00, the final seat | 9; 10 only for a squad that won two fights or more | Knocks | |

- Over a whole match a squad at the pace earns about 55% of its XP from camps, 30% from knocks, 15% from bosses and the Watcher. Before 2:30, at least 85% is camps.
- A squad that never kills anything is level 1 at 12:00. There is no floor from time.
- Way-out quests, the Heartspark, chests, perk orbs and scanning Boki pay **no** XP: they pay what they already pay (the way out, loot, perks, Boki). One currency per reward.

### 6.3 XP table: every monster
The XP of one kill, to each Hunter who gets it (6.4). Rarity multiplies it: Uncommon x1.2, Rare x1.4, Elite x1.7 (camp monsters are common, bar the Chief).

| Monster | XP | Where | Note |
|---|---|---|---|
| Skitter, Puffbomb, Spitter | 30 | Camps: the "small" ones | Two make a Small Camp: 60, level 2 |
| Shrubling | 15 | Hidden among bushes | It carries a chest key; the key is the prize |
| Sentinel | 50 | The Camp's third monster | |
| Brute | 100 | The Great Camp's big one | Prize monster (6.6) |
| Camp Chief (an Elite Brute) | 170 | Hot zone and comeback Great Camps | Prize monster |
| Glimmerkin | 120 | Roams and flees, from 6:00 | Prize monster; its gems as today |
| The Watcher | 250 | The Heart, from about 4:48 | Prize monster; its treasure and three perk orbs as today |
| The Stone Colossus, Stormcoil, the Brood Mother | 300 | Boss lairs | Prize monsters. To the squad that lands the kill, its members inside the lair. The old shares for other squads (half, a fifth) go |
| Lair guards | Their kind's XP | Lairs | |
| Blight Skitter / Blight Watcher | 8 / 20 | Inside the Blight | Never worth the trip |
| Ward Stone, anything a boss or monster summons | 0 | | No farming a boss's brood |

| Camp | Monsters | XP | Hot zone or comeback |
|---|---|---|---|
| Small Camp | 2 small | 60 | becomes a Camp |
| Camp | 2 small + Sentinel | 110 | becomes a Great Camp |
| Great Camp | Brute + 3 small | 190 | becomes a Camp Chief's camp |
| Camp Chief's camp | Chief + 3 small | 260 | |

`camps.json` holds no XP numbers: a camp's XP is the sum of its monsters from this table, and `Camps.region_xp` adds up what is alive. Supply on the 2x map is unchanged: 12 x 60 + 9 x 110 + 7 x 190 = 3,040 on first clears.

### 6.4 Who gets it: the last hit, and the squad around it
- **Monsters:** the Hunter who lands the last hit gets the XP. So does each squadmate, alive or downed, within **30 m** of the kill, in full (not split: a trio that stays together levels together, a split squad levels apart). A Boki's or a summon's last hit is its Hunter's. A monster that dies to the Blight, a fall or another monster pays nobody.
- **No XP for damage.** A squad that did 99% of a Brute and lost the last hit gets nothing from it. That is the steal, and 6.6 makes it fair to read.
- **Hunters:** a knock pays **40 + 15 x the victim's level** (85 at level 3, 130 at 6, 160 at 8) to the knocker and each squadmate within 30 m of the victim, bent by the gap (6.5). The knock is credited as today. Finishing a downed Hunter pays nothing more, and a Hunter pays knock XP at most once every 45 s (no farming a revive).
- **Hitting Hunters pays no level XP.** It builds **armor**, exactly as today: damage to Hunters at full rate, to monsters at a third, 140 for a knock, tiers at 220 / 560 / 1,000 / 1,600. Two tracks with two jobs: armor rewards trading shots, levels reward finishing things.
- **Dead Hunters earn nothing** until they are back. Downed ones in range do.

### 6.5 Catching up, and not running away
No XP comes from time, so catch-up is built from things you do.

| Lever | Rule | Number |
|---|---|---|
| **Pace bonus** (owner call 3) | Monster XP is multiplied by how your level sits against the pace level (6.2). Monsters only, never knocks | 3 or more behind x1.75; 2 behind x1.5; 1 behind x1.25; level or 1 ahead x1; 2 ahead x0.75; 3 or more ahead x0.5 |
| **Gap bonus on knocks** | Knocking a Hunter above your level pays more; farming one far below pays less | +30 per level the victim is above you; half XP when the victim is 2 or more below you |
| **Comeback camps** (2.3) | A cleared camp returns once, one size up, 150 s later, none after 7:00 | A beaten squad's region is worth more the second time: 230 becomes 410 on the rim |
| **Revive floor** | A Hunter brought back (revive box or beacon) keeps level, XP, ability ranks, weapon steps and armor tier, and is lifted to 2 levels under their squad's highest living member if they were lower | No XP is ever lost to a down or a death. Gear follows today's revive rules |
| **Finite farm** | First clears hold about 300 XP a squad; one comeback each; the Blight eats the rim first | The leader cannot farm its way further ahead: past level 5 the XP is other Hunters |
| **Soft cap** | Health and ability growth halves from level 7; steps cost more each level | 8 against 10 is a smaller edge than 3 against 5 |

- Worked case: a squad wiped to one Hunter at 2:00, level 2. The two come back at the beacon at level 2. At 3:00 the pace is 4, so they are 2 behind: their old Camp, back as a Great Camp (190), pays each of them 285: level 2 to level 4 in one clear. By 6:00 they are within 2 of the median, with an ultimate one beat late. Knocking one level 6 Hunter at level 4 pays 130 + 60 = 190.
- Limits the sim asserts: the top squad is at most 2 levels above the median squad at 4:00 and at most 3 at 8:00; a squad behind by 2 at 3:00 gains on the leaders by 6:00 if it clears two camps.
- What we do **not** do: no XP loss on death, no shared squad level, no rubber-band on knocks beyond the gap bonus, no hidden rules. Every lever above is shown on screen (6.7).

### 6.6 Steals: readable, and answerable
A steal is a last hit by a squad that did not do most of the damage. It is allowed on everything and **called out on prize monsters**: the Brute, the Camp Chief, the Glimmerkin, the Watcher and the three lair bosses.

- **What the thief takes:** the monster's XP for their squad in range, and whatever the kill carries: the camp's reward bundle if it was the camp's last monster, the Watcher's treasure and orbs, a boss's drops. Those drops are the last-hit squad's alone for **8 s**, then anyone's.
- **The tell (everyone sees it):** at 25% health a prize monster's health bar gains a pulsing band, the **kill window**, and it cries out. Both squads know the next burst decides it.
- **The reel:** the first time a prize monster drops under 25% it reels for **1.2 s**: it stops attacking and stands open (the existing stagger). That is the fighting squad's planned burst window: hold abilities at 30%, push it over, spend everything in the reel. A thief has to already be in range and guess the moment.
- **The callout:** the thief's squad sees "Stolen! +170 XP". The robbed squad sees "*Name* took the Camp Chief" in the thief's squad colour with an arrow toward them for 3 s. Squads within 60 m get a feed line. Small monsters get no callout: just no XP pop where you expected one.
- **Counterplay, in order:** (1) check the nameplates before you cross 30%, and clear or zone the third party first; (2) burst in the reel; (3) hold the ground: the bundle is on the floor where you stand, the thief must walk in to take it, and after 8 s it is yours again; (4) knock the thief: a knock pays more than most monsters and they are usually alone and ahead of their squad; (5) in the Sealed Lair the gate seals behind the squads inside, so nobody arrives late.
- 0.24.4 adds no new buffs. Later (`[early]` boss boon): the squad that lands a lair boss or the Watcher also gets a 120 s boon (+8% damage, +8% move speed, visible on their nameplates, passed on to whoever knocks them), which makes those last hits the biggest in the match.

### 6.7 How levels are shown
| Where | What | Detail |
|---|---|---|
| **Bottom-left vitals** (`hud_vitals.gd`) | Your level on the coin, and a gold **XP bar** to the next level under the armor strip, the full 318 px width | Replaces the thin ring round the coin. On every gain the bar's new part shows lighter and settles in 0.4 s, and "+60" rises from its end and fades in 0.8 s. At 10 the bar is full and reads MAX. The level-up burst stays as it is |
| By the bar | The pace tag | "Catch-up +25%" in green when monsters pay you more, "Slow -25%" in grey when they pay you less, nothing at par. This is the farm-or-fight light: green says farm, grey says go and hunt |
| At the kill | One gold "+30 XP" floater | Yours only, merged when several land within 0.5 s. Squadmates' gains are not shown |
| Squad rows (`team_boki.gd`) | Each squadmate's level badge (there today) | A broken-link mark on a squadmate more than 30 m away: you are not sharing XP |
| Enemy nameplates (`hud_plate.gd`) | The level badge (there today), now coloured by the gap to you | Grey: 2 or more below you (pays half). White: within 1. Amber: 2 or 3 above. Red: 4 or more above. Amber and red are worth more to knock and worse to fight |
| Full map | Hover or ping a camp: "Great Camp, 190 XP" after your pace bonus; a region: "2 camps left, 300 XP" | The planning number for "rotate or stay" |
| Results screen (later) | XP by source, per minute | Camps, knocks, bosses |

No new HUD group: the bar lives in the vitals block, the colours on badges that exist.

**Reading it as a player:** green tag and white or amber plates around you: farm, and avoid the amber squad unless you can third-party it. No tag: play the clock (Sealed Lair at 2:00, the Heart at 4:00). Grey tag: camps are a waste of your time, you are the strongest squad nearby, go and take a fight before the others catch up. One short of 6 at 5:00: one more Camp before the Heart is worth being late. A link mark on a squadmate: regroup before the next kill.

### 6.8 Bots
Bots use the same XP path as Hunters: no bot-only XP, the same last hit, range, pace bonus, gap bonus and revive floor.
- **Farm:** a bot squad at or below the pace level detours to a live camp that is safe for 60 s and within 60 m, smallest first; above the pace it does not.
- **Fight:** it avoids a squad 2 or more levels above it unless that squad is already fighting; it presses a squad 2 or more below. A squad one short of an even level or of 6 prefers a camp to a fight.
- **Steal:** a bold bot within 25 m of a prize monster in its kill window tries the last hit 35% of the time. A bot squad that has seen a rival within 30 m in the last 5 s holds its burst at 30% and uses it in the reel.
- **Stay together:** bots keep within 25 m of their squad while clearing, so they share.
- **Rotate:** the zone spec's zone sense, unchanged.

### 6.9 One rules file
`content/rules/xp.json`, read only through `scripts/match/xp_rules.gd`. It holds everything in this section; `content/rules/level_growth.json` folds into it and is deleted, `Hunter.XP_TO`, `ULT_AT` and the inline 0.6 / 0.35 / 90 / 260 / 1.2 go.

```json
{
  "cap": 10,
  "to_level": [0, 60, 160, 290, 450, 640, 860, 1110, 1390, 1700],
  "ult_at": [6, 9],
  "growth": {"hp": 0.06, "ap": 0.05, "half_from": 7, "half_k": 0.5},
  "share_r": 30.0,
  "mob": {"skitter": 30, "bomber": 30, "spitter": 30, "shrubling": 15, "sentinel": 50, "brute": 100,
          "glimmer": 120, "warden": 250, "colossus": 300, "serpent": 300, "brood": 300,
          "bl_skitter": 8, "bl_warden": 20, "ward": 0},
  "rarity": {"common": 1.0, "uncommon": 1.2, "rare": 1.4, "elite": 1.7},
  "knock": {"base": 40, "per_level": 15, "per_level_above": 30, "below_gap": 2, "below_k": 0.5, "repeat_s": 45},
  "pace_at_s": [0, 45, 105, 165, 240, 315, 400, 490, 600],
  "pace_mult": {"-3": 1.75, "-2": 1.5, "-1": 1.25, "0": 1.0, "1": 1.0, "2": 0.75, "3": 0.5},
  "revive_floor": 2,
  "steal": {"prize": ["brute", "glimmer", "warden", "colossus", "serpent", "brood"],
            "window": 0.25, "reel_s": 1.2, "reserve_s": 8.0, "callout_r": 60.0}
}
```

- A monster missing from `mob` fails the check, so a new monster cannot ship without an XP number.
- Net: each client grants XP to its own Hunters from the monster deaths and knocks it already sees, with the killer the death already names; the level is already synced. Bump `Net.VERSION` only if a sync field has to be added (the reel and the bundle's owner are the two candidates).
- Levels are match flow and combat: the levels task writes `docs/decisions/NNNN-levels-kill-xp.md` first.

