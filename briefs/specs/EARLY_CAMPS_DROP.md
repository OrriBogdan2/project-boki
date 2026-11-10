# Early game = camps, and a bigger drop (spec + build list)

Job 20261110-171956-a4 (design lead, docs only). Owner order 11-10 ~12:30 PM EST, for 0.24.4.
Read against: release candidate `origin/ext/release-integ-0244-fix` ec3c9dafb, the 2x map `origin/ext/map-2x-0245` 2bd777c00, `briefs/specs/LIMITED_WAY_OUTS.md` (12:00 match, four seats), DECISIONS.
Build list: `briefs/specs/EARLY_CAMPS_DROP_TASKS.jsonl`.

## Owner summary (10 lines)
1. Today the answer is no. A camp is worth almost nothing: clearing the biggest one pays less XP than standing still for 90 seconds. That is why it feels random.
2. New rule: you level by clearing monster camps. Every camp is on the drop map from the first second, with its size shown, so the first decision is "which camps do we land on".
3. Three sizes: Small Camp, Camp, Great Camp. The whole squad gets the XP when the last monster dies, no matter who hit what.
4. The 2x map gets 28 camps (19 today): quiet corners are small and safe, the middle ring is the standard drop, the Crown is the richest.
5. The hot zone's camps are one size bigger. Land there and win: your ultimate is ready about 90 seconds before a quiet squad's.
6. XP for poking things is nearly gone, and the free XP over time is cut by 80%. Camps, knocks and bosses are what level you.
7. A quiet squad is level 4 when the Blight first bites and has its ultimate (level 6) for the Heart fight at about 5:00.
8. A cleared camp comes back once, one size bigger, after 2.5 minutes, so there is a reason to come back or to steal.
9. The drop: the ship flies at 110 m (70 today), the dive is half again as fast, you punch through a cloud layer, and the camps send up smoke you can steer at.
10. New: hold the dive all the way down for a Hard Landing. It staggers and hurts the monsters you land on, and everyone nearby hears it.

## Owner calls (3, each with the default we build)
| # | Call | Default (built unless you say otherwise) | Alternative |
|---|---|---|---|
| 1 | Ship height | **110 m**, about 7 s straight down in a dive, 22 s if you glide the whole way | 140 m: grander, but 9 s and 28 s; one number in `content/rules/drop.json` |
| 2 | Hard Landing hits | **Monsters only** (stagger 1.5 s, 30 damage). Hunters are never hurt or staggered by a landing | Also shove Hunters 2 m: funnier, but landing on a squad becomes the meta |
| 3 | Free XP over time | **Kept tiny** (0.25 XP/s: 180 XP, two levels, over a whole match) so a revived player is never stuck | Remove it: purer, but a squad that loses its camps has no floor |

## 1. What is wrong today (numbers from the release candidate)
XP to reach a level (`hunter.gd` XP_TO): L2 70, L3 170, L4 300, L5 460, L6 650 (ultimate), L7 870, L8 1120, L9 1400, L10 1710.

| Source today | Pays | Problem |
|---|---|---|
| Trickle (`hunter.gd` ~1918) | 1.2 XP/s = 72 a minute, to everyone | Standing still reaches L4 at 4:10 and L6 at 9:00. It is the biggest source in a quiet match |
| Damage to monsters (`match.gd` ~1783) | 0.35 per damage, to the one who dealt it | A Great Camp (Brute 170 + Sentinel 70 + Spitter 44 + Skitter 34 = 318 hp) pays 111 XP in total, split by who hit what: about 37 each. A Small Camp pays 24 |
| Damage to Hunters | 0.6 per damage, to the dealer | Poke trades level you; who gets it depends on who landed the stray shot |
| Knock (`match.gd` ~1850) | 90 to the knocker | Last hit takes it all |
| Boss lair (`lairs.gd` ~712) | 260 shared by share of the fight | Fine; kept |

Camps exist (`world.camp_spots`, kinds light/normal/heavy, spawned in `Match._spawn_mobs`, 19 on the 2x map) but pay nothing on a clear, drop loot by per-monster dice, are not on the map, and come back only in the cut rolling mode (`rolling.gd` CAMP_RESPAWN).

## 2. Camps
One new module, `scripts/match/camps.gd`, owns camps: it takes over `_spawn_mobs` (out of `match.gd`), the clear, the pay, the reward and the comeback, and deletes the rolling copy. All numbers in `content/rules/camps.json`. The genre's structure, our names and numbers.

