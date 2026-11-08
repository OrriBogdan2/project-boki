# Project Boki abilities

Every ability in an expedition, by slot. All of them are data. Hunter abilities: `content/abilities/*.json` (class dashes, weapon RMBs) and `content/gear/*.json` (Q gloves), built from the effect verbs in `scripts/combat/effects.gd` and the world verbs in `scripts/combat/verbs.gd` (walls, mirrors, tethers, traps, bridges, yanks, decoys). Kin abilities and merges (E, its auto active and the Merge) are the kin grammar: `content/kin_v2`, `content/abilities_v2`, `content/merges_v2`, run by `scripts/kin/kin_exec.gd` (see docs/KIN_GRAMMAR.md). A new ability is a new JSON file either way.

This file is generated from the JSON by a script; the descriptions are the one-liners players see in the kit panel (K) and on hover.

## Archetypes (the kit you play)

Every hunter plays one of six archetypes (`content/archetypes/*.json`, run by `scripts/arch/arch_kit.gd` and `scripts/arch/kits/*`; design in docs/ARCHETYPES.md). The archetype owns RMB (with contextual variants), Shift (its dash shape), E (utility), X (the hunter ultimate, run level 6, rank 2 at 9; none yet) and a passive with its resource; the weapon owns LMB; Q is the glove; C is the kin's own ability (it hops out, casts, hops back) and G or middle mouse sends / recalls the kin. T is the Merge with your Boki (a full bond meter), R reloads. The kin's typing fills each ability's sockets (docs/ARCHETYPES.md §4).

| Archetype | Weight | Weapons | Dash | Passive | RMB | E | R |
|---|---|---|---|---|---|---|---|
| **Thief** | light | Twin Blades | Vault | Marks | Bola | Shadow Knife (18s) | none (X is the Merge) |
| **Lisette** | light | Longbow | Spirit Walk | Focus | Heavy Shot | Hail Wall (9s) | none (X is the Merge) |
| **Ryzz** | light | Coilcaster | Wirerun | Sparks | Coilshot | Skycall (12s) | none (X is the Merge) |
| **Marlowe** | medium | Quill Rifle | Slipstep | Fever | Burr Charge | Longneedle (12s) | none (X is the Merge) |
| **Juggernaut** | heavy | Greatsword | Rampage | Rage | Smash | Warchain (13s) | none (X is the Merge) |
| **Breaker** | heavy | War Hammer & Aegis | 360 Smash | Guard | Aegis | Mending Ground (12s) | none (X is the Merge) |

### Thief (light)

_The cutpurse duelist. Sticks to one mark, flips past them, never lets go._

- **Passive: Marks.** Every weapon hit puts a Mark on the target (one per 0.3s, up to 5, each lasting 4s and refreshed by the next): your weapon hits on them deal +8% per Mark. A Primed hit adds 2, the Bola 1. The fifth Mark pays out Jackpot (below). A knock heals you 15% of your health on top of the usual knock heal (25% in all); an assist heals 25%.
- **Shift: Vault** (6.5s a charge). A 3.4m flip (shots pass through it) and +30% speed until your next hit (2s at most). Your next weapon hit within 3s is Primed: +10 damage, 2 Marks and Shred (+15% damage taken for 3s). Landing it resets Vault.
- **RMB: Bola** (12s):
  - tap: Throw a spinning Bola 10m: 6 damage and a Mark; the first foe it wraps is Grounded for 1.5s (no dash, jump or glide; slowed 25%) and the Bola flies on 5m. If it catches a second foe, both are stunned 0.9 and take +13 (TANGLED).
  - in the air: Thrown from the air the same way.
- **E: Shadow Knife** (18s). Throw a dagger 12m that sticks in the first foe (8 damage, slowed 50% for 2.5s) or in a wall or the ground where it stops. Press E again to step to it at once; after 5s you step to it anyway.
- Level-up order (bots too): RMB, Dash, E, RMB, Dash, R, RMB, E, R, Q

### Lisette (light)

_The warden of high ground. Climbs, reads the field, pins people to walls._

