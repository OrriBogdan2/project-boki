extends RefCounted
## --friendly-bodies-check: your own and allied Boki do not bend your abilities (item 56), and a Fused
## Dredge's hook pulls straight to the live Fused body (item 58). Each ability runs twice, with and without
## your own Boki in the lane or beside the target, and the results must match.

const TOL := 0.35        # m: how far a run with a Boki may differ from the run without
var main: Node
var ak
var fails := 0
var n := 0

func ok(what: String, cond: bool, info := "") -> void:
	n += 1
	print("FRIENDLYBODIES %-72s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

func run(main_node: Node) -> void:
	main = main_node
	ak = load("res://tools/archetype_check.gd").new()
	ak.main = main
	await _hem_impale()
	await _own_dash()
	await _push_anchor()
	await _dredge_hook(false)
	await _dredge_hook(true)
	await _fused_sweep()
	print("FRIENDLYBODIES DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Your own Boki parked in the world, frozen so only the bodies' rules move it.
func _park(k: Kin, at: Vector3) -> void:
	k.teleport(at)
	k.state = "active"
	k.fly = {}
	k.brain.think_t = 1e9

func _wall(m: Match, t_pos: Vector3, lv: int) -> void:
	var W: World = m.world
	var wk: PackedByteArray = W.kind
	var wl: PackedByteArray = W.level
	for dz in range(-3, 4):
		for dx in range(0, 3):
			var i: int = W.idx(int(t_pos.x) + dx, int(t_pos.z) + dz)
			wk[i] = World.T_GROUND
			wl[i] = lv if dx < 2 else lv + 3
	W.kind = wk
	W.level = wl

## Hem's Heavy Shot into a wall. where: "" (no Boki), "lane" (between her and the target), "behind" (in the
## way of the knock). Returns {x, stun, dmg}.
func _impale(where: String) -> Dictionary:
	var r: Array = ak.setup("archer", 6.0, "pebbit", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var K: ArchKit = P.ak
	_wall(m, T.pos, lv)
	var k: Kin = P.kin
	var spot := Vector3.INF
	match where:
		"lane":
			spot = home + Vector3(3.0, 0, 0)
		"behind":
			spot = T.pos + Vector3(1.0, 0, 0)
		"side":
			spot = home + Vector3(1.0, 0, 2.5)
	if where != "":
		_park(k, spot)
	ak.fresh(T)
	K.res = 0.0
	ak.aim_at(P, T.pos)
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	var stun := 0.0
	var t := 0.0
	while t < 1.15:
		P.inp["sec_hold"] = true
		if where != "":
			_park(k, spot)
		m.step(ak.DT)
		t += ak.DT
	P.inp["sec_hold"] = false
	m.step(ak.DT)
	t = 0.0
	while t < 0.8:
		if where != "":
			_park(k, spot)
		m.step(ak.DT)
		stun = maxf(stun, T.stun_t)
		t += ak.DT
	var out := {"x": T.pos.x - home.x, "z": T.pos.z - home.z, "stun": stun, "dmg": ak.dmg(T)}
	await ak.done(m)
	return out

func _hem_impale() -> void:
	var base: Dictionary = await _impale("")
	ok("Hem impale, no Boki: pins into the wall", float(base["stun"]) > 0.5 and float(base["dmg"]) >= 14.0,
			"stun %.2f dmg %.0f x %.2f" % [base["stun"], base["dmg"], base["x"]])
	for where in ["lane", "behind", "side"]:
		var got: Dictionary = await _impale(where)
		var dx := absf(float(got["x"]) - float(base["x"]))
		var dz := absf(float(got["z"]) - float(base["z"]))
		var same_stop := dx <= TOL and dz <= TOL
		ok("Hem impale, own Boki %s: reaches the foe, same stop point" % where,
				same_stop and float(got["dmg"]) >= float(base["dmg"]) - 1.0,
				"x %.2f vs %.2f z %.2f vs %.2f dmg %.0f vs %.0f" % [
					got["x"], base["x"], got["z"], base["z"], got["dmg"], base["dmg"]])
		ok("Hem impale, own Boki %s: the wall stun still fires" % where,
				float(got["stun"]) > 0.5 and absf(float(got["stun"]) - float(base["stun"])) < 0.3,
				"stun %.2f vs %.2f" % [got["stun"], base["stun"]])

## A dash straight at your Boki: how far it goes.
func _dash_dist(arch: String, boki: bool) -> float:
	var r: Array = ak.setup(arch, 14.0, "pebbit", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home: Vector3 = r[4]
	if boki:
		_park(P.kin, home + Vector3(1.4, 0, 0))
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.dashes = P.max_dashes()
	ak.aim_at(P, home + Vector3(8, 0, 0))
	P.inp["move"] = Vector2(1, 0)
	P.do_dash()
	var spot := home + Vector3(1.4, 0, 0)
	ak.step(m, 0.8, func(): if boki: _park(P.kin, spot))
	var d: float = Vector2(P.pos.x - home.x, P.pos.z - home.z).length()
	await ak.done(m)
	return d

func _own_dash() -> void:
	for arch in ["archer", "gunslinger", "juggernaut"]:
		var clear: float = await _dash_dist(arch, false)
		var bumped: float = await _dash_dist(arch, true)
		ok("%s dash through your own Boki: same distance" % arch, absf(clear - bumped) <= TOL and clear > 1.5,
				"%.2f vs %.2f" % [bumped, clear])

## One Dredge hook at a dummy `ang` degrees off the +x axis, 7 m out. Returns how it ended: the dummy's last
## offset from the straight line to the body, and how far it finished from the body's front.
func _hook(species: String, ang: float, boki_in_path: bool) -> Dictionary:
	var r: Array = ak.setup("dredge", 7.0, species, false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: DredgeKit = P.ak
	var out := {"fused": false}
	if species != "":
		P.kin.trust = 95.0
		if boki_in_path:
			_park(P.kin, home + Vector3(2.5, 0, 0).rotated(Vector3.UP, -deg_to_rad(ang)))
		else:
			ak.merge_now(P)
			ak.step(m, 0.9)
			out["fused"] = KinMerge.in_form(P)
	var dir3 := Vector3(1, 0, 0).rotated(Vector3.UP, -deg_to_rad(ang))
	T.teleport(home + dir3 * 7.0)
	T.vel = Vector3.ZERO
	ak.fresh(T)
	var start := P.pos
	var t0 := T.pos
	ak.aim_at(P, T.pos)
	K.cd["rmb"] = 0.0
	K.ch_rmb = 1.0
	ak.tap(m, P)
	var dev := 0.0
	var t := 0.0
	var line := Vector2(t0.x - start.x, t0.z - start.z).normalized()
	while t < 3.5:
		ak.step(m, ak.DT)
		t += ak.DT
		var rel := Vector2(T.pos.x - start.x, T.pos.z - start.z)
		dev = maxf(dev, absf(rel.cross(line)))
		if K.pull.is_empty() and not K.flying and t > 0.5:
			break
	var front := start + Vector3(line.x, 0, line.y) * float(K.rmb_def()["gap"])
	out["dev"] = dev
	out["end_dist"] = Vector2(T.pos.x - P.pos.x, T.pos.z - P.pos.z).length()
	out["front_miss"] = Vector2(T.pos.x - front.x, T.pos.z - front.z).length()
	out["grapples"] = K.grapples
	await ak.done(m)
	return out

func _dredge_hook(fused: bool) -> void:
	for ang in [0.0, 45.0, 90.0]:
		var got: Dictionary
		var tag: String
		if fused:
			got = await _hook("zephyrak", ang, false)
			tag = "Fused Dredge hook at %d deg" % int(ang)
		else:
			got = await _hook("pebbit", ang, true)
			tag = "Dredge hook, own Boki in the path, %d deg" % int(ang)
		var shape_ok := int(got["grapples"]) >= 1 and float(got["dev"]) <= 0.5 and float(got["front_miss"]) <= 1.0
		var form_ok := bool(got["fused"]) if fused else true
		ok(tag + ": pulled straight to the body", shape_ok and form_ok,
				"fused %s grapples %d dev %.2f front_miss %.2f" % [
					got["fused"], got["grapples"], got["dev"], got["front_miss"]])

## Every Fused form against Dredge's pull: same landing as unfused.
func _fused_sweep() -> void:
	for sp in ["zephyrak", "puddlet", "cairnback", "pebbit"]:
		var got: Dictionary = await _hook(sp, 45.0, false)
		ok("Fused (%s) Dredge hook: straight to the live body" % sp,
				int(got["grapples"]) >= 1 and float(got["dev"]) <= 0.5 and float(got["front_miss"]) <= 1.0,
				"form %s dev %.2f front_miss %.2f" % [got["fused"], got["dev"], got["front_miss"]])

## The grammar's "from the caster" and "to the caster" (a push, a pull) is YOU, not your Boki standing off to one side.
func _push_anchor() -> void:
	for arch in ["archer", "dredge", "juggernaut", "ashwick", "mage", "bulwark", "dolm", "thief", "rimewright"]:
		var r: Array = ak.setup(arch, 6.0, "pebbit", false)
		var m: Match = r[0]
		var P: Hunter = r[1]
		var T: Hunter = r[2]
		var home: Vector3 = r[4]
		_park(P.kin, home + Vector3(3.0, 0, 2.5))
		var c: Dictionary = P.ak.cx("rmb", "x", T.pos)
		var from: Vector3 = KinExec._point("caster", c, T.pos)
		var off := Vector2(from.x - P.pos.x, from.z - P.pos.z).length()
		ok("%s: a push or pull from the caster starts at you, Boki out" % arch, off < 0.01, "%.2f m off" % off)
		await ak.done(m)