### 2.1 Sizes
| Size (player text) | Layout kind | Monsters | XP to each squadmate | Reward, dropped once where the last monster fell | Clear time, 3 Hunters at L1-2 |
|---|---|---|---|---|---|
| **Small Camp** | light | 2 small (Skitter, Puffbomb, Spitter) | **60** | Armor 25 | 8-12 s |
| **Camp** | normal | 3: two small + a Sentinel or Spitter | **110** | Armor 50, a perk orb 50% of the time | 15-25 s |
| **Great Camp** | heavy | 4: the region's Brute + 3 | **190** | Armor 50, one perk orb (always), one gear piece at the region's rarity | 30-40 s |
| **Camp Chief** (hot zone and comeback Great Camps) | heavy + chief | A Great Camp whose Brute is one rarity higher | **240** | Great Camp's, with the gear piece one rarity step up | 40-50 s |

- **Pay rule:** XP is paid when the last monster of the camp dies, in full to every squadmate of the killer who is alive (or downed) within 30 m. Not split, no last-hit, no damage share. One toast: "Camp cleared  +110 XP". Solo wanderers of the squad more than 30 m away get nothing: stay together.
- **Steal rule:** the squad that lands the last kill gets the pay. Third-partying a half-dead Great Camp is a real play, and the Hard Landing (section 4) is the tool for it.
- **Loot rule:** camp monsters stop rolling their own drops (the Brute's 50% orb, 25% valuable, the 12% and 35% seeds in `match.gd` ~2236). The camp pays one fixed bundle, merged in one spot (the perf order: fewer, bigger drops). Monsters outside camps (the Blight's, lair broods, elites) keep theirs.
- **Region flavour:** which monsters is still the region's biome table (`BiomeRun.camp_comp`); the size fixes the count and the big one.

### 2.2 How many, where (2x Hollow Crown, 10 trios)
28 camps (19 today), 79 camp monsters (59 today; 82 when the hot zone makes its camps bigger). Sizes follow how close a region is to the centre, because the Blight closes on the Heart: the rim is eaten first, the Crown last.

| Ring | Regions | Camps per region | First-clear XP each | Role |
|---|---|---|---|---|
| Rim (corners) | Larkhollow, Highwatch, Duskmoor, Saltmere | 2 Small + 1 Camp | 230 (L3) | The quiet drop. Safe, small, and the first land the Blight takes, so it forces a move inward |
| Mid | Frostgate, Cinder Steps, Stormbreak, Thornwood | 1 Small + 1 Camp + 1 Great | 360 (L4) | The standard drop. One squad levels fully; two squads fight over the Great Camp |
| Crown | The Crown (not the Gaols: those are lairs) | 1 Camp + 3 Great | 680 (L6) | The greedy drop: most XP, most squads, the Sealed Lair next door at 2:00 |
| Hot zone | One non-Crown region per match (existing `HotZone`) | Every camp one size up; Great becomes Camp Chief | Rim 410, Mid 540 | The fight drop. Loot is already +1 rarity there |

- Placing rules for the map task: camps in a region at least 30 m apart and at most 70 m (a clear path, small to great); at least 14 m from a train halt and 20 m from a lair gate or quest seat; each within 12 m of cover; the Great Camp nearest the region's inner edge (it pulls squads the way the Blight will push them).
- Supply check: first clears hold 3,040 squad-XP for 10 squads, about 300 each (L4). There is not enough for everyone to be L5 off camps: the rest comes from knocks, comebacks and the lair, which is the point.

### 2.3 Coming back
- A cleared camp comes back **once**, **150 s** after its clear, **one size up** (Small to Camp, Camp to Great, Great to Camp Chief), if no Hunter is within 30 m, the spot is outside the Blight and will still be outside it for 60 s. No comebacks after 7:00: the end is about Hunters.
- The map shows it: a cleared camp is a dim icon with a ring that fills until it returns (to a squad that has been within 60 m of it since the clear; others still see it live until they get eyes on it).
- Why once and bigger: it pays a squad for holding or returning to its region mid-game (L6 for the Heart fight), gives a beaten squad something to catch up on, and caps the monster count.

### 2.4 XP sources after the change
New rules file `content/rules/xp.json`, read by a small `scripts/match/xp_rules.gd`; the inline numbers in the god files go.

| Source | Today | New | Why |
|---|---|---|---|
| Camp clear | 0 (only damage XP, 24-111 in total) | 60 / 110 / 190 / 240 to each squadmate | The core |
| Damage to monsters | 0.35 per damage | **0** | Replaced by the clear |
| Damage to Hunters | 0.6 per damage | **0.15** per damage | Poke no longer levels; a real fight still ticks |
| Knock | 90, knocker only | **40 + 15 x the victim's level**, to every squadmate within 30 m | Shared; killing a levelled squad is worth a camp each (victim L3 = 85, a wiped trio = 255 each) |
| Trickle | 1.2 XP/s | **0.25 XP/s** | A floor only: 180 XP over 12:00 |
| Boss lair | 260 by share | Unchanged | |
| Blight monsters, wanderers | damage XP | **8 per kill**, shared the same way | Not worth farming |