- **Passive: Focus.** Builds while you stand still (full in 1.4s), sneak (2.8s), 50% faster on high ground; a Heavy Shot that hits adds 40 (a wall pin fills it). Drains while running and drops 40 when hit. At 100 your next shot is Supercharged or aimed at once, with +20% range, and if it hits a rooted or stunned foe it is a Deadeye: +18 damage, a crit. Hawk Sense: rivals under half health are seen through cover within 22m. A knock heals 18.
- **Shift: Spirit Walk** (6s a charge). A quick dodge roll in the direction you move (or aim), then 2.8s as a spirit: rocks, trees, pillars, ability barriers and raised terrain don't stop you; you move 10% faster. Walking into something leaves a spirit orb there for 4s: anyone who touches it walks as a spirit too. Taking damage ends it. If it ends while you're inside something you lose 30 Focus and are put back where you went in.
- **RMB: Heavy Shot** (16s):
  - hold: Heavy Shot: hold to draw (0.5s to start, full at 1.1s, a rising creak, a ring, a ping at full) and let go to loose it: 16 -> 30 damage, push 6 -> 12, pierces 2; driven into a wall within 3m it hits again (up to 12) and stuns 1.2 (PINNED). A quick tap does nothing and costs nothing.
- **E: Hail Wall** (9s). Lob a volley: 0.35s later arrows rain for 4.4s on a curved wall 120 degrees wide round you, at the cursor distance (2-9m). Foes inside take 5 every 0.5s, are slowed 35% and burn blue (healing barely takes). A Heavy Shot that knocks a burning foe Cremates them: +10 and a longer burn.
- Level-up order (bots too): RMB, Dash, E, RMB, E, RMB, Dash, E

### Ryzz (light)

_The storm-kite runner. Charges you up shot by shot, then runs straight through you and comes out the other side with the dash back._

- **Passive: Sparks.** Your bolts, Coilshot and Skycall each load a Spark onto what they hit (up to 4, 4.5s, refreshed by every hit). At 4 the foe is Live: a ring of crackling pips over them that everyone sees. Wirerun through a Live foe for a Blowout: 8 damage plus 15% of their health, a T4 hit, their Sparks spent and your dash recharged on the spot. Knocking a hunter down heals you for 15% of your health.
- **Shift: Wirerun** (9s a charge). Press and hold: a lane grows from 5 to 8.5m over 0.45s for everyone to see; let go and you streak along it. Shots pass straight through you for the whole run, and every foe you cross takes 10. Crossing a Live foe is a Blowout and gives the dash straight back. Picking up a charge mote also gives it back.
- **RMB: Coilshot** (10s):
  - tap: A quick Coilshot (it still takes 0.33s to wind): 9 damage, 6m, a short throw.
  - hold: Hold up to 1s: up to 15 damage, 13m and a big throw. A foe thrown into a wall or into another foe is stunned 0.8s (so is the one they hit). Hitting a hunter drops a charge mote 0.5s later: pick it up for your dash back.
- **E: Skycall** (12s). Mark a spot up to 9m away (a filling ring everyone sees); 0.55s later lightning strikes it: 14 damage, a Spark, and everyone inside is flung along your aim and Grounded for 1.2s (no dashing). It also flings any charge mote it catches, so you can steal a rival's.
- Level-up order (bots too): RMB, Dash, E, RMB, Dash, E, RMB, Dash, E

### Marlowe (medium)

_The burr-and-needle marksman. Tags a foe with a clinging charge, lets the rifle and one long needle of light do the rest, and lives off every hit that lands._

- **Passive: Fever.** Each ability that lands (Burr Charge, its blast, Longneedle) adds a stack, up to 8, lasting 3.5s. Every stack makes your damage heal you for 6%, rifle included. A Burr Charge counts twice, once when it sticks and once when it goes off. Knocking a hunter down heals a quarter of your health and refreshes Slipstep.
- **Shift: Slipstep** (11.5s a charge). Tap: a quick 3.4m skid. Hold: a 6m low slide you can shoot from; let go early and part of the cooldown comes back. A knock refreshes it.
- **RMB: Burr Charge** (9s):
  - tap: Lob a burr 11m. On a hunter or monster it sticks, then pops after 0.7s: 13 damage in 1.9m and Rattled for 1.2s.
  - resource full: On a wall it blasts a cone back out: 10 damage, a hard shove, Rattled for 2s; a hunter shoved into more terrain is stunned, and the Burr Charge's cooldown drops 40%.
- **E: Longneedle** (12s). Stand and charge for 0.8s (slowed, a lane shows), then fire a needle of light 14m that passes through cover and everything in its line: 36 damage, 20% more on a Rattled foe, and a Rattled hunter hit is Skewered. Hitting a hunter takes 30% off its cooldown.
- Level-up order (bots too): RMB, Dash, E, RMB, Dash, E, RMB, Dash, E

