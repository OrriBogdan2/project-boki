class_name InCombat
extends RefCounted
## The one "in combat" rule (content/rules/combat.json): a Hunter or a Boki is in combat for window_s
## seconds after it deals or takes fight damage. Ent.hurt reports every hit here; regen, music, the
## bot and Boki AI tick and the Boki's orders only ask is_in.

const CALM_HZ := 10.0                           # decisions a second for a Boki out of combat (perf pass)
const NOT_FIGHTS := ["fall", "wall", "heat"]    # hit sources that are the world, not a fight

static func window() -> float:
	return float(Content.rules("combat")["window_s"])

static func is_in(e: Ent) -> bool:
	return e.m.time - e.combat_at < window()

## Damage from by (null: a monster or Blight with no body) to target is landing. Friendly fire, self damage
## and the world's hits don't start a fight. Healing never reaches this.
static func on_hit(target: Ent, by: Ent, opts: Dictionary) -> void:
	if String(opts.get("src", "")) in NOT_FIGHTS or (is_instance_valid(by) and by.team == target.team):
		return
	_mark(target)
	if is_instance_valid(by):
		_mark(by)

## A Hunter or a Boki is marked; a Boki's fight is its owner's too.
static func _mark(e: Ent) -> void:
	if e is Hunter:
		e.combat_at = e.m.time
	elif e is Kin:
		e.combat_at = e.m.time
		if e.owner_h != null:
			e.owner_h.combat_at = e.m.time