### 2.5 Level pace (targets; the sim gate in the task list asserts them)
Assumes Limited Way Outs' clock: Blight starts closing 1:30, Sealed Lair 2:00, Heart unlocks 4:00, Heartspark 5:15, final 10:00.

| Squad | 1:30 | 2:30 | 4:00 | 5:15 | 10:00 |
|---|---|---|---|---|---|
| Quiet rim drop, then moves inward | L3 | L3-4 | L5 | L6 | L8-9 |
| Mid drop, uncontested | L3 | **L4** | L5 | **L6 (ultimate)** | L8-9 |
| Hot zone, won the fight | L4 | L5-6 | L7 | L7-8 | L10 |
| Hot zone, lost and ran | L2 | L3 | L4 | L5 | L7 |
| Crown, uncontested (rare) | L4 | L6 | L7 | L8 | L10 |
| Never touches a camp | L1 | L1 | L1 | L2 | L2 |

Rules of thumb for tuning: nobody has an ultimate before 2:30; a squad that plays camps has it for the Heartspark fight; the hot-zone winner is one to two levels up at 4:00, never three. `LevelGrowth` (6% health and 5% ability power a level) and `WeaponPath` are unchanged: with levels now earned, they finally mean something.

### 2.6 Hot drop vs quiet camp, side by side
| | Hot zone | Quiet mid region | Quiet rim |
|---|---|---|---|
| XP on the table | 540 + about 255 per squad wiped | 360 | 230 |
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
- After landing they clear smallest to biggest inside their region, skip a camp a stronger squad is fighting on, and stop camping at 2:30 or when the Blight is within 40 m, then go on to the Limited Way Outs objectives. Mid-game, a bot squad below L5 detours to a come-back camp within 60 m.
- Bots Hard Land half the time when their landing camp is live. Par: bot squads average L3.5 to L4.5 at 2:30, the same band as the human targets.

### 2.9 Boki wisps
- 0.24.4: nothing new to build. The wisp's carry passive is always on, which is what makes a Small Camp safe at level 1; the Bond meter still fills from the damage you deal to camp monsters.
- Later, when the summon button ships (DECISIONS 11-09): clearing a camp refunds summon cooldown (Small 10%, Camp 20%, Great 35%), so a squad that farmed arrives at its first fight with the Boki ready. And two of the five rare Boki spots move inside Great Camps as "guarded" (a paw on the icon): clear the camp, the Boki wisp floats free, scan it. Both are `[early]` tasks.

### 2.10 What the Blight zone redesign must keep (job 20261110-171438-a4)
Camps feed the phase before and during the first shrinks. Handed to that spec as constraints, in order of weight:
1. No rim camp is covered before **1:45**, no mid camp before **4:00**, the Crown's last. (The LWO ring, 183 m at 1:30 on the 2x map, already does this.)
2. The first shrink should take the rim between about 1:45 and 4:00: that is the push that turns "farm" into "rotate and fight".
3. `Camps` needs one question answered by the zone: "is this point safe for the next 60 s". It gates comebacks and bot camping.
If its shrink times differ, only the two clock columns in 2.5 move; the camp numbers stand.

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
- **Waves:** W0 base (1 h), W1 camps core + map + drop (4 h, three workers), W2 Hard Landing + map display + bots (4 h, three workers), W3 one gate (3 h). Each task names the branches it needs on origin before it starts.
- **0.24.4 (tasks `[early-0244]`, about 12 h):** XP rules; the camps module (sizes, pay, reward, one comeback); 28 camps on the 2x map; camps on the drop map and minimap with the region line and smoke; bots; the drop numbers, dive view and cloud layer; the Hard Landing; one verify gate (pace sim, perf, shots).
- **Later (tasks `[early]`):** wisp summon refund; guarded Boki in Great Camps; Camp Chief art and per-region camp dressing; a pace readout on the results screen for tuning; a retune after the owner's first playtest.

## 5. Risks
| Risk | Guard |
|---|---|
| The hot-zone winner snowballs | Targets cap the lead at two levels at 4:00; knock XP scales with the victim's level, so a levelled leader is worth more to kill |
| Every squad lands quiet and nobody fights early | The rim is 70 XP short of L4 and is taken by the Blight first; the Sealed Lair opens at 2:00 |
| Clearing camps is a chore | Small Camp 10 s, a full region about 90 s including the walk; the Hard Landing opens the first one |
| Net: clients grant their own XP | The clear is decided per client from monsters it already sees die; if camp membership cannot be derived without a sync change, bump `Net.VERSION` (the 2x map already takes it to 0.24.5) |
| Blight spec lands with different shrink times | Section 2.10: only the clock columns move |
