extends RefCounted
## --hit-shape-check: how far, how wide and how round each Hunter's damaging inputs really hit
## (docs/HITBOX_SIZE.md, "Measured hit shapes"). The hero stands facing +X on flat ground beside a
## grid of training dummies (0.5 m apart, the standard body radius) and fires LMB tap and hold, RMB tap
## and hold, E, X (the hero ultimate) and the dash once each, aimed straight down +X. Which dummies lost
## health gives reach, lane width and arc. Only z >= 0 is gridded (shapes aimed down +X are mirrored:
## 70 dummies instead of 400 keep the run under a minute). A bullet stops at the first dummy it hits, so
## a shot is measured from its own flight range and radius instead. Prints HSROW lines for the doc table.
## Never touches the save.

const STEP := 1.0 / 20.0         # s per Match step (the grid is too heavy for 60 Hz)
const NX := 14                   # columns: x = 1.0 .. 7.5 m
const NZ := 5                    # rows: z = 0 .. 2.0 m (mirrored)
const GRID := 0.5                # m between dummies
const TOL := 0.10                # a content number this far off the measurement is flagged
const REACH_KEYS := ["range", "reach", "len", "length", "dist", "roll", "lunge"]
const WIDTH_KEYS := ["width"]
const ARC_KEYS := ["deg", "arc", "angle"]

var bad := 0
var m: Match
var P: Hunter
var home: Vector3
var dummies: Array = []
var parked := false              # the dummies stand behind the hero: a lane probe, only the shots count
var shot_seen: Array = []        # [flight range, radius] of each non-melee shot the hero fired

