class_name Stacks
extends RefCounted
## What happens when two casters put the same status on one body: one rule per kind, in
## content/rules/status_stacking.json (docs/COMBAT.md, Status stacking). Slow, burn, stun and root merge
## through merge_k / merge_time (Ent.add_slow, add_burn, hurt). Stack counts (Static, Shatter darts, Chill,
## Char, Ignite) live on the body, in Ent.stacks, so every caster adds to the same count.

static func rule(kind: String) -> Dictionary:
	return Content.rules("status_stacking").get(kind, {})

## The strength a body ends up with when `new` lands on `old`.
static func merge_k(kind: String, old: float, new: float) -> float:
	return old + new if rule(kind).get("combine", "") == "add" else maxf(old, new)

## The time left after `secs` lands on a status with `left` running.
static func merge_time(kind: String, left: float, secs: float) -> float:
	return maxf(left, secs) if rule(kind).get("time", "longest") == "longest" else secs

static func _key(kind: String, by: Ent) -> String:
	return "%s@%s" % [kind, by.nid] if by != null and rule(kind).get("owner", "target") == "caster" else kind

static func count(e: Ent, kind: String, by: Ent = null) -> float:
	if e == null or not is_instance_valid(e):
		return 0.0
	return float((e.stacks.get(_key(kind, by), [0.0, 0.0]) as Array)[0])

## Adds `n` (or, for a "strongest" kind, raises it to `n`) and times it. Returns the new count.
static func add(e: Ent, kind: String, n: float, secs: float, by: Ent = null) -> float:
	var key := _key(kind, by)
	var s: Array = e.stacks.get(key, [0.0, 0.0])
	s[0] = merge_k(kind, float(s[0]), n)
	s[1] = merge_time(kind, float(s[1]), secs)
	e.stacks[key] = s
	return float(s[0])

static func clear(e: Ent, kind: String, by: Ent = null) -> void:
	e.stacks.erase(_key(kind, by))

## Gives back `dt` of a stack's time (a caster whose ultimate freezes its stacks).
static func hold(e: Ent, kind: String, dt: float, by: Ent = null) -> void:
	var s: Array = e.stacks.get(_key(kind, by), [])
	if not s.is_empty():
		s[1] = float(s[1]) + dt

static func tick(e: Ent, dt: float) -> void:
	for key in e.stacks.keys():
		var s: Array = e.stacks[key]
		s[1] = float(s[1]) - dt
		if float(s[1]) <= 0.0:
			e.stacks.erase(key)
