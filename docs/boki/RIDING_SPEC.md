# Big-Boki roles: riding and the rest (proposal, for owner approval)

Status: **specs only, nothing built.** Every section is **for owner approval**. They touch movement,
combat and the match flow, so each approved role gets a decision note (`docs/decisions/NNNN-*.md`)
before code.

Large Boki aren't all mounts (owner review, 02:30). The 16 big Boki in docs/boki/ROSTER_50.md split into
six roles; riding is one of them:

| Role | Who | Pitch |
|---|---|---|
| mount | Heatherhorn, Glaciyak, Lilybara, Cindowary, Nimbostrich, Duskapi | You ride it: travel speed out of combat. |
| companion | Gravadillo, Scaldamus, Umbrathere | Walks beside you and fights as a second body. |
| flyer | Goliathite, Squalltross | Lifts you: a carried glide, or a haul over an abyss gap. |
| bulwark | Cairnback, Limpetor | Plants itself as living cover for the squad. |
| packbeast | Floenatee, Spatewader | Carries loot in extra slots that rivals can knock loose. |
| watchtower | Moundvark | You climb on top: height and sight for a sniper. |

**The grammar today.** A large kin may only be `carry.style: "mount"` (`KinParts.CARRY`), so all 16
stubs are mounts in data; the role lives in the roster doc. Each role below says what it would need:
a new `carry.style` value (for large kin) with its own small settings block, checked in
`kin_spec.gd` like `carry.mount`, plus the behaviour code.

# Role 1: mount (riding) — for owner approval

## What exists today

Large Boki already carry you (`carry.style: "mount"`, docs/KIN_GRAMMAR.md "Carry modes"): when a large
Boki is on the **Return** order it is under you, ground speed and jump come from `carry.mount`
(x0.8-1.3), you take 15% less damage and half knockback (its carry passives), and opening the glider
curls it into a ball on your back. Today's mounts are the two heavy ones, Cairnback (x0.85) and
Gravadillo (x0.9), so riding is a slow armoured stance, not travel. `Hunter.mounted()`, `Kin.ride_height()`
and `_mount_speed()` are the code paths.

This spec turns that into **riding**: an explicit mount and dismount, travel speed for the six mounts
(mount speed x1.1 and up, docs/boki/ROSTER_50.md), and clear rules for combat, knock-offs, extraction
and PvP. Grammar: none new; the role is today's `carry.style: "mount"`. Code: the `ride` action, the
combat speed cap, the knock-off rules and the riding restrictions below.

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
- **Return stays.** For a mount, the Return order still parks it under you as today. `ride` is the
  explicit way to get on and off; the order wheel is unchanged. (The other roles give Return their own
  meaning below.)
- **Prompt:** "[`key_cap("ride")`] Ride <name>" near your mount; "Riding <name> · [`key_cap("ride")`] to
  get off" on the HUD while up (the HUD's existing "riding" kin state).

## Speed

- Ground speed = your run speed x the Boki's `carry.mount.speed` (mounts x1.1-1.3), as today. A rideable at x1.3 runs about as fast as a hunter's dash chain without spending charges.
- **Out of combat only for the bonus.** Hit or hitting something in the last 3 s caps mount speed at
  x1.0. Travel is fast; a chase or a kite is not.
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

Pushes and pulls move you and the mount together. Mounts trade today's -15% damage and half knockback
for speed; that armoured stance moves to the bulwark and companion roles.

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
3. **Animation cost.** The mounts use two rigs (QUAD-L, BIPED-L), each needing rider poses (sit, lean,
   jump, knocked off): about 5 clips per rig.
4. **Camera and aim.** The rider sits higher; the shot origin moves up 0.4 m or so. Check aim and
   cover (decision 0009) so riders can't shoot over walls they couldn't before.
5. **Readability.** A big Boki with a rider must still read as one target. The rider's outline stays on.
6. **Scope creep.** No flying mounts (no free flight is a core rule), no mounted-only weapons, no
   two-seat mounts in this spec.

## What the owner approves (mount)

- The `ride` action and the default key you want for it.
- The combat speed cap (3 s, x1.0) and the -15% fire rate while riding.
- The knock-off rules (hard CC, 25% health in 1 s, mount downed).
- Dismount required to use an extract.
- Optional: Spatewader swims at mount speed.

# Role 2: companion (walks beside you) — for owner approval

**Pitch.** A big Boki that fights next to you as a second body: it draws fire, holds a lane and blocks
a chase. You never sit on it. (Gravadillo, Scaldamus, Umbrathere.)

- **Play:** it is always "out" (the follow and attack AI it already uses when sent out, `KinFollow`,
  `KinTactics`). Return makes it heel at your side instead of mounting. Throwing it is replaced by a
  **charge**: it barrels 8 m at the aim point and knocks foes aside (the mount kin's existing `charge`
  flag on the fly).
- **Rules:** it has the most kin hp; its carry passives (damage reduction, knockback resist) apply while
  you stand within 4 m of it, not while carried. It can't be carried, so it can't regenerate "on you";
  it uses the out-of-combat mend only.
