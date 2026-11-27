extends RefCounted
## --knock-chain-check: a Hunter already flying from a knock is knocked again (docs/decisions/0022, the rule
## in Displace.knock_speed / Displace.knocked). The newer knock takes over: its speed replaces the old flight
## (the distance it covers matches the same knock on a standing body), it ends a reel, and it can wall-stun
## even right after an earlier wall slam. Three pairs from the kits' own numbers, through the real hit path
## (Hunter.hurt with the kit's kb and lift) and the real reel (Displace.tow with Grimble's params):
##   Kael's Finishing Slam (rmb.slam.push) -> Albert's Shield Charge shove (dash.charge_kb, lift 2.5)
##   Grimble's Abyssal Hand reel (rmb pull_speed/gap/pull_max) -> Sparkle's full Storm Rod (rmb.coil.push[1])
##   Vex's Burr Charge (rmb.burr.push, lift 2) -> Vex's Burr Charge
## Each pair runs twice: on open ground (distance after the second knock vs that knock alone) and with a
## wall in the second knock's way (wall stun). Lines: KNOCKCHAIN PASS|FAIL <what>, then the table.

const DT := 1.0 / 60.0
const MID := 0.15  # s into the first knock's flight when the second lands
const SETTLE := 1.5  # s to let the body come to rest
const DIST_TOL := 0.3  # m: the chained knock covers the solo knock's distance within this (the first knock's
# leftover lift moves the landing a few cm)
const SLAM_SPEED := 8.0  # m/s: Hunter's wall-slam threshold; a slower knock into a wall only stops
const SPD_TOL := 0.05  # m/s: right after the second knock its speed is the knock's own

var main: Node
var ak = null
var fails := 0
var n := 0
var rows: Array = []


