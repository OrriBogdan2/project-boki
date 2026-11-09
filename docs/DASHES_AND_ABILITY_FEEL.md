# Dashes and ability feel

Status: **built** for the archetype dashes and the global feel spec (`scripts/arch/feel.gd`,
`scripts/arch/kits/*`); see docs/ARCHETYPES.md "Implementation status". Floors are inserted for rivals'
casts and for every cast online (each client runs its own hunter); your own offline casts stay as
authored. Online hitstop is per-entity and visual only (`Ent.freeze_t`). It covers three things: a distinct dash for every archetype and for
every archetype + kin pairing, a feel pass on every current kin ability and merge, and one global
"feel" spec. The feel spec is derived from the grammar parts, so a community kin gets the same
telegraphs, hitstop, shake, sound and colour rules without writing any of them.

It follows the archetype model in `docs/ARCHETYPES.md`:

- the **weight class** (light, medium, heavy) sets dash **charges, recharge, air dash and mass**;
- the **archetype** (Thief, Archer, Mage, Gunslinger, Juggernaut, Bulwark) sets the dash's **shape
  and input**;
- the **kin** adds nothing: dodge riders are retired (§3.4).

Until archetypes ship, the three current class dashes stay as they are. Phase Step grows into the
Thief's Flicker, Combat Roll into the Gunslinger's Slide Reload, and Shoulder Charge into the
Juggernaut's Rampage. Archer, Mage and Bulwark get new dashes.

Research section 1 is SUPERVIVE-only and comes from the public wiki. Section 2 adds LoL, Battlerite,
Smash, Street Fighter, Overwatch and general game-feel sources. Nothing here comes from game files.
No SUPERVIVE hunter names, kits or numbers are copied into Kinfall content. They only informed the
patterns.

---

## 0. Principles (the short list everything else follows)

1. **Every dash differs in input or shape, not just numbers.** The six archetype dashes use six
   different inputs: double-tap steps, an aimed grapple, a telegraphed blink, tap-or-hold slide,
   hold-to-charge, and context-targeted. Kin riders then change what the dash does, never how it's pressed.
2. **Both sides must see a cast happen.** Every ability has an enemy-readable tell, a body (travel
   or channel) and an impact. Hard CC is never faster than a human can react to (section 5.3).
3. **Fill colour says what it does, rim says whose it is.** Effect category picks the colour of
   ground decals and impact flashes. Allegiance picks the rim and pattern. A kin's theme only tints particles.
4. **Oomph is budgeted.** Hitstop and shake scale with what actually happened (chip, solid hit,
   CC landed, payoff, finisher), are capped, and are mostly felt by the two people involved. Twenty
   players' worth of juice on one screen turns to noise.
5. **Kits are setter → payoff.** Each kin has one thing it sets up (poison, lift, reflect, slow/root,
   reveal/jolt, displacement) and one part that cashes it in. A small grammar addition, `exploit`
   (5.9), lets data express the payoff.

---

## 1. Research: how SUPERVIVE hunters' movement abilities differ

Source: each hunter's page on supervive.wiki.gg, read Oct 2026 (the game shut down Feb 2026, so
these are final values; see docs/SUPERVIVE_DATA.md for eras). The wiki almost never publishes dash
distances or speeds. Where it doesn't, the column says "n/l" (not listed). "Knock" means downing an
enemy hunter. "Ex-dash" means the long dash you get in the air or while the main dash is on cooldown.

| Hunter | Dash | Input | Charges / recharge | Arrival / payload | Protection | Counterplay notes |
|---|---|---|---|---|---|---|
| Jin | Dodge Roll | tap toward cursor; ex-dash in the air or when on cooldown | 1; 7s mini / 12.5s ex | none (pure mobility) | n/l | two separate cooldowns you can track |
| Shiv | Quickflip | tap | 1; 6.5s | movement speed burst; next shot empowered; **landing that shot resets the dash** | n/l | punish the dash if the empowered shot misses |
| Myth | Phase Walk | tap into a roll, then a 2.8s state | **2 charges**, 11s; knock restores 1 | walk through walls and objects; leaves a phase orb others can use; taking damage ends it | through walls only | hit her once to end it |
| Shrike | Disengage | tap; fires a shot that **propels her backward** | 1; 11s; knock resets | the shot slows and grounds who it hits | n/l | she always moves away from her aim |
| Brall | Flame Step | tap, forward | **2**, 13s listed (patched 11/9/7/6 by level); knock restores 1 | dash-attack with a tip sweet spot (damage ×2) | n/l | wind-down frames stop an instant glide after it |
| Carbine | Thrusters / Jetpack | tap; Jetpack is the ex version (0.8s hover, pops over low obstacles) | 1 + ex; 12s / 12s | next shot empowered and slows | n/l | LMB hits refund only the base dash |
| Crysta | Double Dash | tap | **2**, 15s; knock restores 1 | each dash empowers a double shot and resets LMB | n/l | short dashes, so watch for the second |
| Joule | Surge | **hold and release** | 1; 9s; resets off her own passive and orbs | dash-attack through targets; detonates her static marks | **ignores projectiles** (melee and CC still land; stun, root, ground and glider cancel it) | melee or CC her, don't shoot |
| Saros | Dive Slash | tap dive, then **recast** a slash | 1; 10s; a hit allows one more cast | dive pushes; slash knocks back, double damage and stun into a wall; can kick his orb | n/l | the recast is the threat |
| Wukong | Cloud Somersault | **tap = quick dash, hold-release = somersault into the air** | 1; 14s; perching in a tree resets it | attack speed +50% briefly | n/l | resets near trees |
| Bishop | Rocket Jump | tap; launches **up** | **2**, 14s; knock restores 1 | blast at the feet, knockback; hitting enemies from above slams them | n/l | he lands where his arc goes |
| Kingpin | Dash | tap; goes further in the air | 1 + separate air; 7s / 14s | a level-4 upgrade ties it to his shotgun | n/l | two cooldowns |
| Felix | Pyro Pounce | tap | **2**, 9s; knock restores 1 | dash-attack, knockback, ignite; bounces him back a little on impact | n/l | he ends up next to you |
| Oath | Spin Dash / Shield Bash | tap = spin dash; **with shield held (RMB) = Shield Bash** | 11s / 7s | spin damage and knock; bash knocks back and the shield is briefly invulnerable | shield only | the context version changes the threat |
| Elluna | Lunar Dash | tap; ex in the air | 1 + air; 7s / 14s | **dashing through allies refunds half the cooldown** | n/l | support movement |
| Zeph | Cyclone Dash | **tap = short dash (partial refund), hold = summon a cyclone, release = long dash carrying allies** | 1; 11s | gives allies glider fuel; can carry ally wisps | n/l | the hold is visible |
| Eva | Sashay | tap | 1; 8s | 80 bonus speed decaying over 2s | **incorporeal 0.1s** | mostly a speed boost |
| Beebo | Shwoop | tap | **2**, 8s; knock restores 1 | decaying speed buff | n/l | — |
| Celeste | Skate | **hold to skate, release to stop**; early release refunds cooldown | 1; 13s | her shots do ×2 while skating; makes ice islands over the abyss | n/l | long, steerable, predictable |
| Hudson | Hover Jets | tap = speed burst; **hold = hover up to 1.4s** (longer cooldown) | 1; 12.5s; hitting refunds 25% | ram for 100 (300 spun up), knockback scales with speed | n/l | ram is speed-based |
| Mercury | Backblast | tap; blasts **backward and up** | 1; 12s | goes further with charged rockets; nearby enemies knocked back, stunned into walls | n/l | always away from his aim |
| Void | Swap | **aimed lob to a point**, travel time 1.7s (1.25s empowered), then teleport | 1; 9.5s | **swaps places** with units at the spot; enemies swapped are slowed 40% for 3s | n/l | the lob shows the destination for 1.25-1.7s |
| Tetra | Landslide | tap | 1; 12s | makes a rock, dashes, then launches the rock forward | n/l | the rock is a projectile to dodge |
| Ghost | Combat Slide | **tap = short slide, hold = longer slide**; early release lowers the cooldown | 1; 11.5s (min 3.5s); knocks reset | movement speed at the end (level 4) | n/l | the hold slide is long and committed |

