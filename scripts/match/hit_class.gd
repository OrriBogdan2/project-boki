class_name HitClass
extends RefCounted
## What a hit landed on. One place decides the class (HitClass.of), so everything that varies by target
## (the sound under the weapon's hit, the short pooled look) reads the same answer:
##   ARMOUR  bright chips in the armour colour      BODY   the Hunter's hit flash only
##   BOKI    a soft puff in its type colour         MONSTER sparks in the monster's colour
##   WALL    dust (a shot stopped by a wall or terrain)
## Each look draws at most one flash and one pooled spray (Fx pools), never a ring. A Hunter's own
## ability impact (AbilityFx.hit) draws on top of this shared layer in its own colour.

enum { BODY, ARMOUR, BOKI, MONSTER, WALL }

const ARMOUR_COL := Color("8fd4ff")     # chips off armoured things that aren't Hunters
const CRIT_COL := Color("ffd23f")

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

## The colour the class paints in: the armour tier, the Boki's type, the monster's hide.
static func tint(target: Ent, cls: int, fallback: Color) -> Color:
	match cls:
		ARMOUR:
			return (target as Hunter).armor_col() if target is Hunter else ARMOUR_COL
		BOKI:
			return DexView.type_col(String((target as Kin).sp.get("type", "")))
		MONSTER:
			return Data.MOBS.get((target as Mob).mkind, {}).get("color", fallback)
	return fallback

## Draw the look for a hit of class `cls` at `at`, flying on along `dir`. power: 0..3 from the damage.
static func draw(fx: Fx, cls: int, at: Vector3, dir: Vector3, col: Color, power: float, crit: bool) -> void:
	var fcol := CRIT_COL if crit else col
	var flash_sz := (0.3 + 0.14 * power) * (1.4 if crit else 1.0)
	var out := (dir.normalized() + Vector3(0, 0.35, 0)).normalized() if dir.length() > 0.01 else Vector3.UP
	match cls:
		BODY:
			fx.flash(at, fcol, flash_sz, 0.07 + 0.02 * power)
		ARMOUR:
			fx.flash(at, fcol.lerp(Color.WHITE, 0.4), flash_sz * 0.8, 0.06)
			fx.spark(at, out, fcol.lerp(Color.WHITE, 0.3), int(5 + 3 * power), 8.0 + 2.0 * power, 55.0, 0.24, 16.0, 1.1)
		BOKI:
			fx.burst(at, Color(fcol, 0.75), int(5 + 2 * power), 1.6, 0.4, -0.5, 1.3, Vector3.UP, 120.0)
		MONSTER:
			fx.flash(at, fcol.lerp(Color.WHITE, 0.5), flash_sz * 0.7, 0.06)
			var hot := fcol.lerp(Color.WHITE, 0.25)
			fx.spark(at, out, hot, int(4 + 3 * power), 6.0 + 2.0 * power, 45.0, 0.22, 12.0, 1.0)
		WALL:
			fx.dust(at, int(3 + 2 * power))
