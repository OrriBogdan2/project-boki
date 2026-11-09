# Archetypes

Naming: players see these as **classes** ("archetype" is the internal word: ids, files and save keys keep it, and the weight (Light, Medium, Heavy) is what used to be called the class).

Status: **built** (branch `archetypes`; see "Implementation status" at the end for what's in, what's
a subset and the gaps). It describes six archetypes, two per weight class. Each one is a
whole character: a dash, a passive, LMB, RMB with contextual variants, E (usually utility) and R
(the ultimate, unlocked at run level 6). The weapon is part of the archetype. The kin changes what
the archetype's abilities do, through grammar parts, and keeps its own identity through its throw,
owner bonus, carry mode, auto ability and the merge.

Read with `docs/DASHES_AND_ABILITY_FEEL.md`. Each dash is specified there (§3), and so are the feel
rules (telegraphs, hitstop, shake, sound, colour) that every ability here inherits. Everything is
original to Kinfall. The SUPERVIVE research only informed structure: the kit layout, contextual RMBs
and passive build-ups.

---

## 1. Who gives what

| Layer | Gives | Lives in |
|---|---|---|
| **Weight class** (light, medium, heavy) | HP, run speed, mass and knockback, glide heat, **dash charges and recharge**, air dash | `Data.CLASSES` (unchanged) |
| **Archetype** (2 per weight) | silhouette, **weapon family (LMB + RMB)**, **passive** (and its resource, if any), **E**, **R**, **dash shape** | new core data `content/archetypes/<id>.json` (reviewed, not community-authored) |
| **Weapon** (2 per archetype) | LMB firing pattern, and the RMB's flavour within the archetype's verb | `content/weapons/*.json` (+ a `archetype` field) |
| **Kin** | **modifies** archetype abilities through sockets (§4), plus its own throw (G), owner bonus, carry mode (shoulder, perch, mount), auto ability, dodge rider and **merge** | `content/kin_v2/*.json` (+ an optional `infusion` field) |
| **Glove** (loot) | Q active, or passive stats | `content/gear` (unchanged) |

| Weight | Archetypes | Charges / recharge (from the class) |
|---|---|---|
| Light | **Thief**, **Archer** | 1 / 6.5s |
| Medium | **Mage**, **Gunslinger** | 1 / 9s |
| Heavy | **Juggernaut**, **Bulwark** | 2 / 12s |

## 2. Key layout: today → new

Current binds are in `scripts/core/game.gd` `_setup_input()`.

| Key | Today | New |
|---|---|---|
| LMB | weapon fire | weapon fire (unchanged) |
| RMB | the weapon's own utility (9 different abilities, one per weapon) | the **archetype's RMB**, tied to firing, with contextual variants (tap, hold, airborne, during E, resource full). Both weapons of an archetype share the verb |
| Shift | class dodge (phase step, roll, shoulder charge) | the **archetype dash** (charges from weight) |
| Space / Mouse 5 | jump / glide | unchanged |
| Q | active glove (`gear1`) | **unchanged**: gloves stay the run's loot layer, so Q is still the glove |
| E | the kin's ability (`signature`) | the **archetype's E** (usually utility). The kin's old E becomes the kin's **infusion source** (§4) |
| G / middle mouse | throw / recall the kin | unchanged (the kin keeps its throw, and casts its own ability itself) |
| R | (then) bond ultimate (the merge), when the bond meter is full. **Now: X is Merge, R is the hunter ultimate, there is no reload key** | the **archetype's ultimate**, from run level 6. When the bond meter is full, R casts **bonded**: the kin merges as it fires (§5) |
| 1 · F · B · Ctrl · T · M · Tab | tonic · interact · base · sneak · emote · map · scores | unchanged |
| Alt + key | rank up that slot with a skill point (`match.gd`) | unchanged |
| G | folds the training guide (training/duel only, `hud.gd`) | unchanged. Note: G is **not** the throw today; the throw is C or middle mouse |
| (none) | — | **passive**: no key; its resource shows on the HUD (§3.2) |
| (none) | kin auto ability | unchanged: the kin casts it on its own (with the 0.25s kin tell) |

Skill slots (`Hunter.SLOTS`): `sec` (RMB), `gear` (Q), `dash`, `kin` (rename to `e`; the alias
already exists), `ult` (R). Ranks stay 3/3/3/3/2.

## 3. Global rules

### 3.1 Cohesion checklist (every archetype must pass)

1. The **passive** builds from things the kit already does, and pays off in one named place
   (usually the RMB).
2. The **RMB** has at least three contextual variants, and at least one of them interacts with E or R.
3. The **dash** sets up the combo: it creates the passive's condition, or opens a window for the RMB.
4. **E** is utility (vision, terrain, buffs, zones, defence) and changes how RMB or R behaves while it's up.
5. **R** cashes in what the kit built up (resource, marks, zones) and has a counterplay window
   enemies can read (DASHES §5.3).
