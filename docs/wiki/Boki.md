# Boki

Boki are the Skylands' wildlife. Each species is built from one or two real animals and has a type of
its own. Every single Boki is also its own animal: its size, coat, eyes, voice, habits and personality
are rolled when it hatches or is caught, and it remembers what you do together.

Every species, with its abilities and evolution paths, is on [Boki species](Boki-Species.md). The
numbers behind bonds, IVs, mutations and evolution are on [Boki growth](Boki-Growth.md).

## Types

A Boki's type (Venom, Prism, Spore, Echo, Gravity, Lunar, Titan, Swarm, Tempest) is the flavour of
its abilities. It doesn't change what your class can do; it adds to it (see
[Classes](Classes.md#your-boki-and-your-class)). On the farm, each species also has work knacks that
roughly follow its type (an Ember-type knack bakes and warms eggs, Tide waters, and so on).

## In a match

You bring **one Boki** per expedition. It walks beside you and fights with you; on the **Return** order it goes back onto you (big ones are ridden, some perch).

- **C** is its own ability, cast from wherever your Boki is: on you (Return) it casts through you, out in the world it casts where it stands. It also has an **auto ability** it uses
  on its own when the moment is right (Settings can turn that off).
- **G**: with your Boki at your side, tap to **Sic** it at the cursor: it leaps there and its
  landing staggers whatever it lands on. With it away, tap to **Call back**: it leaps to your side and hits
  anything along the path (only within a set range; farther out it comes back on its own). **Hold G** for the
  order wheel and flick toward one: **Chase** (go for what is under the cursor), **Guard** (hold this spot),
  **Return** (back onto you: perch, or you ride it) or **Follow** (the default: beside you). A Boki you are
  carrying only gives its carried bonuses on **Return**, so choose between a fighting partner and a perk.
  It never leaves you behind: if it is stuck or too far it leaps back to your side, and on a glide or a
  long drop it hops onto you and hops off again once you are steady. In a fight it never turns down an
  order, though a Wary one may think about it for a moment.
- **A downed Boki** stays where it fell, marked on your screen and the minimap. Run into it to
  pick it up: you kneel, then cradle it, for 3.5 seconds, rooted and unable to attack. A dash, a stun, a
  root or a knockback stops it (damage alone does not), and the progress drains back over about two
  seconds instead of vanishing. It comes back with 60% health. Left alone it comes round after 15 to 20
  seconds at low health. While it is down you have no C, no shoulder perks, and R only says "Rescue
  (name) to merge"; the meter keeps filling. Rivals can't take it while you are still in the map.
- **Your dash** carries a little of it too (a spore puff, a venom trail, a moon blink...).
- **The bond meter.** Your hits, its hits, combos and its knockouts fill a shared meter. Press **R**
  with a full meter and you **transform** (about 0.7 seconds, you cannot be hurt): the Boki leaps into
  you and you become its form for about ten seconds, the same for everyone. Rivals see and hear it, and
  your name plate shows the form and what is left. A form has a shell of extra health on top of your own,
  and replaces left click, right click (a hold) and E with its own kit; Shift is flavoured, Q stays and C
  is off. Press **R** again to fire the form's ultimate (it unlocks a moment in) and split apart, or let
  the timer run out. If the shell breaks, or you are knocked out of it, the Boki pops out and the merge
  ends. Heavy Star (Pebbit), Stormwing (Zephyrak) and Prism Shell (Puddlet) have full kits; the other
  Boki merge for a plain stat boost and a basic burst on the second R for now. With no Boki at all R is
  only a weak three second surge. Hits on foes your Boki marked fill the meter faster.
- **Combos.** Your Boki stuns or roots a foe and your next hit on it lands a COMBO. You stun or slow a
  foe and your Boki's next hit POUNCES. Its ability on a burning foe FLARES. See [Rules](Rules.md#combos).
- **It's a teammate.** It calls out rivals behind you, snipers, monster packs, loot and wild Boki; it
  frets when you're hurt, stands over you when you're down, and pulls you back up (8 seconds) if
  nobody else can (if it isn't down itself).
- **It has a mind.** Aggression, loyalty and caution decide how far it chases, how close it stays, who
  it goes after and when it backs off. Away from a fight, a Wary Boki may refuse a reckless Sic; a
  hot-tempered one may ignore a Call back to finish a kill.

## Personality and bond

Each Boki has four traits (bravery, loyalty, temper, curiosity), seeded by its species and varied
per Boki, which drift with experience. Its two strongest traits give it a **nature**.

**Trust** runs from 0 to 100 and sets its bond rank: Wary, Friendly, Close (skills hit 5% harder),
Devoted (rushes to revive you) and Soulbound (never refuses, +10% health and damage). Trust rises when
you extract together, talk, pet and feed it; it falls when you throw it into danger while it's hurt,
or when you lose together.

Newly hatched Boki can only say their own name. With levels and trust they pick up words, then short
sentences, and a grown, Devoted Boki talks freely.

## Raising

- **Needs.** Full, Energy, Happy and Clean drift down at home and drop after every expedition. A Boki
  in great shape fights better; a struggling one fights worse and refuses you more. A Boki left with
  nothing to eat starves in stages (weak, too weak to go out, sick) but never dies of neglect
  (content/rules/care.json `natural_death`); regular meals bring it back. Feeders prevent it.
- **Care.** Pet (F), play fetch (V), talk (T); the details card (C) has Feed, Brush, Bath, Nap, Train,
  Dress and Pair. Every Boki loves one food, refuses another and has a favourite pastime: you find
  out by trying, and the card remembers. Each kind of care builds a little trust once a farm day
  (5 minutes), so a Boki raised only at home still grows close.
- **Training.** Power, Guard, Speed and Focus, trained at the Training post with a three-round timing
  drill. A happy Boki learns faster; a tired one won't train. Play is practice too: a finished game
  of fetch trains a point of Speed while it still has the energy.
- **Life stages.** Hatchling, Youngling (level 4), Grown (8), Elder (16).
- **Evolution.** How you raise it decides what it grows into. It builds four affinities (Fierce,
  Steadfast, Curious, Swift) from what it eats, what it does in matches and its personality, and every
  4 levels takes a new form along the strongest one. Between forms it grows new body parts. There's
  no cap.
- **IVs.** Five inborn gifts (Health, Power, Speed, Work, Bond) from 0 to 31, fixed for life. The
  difference is small on purpose: a perfect Boki is at most 10% ahead in a stat.

## No two alike

Every Boki rolls its own height and weight (a bell curve for its species, with rare XS and XL ones),
proportions, colour shift, coat pattern, eye colour, ear and tail shapes, an idle habit, a voice, a
birthmark and a favourite food. Size matters a little in a fight (never more than 4%). Rare
**mutations** (Giant, Tiny, Piebald, Melanistic, Albino, Glowing, Twin-tail, Crystal...) change its
look and nudge its stats, and very rarely a Boki **shimmers**: its species' own alternate colours,
about 1 in 4096. The About tab on its card shows all of it, plus where it was found, who first raised
it, and its number among its kind.

## Getting more Boki

- **Scanning.** Wild Boki are rare on expeditions, and rare-Boki spots are rolled each match (they show
  as "?" on the map until someone sees them). Knock a wild Boki out, then hold **F** beside it for a
  moment: a 4 second scan starts on its own. You can't move or shoot while it runs, a dash cancels it,
  and anything that stuns, roots or knocks you back interrupts it (plain damage does not). Rivals can see
  the beam and hear it. It goes into your **box** as a capsule (3 at a time; release one in the
  backpack to make room) and comes home with you only if you **extract**. It never joins the fight: you
  always have exactly one active Boki. Every Boki you glimpse is written into the **Field Book**, with
  where you saw it.
- **Breeding.** Two Boki at level 5 with a Close bond, rested from their last egg, can leave an egg in
  the **Nesting Nook**. It hatches after your next expedition, or in about ten minutes at home. The
  baby mixes its parents' personalities, takes 3 of its 5 IVs from them, and can inherit a mutation.
- **Rare Eggs.** Each lair boss guards a Rare Egg (see [Expeditions](Expeditions.md#boss-lairs)).
  Bring it home and it goes into the **Incubator** by the Nook (5 cradles, up to 8 bought). It warms
  for 2 expeditions or about 8 minutes at home; an Ember Boki at the brazier doubles that, and Ember
  Coals from the Kiln add as much again. It hatches a rare species with 3 IVs of 26 or better.
- **Your first egg** is one of three starters (or the mystery egg): see [Getting started](Getting-Started.md).

The farm only has room for so many Boki (6 at first, more with expansions); the rest sleep in the
**Boki Burrow**, a box of pages you can sort and move Boki in and out of.

## Losing a Boki

What can happen to the Boki you bring depends on the tier, and the game warns you before you queue:

| Tier | If you die |
|---|---|
| The Meadow | Your Boki are never lost. They keep out of sight and come back if you're revived (or go home). |
| Dusk Isles | Boki on you drop into your deathbox. Anyone who loots it takes them. Boki out of your hands escape. |
| The Hollow | As the Dusk Isles, and Boki out of your hands are also left dazed where they were: anyone can capture them (hold F for 3s). |

A box revive, or looting your own box, gets them back; a teammate who loots it carries them home for
you. A Boki left behind shows a banner over it ("Your Boki was left here"). Afterwards:

- **Nobody took it:** it turns up at **Old Pell's Ransom House** on your farm. Buy it back or haggle;
  after 6 expeditions he sells it on.
- **A rival took it:** it stays with them. Make them an offer, or meet them on a later expedition:
  your bond lets you sense your Boki nearby, and a knock gets it back.
- **Its trust carries.** A Boki that loved its old owner keeps that memory.

Everything is paid in gems you earn in play. Boki and Boki power are never sold for money.

_Planned (not in the game yet):_ a free starter kit so nobody is ever left with no Boki and no gems.