- **Grammar:** `carry.style: "beside"` for large kin, with `carry.beside: {"aura": 4}` (m, the passive
  radius). **Code:** a carry mode where Return means heel, the charge throw, and passives by distance.
- **Risks:** pathing a big body through narrow lanes and bridges; it must not body-block teammates.

# Role 3: flyer — for owner approval

**Pitch.** It lifts you. Hang from its feet or harness for a long carried glide, or let it haul you over
an abyss gap it can reach. Never free flight (core rule). (Goliathite, Squalltross.)

- **Play:** while you glide with a flyer, it carries you: your glide gets the carry passive (glide up to
  the merge cap of +50% instead of the carry cap of +20%) and its heat cools faster. Pressing `ride`
  at an abyss edge starts a **haul**: it lifts you up to 12 m across, at walking speed, and drops you on
  the far side. A haul is cancelled by any damage over 10 (you drop and can glide).
- **Rules:** no weapons while hauled; flyers don't carry you upward past the edge height; at most one
  haul every 20 s.
- **Grammar:** `carry.style: "flyer"` with `carry.flyer: {"glide": 0.4, "haul": 12}`. Needs the glide
  cap raised for this style only (today carry glide is capped at 0.2). **Code:** the carried-glide pose,
  the haul path and its cancel rules.
- **Risks:** hauls skip map routes and chokepoints; the 12 m cap and cooldown keep the abyss a barrier.

# Role 4: bulwark (shield-wall, own idea) — for owner approval

**Pitch.** It plants itself as living cover. You and your squad shoot from behind it while it soaks the
shots until it cracks. (Cairnback, Limpetor.)

- **Play:** order "plant" (Return while it's out, or a new order-wheel slot): it braces facing your aim
  and becomes cover, a 3 m arc that stops enemy shots (the `wall` delivery and `rock_guard` ability
  already block shots) for up to 6 s or 200 damage, then needs 10 s to recover. Hunters behind it count
  as in cover for the cover rules (decision 0009).
- **Rules:** while planted it can't move or attack; it can be flanked. Carried, it gives today's
  -15% damage and half knockback.
- **Grammar:** `carry.style: "bulwark"` with `carry.bulwark: {"arc": 3, "hp": 200, "secs": 6}`. **Code:**
  the plant order, the braced kin as a shot-blocking wall, and cover rules reading it.
- **Risks:** stacking two bulwarks makes a fort; cap one planted bulwark per squad.

# Role 5: packbeast (carrier, own idea) — for owner approval

**Pitch.** It carries loot: extra pack slots on its back that you can extract with. Hit it hard enough
and the load spills for rivals to grab. (Floenatee, Spatewader.)

- **Play:** adds 4 pack slots while it's your Boki (`Equal.pack_slots(h)` gains a kin source). Items in
  those slots ride on the Boki, shown on its back. Spatewader swims across water with its load.
- **Rules:** when the packbeast is downed, its slots spill on the ground like a deathbox (decision
  0005: every item exists once). It extracts its load only if it is beside you or carried when you
  extract. At loss tiers a captured packbeast's load goes with the captor (decision 0008).
- **Grammar:** `carry.style: "pack"` with `carry.pack: {"slots": 4}`. **Code:** the kin source in
  `Equal.pack_slots`, the spill on down, the extract rule and the inventory UI for its slots.
- **Risks:** equal footing (decision 0005): a bigger pack from a Boki is a brought-in advantage. Cap
  its slots by difficulty tier like backpacks (`backpack_cap_by_tier`).

# Role 6: watchtower (living perch, own idea) — for owner approval

**Pitch.** It stands still and lets you climb on top: height, longer sight and reveal for a sniper, but
you're the most visible thing on the island. (Moundvark.)

- **Play:** order "tower" (Return while it's out): it plants, and `ride` climbs you onto its lookout
  (0.6 s). Up there you get +3 m height, a reveal radius of 12 m (the merge-only `reveal_radius` stat,
  allowed here) and your shots gain 15% range. You can't move; `ride` or any hard CC drops you off.
- **Rules:** you're always revealed to rivals within 30 m while on top; the tower can't be planted in
  tall grass or on a lair floor; one tower per squad.
- **Grammar:** `carry.style: "tower"` with `carry.tower: {"height": 3, "reveal": 12}`. **Code:** the
  climb, the raised rider position (reuses `ride_height`), the stat block while on top and the reveal.
- **Risks:** high ground over cover (decision 0009): shots from the tower must still respect walls.

## Grammar summary for main (all roles)

| Role | `carry.style` | Settings block | Exists today |
|---|---|---|---|
| mount | `mount` | `carry.mount` speed/jump/turn | yes |
| companion | `beside` | `carry.beside` aura | no |
| flyer | `flyer` | `carry.flyer` glide/haul | no |
| bulwark | `bulwark` | `carry.bulwark` arc/hp/secs | no |
| packbeast | `pack` | `carry.pack` slots | no |
| watchtower | `tower` | `carry.tower` height/reveal | no |

Until a style exists, the stub stays `mount` (the only legal large style), which is why the stubs for
the ten non-ridden big Boki have mount speed x1.0 or below and `--roster-check` doesn't count them as
rideable.
