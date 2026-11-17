extends RefCounted
## --move-feel-check's no-carry rows (the owner's decision: one shared movement profile for all modes, and
## falling never converts into horizontal momentum). Every Hunter in Arch.ORDER runs the same rows in
## the match and in the garden, on the same lane (tools/fall_course.gd): walking off a ledge at run speed,
## walking off into a 6 m and a 15 m fall, dropping 6 m from rest onto a 10, 25 and 40 degree slope and
## running off a ledge onto each, a mantle that ends in a fall, a knock that ends in a fall, and closing
## the glider at height. The speed when the last fall began is "before"; "after" is the most horizontal
## speed from the landing step to FOLLOW s on. After may never pass before by more than EPS.
##
## Prints one "MFEEL carry <mode> <id> ..." line per Hunter and mode, and a FAIL line per broken row.

const COURSE := preload("res://tools/fall_course.gd")
const DT := 1.0 / 60.0
const EPS := 0.05           # m/s: what a landing may add (none: float slack)
const FOLLOW := 0.5         # s watched from the landing step on
const LIMIT := 6.0          # s: a row that never lands fails
const TOP := 9.6            # m: the lane's top (12 terraces); its lowest ground stays above the abyss backstops
const EDGE := 12.0          # m along the lane: where the top ends
const SLOPES := [10.0, 25.0, 40.0]      # degrees, falling away along the run
const KNOCK := Vector3(10.0, 4.0, 0.0)  # m/s: the knock's push along the lane and its lift
const GLIDE_HOLD := 0.6     # s gliding at height before the glider is closed
const GLIDE_UP := 12.0      # m above the ground where the glider is closed
const KEYS := Vector2(1, 0)             # held along the lane

var bad := 0

## Each row: name, the lane's pieces (fall_course.gd), where the body starts (u along the lane, height above
## the ground there, upward speed), the keys held from the start ("hold") and let go when the fall begins
## ("let_go": what the fall then carries is the body's own speed, not air control), the height a landing must
## be under to count (the top itself is never the landing), and the knock or the glide it starts with.
func rows() -> Array:
	var out := [
		_row("ledge", [[0, TOP, 0], [EDGE, TOP - 2.4, 0]], 1.0, 0.0),
		_row("fall_6", [[0, TOP, 0], [EDGE, TOP - 6.0, 0]], 1.0, 0.0),
		_row("fall_15", [[0, TOP, 0], [EDGE, TOP - 15.0, 0]], 1.0, 0.0),
	]
	for deg in SLOPES:
		var k := -tan(deg_to_rad(deg))
		var drop := _row("slope_%d" % deg, [[0, TOP, k]], 6.0, 6.0)
		drop["hold"] = false
		drop["land"] = INF
		out.append(drop)
		out.append(_row("slope_%d_run" % deg, [[0, TOP, 0], [EDGE, TOP - 2.4, k]], 1.0, 0.0))
	# a jump into a wall three terraces up, the ledge rise onto its 1 m top, and on over into an 8 m fall
	var mantle := _row("mantle", [[0, TOP, 0], [8, TOP + 2.4, 0], [9, TOP - 5.6, 0]], 6.9, 0.0)
	mantle["vy"] = Hunter.JUMP_V
	mantle["arm"] = TOP + 2.35      # (the fall that counts starts above the wall's top)
	mantle["let_go"] = true
	out.append(mantle)
	var knock := _row("knock", [[0, TOP, 0], [EDGE, TOP - 6.0, 0]], EDGE - 1.5, 0.0)
	knock["knock"] = true
	knock["hold"] = false
	out.append(knock)
	var glide := _row("glide_close", [[0, TOP, 0]], 1.0, GLIDE_UP)
	glide["glide"] = GLIDE_HOLD
	glide["let_go"] = true
	glide["land"] = TOP + 0.1
	out.append(glide)
	return out

func _row(row_name: String, pieces: Array, u: float, up: float) -> Dictionary:
	return {"name": row_name, "pieces": pieces, "u": u, "up": up, "vy": 0.0, "hold": true, "let_go": false,
		"arm": -INF, "land": TOP - 1.0, "knock": false, "glide": 0.0}

## Lays the lane over open sky in `w` (its script becomes the course for the rows; put back after).
func lay(w: World) -> Dictionary:
	var keep := {}
	for p in w.get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			keep[p["name"]] = w.get(p["name"])
	var was: Script = w.get_script()
	w.set_script(COURSE)
	for k in keep: w.set(k, keep[k])
	w.set("at", w.call("find_lane"))
	return {"keep": keep, "script": was}

func lift(w: World, laid: Dictionary) -> void:
	w.set_script(laid["script"])
	for k in laid["keep"]: w.set(k, laid["keep"][k])

## Every row for every Hunter; `body` is a MatchBody or a HomeBody already on the laid world `w`.
func run_all(mode: String, w: World, body) -> void:
	var at: Vector2 = w.get("at")
	if at == Vector2.INF:
		_fail("carry %s: no open sky for the lane" % mode)
		return
	for id in Arch.ORDER:
		body.become(id)
		var line := []
		for r in rows():
			w.call("lay_pieces", r["pieces"])
			_start(body, w, at, r)
			await body.settle()
			var ba := _run(body, r)
			line.append("%s %.2f>%.2f" % [r["name"], ba.x, ba.y])
			if not (ba.y <= ba.x + EPS):
				_fail("carry %s %s %s: %.3f m/s after the landing, %.3f before the fall"
					% [mode, id, r["name"], ba.y, ba.x])
		print("MFEEL carry %-5s %-11s %s" % [mode, id, " | ".join(line)])
	w.call("lay_pieces", [])

