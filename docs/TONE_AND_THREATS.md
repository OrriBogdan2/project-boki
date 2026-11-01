# Tone, threats and companions: what we take from ARC Raiders and Palworld

Owner direction (Oct 31 2026): "more ARC Raiders (scarier environment, scarier enemies, less
SUPERVIVE in a way) as well as Palworld concepts". Read with docs/POSITIONING.md.

What stays: the top-down camera, the archetype kits, the controls and the speed of a fight. What
changes: the world around the fight becomes dangerous and moody, PvE becomes a real threat that
shapes PvP, and Boki become useful far beyond combat.

## From ARC Raiders: a world that wants you dead

### 1. The Blight (a new enemy faction)
The Wyrm's corruption, left behind by the Sundering. Not cute critters: things that are wrong.
- **Look:** original designs, half-creature half-petrified wreck: stone and bone shells, ember-lit
  cracks, too many legs, no faces. Silhouettes readable from the top-down camera (each type has
  one unmistakable shape), with a sound before they're seen.
- **Roster (first pass):**
  - *Skitters*: small, fast, come in packs, climb walls; dangerous when you're alone or reloading.
  - *Wardens of the Blight*: slow sentries that sweep a cone of light; spotted means a shriek that
    wakes everything nearby.
  - *Hollow Fliers*: circle overhead, dive at gliders (the sky stops being safe).
  - *Husks*: armored brutes that charge through cover and break it.
  - *The Walker*: one huge roaming threat per map that crosses islands on a route, levels cover,
    and is visible from far away. Killing it takes a squad or two working together and drops the
    best loot of the match. Ignoring it is valid; being in its way is not.
- **Behaviour:** they hunt by **noise** and **light**. Gunfire, explosions, sprinting and opened
  chests make sound pings (the sound-ping system already exists); a loud fight draws them in, so
  a third party might be the Blight, not a squad. Quiet play (crouch, melee, suppressed weapons,
  Boki scouting) is rewarded.
- **Threat to everyone:** the Blight attacks every squad, so it creates truces, betrayals and
  "do we fight them or the thing coming?" moments (the truce system already exists).

### 1b. Pacing: the Blight starts weak (owner, Nov 1)
Players drop at level 1 with one ability and level up fast by farming camps (SUPERVIVE-style), so the
Blight must not punish the opening minutes:
- **Early (first minutes after you land, and the safer outer islands):** only light Blight: lone
  Skitters and a few Wardens whose shriek is a warning, not a death sentence. The normal monster camps
  stay the main way to level.
- **Ramps with time and depth:** the Blight's strength and numbers scale with how long you've been in
  (per squad, so late joiners in rolling sessions also get a soft start), the region (dangerous core vs
  outer islands), the raid condition (night/storm = more) and noise. Husks and Fliers come later;
  the Walker appears mid-session.
- **Smarter, not tankier, early on:** early Blight hunt by noise and light, but die fast and hit softly;
  later ones get the real health and damage.
- Tuned so a level-1 hunter can always fight or flee a Blight they meet in the first minutes.

### 2. A scarier environment
- **Raid conditions** rolled per match and shown before you drop: clear day, dusk, night, ash storm,
  fog. Night and fog shrink sight (the sight system already exists), make light sources matter
  (lanterns, glowing Boki, muzzle flashes give you away) and raise Blight activity.
- **Art direction shift:** lower saturation, heavier fog and volumetric light shafts, colour mostly
  in danger (ember cracks, warning lights) and in Boki. Ruins of the old world, scars of the
  Sundering. Keep it stylized (painterly, not gritty realism).
- **Sound as information:** distant shrieks, the Walker's footsteps shaking the camera, quiet
  ambience that drops out before something arrives. Positional audio for every threat.
- **Extraction pressure:** some exits are timed or contested (an uplink you have to hold while the
  noise draws the Blight), plus the rift hatch and updrafts we have.

### 3. Raider culture
- **Free kit option:** queue with a basic loadout and no Boki at risk, so losing everything never
  locks a player out (ARC's free loadout).
- **Emergent social play:** emotes and pings readable by rivals (the "don't shoot" wave), truce
  offers, and the betrayal risk that comes with them.
- **Loot that matters at home:** most loot becomes materials for the farm, crafting and Boki care,
  not only gear for the next run.

## From Palworld: Boki that do things

1. **Boki work the farm.** Each species has work skills (hauling, chopping, mining, farming,
  kindling, watering, building, guarding) with levels. Assign Boki to stations and they work while
  you're away or on a run (home_work.gd is the starting point). This is the survival-lite loop the
  owner asked for: cut trees, mine, forage, craft, build, with Boki doing the repetitive part.
2. **Boki move you through the world.** Riding (exists), swimming, climbing, short flight, carrying
  loot, scouting ahead. Each species has one standout traversal or utility trick, so which Boki
  you bring changes your route, not just your damage.
3. **Partner skills.** Each species' own active (C) is distinct and readable (Palworld's partner
  skills); typing infuses your archetype (as designed in ARCHETYPES.md).
4. **Breeding for traits.** IVs, mutations, uniqueness rolls and inheritance (built or in progress)
  give a long-term goal: breeding the Boki you want, not buying it.
5. **A base that is yours.** Each farm island is distinct; you build it up from almost nothing.

### What we don't take from Palworld
- **Throwing an item to capture a creature** and its exact riding/switching mechanics: Nintendo
  has patents on these and sued Pocketpair. Our taming is different by design: a dazed Boki is
  befriended (approach, feed, hold to bond), and how fast it bonds depends on your care and its
  personality. Get a lawyer to review taming and riding before any commercial launch.
- The "creature with a gun" parody tone. Boki are wildlife and partners.
- Survival chores as the main loop. The survival layer stays light; runs are the game.

## Build order (proposed)
1. Raid conditions + lighting/fog/art direction pass on the match map (biggest change in feel).
2. The Blight: noise/light hunting AI, then Skitters, Wardens, Fliers, Husks, then the Walker.
3. Boki work skills + farm stations + survival-lite (combined with the farm-start rework).
4. Per-species traversal/utility tricks (feeds the 150-Boki pipeline).
5. Free kit queue option and rival-readable emotes.