func ok(cond: bool, what: String) -> void:
	print("HSCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _slot(i: int) -> Vector3:
	return home + Vector3(1.0 + (i / NZ) * GRID, 0.0, (i % NZ) * GRID)

func _clear_dummies() -> void:
	for i in dummies.size():
		var d: Hunter = dummies[i]
		d.teleport(home + Vector3(-6.0, 0, 6.0) if parked else _slot(i))
		d.vel = Vector3.ZERO
		d.hp = d.max_hp
		d.stun_t = 0.0
		d.root_t = 0.0
		d.slow_t = 0.0
		d.knock_t = 0.0
		d.burn_t = 0.0

## The slots that lost health since the last call; the dummies go back to their places.
func _took_damage() -> Array:
	var hit: Array = []
	for i in dummies.size():
		var d: Hunter = dummies[i]
		if d.hp < d.max_hp: hit.append(i)
	return hit

func _spawn(main: Node) -> void:
	var ac: RefCounted = load("res://tools/archetype_check.gd").new()
	ac.main = main
	var r: Array = ac.setup("mage", 30.0)
	m = r[0]
	P = r[1]
	home = r[4]
	(r[2] as Hunter).teleport(home + Vector3(-6.0, 0, -8.0))      # the setup's own target: out of the grid
	for i in NX * NZ:
		var d: Hunter = m.make_hunter("D%d" % i, 5, "medium", "Dummy", "idle", {}, _slot(i), {"arch": "none"})
		d.max_hp = 1e6
		d.hp = 1e6
		dummies.append(d)

## Fresh hero, fresh dummies, aim down +X; then fires `kind` and returns the slots hit within `secs`.
func _probe(arch: String, kind: String, hold: float, secs: float, park := false) -> Array:
	parked = park
	HeroVfx.of(m).ribbons.clear()      # (a trail still following the old model would read a freed node)
	P.reclass(Arch.weight(arch), arch)
	P.unlock_all()
	P.lvl = 6
	P.slot_lv["ult"] = 1
	P.ult = 1.0
	P.dashes = P.max_dashes()
	P.hp = P.max_hp
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.inp["aim"] = home + Vector3(20.0, 0.9, 0)
	P.inp["aim_y"] = home.y
	m.shots.clear()
	m.zones.clear()
	_clear_dummies()
	shot_seen.clear()
	for i in 3: m.step(STEP)
	_clear_dummies()
	var hit := {}
	var t := 0.0
	var first := true
	while t < secs:
		var held := t < hold
		P.inp["fire"] = (kind == "lmb" and first) or (kind == "lmb_hold" and held)
		P.inp["sec_hold"] = kind == "rmb_hold" and held
		P.inp["dash_down"] = (kind == "dash" and first) or (kind == "dash_hold" and held)
		P.fire_cd = 0.0 if first else P.fire_cd
		if first:
			match kind:
				"rmb", "rmb_hold": P.ak.press_rmb()
				"e": P.ak.use_e()
				"x": P.ak.cast_ult()
				"dash", "dash_hold": P.do_dash()
		m.step(0.002 if first else STEP)      # (a tiny first step: a bullet is seen before a dummy eats it)
		first = false
		t += STEP
		for s in m.shots:
			if s["by"] == P and not s["x"].get("melee", false) and not s.has("hs_seen"):
				s["hs_seen"] = true
				shot_seen.append([float(s["life0"]) * (s["vel"] as Vector2).length(), float(s["r"])])
		if parked and not shot_seen.is_empty(): break
		for i in _took_damage(): hit[i] = true
		if kind == "rmb_hold" and t >= hold: P.inp["sec_hold"] = false
	P.inp["fire"] = false
	P.inp["dash_down"] = false
	P.inp["sec_hold"] = false
	return hit.keys()

## {reach, width, arc, n}: reach to the far edge of what was hit (m), the widest lane across the
## aim line (m) and the angle the hits spread over (degrees). Centres are corrected by the dummy's
## own hit circle and by half a grid cell, since a dummy is hit once its circle touches the shape.
func _measure(hit: Array) -> Dictionary:
	var out := {"n": hit.size(), "reach": 0.0, "width": 0.0, "arc": 0.0, "src": "grid", "cap": ""}
	if hit.is_empty(): return out
	var rd: float = dummies[0].hit_radius()
	var far := 0.0
	var zmax := 0.0
	for i in hit:
		var c: Vector3 = _slot(i) - home
		far = maxf(far, Vector2(c.x, c.z).length())
		zmax = maxf(zmax, c.z)
	var edge_x := 1.0 + (NX - 1) * GRID
	var edge_z := (NZ - 1) * GRID
	var cap := ""
	for i in hit:
		var c: Vector3 = _slot(i) - home
		if c.x >= edge_x and not cap.contains("r"): cap += "r"
		if c.z >= edge_z and not cap.contains("w"): cap += "w"
	out["cap"] = cap
	var arc := 0.0
	for i in hit:
		var c: Vector3 = _slot(i) - home
		if Vector2(c.x, c.z).length() >= far * 0.6: arc = maxf(arc, absf(atan2(c.z, c.x)))
	out["reach"] = maxf(0.0, far - rd + GRID * 0.5)
	out["width"] = maxf(0.0, 2.0 * (zmax - rd + GRID * 0.5))
	out["arc"] = rad_to_deg(arc) * 2.0 if zmax > rd + GRID else 0.0
	return out

func _top(d: Dictionary, keys: Array) -> float:
	var best := 0.0
	for k in keys:
		var v = d.get(k, 0.0)
		if v is Array and not v.is_empty():
			best = maxf(best, float(v[v.size() - 1]))
		elif v is float or v is int:
			best = maxf(best, float(v))
	return best

## The kit's JSON numbers for this input: the slot's def (or the weapon for LMB).
func _content(kind: String) -> Dictionary:
	var d: Dictionary
	match kind:
		"lmb", "lmb_hold": d = P.wpn
		"rmb", "rmb_hold": d = P.ak.rmb_def()
		"e": d = P.ak.e_def()
		"x": d = P.ak.x_def()
		_: d = P.ak.dash_def()
	return {"reach": _top(d, REACH_KEYS), "width": _top(d, WIDTH_KEYS), "arc": _top(d, ARC_KEYS)}

## "reach +23%" for every content number that is more than TOL off; "~" marks one within the 0.5 m grid.
func _flags(meas: Dictionary, cont: Dictionary) -> String:
	var out: Array = []
	for k in ["reach", "width", "arc"]:
		var c: float = cont[k]
		var v: float = meas[k]
		if c <= 0.0 or int(meas["n"]) == 0: continue
		var edge := "r" if k == "reach" else "w"
		if edge in meas["cap"]: continue      # the grid ends first
		if absf(v - c) > TOL * c:
			var tag := "~" if k != "arc" and absf(v - c) <= GRID else ""
			out.append("%s%s %+.0f%%" % [tag, k, (v - c) / c * 100.0])
	return ", ".join(out)

func _has(arch: String, kind: String) -> bool:
	match kind:
		"rmb_hold": return float(P.ak.rmb_def().get("hold", 0.0)) > 0.0
		"dash_hold": return float(P.ak.dash_def().get("hold", 0.0)) > 0.0
		"x": return not P.ak.x_def().is_empty()
		"lmb_hold": return P.wpn.has("charge_time") or P.wpn.has("draw")
	return true

func _secs_for(kind: String, hold: float) -> float:
	match kind:
		"e": return 1.2
		"x": return 1.5
		"lmb": return 0.5
	return hold + 0.5 if hold > 0.0 else 0.6

func _hold_for(kind: String) -> float:
	match kind:
		"lmb_hold": return maxf(float(P.wpn.get("charge_time", 0.0)), 1.1 if P.wpn.has("draw") else 0.6) + 0.15
		"rmb_hold":
			var rd := P.ak.rmb_def()
			return maxf(float(rd.get("full_t", 0.0)), float(rd.get("hold", 0.3)) + 0.5) + 0.1
		"dash_hold": return float(P.ak.dash_def().get("hold", 0.6)) + 0.05
	return 0.0

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	await _spawn(main)
	var t0 := Time.get_ticks_msec()
	for a in Arch.ids():
		var hits := 0
		P.reclass(Arch.weight(a), a)
		for kind in ["lmb", "lmb_hold", "rmb", "rmb_hold", "e", "x", "dash", "dash_hold"]:
			if not _has(a, kind): continue
			var hold := _hold_for(kind)
			var hit := _probe(a, kind, hold, _secs_for(kind, hold))
			var meas := _measure(hit)
			if meas["n"] >= 1 and meas["n"] <= 2 and kind != "dash" and kind != "dash_hold":
				_probe(a, kind, hold, _secs_for(kind, hold), true)      # a lone bullet: measured on a clear lane
				if not shot_seen.is_empty():
					var far := 0.0
					for s in shot_seen: far = maxf(far, s[0])
					var wide := 2.0 * float(shot_seen[0][1])
					meas = {"n": meas["n"], "reach": far, "width": wide, "arc": 0.0, "src": "shot", "cap": ""}
			var cont := _content(kind)
			var flags := _flags(meas, cont)
			hits += 1 if int(meas["n"]) > 0 else 0
			var src: String = meas["src"] + ("+" + meas["cap"] if meas["cap"] != "" else "")
			print("HSROW|%s|%s|%d|%s|%.1f|%.1f|%.0f|%.1f|%.1f|%.0f|%s" % [a, kind, meas["n"], src,
					meas["reach"], meas["width"], meas["arc"], cont["reach"], cont["width"], cont["arc"], flags])
		ok(hits >= 1, "%s: at least one input hurt a dummy (%d did)" % [a, hits])
	ok(Time.get_ticks_msec() - t0 < 60000, "the run took %.1f s (budget 60)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	HeroVfx.of(m).ribbons.clear()
	print("HIT SHAPE CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