### Juggernaut (heavy)

_The wrecking ball. Burns hotter with every hit, chains you in, and finishes it._

- **Passive: Rage.** Damage you deal fills Rage (a Searing Wave fills it three times as fast); it cools after 3s out of a fight. Full, you're Enraged for 6s: +15% damage, +12% dash recharge and +20% cooldown speed, with the red shell and the hunter swelling. Knocking a hunter heals you 20% of their health (killing a monster, 20% of its).
- **Shift: Rampage** (9s a charge). A 4.4m dash attack the way you face (2 charges): 7 to foes along it; the tip at its end hits twice as hard, 14 and a big knock (stun 0.8 into a wall). A knock gives a charge back.
- **RMB: Smash** (3s):
  - tap: Finishing Slam: a 0.5s wind-up you aim freely (a warning shows over you), then a 3.2m cone: 26 and push 6; foes under 35% take +50%. Landing its sweet spot (the far tip, dead ahead) is a SWEET SPOT payoff; at rank 3 it also brings a 3m crash down on the foe (24, push 7, heals you 60% of the damage it deals; rests 12s, and a knock on anyone it hit within 2s makes it ready at once).
  - hold: Lunge: charge 0.3 -> full at 0.9s, then a 3 -> 7m dash attack into the first foe: 14 -> 22. Strike nothing and the cooldown doubles.
  - in the air: Meteor Drop: slam straight down, a 2.6m burst: 18 and slow 40% for 1.5s; the centre (1.2m) takes +50% and is stunned 0.8.
  - with E: With the Warchain: tap while it pulls you for a Cinder Spin (2.6m, 18, blights 4s); hold while it pulls you, or hold and then pull, for a Haul Slam where you arrive (2.8m, 16 -> 30, stun 0.25 -> 0.6); hold while it's attached and let go for a Chain Lunge along it (x1.25 and a short stun).
- **E: Warchain** (13s). Throw a chain 10m: it hooks the first foe (8 damage, blighted while tethered: healing barely takes) or bites a wall, for 4s. Press E again to pull yourself to it. The cooldown starts when you pull or the chain breaks (a stun breaks it); you can't throw it while rooted or grounded.
- Level-up order (bots too): Dash, RMB, E, RMB, Dash, R, RMB, E, R, Q

### Breaker (heavy)

_The squad's shield. Holds the line with his aegis, plants his hammer where the fight is, and heals the spot._

- **Passive: Guard.** Damage your aegis blocks becomes Guard (1 per 2 blocked, max 100); at 50 your Shield Charge ends in a Shield Slam (push 12, stun 0.6, spends 50). Crushed: any knock of yours (Crushing Blow, 360 Smash, Shield Charge, Shield Slam) that drives a foe into a wall or another foe stuns it 0.5 (8 damage).
- **Shift: 360 Smash** (9s a charge). 360 Smash: a hard 3.5m dash (0.17s) that slides on through one full spin of the hammer around you (2.2m): 24 damage, push 7. With the aegis raised it's a Shield Charge on its own 6s cooldown (it spends no dash charge): 4.2m behind the aegis, invulnerable for its length, 10 damage and push 11 (into a wall or a foe: Crushed). Shift while spinning up a Crushing Blow: a short plain dash that costs half a charge.
- **RMB: Aegis** (6s):
  - tap: A tap only raises and lowers the aegis; the Bash is the Shield Charge on Shift.
  - hold: Raise the aegis: a curved gold shield with 160 HP that regenerates; it blocks shots from the front and you walk slower. With it up, Shift is the Shield Charge on this slot's 6s cooldown.
  - in the air: Shield Surf: hold to block from the front while gliding.
  - resource full: Guard 50+: the Shield Charge ends in a Shield Slam, 18 damage, push 12 and stun 0.6 (spends 50).
- **E: Mending Ground** (12s). A green light column comes down for 1s on your hammer (on you with the hammer in hand), then the zone round it heals allies inside 2 every 0.5s for 4s, following the hammer, and ends in a burst of 18; if your aegis is raised the burst mends it 60. A downed teammate inside is a third of the way back up at the burst.
- Level-up order (bots too): RMB, Dash, E, RMB, E, RMB, Dash, Q

The old class dashes and weapon RMBs below are kept as data (the verbs return as gloves and other content); a hunter with no archetype still uses them.

