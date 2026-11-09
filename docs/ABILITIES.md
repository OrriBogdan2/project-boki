# Project Boki abilities

Every ability in an expedition, by slot. All of them are data. Hunter abilities: `content/abilities/*.json` (class dashes, weapon RMBs) and `content/gloves/*.json` (Q gloves), built from the effect verbs in `scripts/combat/effects.gd` and the world verbs in `scripts/combat/verbs.gd` (walls, mirrors, tethers, traps, bridges, yanks, decoys). Kin abilities, dodge riders and merges (E, its auto active, the Shift rider and R) are the kin grammar: `content/kin_v2`, `content/abilities_v2`, `content/merges_v2`, run by `scripts/kin/kin_exec.gd` (see docs/KIN_GRAMMAR.md). A new ability is a new JSON file either way.

This file is generated from the JSON by a script; the descriptions are the one-liners players see in the kit panel (K) and on hover.

## Archetypes (the kit you play)

Every hunter plays one of six archetypes (`content/archetypes/*.json`, run by `scripts/arch/arch_kit.gd` and `scripts/arch/kits/*`; design in docs/ARCHETYPES.md). The archetype owns RMB (with contextual variants), Shift (its dash shape), E (utility), R (ultimate, run level 6, rank 2 at 9) and a passive with its resource; the weapon owns LMB; Q is the glove; C is the kin's own ability (it hops out, casts, hops back) and G or middle mouse sends / recalls the kin. With a full bond meter, R is Bonded: the kin merges 0.2s after the ult. The kin's typing fills each ability's sockets (docs/ARCHETYPES.md §4).

| Archetype | Weight | Weapons | Dash | Passive | RMB | E | R |
|---|---|---|---|---|---|---|---|
| **Thief** | light | Twin Blades / SMG | Flicker | Marks | Knife | Smoke Veil (18s) | Heist (70s) |
| **Archer** | light | Longbow / Sniper | Grapple Arrow | Focus | Snare | Flare Arrow (16s) | Skyfall Volley (75s) |
| **Mage** | medium | Spellstaff / Longsword | Blink | Overload (Heat) | Bolt | Sigil (14s) | Meteor (70s) |
| **Gunslinger** | medium | Rifle / Burst Rifle | Slide Reload | Six Chambers | Trick Shot | Quickdraw (16s) | Last Round (70s) |
| **Juggernaut** | heavy | Greatsword / Shotgun / Minigun | Rampage | Rage | Smash | Iron Hide (16s) | Avalanche (75s) |
| **Bulwark** | heavy | Tower Shield & Mace / Minigun | Interpose | Guard | Shield | Rally Banner (18s) | Bastion (80s) |

### Thief (light)

_The cutpurse. Slips behind you, marks you, cashes in, gone in smoke._

- **Passive: Marks.** Hits from behind (or in the Ambush window) Mark the target: up to 3, 6s, +5% damage from you each. At 3 your next Knife on them Cashes In: +50% damage and your dash charge back.
- **Shift: Flicker** (6.5s a charge). Tap twice: two quick 2.3m steps on one charge (the second any way you like within 0.7s). Shots pass through each step. After the last step your next hit counts as from behind (Ambush, 1s).
- **RMB: Knife** (8s):
  - tap: Throw a knife 9m: 10 damage and a Mark. Recast within 1.5s of a hit to Shadow Step behind them (Ambush).
  - hold: Fan: 3 knives in a 35° fan, 6m, 6 damage, slow, a Mark each.
  - in the air: Drop Knife: the Shadow Step recast becomes a dive, a 1.5m burst for 8 behind them.
  - with E: Inside your smoke the knife is silent and its streak hidden.
  - resource full: Cash In: a target at 3 Marks takes +50% and refunds your dash.
- **E: Smoke Veil** (18s). A 3.5m cloud at the cursor (up to 6m) for 5s: everyone inside is hidden from outside, like tall grass. Attacking reveals you for 0.5s. Foes inside are slowed.
- **R: Heist** (70s, level 6). Gold lines mark up to 4 rival hunters within 9m (0.4s, anyone who dashes out or breaks sight drops out), then four blink strikes 0.2s apart: 14 damage and 3 Marks each. You end behind the last with Ambush open.
- Level-up order (bots too): RMB, Dash, E, RMB, Dash, R, RMB, E, R, Q