6. **Silhouette:** one primary feature never changes with cosmetics (Riot's rule). Size follows weight.
7. Each archetype has a **two-sided read**: what enemies see when the resource is high, when the R is
   bonded, and when the dash is spent.

### 3.2 No mana; resources and readability

- **No mana or energy pool anywhere.** Every ability is cooldown or charge based. (Kinfall's
  hunters don't have mana today, so nothing needs removing.)
- An archetype's passive **may** own one resource, if it strengthens cohesion. A resource:
  - is bounded (0-100, or a stack count up to N);
  - is **built by play**: dealing or taking damage, blocking, standing still, hitting, casting;
  - **decays out of combat** (after 3-4s);
  - **never gates the basic kit**. It only empowers one thing, or forces one risk (the Mage's Vent);
  - is shown in two places on the HUD: a small arc or pip row hugging the crosshair, and a bar or
    counter in the portrait cluster;
  - has an **enemy-readable tell**: a subtle one at 50% (glow), a strong one at full (aura plus a
    short sound sting audible within 12-25m). Opponents can see "they're full, bait it out or back off";
  - is core data, never kin data. A kin can't add a resource. A kin can only change the empowered
    variant through its sockets (§4), so community kin can't create hidden power states.
- The six differ in **how** they build, which is why each is kept:

| Archetype | Resource | Built by | Shape |
|---|---|---|---|
| Thief | **Marks** | hits from behind | stored on *targets* |
| Archer | **Hawk Sense** | always on | no meter (Focus was cut, 2026-11-07) |
| Mage | **Heat** | casting | risk meter (overheat Vents) |
| Gunslinger | **Chambers** | weapon hits | six-count |
| Juggernaut | **Rage** | dealing and taking damage | brawl meter |
| Bulwark | **Guard** | blocking | defence meter |

  The Gunslinger's is the lightest. If playtests show six resources is too much to read, cut that one first.

### 3.3 RMB variants

Priority when several apply: **resource full > during R > during E > airborne or gliding > hold > tap**.

- Tap fires on release under the hold threshold (0.18-0.4s depending on the archetype). A hold shows
  its own telegraph while held (self: aim shape; enemies: a growing line or circle if it's a hard-CC hold).
- Variants share one cooldown unless stated otherwise.
- Each variant is a normal grammar AbilitySpec (`from: owner`). The archetype's input router picks
  which one fires. The executor (Phase 2) only ever runs plain stages.

### 3.4 Run levels and unlocks

Run levels already exist: `Hunter.XP_TO` (10 levels), `skill_pts` (1 at the start, +1 per level),
`slot_lv` (everything locked at the start), `SLOT_MAX` (RMB, Q, dash, E: 3; R: 2), `ULT_AT = [6, 9]`.
That's 10 points for 14 possible ranks, so choices matter.

- **R stays a level-6 unlock** (rank 1 at 6, rank 2 at 9). Nothing in this proposal changes `ULT_AT`.
- The first point (level 1) should open the archetype's core verb. Each archetype below gives a
  recommended order, which is also the bot order (`Hunter._bot_spend`).
- Generic rank effects stay (ABILITIES.md): +15% damage per rank, −10% cooldown (dash −15%
  recharge), the verb's own numbers grow (`Effects.RANK_GROW`). Dash distances never grow. R rank 2:
  +30% duration and +15% cast effects. Each archetype adds **one rank-3 special** per slot, listed below.

### 3.5 HUD: making the level obvious (SUPERVIVE-style portrait cluster)

Most of this exists in `hud.gd` already: the portrait with a run-level badge and XP ring, a pulsing
"+" for unspent points, rank pips over each slot, a padlock on locked slots and "LV 6" over a locked
R. The layout was modelled on SUPERVIVE's portrait cluster from public gameplay footage. The proposal
makes it louder:

| Element | Today | Proposed |
|---|---|---|
| level number | 19px in a 19px-radius badge at the portrait's corner | **26px bold in a 26px-radius badge**, overlapping the portrait's bottom-left corner. The XP ring is 4px gold, with a bright head dot at the fill point |
| level-up | the ring fills; the "+" badge appears | a **0.35s badge pop** (scale 1 → 1.35 → 1), a gold ring burst around the portrait, a dedicated `level_up` chime (distinct from `unlock`), and a toast: "LEVEL 4 · +1 SKILL POINT". In the world, a gold ring pulse on your hunter that nearby players see too |
| skill points | a "+" on the portrait badge; a "+" on rankable slots | the same, plus slot frames **glow gold** while a point is spendable and the key hint reads "ALT+E" for 5 s after a new point and on hover; the + is clickable (RankClick) |
| R before 6 | padlock + small "LV 6" above | a **big "6" in the slot's centre** over the padlock. At level 5 the slot fills with progress to 6 (a vertical gold fill). At 6 it flashes and reads "UNLOCK" |
| R at 6-8 | rank pips | rank pip 1/2 plus a small "9" corner tag for the next rank |
| enemy level | — | a small level badge at the left end of every enemy nameplate (with a gold rim once they're 6+ and their R is unlocked) |
| resource | — | the archetype resource arc at the crosshair and a bar under the health bar (§3.2) |
| bond | kin card on the portrait corner | the kin card's ring is the bond meter. When full, the R slot gets a **kin-coloured rim and "BONDED"** (§5) |

---

## 4. The kin's role: sockets and infusion

### 4.1 Sockets (on archetype abilities)

Every archetype ability declares a few **sockets**: typed places where a kin's parts go.

| Socket | Accepts | Mode | Notes |
|---|---|---|---|
| `hit` | one damage-category part (a preset like poison, or a mark) | add | a rider on what the ability already hits |
| `ctrl` | one control part | **add** or **swap** (the socket says which) | soft sockets cap stun 0.3 and root 0.6; hard sockets cap stun 0.8 and root 1.2. A swap replaces the base control effect (e.g. the Mage bolt's slow) |
| `guard` | one sustain part (shield, heal, reflect) | add | only on defensive or self abilities |
| `util` | one utility part (reveal, vulnerable, buff) | add | — |
| `mod` | one modifier compatible with the delivery (KIN_GRAMMAR rules) | add | if nothing fits: **fallback +10% to the stage's primary number** |
| `move` | `blink` | swap | only on dash and leap deliveries |

Sockets have a **budget** (Phase 3 points). A kin part's numbers are relative intensity. The socket
rescales them to its budget, so a kin can't overload a weak socket, and a socket can't make a weak
kin part overpowered.

### 4.2 Infusion (on the kin)

New optional KinSpec field:
`"infusion": {"hit": {...}, "ctrl": {...}, "guard": {...}, "util": {...}, "mod": [{...}, ...], "move": "blink"}`.
If a kin leaves it out, it's **derived from the kin's current E active** (dodge riders are retired, owner 2026-11-05: dashes are the hero's own):

1. `hit` ← the first damage effect with `over` > 0, or a damage-category mark.
2. `ctrl` ← the first control effect.
3. `guard` ← the first sustain effect.
4. `util` ← the first utility effect.
5. `mod` ← the active's modifiers in order.
6. `move`: retired with the dodge riders (no kin changes how you dash).

The six kin today:

| Kin | hit | ctrl | guard | util | mod (in order of preference) | move |
|---|---|---|---|---|---|---|
| **Vespyx** | poison (damage over 3s) | blight mark; on projectiles a short barb pull (to caster, gap 1.5) | — | — | pierce | — |
| **Gravadillo** | — | lift (bursts, cones); gravity-well pull (zones, landings) | shield (plate) | — | spike | — |
| **Prismander** | — | dazzle (slow 0.35-0.5) | reflect (mirror), shield | — | split | — |
| **Mycroll** | spore damage over time (small) | slow → root if already slowed (`exploit slowed`) | shield (small) | — | linger | — |
| **Echolop** | — | jolt (stun 0.25-0.3) | — | reveal | chain, repeat | — |
| **Lunowl** | — | push (gust); lift with forward on launches | — | vulnerable mark | return, bounce | blink |

### 4.3 Rules, so a community kin maps automatically

1. Fill each socket by category match. A kin with no part for a socket leaves it empty, and that
   socket's fallback applies (+10% primary number, or +0.5s duration on buffs and zones).
2. A `mod` socket takes the kin's first preference that's compatible with the delivery and not
   already on the stage. Otherwise the next. Otherwise the fallback.
3. Hard CC is clamped to the socket's soft or hard caps. Reflect only goes into `guard` sockets.
   Signature effects (swap, decoy, bridge) only go into sockets marked `signature_ok` (R sockets,
   at bonded budget).
4. A kin **never** changes an ability's delivery, input, cooldown or telegraph, except `move: blink`
   on dash and leap deliveries (DASHES §3.4). The archetype keeps its identity; the kin changes its nature.
5. All grammar hard caps still apply: shot riders never stun or root, `linger` never repeats stun or
   root, a vulnerable mark is at most +35%, and so on.
6. The checker (`--grammar-check`, Phase 3) prints a kin's result table against all six archetypes,
   like the tables in §6. A community author sees exactly what their kin does to every archetype
   before submitting.

### 4.4 What the kin keeps as its own identity

- **Throw (C):** `throw.effects`.
- **Owner bonus:** the stat profile's owner points and carry passives.
- **Carry mode:** shoulder, perch, or mount. Lunowl's perch adds +1 dash charge on top of the
  weight class. Gravadillo's mount cuts damage taken and knockback.
- **Auto ability:** cast by the kin itself.
- **Dodge rider:** DASHES §3.5.
- **Merge:** §5.

---

## 5. Merge vs R: resolving the conflict

> **Superseded (docs/decisions/0001-boki-merge-and-commands.md):** R is the Merge for every class. The
> options below are kept for the record; the class's own R stays reachable behind
> `content/rules/boki_system.json` `class_ults` until the hero-port work folds it into the kits.

Today the merge **is** R (the bond ultimate, unlocking at run level 6). The new kit gives R to the
archetype. Options:

| Option | How it works | Pros | Cons |
|---|---|---|---|
| **A. Separate merge key** (e.g. V) with its own bond meter | press V to merge any time the meter's full; R is the archetype ult | the most freedom; two separate big moments | a 7th combat key; merge + ult can stack into a huge spike; two "transform" states to read; screens get noisy |
| **B. Merge replaces R when bond is full** | while bond is full, R casts the merge instead of the ult | no new key | you lose your ult whenever bond is full (or have to waste bond); confusing ("what does R do right now?"); the ult and merge compete instead of combining |
| **C. Bonded R** (recommended) | R is always the archetype ult (level 6). When the bond meter is full, the next R is **bonded**: the ult fires with the kin's R sockets at bonded budget, and the kin merges for the merge's duration (passives, `on_shot`, pulses, and `merged` patches retargeted to RMB/E sockets). Bond spent; the ult goes on its normal cooldown | one key, one big moment that's both "my character" and "my kin"; the bond meter has a clear purpose; the kin's merge identity survives intact; the moment gets the T5 feel budget once, not twice; enemies get one clear tell (§3.5: kin glow, BONDED rim) | the merge can't happen without the ult; the bond meter and the ult cooldown need tuning so bond is usually full about every second R |
| **C′. Bonded R + hold R** (playtest toggle) | as C, plus: if bond is full and R is on cooldown, **hold R for 0.5s** to merge alone (the merge without the ult's blast) | covers a long ult cooldown with a full bond | slightly more to learn; a merge without the ult is weaker, and that's on purpose |

**Recommendation: C, with C′ behind a playtest flag.** Details:

- **Unlock:** R still unlocks at level 6. The bond meter starts filling from level 6. The first R
  unlock fills it once, so the very first R is bonded: the moment the owner liked, kept.
- **Bonded R tell:** at a full bond, the kin's eyes and aura glow in its theme colour, with orbiting
  motes. Enemies within 20m see it, so "their next R is bonded" is readable. The R slot shows the
  kin-coloured rim and "BONDED".
- **Cast:** the ult's own cast tell, then **0.2s later** the merge's `on_start`. Two beats, one
  moment. One T5 hitstop for the caster (DASHES §5.4).
- **MergeSpec change:** `merged` keys move from `active`/`auto` to the archetype sockets: `rmb`, `e`,
  `dash`. The scales are unchanged (×1.0-1.3, within part bounds). Merge `duration` stays 4-10s.
  It still ends early if you're knocked or you throw the kin.
- **Bond gain:** unchanged (fighting together). Target: bond full roughly every 1.5-2 R cooldowns.

---

## 6. The six archetypes

Each section covers: fantasy and silhouette · weapons · passive · RMB variants · E · R · dash ·
the combo loop · level-up order and rank-3 specials · counterplay · how each kin modifies it. In the
kin tables, `+` means added, `→` means swapped, and "fallback" is §4.3 rule 1. Numbers use the live
game's scale (`Data.CLASSES` HP 124 / 145 / 193; kin abilities hit for 8-22).

---

### 6.1 Thief (light)

> **Nov 1 (kits2): superseded.** The Thief was rebuilt as a port of SUPERVIVE's Shiv (owner direction); the built kit is in "Kit loops" at the end of this document, and it wins where they differ.

**Fantasy:** the cutpurse. Slips behind you, marks you, cashes in, gone in smoke.
**Silhouette:** the smallest and most hunched. A hood with a long pointed tail, a short asymmetric
cape, a crouched forward run, a reverse-grip blade or a stubby SMG. Eyes glint under the hood. The
**primary feature is the hood tail and cape**.

**Weapons** (both throw the RMB knife; the payoff after a Shadow Step differs):

| Weapon | LMB (today's numbers) | After Shadow Step |
|---|---|---|
| Twin Blades | tap: a 3-hit combo with small lunges; hold 0.5s: a 4.5m lunging stab | next hits crit for 1.5s |
| SMG | hold: spray, spread grows, falloff past 60% | 1.5s of zero spread, and shots crit on Marked targets |

Razor Disc (today's SMG RMB) retires. Shadow Step becomes the archetype's RMB.

**Passive: Marks.** A hit from behind (the rear 120°), or during the Flicker's Ambush window, adds a
Mark to the target (max 3, 6s, refreshed by each new mark). Each Mark makes the target take +5% from
you. At 3 Marks the target shows a gold purse glyph, and your next RMB on them **Cashes In**: it
consumes the Marks for +50% RMB damage and refunds your dash charge.
**Tells:** Mark pips over the target's head, visible to them and their team. At 3, the glyph pulses
and the victim hears a coin jingle. The Thief sees pips on targets and a gold dot on the RMB slot
while any target is at 3.

**RMB: Knife** (8s):

| Variant | What it does |
|---|---|
| tap | throw a knife 9m at 40 m/s: 10 damage, 1 Mark. Recast within 1.5s of a hit to **Shadow Step**: appear behind that foe (a blink up to 9m) and open the Ambush window |
| hold 0.35s | **Fan**: 3 knives in a 35° fan, 6m, 6 damage each, slow 0.25 for 0.8s, a Mark each. No step |
| airborne / gliding | **Drop Knife**: the Shadow Step recast becomes a dive. You land behind them with a 1.5m burst for 8 (no CC) and leave the glide |
| during E (inside your smoke) | the knife is silent and its streak hidden beyond 4m. Stepping out of smoke doesn't reveal you until you hit |
| target at 3 Marks | **Cash In** (above) |

**E: Smoke Veil** (18s, utility): a 3.5m cloud at your feet or the cursor (up to 6m) for 5s. Everyone
inside is hidden from outside, like tall grass. Attacking reveals you for 0.5s. Foes inside are slowed 0.2.

**R: Heist** (level 6, 70s):

- **Tell:** a 0.4s mark-out. Gold lines run from you to up to 4 enemy hunters within 9m and in sight.
  Each target sees "TARGETED" and its line.
- **Then:** four blink strikes 0.2s apart, each 14 damage + 3 Marks. You're untargetable for each
  0.2s hop and end behind the last target with the Ambush window open.
- **Counterplay:** a target that dashes out of 9m or breaks line of sight during the 0.4s drops out
  of the chain.

**Dash: Flicker** (DASHES §3.2): two quick steps per charge. The Ambush window feeds Marks.

**Loop:** Smoke → a silent knife → Shadow Step behind (Ambush) → strikes from behind stack Marks →
Flicker behind again → Cash In refunds the dash → Heist puts 3 Marks on everyone → Cash In on the
best target.

**Level-up order:** 1 RMB · 2 Dash · 3 E · 4 RMB · 5 Dash · 6 R · 7 RMB · 8 E · 9 R · 10 Q or E.

| Rank-3 special | |
|---|---|
| RMB | Shadow Step recast window 1.5 → 2.0s |
| Dash | second-step window 0.7 → 0.9s |
| E | radius +0.5m |
| R rank 2 | a 5th target, +15% damage |

**Counterplay:** watch your Mark pips; at 3, peel back or break line. Hit area damage into the smoke.
Save CC for after the second Flicker step. Heist's lines show who's next.

**Kin modifiers:**

| Kin | RMB Knife | E Smoke Veil | R Heist |
|---|---|---|---|
| Vespyx | + poison 6 over 3s; Fan + blight 3s; mod pierce (passes the first foe) | toxic smoke: + poison 2 a tick, blight inside | + poison 8 per strike; `exploit poisoned` on Cash In |
| Gravadillo | tap + lift 5 (a teammate can spike them); mod: fallback +10% damage | → pull 4 toward the centre (foes drift into the smoke) | the final strike gains `spike` (+0.5, stun 0.6) |
| Prismander | + dazzle slow 0.35; mod split (2 knives at 20°) | + shield 8 to allies who enter (guard) | + shield 8 to you per strike |
| Mycroll | + slow 0.3; a second hit on a slowed target roots 0.6; mod linger (a 1.2m spore patch where it lands) | slow 0.2 → 0.35, + spores 2 a tick | each strike roots 0.4 (soft cap) |
| Echolop | tap + jolt 0.25; mod chain 1 (3.5m) | foes inside are revealed to you only (one-way smoke) | mod repeat: the last strike echoes at 50%, 0.8s later |
| Lunowl | tap + push 6; mod return (the knife flies back, hitting again at 50%) | + vulnerable 0.15 on foes inside | strikes push targets 6 away from the last strike point (edges) |

---

### 6.2 Archer (light)

> **Nov 1 (kits4): superseded in part.** The Archer was rebuilt on a reference baseline (owner direction); the built kit is in "Kit loops" at the end of this document, and it wins where they differ.

**Fantasy:** the warden of high ground. Climbs, reads the field, pins people to walls.
**Silhouette:** tall and upright, standing still. A long weapon slung across the back rises above
the head (bow tips or rifle barrel). A feathered cowl crest and a quiver. The **primary feature is
the long weapon over the shoulder**.

**Weapons** (both fire the RMB snare: an arrow from the bow, a dart from the rifle):

| Weapon | LMB |
|---|---|
| **Longbow** (new) | hold to draw. Stage 1 at 0.4s: 30 damage, 12m, 45 m/s. Stage 2 at 0.9s: 60 damage, 15m, 60 m/s. An early release does 15. Slowed 30% while drawing |
| Sniper | press → 0.6s aim laser enemies can see → one heavy round (today's numbers) |

Tripwire Mine (today's Sniper RMB) folds into the RMB below.

**Passive: Focus.** Builds while you stand still (0 → 100 in 1.4s), while sneaking (2.8s), and 50%
faster on high ground. Drains 60/s while running, and drops 40 when you're hit. At 100 your next LMB
is **fully drawn or aimed instantly**, with +20% range.
**Tells:** a faint lens glint at 50. At 100, a bright glint and a thin aim line that anyone in your
aim line can see. HUD: an arc under the crosshair.

**RMB: Snare** (9s, 2 charges):

| Variant | What it does |
|---|---|
| tap | a snare arrow 11m at 45 m/s. A foe hit takes 8 and is rooted 0.6. Ground or terrain hit: it plants a **Tripwire** there (arms in 0.5s, lasts 15s, max 2 live). On trigger: 0.15s click, then root 1.2, reveal 3s, 10 damage |
| hold 0.5s | **Pinning Shot**: 14m at 60 m/s, 16 damage, push 6, pierces 1. A target pushed into terrain within 3m is rooted 1.2 (`exploit near_wall`). The draw shows a cast glint and lane to enemies (hard-CC telegraph) |
| airborne / gliding | **Plunge**: shoot straight down. A 2m burst under you pushes foes 8 and lifts you 3m, and cools the glider 15%. Saves you after a knock-off, or gets you up |
| during E (inside your Flare zone) | snares seek revealed targets by up to 10° |
| Focus 100 | a tap snare roots 1.0 instead of 0.6 |

**E: Flare Arrow** (16s, utility): lob it up to 14m (0.4s flight). A burst reveals within 7m for 4s,
and a 7m zone keeps revealing anyone who enters for 4s. It shows traps and stealth, smoke included.

**R: Skyfall Volley** (level 6, 75s):

- **Tell:** aim a 5m circle up to 16m. For 0.8s, arrows visibly arc up and the circle fills, with a
  rising whistle.
- **Then:** 5 waves every 0.4s, 6 damage each, slow 0.3. The last wave roots 1.0 in the inner 2m,
  which has its own 0.4s fill.
- **Counterplay:** walk out during the 0.8s, or leave the inner ring before the last wave.

**Dash: Grapple Arrow** (DASHES §3.2). The way up onto ledges, where Focus builds faster.

**Loop:** Grapple onto a ledge → stand still for Focus → Flare reveals → a full-Focus Pinning Shot
into a wall → Volley on the rooted target. Tripwires guard the perch's approach. Plunge if you're
knocked off.

**Level-up order:** 1 RMB · 2 Dash · 3 E · 4 RMB · 5 E · 6 R · 7 RMB · 8 Dash · 9 R · 10 E or Q.

| Rank-3 special | |
|---|---|
| RMB | max 3 live Tripwires |
| Dash | the backward-hop fallback refunds 40% |
| E | the zone lasts 6s |
| R rank 2 | a 6th wave |

**Counterplay:** the glint and aim line warn you of a full-Focus shot. Rush or flank the perch, and
cut the grapple rope. Watch for the Plunge if you knock them off. Leave Volley circles early.

**Kin modifiers:**

| Kin | RMB Snare | E Flare | R Volley |
|---|---|---|---|
| Vespyx | + poison 6; Tripwire + blight 4s; mod pierce (tap passes the first foe) | revealed foes are blighted 3s | + poison 4 per wave; mod fallback +10% damage |
| Gravadillo | Pinning Shot push 6 → lift 6 (spike setup); tap + gravity-well pull 6 on Tripwire triggers | fallback +0.5s | the last wave + `spike` (+0.5); pulls the inner ring inward 6 |
| Prismander | + dazzle slow 0.4; mod split (tap fires 2 at 15°) | + shield 10 to allies inside on the burst | + shield 10 to allies inside the circle per wave (heals your side) |
| Mycroll | Tripwire leaves a spore zone (`linger`); slowed targets rooted 0.6 by the tap | revealed foes are slowed 0.25 | waves slow 0.3 → 0.45; mod linger (spore ground 2s after) |
| Echolop | tap + jolt 0.25; mod chain 1 on foe hits | the burst also jolts 0.2 (soft) | mod repeat: the last wave echoes at 50%, 0.9s later |
| Lunowl | Pinning push 6 → push 10 (the wall pin is easier, and so are edge kills); mod return | + vulnerable 0.15 on revealed foes | waves push 4 out from the centre, the last pushes 8 (edge clear) |

---

### 6.3 Mage (medium)

> **Nov 1 (kits4): superseded in part.** The Mage was rebuilt on a reference baseline (owner direction); the built kit is in "Kit loops" at the end of this document, and it wins where they differ.

**Fantasy:** the runecaster. Draws sigils, throws bolts that take on the kin's nature, and runs
dangerously hot.
**Silhouette:** a tall pointed hood or brimmed hat, a long robe that flares, and a staff taller than
the head with a glowing focus. A rune ring floats at the casting hand. The spellblade version keeps
the robe and carries a rune-lit sword. The **primary feature is the hat and robe flare**.

**Weapons** (both fire the RMB bolt; the sword fires it as a crescent):

| Weapon | LMB |
|---|---|
| **Spellstaff** (new) | an orb bolt every 0.45s, 26 m/s, 10m; every 4th bolt is +50% |
| Longsword (spellblade) | today's 3-hit combo, tip bonus, hold 0.8s lunge |

Riposte (today's Longsword RMB) retires. A frontal reflect stays in the game through the Mirror Glove
and Prismander's sockets.

**Passive: Overload (Heat).** An RMB tap adds 20 Heat, a hold adds 35, E adds 25. Heat decays 18/s
after 1.2s without casting.

- **Overcharged** (70+): RMB and E get +25% radius and damage, and bolts pierce 1.
- **100: Vent.** A 0.4s windup (a ring collapses onto you, visible to all), then a 3m nova: 14
  damage, push 9. Heat resets to 0 and RMB is locked for 1s. Skilled Mages ride 70-99, and use the
  Vent as a peel.
- **Tells:** robe runes go white-hot at 70+, steam at 90+, then the Vent ring. HUD: a heat arc around
  the RMB slot and the crosshair.

**RMB: Bolt** (2.5s, gated by Heat):

| Variant | What it does |
|---|---|
| tap | a bolt 10m at 28 m/s: 14 damage, **slow 0.25 for 0.8s** (the swap socket kin change: frost, chain, push...) |
| hold 0.6s | **Lance**: a 14m beam (width 0.5), 24 damage, pierces. You're slowed 50% while charging; enemies see the line during the charge |
| airborne / gliding | **Starfall**: a bolt into the ground under you. A 2.5m burst: 10 damage, push 7. It lifts you 2m and cools the glider 15% |
| through your Sigil (E) | a tap bolt that passes through the Sigil **splits into 3** (25°); a Lance chains to 2 more foes |
| Overcharged | +25%, and pierce 1 |

**E: Sigil** (14s, utility):

- Draw a 3m rune circle up to 9m away for 6s. Allies inside move 15% faster.
- Bolts through it split (above).
- **Recast E to detonate:** a 0.3s flash, then a 3m burst: 10 damage, lift 7.

**R: Meteor** (level 6, 70s):

- **Tell:** aim a 4m circle up to 14m. For 1.0s the circle fills, a burning rock visibly descends,
  and the ground rumbles.
- **Impact:** a 4m burst, 30 damage, lift 8, `spike` (+50%, stun 0.8 on foes already airborne).
  Burning ground for 2s (linger, 3 a tick).
- **Overcharged cast:** Heat resets to 0 without a Vent nova.
- **Combo:** a Sigil detonation lifts, the Meteor spikes.

**Dash: Blink** (DASHES §3.2). The residue rune covers the escape.

**Loop:** Sigil → bolts split through it → Heat to Overcharged → detonate the Sigil to lift → Meteor
spikes the lifted → Blink out before the Vent, or let it Vent on purpose as a peel.

**Level-up order:** 1 RMB · 2 E · 3 Dash · 4 RMB · 5 E · 6 R · 7 RMB · 8 E · 9 R · 10 Dash or Q.

| Rank-3 special | |
|---|---|
| RMB | the Lance pierces all |
| E | two Sigils at once |
| Dash | the residue rune's payload doubles |
| R rank 2 | an echo impact at 50%, 0.5s later |

**Counterplay:** a white-hot Mage is close to Venting; back off, or bait the Vent. Step out of Sigils
before the detonation flash. The Meteor's 1.0s is the longest tell in the game. Prefire the Blink sigil.

**Kin modifiers:**

| Kin | RMB Bolt | E Sigil | R Meteor |
|---|---|---|---|
| Vespyx | → **venom bolt**: slow → blight 3s + poison 8; the Lance poisons; mod pierce | detonation lift → barb pull 10 to the centre | burning ground → venom ground (linger poison); `exploit poisoned +0.3` |
| Gravadillo | → **pebble bolt**: slow → lift 4 (sets up the Meteor's spike); mod fallback +10% | → gravity well: pull 9, then lift (two beats, 0.12s) | spike bonus 0.5 → 0.6 |
| Prismander | → **prism bolt**: slow 0.25 → dazzle 0.4 for 1.0s; mod split (2 bolts at 15°; through the Sigil, 4) | + shield 12 to allies inside on detonation | + shield 15 to you on impact |
| Mycroll | → **spore bolt**: slow 0.4 for 1.2s; a second hit roots 0.6; mod linger (a 1.2m patch, 2s) | detonation lift → root 0.8 | burning ground → spore ground (slow 0.4) |
| Echolop | → **chain bolt**: slow → jolt 0.25; mod chain 2 (4.5m) | + reveal 3s on foes inside | mod repeat: a second impact at 50%, 0.9s later |
| Lunowl | → **gust bolt**: slow → push 8; mod return (the bolt comes back) | detonation lift → lift 9 + forward 4 (a fling toward your aim) | + push 10 outward + vulnerable 0.15; the dash gains **Moon Return** |

---

### 6.4 Gunslinger (medium)

> **Nov 1 (kits4):** the built kit and its numbers are in "Kit loops" at the end of this document; where they differ from this section, they win.

**Fantasy:** the duelist. A rhythm of six, trick shots off walls, slide and reload.
**Silhouette:** a wide-brimmed hat, a long split-tail coat that flares when moving, a hip holster
and bandolier. A side-on stance with the gun raised. The **primary feature is the brim and coat tails**.

**Weapons** (both fire the RMB Trick Shot; the Burst Rifle fires its tap as a burst):

| Weapon | LMB | RMB tap flavour |
|---|---|---|
| Rifle | hold; damage falls over the first 10 rounds | one ricochet round |
| Burst Rifle | 3-round bursts | 3 small ricochets (6 each, 1 bounce) |

Rail Charge (today's Rifle RMB) becomes the hold variant. Leash Bolt (today's Burst Rifle RMB) retires.

**Passive: Six Chambers.** Each weapon hit loads a chamber (at most one per 0.25s). A Slide Reload
tap roll loads 2. At 6, the gun glows gold and your next RMB is a **Called Shot**: +40% damage, a
guaranteed crit and stun 0.4. Chambers drain 1/s after 4s without a hit.
**Tells:** a gold barrel glow and a cylinder-spin click audible within 12m. HUD: a six-dot cylinder
around the crosshair.

**RMB: Trick Shot** (7s):

| Variant | What it does |
|---|---|
| tap | a ricochet round 9m at 60 m/s, 12 damage. It bounces off walls (up to 2) and off a struck foe to the nearest other foe within 5m (1). Each bounce is +20%. The aim preview draws the wall angles for you |
| hold up to 1.0s | **Rail Charge** (today's): pierces, 10 → 34 damage, 9 → 17m. At full charge, stun 0.6. A growing gold line shows enemies the charge |
| airborne / gliding | **Recoil Shot**: fire down and forward. You're kicked 3m up and back, and the target is pushed 6 |
| during E (Quickdraw) | fires two rounds; the second follows 0.1s later at 60% |
| 6 chambers | **Called Shot** |

**E: Quickdraw** (16s, utility): for 3s, fire rate +25%, an instant reload, one dash charge
refilled, and a perfect-dodge window twice as long on your next Slide Reload.

**R: Last Round** (level 6, 70s):

- **Channel:** 1.2s, slowed 60%. Gold lock lines draw to every enemy hunter within 12m and in sight,
  thickening over time. Targets see the line and "LOCKED".
- **Release** (or at 1.2s): one round per locked target, 16 + 12 × lock time (up to ~30). A target
  locked for the full time is stunned 0.5.
- **Counterplay:** breaking line of sight (walls, smoke, Prism Wall, Bastion) drops your lock.

**Dash: Slide Reload** (DASHES §3.2): tap roll or held slide. The roll feeds chambers.

**Loop:** hits load chambers → a tap roll adds 2 → a Called Shot ricochets off a wall into the
target → Quickdraw doubles the Trick Shot and refills the dash → Last Round on whoever's left in the open.

**Level-up order:** 1 RMB · 2 Dash · 3 E · 4 RMB · 5 Dash · 6 R · 7 RMB · 8 E · 9 R · 10 Q.

| Rank-3 special | |
|---|---|
| RMB | +1 wall bounce |
| Dash | a perfect dodge also loads 2 chambers |
| E | +1s |
| R rank 2 | 14m reach |

**Counterplay:** a gold barrel means a Called Shot is next, so stay off walls near you and bait the
RMB. The held slide is a long line. Break line of sight against Last Round.

**Kin modifiers:**

| Kin | RMB Trick Shot | E Quickdraw | R Last Round |
|---|---|---|---|
| Vespyx | + poison 6; each bounce blights 2s; the full Rail blights 4s | fallback +0.5s | + poison 8 per round |
| Gravadillo | + push 6 per hit (bounces knock people around); the full Rail pushes 10 | + shield 12 for the duration (guard) | rounds lift 4 (sets up spikes) |
| Prismander | + dazzle 0.3; mod split (2 rounds after the first bounce); the Rail dazzles 0.5 | + a 0.4s frontal reflect at cast (a parry window) | + shield 6 per target hit |
| Mycroll | + slow 0.3; mod linger at the last bounce; the full Rail stun 0.6 → root 1.0 | + shield 10 | + slow 0.4 for 2s |
| Echolop | mod chain 1 (+1 jump); + reveal 2s; the Rail gets `repeat` (50%, 0.6s later) | + reveal foes within 12m at cast | each round chains to 1 unlocked foe at 50% |
| Lunowl | + push 6; mod return (the round flies back along its path); the full Rail pushes 10 | + vulnerable 0.15 on your next hit | rounds push 8 away from you (edge kills) |

---

### 6.5 Juggernaut (heavy)

> **Nov 1 (kits2): superseded.** The Juggernaut was rebuilt as a port of SUPERVIVE's Brall (owner direction); the built kit is in "Kit loops" at the end of this document, and it wins where they differ.

**Fantasy:** the wrecking ball. Gets angrier, crashes through, slams you into the wall.
**Silhouette:** the biggest shoulders in the game, with horned pauldrons. Hunched forward, with an
oversized blade or a drum-fed shotgun and heavy dust footsteps. The **primary feature is the horned pauldrons**.

**Weapons** (both use the RMB Smash; the tap is a knock cone in each weapon's style, the hold is the same leap slam):

| Weapon | LMB | RMB tap flavour |
|---|---|---|
| Greatsword | slow 3-hit combo, tip bonus; hold 1s: slam stun 0.6 | Overhead Smash: a 3m cone, 18 damage, push 6 |
| Shotgun | 7 slugs in a 60° fan | Breach (today's): a point-blank cone pushes 13 and kicks you back |

Earthshatter (today's Greatsword RMB) becomes the hold variant. Breach stays as the Shotgun's tap.

**Passive: Rage.** +6 per hit (a pellet volley counts as one), +10 per 10% of max HP lost, +20 on a
wall slam. Decays 12/s after 3s out of combat. At 100 you're **Enraged** for 5s: your next RMB is
empowered (+50% knock; Earthshatter's radius +1m, and it stuns 0.6 everyone it lifts), and
Rampage's hold windup is 50% faster.
**Tells:** red steam from the pauldrons at 50+. Red eyes and weapon at 100, and a roar audible
within 25m when you become Enraged. HUD: a red bar under health.

**RMB: Smash** (9s, shared):

| Variant | What it does |
|---|---|
| tap | the weapon's knock cone (above) |
| hold 0.6-1.0s | **Earthshatter** (today's): leap up to 7m. The landing circle shows to all. A 3m burst: 20 damage, push 3, lift 8, `spike` (+60%, stun 1.0) |
| airborne / gliding | **Meteor Drop**: slam straight down where you are. A 2.5m burst: 16 damage, lift 6, spike (stun 0.6). You leave the glide at once |
| during E (Iron Hide) | the tap pulls foes within 4m in (pull 9) before the knock |
| Enraged | empowered (above) |

**E: Iron Hide** (16s, defensive utility): 3s of 30% less damage taken and knockback immunity, with
a cleanse on cast. When it ends, a 2.5m burst pushes 10 ("shrug off").

**R: Avalanche** (level 6, 75s):

- **Tell:** a 0.35s roar, with a column visible within 25m.
- **Then:** 5s **unstoppable** (immune to stun, root and knockback; slows at half strength), +30%
  move speed. A stomp every 0.5s: a 2m burst, 6 damage, push 6. The first wall slam on each foe
  stuns 1.0. Rampage charges refill at the start.
- **Counterplay:** kite it and keep away from walls. Damage still lands.

**Dash: Rampage** (DASHES §3.2): tap shove or held charge. The carry into a wall builds Rage.

**Loop:** brawl to build Rage → Rampage carries someone into a wall (+20 Rage) → an Enraged
Earthshatter lifts the group → a Meteor Drop from a jump spikes them → Iron Hide plus the pull tap to
hold the brawl → Avalanche to finish.

**Level-up order:** 1 Dash · 2 RMB · 3 E · 4 RMB · 5 Dash · 6 R · 7 RMB · 8 E · 9 R · 10 Q.
(The dash comes first because Rampage is the Juggernaut's way in.)

| Rank-3 special | |
|---|---|
| Dash | the hold windup is 0.7 → 0.55s |
| RMB | Earthshatter's spike stun +0.2s |
| E | the end burst pushes 14 |
| R rank 2 | 6s, and the first stomp is a 3m burst |

**Counterplay:** red steam means Rage is close; don't trade near walls. The Rampage arrow and
Earthshatter landing circle are both dodgeable. Kite during Iron Hide and Avalanche.

**Kin modifiers:**

| Kin | RMB Smash | E Iron Hide | R Avalanche |
|---|---|---|---|
| Vespyx | + poison 8; Earthshatter + blight 3s | the end burst + poison 10 | stomps leave a venom trail (linger poison) |
| Gravadillo | tap + a gravity-well pre-pull 8; Earthshatter + a pull on landing (Gravity Slam's two beats) and spike +0.3 | + shield 15 | stomps lift 4; Avalanche wall slams spike |
| Prismander | + dazzle 0.35 | + a 0.6s frontal reflect at cast | + shield 20 at the start |
| Mycroll | + slow 0.35; Earthshatter's landing leaves a spore patch (linger slow) | the end burst roots 0.6 | stomps slow 0.3 (a spore wake) |
| Echolop | mod repeat (an echo smash at 50%, 0.6s later); Earthshatter + jolt 0.3 | + reveal foes within 10m for the duration | each stomp echoes at 50% |
| Lunowl | tap push → 12; Earthshatter lift + forward 4 (a fling) | the end burst pushes 14 | stomps push 8 (they clear edges); Rampage's tap blinks |

---

### 6.6 Bulwark (heavy)

> **Nov 1 (kits4): superseded in part.** The Bulwark was rebuilt on a reference baseline (owner direction); the built kit is in "Kit loops" at the end of this document, and it wins where they differ.

**Fantasy:** the squad's shield. Holds the line, plants a banner, leaps in to save an ally at the edge.
**Silhouette:** a big rectangular tower shield, or a minigun with a front plate. A square crested
helm, a planted wide stance and a banner pole on the back. The **primary feature is the shield
shape and the banner**.

**Weapons** (RMB Shield on both; the minigun's shield is an energy plate you fire through, the tower shield is physical):

| Weapon | LMB | RMB hold flavour |
|---|---|---|
| Minigun | hold, 0.7s spin-up, slowed while firing (today's) | today's Bulwark plate: 3m, follows your aim, 160 HP; your shots pass through it |
| **Tower Shield & Mace** (new) | a 2-hit mace combo, 0.45s per swing, 2.4m, 120°; hold 0.8s for an overhead (24 damage, push 8) | a physical 140° front block; you can't swing while it's up and you move at 60% |

The shield's HP is 160, regenerating 20/s after 2s lowered. If it breaks, it's locked out for 3s. It
has no cooldown; it's HP-gated.

**Passive: Guard.** Damage blocked by your shield, your walls or your Interpose guard becomes Guard
(1 per 2 HP blocked, max 100). It decays 5/s out of combat. It's spent by:
- an empowered Bash (50);
- the Interpose ally-leap shield (20 for its +15 shield);
- Bastion (all of it: +1s per 50).

**Tells:** shield runes light in three steps (33, 66, 100); the crest glows at 100. HUD: a Guard bar
on the shield icon.

**RMB: Shield**:

| Variant | What it does |
|---|---|
| hold | raise the shield (weapon flavour above) |
| tap | **Bash** (6s): a 2.5m, 90° cone, 10 damage, push 8. Stun 0.8 into a wall |
| airborne / gliding | **Shield Surf**: hold to block from the front while gliding (frontal hits can't spike you); glider heat builds 25% faster while it's up |
| during E (inside the Banner's radius) | the shield is +1.5m wider (it covers allies), and a Bash heals allies behind you 8 |
| Guard 50+ | the Bash becomes **Shield Slam** (spends 50): push 12 and stun 0.6 even without a wall. A 0.3s shield flare is the tell |

**E: Rally Banner** (18s, utility): plant a banner totem up to 7m away for 6s (60 HP, 4m radius).
Allies inside get a shield of 6 per second (max 24). Foes inside are slowed 0.2.

**R: Bastion** (level 6, 80s):

- **Tell:** a 0.35s plant: the shield slams down and the dome outline appears.
- **Then:** a 4.5m dome for 4s.
  - Enemy shots from outside stop at it (a 600 HP ring).
  - On start, foes inside are pushed out (12).
  - Allies inside regenerate 8/s.
  - Bodies can still walk in.
  - It spends all Guard for +1s per 50.
- **Counterplay:** walk in and fight up close, or reposition and wait it out.

**Dash: Interpose** (DASHES §3.2): a braced step, or a leap to an ally. Both build and spend Guard.

**Loop:** block → Guard → Interpose to an ally in trouble → Banner over the fight → Shield Slam
whoever dives → Bastion when the squad is collapsing (bigger with more Guard).

**Level-up order:** 1 RMB · 2 Dash · 3 E · 4 RMB · 5 E · 6 R · 7 RMB · 8 Dash · 9 R · 10 Q.

| Rank-3 special | |
|---|---|
| RMB | shield HP +60 |
| Dash | the ally leap's range is 8 → 9m (a targeting radius, not travel) |
| E | the Banner's radius is 5m |
| R rank 2 | the dome is 5.5m |

**Counterplay:** flank the frontal shield. Glowing runes mean a Shield Slam is ready, so stay off the
front. Break the Banner (60 HP). Melee inside Bastion.

**Kin modifiers:**

| Kin | RMB Shield / Bash | E Rally Banner | R Bastion |
|---|---|---|---|
| Vespyx | the Bash + poison 8; melee hits on the raised shield poison the attacker 6 | foes inside are poisoned 2 a tick | the dome's edge poisons foes who cross it |
| Gravadillo | the Bash + lift 5 (spike setup); knockback immune while the shield is up | foes inside are pulled 4 toward the banner | two beats on start: pull 8, then push 12 |
| Prismander | the Bash + dazzle 0.35; blocked shots reflect at power 0.5 | + shield 4 per tick | the dome reflects shots at power 0.5 |
| Mycroll | the Bash + root 0.5 (stacks with a wall stun, capped at 0.8) | slow 0.2 → 0.35 | the dome's ring roots 0.6 foes who walk in (once each) |
| Echolop | the Bash gets `repeat` (50%, 0.6s later); blocked shots reveal the shooter 2s | + reveal foes within 6m | + reveal every foe within 12m for the duration |
| Lunowl | the Bash pushes 12 (edge shoves); shield: fallback +20 HP | allies inside move 15% faster | on start, push 16 outward (off the plateau) |

---

## 7. How this fits the grammar phases

| Phase | Was | With archetypes |
|---|---|---|
| 1 data model (done) | AbilitySpec, MergeSpec, KinSpec, EvolutionNode | + `ArchetypeSpec` (core, reviewed): weight, weapons, dash shape, passive resource, RMB variant ids, E, R, sockets. KinSpec + optional `infusion`. Weapons + `archetype` |
| 2 runtime executor (in progress) | runs stages, triggers, cues | + the archetype input router (tap/hold/air/during-E/resource → which AbilitySpec), socket resolution at load (kin parts baked into concrete stages, so the executor only runs plain stages), telegraph floors (DASHES §5.3), resource tracking |
| 3 budget and validator | tier caps, part prices | **prices sockets and the kin parts in them**. Checks every kin against every archetype and prints the result table. Flags fallbacks. Prices the dodge rider per dash shape |
| 4 rules text, look and sound | generated from parts | DASHES §5 is its spec. Generated text names the kin's change ("Venom Bolt: blights and poisons instead of slowing") |
| 5 (per the coordinator: the review of placeholder content) | the hunter-owned abilities mapped "to test coverage" and the `merged` patches marked "placeholders for review" in KIN_GRAMMAR | **replaced by this document.** The archetype kits are the reviewed hunter content. Merged patches retarget to the `rmb`/`e`/`dash` sockets. The review becomes: playtest the 6 × 6 tables. I couldn't find a written Phase 5 plan in the repo, so this row follows the coordinator's description |

**Migration notes:**

| Today | Becomes |
|---|---|
| Rail Charge, Earthshatter, Tripwire Mine, Breach, Bulwark, Shadow Step | archetype RMB variants (above) |
| Razor Disc, Leash Bolt, Riposte | retired as RMBs (the data stays and can return as gloves) |
| Kin E actives (Stinger Hook, Gravity Slam, Prism Wall, Puffcap Mines, Echo Chain, Moon Swap) | infusion sources. They're still playable as the kin's **auto** ability if desired, but the kin keeps one auto. Recommendation: keep each kin's current auto and archive the actives as infusion sources |
| `kin` slot | archetype E |

## 8. Open questions

- New weapons (Longbow, Spellstaff, Tower Shield & Mace) need art and firing data
  (WEAPON_FIRING_DATA.md style). Until they exist, the Archer, Mage and Bulwark run on one weapon each.
- Kin E actives: archive them, or rotate them in as alternative autos (a kin has 2 autos and the
  player picks one)?
- Six resources: is that too much to read in a 20-player match? Cut order: Gunslinger chambers first.
- Bonded R tuning: how often bond fills relative to the ult cooldown; whether to ship C′ (hold R to merge alone).
- Enemy level badges on nameplates: show the gold "R unlocked" rim, or keep it subtler?

## Sources

- Kinfall: `docs/KIN_GRAMMAR.md`, `docs/ABILITIES.md`, `docs/KINFALL_CLASSES.md`,
  `docs/SUPERVIVE_DATA.md` (§7 levels), `docs/DASHES_AND_ABILITY_FEEL.md`, `scripts/core/data.gd`,
  `scripts/core/game.gd` (binds), `scripts/match/hunter.gd` (XP_TO, ULT_AT, slot_lv),
  `scripts/ui/hud.gd` (portrait cluster), `content/weapons`, `content/kin_v2`
- SUPERVIVE structure references (public wiki): kit layout and contextual RMB, e.g.
  [Brall](https://supervive.wiki.gg/wiki/Brall) (tap, hold, airborne and during-Q RMB variants),
  [Oath](https://supervive.wiki.gg/wiki/Oath) (shield + Shift context), and build-up passives such as
  [Joule](https://supervive.wiki.gg/wiki/Joule) (Static), [Crysta](https://supervive.wiki.gg/wiki/Crysta)
  (Reverberation), [Celeste](https://supervive.wiki.gg/wiki/Celeste) (Chill),
  [Felix](https://supervive.wiki.gg/wiki/Felix) (Ignite), [Void](https://supervive.wiki.gg/wiki/Void)
  (Empowered). The full hunter list is in DASHES_AND_ABILITY_FEEL.md's sources.
- Readability references: [Riot, "Clarity in League"](https://riotgames.com/en/news/dev-clarity-in-league)
  (silhouette primary feature, clarity parity) and
  [80.lv Battlerite interview](https://80.lv/articles/battlerite-interiew) (read a character at a glance).

## Owner decision (Oct 31): kin keep their own abilities

Resolves the open question on kin E actives. Owner: "kins should have their own abilities as well,
but it doesn't affect the players abilities, rather the typing and maybe some other stuff".

- The archetype owns the player's kit (dash, passive, LMB/RMB, E, R). Kin never replace or restructure it.
- A kin's **typing** (its theme/effect family) infuses the archetype's sockets: it changes the
  *effect* riders on the player's abilities (burn, slow, chain, pull, shield...), within socket budgets.
- Each kin keeps **its own active ability**, cast by the kin on the kin key (C), with its own cooldown:
  e.g. Mycroll plants puffcap mines, Lunowl raises an updraft, Gravadillo slams, Prismander raises a prism wall.
  These are the kin's current actives, kept (re-expressed in grammar parts), not archived.
- Plus the kin's throw, owner bonus, carry mode (shoulder / perch / mount), companion utility
  (ride, carry-flight, bounce/launch pads, throw-you, grapple, shield, scout) and the Bonded R merge.

### Kin controls (owner, Oct 31): two keys, no hold (G default for send/recall, owner: MMB only as alternate)
- **C: kin ability.** Tap: the kin hops out, does its signature move at your aim, and hops back (own cooldown).
- **G (default; middle mouse as the alternate bind, rebindable): send / recall.** Throw the kin out to fight on its own
  (chase, guard, hold a choke); press again to recall. While it's out you lose its owner bonus and carry-mode perk.
- Mount and perch kin: C is still their ability; send/recall dismounts and remounts.

### Weapons under archetypes (owner question, Oct 31)
Weapons stay. Each archetype has its weapon family (Thief: twin blades or SMG; Gunslinger: rifles;
Juggernaut: greatsword or minigun; Archer: longbow/sniper; Mage: spellstaff; Bulwark: shield & mace).
- **The weapon defines LMB:** firing pattern, damage, range, magazine/reload, plus its loot roll:
  rarity, element and perks (the existing Loot system). Finding a better one mid-raid still matters.
- **The archetype defines RMB:** the same RMB on every weapon of the family, but it reads the weapon
  (e.g. the Thief's knife payoff differs for blades vs SMG, per §6.1). So swapping weapons changes
  your LMB and stats without breaking the kit.
- You can only pick up your archetype's family (today's class lock, narrowed to the archetype);
  other weapons can be stashed in the backpack to take home or trade.

## Implementation status (Oct 31)

Code: `content/archetypes/<id>.json` (numbers, variants, sockets, level order, tells), `scripts/arch/arch.gd`
(lookups, weapon families, the kin infusion), `scripts/arch/arch_kit.gd` (timers, the RMB router, Bonded R,
dash helpers, sockets through grammar parts, telegraphs, resource tells, HUD slot info),
`scripts/arch/kits/<id>_kit.gd` (one per archetype), `scripts/arch/feel.gd` (DASHES §5: telegraph floors,
hitstop and shake tiers, category colours, sound layers). Test: `--archetype-check` (122 checks).

- **Selection:** the creator has an Archetype row (it sets class and weapon with it); the expedition panel
  picks the archetype inside the class and lists only its weapon family. `Save.d["arch"]`, checked against
  the class (`Arch.of_save`). Bots pick an archetype of their class and a weapon from its family. The model
  always gets the real archetype (`Models.hunter(..., arch)`): looks never carry gear, remote players come
  with theirs (lobby presence, host snapshots), so nobody can look like an archetype they aren't.
- **Controls (keys_v 3; final kit keys4_v 1: R hunter ultimate, X Merge, no reload key):** E archetype utility, the kin casts its
  own active by itself (a mount lends it), G / middle mouse send-recall, Shift archetype dash, Q glove,
  RMB archetype. The training guide moved from G to H.
- **Weapons:** families narrow `Loot.usable` (others still pack and go home). Thief twin blades / SMG;
  Archer Longbow (new: hold-to-draw stages 0.4s/0.9s, Focus draws it instantly) / sniper; Mage Spellstaff
  (new: orb every 0.45s, every 4th +50%) / longsword; Gunslinger rifle / burst rifle; Juggernaut
  greatsword / shotgun / minigun; Bulwark Tower Shield & Mace (new: 2-hit mace, hold for an overhead; the
  shield is the RMB) / minigun. The owner's list puts the minigun with the Juggernaut and §6.6 with the
  Bulwark, so both can hold it.
- **Each kit:** dash, passive + resource (HUD bar under health, crosshair arc, enemy-visible glow/aura +
  sting at full), every RMB variant in the tables (tap, hold, air, during E, resource full), E and R with the
  tells listed, rank-3 specials, the level-up order (also the bot order).
- **Kin:** sockets per ability (`sockets` in the JSON) filled by `Arch.fill` from the kin's infusion
  (explicit `infusion` field, else derived), clamped to socket caps and budgets, fallback +10% per empty
  socket; mods added when compatible with the delivery. `Arch.infusion_table(ks)` prints a kin's result
  against all six. Dashes: travelling dashes take the existing rider; Blink, Grapple and the ally leap use
  the §3.4 streak rule (on_start / on_pass along the line / on_end), `repeat` gives the Blink recast and the
  Rampage second charge, `as: blink` gives Moon Return, the instant zip and the +1m arrow.
- **Bonded R (§5 C):** built. C′ (hold R to merge alone) is not.

Subsets and gaps:
- Sockets are generic (category match + delivery preference), not the hand-tuned 6x6 tables: e.g. Vespyx on
  the Thief knife gives poison 6.3 + a soft 0.3 stun (its hook's stun) rather than the table's pierce.
  Some named table effects (Echolop one-way smoke, Prismander reflect on blocked shots, Lunowl edge pushes on
  Heist) come out as their generic socket parts.
- `merged` patches on `rmb`/`e`/`dash` aren't read; a merged kin raises every socket budget x1.3 instead.
- Not built: the Mage's rank-3 "two Sigils", Trick Shot's +20% per bounce (bounces keep full damage), the
  Bastion ring's 600 HP shows no bar, the Rally Banner can't be shot down (60 HP not modelled), the Thief's
  silent knife only drops its sound (the streak still shows), Shield Surf heats the glider but doesn't stop
  spikes from the front specifically, Last Round lock lines are drawn as flickering bolts (no thickening mesh).
- Sounds are placeholders layered from the existing Sfx set (`Feel.DELIVERY_TELL`, `CATEGORY_IMPACT`,
  `SWEETENER`, `DASH_SOUND`); the level-up chime is a three-note layer of existing sounds.

## Ult fuse and cooldowns (owner, Oct 31)

"Ult base cooldown seems too low" and "ulting needs an animation for the fuse and then the effect
after". Every R now winds up before it fires (`r.fuse` in `content/archetypes/*.json`, run by
`ArchKit.use_r` / `_tick_fuse` / `_fire_r`): the hunter plants (35% move speed, no weapon fire), the
ult's name pops over them, energy gathers inward, a filling ring shows to everyone (hostile rim for
enemies, also sent to other players through the existing Net `fx` ring/bolt events), a sting plays and
the camera pushes in. Then the effect fires with an impact (ring, burst, flash, T4 shake, camera
punch). The cooldown starts at the fuse, so the slot reads as spent; R rank 2 is 15% shorter. A
Bonded R pours the Boki into the hunter during the fuse (kin-coloured streams from the Boki to the
chest) and the merge starts on the same frame the ult fires, with the BONDED column.

| Archetype | R | Cooldown | Fuse | During the fuse |
|---|---|---|---|---|
| Thief | none (kits2-nor: Jackpot is the fifth-Mark trigger) | | | |
| Archer | Skyfall Volley | 110s | 0.50s | vulnerable |
| Mage | Meteor | 105s | 0.55s | vulnerable |
| Gunslinger | Last Round | 100s | 0.45s | vulnerable |
| Juggernaut | none (kits2-nor: the Smash's rank-3 crash) | | | |
| Bulwark | Bastion | 120s | 0.50s | unstoppable (fortify) |

An ult that needs targets (Heist, Last Round) checks for them before the fuse, so a fuse never
fizzles; if everyone escapes during it, almost all of the cooldown comes back.

## Kit loops: every archetype at the Thief / Juggernaut bar (kits4, Nov 1)

The Thief (Marks -> Knife ready at 3 -> Cash In) and the Juggernaut (Rage -> Enraged -> Rage Smash)
set the bar for "oomph": one resource that the kit's own abilities build, a hunter that visibly
changes when the payoff is armed, and a named payoff that lands with T4 hitstop (the hit carries
`payoff: true`), a T4 shake, its own synthesized sound, VFX and a camera punch. The other four now
follow the same shape, through shared helpers in `ArchKit` (`armed_fx`, `payoff_fx`, `self_pips`,
`net_pulse`, `net_ring`/`net_bolt`, `terrain_behind`, `ready_label`, `e_payoff_ready`, `teardown`):

- **HUD:** the resource bar and crosshair arc as before, plus a pulsing label under the crosshair
  while the payoff is armed (`ready_label`) and the gold "ready" dot on the slot the payoff lives on.
- **Remote players** (whose games don't run your kit): the armed moment and every payoff send the
  existing Net `fx` ring / bolt events, and an armed kit pulses a ring under the hunter every 1.1s.
  The protocol shape is unchanged (no `Net.VERSION` bump).
- **Sounds:** `pay_deadeye`, `pay_flashpoint`, `pay_called`, `pay_slam`, synthesized by
  `tools/sfx_combat.py` (appended last, so no other sound changes).

### Archer: Lace (on a Myth-style hunter-archer baseline)

**Cut 2026-11-07 (owner, parity first):** the Focus meter and the Deadeye below were invented and are gone (no meter, no +20% range, no Deadeye hit, no HUD arc). Only Hawk Sense stays. Read the Focus and Deadeye lines in this section and the Nov 1 design above as history.

Owner direction (Nov 1): a hold-to-charge bow with stages you feel, a wall of falling arrows on E,
three empowered arrows on R. Mechanics only; names, numbers and art are ours.

| Slot | What it does |
|---|---|
| LMB (Longbow) | hold to draw: a creak and flash at stage 1 (0.4s, 30), a ping, flash and ring at full draw (0.9s, 60) that opens a 0.15s **perfect window**: let go inside it for +25% ("PERFECT", 75) |
| RMB | **tap: Snare** (8, root 0.6; on the ground a Tripwire). **Hold: Heavy Shot**, charged 0.5s -> full at 1.1s: 16 -> 30, push 6 -> 12, pierces 2, a bigger arrow; driven into a wall within 3m it stuns 0.8 ("PINNED"). In the air: Plunge |
| Dash | Grapple Arrow (unchanged) |
| Passive | **Focus** -> **Deadeye** (below) |
| E | **Hail Wall**: lob a volley up to 9m; 0.35s later (the strip fills, soft-CC floor) a 6m x 2.2m line of arrows rains across your aim for 3.75s: 5 every 0.5s, slow 35%, blight 1s (healing barely takes). A steady patter while it falls. During it the tap snare roots 1.0 |
| R | (removed in the accuracy pass, see docs/heroes/archer.md) **Great Arrows** (0.5s fuse): for 6s your next 3 shots need no draw: great arrows that fly 22m, pierce everyone, knock back and hit 28 / 28 / 44 (the third a payoff hit, T4, stun 1.0 into a wall). Heavy twang and boom, recoil, a big flash |

Snares (tap, Tripwire, Heavy Shot, the Great Arrow's wall stun) root or stun people; a snare or
Heavy Shot that hits adds 40 Focus (driven into a wall fills it). At 100 Focus the **Deadeye is
armed**: the next shot is drawn at once (+20% range) and, if it hits a **pinned** foe (rooted or
stunned, or within 0.8s of it), a gold second hit lands: +18 damage, a crit, T4.

- Tells: a lens glint at the bow from 50 Focus; at 100 a bright star with a light, a thin gold aim
  line along the shot, and crosshairs over every pinned foe within 18m (everyone sees them); the
  crosshair reads "DEADEYE READY" (or "GREAT ARROWS · n" during the ult).
- Payoff: "DEADEYE", the arrow's line redrawn in gold, `pay_deadeye`, T4 hitstop and shake.
- Numbers: Longbow Focus shot 60 + 18 = 78 into a rooted target. Note the existing combo system
  (`Combos.payoff`) also boosts a hit on a stunned target, so a Deadeye on a wall-PINNED foe reads
  about 108; it needs a full Heavy Shot into a wall first. Great Arrows 100 if all three land
  (Volley was 30 + a root over 2s, but area); Hail Wall ~35 over its life plus the slow and blight.
- Bots: snare first when the target isn't pinned; loose the Deadeye when armed and they're pinned;
  Hail Wall across a target's path from 3-10m; Great Arrows at a rival in a long clear line, then
  fire them through.
- Retired: Flare Arrow (E), Skyfall Volley (R).

### Mage: Rune -> detonate (Runeburst / Flashpoint), Hex, Blink and snap back

Owner direction (Nov 1): the Mage felt too close to the Archer; make it a tricky, mobile spell
duelist (LeBlanc-style combos; a Sinclair-style steerable RMB). Ideas only; our names and numbers.
The §6.3 design above (Bolt/Lance, Sigil, Meteor) is superseded by this:

| Slot | What it does |
|---|---|
| RMB | **Guided Bolt**: fires on the press (15 m/s, 2.2s); keep holding and it bends toward your cursor (6 rad/s), round cover onto a target. 10 damage, up to 22 after 1.6s in flight, a light slow; it **Runes** what it hits. A rising hum while it flies (remote players see its path as Net fx bolts). In the air: Starfall |
| Passive | **Runes and Heat**: your next spell on a Runed foe (a Bolt, a Hex, an echo) **detonates** it: a **Runeburst**, 16 + root 0.5, T4. Casting builds Heat (Bolt 15, Hex 25); Overcharged (70+) a detonation is a **Flashpoint**: 30 + 14 to everyone within 2.6m, root 0.8, all the Heat spent with no Vent, the Bolt back. 100 Vents (the risk stays) |
| E | **Hex**: a dodgeable bolt (20 m/s, 11m; a projectile, so it can be sidestepped or blocked) that turns a hunter into a harmless critter for 1.3s: half speed, no attacks, casts, dashes, gloves or glides; the model swaps for a hopping critter with a rune over it. Monsters are stunned 1s. On a Runed foe it detonates the Rune too (no root on top of the Hex) |
| Dash | **Blink**: a 0.12s windup (the landing sigil shows), up to 5.5m through walls; the sigil left behind slows foes 0.6s later and for 3s a second dash **snaps you back** to it (free) |
| R | **Encore** (0.55s fuse): two mirror images at your sides recast your last spell at full power, then echo every Bolt and Hex for 4s at 60% (their bolts steer with yours) |

- Loop: Guided Bolt round a pillar (Rune) -> Hex them (detonates: Runeburst, then they're a critter)
  -> Blink in, Bolt again; Overcharged, the detonation is a Flashpoint -> snap back out.
- Tells: rune motes orbit the Mage (one per 20 Heat), white-hot when Overcharged; a rune ring over
  every Runed foe (it throbs when the next detonation would be a Flashpoint); the crosshair reads
  "RUNED · hit it again" / "OVERCHARGED: FLASHPOINT". Payoffs: "RUNEBURST" / "FLASHPOINT", T4,
  `pay_flashpoint`.
- Hex online: `Hex.apply` sends a Net event `["hex", nid, seconds]`; every game shows the critter,
  the body's own game runs the rules. **Net.VERSION 0.4.0 -> 0.5.0** (a new event kind).
- Bots: Guided Bolts steered onto the target (their aim follows it while they hold), Hex rival
  hunters (always on a Runed one), Encore in range, Blink away when hurt and snap back once safe;
  a hexed bot scurries away from its target.
- Retired: Lance, Sigil (and the Sigil-based Flashpoint), Meteor.

### Gunslinger: Chambers -> Called Shot

Weapon hits load a chamber (one per 0.25s), a tap roll loads 2. At 6 the **Called Shot is armed**:
the next Trick Shot (or Rail, or Recoil Shot) is a Called Shot: +70% (a Rail takes half, +35%), a
crit, stun 0.4, T4 hitstop on its hits; when it lands the cylinder spins a full magazine in, so the
stun is your window to unload. Quickdraw (E) speeds the loading and doubles the Trick Shot.

- Tells: a gold six-pip cylinder over the hat fills pip by pip (everyone sees it) and spins at 6;
  the gun glows gold with a light at the muzzle; "CALLED SHOT READY" pops with the reload click and
  sits under the crosshair; the RMB slot gets the gold dot.
- Payoff: a gold muzzle flare and hammer crack on the call, then on the hit "CALLED SHOT", the
  round's line in gold, `pay_called` (a heavy round, a bell ting, the cylinder spinning), T4 shake.
- Numbers: the Called multiplier was `(1 + 0.4) x 1.5 = 2.1x`; now 1.7x (a Rail 1.35x). Trick Shot
  12 -> 20 called (was 25); a full Rail 34 -> 46 called (was 71); the two-target bounce case in the
  check 50 -> 41.
- Bots: a full cylinder taps a Called Shot within 9m; otherwise the Rail from range.

### Bulwark: Block -> Guard -> Crushed (rebuilt on an Oath-style shield-tank baseline)

Owner direction (Nov 1): base the kits on SUPERVIVE / League references, and make the Bulwark as
close to Oath as possible; mechanics only, our own names, art, sounds and numbers. The §6.6 design
above is superseded by this:

| Slot | What it does |
|---|---|
| LMB (Tower Shield & Mace) | **tap: throw the mace** 9m (16, passes through foes); it lies where it lands for 6s and shows foes within 4.5m of it to your team; tap again and it comes back to you, hitting on the way (10). **Hold: Crushing Blow**, 14 -> 34 damage and knock 4 -> 12 over 1.25s (full: stun 0.4); its wind-down carries you forward 3-8 m/s, so a jump out of it rolls into a glide. (`ArchKit.lmb_override`: the kit runs this weapon's attack; the minigun Bulwark fires normally) |
| RMB | **hold: raise the shield** (160 HP, regenerates 20/s after 2s down, broken = 3s lockout, you walk at 60%); **tap, or let go after a block: Bash** (2.6m cone, 12, push 9; you step into it). Guard 50+: **Shield Slam** (0.3s flare tell, 18, push 12, stun 0.6, spends 50) |
| Dash | **Whirl**: a 3.6m spinning dash, foes along it knocked aside (6, push 7). **Shield up: Shield Charge**: 4.2m behind the shield, invulnerable for its length, 10 and push 11 |
| Passive | **Guard**: blocked damage becomes Guard (1 per 2). **Crushed** (the payoff): a Bash, Shield Charge or full Crushing Blow that knocks a foe into terrain or another foe (within 1.5m behind them) stuns it 0.8 (+8 damage, T4), stuns the foe it hit 0.5, and heals you 14 |
| E | **Mending Ground**: marks ground up to 7m away, or where the mace lies; 1s later it bursts: allies inside heal 26, your shield mends 60, foes inside are slowed |
| R | (removed in the accuracy pass, see docs/heroes/bulwark.md) **Fissure** (0.5s unstoppable fuse): a crack runs 14m forward at 40 m/s (walls, rocks and rises stop it): 8 and stun 0.6 to everyone it passes; 0.35s later the line erupts in 3 pulses 0.3s apart (9 + slow 0.45 each). All Guard goes in: +1 pulse per 50 |

- Loop: raise the shield into their fire (Guard) -> Shield Charge or Slam them into a wall or into
  their teammate -> Crushed (stun, heal) -> a full Crushing Blow or the Fissure on the stunned.
  Throw the mace to scout a corner, then Mending Ground on it.
- Tells: three rune pips over the helm (33/66/100 Guard); at 50 a gold crest light, the raised
  shield burns gold, "SLAM READY" / "SHIELD SLAM READY". Payoff: "CRUSHED", `pay_slam`, T4.
- Bots: shield toward whoever is shooting, Bash up close, Shield Charge / Whirl in from 1.5-4.5m,
  Mending Ground when hurt or the shield is low, Fissure at 11m; LMB throws from range and winds
  up Crushing Blows up close.
- Retired: Interpose (ally leap), Rally Banner, Bastion.

### Six RMBs, six input patterns (owner: "all the RMBs mostly feel the same")

| Archetype | Input | Shape | Sound | Payoff |
|---|---|---|---|---|
| Thief | tap | a spinning Bola; the first foe it wraps is Grounded and it flies on; a second foe caught and both are stunned | a whirr, a cord snap, a stun clang | TANGLED; Marks |
| Archer | hold to charge, release | a heavy piercing arrow, knockback grows with the charge (0.5s -> 1.1s); tap drops a root snare | a creak rising to a ping, then a string-snap and a sniper boom | into a wall within 3m: PINNED (stun); feeds Focus for the Deadeye |
| Mage | press to fire, hold to steer | a slow glowing bolt that bends toward your cursor round cover, harder the longer it flies | a hum that rises with travel time | Runes the target; the next spell detonates it |
| Gunslinger | tap (hold = Rail) | a ricochet round off up to 2 walls and on to a second foe | a revolver crack, a hammer click, a ricochet whine | at 6 Chambers a Called Shot (stun, crit, reload) |
| Juggernaut | tap (wound up) / hold / air / in the pull | a Finishing Slam cone after a 0.5s aimed wind-up; hold a Lunge; air a Meteor Drop; in the chain pull a Scorching Spin | a charge hum, a cleave and a slam | the sweet spot is the payoff; at rank 3 it also crashes and heals |
| Bulwark | hold to block, release to bash | a frontal shield wall (its own HP), then a forward bash cone you step into | a shield clang, then a plate slam | into a wall or another foe: Crushed (stun + heal) |

### Holds and charges: the wind-up feel (shared, every archetype)

`ArchKit._tick_charge` watches every hold a kit has (a charged RMB via `rmb_charge_full`, a bow
draw, a melee charge such as the Bulwark's Crushing Blow, a held dash via `dash_charge`, e.g. the
Juggernaut's Rampage) and gives it one language:

- a rising wind-up voice in the archetype's own sound (`CHARGE_VOICE`: Thief swipe, Archer string
  creak, Mage zap, Gunslinger cylinder, Juggernaut thump, Bulwark shield): ticks that climb in pitch
  and volume and quicken as it fills;
- a filling ring at the hunter (enemies see the hostile rim) and a glow growing at the hand, with
  motes drawn inward;
- a clear "full" tick: `ab_ready` plus the voice an octave up, a flash at the hand, a ring;
- Net fx rings at the start and at full, so remote players read the wind-up;
- a release punch scaled by the charge (camera punch 0.06-0.32, a muzzle burst above half, trauma
  at full).

The Archer's bow adds its own stage ticks and the perfect window; the Mage's Guided Bolt hold is a
steer (its feedback is the bolt's rising hum). Covered by `--arena-check` (every archetype's hold:
ring, full tick, release) and `--ability-check` (the Gunslinger's Rail as an archetype hold).

### Rank previews: always the next rank

Owner: "why does it show me rank 3 but not rank 2 when it's rank 1?" Every archetype's data now has
`rank2` (a concrete line per slot, e.g. "cooldown 9s -> 8.1s, damage +15%") and `rank_next` (rank
3: the cooldown and damage at rank 3 plus its special). `Arch.next_ranks(arch, slot, rank)` returns
the next rank first, then rank 3 after it; the HUD ability tooltip ("Next · Rank 2: ..."), the
rank line ("next rank: ...") and the kit card's detail page ("Ranks: Rank 2 ... Rank 3 ...") use it.

## Kits2: the Thief and the Juggernaut ported from SUPERVIVE (Nov 1)

Owner: "do you think Thief and Juggernaut can be better too?", then: port them "as accurately as
possible, ability-wise, passive included" from the supervive.wiki.gg pages: the Thief is **Shiv**, the
Juggernaut is **Brall**. Every slot follows the wiki's input pattern, shape, conditions, resets and
upgrade path; numbers are scaled to our health and TTK (their relative sizes kept); only the names,
art, sounds and on-screen text are ours. They follow the kits4 conventions (hold wind-up feel,
next-rank previews, payoffs with T4 hitstop, shake, their own sound via `tools/sfx_combat.py`
(`pay_cashin`, `pay_rage`), a big word, VFX and a HUD ready label). Ranks: our rank 2 is the shared
step (cooldown -10%, damage +15%); rank 3 carries the wiki's level 3-4 specials.

### Thief = Shiv

| Slot | Input | Shiv (wiki) | Ours |
|---|---|---|---|
| Passive | none | **Malice & Resolve**: each consecutive basic-attack hit on a target adds a stack of bonus damage (LMB 1, empowered shot 2, Chain Bolas); a knock or an assist heals 25% max HP | **Marks**: every weapon hit stacks a Mark on the target (gold diamonds, one per Mark, up to 5; 4s, refreshed): +8% damage from your weapon hits per Mark. Primed hit +2, Bola +1. A knock heals 15% on top of the shared 10% knock heal (25%); an assist heals 25% |
| LMB | tap / hold | Arcslinger, one stack per hit | Twin Blades or SMG; every hit stacks |
| Shift | tap | **Quickflip**: a short dash and a speed boost; the next LMB is empowered (damage, 2 stacks, armor shred); landing it resets the cooldown; the speed boost ends on the empowered attack | **Vault**: a 3.4m flip, +30% speed until the next hit (2s max); the next weapon hit within 3s is **Primed**: +10, 2 Marks, Shred (+15% damage taken, 3s); landing it resets Vault (the payoff: VAULT RESET, T4, `pay_cashin`) |
| RMB | tap | **Chain Bolas**: grounds the first target, travels on after hitting; a second target hit stuns both and deals bonus damage | **Bola**: 10m, 6 and a Mark; the first foe is **Grounded** 1.5s (no dash, jump or glide; slowed 25%) and the Bola flies on 5m past them; a second foe it touches: both stunned 0.9 and +13 (TANGLED) |
| E (their Q) | tap, recast | **Farstep Dagger**: a dagger that sticks to surfaces or characters (slows 50% 4s); recast to teleport to it; after 6s you teleport anyway | **Shadow Knife**: 12m, sticks in the first foe (8, slow 50% for 2.5s) or where it stops; recast to step to it; after 5s you step anyway |
| R | tap | **Fusillade**: after a short delay, up to 5 shots at each nearby enemy over 2s, each resetting all stacks' duration; the outer ring takes bonus damage and anti-heal; 2 charges of a weaker dash; LMB usable | **No R (kits2-nor).** **Jackpot** is a Mark trigger: the fifth Mark on a foe releases 4 knives at it over 0.45s (4.5 each, in sight within 14m); each knife refreshes every Mark; one free Vault (2.8m, it Primes too) for 4s; it rests 8s. R is the Boki Merge |

Ranks (wiki levels 2-4 -> our ranks): Bola rank 3 flies 1m further after the first foe and two foes
caught pool their Marks (level 3 travel, level 3-4 stack combining); Vault rank 3: Primed hits +20% and
a Shadow Knife sticking in a foe resets Vault (levels 2-4); Shadow Knife rank 3: sticking refunds 25% of
the cooldown, 50% in a foe (level 3). (Jackpot used to have its own rank 2; as a Mark trigger it has no
ranks.)

- Loop: shoot one target (Marks stack) -> Vault -> the Primed hit (+2 Marks) resets Vault ->
  Vault again. Bola into two for the stun; the fifth Mark pays out Jackpot, which keeps every Mark alive
  and hands you a free Vault to carry on.
- Tells: gold diamonds over the target (spinning faster as they stack, a jingle at 5); a gold glint and
  light at the hand while Primed; crosshair "PRIMED · land it to reset Vault"; the dash slot's gold dot.
- Retired: Cash In (Shiv has no 3-stack payoff: the Primed reset is the payoff), Flicker, the old Knife /
  Fan / Drop Knife, Smoke Veil, Heist, the from-behind Mark rule.

### Juggernaut = Brall

| Slot | Input | Brall (wiki) | Ours |
|---|---|---|---|
| Passive | none | **Blazing Spirit**: dealing damage builds it; Empowered: +15% damage, +12% dash haste, +20% ability haste; knocking a hunter (or killing a creep) heals 20% of the enemy's max HP | **Rage**: damage you deal fills it (+0.7 per point; a Searing Wave fills it 3x as fast; cools after 3s out of a fight); full = **Enraged** 6s: +15% damage, +12% dash recharge, +20% cooldown speed (the red shell and swell stay). A knock heals 20% of the knocked hunter's max health; a monster kill 20% of its |
| LMB | tap / hold | **Quick melee** cone slash, the central tip deals bonus equal to the base; **hold**: a charged ranged fireblast that quickly builds Blazing Spirit | Greatsword (kit-run): slashes 8 every 0.34s, alternating, double at the tip (no heavier third: Brall's 3rd/4th-hit bonus was removed in a patch); **hold**: charge 0.22 -> 0.95s, a **Searing Wave** 6 -> 10m, 12 -> 28, through a line (full: burns, slows). Shotgun and minigun as before |
| RMB | tap / hold / air / with the chain | **Adaptive Strike**, 2.5s cooldown, 0.55s cast you aim freely with a warning overhead: press **Execution Slam** (x1.5 below 35% HP; its sweet spot resets R); hold **Fiery Lunge** (charged dash attack; cooldown doubled on a miss); airborne **Obsidian Slam** (slows; the centre ring +50%, stunned); during the chain pull **Scorching Spin** (anti-heal 5s) | **Smash**, 3s: tap a 0.5s wind-up (a red "!" over you, keep aiming) into a 3.2m cone, 26, +50% under 35%; its **sweet spot** (the far tip, 1.9-3.4m within 22° of your aim) is the payoff (SWEET SPOT, T4, `pay_rage`); at rank 3 it also crashes (see R below). Hold: a 3 -> 7m Lunge, 14 -> 22; a miss doubles the cooldown. Air: Meteor Drop 2.6m, 18 and slow 40%; the centre 1.2m +50% and stun 0.8. With the Warchain: see the combinations below (Scorching Spin, Chain Lunge, Haul Slam) |
| Shift | tap | **Flame Step**: 2 charges, a dash attack in the facing direction; the tip deals double; a knock restores a charge | **Rampage**: 2 charges, 4.4m the way you face: 7 along it, the tip 14 and a big knock (stun 0.8 into a wall); a knock gives a charge back (the shared knock rule) |
| E (their Q) | tap, recast | **Feysteel Chain**: attaches to an enemy (damage, anti-heal) or a wall; recast pulls you to it; the cooldown starts on the pull or when it breaks; a stun breaks it; not castable while rooted or grounded | **Warchain**: 10m, hooks a foe (8, blighted while tethered) or bites a wall, 4s; recast pulls you; the cooldown starts on the pull or the break (a miss breaks it); a stun breaks it; no throw while rooted or Grounded |
| R | tap | **Volcanic Rebuke**: invulnerable 0.65s, then a strike that heals 60% of the damage dealt; a knock resets its cooldown | **No R (kits2-nor).** Folded into Smash rank 3: the sweet spot also brings a **crash** down (3m, 24, push 7, heals 60% of the damage it deals); it rests 12s, and a knock on anyone it hit within 2s makes it ready at once. R is the Boki Merge |

### E + RMB combinations and the other cross-ability interactions

`--kit-combo-check` scripts each of these and asserts the variant that fires (it also runs inside
`--archetype-check`). "Wiki" rows are SUPERVIVE's own interactions; "owner" rows are the owner's
asked-for chain combinations ("E, charge RMB, then use either to affect the swing"), each with its own
pose, sound and VFX.

| Hero | Sequence | Result | Source |
|---|---|---|---|
| Juggernaut | E (hooked) -> E (pull) -> RMB tap | **Cinder Spin**: 2.6m spin, 18, blight 4s; a full-body double spin, orange slash rings, a whirr and blast | wiki |
| Juggernaut | E (hooked or anchored) -> hold RMB -> let go | **Chain Lunge**: the Lunge runs along the chain to its end (x1.25, a 0.35 stun, RUN THROUGH); the chain hand hauls back, gold chain flash, a tether snap and a rising charge; the chain is spent | owner |
| Juggernaut | E -> hold RMB -> E while holding | **Haul Slam**: pulled in with the charge, a crash where you arrive (2.8m, 16 -> 30 by charge, stun 0.25 -> 0.6); the blade cocked high through the pull, then the drop; gold ring, dust, slam and boom | owner |
| Juggernaut | E -> E (pull) -> hold RMB | **Haul Slam** on arrival (or at once if the pull is over) | owner |
| Juggernaut | E attached -> RMB tap | the normal **Finishing Slam** (wound up, aimed) | wiki |
| Juggernaut | RMB tap, sweet spot (rank 1-2) | the SWEET SPOT payoff (T4) | wiki |
| Juggernaut | RMB tap, sweet spot (rank 3) | the payoff **and a crash** on the foe (3m, 24) that heals you 60% of its damage; it rests 12s | wiki (Volcanic Rebuke, folded in) |
| Juggernaut | the crash, then a knock on someone it hit (2s) | **the crash is ready again**; the knock also heals 20% of their health and gives a Rampage charge | wiki |
| Juggernaut | RMB hold that strikes nothing | the Smash cooldown **doubles** | wiki |
| Juggernaut | Rampage / Lunge, then glide | no glider for the wind-down (0.35s) | wiki (patch notes) |
| Juggernaut | rooted / Grounded -> E | no chain; a stun on you breaks a chain (its cooldown starts) | wiki (patch notes) |
| Juggernaut | Enraged (full Rage) | +15% damage, +20% cooldown speed (every Smash, the chain), +12% dash recharge | wiki |
| Juggernaut | Searing Wave hits | fill Rage 3x as fast | wiki |
| Thief | Vault -> weapon hit | **Primed**: +10, 2 Marks; Vault resets; the speed boost ends | wiki |
| Thief | Shadow Knife in a foe (rank 3) | Vault resets; 50% of the Knife's cooldown back (25% in a wall) | wiki (levels 3-4) |
| Thief | Shadow Knife -> E (or wait 5s) | step to the knife (the arrival pose) | wiki |
| Thief | Bola catches two (rank 3) | both foes' Marks pool | wiki (levels 3-4) |
| Thief | Bola -> Grounded foe | can't dash, jump or glide | wiki |
| Thief | fifth Mark on a foe | **Jackpot**: 4 knives at it, every knife refreshes all Marks; it rests 8s | wiki (Fusillade, made a trigger) |
| Thief | Jackpot -> Vault | one free Vault (no charge) that Primes; its Primed hit resets Vault too | wiki (the Prime on the free Vault is ours: the wiki doesn't say) |
| Thief | knock / assist | heal (25% in all) | wiki |

### Animations (kits2): every ability has its own move

`HunterAnim.KMOVES` holds keyed full-body moves (anticipation, a key pose on the hit, follow-through)
that the kits play with `ArchKit.play(id)`, timed to their hit: channels for the torso, the legs, the
free hands, the greatsword's arc and whole-body turns (flips, spins). Juggernaut: the slashes
alternate (no heavier third, as Brall's), `jug_wave` (the raised charge carving down into a lunge),
`jug_slam` (0.5s rearing wind-up, the crash on the hit), `jug_lunge_wind` / `jug_lunge`, `jug_meteor`,
`jug_dash` (shoulder-down, the tip thrust at the end), `jug_chain` / `jug_reel`, `jug_spin`,
`jug_chainlunge`, `jug_haul_wind` / `jug_haulslam` (`jug_doom` went with the R; the rank-3 crash
uses `jug_slam`). Thief: SMG recoil and the twin blades' arcs as before, `thf_vault_f/b/l/r` (a tucked flip by
the dash's direction), `thf_primed`, `thf_bola` (whirled, then slung: the Bola leaves the hand 0.14s
in), `thf_knife` (cocked by the ear; the knife leaves 0.12s in), `thf_arrive`, `thf_volley` (0.7s, the
Jackpot burst). Strips: `--arena-demo=anim_<move>` (see `ArenaDemo.ANIM_DEMO`). Kit moves play on the
hunter's own game and bots, and since Net 0.15.0 on remote players too: the move id and its age ride the
hunter snapshot (indices 31-32, `ArchKit.net_move` / `apply_net_move`).

Ranks: Smash rank 3 +20% on every Smash and the sweet-spot crash (levels 2-3, and Volcanic Rebuke); Rampage
rank 3 a third charge (level 2); Warchain rank 3 refunds 33% when it hooks a foe (level 4).

- Loop: slash and wave into Rage -> Enraged (everything comes back faster) -> chain them, pull in and
  spin -> Rampage tip -> an Finishing Slam's sweet spot (rank 3: the crash and its heal) -> the knock
  makes the crash ready again.
- Tells: red heat at the pauldrons that grows with Rage; the Enraged shell, swell and roar; the red "!"
  over the head while a Smash winds up; crosshair "ENRAGED" / "SMASH · aim it".
- Retired: the Rage Smash (Brall's Empowered state buffs everything instead of one strike), the
  tap/hold Rampage carry, Earthshatter, Iron Hide, Avalanche, the chain's slow, leash and haul stun.

### Sources cross-checked (Nov 1)

- supervive.wiki.gg **Shiv** and **Brall** pages (ability text, levels 2-4, the patch history per
  ability) are the baseline for everything above.
- Wiki patch pages: *Leveling Rework + Big Balance Patch* (Brall: LMB hitbox -20%, sweet spot moved to
  the central tip, the 3rd/4th consecutive-hit bonus removed, Empowered attack speed +100% -> 0%, R no
  longer resets on Wisp execution, Flame Step charges 10/6/6/6 and no longer refunds all charges);
  *Gold + Mobility + Discord Patch* (Brall: Adaptive Strike cast 0.35 -> 0.55s with a warning icon and
  free aim, Execution x2 -> x1.5 and threshold 45% -> 35%, Flame Step 11/9/7/6, the chain 18/16/14/12
  with the level-4 refund 50% -> 33%, breaks on stun, no cast while rooted or grounded, dash wind-down
  frames, turning restricted after RMB -> Shift); *Patch Week 1 Open Beta* (Shiv: LMB range 800 -> 850,
  empowered 925 -> 950); *Patch Open Beta* (Brall's LMB a slice, not a box; Shiv's dagger sticks to
  dynamic objects; +30 health for all).
- Guides: gamerblurb's Brall guide (Execution Slam "double damage" to low health, Lunge "missing doubles
  mana cost and cooldown", the spin during the chain pull, a "four-hit" LMB with later hits stronger);
  deltiasgaming's Brall guide (the four RMB forms, a "four-hit combo"); ludo.guide (template only, no
  data); gamerblurb's Shiv page and esports.gg's hunter list failed to load.
- Disagreements: the guides' "double damage" and "four-hit combo, later hits stronger" are pre-patch
  (the wiki's patch history lowers execution to x1.5 and removes the combo bonus): we follow the wiki.
  Brall's Flame Step cooldown differs between the wiki header (13s) and the patch notes (11/9/7/6); we
  use the patch notes' shape. The Shiv page lists Farstep's Quickflip reset at level 3 in its patch note
  and level 4 in its tooltip; ours is rank 3 (our last rank). No source gives Malice's cap or duration.

### Couldn't reproduce (or chose not to)

- Mana: none of it (costs, refunds on hit, the Lunge's double cost) exists in our game.
- Brall: climbing double-height walls; dodging shots building Blazing Spirit (his level-4 dash
  upgrade); Volcanic Rebuke sending a knocked hunter straight to the deathbox (ours resets but the
  knocked hunter goes down as usual); turn restriction when dashing out of a Smash.
- Shiv: Farstep Dagger sticking to moving objects other than hunters and monsters; Bolas hitting
  destructibles; whether the weaker Fusillade dashes empower (ours do).
- The wiki gives no Malice stack cap or duration (ours: 5 and 4s) and no Blazing Spirit duration
  (ours: 6s Enraged). Online, Grounded, blight and Shred go through Net event `["kst", nid, kind,
  seconds, k]` (`KitStatus`); **Net.VERSION 0.6.0 -> 0.7.0**. The kit move id rides the hunter snapshot
  from **Net.VERSION 0.15.0**.

### Numbers against the other four (TTK)

Shiv's scale: LMB 58, a stack ~9 (15% of a shot), empowered 50, bolas 23 (+53 with two), R shot 25
(+17 rim). Ours keeps those ratios on our weapons: blades 7 / SMG 4.6 a hit, +8% a Mark (capped at 5
for the SMG's rate), Primed +10, Bola 6 (+13 tangled), Jackpot 4.5 a knife (4 of them). Brall's: slash 20
(tip +20), Execution Slam 70 (3.5 slashes), Lunge 45, Obsidian 52, Spin 54, Flame Step 18 / tip 36, R
130 -> ours slash 8 (tip 16), Slam 26, Lunge 14 -> 22, Meteor 18, Spin 18, Rampage 7 / tip 14,
the crash 24. A medium (145) falls to the Thief in about 4s of steady fire with two Primed hits, to the
Juggernaut in about 4s with a sweet-spot slam (rank 3 adds the crash on top).

### R removed: the ult choice (kits2-nor, Nov 2)

Owner decision (Nov 1): R becomes the Boki Merge for every hero, so the Thief and Juggernaut lose
theirs. Rather than drop the wiki's ultimates, each is folded into the kit where it already fits:

- **Doomfall -> Smash rank 3.** The Smash's sweet spot already was Doomfall's reset trigger, so at rank
  3 landing it brings the crash down (3m, 24, push 7, heals 60% of the damage dealt); a knock within 2s on
  a foe it hit makes it ready again (the old reset rule), and it rests 12s so it is a moment, not a loop.
  The 0.6s invulnerable rise is gone: the Smash's own 0.5s wind-up is the tell.
- **Jackpot -> a Mark trigger.** The fifth Mark on a foe releases 4 knives at it over 0.45s, each
  refreshing every Mark (the Fusillade's rule), plus one free Vault; it rests 8s. The all-foes 2s volley,
  the rim ring and its blight are gone.

`docs/heroes/thief.md` and `docs/heroes/juggernaut.md` carry the per-slot tables and the checks that
assert each combination. The class-ultimate framework (`ArchKit.use_r`, `class_ults`) stays for the
other four kits; a kit with no `"r"` in its JSON refuses the press.

## Hero rebuild: Sparkle (mage) and Vex (gunslinger), Nov 1

The Mage (medium, Hex/Runes) and the Gunslinger (Chambers/Called Shot) kits are replaced by two new
heroes under the same ids: **Sparkle** (id `mage`, now Light: Sparks, Wirerun, Coilshot, Skycall) and **Vex**
(id `gunslinger`, Medium: Fever, Slipstep, Burr Charge, Longneedle). Neither has an R (the Boki Merge owns it).
The old Mage and Gunslinger sections above are history. Per-slot tables, research notes and combinations:
`docs/heroes/mage.md` and `docs/heroes/gunslinger.md`; combos are checked by `--mage-combo-check` and
`--gunslinger-combo-check`. `Hex` (scripts/arch/hex.gd) is no longer used by a kit.

## Inspired by (per hero)

The one place the hero docs point to for traceability (the per-hero files in `docs/heroes/` do not name other
games' heroes). Mechanics only: every name, number, text, look and sound in the game is ours.

| Archetype | Hero | Reference hero's public page | Notes |
|---|---|---|---|
| `thief` | Thief | [Shiv](https://supervive.wiki.gg/wiki/Shiv) | Ported ability by ability (Kits2 above) |
| `juggernaut` | Juggernaut | [Brall](https://supervive.wiki.gg/wiki/Brall) | Ported ability by ability (Kits2 above) |
| `archer` | Archer | [Myth](https://supervive.wiki.gg/wiki/Myth) | Accuracy pass: `docs/heroes/archer.md` |
| `bulwark` | Bulwark | [Oath](https://supervive.wiki.gg/wiki/Oath) | Accuracy pass: `docs/heroes/bulwark.md` |
| `mage` | Sparkle | [Joule](https://supervive.wiki.gg/wiki/Joule) | `docs/heroes/mage.md` |
| `gunslinger` | Vex | [Ghost](https://supervive.wiki.gg/wiki/Ghost) | `docs/heroes/gunslinger.md` |
| `ashwick` | Cinder (was Ashwick) | [Felix](https://supervive.wiki.gg/wiki/Felix) | `docs/heroes/ashwick.md` |
| `dredge` | Grimble | [Kingpin](https://supervive.wiki.gg/wiki/Kingpin) | `docs/heroes/dredge.md` |
| `tender` | Meeko, the Tender | [Elluna](https://supervive.wiki.gg/wiki/Elluna) | `docs/heroes/tender.md` |
| `rimewright` | Neve, the Rimewright | [Celeste](https://supervive.wiki.gg/wiki/Celeste) | `docs/heroes/rimewright.md` |
| `dolm` | Tenzo | [Tetra](https://supervive.wiki.gg/wiki/Tetra) | `docs/heroes/dolm.md` |
| `ostra` | Motley | [Void](https://supervive.wiki.gg/wiki/Void) | `docs/heroes/ostra.md` |

## Kit parity lock
`content/rules/kit_parity.json` holds sourced kit numbers (hero, slot, `field` = dotted path into `content/archetypes/<hero>.json`, `value`, `tol`, `evidence`). `--kit-parity-check` fails when the JSON drifts outside `value ± tol`, so a retune of a matched number is a deliberate edit of both files. It sits beside the combo checks (which assert our spec); this one asserts the source.
- **Add a row** for a number in the source: `[D]` evidence from `briefs/supervive-data` (file:line), cooldowns at level 1 included (PARITY FIRST: 1.0x unless the owner says otherwise). A row whose value differs on main FAILS and is listed for a kit fix; it is never loosened.
- **Owner override:** a row main may not match because the owner said so carries `"owner": "<DECISIONS date and note>"` and `"ours": <the pinned value>`; the check prints OWNER and still fails if ours drifts.
- **Other files:** `field` and `per` may read another content file as `"weapons/quill_rifle:primary.dmg"` (`content/<file>.json`, then the dotted path); a number in an array is `smash_dmg.0`.
- A damage ratio takes `"per": "<path of the divisor>"` (e.g. slam damage per LMB damage) and a tolerance (12% of the ratio). Oath, Joule, Shiv, Tetra and Void damage is read at level 15 in the data, so only ratios to the same kit's other hit are usable.
- Change a number on purpose: edit the JSON and the row together, and say which source or owner call moved it.
- Run: `godot --headless -- --kit-parity-check` (temp `XDG_DATA_HOME`).
