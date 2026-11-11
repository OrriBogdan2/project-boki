# Project Boki Expedition Spec (estimate-based)

Status: **ESTIMATES**. Every number here is derived from public sources
(official wiki, patch notes, gameplay footage) and reasonable conversion,
not from extracted game data. Treat them as starting points to tune
against, not ground truth. Where a value is a pure guess from footage it
is marked (eyeball).

Sources: supervive.wiki.gg (Gliding, Getting Started), Deltia's Gaming
gliding guide, general gameplay footage. The wiki's own stats pages are
flagged outdated, so hard numbers are scarce; mechanics are well
documented, magnitudes are inferred.

This spec covers the *feel* of a top-down MOBA-survival extraction mode.
It deliberately does not reproduce their map, items, characters or art.

---

## 1. Unit conventions (how to read the numbers)

- Kinfall works in **meters, Y-up** (Godot 3D convention used in the
  project). Unreal source would be **centimeters, Z-up**: divide cm by
  100 for meters, and swap Z<->Y if we ever get real transforms.
- Horizontal plane is **X/Z** in Godot; "up" is **+Y**.
- Camera FOV below is given as **vertical** FOV (Godot's default axis).
  Unreal quotes **horizontal** FOV; convert with
  `vfov = 2*atan(tan(hfov/2) / aspect)` at 16:9.
- Speeds are **meters/second**, times in **seconds**, angles in degrees.

---

## 2. Camera rig

A top-down MOBA camera, slightly pitched so you see a little of the far
side of characters (not a pure 90-degree overhead).

| Param | Estimate | Notes |
|---|---|---|
| Pitch (down-angle) | 55-60 deg from horizontal (eyeball) | not straight down; you read elevation and glide arcs |
| Height above focus | 18-24 m (eyeball) | spring-arm length along the pitched boom |
| Vertical FOV | 38-42 deg | longer boom + narrow FOV keeps it readable, less distortion |
| Follow lag | 0.08-0.15 s smoothing | camera eases toward the hunter, doesn't hard-lock |
| Look-ahead | 1.5-3 m toward aim/cursor | shifts framing toward where you're aiming |
| Glide zoom-out | +15 to +25% boom length while gliding | they pull the camera back in the air for arc readability |

Recommendation: **copy closely.** The pitched-boom + narrow-FOV combo is
most of why the game reads well. Build it as a `SpringArm3D` with a
`Camera3D`, lerp boom length on glide.

---

## 3. Ground movement

| Param | Estimate | Notes |
|---|---|---|
| Base move speed | 5.0-5.5 m/s (eyeball) | our classes already sit 4.7-5.2; in range |
| Sneak speed | ~60-70% of base | Left Ctrl; slower, more vision |
| Accel / decel | near-instant (0.05-0.1 s ramp) | arcade feel, not momentum-heavy |
| Turn | instant facing toward aim | twin-stick style |

Recommendation: **keep ours.** Our class speeds (Light 5.2 / Medium 5.0 /
Heavy 4.73) are already in the plausible band. Add the sneak modifier if
we want their vision tradeoff.

---

## 4. Jump, glide, fall (the signature system)

Gliding is the identity mechanic: jump, hold to deploy the glider, and
you trade height for horizontal distance while "Glider Fuel" / heat
drains. Taking damage mid-glide does not knock you down by itself: it drains the glider at double
rate (normal damage to you). Only when the glider hits 0 are you spiked (stun, smash to the ground);
doing it over the abyss is instant death.

| Param | Estimate | Notes |
|---|---|---|
| Jump height | 2-3 m (eyeball) | enough to clear ledges and start a glide |
| Glide horizontal speed | 7-10 m/s (eyeball) | faster than run; the point of gliding |
| Glide descent rate | 2-4 m/s | slow sink while held |
| Glide fuel / capacity | 2.5-4 s of continuous glide (eyeball) | our `glide_cap` 0.85-1.2 is a multiplier, keep as-is and map to seconds |
| Fuel regen | refills on ground over 2-4 s | |
| Spike stun (hit in air) | **0.7 s** | this one IS stated on the wiki |
| Abyss fall | instant death | map hazard, not damage |

Recommendation: **copy closely**, it's the core. We already model glider
heat (`fuel`, `glide_max`, spiking cools the attacker by 0.5). Tie fuel
to real seconds using the capacity above, and keep the 0.7 s spike stun
exact since it's a known value.

---

## 5. Dash / mobility ability

Most hunters have a dash on LShift (one of the four ability slots). Exact
distances and cooldowns are per-character and not public.

| Param | Estimate | Notes |
|---|---|---|
| Dash distance | 5-8 m (eyeball) | our class ex-dash is 5-7 m, in range |
| Dash duration | 0.2-0.3 s | our 0.22-0.24 s is fine |
| Dash cooldown | 10-16 s (eyeball) | our 12-15 s is reasonable |

Recommendation: **keep ours.** Values land in the public-footage band.

---

## 6. Abilities & levels (structure, well documented)

- Hunters start **level 1** with **1 skill point**.
- Four abilities: RMB, Q, LShift, R. **Ultimate (R) unlocks at level 7.**
- One non-ultimate skill can reach **level 4**; the others cap at
  **level 3**.
- Relic actives on F and G; up to **2 Relics, 2 Grips, 1 Kick, 1 Armor**.

Recommendation: our kit is weapon-class based, not hero-ability based, so
**adapt rather than copy.** Borrow the level-gated ultimate idea (unlock
a class ultimate partway through a run) if we want a power curve.

---

## 7. Down / death / revive (already implemented, matches their rules)

This is the system in `DEATH_AND_REVIVE.md` and `life.gd`. Public rules:

- **0 HP -> Wisp state.** Heavily slowed, can't fight. (We model this.)
- **Ally stands on wisp -> revive** with a portion of HP. (We use 0.33.)
- **Enemy stands on wisp -> kill**, drops a **Deathbox** with resources.
  Enemies can also **execute** with E.
- **Deathbox revive:** long-press E near it = full revive.
- **Revive beacons:** revive the whole team, make a sound enemies hear,
  show duration on the minimap. (We model beacons.)

Recommendation: **keep ours**, it already tracks their rules. Our exact
timers (bleed-out 15 s, revive 4 s, soul 90 s, beacon 6 s) are our own
tuning and fine to keep.

---

## 8. Basecamp / extraction

- Claiming a basecamp takes time; gives **vision** and a central
  **healing zone**. Repair armor at the Envil (long-press E), brew at the
  cooking pot. Camps can be **packed up for a price and moved**. Recall
  on B.
- Loot from monsters, coins, shops, chests, vaults, deathboxes, and
  **guaranteed boss drops** (abyssal hatchling, meteor beast).

Kinfall's extraction loop is our own (kin as the thing you carry out, tier
risk, theft/chase). Borrow:
- a **claimable safe node** that heals and gives vision,
- **guaranteed drops from a tier boss** as the reward spike,
- **recall** to leave.

