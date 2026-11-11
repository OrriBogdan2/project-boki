extends RefCounted
## --mantle-fling-check (owner bug 11-11: "hit an edge at a certain angle, you mantle and maintain momentum and go
## flying off"). A sweep of approaches into a long straight ledge, one and two terraces high: running jumps,
## ground and air dashes, glides, and flying in fast (a knock or a launch carrying you), each from straight
## in to 80 degrees off the face. For every approach that tops the ledge it follows the next EXIT_S seconds
## and asserts the fastest you go is at most MantleCarry.exit_cap (a little forward flow, never a launch),
## and that you never jump further than the speed you're going (no push out of the wall).
## Prints "MFLING ok|FAIL ..." lines, the worst approaches, and "MFLING DONE, failures: N". Never touches the save.

const DT := Match.DT
const ANGLES := [0.0, 20.0, 40.0, 55.0, 65.0, 75.0, 80.0]     # degrees off straight into the face
const FLY_SPEEDS := [6.0, 10.0, 14.0, 19.0]                   # m/s: thrown or launched into the face
const MODES := ["run_jump", "dash", "jump_dash", "glide", "fly"]
const EXIT_S := 0.8            # s followed after the mantle hands back
const WALL_HALF := 7           # tiles each side of the hit point: a long wall, so a glancing rise stays on it

var m: Match
var w: World
var h: Hunter
var bad := 0
var rows: Array = []