### Archer (light)

_The warden of high ground. Climbs, reads the field, pins people to walls._

- **Passive: Focus.** Builds while you stand still (full in 1.4s), sneak (2.8s), 50% faster on high ground. Drains while running and drops 40 when hit. At 100 your next shot is fully drawn or aimed at once, with +20% range.
- **Shift: Grapple Arrow** (7s a charge). A line arrow at the cursor (9m). If it bites a wall, rock or ledge you zip to it and climb on top; if it bites nothing you hop 3.2m back. Works from a glide and cools it.
- **RMB: Snare** (9s, 2 charges):
  - tap: A snare arrow 11m: 8 damage and root 0.6 on a foe; on the ground it plants a Tripwire (root 1.2, reveal 3s).
  - hold: Pinning Shot: 14m, 16 damage, push 6, pierces 1; pushed into a wall within 3m roots 1.2.
  - in the air: Plunge: shoot straight down, push 8 around you, lift yourself 3m, cool the glider.
  - with E: Inside your Flare zone snares seek revealed targets.
  - resource full: At 100 Focus the tap roots 1.0.
- **E: Flare Arrow** (16s). Lob a flare up to 14m: it reveals everyone within 7m for 4s, and the zone keeps revealing anyone who walks in. Shows traps, stealth and smoke.
- **R: Skyfall Volley** (75s, level 6). Aim a 5m circle up to 16m: 0.8s of arrows arcing up, then 5 waves 0.4s apart (6 damage, slow). The last roots 1.0 in the inner 2m.
- Level-up order (bots too): RMB, Dash, E, RMB, E, R, RMB, Dash, R, E

### Mage (medium)

_The runecaster. Draws sigils, throws bolts that take on the kin's nature, and runs dangerously hot._

