# Inspirations

Design notes for the team: which mechanics we based on which games, so we know what we're matching
and where we chose to differ. We take **mechanics only**. Names, numbers, art, sound and every word
of on-screen text are ours, and nothing comes from another game's files (see
[Contributing and licensing](Contributing-and-Licensing.md)). Player-facing copy follows
`docs/POSITIONING.md` on the `design` branch, which also says which comparisons we make in public.

## Class kits

| Class | Based on | What we kept | Where we differ |
|---|---|---|---|
| Sable (id thief) | SUPERVIVE's **Shiv**, matched to gameplay footage | A ranged bolt from alternating hands that lands at the cursor, a stacking bonus on consecutive hits, a cartwheel that empowers the next shot and resets when it lands, a grounding bola down a lane that stuns two, a dagger you blink to through afterimages, a ring of blades at the fifth stack (the ult folded into a trigger), heal on knock/assist | Numbers scaled as ratios to our health and time-to-kill; names, models, effects and sounds are ours. Our earlier Cash In payoff was retired to match (the empowered reset is the payoff) |
| Kael (id juggernaut) | SUPERVIVE's **Brall**, ported ability by ability | A damage-built "empowered" state, tip-bonus melee with a charged ranged wave, a contextual RMB (wound-up slam with a reset sweet spot, charged lunge whose miss doubles the cooldown, air slam, spin during the chain pull), a two-charge dash attack, a chain that hooks foes or walls and pulls you in, an invulnerable heal-on-damage ult reset by knocks | Owner-requested chain combinations (Chain Lunge, Haul Slam) on top; numbers scaled |
| Archer | A SUPERVIVE hunter-archer baseline (**Myth**-style) | A bow that draws in stages with a perfect-release window, a held heavy shot, a rain of arrows, an ult of empowered no-draw shots | The Focus resource and Deadeye payoff, the grapple dash and wall pins are our own loop |
| Mage | **League of Legends**: LeBlanc-style mark-and-detonate combos and snap-back blink; a steerable bolt (see the `mage_kit.gd` header) | Mark, then detonate with the next spell; blink and return | The Hex critter, Heat and Flashpoint, the Encore mirrors are ours |
| Gunslinger | No single source | | Six-chamber rhythm, ricochet trick shots and the Called Shot are our own design |
| Bulwark | SUPERVIVE's **Oath** (shield tank) baseline | A raised shield with its own health, bash on release, shield-up dash variant | Guard, the Crushed wall/foe collision payoff, the thrown mace and Mending Ground are ours |
| Tarek | SUPERVIVE's **Tetra**, ability by ability (docs/heroes/dolm.md) | Sneak-reveal passive, tap boulder / hold punch with wall stun, a charged slam with a jump-leap and an abyss dunk, a dash that leaves a launched rock, a three-rock wall you punch away | Rocks are real walls with placement rules; the ult is her own on R (Basalt Spine: a dragged ridge that is a walkway over the abyss); a slam that knocks resets itself; all names and numbers ours |
| Motley | SUPERVIVE's **Void** (docs/heroes/ostra.md) | Damage-built empowered state, a charged orb after a pause, a shard cluster whose stun grows with range, a lobbed teleport that trades places, a growing bomb you detonate | The pull-in ult is her own on R (Nightwell); Collapse payoff, footstep silence not built; names and numbers ours |

Shared kit conventions also follow SUPERVIVE: RMB variants by context (tap, hold, in the air, during
another ability), run levels from 1 with the ultimate at level 6, readable build-up passives (their
static, chill, ignite-style stacks) instead of mana, and "tells" the enemy can read. Readability
references: Riot's "Clarity in League" and Battlerite's at-a-glance character reads.

## Movement, camera and combat feel (SUPERVIVE)

- The high, far, cursor-leaning camera, snappy WASD, the long air dash, perfect dodges.
- The glider: hold to glide, heat as the limit, speed keeps you up, **feathering** (tapping it).
- The **abyss**: a short fall with a rapid upward lift under island lips, the tint as you sink.
- **Ledge rise** (floating up a cliff face you push into) and the jump-fling at the top.
- Down, death and revive: wisps, bleed-out, stomps, deathboxes, revive beacons, resurrection sickness.
- The drop: a planning map with pings, a ship crossing the map, squads gliding in formation, passing the lead.
- Lair locks with a timing dial (after their vault locks), boss telegraphs, staggers on big monsters.
- Gloves (their "grips"): an active and a passive slot found on the run.
- Numbers and timings measured from public footage and patch notes live in `docs/SUPERVIVE_DATA.md`,
  `docs/SUPERVIVE_FEEL.md`, `docs/WEAPON_FIRING_DATA.md` and `docs/MOVEMENT_FEEL.md`, each tagged with its source.

## Extraction and tone

- **ARC Raiders:** the exits (a loud called evacuation, keyed hatches, holding a point), sessions you
  join at a random point (planned), and a scarier world: the Blight hunting by noise and light,
  moody raid conditions. See `docs/TONE_AND_THREATS.md`.
- **Escape from Tarkov:** stakes. What you bring can be lost, what you extract is kept.
- **RuneScape's Grand Exchange:** the planned commodity market for basic materials.

## Boki and the farm

- **Palworld:** Boki that do things. Work knacks, stations and automation on the farm.
- **Monster Rancher / Digimon World:** a bond-first creature you raise (needs, training, trust,
  personality, a creature that remembers you).
- Inborn stats (IVs), natures and rare alternate colours are familiar ideas from creature-collecting
  RPGs; we keep their effect small on purpose, and nothing is ever sold.
- **Stardew Valley:** the farm loop (plant, water, harvest, cook, decorate).