func ok(what: String, cond: bool, info := "") -> void:
	n += 1
	print("KNOCKCHAIN %-66s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1


func run(main_node: Node) -> void:
	main = main_node
	ak = load("res://tools/archetype_check.gd").new()
	ak.main = main
	var r: Array = ak.setup("dredge", 6.0, "", false)
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t: Hunter = r[2]
	var home: Vector3 = r[4]
	var open := home + Vector3(2.5, 0, -8.5)
	var walled := home + Vector3(10.5, 0, 3.5)
	_wall(m.world, walled)
	var kael := float(Arch.def("juggernaut")["rmb"]["slam"]["push"])
	var albert := float(Arch.def("bulwark")["dash"]["charge_kb"])
	var sparkle := float((Arch.def("mage")["rmb"]["coil"]["push"] as Array)[1])
	var vex := float(Arch.def("gunslinger")["rmb"]["burr"]["push"])
	var rd: Dictionary = Arch.def("dredge")["rmb"]
	var reel_gap := p_v.r + t.r + float(rd["stop_gap"])
	var reel := {
		"mode": "haul",
		"spd": float(rd["pull_speed"]),
		"gap": reel_gap,
		"dur": float(rd["pull_max"]),
		"swing": DredgeKit.SWING,
		"stun": 0.2
	}
	var side := Vector2(0, 1)  # every second knock goes +z (toward the wall on the walled strip)
	var pairs := [
		["Kael Finishing Slam -> Albert Shield Charge", _hit(Vector2(1, 0) * kael, -1.0), _hit(side * albert, 2.5)],
		["Grimble reel -> Sparkle Storm Rod", reel, _hit(side * sparkle, -1.0)],
		["Vex Burr Charge -> Vex Burr Charge", _hit(Vector2(1, 0) * vex, 2.0), _hit(side * vex, 2.0)],
	]
	for p in pairs:
		var solo: Vector3 = _solo(m, p_v, t, open, p[2])
		var chain: Dictionary = await _chain(m, p_v, t, open, p[1], p[2])
		var into: Dictionary = await _chain(m, p_v, t, walled, p[1], p[2])
		var want: Vector2 = p[2]["kb"]
		ok(
			"%s: right after it, the speed is the newer knock's" % p[0],
			(chain["v"] as Vector2).distance_to(want) < SPD_TOL,
			"%s want %s" % [chain["v"], want]
		)
		var gap := (chain["moved"] as Vector3).distance_to(solo)
		ok(
			"%s: covers the solo knock's distance (replace, no add, no immunity)" % p[0],
			gap < DIST_TOL,
			(
				"%.2f m vs solo %.2f m (off %.2f)"
				% [Vector2(chain["moved"].x, chain["moved"].z).length(), Vector2(solo.x, solo.z).length(), gap]
			)
		)
		if want.length() > SLAM_SPEED:
			ok(
				"%s: into a wall, the second knock wall-stuns" % p[0],
				int(into["slams"]) >= 1,
				"stun %.2f" % into["stun"]
			)
		if p[1].has("mode"):
			ok("%s: the knock ends the reel" % p[0], chain["tow_end"] == "knocked", String(chain["tow_end"]))
		rows.append(
			[
				p[0],
				Vector2(chain["moved"].x, chain["moved"].z).length(),
				Vector2(solo.x, solo.z).length(),
				absf(chain["moved"].x),
				int(into["slams"]) >= 1,
				into["stun"]
			]
		)
	_reel_takes_over(m, p_v, t, open, reel, _hit(side * sparkle, -1.0))
	await _lockout(m, p_v, t, walled, _hit(Vector2(1, 0) * vex, 2.0), _hit(side * vex, 2.0))
	await _stale_wallstun(m, p_v, t, walled, _hit(Vector2(1, 0) * kael, -1.0), _hit(side * albert, 2.5))
	print("KNOCKCHAIN TABLE | pair | after 2nd knock (m) | 2nd knock alone (m) | 1st knock's carry (m) | wall stun |")
	for w in rows:
		print(
			(
				"KNOCKCHAIN TABLE | %s | %.2f | %.2f | %.2f | %s |"
				% [w[0], w[1], w[2], w[3], "STUNNED %.2fs" % w[5] if w[4] else "none"]
			)
		)
	print("KNOCKCHAIN DONE, %d checks, failures: %d" % [n, fails])
	await ak.done(m)
	main.get_tree().quit(1 if fails > 0 else 0)


static func _hit(kb: Vector2, lift: float) -> Dictionary:
	var o := {"src": "abil", "ab": "utility", "kb": kb}
	if lift >= 0.0:
		o["lift"] = lift
	return o


## Wall A: a column 2 m along +x of the walled spot; wall B: a row 1 m along +z (the second knocks' way: close
## enough that Sparkle's 9 m/s rod still meets it over the 8 m/s wall-slam speed).
func _wall(w: World, at: Vector3) -> void:
	var wk: PackedByteArray = w.kind
	var ax := int(floor(at.x)) + 2
	var bz := int(floor(at.z)) + 1
	for d in range(-3, 4):
		wk[w.idx(ax, int(floor(at.z)) + d)] = World.T_BLOCK
		wk[w.idx(int(floor(at.x)) + d - 2, bz)] = World.T_BLOCK
	w.kind = wk


func _place(m: Match, p: Hunter, t: Hunter, at: Vector3) -> void:
	ak.fresh(t)
	t.wallstun = 0.0
	t.wslam_t = 0.0
	t.teleport(at)
	p.teleport(at + Vector3(-6.0, 0, 0))
	p.vel = Vector3.ZERO
	ak.step(m, 0.3)
	ak.fresh(t)


## Starts a knock or a reel: a hit through Hunter.hurt, or a tow through Displace.
func _apply(m: Match, p: Hunter, t: Hunter, what: Dictionary) -> Dictionary:
	if what.has("mode"):
		return m.displace.tow(t, p, what.duplicate())
	t.hurt(1.0, p, what.duplicate())
	return {}


func _solo(m: Match, p: Hunter, t: Hunter, at: Vector3, second: Dictionary) -> Vector3:
	_place(m, p, t, at)
	var from := t.pos
	_apply(m, p, t, second)
	ak.step(m, SETTLE)
	return t.pos - from


## The first knock, MID s of flight, the second; what the second did from there.
func _chain(m: Match, p: Hunter, t: Hunter, at: Vector3, first: Dictionary, second: Dictionary) -> Dictionary:
	_place(m, p, t, at)
	var tow := _apply(m, p, t, first)
	ak.step(m, MID)
	var from := t.pos
	_apply(m, p, t, second)
	var out := {"v": Vector2(t.vel.x, t.vel.z), "tow_end": String(tow.get("end", "")), "slams": 0, "stun": 0.0}
	await _watch(m, t, out)
	out["moved"] = t.pos - from
	return out


## Steps SETTLE s, counting wall slams (wslam_t rising) and the longest stun.
func _watch(m: Match, t_v: Hunter, out: Dictionary) -> void:
	var prev := t_v.wslam_t
	var t := 0.0
	while t < SETTLE:
		m.step(DT)
		t += DT
		if t_v.wslam_t > prev:
			out["slams"] = int(out["slams"]) + 1
		prev = t_v.wslam_t
		out["stun"] = maxf(float(out["stun"]), t_v.stun_t)
	await main.get_tree().process_frame


## The other order: a reel starting on a knocked body takes over its flight.
func _reel_takes_over(m: Match, p: Hunter, t: Hunter, at: Vector3, reel: Dictionary, knock: Dictionary) -> void:
	_place(m, p, t, at)
	_apply(m, p, t, knock)
	ak.step(m, 0.05)
	var tow := _apply(m, p, t, reel)
	var v := Vector2(t.vel.x, t.vel.z)
	ok(
		"Sparkle Storm Rod -> Grimble reel: the reel takes over the knock's flight",
		v.length() < 0.01 and t.knock_t == 0.0,
		"v %.2f knock_t %.2f" % [v.length(), t.knock_t]
	)
	ak.step(m, float(reel["dur"]))
	ok(
		"Sparkle Storm Rod -> Grimble reel: the reel still lands him at the arm",
		String(tow.get("end", "")) == "arrived",
		String(tow.get("end", ""))
	)


## Two Vex knocks, the first into wall A (a slam), the second 0.4 s later into wall B: no slam lockout.
func _lockout(m: Match, p: Hunter, t_v: Hunter, at: Vector3, first: Dictionary, second: Dictionary) -> void:
	_place(m, p, t_v, at)
	var out := {"slams": 0, "stun": 0.0}
	_apply(m, p, t_v, first)
	var prev := t_v.wslam_t
	var t := 0.0
	while t < 0.4:
		m.step(DT)
		t += DT
		if t_v.wslam_t > prev:
			out["slams"] = int(out["slams"]) + 1
		prev = t_v.wslam_t
	var first_slams := int(out["slams"])
	_apply(m, p, t_v, second)
	await _watch(m, t_v, out)
	ok(
		"Vex -> Vex, both into walls: each knock wall-stuns (no lockout after the first slam)",
		first_slams == 1 and int(out["slams"]) == 2,
		"slams %d then %d" % [first_slams, out["slams"]]
	)


## A first knock carrying a longer wall stun (Shoulder Charge's 1.2 s) doesn't lend it to the second: the second's
## slam stuns what the same chain without it does (its own impact speed, KnockWall.slam_stun; decision 0179).
func _stale_wallstun(m: Match, p: Hunter, t: Hunter, at: Vector3, first: Dictionary, second: Dictionary) -> void:
	var plain: Dictionary = await _chain(m, p, t, at, first, second)
	var long := first.duplicate()
	long["wallstun"] = 1.2
	var out: Dictionary = await _chain(m, p, t, at, long, second)
	ok(
		"a first knock's longer wall stun is the first knock's: the second's slam stuns its own length",
		int(out["slams"]) >= 1 and absf(float(out["stun"]) - float(plain["stun"])) < 0.05 and float(out["stun"]) < 1.1,
		"stun %.2f, without the long one %.2f" % [out["stun"], plain["stun"]]
	)