## Ranks

Every run starts with abilities locked (see `Hunter.slot_lv`). A skill point unlocks a slot at rank 1 and further points raise it (RMB, Q, Shift, E: ranks 1-3; R: ranks 1-2). You choose where each point goes: Alt + the ability's key, or click the gold + on its slot (`RankMarks`, `RankClick`), so one ability can be maxed first; tier pips over each slot show its rank and turn gold at max, and a new point shows the ALT+key hint for a few seconds. Bots spend by their kit's `order`. Per rank past the first:

- damage +15% (`Effects.level_k`)
- cooldown 10% shorter (RMB, Q via `AbilityRunner`/`Hunter.rank_cd_k`, E via `KinRunner`); Shift dashes recharge 15% faster
- each verb grows the numbers that define it (`Effects.RANK_GROW`): walls +20% health, +15% time, +10% length; mirrors +20% time; tethers +15% time, +20% snap stun; traps +15% time and root; zones +15% time, +10% radius; fissures +10% length; shots +10% range and +15% stun/root/slow; pulls +15% strength; chains +1 hop per rank; yanks and swaps +25% stun; bridges +20% time; cloaks/decoys/reveals +20-25% time; shields and heals +15%; blinks +10% distance; blink-strike crit window +25%
- kin abilities grow through the core rank table `KinRules.RANK_GROW` (never through data), clamped to each part's bounds
- the merge at rank 2 lasts 30% longer and its effects hit 15% harder
- dash and charge distances never grow: dashes stay short

An ability JSON can override any of these with `"per_level": {"key": flat amount per rank}`.

## Shift: class dashes

Each class has its own dodge verb. Grounded with a charge, Shift does the class dodge; in the air or out of charges it does the class's long dash (its own cooldown). Both chain straight into a jump or the glider.

| Class | Dash | Charges / cooldown | What it does |
|---|---|---|---|
| Light | **Phase Step** (3.6m) | 1 / 6.5s | Light: a short, very fast phase. Shots pass straight through you for the whole step. In the air, or on cooldown, Shift does the long dash. |
| Medium | **Combat Roll** (3.4m) | 1 / 9.0s | Medium: a quick roll that slips a third of a magazine in on the way. Roll through a hit as it lands for a perfect dodge: your next shots crit. |
| Heavy | **Shoulder Charge** (3.1m) | 2 / 12.0s | Heavy: a short charge nothing can knock back (2 charges). Anyone you run into is bowled aside, and slammed into a wall they're stunned 1.2s. |

## RMB: weapon signature abilities (no archetype)

Right click is your weapon's own verb. Hold RMB to see its telegraph (lane, landing circle, wall footprint or arc); release to cast. Rail Charge charges while held instead.

| Weapon | Class | Ability | Verb | Cooldown | What it does |
|---|---|---|---|---|---|
| Burst Rifle | medium | **Leash Bolt** | tether | 10s | A bolt that leashes whoever it hits to you for 3.5s. If they get 6m away it snaps: 22 damage, stunned 1s, dragged back. |
| Greatsword | heavy | **Earthshatter** | leap slam | 10s | Leap up to 7m and smash down: everyone within 3m is thrown into the air; anyone already airborne is spiked (+60% damage, stunned 1s). |
| Longsword | medium | **Riposte** | reflect | 8s | Raise your blade for 0.7s: shots hitting your front fly back at the shooter (+30%), and a sword or claw that hits it is parried and stunned 1s. |
| Minigun | heavy | **Bracewall** | shield wall | 12s | Raise a 3m energy shield in front of you for 5s (160 HP). It turns with your aim and stops enemy shots; yours go through. |
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

Passive gloves (no Q, stats only): **Bastion Plate** (Heavy plate: lots of armor, a little slower on foot.); **Glider Glove** (Glide faster and longer.); **Springheel Boots** (Sprung soles: faster on foot.); **Field Surgeon's Kit** (Needle and thread: tonics heal more.); **Focus Glove** (Abilities recharge faster.); **Gale Mantle** (A light cloak that catches the wind: some armor and a faster glide.); **Cooling Glove** (Your glider holds more heat.); **Magpie Pouch** (Shiny things stick: gems you pick up are worth more.); **Power Glove** (More damage.); **Quickstep Boots** (Spring-loaded heels: dashes come back sooner and a touch more speed.); **Quilted Coat** (Padded and warm: more health and some armor.); **Wayfarer's Satchel** (A deep bag: one more backpack slot (two from Epic).); **Skylark Boots** (Feathered cuffs: your glider lasts longer.); **Brass Spyglass** (See further through grass and gloom.); **Tinker's Roll** (A roll of small tools: reloads faster.); **Brace Plate** (A bolted breastplate: extra armor.); **Windstep Boots** (Light soles for the air: a faster glide that runs hot later.)