func ok(cond: bool, what: String) -> void:
	print("MFLING %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	w = m.world
	for i in 10:
		m.step(DT)
	_clear_others()
	for rise in [1, 2]:
		var wall := _carve(rise)
		if wall.is_empty():
			ok(false, "found flat ground for a %d-terrace wall" % rise)
			continue
		for mode in MODES:
			for ang in ANGLES:
				for side in [1.0, -1.0]:
					var speeds: Array = FLY_SPEEDS if mode == "fly" else [0.0]
					for s in speeds:
						var r := _try(wall, mode, ang * side, s)
						if not r.is_empty():
							r["what"] = "%dT %s %+.0fdeg %s" % [rise, mode, ang * side, ("%.0fm/s" % s) if s > 0.0 else ""]
							rows.append(r)
	_report()
	main.get_tree().quit()

func _report() -> void:
	var cap := MantleCarry.exit_cap(h)
	var worst := {}
	var fast := 0
	var pushed := 0
	var flown := 0.0
	for r in rows:
		flown = maxf(flown, r["flown"])
		if worst.is_empty() or r["vmax"] > worst["vmax"]:
			worst = r
		if r["vmax"] > cap + 0.05:
			fast += 1
			print("MFLING over cap: %s in %.1f -> exit %.1f m/s, %.1fm before landing" % [r["what"], r["vin"], r["vmax"], r["flown"]])
		if r["jump"] > 0.0:
			pushed += 1
			print("MFLING pushed: %s %.2fm in one step" % [r["what"], r["jump"]])
	print("MFLING %d topped approaches; fastest exit %.1f m/s (%s, in at %.1f), cap %.1f; longest flight %.1fm" % [
		rows.size(), worst.get("vmax", 0.0), worst.get("what", "-"), worst.get("vin", 0.0), cap, flown])
	ok(rows.size() >= 80, "most approaches top the ledge (%d)" % rows.size())
	ok(fast == 0, "no exit faster than %.1f m/s, from any angle or speed (%d over)" % [cap, fast])
	ok(pushed == 0, "never moved further in a step than your speed carries you (%d pushed)" % pushed)
	print("MFLING DONE, failures: %d" % bad)

## Only the player is in the match.
func _clear_others() -> void:
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	h = m.player
	for o in m.hunters:
		if o != h:
			o.ctrl = "idle"
			o.teleport(Vector3(-500, 50, -500))
			o.out = true
	for kk in [h.kin, h.kin2]:
		if kk:
			m.kins.erase(kk)
			kk.queue_free()
	h.kin = null
	h.kin2 = null
	h.ctrl = "local"

## Raises a wall `rise` terraces high, 2*WALL_HALF+1 tiles long, facing -x onto 8 m of flat open ground.
## Returns {face (the hit point on it), n (into the wall), low, top}.
func _carve(rise: int) -> Dictionary:
	for k in 4000:
		var g := w.random_ground()
		var x0 := int(floor(g.x))
		var z0 := int(floor(g.z))
		var lv := int(w.level[w.idx(x0, z0)])
		var good := true
		for dz in range(-WALL_HALF - 2, WALL_HALF + 3):
			for dx in range(-8, 4):
				var tx := x0 + dx
				var tz := z0 + dz
				if not w.inb(tx, tz):
					good = false
					break
				var i := w.idx(tx, tz)
				if w.kind[i] != World.T_GROUND or int(w.level[i]) != lv or w.stairs.has(i) or w.walls.has(i) \
						or w.sheer.has(i) or w.is_block(tx + 0.5, tz + 0.5):
					good = false
					break
			if not good:
				break
		if not good:
			continue
		for dz in range(-WALL_HALF, WALL_HALF + 1):
			for dx in range(1, 4):
				w.level[w.idx(x0 + dx, z0 + dz)] = lv + rise
		return {"face": Vector2(x0 + 1.0, z0 + 0.5), "n": Vector2(1, 0), "low": lv * World.LEVEL, "top": (lv + rise) * World.LEVEL}
	return {}

func _reset(at: Vector3, v: Vector3, grounded: bool) -> void:
	h.out = false
	h.downed = false
	h.hp = h.max_hp
	h.teleport(at)
	h.grounded = grounded
	h.vel = v
	h.pad = {}
	h.grap = {}
	h.lfloat = {}
	for k in ["grap_cd", "mantle_cd", "roll_t", "knock_t", "fly_t", "stun_t", "dash_buf", "coyote", "jump_buf", "ex_cd"]:
		h.set(k, 0.0)
	h.kb_t = -9.0
	h.gliding = false
	h.dropping = false
	h.diving = false
	h.air_t = 0.0 if grounded else 0.3
	h.dashes = h.max_dashes()
	for k in ["glide", "glide_btn", "jump", "dash", "fire", "sig", "sec", "ult"]:
		h.inp[k] = false
	h.inp["move"] = Vector2.ZERO

## One approach `ang` degrees off straight in. Empty if it never topped; else {vin, vmax, flown, jump}: the speed
## as you caught the ledge, the fastest from the hand-back over EXIT_S, how far you went before landing, and the
## biggest step beyond what your speed carries (a push out of the wall).
func _try(wall: Dictionary, mode: String, ang: float, fly_speed: float) -> Dictionary:
	var n: Vector2 = wall["n"]
	var face: Vector2 = wall["face"]
	var top := float(wall["top"])
	var mv := n.rotated(deg_to_rad(ang))
	# where you'd meet the face, and how long before that the approach starts
	var lead := {"run_jump": 0.45, "dash": 0.5, "jump_dash": 0.55, "glide": 0.5, "fly": 0.12}[mode] as float
	var speed := {"run_jump": h.base_speed, "dash": h.base_speed, "jump_dash": h.base_speed, "glide": Hunter.GLIDE_SPEED, "fly": fly_speed}[mode] as float
	var hit := face - n * (h.r + 0.05)
	var st := hit - mv * speed * lead
	if mode == "fly":
		_reset(Vector3(st.x, top - 0.5, st.y), Vector3(mv.x * speed, 0.0, mv.y * speed), false)
		h.last_gy = float(wall["low"])
	elif mode == "glide":
		_reset(Vector3(st.x, top - 0.2, st.y), Vector3(mv.x * speed, 0.0, mv.y * speed), false)
		h.last_gy = float(wall["low"])
		h.inp["glide"] = true
		h.inp["glide_btn"] = true
		h.gliding = true
	else:
		_reset(Vector3(st.x, float(wall["low"]) + 0.02, st.y), Vector3(mv.x * speed, 0.0, mv.y * speed), true)
	var t := 0.0
	var caught := false
	var out_t := -1.0
	var res := {"vin": 0.0, "vmax": 0.0, "flown": 0.0, "jump": 0.0}
	var from := Vector2.ZERO
	while t < 2.5:
		h.inp["move"] = mv
		h.inp["jump"] = (mode == "run_jump" and absf(t - 0.2) < DT * 0.5) or (mode == "jump_dash" and t < DT * 0.5)
		h.inp["dash"] = (mode == "dash" and absf(t - 0.25) < DT * 0.5) or (mode == "jump_dash" and absf(t - 0.15) < DT * 0.5)
		var p0 := Vector2(h.pos.x, h.pos.z)
		var v0 := Vector2(h.vel.x, h.vel.z).length()
		m.step(DT)
		t += DT
		var hv := Vector2(h.vel.x, h.vel.z).length()
		var stepped := Vector2(h.pos.x, h.pos.z).distance_to(p0)
		if not caught and not h.lfloat.is_empty():
			caught = true
			res["vin"] = h.carry_v
		elif caught and out_t < 0.0 and h.lfloat.is_empty():
			if h.pos.y < top - 0.2:
				return {}       # let go or slid off the end: not a mantle
			out_t = t
			from = Vector2(h.pos.x, h.pos.z)
		if out_t >= 0.0:
			res["vmax"] = maxf(res["vmax"], hv)
			res["jump"] = maxf(res["jump"], stepped - maxf(v0, hv) * DT - 0.05)
			if not h.grounded:
				res["flown"] = from.distance_to(Vector2(h.pos.x, h.pos.z))
			if t - out_t >= EXIT_S:
				return res
	return res if out_t >= 0.0 else {}
