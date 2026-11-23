# 0022: A newer knock takes over

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** combat / movement

## Problem
A Hunter already flying from a knock gets knocked again (Kael's Haul Slam then Albert's Shield Charge, Grimble's reel into Sparkle's Storm Rod, two Vex Burr Charges). `Hunter.impulse` set the speed along the new knock but kept the old flight's sideways speed, so the two added (2.2-4.5 m of extra carry). A knock on a reeled body stacked with the reel. A first wall slam locked out a second one for 1.2 s, and a first knock's longer wall stun stayed on for the next knock.

## Source (parity first)
- Game data (briefs/supervive-data/supervive_physics.md): the only knock stats are Knockback 1.0 and KnockbackResist 1.0, both multipliers. There is no knock immunity or knock diminishing-returns stat.
- Wiki and tooltips (supervive_kits.md): every wall stun belongs to the ability that threw you ("Heartpiercer: enemies that collide with terrain are Stunned", "Voltaic Spear: knocked into a wall = Stunned", "Spike Grenade: knocked into a wall are Stunned", Oath's "knocking an enemy into a wall Stuns them"). So the knock you are flying from decides the wall stun.
- Footage: the hero-ref sheets only show one hero against dummies, so no chained knock is on film, and the frames aren't on every machine. This note does not cover add versus replace from footage. That should be checked against a real chained knock in a match clip.

## Options
1. Add: the second knock adds to the flight. Distances depend on what was already moving you, and the stun-on-wall belongs to no single ability.
2. A short immunity after a knock. Nothing in the data supports it.
3. Replace: the newer knock sets the flight, ends a reel, and owns the wall stun.

## Decision
Option 3, in one place: `Displace.knock_speed` / `Displace.knocked` (with `Displace.KNOCK_MIN` 2.5 m/s, the existing knock threshold). Below it a shove is a nudge and only tops speed up, as before. A tow that starts on a knocked body takes over the same way (`Displace.tow`).

## Consequences
- `hunter.gd`: `impulse` calls the rule. `_mitigate` stamps `wallstun_at`, so a knock's own wall stun survives its own push.
- A reel or push ended by a knock reports `"knocked"` (Net "end" reason; same message shape, no Net.VERSION bump).
- Mobs (`Ent.impulse`) are unchanged.
- Check: `--knock-chain-check`.