## E, the kin's own ability, and the merge

Each kin has one E ability (`active`), an auto active it uses by itself (`auto`), a throw (G) and a merge (the Merge key, X by default, unlocked at run level 6 with a full bond meter). Its abilities are built from grammar parts; the lines below are the creators' flavour text. In a match the HUD and hover panels read the parts themselves (`KinText`). E is cast from your shoulder (you perform it) or by the kin where it stands, aimed at the cursor.

### Mycroll (Hedgehog + Toadstool, shoulder)

- **E: Puffcap Mines** (trap, 10s): Mycroll plants three puffcaps in a triangle. Step on one and it bursts: rooted 1.4s inside a lingering spore cloud.
- **Auto: Spore Patch** (zone, 11s): On its own, when foes bunch up, Mycroll puffs a 4s spore cloud on them: slowed and taking damage while inside.
- **Throw (C)**: stuns what it hits; also root.
- **Merge: Sporewake** (8s): Mycroll grows into a giant toadstool beast for 8s. Its stomps root everything around it.

### Cairnback (Tortoise + Ibex, mount)

- **E: Boulder Heave** (projectile, 9s): Cairnback heaves a rune-lit boulder 8m. Where it lands everyone within 2.6m is thrown up and stunned; anyone already airborne is spiked.
- **Auto: Mass Guard** (wall, 12s): When you're under fire, Gravadillo curls into a heavy plate in front of you for 3s that stops enemy shots (120 HP).
- **Throw (C)**: stuns what it hits; also push.
- **Merge: Cairn Colossus** (8s): Cairnback rises into a rune-carved colossus under you for 8s: a stone shell takes the hits first, and every stomp quakes the ground and stuns.

### Vespyx (Fox + Scorpion, shoulder)

- **E: Stinger Hook** (projectile, 8s): Vespyx lashes its tail 8m: the first foe it stings is dragged back to it, poisoned, blighted (healing halved) and stunned 0.3s.
- **Auto: Stinger Dash** (dash, 9s): On its own, Vespyx lunges 7m tail first, poisoning everything it passes through.
- **Throw (C)**: stuns what it hits; also 15 damage over 3s.
- **Merge: Venom Mantle** (7s): Vespyx fuses onto you as venomous armor for 7s: 20% more damage, and your shots poison and burst.

### Hivara (Honeybee + Praying mantis, shoulder)

- **E: Hive Swarm** (cone, 9s): Hivara looses a buzzing swarm in a 5m cone: stung, poisoned and slowed. The swarm then hangs over the spot for 3s, stinging anyone inside.
- **Auto: Spore Patch** (zone, 11s): On its own, when foes bunch up, Mycroll puffs a 4s spore cloud on them: slowed and taking damage while inside.
- **Throw (C)**: stuns what it hits; also slow.
- **Merge: Hive Crown** (7s): Hivara crowns you with its hive for 7s: 20% more damage, and every shot stings, poisons and slows.

### Gravadillo (Armadillo + Rhino beetle, mount)

- **E: Gravity Slam** (leap, 9s): Gravadillo drops onto the spot like a meteor: everything within 3.5m is sucked into the crater and flung up; anyone already airborne is spiked.
- **Auto: Mass Guard** (wall, 12s): When you're under fire, Gravadillo curls into a heavy plate in front of you for 3s that stops enemy shots (120 HP).
- **Throw (C)**: stuns what it hits; also push.
- **Merge: Heavy Star** (10s): Gravadillo folds into you as a heavy star for 10s. Slam with the left button, roll through foes with the right, drag them in with E, then Merge again brings the whole sky down.

### Prismander (Axolotl, shoulder)

- **E: Prism Wall** (wall, 10s): Prismander raises a 4m crystal wall at the spot: enemy shots that hit it bounce back at them. Lasts 4.5s or 140 damage.
- **Auto: Refraction** (burst, 12s): When you're hurt, Prismander wraps you in a 1s mirror shell: shots that reach you fly back at the shooter, and you get a 20 shield.
- **Throw (C)**: stuns what it hits; also slow.
- **Merge: Prism Shell** (10s): Prismander grows a crystal shell around you for 10s. Piercing shards, a prism that throws shots back, a healing crystal wall, and Merge again shatters the shell outward.

