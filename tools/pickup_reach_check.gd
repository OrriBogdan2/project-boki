extends RefCounted
## --pickup-reach-check: ground pickup reach (PickupReach, content/rules/pickup.json). Walking past
## a consumable at the walk radius takes it and a pass just outside leaves it; with two gear pieces in
## reach the interact key takes the one nearest the cursor, even when it is the farther from you;
## nothing is taken or offered through a rock; a dash still takes, a glide well above the ground
## doesn't. An expedition island (the rival spawns far off), never touches the save.

var bad := 0
var m: Match
var w: World
var P: Hunter

func ok(cond: bool, what: String) -> void:
	print("PICKUP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 91, "no_drop": true, "god": true})
	m.set_process(false)
	w = m.world
	P = m.player
	var walk: Dictionary = PickupReach.rules()["walk"]
	var flat := _flat_spot(4.5, 3.5)
	ok(flat != Vector3.INF, "a flat clear spot to walk on: %s" % str(flat))
	_walk_past(flat, float(walk["radius"]) - 0.15, true)
	_walk_past(flat, float(walk["radius"]) + 0.3, false)
	_cursor_pick(flat)
	_through_rock(flat)
	_in_the_air(flat)
	print("PICKUP REACH CHECK DONE, failures: ", bad)
	main.get_tree().quit()

## A tonic lies at `at`; the hunter runs along x past it `off` metres to the side.
func _walk_past(at: Vector3, off: float, taken: bool) -> void:
	_clear_ground()
	_reset(at + Vector3(-3.0, 0, off))
	m.drop("tonic", at, 1, "", "", Vector3.ZERO)
	for i in 90:
		P.inp["move"] = Vector2.RIGHT
		_step()
	P.inp["move"] = Vector2.ZERO
	ok(m.pickups.is_empty() == taken, "running past a tonic %.2f m to the side: %s (pickups left %d)"
		% [off, "taken" if taken else "left", m.pickups.size()])

## Two gear pieces in reach: the key takes the one under the cursor, the farther one from the hunter.
func _cursor_pick(at: Vector3) -> void:
	_clear_ground()
	_reset(at)
	var gid: String = Gear.ALL.keys()[0]
	m.spawn_gear(gid, 1, at + Vector3(0.5, 0, 0), "near", false)
	m.spawn_gear(gid, 1, at + Vector3(-1.2, 0, 0), "far", false)
	P.inp["aim"] = at + Vector3(-1.2, 0, 0)
	_step()
	ok(String(m.interact.get("kind", "")) == "weapon" and String(m.interact["wp"]["id"]) == "far",
		"cursor on the farther piece: the prompt offers it (%s)" % str(m.interact.get("wp", {}).get("id", "")))
	P.inp["aim"] = at + Vector3(0.5, 0, 0)
	_step()
	ok(String(m.interact.get("wp", {}).get("id", "")) == "near", "cursor on the nearer piece: the prompt offers it")
	P.inp["aim"] = at + Vector3(-1.2, 0, 0)
	P.inp["interact"] = true
	_step()
	P.inp["interact"] = false
	var left: Array = m.wpicks.map(func(wp): return String(wp["id"]))
	ok(left == ["near"], "pressing the key takes the one under the cursor first (left on the ground: %s)" % str(left))

## A rock between the hunter and a tonic (and a gear piece) within reach: neither is taken nor offered.
func _through_rock(flat: Vector3) -> void:
	_clear_ground()
	var rock := _rock_with_room()
	ok(rock != Vector3.INF, "a rock with clear ground on both sides: %s" % str(rock))
	if rock == Vector3.INF:
		return
	var theirs := rock + Vector3(1.0, 0, 0)
	theirs.y = w.ground_at(theirs.x, theirs.z)
	var gear_at := rock + Vector3(0.55, 0, 0)      # just past the rock's far edge, inside the interact radius
	gear_at.y = theirs.y
	_reset(rock + Vector3(-0.9, 0, 0))
	m.drop("tonic", theirs, 1, "", "", Vector3.ZERO)
	m.spawn_gear(Gear.ALL.keys()[0], 1, gear_at, "behind", false)
	P.inp["aim"] = gear_at
	for i in 60:
		_step()
	ok(m.pickups.size() == 1, "a tonic %.2f m away behind a rock stays there" % P.flat_dist(theirs))
	ok(m.interact.is_empty(), "gear %.2f m away behind the rock is not offered (%s)"
		% [P.flat_dist(gear_at), str(m.interact.get("kind", ""))])
	# the same distances with nothing between: both come
	_clear_ground()
	_reset(flat + Vector3(-1.0, 0, 0))
	var open := flat + Vector3(1.0, 0, 0)
	m.drop("tonic", open, 1, "", "", Vector3.ZERO)
	m.spawn_gear(Gear.ALL.keys()[0], 1, flat + Vector3(0.45, 0, 0), "open", false)
	P.inp["aim"] = open
	for i in 60:
		_step()
	ok(m.pickups.is_empty(), "the same 2 m with nothing between: the tonic flies over (at %s)" % str(flat))
	ok(String(m.interact.get("wp", {}).get("id", "")) == "open", "and the gear is offered")

## A dash takes a pickup like a run does; gliding well above it doesn't reach.
func _in_the_air(at: Vector3) -> void:
	_clear_ground()
	_reset(at + Vector3(-1.5, 0, 0))
	m.drop("tonic", at, 1, "", "", Vector3.ZERO)
	for i in 60:
		P.roll_t = 0.2
		_step()
	ok(m.pickups.is_empty(), "a tonic in reach is taken mid-dash")
	_clear_ground()
	var height: float = PickupReach.rules()["walk"]["height"]
	_reset(at + Vector3(-1.0, height + 1.0, 0))
	m.drop("tonic", at, 1, "", "", Vector3.ZERO)
	for i in 60:
		P.gliding = true
		P.vel = Vector3.ZERO
		P.pos.y = at.y + height + 1.0
		_step()
	ok(m.pickups.size() == 1, "gliding %.1f m over a tonic doesn't take it" % (height + 1.0))

func _clear_ground() -> void:
	for p in m.pickups:
		p["node"].queue_free()
	m.pickups.clear()
	for wp in m.wpicks:
		wp["node"].queue_free()
	m.wpicks.clear()

## Flat ground with no rock or void within half_x by half_z metres, searched out from the spawn.
func _flat_spot(half_x: float, half_z: float) -> Vector3:
	var c := P.pos
	for ring in range(0, 60):
		for k in 16:
			var d := Vector2.RIGHT.rotated(TAU * k / 16.0) * float(ring)
			var x := c.x + d.x
			var z := c.z + d.y
			if _clear_rect(x, z, half_x, half_z):
				return Vector3(x, w.ground_at(x, z), z)
	return Vector3.INF

func _clear_rect(x: float, z: float, half_x: float, half_z: float) -> bool:
	var g := w.ground_at(x, z)
	for ix in range(int(floor(x - half_x)), int(ceil(x + half_x)) + 1):
		for iz in range(int(floor(z - half_z)), int(ceil(z + half_z)) + 1):
			var cx := ix + 0.5
			var cz := iz + 0.5
			if w.is_block(cx, cz) or w.is_void(cx, cz) or absf(w.ground_at(cx, cz) - g) > 0.05:
				return false
	return true

## The middle of a rock cell with two clear flat cells on each side along x, at the rock's ground height.
func _rock_with_room() -> Vector3:
	var c := P.pos
	var best := Vector3.INF
	var best_d := INF
	for ix in range(2, w.w - 2):
		for iz in range(2, w.h - 2):
			var cx := float(ix) + 0.5
			var cz := float(iz) + 0.5
			if not w.is_block(cx, cz) or Vector2(cx - c.x, cz - c.z).length() >= best_d:
				continue
			var g := w.ground_at(cx - 1.0, cz)
			var room := true
			for ox: float in [-2.0, -1.0, 1.0, 2.0]:
				for oz: float in [-1.0, 0.0, 1.0]:
					var px := cx + ox
					var pz := cz + oz
					if w.is_block(px, pz) or w.is_void(px, pz) or absf(w.ground_at(px, pz) - g) > 0.05:
						room = false
			if room:
				best = Vector3(cx, g, cz)
				best_d = Vector2(cx - c.x, cz - c.z).length()
	return best

func _reset(at: Vector3) -> void:
	P.teleport(Vector3(at.x, w.ground_at(at.x, at.z), at.z))
	P.grounded = true
	P.vel = Vector3.ZERO
	P.roll_t = 0.0
	P.gliding = false
	P.inp["move"] = Vector2.ZERO
	P.inp["interact"] = false
	P.inp["aim"] = P.pos
	_step()

func _step() -> void:
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	m.step(Match.DT)