## The row's start: the body placed, keys down, the glider open.
func _start(body, w: World, at: Vector2, r: Dictionary) -> void:
	var u: float = r["u"]
	var g := w.ground_at(at.x + u, at.y)
	var up: float = r["up"]
	var vy: float = r["vy"]
	body.place(Vector3(at.x + u, g + up, at.y), vy, up <= 0.0 and vy <= 0.0)
	body.keys(KEYS if r["hold"] else Vector2.ZERO)
	if r["glide"] > 0.0:
		body.glide(true)

## One row from its start: (before, after) in m/s; after is INF when it never landed.
func _run(body, r: Dictionary) -> Vector2:
	if r["knock"]: body.knock(KNOCK)
	var glide_left: float = r["glide"]
	var before := INF
	var was_falling := false
	var landed := -1
	var after := 0.0
	for i in int(LIMIT / DT):
		if glide_left > 0.0:
			glide_left -= DT
			if glide_left <= 0.0: body.glide(false)
		body.step()
		var falling: bool = not body.on_ground() and body.vy() <= 0.0 and not body.gliding()
		if falling and not was_falling and body.y() >= float(r["arm"]):
			before = body.hv()
			if r["let_go"]: body.keys(Vector2.ZERO)
		was_falling = falling
		if landed < 0 and before < INF and body.on_ground() and body.y() <= float(r["land"]):
			landed = i
		if landed >= 0:
			after = maxf(after, body.hv())
			if i - landed >= int(FOLLOW / DT): break
	body.keys(Vector2.ZERO)
	if landed < 0:
		after = INF      # (never landed: the row fails)
	if before == INF:
		before = 0.0     # (never fell)
	return Vector2(before, after)

func _fail(what: String) -> void:
	print("MFEEL FAIL %s" % what)
	bad += 1

## The match's player Hunter, through Match.step.
class MatchBody:
	var m: Match
	var h: Hunter
	var reset: Callable      # (p, grounded): the check's clean-hunter reset
	func _init(match_node: Match, hunter: Hunter, reset_fn: Callable) -> void:
		m = match_node
		h = hunter
		reset = reset_fn
	func become(id: String) -> void:
		h.reclass(Arch.weight(id), id)      # (set_arch keeps the class, which can swap the Hunter for another)
	func settle() -> void:
		pass
	func place(p: Vector3, vy: float, grounded: bool) -> void:
		reset.call(p, grounded)
		h.vel = Vector3(0, vy, 0)
		h.last_gy = p.y
		if not grounded: h.air_t = 1.0
	func keys(v: Vector2) -> void:
		h.inp["move"] = v
	func knock(v: Vector3) -> void:
		m.displace.knock(h, Vector2(v.x, v.z) * h.mass(), v.y * h.mass())
	func glide(on: bool) -> void:
		h.inp["glide"] = on
		if on: h.gliding = true
	func step() -> void:
		m.step(Match.DT)
	func on_ground() -> bool: return h.grounded
	func gliding() -> bool: return h.gliding
	func vy() -> float: return h.vel.y
	func y() -> float: return h.pos.y
	func hv() -> float: return Vector2(h.vel.x, h.vel.z).length()

## The garden's player (Home._move_player), the hero read from the save as it is at home.
class HomeBody:
	var hm: Node
	func _init(home: Node) -> void:
		hm = home
	func become(id: String) -> void:
		Save.d["arch"] = id
	## A frame between rows: the garden reads just-pressed keys, which hold for the rest of their frame.
	func settle() -> void:
		await hm.get_tree().process_frame
	func place(p: Vector3, vy: float, _grounded: bool) -> void:
		hm.ppos = Vector3(p.x, 0, p.z)
		hm.py = p.y
		hm.pvy = vy
		hm.pvel = Vector3.ZERO
		hm.gliding = false
		hm.dash_t = 0.0
		hm.lfl = {}
	func keys(v: Vector2) -> void:      # (the rows only ever hold KEYS, along +x)
		if v.x > 0.0: Input.action_press("right", v.x)
		else: Input.action_release("right")
	## The garden has no knock: the push and lift go on as Hunter.impulse puts them on a body at rest.
	func knock(v: Vector3) -> void:
		hm.pvel = Vector3(v.x, 0, v.z)
		hm.pvy = v.y
	func glide(on: bool) -> void:
		if on:
			Input.action_press("glide")
			hm.gliding = true
		else:
			Input.action_release("glide")
	func step() -> void:
		hm._move_player(DT)
	func on_ground() -> bool: return hm.pvy <= 0.0 and hm.py <= hm._ground_h(hm.ppos.x, hm.ppos.z) + 0.001
	func gliding() -> bool: return hm.gliding
	func vy() -> float: return hm.pvy
	func y() -> float: return hm.py
	func hv() -> float: return Vector2(hm.pvel.x, hm.pvel.z).length()