### Lunowl (Owl + Luna moth, perch)

- **E: Moon Swap** (projectile, 10s): Lunowl throws a moon mark 9m. The first foe it touches trades places with YOU (stunned 0.4s): pull a rival off a ledge, or step behind them.
- **Auto: Moonlift** (burst, 14s): On its own, when you fall into the abyss, Lunowl throws up a column of moonlight that lifts you high and cools your glider.
- **Throw (C)**: stuns what it hits; also push.
- **Merge: Eclipse** (7s): Lunowl swells into a living eclipse for 7s that drags foes in and flings them skyward.

### Echolop (Hare + Bat, shoulder)

- **E: Echo Chain** (beam, 7s): A sound pulse leaps between up to 3 foes, stunning each 0.4s, then echoes 0.9s later and does it all again at half strength.
- **Auto: Echolocate** (burst, 14s): On its own in a fight, Echolop pings: every rival within 18m is revealed through grass and walls for 3s, and your next shots for 1.5s crit.
- **Throw (C)**: stuns what it hits; also stun.
- **Merge: Resonance** (6s): Echolop hums over you for 6s: 30% faster, every dash back, and each shot echoes to a second foe.

### Zephyrak (Moray eel + Swift, shoulder)

- **E: Gale Lance** (dash, 8s): Zephyrak spears 8m through the air, shocking everything it passes, then bursts in a ring of wind that throws foes back and arcs lightning to two more.
- **Auto: Storm Arc** (beam, 10s): On its own, Zephyrak crackles a bolt at the nearest foe that jumps to two more.
- **Throw (C)**: stuns what it hits; also stun.
- **Merge: Stormwing** (10s): Zephyrak wraps you in a living storm for 10s. Chaining bolts, a hover over any gap, a double storm blink, and Merge again calls a thunderhead down on everyone near.

## Element variants of shared verbs

Several verbs appear in more than one element, tuned to fit it:

- **Hook / yank**: Hook Glove (neutral, drags to your feet or zips you to terrain), Stinger Hook (venom: poisons and blights), Leash Bolt (tether that snaps back).
- **Wall**: Barrier Glove (stone, blocks shots and bodies both ways), Bracewall (energy, follows your aim, yours pass through), Mass Guard (gravity plate, raised for you when you're shot), Prism Wall (crystal, reflects shots).
- **Reflect**: Mirror Glove (all-round bubble), Riposte (frontal, parries melee), Refraction (prism, auto when hurt), Prism Wall (reflecting wall).
- **Slam / knock-up**: Earthshatter (hunter leap), Gravity Slam (kin meteor that pulls in first), Fissure Glove (a line eruption), Vortex Glove (pull then pop).
- **Blink**: Blink Glove (blink-strike), Shadow Step (appear behind who your knife hits), Moon Swap (lunar: trade places).
- **Trap / zone**: Tripwire Mine (root + reveal), Puffcap Mines (spore triangle), Spore Patch (spore cloud).

## Readability

- Holding RMB, Q, E or R shows the cast's shape before you let go: a lane for shots and rushes (with a tick at the far end), a range ring plus landing circle for lobs and leaps, the wall's footprint across your aim, a cone, or a ring round you (`Match._update_indicators`, shape from `AbilityDef.aim_spec` and, for kin, `KinText.aim`).
- Enemy area casts get a 0.32s filling ground marker before they land; leaps show their landing circle to everyone; fissures show their lane filling.
- Each verb has its own shape in the world (wall slabs, a mirror shell, a rope for tethers, a disc, a hook, an orb, trap pads, ice tiles, ghost decoys) in its colour (kin abilities: effect category colour, `KinRules.CAT_COLORS`), plus HOOKED / SPIKED / PARRIED / SNAP / TRAP words when they go off.

## Bots

Each ability carries a `bot` hint (`when`: in_range, under_fire, clumped, hurt, gap, always; `min`/`max`), read by `Bot.ability_aim`: walls and mirrors go up when a bot is being shot, hooks and slams when the target is in reach and in sight, vortex and fissure when foes bunch, Rail Charge is held to full. Bots shoot decoys while the real hunter is cloaked. Bot points are spent automatically (`Hunter._bot_spend`).

