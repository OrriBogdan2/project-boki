# Riding spec (proposal, for owner approval)

Status: **spec only, not built.** Waiting for the owner's OK. It touches movement, combat and the
match flow, so once approved it gets a decision note (`docs/decisions/NNNN-riding.md`) before code.

## What exists today

Large Boki already carry you (`carry.style: "mount"`, docs/KIN_GRAMMAR.md "Carry modes"): when a large
Boki is on the **Return** order it is under you, ground speed and jump come from `carry.mount`
(x0.8-1.3), you take 15% less damage and half knockback (its carry passives), and opening the glider
curls it into a ball on your back. Today's mounts are the two heavy ones, Cairnback (x0.85) and
Gravadillo (x0.9), so riding is a slow armoured stance, not travel. `Hunter.mounted()`, `Kin.ride_height()`
and `_mount_speed()` are the code paths.

This spec turns that into **riding**: an explicit mount and dismount, travel speed for the eight
rideable Boki (mount speed x1.1 and up, docs/boki/ROSTER_50.md), and clear rules for combat,
knock-offs, extraction and PvP. The seven heavy mounts keep today's behaviour under the same keys.

## Mount and dismount

- **One new rebindable action, `ride`** ("Ride or dismount your Boki"), added to `Settings.ACTIONS`.
  Every prompt and HUD hint reads its key from `Settings.key_cap("ride")` (or `key_caps` where there is
  room). No key letter is written in code, text or data. The default binding is the owner's pick; it
  must be a key not already in the kit.
- **Mount:** with your large Boki out and within 3 m, press `ride`: a 0.5 s climb (interrupted by any
  damage over 10, or by moving more than 1 m), then you're up. If it's on you (Return), `ride` mounts at
  once. A Boki that is downed, dazed, guarding or resting after a merge can't be ridden.
- **Dismount:** press `ride` again; you hop off to the side (0.25 s, no lockout). Interact (`interact`),
  opening the glider, or any ability that moves you (dash, blink, leap) also dismounts you first.
- **Return stays.** The Return order still parks a large Boki under you as today (the heavy mounts'
  armoured stance). `ride` is the explicit way to get on and off; the order wheel is unchanged.
- **Prompt:** "[`key_cap("ride")`] Ride <name>" near your large Boki; "Riding <name> · [`key_cap("ride")`] to
  get off" on the HUD while up (the HUD's existing "riding" kin state).

## Speed

- Ground speed = your run speed x the Boki's `carry.mount.speed` (rideables x1.1-1.3, heavy x0.8-0.95),
  as today. A rideable at x1.3 runs about as fast as a hunter's dash chain without spending charges.
- **Out of combat only for the bonus.** Hit or hitting something in the last 3 s caps mount speed at
  x1.0 (heavy mounts keep their slower value). Travel is fast; a chase or a kite is not.
- Jump and turn come from `carry.mount` (jump x0.8-1.3, turn 0.5-1). Turning is a rate, so a fast mount
  takes wide corners.
- No sprint, no stamina. Speed is the mount's whole identity, so it stays one number.
- **Water (proposal, Spatewader only):** an aquatic rideable swims at its mount speed instead of your
  swim speed. Optional; drop it if swimming changes too much.

## While riding

| You can | You can't |
|---|---|
| Fire your weapon (LMB), at -15% fire rate | Dash, blink or leap (it dismounts you first) |
| Use your Hunter ability and utility if they don't move you | Glide (core rule; opening the glider dismounts, the Boki curls onto your back as today) |
| Use your Boki's ability (C), cast by the mount | Sneak or hide in tall grass (a mount is never concealed) |
| Merge (R): a mount grows giant under you, as today | Open chests, scan, revive, loot or pick up (interact dismounts first) |
| Ping, emote, use the map | Carry a downed Boki or a teammate |
| Jump (the mount's jump) | Throw your Boki (send it out = dismount first) |

The rider sits higher (`ride_height`), so your hitbox moves up with you and stays the same size. The
mount has its own health (its kin hp) and takes splash and beams that pass through it.

## Getting knocked off

You're thrown off (land beside the mount, 0.4 s stagger, can't remount for 3 s) when:
- you take hard crowd control: stun, root, Grounded, a launch, or a knock-up;
- you take 25% of your max health within 1 s;
- the mount is downed (its hp hits 0): it drops as a downed Boki and the usual rescue applies;
- the mount steps off a ledge into the abyss: you're thrown clear and can glide; it curls up on your back.

Pushes and pulls move you and the mount together (heavy mounts resist them through `knockback_resist`).
The heavy mounts' -15% damage and half knockback stay as carry passives; rideables trade them for speed.

## Extraction and PvP

- **Travel, not combat.** The out-of-combat speed cap keeps mounts for crossing the map, reaching an
  extract or a lair, and running from a lost fight, not for out-running shots in a duel.
- **Loud and visible.** A ridden mount makes footstep noise at twice the hunter radius and shows on
  rivals' minimap ping as a hunter does. It can't hide in grass. Riding is a choice: speed for stealth.
- **Extraction:** you can ride onto an extract, but calling or holding an exit requires dismounting
  (interact dismounts). Keyed hatches and evac points read the same rule.
- **Loss stakes (docs/decisions/0008):** at loss tiers a downed mount drops dazed and guards like any
  Boki. A big, rare rideable is a tempting target for a scan, which is the extraction tension we want.
- **Equal footing (docs/decisions/0005):** your Boki is the one lasting difference you bring. A fast
  mount is that difference, capped to out-of-combat travel. If tests show rideable squads dominate
  rotations, the lever is the cap (x1.3 down to x1.2), not removing mounts.
- **Bots** ride their own rideable Boki for travel only (mount on a path over 30 m, dismount at 15 m
  from a foe or on any hit).

## Risks

1. **Rotation speed.** Fast mounts change how quickly squads reach exits and fights. Mitigation: the
   combat cap; tune mount speeds per tier.
2. **Netcode.** The rider is attached to the mount, so a host-side knock-off has to land on clients the
   same frame. Riding state is one more field in the hunter and kin snapshots (Net version bump).
3. **Animation cost.** Each `-L` skeleton needs rider poses (sit, lean, jump, knocked off): 5 rigs
   (QUAD-L, BIPED-L, HEXA-L, FIN-L, BLOB-L as one sit pose) times about 5 clips.
4. **Camera and aim.** The rider sits higher; the shot origin moves up 0.4 m or so. Check aim and
   cover (decision 0009) so riders can't shoot over walls they couldn't before.
5. **Readability.** A big Boki with a rider must still read as one target. The rider's outline stays on.
6. **Scope creep.** No flying mounts (no free flight is a core rule), no mounted-only weapons, no
   two-seat mounts in this spec.

## What the owner approves

- The `ride` action and the default key you want for it.
- The combat speed cap (3 s, x1.0) and the -15% fire rate while riding.
- The knock-off rules (hard CC, 25% health in 1 s, mount downed).
- Dismount required to use an extract.
- Optional: Spatewader swims at mount speed.
