extends "res://tools/wall_slide_check.gd"
## --dash-wall-check: a ground dash that meets a wall slides along it and keeps the part of its length that
## runs along the face (docs/decisions/0047-dash-wall-slide.md: cos of the angle to the wall, 0.94 at 20
## degrees, 0.71 at 45, 0.17 at 80). All 12 Hunters dash from touching a straight cliff on The Hollow Crown,
## a placed Tenzo rock, a raised Neve wall and a Hollow Crown prop's face, at 20, 45 and 80 degrees to it;
## the same dash on open ground is the reference. A try fails when the distance it makes along the wall is
## off the reference's (its length times the table) by more than KEEP_TOL. Tenzo's Rock Hop is a leap to a spot
## picked short of the wall (KIT_STOPS): it only must never end up inside it.
## Counts fixed simulation steps; never touches the save. Prints one "DWALL ..." line per try and
## "DASH WALL CHECK DONE, failures: N".

const DASH_ANGLES := [20.0, 45.0, 80.0]
const KEEP_TOL := 0.1           # share of the table's distance a dash may be off by
const WINDOW := 150             # steps (2.5 s): the longest dash (Ostra's 1.8 s trade) and the stop after it
const START_GAP := 0.02         # m off the face the body starts, touching it
const BOUNCED := 0.3            # m off the wall a try ends that counts as a rebound (for the print)
const PROP_TOUCH := 0.9         # m before the prop's corner the dash meets its face
const REF_DIR := Vector2(1, 0)  # the reference dashes' line on open ground
const PATH_LEN := 9.0           # m of open ground the slide and what follows the corner must have
# kits whose dash stops at a wall on purpose: the try only asserts it never ends inside the wall
const KIT_STOPS := {"dolm": "Rock Hop picks a landing short of what it would hop into (BreahHop.spot_for)"}
const HUNTERS := ["archer", "ashwick", "bulwark", "dolm", "dredge", "gunslinger", "juggernaut", "mage", "ostra",
	"rimewright", "tender", "thief"]

var own_walls: Array = []         # the Tenzo rock and the Neve wall the tries meet

func run(main: Node) -> void:
	await _setup(main)
	var foe: Hunter = null
	for h in m.hunters:
		if h.team != P.team:
			foe = h
			break
	var rock_at := _flat_spot(PATH_LEN)
	var neve_at := _spot_away(rock_at)
	if neve_at == Vector3.INF:
		neve_at = _flat_spot(PATH_LEN)
	var surfaces: Array = [_cliff(), _rock(foe, rock_at), _neve_wall(foe, neve_at), _prop()]
	open_spot = _spot_away(rock_at, neve_at)
	if open_spot == Vector3.INF:
		bad += 1
		print("DWALL no open ground for the reference dashes")
		open_spot = _flat_spot(PATH_LEN)
	for s in surfaces:
		if s.is_empty():
			bad += 1
			print("DWALL a surface was not found")
		else:
			print("DWALL surface %s at %s" % [s["name"], str(_touch(s))])
	print("DWALL reference dashes at %s" % str(open_spot))
	for a in HUNTERS:
		P.reclass(Arch.weight(a), a, Arch.signature(a))
		if KIT_STOPS.has(a):
			print("DWALL %s: %s" % [a, KIT_STOPS[a]])
		_dash(open_spot, REF_DIR)      # (a fresh kit's first dash can come out short: not a try)
		for s in surfaces:
			if s.is_empty(): continue
			for ang in DASH_ANGLES:
				_dash_try(a, s, ang)
	print("DASH WALL CHECK DONE, failures: ", bad)
	main.get_tree().quit()

## One dash into surface s at `ang` degrees to it, against the same dash on open ground just before.
func _dash_try(hero: String, s: Dictionary, ang: float) -> void:
	var t: Vector2 = s["t"]
	var n: Vector2 = s["n"]
	var at := _touch(s) + n * START_GAP
	var length := _dash(open_spot, REF_DIR).length()
	var got := _dash(Vector3(at.x, float(s["y"]), at.y), _wish(s, ang))
	var table := cos(deg_to_rad(ang))
	var along := got.dot(t)
	var out := got.dot(n)
	var how := "slide"
	if out > BOUNCED:
		how = "bounce"
	elif along < length * table * 0.5:
		how = "stop"
	var ok := length > 0.5 and absf(along - length * table) <= length * table * KEEP_TOL
	if KIT_STOPS.has(hero):
		how = "kit"
		StoneStand.mover = P      # (his own rocks count as he walks them, as BreahHop._lands asks)
		ok = w.occupy(P.pos.x, P.pos.z, P.r, P.pos.y, false) == 0.0      # it ends free, not in the wall
		StoneStand.mover = null
	if not ok: bad += 1
	print("DWALL %-10s %-12s a%-2d dash %4.1fm  kept %3d%% (table %3d%%)  along %4.1fm  out %5.2fm  %-6s  %s" % [
		hero, s["name"], int(ang), length, roundi(along / maxf(0.01, length) * 100.0), roundi(table * 100.0), along,
		out, how, "ok" if ok else "FAIL"])

## Dashes from `at` along `wish` (the key and the cursor that way on the press, nothing held after it) and
## returns where the body got to over WINDOW steps.
func _dash(at: Vector3, wish: Vector2) -> Vector2:
	_rest()
	_reset(at, wish)
	var cursor := at + Vector3(wish.x, 0.9, wish.y) * 6.0
	for i in WINDOW:
		P.inp["move"] = wish if i == 0 else Vector2.ZERO
		P.inp["aim"] = cursor
		P.inp["dash"] = i == 0
		P.inp["dash_down"] = i == 0      # a tap: held for the press's step only
		_step()
	return Vector2(P.pos.x - at.x, P.pos.z - at.z)