Recommendation: **adapt.** Use the basecamp idea for our extraction
points; keep our kin-centric stakes.

---

## 9. Map scale (roughest estimates)

No public map dimensions. From footage, a full match map reads as a
large island broken into zones around a shrinking boundary.

| Param | Estimate | Notes |
|---|---|---|
| Playable radius | 300-500 m per side (eyeball) | a hunter crosses a zone in ~20-40 s |
| Zones | 6-9 named areas | each with a basecamp + loot |
| Boundary | shrinks over the match (storm) | standard BR pressure |

Recommendation: our expedition maps are smaller and tier-based; **don't
match their scale.** Use the "zone with a basecamp and a boss" unit as a
building block and size to our match length.

---

## 10. What to copy closely vs change

**Copy closely (this is the feel):**
- Pitched top-down spring-arm camera with narrow vertical FOV and glide
  zoom-out.
- The jump/glide/fuel loop and the 0.7 s spike stun.
- Wisp -> deathbox -> beacon death-and-revive flow (done).

**Keep ours (already in range):**
- Ground speeds, dash distance/duration/cooldown, revive timers.

**Change / make our own (don't clone):**
- Hero abilities -> our weapon-class kits.
- Their map, zones, items, bosses, art, audio -> original Kinfall
  content and kin-centric extraction stakes.

---

## 11. If we later get exact data (legal routes only)

With written permission from Theorycraft, or an official data source, the
real values live in these tables (names seen in the asset registry, not
their contents):

- `CT_LokiCharacterAttributes`, `CT_PrimaryAttackSpeeds`,
  `CT_LokiAbilityAttributes`, `CT_LokiPowerAttributes`,
  per-hero `CT_*Attributes`, `CT_*DashScaling`,
  `CT_StunDurationByDistance`.
- Camera: `BP_LokiPlayerCameraManager`, player-controller camera
  components, `GE_Gliding_CameraZoom`.
- Main map bounds: the Skylands map level asset.

Swap the estimates above for those values and re-flag this doc as
measured. Until then: estimates.

---

## 13. Monster damage to Hunters (PvE, measured)

Measured with `--mob-damage-check`. A Medium Hunter (145 health, classic kit, no Boki, full starting
armour) stands still and never fights back. First they stand alone with each monster, then in each
fixed camp mix Match spawns (light, normal, heavy), then in each lair with its boss awake. Health
doesn't change what monsters do, so a single run gives both levels: the time the damage taken reaches
level-1 health (145) and level-5 health (180, +6% a level, `content/rules/level_growth.json`). Each
monster is the base kind: tier 0, no region, rarity or mutation. A knock that carries the Hunter more
than 3 m is undone, as a Hunter holding the camp would walk back in. The match seed is fixed, so the
rows repeat exactly from run to run. Each row is one run, so a small change in timing can shift a row
by a few seconds.

Our numbers per hit are the raw values in `Data.MOBS` (`scripts/core/data.gd`). Measured hits land
20% lower while armour holds (`Hunter.ARMOR_DR`). Boss attacks scale their base value (`Boss.dmg`).

| Monster / camp | Ours per hit (data) | Measured per hit | Measured per s | Falls, level 1 | Falls, level 5 | Source |
|---|---|---|---|---|---|---|
| Skitter | 9 | 7.2 | 3.9 | 38.6 s | 46.5 s | — |
| Spitter | 11 | 8.4 | 2.8 | 53.5 s | 65.7 s | — |
| Brute | 24 | 18.3 | 5.2 | 31.8 s | 35.4 s | — |
| The Watcher (warden) | 30 | 24.0 | 8.2 | 20.3 s | 23.4 s | — |
| Puffbomb (bomber) | 16, once (blows up) | 12.8 | one blast | never | never | — |
| Sentinel | 8 | 8.1 | 3.2 | 37.1 s | 58.8 s | — |
| Glimmerkin | 0 (flees) | 0 | 0 | never | never | — |
| Light: 2 Skitter | | 7.5 | 4.8 | 33.7 s | 37.3 s | — |
| Light: Spitter + Skitter | | 7.6 | 5.4 | 29.9 s | 33.7 s | — |
| Light: Puffbomb + Skitter | | 7.4 | 4.0 | 36.6 s | 45.9 s | — |
| Normal: Brute + Skitter + Puffbomb | | 13.6 | 8.5 | 19.0 s | 22.5 s | — |
| Normal: Skitter + Puffbomb + Spitter | | 7.8 | 5.4 | 28.3 s | 34.9 s | — |
| Normal: Sentinel + 2 Skitter | | 8.0 | 7.4 | 20.8 s | 24.9 s | — |
| Heavy: Brute + Spitter + Skitter + Sentinel | | 7.9 | 7.9 | 19.5 s | 23.1 s | — |
| The Stone Colossus | 26 base | 15.5 | 5.9 | 26.6 s | 31.2 s | — |
| Stormcoil | 22 base | 16.0 | 5.0 | 28.6 s | 38.3 s | — |
| The Brood Mother (and her adds) | 18 base | 5.8 | 11.4 | 12.3 s | 16.3 s | — |

A camp never has more than two monsters on one Hunter at once (`Mob.MAX_ENGAGED`), so a 4-monster
heavy camp hits about as hard as a 3-monster normal one.

**Source column: — means the source publishes nothing on this (2026-11-11).** Where we looked:
- `briefs/supervive-data`: the game-file pull covers Hunter attributes only, with no creature tables.
- The wiki Creeps page (supervive.wiki.gg/wiki/Creeps): no damage, health or attack rate for any creep
  or boss, and the page is marked outdated. It gives only the camp makeup (3 small creeps and 1 elite,
  back each day) and that a stagger takes 3x damage.
- The footage in briefs: training-range kit footage against dummies (docs/CAMP_PARITY.md on
  ext/camp-parity says the same).

So none of these numbers can be matched, and **no monster or boss number was changed**.

What the source does settle is Hunter health growth. Its base health is 1,290 for most Hunters, plus
77.4 a level (6%) (`briefs/supervive-data/supervive_physics.md`). Ours is 145 for a Medium plus 6% a
level, so the curve matches, and so does the level-5 gain over level 1 (+24%). Source numbers run
about 9x ours (1,290 / 145). Read any creature damage that turns up later at that scale. When a camp
capture or a data pull gives creature damage, fill the Source column, change `Data.MOBS` to match,
and rerun `--mob-damage-check`.
## 12. Camp clear pacing (PvE, measured)

`--camp-clear-check` puts each of the 12 Hunters (bot-driven, normal kit use, no Boki summon) against a fresh camp at level 1 and level 5. Skitter camp = 2 Skitters, spitter camp = Spitter + Skitter, brute camp = Brute + Skitter + Puffbomb (the game's own comps). Each trial puts the hunter back on its landing spot and lets it rest 3 s. The camp spawns alerted, 6 m away on the same level and in line of sight, so the time is the fight, not the bot's walk. A cell is the median of 5 trials: time to clear / damage taken (hp). Seed 4242:

| Hunter | ski L1 | spi L1 | bru L1 | ski L5 | spi L5 | bru L5 |
|---|---|---|---|---|---|---|
| gunslinger | 3.2s / 0 | 4.4s / 0 | 9.0s / 0 | 3.5s / 0 | 4.9s / 0 | 10.2s / 0 |
| juggernaut | 2.4s / 7 | 2.2s / 0 | 3.8s / 19 | 2.0s / 7 | 2.7s / 7 | 1.9s / 7 |
| ashwick | 9.9s / 7 | 10.3s / 0 | 11.4s / 0 | 8.1s / 0 | 6.2s / 0 | 10.8s / 0 |
| tender | 5.4s / 0 | 6.4s / 7 | 13.1s / 12 | 4.9s / 0 | 8.3s / 0 | 10.3s / 0 |
| dolm | 1.5s / 0 | 3.8s / 0 | 3.7s / 0 | 1.8s / 7 | 3.3s / 0 | 3.4s / 0 |
| archer | 5.3s / 7 | 6.3s / 0 | 9.3s / 0 | 4.6s / 0 | 3.4s / 0 | 7.9s / 7 |
| dredge | 3.2s / 0 | 5.0s / 0 | 6.8s / 26 | 2.2s / 0 | 3.1s / 0 | 6.4s / 19 |
| rimewright | 4.8s / 0 | 6.8s / 0 | 7.3s / 0 | 5.4s / 0 | 3.9s / 0 | 3.6s / 0 |
| mage | 4.0s / 0 | 4.5s / 0 | 6.6s / 0 | 3.7s / 0 | 3.8s / 8 | 5.1s / 0 |
| bulwark | 11.1s / 35 | 19.6s / 39 | 15.9s / 57 | 3.2s / 14 | 19.4s / 16 | 22.6s / 70 |
| thief | 3.7s / 0 | 4.1s / 0 | 6.8s / 19 | 2.9s / 0 | 2.3s / 0 | 5.6s / 0 |
| ostra | 5.0s / 0 | 5.6s / 8 | 10.9s / 0 | 4.3s / 0 | 5.2s / 8 | 8.2s / 0 |

Spread per camp and level, slowest median vs fastest:

```
skitter@1: slowest 11.1s vs fastest 1.5s (7.39x)
spitter@1: slowest 19.6s vs fastest 2.2s (8.96x)
brute@1:   slowest 15.9s vs fastest 3.7s (4.35x)
skitter@5: slowest 8.1s vs fastest 1.8s (4.47x)
spitter@5: slowest 19.4s vs fastest 2.3s (8.37x)
brute@5:   slowest 22.6s vs fastest 1.9s (12.00x)
```

**Findings.** `briefs/supervive-data` has no creature hp or damage, so there is nothing to compare against. The proposed band is slowest no more than 1.6x the fastest. It is **not met**, and mob numbers can't meet it: with Skitter, Spitter, Brute and Puffbomb hp all doubled, the spread is still 4.7x to 7.2x. The gap is how the bots use the slow kits:
- Bulwark's tap throws the hammer, which has to come back.
- Ashwick's hose (27 dps, 7 m) is fired in the bot's on/off bursts for fast guns, from a heavy's 5.5 m, so it lands about half its damage.
- Juggernaut and Dolm close in and cleave whole camps.

Fixing this is bot-brain work (`scripts/match/bot.gd`: per-kit fire duty and preferred range), not mob or kit numbers. The check asserts that every Hunter clears every camp (median under 30 s) and a spread ratchet (`SPREAD_MAX` 14x). It prints the 1.6x target beside the ratchet. Lower `SPREAD_MAX` as the bots improve. Runs are deterministic per seed. The full check takes about 3 minutes; `--arch=<id>` runs one Hunter.