Two other movement tools sit outside Shift but are useful patterns: Shiv's Farstep Dagger (throw a
dagger, auto-teleport to it after 6s or recast early) and Brall's Feysteel Chain (chain to an enemy
or wall, recast to pull yourself in).

### Patterns

| Pattern | Who | What it gives the design |
|---|---|---|
| Multi-charge short dashes (2 charges, knock restores 1) | Myth, Brall, Crysta, Bishop, Felix, Beebo | rhythm; a "did they spend both?" read for enemies |
| Tap vs hold on one key | Wukong, Zeph, Hudson, Ghost, Celeste, Joule | one button, two jobs; the hold is a visible commitment |
| Dash-attack (damage or knock on contact) | Brall, Joule, Felix, Saros, Hudson, Oath | dashes become part of the combo, not just escape |
| Dash that empowers the next shot / resets on hit | Shiv, Carbine, Crysta | ties the dash to the weapon (kit cohesion) |
| Backward self-propulsion off a shot | Shrike, Mercury | disengage you can only aim away from |
| Vertical (rocket jump, somersault) | Bishop, Wukong, Carbine Jetpack | high ground and abyss play |
| Telegraphed teleport to a point | Void (1.25-1.7s lob) | a long teleport made fair by a visible destination |
| Context variants (with shield, in the air, during another ability) | Oath, Jin/Kingpin/Elluna ex-dash | the same key reads differently in different states |
| Partial-projectile immunity rather than full invulnerability | Joule (ignores projectiles), Eva (0.1s incorporeal) | counterplay survives: melee and CC still land |
| Ally interaction | Elluna (refund through allies), Zeph (carry allies) | support identity in movement |

Takeaways for Kinfall:

- Almost nobody gets long full invulnerability. Protection is short (around 0.1s) or partial
  (projectiles only). Kinfall's existing 0.08-0.16s invulnerability frames fit that.
- Knock resets are universal. Kinfall already refunds a charge on knock (`refund_dash_charge()`).
- Dash distances stay short. The real variety is in input, payload and what the dash sets up.
- The ex/air dash as a second, longer dash is common. Kinfall keeps it per weight class.

---

## 2. Research: readability, telegraphs and "oomph"

### 2.1 Telegraphs and reaction windows

| Finding | Source |
|---|---|
| Average reaction to a single, expected, clear stimulus is ~265ms (~16 frames). 15f is "virtually unreactable", 19f is "reactable but near the limit", ~27f is easy when it's the main threat but harder in a mix | infil, "On Reaction Times" |
| A strong visual windup tell matters as much as total startup: moves with little early motion are hard to react to even when slow | infil |
| SUPERVIVE cast windups in its data run 0.1-0.65s (median 0.45); charge-to-full 0.5-1.25s (median 1.0) | docs/SUPERVIVE_DATA.md §6 (wiki) |
| SUPERVIVE delays its big area hits: Shrike's Dive-Bomb 0.65s fuse; Hudson's Barbed Wire 1s activation (raised from 0.6); Kingpin's second slug wave 0.6s later; Celeste's ult must be held to full; Bishop's ult cast raised 0.3→0.5s | wiki hunter pages |
| SUPERVIVE added **enemy-only global iconography** to Elluna's delayed root, so the victim knows a 2s detonation is coming; Joule's ult got a landing indicator | Elluna and Joule wiki pages (patch notes) |
| SUPERVIVE added wind-down frames after dashes and big swings (Brall, Oath) so you can't instantly glide away; an end-of-action vulnerability window | Brall and Oath wiki pages |
| Battlerite: cues exist "to show players what to dodge or interrupt". The sniper shows an aim line and has a distinct cast sound that plays even from stealth. A teleport was cut for a dash that stops on the first enemy hit because it was "more consistent and fair to land" | Stunlock dev blog 003 |
| Kinfall today: enemy area casts get a 0.32s filling ground marker; leaps show their landing circle to everyone; `delay` shows a telegraph ring | docs/ABILITIES.md, KIN_GRAMMAR.md |

### 2.2 Impact feedback: hitstop, shake, flashes

| Finding | Source |
|---|---|
| Hitstop is "purely visual": it makes a hit feel connected and conveys weight. Example scale is 8/12/16 frames for light/medium/heavy. Multi-hit moves get less. **Projectiles cause no hitstop for the attacker** | Capcom SF seminar column |
| Smash: both fighters freeze for the same time, and stronger hits freeze longer. Projectiles get less, electric gets ×1.5, there's a cap. Hitstop is kept short partly because a third player could act during a freeze. The victim shakes (side to side on the ground, up and down in the air); the attacker shakes slightly; hurtboxes don't move; the shake starts big and shrinks; its size adapts to camera distance | Sakurai via Source Gaming; SmashWiki |
| Smash Ultimate hitlag = (damage×0.65 + 6)×multipliers frames, capped at 30 (a 15% hit freezes 15 frames); Melee capped at 20 | SmashWiki "Hitlag" |
| A Godot reference hitstop of 0.08s (time scale 0.05, not 0), flash recovery 0.15s, trauma 0.7 decaying 3/s; one owner for time scale; a call token so a short stop can't end a long one | uhiyama-lab Godot hitstop note |
| Trauma-based camera shake (shake = trauma² or trauma³, noise-driven) is the standard approach | Eiserloh GDC 2016 (session summary) |
| Kinfall today: `freeze_frame()` 0.03-0.075s on heavy hits you deal or take (disabled online), `cam.add_trauma()` 0.08-0.6 across systems, `cam.punch()`, HUD flash, `_reward_moment` (0.07s freeze + 0.22s slow-mo) | scripts/match/match.gd |

### 2.3 Colour, shape and sound language

| Finding | Source |
|---|---|
| Hitboxes must match visuals. Visual attention follows ability importance (hierarchy). Projectiles should show travel direction even standing still | Riot, "Clarity in League" |
| Colour by meaning: heals in friendly green-gold, poisons in aggressive green-purple. Shape by meaning: knock-ups use strong vertical elements, roots and snares use ground particles. **Stuns and snares open with a hard-hitting tone that is then held** | Riot, "Clarity in League" |
| A skin may be clearer than the base, never less clear. Avoid permanent glows that look like an active ability | Riot, "Clarity in League" |
| Effects should show an ability's true size and direction without being distracting or too subtle | Riot VFX dev blog (via Surrender@20) |
| A powerful ability must look powerful, or it "will feel lackluster". Knockback shows its path (a smoke trail) and has a visible recover animation, so both sides know when control returns. Being launched gets camera follow so it feels grand, not frustrating | Stunlock dev blog 003 |
| Overwatch mixes each player's sounds by **threat**: how big they are on your screen, whether they're aiming at you, and path distance (not straight-line distance). Each hero has distinct footsteps, so you can tell who's coming by ear | Overwatch audio, PCGamesN |
| Battlerite: a character should read as what it is "just by looking at it" | 80.lv Battlerite interview |

### 2.4 Kit cohesion and counterplay in SUPERVIVE

Nearly every SUPERVIVE kit has one mark, stack or state that its other parts feed and consume:

| Kit | Setter | Payoff |
|---|---|---|
| Joule | everything applies Static stacks | Surge dashes through a fully charged target: cooldown reset, %HP burst |
| Crysta | abilities mark | basic attack or ult detonates the mark → dash recharge |
| Celeste | damage applies Chill | knock while Chilled → Shatter explosion |
| Felix | damage builds Ignite | spread and upgrade with his bolt |
| Saros | orb hit or portal → Ionized | faster fire and more speed; the dash kicks the orb |
| Kingpin | grab pulls you in | slam stuns, with a bonus in the air |
| Brall | chain pull | a special RMB spin while being pulled; RMB has tap, hold, air and during-Q variants |
| Tetra | rock walls | punch rocks with LMB or RMB to launch them |

Counterplay windows come from a few devices: visible delays, cancel conditions (Joule's dash is
cancelled by CC; Myth's ends on damage), committed lines (Celeste's skate, Ghost's held slide), and
resets that only work if the payoff lands (Shiv, Shrike level 4).

---

## 3. Project Boki dashes

### 3.1 Model

- **Weight class (core data, `Data.CLASSES`)** sets charges, recharge, air (ex) dash and mass. Knock
  refunds one charge, as today.
- **Archetype (core data)** sets the dash shape. Dashes stay core code (KIN_GRAMMAR: "class dodges
  are core"), described in a small shape vocabulary:
  `input` (tap, double_tap, tap_hold, hold_release, aimed, targeted), `steps`, `distance`, `speed`,
  `guard` (incorporeal_shots, unstoppable, front_guard), `arrive` (an event the kin rider can hook).
- **Kin (`dodge_rider`)** adds `on_pass`, `on_start`, `on_end`, `modifiers: [repeat]` or `as: blink`.
  Section 3.4 defines what each hook means for each shape, so a community kin's rider just works.

| Weight | Charges | Recharge per charge | Air (ex) dash | Mass | Source |
|---|---|---|---|---|---|
| Light | 1 | 6.5s | 5.0m, 12s | 0.85 | Data.CLASSES / phase_step.json |
| Medium | 1 | 9.0s | 4.6m, 13s | 1.0 | combat_roll.json |
| Heavy | 2 | 12.0s | 4.2m, 15s | 1.35 | shoulder_charge.json |

An archetype shape may split one charge into sub-steps (the Thief), or spend one charge on a
contextual version (the Bulwark).

### 3.2 The six archetype dashes

Numbers are Kinfall's own: distance in metres, speed in m/s. "Enemy cue" is what the other side sees
and hears. "Self cue" is what the user sees.

#### Thief: **Flicker** (light, tap twice)

- **Input:** tap Shift for step 1. Within 0.08-0.70s, tap again for step 2 in any direction
  (movement keys, or the cursor if none are held). One charge holds both steps.
- **Numbers:** each step is 2.3m in 0.085s (27 m/s). Each step is incorporeal to shots for 0.10s.
  Skipping step 2 refunds 25% of the cooldown.
- **Arrival:** after the last step, a 1.0s **Ambush** window. Your next hit counts as from behind,
  which feeds the Thief's Marks passive (ARCHETYPES.md).
- **Air:** the light ex-dash (5m), one step, no Ambush.
- **Enemy cue:** a smoke afterimage of the Thief's silhouette at each start point (0.25s). Two dash
  pips under the Thief's health bar go dark one by one. Sound: cloth snap "tk", then "tk" at pitch ×1.2.
- **Self cue:** a second-step timer arc around the dash slot, and an Ambush glint on the weapon.
- **Counterplay:** hold your CC until the second step is spent. The 0.7s window is the tell. The
  afterimages show where the Thief went.

#### Archer: **Grapple Arrow** (light, aimed)

- **Input:** tap Shift to fire a line arrow at the cursor (40 m/s, up to 9m).
- **Bites terrain** (wall, rock, tree, island edge, ledge up to 3m above you): you zip to it at
  22 m/s (up to 0.45s) and auto-mantle onto the top.
- **Bites nothing or open ground:** a 3.2m hop backward, away from the cursor (a disengage).
- It never latches onto units. It's movement, not a hook.
- **Charges:** 1, 7.0s (the light baseline plus 0.5s for the reach). In the air it works from a glide
  and cools the glider by 20%. That makes it the Archer's route to high ground.
- **Guard:** none. A stun, root or knockback during the zip drops you where you are.
- **Enemy cue:** the rope line is drawn to everyone for the whole zip. A landing ring flashes 0.15s
  before you arrive. Sound: a bow twang, then a zip whine that rises in pitch toward the end.
- **Counterplay:** the line is committed and interruptible. Shoot the zip, or stand on the landing ring.

#### Mage: **Blink** (medium, aimed, telegraphed)

- **Input:** tap blinks to the cursor. Holding past 0.1s shows a preview ring; release casts.
- **Numbers:** a 0.12s windup, during which a 1m sigil appears at the destination **for everyone**,
  then a teleport of up to 5.5m. It goes through units and walls and never ends in the abyss (an
  over-abyss destination arrives you gliding).
- **Residue rune:** left at the departure point. It bursts 0.6s later in a 1.5m circle: slow 0.25 for
  0.8s (the kin rider can change this payload, 3.4). It discourages chasing through.
- **Charges:** 1, 9.0s. In the air it travels 4m and keeps momentum and the glider state.
- **Guard:** none. The 0.12s windup is vulnerable. The jump itself is instant.
- **Enemy cue:** the destination sigil (a hostile rim for enemies) and a departure flash. Sound: a
  glassy inhale on the windup, a soft pop at both ends.
- **Counterplay:** prefire the sigil. Don't chase through the rune. The cooldown is long.

#### Gunslinger: **Slide Reload** (medium, tap or hold)

- **Tap (released under 0.18s):** a roll of 3.4m (23 m/s, 0.15s), incorporeal 0.14s, reloads 35% of
  the magazine. **Perfect dodge:** rolling through a hit as it lands makes your next 3 shots crit
  (kept from Combat Roll).
- **Hold:** a low slide of up to 6m over 0.5s, slowing as it goes. You can fire during it (spread
  ×0.6) and the magazine fully reloads at the end. Releasing early ends it and refunds 30% of the
  cooldown. The slide has no incorporeal frames.
- **Charges:** 1, 9.0s.
- **Enemy cue:** a dust streak and ejected shell casings with a metallic clink. Opponents can hear
  that you just reloaded.
- **Counterplay:** the hold slide is long and predictable, so a slow or root ends it. The tap roll is
  the short, safe version.

#### Juggernaut: **Rampage** (heavy, hold and release)

- **Tap (under 0.15s):** a shoulder charge of 3m (18 m/s), unstoppable. It shoves 10 and stuns 1.2s
  into a wall (today's Shoulder Charge).
- **Hold:** a windup of up to 0.7s. You're slowed to 50% and can turn freely. A ground arrow grows
  from 3m to 7m, visible to everyone, with a hostile rim for enemies. Release to charge the arrow's
  length at 20 m/s (up to 0.35s), unstoppable.
- **Carry:** the first hunter you hit is carried to the end, up to 3m. If the carry ends at a wall:
  stun 1.2s and payoff-tier hitstop. If not, they're shoved 10.
- **Charges:** 2, 12s each. Tap and hold each use one charge.
- **Cancel:** being stunned or rooted during the windup cancels it and refunds half a charge.
- **Enemy cue:** the growing arrow, dust and stomping, and a rising engine-like growl that tops out
  at full hold.
- **Counterplay:** step perpendicular to the arrow. CC the Juggernaut during the windup. Don't stand
  with your back to a wall in its line.

#### Bulwark: **Interpose** (heavy, context-targeted)

- **Default tap:** a braced step of 2.6m (16 m/s). A front 140° guard blocks shots during the step
  and for 0.3s after. Immune to knockback.
- **Ally under the cursor** (a hunter within 8m, 1.2m snap): you leap to them (0.4s, 2m high) and
  land on the side facing your aim.
  - Allies within 2m get a shield of 15, which spends Guard (ARCHETYPES.md).
  - Enemies within 2.5m are pushed 6.
- **Charges:** 2, 12s each. The ally leap uses one.
- **Enemy cue:** the landing circle is shown to everyone for the 0.4s. The shield face flares. Sound:
  a metal clang and a heavy whoosh.
- **Counterplay:** the guard is frontal only, so flank it. The ally leap shows its landing, so burst
  the ally before the Bulwark arrives, or punish the landing spot.

**Input check:** double-tap steps, aimed grapple, telegraphed blink, tap-or-hold slide, hold-to-charge
and context-targeted. Six different inputs, so no two archetype dashes play alike.

### 3.3 Dash-wide rules

- Every dash spends a visible pip on your own dash slot (DashSlot: a pip per charge, the countdown for the
  next, a flash and tick on return; the same slot at home). Owner item 84 removed the dash bar under the
  overhead health bar, so enemies' charges are no longer shown; the enemy read is the dash animation itself.
- Every dash has a start pose of at least 0.05s (an animation, not a delay on movement) and a unique
  sound per archetype. The kin's rider adds a theme sweetener.
- Wind-down: no glider for 0.12s after a ground dash ends, as SUPERVIVE did. Dash → jump is unchanged.
- Dash buffer (0.18s), rush cancels and the glide → dash → glide chains stay as built (KINFALL_CLASSES.md).
- Distances never grow with rank (ABILITIES.md rule). Ranks cut the recharge only.
- Protection stays short: at most 0.16s, or partial (shots only, front only). No full-invulnerability dash.

### 3.4 How kin riders hook into each shape (RETIRED)

> **Retired (owner decision 2026-11-05, item 129; DECISIONS.md):** Boki dash riders are removed. Dashes are purely the hero's own; a Boki acts only through its own abilities. Kept for history only. `--boki-dash-check` asserts no Boki changes a dash.

General rules, so any rider, including a community one, maps onto any shape:

| Rider hook | On a travelling dash | On a blink | On a carry (Rampage hold) | On a context version (ally leap, grapple zip) |
|---|---|---|---|---|
| `on_pass` (effects; never stun or root) | foes the dash passes through | foes within 1m of the start-to-end line (a streak drawn on the instant) | the carried target and anyone plowed through | foes under the rope or the arc's landing (2.5m) |
| `on_start` (stages) | at the departure point, once per charge (not per sub-step) | at the departure point (with the residue rune) | where the windup was held | at the launch point |
| `on_end` (stages) | at the final arrival, after the last sub-step | at the destination | at the carry's end | at the landing point |
| `repeat` (modifier) | one echo of the last motion at falloff × distance | a free recast blink within 1.0s at falloff × distance | a second shorter charge 0.18s later along the same line | a free second grapple at falloff × range / +0.3s guard |
| `as: blink` | travel becomes a blink of the same distance (riders that need a path use the streak rule) | already a blink: becomes **return** (recast within 1.5s to blink back to the departure point once) | can't blink a carry: the windup arrow gains +1m instead | the zip or leap becomes instant after a 0.1s flash (the line still shows) |

Riders are priced in Phase 3 like any other part. A rider can't change a dash's input, charges or
protection. Those belong to the archetype and weight class.

### 3.5 Every archetype + kin dash (RETIRED)

> **Retired (owner decision 2026-11-05, item 129; DECISIONS.md):** Boki dash riders are removed. Dashes are purely the hero's own; a Boki acts only through its own abilities. Kept for history only. `--boki-dash-check` asserts no Boki changes a dash.

Riders today (content/kin_v2):

- **Vespyx** Venom Trail: `on_pass` damage 3, poison 12, blight 3s.
- **Gravadillo** Gravity Wake: `on_end` burst 3.5m, pull 8.
- **Prismander** Prism Decoy: `on_start` decoy 1.8s.
- **Mycroll** Spore Puff: `on_start` zone 1.5m, 2s, damage 2, slow.
- **Echolop** Echo Step: `repeat` ×1, 0.18s delay, falloff 0.55.
- **Lunowl** Moon Blink: `as: blink`, and its perch carry gives +1 dodge charge.

| | Vespyx | Gravadillo | Prismander | Mycroll | Echolop | Lunowl |
|---|---|---|---|---|---|---|
| **Thief Flicker** | each step poisons what it crosses; stitching through one foe with both steps double-poisons them | after the final step, foes within 3.5m are tugged toward you, into the blades | a decoy stands where step 1 began | a spore puff at step 1; step 2 leaves a second puff at 0.6× strength (a two-puff zigzag) | step 2 echoes into a third step at 0.55× (2.3 → 1.3m) | steps become blinks (2.0m each); with the perch's extra charge, 2 Flickers = 4 blinks |
| **Archer Grapple** | the rope poisons foes it crosses during the zip | on arrival, pull foes toward your perch (lethal near edges) | a decoy at the launch point keeps bots aiming low | a spore zone at the launch point slows anyone who follows the rope | a free second grapple at 55% range within 1s: two-hop climbs | no zip: blink to the bite point after a 0.1s rope flash; the backward hop blinks too |
| **Mage Blink** | the start-to-end streak poisons foes within 1m | a pull at the destination: blink in, pull them together, then cast | a decoy on the residue rune | the residue rune becomes a spore zone (slow 0.8 instead of 0.25) | a free recast blink at 55% within 1s (a double blink) | **Moon Return**: recast within 1.5s to blink back to the rune |
| **Gunslinger Slide** | the slide path poisons (long on a hold, short on a tap) | a pull at the end of the roll or slide, into point-blank spray | a decoy at the start that keeps firing at nothing for bots | a puff at the start; the slide itself leaves no trail | the tap roll echoes into a second roll (55%) and reloads another 15% | the tap roll becomes a 3.4m blink-reload; the hold slide is unchanged |
| **Juggernaut Rampage** | the carried target and everyone plowed through are poisoned and blighted | a pull at the carry's end drags bystanders into the wall-slam spot | a decoy where you released | the windup spot becomes a spore zone that grows 1.5 → 2.2m with the hold | a second 55% charge along the same line 0.18s later (extends a wall slam) | the tap becomes a blink-shove (arrive, shove 10); the hold arrow gains +1m |
| **Bulwark Interpose** | the braced step poisons; the ally leap poisons foes under the landing | a pull at the landing drags attackers off the ally and onto you (bodyguard) | a decoy where you left | a spore zone where you left | the braced step echoes (a second 55% step); the ally leap gets +0.3s guard instead | the ally leap becomes a 0.12s flash then arrive; the braced step blinks 2.6m with a 0.5s guard after |

**36 different dashes:** six inputs, each with six payloads or extra beats. The only near-pair is
Prismander's decoy, which is the same on every shape by design. It's the support kin's "bots look
away" tool. Its merge and archetype infusion carry its other identity (ARCHETYPES.md).

---

## 4. Feel pass on every current kin ability and merge

Under the archetype model (ARCHETYPES.md), each kin's former E active becomes the **infusion source**
(the parts the kin lends to archetype abilities). Its auto ability stays: the kin still casts it on
its own. The merges become the **bonded** form of R. Every ability below stays in the game in one of
those roles, so each gets a full feel pass.

Notation:

- **Tell:** what's shown before it lands, and to whom.
- **Cast / Impact:** the moment of use and the moment it connects.
- **Sound layers:** tell / body / impact (category family) + theme sweetener (5.6).
- **Cat:** colour category (5.1).
- **HS:** hitstop tier (5.4).
- **Shake:** trauma, for the people involved (5.5).

### 4.1 Vespyx (venom, bruiser): "sting, then drag"

**Setter:** poison and blight, from every Vespyx part (shot rider, throw, Venom Trail, Stinger Dash).
**Payoff:** Stinger Hook and the merge's opening burst hit harder on poisoned foes (new `exploit`, 5.9).

| Ability | Tell | Cast / Impact | Sound | Cat | HS | Shake | Cohesion and part changes |
|---|---|---|---|---|---|---|---|
| **Stinger Hook** (projectile, hook preset, 8m) | the kin cocks its tail for 0.15s with a green glint, visible to all; the rope is drawn behind the barb | the barb's tail streak shows direction. On hit: the rope snaps taut, the target is yanked with a green drag trail, and a "HOOKED" word appears | tell: a dry rattle; body: rope whirr; impact: control family (hard hit + held tone 0.3s, matching the stun); sweetener: wet hiss | control (green-purple poison accent on particles) | T3 (target and kin owner) | 0.2 owner / 0.3 target | add `{"type":"exploit","state":"poisoned","bonus":0.3}` so it pays off Venom Trail and the shot rider. Keep stun 0.3. Projectile speed 30 = 0.27s over 8m, above the CC minimum (5.3) |
| **Stinger Dash** (auto dash 7m) | a 0.25s kin crouch with tail high and a hiss bark (the auto-cast tell, 5.8); the dash lane shows as a 0.2s decal | the lunge leaves a green streak; on_end burst 1.6m push 5 | tell: hiss; body: whoosh; impact: damage crack + push thump | damage | T2 on the burst, T0 on poison ticks | 0.1 | it's the setter: poisons for the hook to cash in. No change |
| **Venom Trail** (dodge rider) | none (the dash is the tell) | a green trail where you dashed; poisoned foes drip | sweetener only on the dash sound | damage (tick) | T0 | 0 | setter. No change |
| **Venom Mantle** (merge) | the 0.35s fuse: the kin wraps your shoulders, a green column flashes, a burst ring shows 0.3s ahead | on_start burst 3.2m: damage 18, push 9, poison 18. The silhouette gains a curled tail plume over the shoulder for the duration, so everyone can see you're merged | tell: rising hiss; impact: payoff thump + crack; music ducks −4 dB within 20m | damage | T4 caster, T3 targets | 0.4 caster | add `exploit poisoned +0.3` to the on_start burst. Merged shots poison and splash, so every shot sets up the next merge burst. Keep it |

### 4.2 Gravadillo (gravity, tank): "pull in, then slam"

**Setter:** pull and lift (Gravity Wake, the throw's push, Titan's lift).
**Payoff:** spike on airborne foes (Slam, Titan pulses).

| Ability | Tell | Cast / Impact | Sound | Cat | HS | Shake | Cohesion and part changes |
|---|---|---|---|---|---|---|---|
| **Gravity Slam** (leap 7m → pull 3.5m → burst 2.4m lift + spike) | the landing circle shows to everyone for the whole 0.5s flight and fills as it falls; a low gravity whine rises in pitch | two beats: the pull lands on touchdown (T2, debris sucked inward), then **0.12s later** the crater erupts (lift + spike). Spiked foes get a downward slam streak and a "SPIKED" word | tell: whine; impact 1: sub-bass whump; impact 2: control hard hit + crack; sweetener: pebbles | control | T2 then T4 on spike | 0.3 owner, 0.35 spiked | add `{"type":"delay","time":0.12}` to the second burst, so pull and lift read as two beats and the spike has a chance on foes the pull lifted. 0.5s flight is above the 0.40s hard-CC rule |
| **Mass Guard** (auto wall 2.4m, follows owner) | the kin rolls into a ball for 0.15s, then the plate rises | the plate slams up: dust, a clunk; enemy shots spark off it | impact: utility thunk; while up, shots hitting it ping | utility (shield) | T0 | 0 | add `then.on_end`: burst 1.5m push 6 ("the plate drops"), so the end is visible and gives a peel moment both sides can play around |
| **Gravity Wake** (dodge rider) | a purple ring shows at the dash's end for 0.15s before the pull | foes slide in with debris streaks | sweetener: whump | control | T1 | 0.05 | setter for Slam |
| **Heavy Star** (merge) | 0.35s collapse animation: a purple vortex column, ground cracks radiating out | on_start burst 4.5m: damage 22, push 14, lift 8. Pulses every 1.5s (burst 2.6m) | each pulse has a 0.3s ground ripple tell, a low drone while merged, and footsteps 2× louder | control | T4 on start; pulses T2, T4 on spike | 0.45 start; 0.15 per pulse | add `spike` to the pulses (the setter lifts, the next pulse spikes): a rhythm opponents can learn and dodge between |

### 4.3 Prismander (prism, support): "bend it back"

**Setter:** reflect (Prism Wall, Refraction).
**Payoff:** reflected shots dazzle the shooter. This is a new rule, 5.9 "reflect carries": a reflect
on a wall or bubble passes its stage's slow to the shooter it returns to.

| Ability | Tell | Cast / Impact | Sound | Cat | HS | Shake | Cohesion and part changes |
|---|---|---|---|---|---|---|---|
| **Prism Wall** (wall 4m, reflect) | the footprint shimmers for 0.15s (all players), then crystals grow from the centre outward | enemy shots hit with a "ting", turn prism cyan and fly back along a refracted streak; the shooter sees "REFLECTED" | impact: sustain/reflect chime; crack when the wall breaks (hp 0) | sustain (defensive) | T2 for the shooter when the reflection hits them | 0.15 shooter | add `{"type":"slow","duration":0.6}` to the wall's effects (walls may carry slow). With reflect carries, a reflected shot also slows its shooter |
| **Refraction** (auto, owner mirror 1s + shield 20) | 0.2s kin flare and a bark (auto tell) | a clear mirror shell around the owner for 1s with a held glassy tone the whole time | held tone (enemies hear it louder: stop shooting) | sustain | T0; T2 on reflected hits | 0 | readable on purpose: the counter is to stop firing for 1s |
| **Prism Decoy** (dodge rider) | — | a crystal copy at your start point | sweetener: crystal tinkle | utility | T0 | 0 | for humans, the decoy has no dash pips or name glow, so people can learn to spot it |
| **Prism Shell** (merge) | 0.35s: crystals close over you | on_start burst 3.5m: push 12, slow 2s; heal allies 20 in 5m. A crystal silhouette with frills | impact: payoff chime + push thump | sustain | T3 caster | 0.3 caster | merged shots slow; reflect carries makes the kit's identity "everything that hits you gets slower" |

### 4.4 Mycroll (spore, controller): "plant, then bloom"

**Setter:** slow (shot rider, Spore Puff, Spore Patch).
**Payoff:** root (Puffcap Mines, throw, merge), and `exploit rooted` on Spore Patch.

| Ability | Tell | Cast / Impact | Sound | Cat | HS | Shake | Cohesion and part changes |
|---|---|---|---|---|---|---|---|
| **Puffcap Mines** (3 traps, root 1.4) | planting is visible to everyone in sight (three pops and puffs). Armed mines then show to enemies within 2.5m as faint caps, or within 5m when sneaking | **trigger: a 0.15s click and swelling cap before the root** (a dash in that window escapes), then the burst and a ground-tendril root (Riot's root shape language) | tell: click; impact: control hard hit + held tone for the root's 1.4s | control | T3 for the victim | 0.3 victim, 0.1 owner | add a 0.15 `delay` on the on_trigger burst (5.3, trap rule). The root stays 1.4 |
| **Spore Patch** (auto zone 2.6m, 4s) | 0.25s kin puff bark, and the zone decal fills in over 0.3s before ticking | spores drift; slowed foes drip downward particles | body: soft hiss loop; ticks have no sound beyond the first | control (slow) | T0 | 0 | add `{"type":"exploit","state":"rooted","bonus":0.5}` so mines into patch is the combo |
| **Spore Puff** (dodge rider) | — | a puff at your start | sweetener | control | T0 | 0 | setter |
| **Sporewake** (merge) | 0.35s growth: a cap rises over your head | on_start burst 4m root 1.6 has a 0.4s expanding ring tell first; pulses every 1.5s | each pulse has a 0.3s ripple before it; root tone | control | T3 start; T1 pulses | 0.35 start, 0.1 pulse | the pulse root is 1.0 every 1.5s, too much repeated hard CC. Change to root 0.6 + slow 0.35, and rely on diminishing returns (Phase 2). Keep the 1.6 on_start root with its 0.4s tell |

### 4.5 Echolop (echo, skirmisher): "ring twice"

**Setter:** reveal and jolt (Echolocate, Echo Chain, throw stun).
**Payoff:** the echo (repeat) and crits on revealed foes.

| Ability | Tell | Cast / Impact | Sound | Cat | HS | Shake | Cohesion and part changes |
|---|---|---|---|---|---|---|---|
| **Echo Chain** (seek beam 7m, chain 2, stun 0.4, echo 0.9s) | 0.15s ear flare and a two-note chirp | the beam snaps to the first foe, then arcs on. **The echo shows a ghost ring on each struck foe that shrinks over 0.9s, then the second hit lands** | every hit plays a note; the echo replays it a fifth lower at −6 dB. That's the kin's audio motif | control | T2 first hits, T1 echo | 0.1 | the echo ring makes the repeat dodgeable (move off it). Add `exploit revealed +0.25` so Echolocate feeds it |
| **Echolocate** (auto, reveal 18m) | 0.25s ear flare bark | a sonar ring sweeps outward; revealed foes get an outline and are told: "you're revealed" (an icon on their HUD) | a ping heard by everyone it reveals | utility | T0 | 0 | the victim knowing they're revealed is two-sided readability |
| **Echo Step** (dodge rider) | — | a ghost silhouette copies your dash 0.18s later | the dash sound repeated at −6 dB | utility | T0 | 0 | — |
| **Resonance** (merge) | 0.35s hum swell; rings orbit you | on_start beam chain 3, stun 0.6. Every dash comes back (dodge_regen 1) | a constant low hum while merged, and each shot gets the echo note | control | T3 start | 0.3 | merged shots chain 1. With the archetype's dash, this is the "mobility ult" bonded R |

### 4.6 Lunowl (lunar, trickster): "trade places"

**Setter:** displacement (throw push, Eclipse pull and lift, Moon Blink).
**Payoff:** edges. A swap or push near the abyss is a kill. Lunowl's readability is mostly about
making displacement fair.

| Ability | Tell | Cast / Impact | Sound | Cat | HS | Shake | Cohesion and part changes |
|---|---|---|---|---|---|---|---|
| **Moon Swap** (projectile 9m, swap with owner, stun 0.4) | 0.15s wing flare and silver glint; the moon disc has a long tail | on hit, a **0.12s silver thread** joins the two bodies, both flash, then swap. The victim's screen gets a direction flash showing where they went | tell: chime; body: hum; impact: control hard hit + a reverse-whoosh swap | control | T3 both | 0.35 victim, 0.2 owner | swap counts as hard CC (5.3). Slow the disc from 30 to 22 m/s (0.41s at 9m) so it's dodgeable at range |
| **Moonlift** (auto, lift owner 14) | 0.2s column-of-light tell under you | the owner rises in a moonbeam | rising chime | utility | T0 | 0.1 owner | — |
| **Moon Blink** (dodge rider) | — | blinks with a silver streak (the streak rule) | sweetener | utility | T0 | 0 | — |
| **Eclipse** (merge) | 0.35s darkening of a 5.5m ring around you (enemies see the ring tighten) | on_start burst 4m: damage 12, lift 9; pulses every 0.6s: pull 7 in 5.5m | a low eclipse drone; each pulse is a soft "thrum" | control | T3 start; T0 pulses | 0.3 start | pull pulses every 0.6s with no break are hard to read. Add an edge ring that tightens with each pulse, and drop the pull to 6 so walking out against it is possible (counterplay) |

---

## 5. Global feel spec

### 5.1 Effect categories: colour, shape and sound family

Category comes from the parts (KIN_GRAMMAR: damage, control, sustain, utility). When a stage has
several, the **highest priority** colours it: control > damage > sustain > utility. Control is the
one people most need to dodge.

| Category | Ground and impact colour | Shape language (colour-blind safe) | Sound family |
|---|---|---|---|
| damage | ember `#ff7a3d` | solid fill, sharp shard particles | crack (transient) + thump |
| control | violet `#c46bff` | hatched fill with inward chevrons. Lift: vertical streaks. Root: ground tendrils. Stun: an orbiting ring over the head. Slow: downward drips. Pull: inward particle flow. Push: outward flow | a hard hit, then a **held tone** for the CC's duration (Riot) |
| sustain | green-gold `#b8f06a` (heal), white-gold `#fff1b8` (shield, reflect) | soft gradient, rising motes, plus marks | rising chime |
| utility | cyan `#5fd8ff` | dotted ring, sonar sweep | airy ping |

The theme (venom, gravity, prism, ...) only tints particles and picks the sweetener sound. It never
changes the category colour of a decal or impact flash. This is KIN_GRAMMAR's Phase 4 "colour means
effect category" made concrete.

### 5.2 Allegiance: whose is it

| Viewer sees | Rim and pattern | Opacity | Sound |
|---|---|---|---|
| own casts | a thin white rim | fill 30% | normal |
| ally casts | a thin team-colour rim (TEAM_COLORS) | fill 20% | −4 dB |
| enemy casts | a **thick red rim `#ff2d55` with animated inward chevrons**, drawn on top of everything | fill 35% | +3 dB if it can reach you (in range, aimed at you), otherwise normal |

Rules:

- Enemy telegraphs are never culled by the effect budget. Allied cosmetics are culled first.
- Enemy-only icons go over a target's head when a delayed effect is coming for them (a delayed burst
  on them, a trap they triggered, a tether, a Rampage arrow on their line). SUPERVIVE added exactly
  this to Elluna's delayed root.
- A victim of reveal, mark, blight or vulnerable gets a HUD status icon with a timer, and their model
  shows the mark to everyone (reveal outline, vulnerable crack overlay, blight sickly tint).
- (Enemy dash pips were removed by owner item 84.) Each enemy's merge and resource states have tells
  (ARCHETYPES.md), so you can track their big tools.

### 5.3 Telegraph timing

The window is enemy-visible time from the first tell to when the effect can land. It's measured
against the ~265ms single-stimulus human reaction, plus margin for a 20-player screen.

| Severity (from the parts) | Instant deliveries at range (burst/zone at aim, cone, beam, leap landing) | Projectiles (CC on hit) | Traps | Self or around-self |
|---|---|---|---|---|
| **hard CC**: stun ≥ 0.5, root ≥ 1.0, swap, pull to caster ≥ 20 m/s, lift + spike | **≥ 0.40s** filling marker | travel ≥ 0.25s at 2/3 range, or a 0.15s cast glint plus a visible projectile | 0.15s click before the burst | ≥ 0.30s ring around the caster |
| **soft CC**: stun < 0.5, root < 1.0, slow, push, pull, lift | **≥ 0.30s** (today's 0.32) | travel ≥ 0.2s at 2/3 range | 0.10s click | ≥ 0.20s |
| **damage only**, ≥ 15% of a medium hunter's HP (≥ 22 of 145) | ≥ 0.20s | visible projectile | arm visible | ≥ 0.15s |
| chip damage, sustain, utility | none required (the cast pose is enough) | — | — | — |

- The runtime inserts the minimum. If a stage's own `delay`, leap time or projectile travel is
  shorter than the floor, Phase 2 adds the missing windup. Authors can lengthen a telegraph, never
  shorten it. That's how community kin get fair telegraphs for free.
- **Auto casts** (kin-triggered) add a 0.25s kin tell: an eye and glow flare plus a short bark.
  Enemies learn "the kin flared, something's coming".
- **Merges and bonded R** get a 0.35s transform tell with a column visible within 25m.
- **Wind-down:** a hard-CC ability leaves its caster unable to glide for 0.2s after it lands.

### 5.4 Hitstop

Hitstop is presentation only: the simulation never pauses for it. Offline it can use the existing
global `freeze_frame()`. Online (it's disabled there today, since `net_on` skips it) it becomes
**per-entity**: freeze the two involved models' animation and VFX and hold their rendered position
while their hurtboxes keep updating (Sakurai's rule), only on the clients of the two players
involved, plus a softer 50% version for the kin owner.

| Tier | Trigger (derived from the parts) | Attacker | Target | ≈ frames @60 |
|---|---|---|---|---|
| T0 | damage ticks, zone ticks, slow-only, reveal, buffs | 0 | 0 (a 40ms hit flash only) | 0 |
| T1 | a single hit under 8% of target max HP, no CC | 0 | 0 (the flash only: source parity, below) | 0 |
| T2 | a hit ≥ 8%, or push/pull ≥ 8 m/s, or a reflect returning | 35ms melee / 0 ranged | 45ms | 3 |
| T3 | CC landing (stun, root, hook yank, swap, lift), or ≥ 15% | 50ms melee / 0 ranged | 65ms | 4 |
| T4 | payoff: spike, wall slam, `exploit` triggering, knock (downing) | 70ms | 90ms | 5-6 |
| T5 | merge or bonded R start (caster); a knock on a full-HP-bar burst | 100ms + 0.2s slow-mo at ×0.35 (offline only, existing `_reward_moment`) | — | 6 |

Rules:

- Take the max, never the sum. Within 0.25s, further hits on the same pair get a third of their
  tier (multi-hit rule). Echoes (`repeat`) use half.
- Projectiles never freeze the attacker (Capcom). Melee freezes both, and the victim shakes along the
  hit direction (Sakurai). The shake starts big and shrinks.
- Cap: 110ms in any 0.5s per player.
- The spike tier is a bit longer than SUPERVIVE-era Kinfall's current max of 75ms. It's still short
  of fighting-game values (8-16f), because a third player can act during it (Sakurai's free-for-all point).
- **One owner (impact pass, 2026-11-09).** `Feel.hitstop` alone sets a body's hold (`Ent.freeze_t`); Ent.hurt and
  Oomph no longer write it. Offline, every whole-game freeze (`Match.freeze_frame`: a tier hit, an armor break, a
  parry, a Boki strike) charges the same cap (`Feel.spend`).
- **The strike frame holds.** While a body is frozen every bone holds (clips, hair, cloth: `WardenGlb` skips the
  frame), and `WardenClips` plays the held time back 50% faster so a move stays on the kit's clock (`Ent.held_s`).
- **Reactions.** The hit clip (`hit_f`/`hit_b`, all 12) plays only for a staggering hit (Oomph's "big": >= 12% of
  max health, heavy, payoff or a stun); chip hits flash and shiver. A knockback holds the hit pose while the body
  slides; a stun shows the stun clip over any move. The source's own hit-stop, flash and reaction timings are
  unpublished [?] (docs/SUPERVIVE_DATA.md), so these tiers stay ours. `--impact-check` asserts all of it per Hunter.
- **Source parity (2026-11-09, briefs/hero-ref sheets).** The numbers are in `content/rules/hitstop.json`.
  - *Hit-stop.* No sheet shows a held frame on any hit, light or heavy (Kael's 771/1066, Albert's 976 wall bash,
    Lace's 505 Supercharged). The sheets are 4-10 fps, so they only bound a freeze: under one 10 fps frame (0.1 s).
    The owner asks for a few frames of hit-stop on impacts (OWNER_REVIEW_1103 item 50), so T2-T4 stay, all under
    that bound. T1 holds nothing: the source's light hits (Vex's rifle string, Sable's darts) show only a flash and
    a small number.
  - *Hit flash.* A solid flash on the body, the same on light and heavy hits. Sable's 0.45 s LMB string at 5 fps
    caught it on 3 of 8 hits (about 0.075 s), and Vex's rifle string flashed in every frame (0.1 s or more at its
    rate), so the band is 0.08-0.13 s. Ours (`Ent.hurt`, 0.12 s) sits in it, unchanged.
  - *Heavy against light.* In the source a heavy hit reads through the number (big yellow, or magenta on an
    execute), a burst on the target (Kael's white star and slash, Lace's teal X-star, Albert's white dust), the
    knockback, and stun stars or a STUNNED label. It does not read through a longer flash or a visible freeze.
  - `--polish-check` row 5 asserts the four named hits, the tier bound and the flash band.

### 5.5 Camera: almost no shake (owner rule, replaces the old table)

Your own abilities, dashes, landings and hits never shake or kick your camera: impact reads through
hit-stop, flashes, sparks, debris, sound and the target's reaction. The only shake left is a big thing
that happens TO you (a boss slam, a heavy ult or landing on or near you), through one door,
`Shake.incoming_big(m, at, power, cause)` (scripts/match/shake.gd): at most 0.15 s, falling off over 14 m,
never for whoever caused it, scaled by Settings "Screen shake" (0-100%, default 30%; 0 = off).
`--shake-check` asserts it for all 12 hunters. HUD hurt-direction indicators carry the "from where".

### 5.6 Sound layering

Every ability is up to four layers, generated from its parts:

| Layer | From | Who hears | Level |
|---|---|---|---|
| 1. **Tell** (windup, cast) | delivery type (each has its own sound: projectile = draw/whip, cone = swell, beam = charge whine, burst = inhale, zone = hiss, trap = plant pop, wall = grind, aura = hum-on, tether = rope crack, dash = per archetype, leap = launch grunt + whine, blink = glass inhale, summon = rune hum) | everyone in range | enemies of the caster +3 dB when it can reach them |
| 2. **Body** (travel or channel loop) | delivery (projectile whirr, beam hum, zone loop, tether creak) | everyone | −6 dB; spatialized, with pitch rising as a projectile nears you |
| 3. **Impact** | effect category family (5.1); CC holds its tone for the CC duration | struck player and caster loudest | struck player 0 dB, caster −3 dB, others −8 dB |
| 4. **Sweetener** | kin theme (venom hiss, gravity sub, prism chime, spore puff, echo note, lunar shimmer) | everyone | −6 dB under layers 1 and 3 |

Mix rules (extending `Sfx`'s MIN_GAP and STACK):

- At most 4 voices per ability event.
- Priority: enemy CC tells > incoming impacts on you > your own impacts > ally casts > ambience.
- Threat weighting as in Overwatch: an enemy aiming at you or in your path is louder than one who isn't.
- `Sfx.duck` music −4 dB for 0.3s on merge or bonded R starts within 20m.
- Ticks (damage over time, zone ticks) play only the first tick, then nothing. The held tone of a
  slow or root carries the information.

### 5.7 Oomph budget by tier

The ability's grammar `tier` (1-3) caps its feel, so small abilities can't out-juice big ones.

| Tier | Max hitstop | Max own-cast shake | Max telegraph VFX radius | Example |
|---|---|---|---|---|
| 1 (E/RMB-class, kin auto) | T3 (T4 only via spike or exploit) | 0.15 | the ability's own shape | Stinger Hook, Echo Chain |
| 2 | T4 | 0.25 | shape + 0.5m glow | archetype E, strong RMB holds |
| 3 / R / merge | T5 | 0.4 | shape + 1m glow, column within 25m | bonded R, ultimates |

### 5.8 Derivation from the grammar (how community kin get this automatically)

Phase 4's look-and-sound generator reads only parts. No kin file can set colours, shake, hitstop,
telegraph shortening or sound levels. It can set `theme` (particle tint and sweetener) and lengthen
telegraphs (`delay`).

```
FeelSpec for one stage =
  category  = max_priority(category(e) for e in effects)        # 5.1
  severity  = max(severity(e))   # hard_cc | soft_cc | heavy_dmg | chip | sustain | utility  (5.3)
  telegraph = max(author_delay, floor[severity][delivery.kind]) # inserted if missing
  tell_snd  = DELIVERY_TELL[delivery.type];  body_snd = DELIVERY_BODY[delivery.type]
  impact    = CATEGORY_IMPACT[category], hold = cc_duration(effects)
  hitstop   = tier_from(effects, target_hp, melee=delivery.kind in [cone, dash, leap] or reach<=2.5)
  shake     = SHAKE[hitstop tier][viewer role]                  # 5.5
  extras    = for m in modifiers: MOD_CUE[m.type]
  budget    = clamp to OOMPH[ability.tier]                      # 5.7
  if trigger != on_cast: add KIN_TELL(0.25s)                    # auto casts
```

| Modifier | Automatic cue |
|---|---|
| `delay` | a filling ring or lane (already the vocabulary's telegraph ring) |
| `repeat` | a ghost copy of the shape shrinking over `delay` at the repeat spot; the impact replayed at −6 dB, a fifth lower |
| `linger` | a ground patch decal in the category colour with a slow pulse; first-tick sound only |
| `chain` / `bounce` | an arc line drawn between targets, with a pitch step up per jump |
| `split` | a fan flash at the muzzle |
| `pierce` | the projectile keeps its streak through targets; a small tick per target |
| `return` | a returning streak and rising whirr |
| `spike` | downward slam streaks, "SPIKED" word, T4 |
| `exploit` (new) | a payoff glyph flashes on the target (the state's icon cracking), T4 |

| Delivery | Automatic tell shape |
|---|---|
| projectile | aim lane while held (self); a cast glint and tail streak (all) |
| cone | a wedge decal over the telegraph window |
| beam | a thin pre-line over the window, then a thick beam |
| burst / zone at aim | a filling circle |
| trap | plant pop; hidden after arm; reveal radius when near or sneaking; trigger click |
| wall | footprint shimmer (0.15s), then growth |
| aura | a ring that follows the origin |
| tether | the rope; it reddens toward snap length |
| dash / leap / blink | lane / landing circle / destination sigil |
| summon | rune circle, then the unit rises |

Phase 3's checker gets two new warnings: "hard CC under its telegraph floor (the runtime will add
X s)", and "stage colour category is control but the shape has no control shape cue". That way
authors see what the game will do.

### 5.9 Small grammar additions this needs

| Addition | Kind | Bounds | Why |
|---|---|---|---|
| `exploit` | modifier, on any harmful delivery | `state` ∈ poisoned, blighted, rooted, slowed, revealed, vulnerable, airborne, stunned, near_wall; `bonus` 0-0.5; optional `stun` 0-0.6 | the setter → payoff link in data (`spike` stays as the airborne special case) |
| reflect carries | a runtime rule | slow, push and damage on the same stage ride the reflected shot (never stun or root) | Prismander payoff |
| `as` | dodge_rider field: add `hop` | — | a rider can turn a travelling dash into a short arc (for future kin) |
| telegraph floor | core table, not data | 5.3 | fairness for community kin |
| `windup` | read-only, computed | — | shown in the generated rules text (Phase 4) |

---

## 6. Open questions

- (Enemy dash pips: removed, owner item 84.)
- Per-entity hitstop online: is a local-only presentation freeze acceptable to the netcode owner?
  It doesn't touch simulation, but the two players see a 45-90ms visual hold.
- Mycroll's merge pulse: lower the root (proposed) or lengthen the interval?
- The palette needs a colour-blind pass (the category patterns are designed to carry meaning without hue).

---

## Sources

SUPERVIVE (public wiki pages, read Oct 2026):
- [Ghost](https://supervive.wiki.gg/wiki/Ghost), [Jin](https://supervive.wiki.gg/wiki/Jin), [Shiv](https://supervive.wiki.gg/wiki/Shiv), [Myth](https://supervive.wiki.gg/wiki/Myth), [Shrike](https://supervive.wiki.gg/wiki/Shrike), [Brall](https://supervive.wiki.gg/wiki/Brall), [Carbine](https://supervive.wiki.gg/wiki/Carbine), [Crysta](https://supervive.wiki.gg/wiki/Crysta), [Joule](https://supervive.wiki.gg/wiki/Joule), [Saros](https://supervive.wiki.gg/wiki/Saros), [Wukong](https://supervive.wiki.gg/wiki/Wukong), [Bishop](https://supervive.wiki.gg/wiki/Bishop), [Kingpin](https://supervive.wiki.gg/wiki/Kingpin), [Felix](https://supervive.wiki.gg/wiki/Felix), [Oath](https://supervive.wiki.gg/wiki/Oath), [Elluna](https://supervive.wiki.gg/wiki/Elluna), [Zeph](https://supervive.wiki.gg/wiki/Zeph), [Eva](https://supervive.wiki.gg/wiki/Eva), [Beebo](https://supervive.wiki.gg/wiki/Beebo), [Celeste](https://supervive.wiki.gg/wiki/Celeste), [Hudson](https://supervive.wiki.gg/wiki/Hudson), [Mercury](https://supervive.wiki.gg/wiki/Mercury), [Void](https://supervive.wiki.gg/wiki/Void), [Tetra](https://supervive.wiki.gg/wiki/Tetra), [Getting Started](https://supervive.wiki.gg/wiki/Getting_Started)
- Kinfall's earlier SUPERVIVE research: docs/SUPERVIVE_DATA.md, docs/SUPERVIVE_FEEL.md

Readability, telegraphs, feel:
- [Riot Games, "Clarity in League"](https://riotgames.com/en/news/dev-clarity-in-league)
- [Riot VFX dev blog (Surrender@20 red post collection, 2015)](https://surrenderat20.net/2015/06/red-post-collection-dev-blog-on-vfx.html)
- [Stunlock Studios, Battlerite dev blog 003](https://blog.stunlock.com/dev-blog-003/)
- [80.lv, Battlerite interview](https://80.lv/articles/battlerite-interiew)
- [Capcom SF Seminar column on hitstop](https://game.capcom.com/cfn/sfv/column/131545?lang=en)
- [SmashWiki, Hitlag](https://www.ssbwiki.com/Hitlag)
- [Source Gaming, Sakurai's Famitsu column on hitstop](https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/)
- [infil, "On Reaction Times"](https://ki.infil.net/reaction.html)
- [PCGamesN, Overwatch devs on a game you can play by sound](https://pcgamesn.com/overwatch/overwatch-devs-on-creating-a-game-you-can-play-by-sound-and-announcing-dolby-atmos-support)
- [Game Developer, Eiserloh "Sprucing up cameras with math" (GDC 2016)](https://www.gamedeveloper.com/programming/video-sprucing-up-cameras-with-math)
- [uhiyama-lab, Godot hitstop basics](https://uhiyama-lab.com/en/notes/godot/hit-feedback-hitstop/)

Tried but not readable from this environment: the esports.gg all-hunters guide (site error), the LoL
fandom "Cast time" page (blocked), and Riot's 2017 VFX style guide and 2018 SFX articles on
nexus.leagueoflegends.com (they redirect to the LoL home page). Deadlock was searched but no
design-level source on ability readability turned up, so it isn't used.
