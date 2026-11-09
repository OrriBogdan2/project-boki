class_name HitClass
extends RefCounted
## What a hit landed on. One place decides the class (HitClass.of), so everything that varies by target
## (the sound under the weapon's hit, the hit-spark look) reads the same answer:
##   ARMOUR  it struck armour    BODY  a Hunter's flesh    BOKI  a Boki    MONSTER  a mob
##   WALL    a shot stopped by a wall or terrain

enum { BODY, ARMOUR, BOKI, MONSTER, WALL }

## The short layer each class plays under the weapon's hit (tools/gen_sfx_targets.py).
const SOUND := {BODY: "hit_body", ARMOUR: "hit_armour", BOKI: "hit_boki", MONSTER: "hit_monster", WALL: "hit_wall"}

## The class of a hit on `target` (null: a wall or terrain stopped the shot). `armor`: it struck armour.
static func of(target: Ent, armor: bool) -> int:
	if target == null:
		return WALL
	if armor:
		return ARMOUR
	if target is Kin:
		return BOKI
	if target is Mob:
		return MONSTER
	return BODY