- **Passive: Overload (Heat).** RMB adds 20 Heat (a hold 35), E adds 25; it cools after 1.2s. At 70+ you're Overcharged: RMB and E +25% damage and radius, bolts pierce. At 100 you Vent: a 0.4s ring, then a 3m nova (14, push 9), Heat 0, RMB locked 1s.
- **Shift: Blink** (9s a charge). A 0.12s windup (everyone sees the sigil where you'll land), then you teleport up to 5.5m, through walls, never into the abyss. A rune left behind bursts 0.6s later: slow.
- **RMB: Bolt** (2.5s):
  - tap: A bolt 10m: 14 damage and a slow (your kin's nature changes the slow).
  - hold: Lance: a 14m beam, 24 damage, pierces; you're slowed while it charges and foes see the line.
  - in the air: Starfall: a bolt into the ground under you: 10 damage, push 7, lifts you 2m and cools the glider.
  - with E: Through your Sigil a bolt splits into 3; a Lance chains to 2 more.
  - resource full: Overcharged (70+ Heat): +25% and pierces.
- **E: Sigil** (14s). Draw a 3m rune up to 9m away for 6s: allies inside move 15% faster and your bolts split through it. Press E again to detonate: a 0.3s flash, then 10 damage and a lift.
- **R: Meteor** (70s, level 6). Aim a 4m circle up to 14m: 1.0s of a burning rock coming down, then 30 damage and a lift; anyone already in the air is spiked (+50%, stun 0.8). Burning ground for 2s. Cast Overcharged and your Heat resets without a Vent.
- Level-up order (bots too): RMB, E, Dash, RMB, E, R, RMB, E, R, Dash

### Gunslinger (medium)

_The duelist. A rhythm of six, trick shots off walls, slide and reload._

- **Passive: Six Chambers.** Each weapon hit loads a chamber (one per 0.25s); a tap roll loads 2. At 6 the gun glows gold and your next Trick Shot is a Called Shot: +40%, a crit and stun 0.4. Chambers drain after 4s without a hit.
- **Shift: Slide Reload** (9s a charge). Tap: a 3.4m roll that slips 35% of the magazine in (roll through a hit as it lands: your next shots crit). Hold: a 6m low slide you can shoot from that fully reloads at the end; let go early to refund 30%.
- **RMB: Trick Shot** (7s):
  - tap: A ricochet round 9m: 12 damage, bounces off up to 2 walls and on to a second foe (+20% a bounce).
  - hold: Rail Charge: hold up to 1s, a piercing rail 10 to 34 damage, 9 to 17m; full charge stuns 0.6.
  - in the air: Recoil Shot: fire down and forward, kicked 3m up and back, the target pushed 6.
  - with E: During Quickdraw it fires two rounds, the second 0.1s later at 60%.
  - resource full: At 6 Chambers: a Called Shot (+40%, crit, stun 0.4).
- **E: Quickdraw** (16s). For 3s: fire 25% faster, an instant reload, a dash charge back, and your next Slide Reload's perfect-dodge window is twice as long.
- **R: Last Round** (70s, level 6). Channel up to 1.2s (slowed): gold lock lines draw to every rival hunter within 12m in sight. Press R again (or wait) to fire one round per lock: 16 + 12 per second locked; a full lock stuns 0.5. Breaking line of sight drops the lock.
- Level-up order (bots too): RMB, Dash, E, RMB, Dash, R, RMB, E, R, Q

### Juggernaut (heavy)

_The wrecking ball. Gets angrier, crashes through, slams you into the wall._

- **Passive: Rage.** +6 per hit, +10 per 10% of your health lost, +20 on a wall slam; cools after 3s out of a fight. At 100 you're Enraged for 5s: your next Smash is empowered (+50% knock; Earthshatter +1m and stuns everyone it lifts) and Rampage winds up twice as fast.
- **Shift: Rampage** (12s a charge). Tap: an unstoppable shoulder charge, 3m, shoves 10 (stun 1.2 into a wall). Hold: wind up to 0.7s while an arrow grows 3 to 7m for everyone to see, then charge it and carry the first hunter to a wall.
- **RMB: Smash** (9s):
  - tap: The weapon's knock cone: an Overhead Smash (3m, 18, push 6), or the Shotgun's Breach.
  - hold: Earthshatter: leap up to 7m, a 3m crater that lifts, spikes the airborne (+60%, stun 1.0).
  - in the air: Meteor Drop: slam straight down, a 2.5m burst (16, lift, spike stun 0.6).
  - with E: During Iron Hide the tap pulls foes within 4m in first.
  - resource full: Enraged: +50% knock, Earthshatter +1m and stuns everyone it lifts.
- **E: Iron Hide** (16s). 3s of 30% less damage and no knockback, with a cleanse on cast. When it ends a 2.5m burst shrugs everyone off (push 10).
- **R: Avalanche** (75s, level 6). A 0.35s roar, then 5s unstoppable (no stun, root or knockback; slows half strength) and 30% faster, stomping every 0.5s (6, push 6). The first wall slam on each foe stuns 1.0. Rampage charges refill.
- Level-up order (bots too): Dash, RMB, E, RMB, Dash, R, RMB, E, R, Q

### Bulwark (heavy)

_The squad's shield. Holds the line, plants a banner, leaps in to save an ally at the edge._

- **Passive: Guard.** Damage your shield, walls or Interpose guard blocks becomes Guard (1 per 2 blocked, max 100). Spent by Shield Slam (50), the Interpose ally shield (20) and Bastion (all of it, +1s per 50).
- **Shift: Interpose** (12s a charge). Tap: a braced 2.6m step that blocks shots from the front during it and 0.3s after, unshoveable. With an ally under the cursor (8m): leap to them, shield allies near the landing 15 and push foes off them.
- **RMB: Shield** (6s):
  - tap: Bash: a 2.5m cone, 10 damage, push 8, stun 0.8 into a wall.
  - hold: Raise the shield: 160 HP, regenerating; it blocks from the front.
  - in the air: Shield Surf: hold to block from the front while gliding.
  - with E: Inside your Banner the shield is wider and a Bash heals allies behind you 8.
  - resource full: Guard 50+: Shield Slam, push 12 and stun 0.6 even without a wall (spends 50).
- **E: Rally Banner** (18s). Plant a banner up to 7m away for 6s (60 HP, 4m): allies inside gain 6 shield a second (up to 24), foes inside are slowed.
- **R: Bastion** (80s, level 6). A 0.35s plant, then a 4.5m dome for 4s: rival shots from outside stop at it, foes inside are pushed out, allies inside regenerate 8/s. Spends all your Guard for +1s per 50.
- Level-up order (bots too): RMB, Dash, E, RMB, E, R, RMB, Dash, R, Q

The old class dashes and weapon RMBs below are kept as data (the verbs return as gloves and other content); a hunter with no archetype still uses them.

## Ranks

Every run starts with abilities locked (see `Hunter.slot_lv`). A skill point unlocks a slot at rank 1 and further points raise it (RMB, Q, Shift, E: ranks 1-3; R: ranks 1-2). Per rank past the first:

- damage +15% (`Effects.level_k`)
- cooldown 10% shorter (RMB, Q via `AbilityRunner`/`Hunter.rank_cd_k`, E via `KinRunner`); Shift dashes recharge 15% faster
- each verb grows the numbers that define it (`Effects.RANK_GROW`): walls +20% health, +15% time, +10% length; mirrors +20% time; tethers +15% time, +20% snap stun; traps +15% time and root; zones +15% time, +10% radius; fissures +10% length; shots +10% range and +15% stun/root/slow; pulls +15% strength; chains +1 hop per rank; yanks and swaps +25% stun; bridges +20% time; cloaks/decoys/reveals +20-25% time; shields and heals +15%; blinks +10% distance; blink-strike crit window +25%
- kin abilities grow through the core rank table `KinRules.RANK_GROW` (never through data), clamped to each part's bounds
- the merge (R) at rank 2 lasts 30% longer and its effects hit 15% harder
- dash and charge distances never grow: dashes stay short

An ability JSON can override any of these with `"per_level": {"key": flat amount per rank}`.

## Shift: class dashes

Each class has its own dodge verb. Grounded with a charge, Shift does the class dodge; in the air or out of charges it does the class's long dash (its own cooldown). Both chain straight into a jump or the glider.

| Class | Dash | Charges / cooldown | What it does |
|---|---|---|---|
| Light | **Phase Step** (3.6m) | 1 / 6.5s | Light: a short, very fast phase. Shots pass straight through you for the whole step. In the air, or on cooldown, Shift does the long dash. |
| Medium | **Combat Roll** (3.4m) | 1 / 9.0s | Medium: a quick roll that slips a third of a magazine in on the way. Roll through a hit as it lands for a perfect dodge: your next shots crit. |
| Heavy | **Shoulder Charge** (3.1m) | 2 / 12.0s | Heavy: a short charge nothing can knock back (2 charges). Anyone you run into is bowled aside, and slammed into a wall they're stunned 1.2s. |

### Kin dodge riders

The kin you brought adds a rider to every class dodge (`dodge_rider` in `content/kin_v2/<id>.json`).

| Kin | Rider | What it adds |
|---|---|---|
| Mycroll | **Spore Puff** | where you start: zone 1.5m: 2 damage, slow |
| Vespyx | **Venom Trail** | what you pass through: 3 damage, 12 damage over 3s, blight 3s |
| Gravadillo | **Gravity Wake** | where you stop: burst 3.5m: pull |
| Prismander | **Prism Decoy** | where you start: burst 0m: decoy |
| Lunowl | **Moon Blink** | the dodge is an instant blink |
| Echolop | **Echo Step** | a second, shorter dodge a beat later |

## RMB: weapon signature abilities (no archetype)

Right click is your weapon's own verb. Hold RMB to see its telegraph (lane, landing circle, wall footprint or arc); release to cast. Rail Charge charges while held instead.

| Weapon | Class | Ability | Verb | Cooldown | What it does |
|---|---|---|---|---|---|
| Burst Rifle | medium | **Leash Bolt** | tether | 10s | A bolt that leashes whoever it hits to you for 3.5s. If they get 6m away it snaps: 22 damage, stunned 1s, dragged back. |
| Greatsword | heavy | **Earthshatter** | leap slam | 10s | Leap up to 7m and smash down: everyone within 3m is thrown into the air; anyone already airborne is spiked (+60% damage, stunned 1s). |
| Longsword | medium | **Riposte** | reflect | 8s | Raise your blade for 0.7s: shots hitting your front fly back at the shooter (+30%), and a sword or claw that hits it is parried and stunned 1s. |
| Minigun | heavy | **Bulwark** | shield wall | 12s | Raise a 3m energy shield in front of you for 5s (160 HP). It turns with your aim and stops enemy shots; yours go through. |
| Rifle | medium | **Rail Charge** | charge-shot | 8s | Hold to charge for up to 1s, let go to fire a rail that pierces everyone in its line: 10 to 34 damage, 9 to 17m, full charge stuns. |
| Shotgun | heavy | **Breach** | knockback | 8s | A point-blank blast that throws everyone in front of you 6m back (into a wall: stunned) and kicks you backwards out of the fight. |
| SMG | light | **Razor Disc** | boomerang | 7s | Throw a spinning disc 8m that cuts everything it passes, then flies back to you and cuts them again. |
| Sniper | light | **Tripwire Mine** | trap | 10s | Plant a mine up to 8m away (2 charges). The first rival to step on it is rooted 1.4s, revealed for 3s and takes 14. |
| Twin Blades | light | **Shadow Step** | blink-strike | 8s | Throw a knife 9m. If it hits, you appear behind that foe and your next hits for 1.5s crit. |

## Q: active gloves

Gloves drop in runs. Rarer gloves keep the same verb with bigger numbers: damage, wall health, heals and shields x1 / x1.3 / x1.6 / x2 (common to legendary), durations and pull strength by half as much, cooldown 8% shorter per step. Rank (skill points into Q) stacks on top.

| Glove | Verb | Cooldown | What it does |
|---|---|---|---|
| **Barrier Glove** | wall | 18s | Raise a 4.5m stone wall at the cursor for 5s (220 HP): it stops shots and bodies from both sides. Knock people into it to stun them. |
| **Blink Glove** | blink-strike | 12s | Blink 5m toward the cursor (never into the abyss) and slash everything around where you land: 14 damage, slowed. |
| **Mirror Glove** | reflect | 14s | A 0.8s mirror bubble: every shot that reaches you flies back at whoever fired it, and a melee swing is parried. |
| **Ice Bridge Glove** | terrain | 18s | Freeze a 10m ice bridge toward the cursor across the abyss for 7s. Cross gaps, chase, escape, but it melts. |
| **Hook Glove** | hook | 12s | Fire a hook 10m: it drags the first foe it catches to your feet (stunned 0.3s), or pulls you to the wall or rock it bites. |
| **Gust Glove** | launch | 16s | A burst of wind launches you up and forward and cools your glider. Saves falls, reaches high ground. |
| **Hover Glove** | double jump | 7s | A second jump in mid-air, and your glider is ready the moment you want it. |
| **Springpad Glove** | launch pad | 22s | Throw down a jump pad. Anyone who steps on it is launched high. Lasts 20s. |
| **Mending Glove** | heal orb | 22s | Lob a mending orb at the cursor: you and teammates where it lands heal 35 and shake off slows, roots and poison. |
| **Ledge Glove** | terrain | 40s | Pop a floating platform under your feet for 8s. Your rescue over the abyss. |
| **Fissure Glove** | ground line | 14s | Crack the ground in an 8m line toward the cursor: it erupts end to end, throwing everyone on it into the air. |
| **Rocket Glove** | launch | 16s | Blast straight up into the sky and cool your glider by half. Chain it into a glide to go high and far. |
| **Seeker Glove** | reveal | 26s | Reveal every rival hunter within 26 tiles for 3s, through walls and grass. |
| **Vortex Glove** | pull | 16s | Lob a gravity bomb at the cursor: for 1s it drags everyone within 3.5m into its centre, then pops (12 damage, thrown up). |
| **Skyhook Glove** | grapple | 14s | Hook a point toward the cursor and swing up to it: onto a ledge above you, or high into the air. |
| **Smoke Glove** | stealth zone | 22s | A cloud that hides everyone inside it, like tall grass, for 8s. |
| **Decoy Glove** | decoy | 18s | Leave a glowing copy of yourself where you stand and vanish for 1.5s, moving faster. Bots keep shooting the copy. |

Passive gloves (no Q, stats only): **Glider Glove** (Glide 20% faster and longer.); **Swift Glove** (10% faster on foot.); **Focus Glove** (Abilities recharge 18% faster.); **Cooling Glove** (Your glider holds 45% more heat.); **Power Glove** (12% more damage.); **Plated Glove** (25 more armor.)

## E, the kin's own ability, and R, the merge

Each kin has one E ability (`active`), an auto active it uses by itself (`auto`), a throw (C), a dodge rider and a merge (R, unlocked at run level 6 with a full bond meter). Its abilities are built from grammar parts; the lines below are the creators' flavour text. In a match the HUD and hover panels read the parts themselves (`KinText`). E is cast from your shoulder (you perform it) or by the kin where it stands, aimed at the cursor.

### Mycroll (Hedgehog + Toadstool, shoulder)

- **E: Puffcap Mines** (trap, 10s): Mycroll plants three puffcaps in a triangle. Step on one and it bursts: rooted 1.4s inside a lingering spore cloud.
- **Auto: Spore Patch** (zone, 11s): On its own, when foes bunch up, Mycroll puffs a 4s spore cloud on them: slowed and taking damage while inside.
- **Throw (C)**: stuns what it hits; also root.
- **Shift rider: Spore Puff**
- **R: Sporewake** (8s): Mycroll grows into a giant toadstool beast for 8s. Its stomps root everything around it.

### Cairnback (Tortoise + Ibex, mount)

- **E: Boulder Heave** (projectile, 9s): Cairnback heaves a rune-lit boulder 8m. Where it lands everyone within 2.6m is thrown up and stunned; anyone already airborne is spiked.
- **Auto: Mass Guard** (wall, 12s): When you're under fire, Gravadillo curls into a heavy plate in front of you for 3s that stops enemy shots (120 HP).
- **Throw (C)**: stuns what it hits; also push.
- **R: Cairn Colossus** (8s): Cairnback rises into a rune-carved colossus under you for 8s: towering armor, and every stomp quakes the ground and stuns.

### Vespyx (Fox + Scorpion, shoulder)

- **E: Stinger Hook** (projectile, 8s): Vespyx lashes its tail 8m: the first foe it stings is dragged back to it, poisoned, blighted (healing halved) and stunned 0.3s.
- **Auto: Stinger Dash** (dash, 9s): On its own, Vespyx lunges 7m tail first, poisoning everything it passes through.
- **Throw (C)**: stuns what it hits; also 15 damage over 3s.
- **Shift rider: Venom Trail**
- **R: Venom Mantle** (7s): Vespyx fuses onto you as venomous armor for 7s: 30% more damage, and your shots poison and burst.

### Hivara (Honeybee + Praying mantis, shoulder)

- **E: Hive Swarm** (cone, 9s): Hivara looses a buzzing swarm in a 5m cone: stung, poisoned and slowed. The swarm then hangs over the spot for 3s, stinging anyone inside.
- **Auto: Spore Patch** (zone, 11s): On its own, when foes bunch up, Mycroll puffs a 4s spore cloud on them: slowed and taking damage while inside.
- **Throw (C)**: stuns what it hits; also slow.
- **R: Hive Crown** (7s): Hivara crowns you with its hive for 7s: 30% more damage, and every shot stings, poisons and slows.

### Gravadillo (Armadillo + Rhino beetle, mount)

- **E: Gravity Slam** (leap, 9s): Gravadillo drops onto the spot like a meteor: everything within 3.5m is sucked into the crater and flung up; anyone already airborne is spiked.
- **Auto: Mass Guard** (wall, 12s): When you're under fire, Gravadillo curls into a heavy plate in front of you for 3s that stops enemy shots (120 HP).
- **Throw (C)**: stuns what it hits; also push.
- **Shift rider: Gravity Wake**
- **R: Heavy Star** (8s): Gravadillo collapses into a towering heavy star for 8s. Huge health, and every stomp launches foes away.

### Prismander (Axolotl, shoulder)

- **E: Prism Wall** (wall, 10s): Prismander raises a 4m crystal wall at the spot: enemy shots that hit it bounce back at them. Lasts 4.5s or 140 damage.
- **Auto: Refraction** (burst, 12s): When you're hurt, Prismander wraps you in a 1s mirror shell: shots that reach you fly back at the shooter, and you get a 20 shield.
- **Throw (C)**: stuns what it hits; also slow.
- **Shift rider: Prism Decoy**
- **R: Prism Shell** (7s): Prismander wraps around you as a shell of living crystal for 7s: an 80 point shield, steady healing, and shots that slow.

### Lunowl (Owl + Luna moth, perch)

- **E: Moon Swap** (projectile, 10s): Lunowl throws a moon mark 9m. The first foe it touches trades places with YOU (stunned 0.4s): pull a rival off a ledge, or step behind them.
- **Auto: Moonlift** (burst, 14s): On its own, when you fall into the abyss, Lunowl throws up a column of moonlight that lifts you high and cools your glider.
- **Throw (C)**: stuns what it hits; also push.
- **Shift rider: Moon Blink**
- **R: Eclipse** (7s): Lunowl swells into a living eclipse for 7s that drags foes in and flings them skyward.

### Echolop (Hare + Bat, shoulder)

- **E: Echo Chain** (beam, 7s): A sound pulse leaps between up to 3 foes, stunning each 0.4s, then echoes 0.9s later and does it all again at half strength.
- **Auto: Echolocate** (burst, 14s): On its own in a fight, Echolop pings: every rival within 18m is revealed through grass and walls for 3s, and your next shots for 1.5s crit.
- **Throw (C)**: stuns what it hits; also stun.
- **Shift rider: Echo Step**
- **R: Resonance** (6s): Echolop hums over you for 6s: 30% faster, every dash back, and each shot echoes to a second foe.

### Zephyrak (Moray eel + Swift, shoulder)

- **E: Gale Lance** (dash, 8s): Zephyrak spears 8m through the air, shocking everything it passes, then bursts in a ring of wind that throws foes back and arcs lightning to two more.
- **Auto: Storm Arc** (beam, 10s): On its own, Zephyrak crackles a bolt at the nearest foe that jumps to two more.
- **Throw (C)**: stuns what it hits; also stun.
- **R: Stormwing** (7s): Zephyrak coils round you as living storm for 7s: 35% faster, every dodge back, and each shot arcs to a second foe.

## Element variants of shared verbs

Several verbs appear in more than one element, tuned to fit it:

- **Hook / yank**: Hook Glove (neutral, drags to your feet or zips you to terrain), Stinger Hook (venom: poisons and blights), Leash Bolt (tether that snaps back).
- **Wall**: Barrier Glove (stone, blocks shots and bodies both ways), Bulwark (energy, follows your aim, yours pass through), Mass Guard (gravity plate, raised for you when you're shot), Prism Wall (crystal, reflects shots).
- **Reflect**: Mirror Glove (all-round bubble), Riposte (frontal, parries melee), Refraction (prism, auto when hurt), Prism Wall (reflecting wall).
- **Slam / knock-up**: Earthshatter (hunter leap), Gravity Slam (kin meteor that pulls in first), Fissure Glove (a line eruption), Vortex Glove (pull then pop).
- **Blink**: Blink Glove (blink-strike), Shadow Step (appear behind who your knife hits), Moon Swap (lunar: trade places), Lunar dash rider.
- **Trap / zone**: Tripwire Mine (root + reveal), Puffcap Mines (spore triangle), Spore Patch (spore cloud), Spore dash rider.

## Readability

- Holding RMB, Q, E or R shows the cast's shape before you let go: a lane for shots and rushes (with a tick at the far end), a range ring plus landing circle for lobs and leaps, the wall's footprint across your aim, a cone, or a ring round you (`Match._update_indicators`, shape from `AbilityDef.aim_spec` and, for kin, `KinText.aim`).
- Enemy area casts get a 0.32s filling ground marker before they land; leaps show their landing circle to everyone; fissures show their lane filling.
- Each verb has its own shape in the world (wall slabs, a mirror shell, a rope for tethers, a disc, a hook, an orb, trap pads, ice tiles, ghost decoys) in its colour (kin abilities: effect category colour, `KinRules.CAT_COLORS`), plus HOOKED / SPIKED / PARRIED / SNAP / TRAP words when they go off.

## Bots

Each ability carries a `bot` hint (`when`: in_range, under_fire, clumped, hurt, gap, always; `min`/`max`), read by `Bot.ability_aim`: walls and mirrors go up when a bot is being shot, hooks and slams when the target is in reach and in sight, vortex and fissure when foes bunch, Rail Charge is held to full. Bots shoot decoys while the real hunter is cloaked. Bot points are spent automatically (`Hunter._bot_spend`).