## A flat open spot at least two dashes' room from a and b (each try meets only its own wall), with level
## open ground along REF_DIR for PATH_LEN and a body's width either side (the reference dash's line).
func _spot_away(a: Vector3, b := Vector3(INF, 0, INF)) -> Vector3:
	var side := REF_DIR.orthogonal() * P.r * 2.0
	for k in 200:
		var p := _flat_spot(PATH_LEN)
		var p2 := Vector2(p.x, p.z)
		var run := REF_DIR * (PATH_LEN + 2.0)
		var lane := _line(p2, p2 + run) + _line(p2 + side, p2 + side + run) + _line(p2 - side, p2 - side + run)
		if p.distance_to(a) > PATH_LEN * 2.0 and p.distance_to(b) > PATH_LEN * 2.0 and _clear(lane, p.y):
			return p
	return Vector3.INF

## The wall slide check's clear ground, with normal grip as well (no frost: ice skids a dash further).
func _clear(pts: Array, y: float) -> bool:
	var gripped := func(p: Vector2) -> bool: return is_equal_approx(m.ground_grip(Vector3(p.x, y, p.y)), 1.0)
	return super(pts, y) and pts.all(gripped)

## Stands the body on open ground with no keys for WINDOW steps with only the check's own walls up, so nothing
## from the try before (a haste, a slow, a cooldown, a rock a kit raised) carries into the next one.
func _rest() -> void:
	for w_ in m.verbs.walls.duplicate():
		if not own_walls.has(w_):
			HeroZones.remove_rock(m, w_, false)      # (a Tenzo hop leaves rocks behind)
	_reset(open_spot, Vector2.ZERO)
	P.inp["move"] = Vector2.ZERO
	P.inp["dash_down"] = false
	for i in WINDOW:
		_step()

## One step with no mobs about (lairs keep spawning them: a mob's hit would shove the try).
func _step() -> void:
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	m.step(DT)

## Where this Hunter's body touches surface s (each Hunter's radius is its own).
func _touch(s: Dictionary) -> Vector2:
	if s.has("wall"):
		return s["mid"] - s["t"] * (float(s["wall"]["len"]) * 0.5 - 0.3) + s["n"] * Verbs.wall_reach(s["wall"], P.r)
	return _at(s)

## A Tenzo rock (someone else's, so a full wall), long side across the run, turned off the map's grid. The
## dash meets it near one end and slides its length and on past it.
func _rock(by: Hunter, spot: Vector3) -> Dictionary:
	var rd: Dictionary = Arch.def("dolm")["rock"]
	var d := Vector2(1, 0).rotated(deg_to_rad(ROCK_TURN))
	var rock := HeroZones.rock(m, by, spot, d, "dwall", float(rd["len"]), 999.0, 999.0, false)
	own_walls.append(rock)
	return _barrier("tenzo rock", rock, d, spot)

## A Neve wall at its full width, standing (a foe's: it shoves you off when you touch it, as in a match).
func _neve_wall(by: Hunter, spot: Vector3) -> Dictionary:
	var ed: Dictionary = Arch.def("rimewright")["e"]
	var d := Vector2(1, 0).rotated(deg_to_rad(ROCK_TURN))
	var wall: Dictionary = m.verbs.add_wall(by, spot, d, {
		"length": float(ed["length_max"]), "hp": 999.0, "time": 999.0, "move": true, "block": "enemy",
		"touch": {"kb": float(ed["push"]), "dmg": 0.5, "slow": 1.0, "slow_k": 0.3}}, 1.0)
	wall["y"] = spot.y
	own_walls.append(wall)
	return _barrier("neve wall", wall, d, spot)

## Surface record for barrier w (a Verbs wall facing -d), touched near its start end.
func _barrier(what: String, w_: Dictionary, d: Vector2, spot: Vector3) -> Dictionary:
	return {"name": what, "t": Vector2(-d.y, d.x), "n": -d, "wall": w_, "mid": Vector2(spot.x, spot.z), "y": spot.y}

## A face of a Hollow Crown prop (crates, ruins, rocks or trees; not a built wall), met PROP_TOUCH before its
## corner, with open ground along the face, past the corner and on along every angle's dash.
func _prop() -> Dictionary:
	for iz in range(3, w.h - 3):
		for ix in range(3, w.w - 3):
			var bi := w.idx(ix, iz)
			if w.kind[bi] != World.T_BLOCK or w.walls.has(bi) or not w.props.has(bi): continue
			for nn in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				for tt in [Vector2i(-nn.y, nn.x), Vector2i(nn.y, -nn.x)]:
					var s := _prop_face(ix, iz, Vector2(nn), Vector2(tt))
					if not s.is_empty():
						return s
	return {}

func _prop_face(ix: int, iz: int, n: Vector2, t: Vector2) -> Dictionary:
	var lv := int(w.level[w.idx(ix, iz)])
	if not _open(ix + int(n.x), iz + int(n.y), lv) or not _open(ix + int(t.x), iz + int(t.y), lv):
		return {}
	var corner := Vector2(ix + 0.5, iz + 0.5) + n * 0.5 + t * 0.5
	var s := {"name": String(w.props[w.idx(ix, iz)]), "t": t, "n": n, "edge": corner - t * PROP_TOUCH,
		"y": float(lv) * World.LEVEL}
	var rb := P.r * World.BLOCK_BODY
	var pts := _line(_at(s), corner + n * rb)
	var past := corner + t * rb       # round the corner, the dash goes on along its own line
	for ang in DASH_ANGLES:
		pts.append_array(_line(past, past + _wish(s, ang) * PATH_LEN))
	return s if _clear(pts, s["y"]) else {}
