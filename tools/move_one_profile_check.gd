extends RefCounted
## One shared movement profile (DECISIONS 11-11): a section of --move-feel-check. The same hunter (ARCH) runs the
## same scripted inputs in every mode the game ships (Expedition trio and solo, the Arena, the Training Grounds,
## the duel ring, the garden) and each mode must read the numbers in content/rules/hunter_move.json and
## tuning.json: the loaded tables equal the files, every hunter's run speed and accel are the file's row, and
## run, brake, jump, air accel, glide and dash measure the same as the Expedition solo and as the file says.
## Prints "MFEEL ok|FAIL <what>" lines through the host check and adds to its failure count.

const ARCH := "bulwark"      # a hero with its own row (4.85 m/s, accel 47), so a mode reading "default" shows
const TOL := 0.03            # m or m/s: the same inputs through the same code agree to well under a step
const DT := 1.0 / 60.0
const SOLO := {"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": true}
const MODES := ["expedition solo", "expedition trio", "arena", "training grounds", "duel ring", "garden"]

var mfc            # the host move_feel_check: its helpers (_reset, _steps, _flat_spot) and its fail count
var main: Node

func _init(host, scene: Node) -> void:
	mfc = host
	main = scene

func run() -> void:
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/hunter_move.json"))
	var tune: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/tuning.json"))
	_tables(rules, tune)
	var base := {}
	for mode in MODES:
		var got: Dictionary = await _garden() if mode == "garden" else await _match_mode(mode, rules)
		if mode == "expedition solo":
			base = got
			_anchor(got, rules)
		else:
			_same(mode, got, base)

func _tables(rules: Dictionary, tune: Dictionary) -> void:
	var p: Dictionary = rules["physics"]
	var a: Dictionary = tune["air"]
	var g: Dictionary = tune["glide"]
	mfc.ok(HunterMove.brake_decel == float(p["brake"]) and HunterMove.ground_friction == float(p["ground_friction"])
			and HunterMove.glide_accel == float(p["glide_accel"]) and HunterMove.dive_vy == float(p["dive_vy"]),
			"one profile: HunterMove holds hunter_move.json physics (brake, friction, glide_accel, dive_vy)")
	mfc.ok(Loco.air_accel == float(a["accel"]) and Loco.air_counter == float(a["counter"])
			and Loco.air_drag == float(a["drag"]),
			"one profile: Loco air accel/counter/drag = tuning.json air")
	mfc.ok(Loco.glide_turn == float(g["turn"]) and Loco.glide_brake == float(g["brake"])
			and Loco.glide_catch == float(g["catch"]),
			"one profile: Loco glide turn/brake/catch = tuning.json glide")
	mfc.ok(Loco.dash_jump_keep == float(tune["dash"]["jump_keep"]),
			"one profile: Loco dash jump keep = tuning.json dash")

## Expedition solo against the files: the run is the arch's row, the jump apex is v^2/2g.
func _anchor(got: Dictionary, rules: Dictionary) -> void:
	var row: Dictionary = rules[ARCH]
	mfc.ok(absf(got["run"] - float(row["speed"])) < TOL,
			"one profile: %s runs %.2f m/s = hunter_move.json %.2f" % [ARCH, got["run"], row["speed"]])
	var apex := Hunter.JUMP_V * Hunter.JUMP_V / (2.0 * Hunter.H_GRAV)
	mfc.ok(absf(got["apex"] - apex) < 0.15, "one profile: jump apex %.2f m ~ v^2/2g %.2f" % [got["apex"], apex])
	mfc.ok(absf(got["glide_v"] - Hunter.GLIDE_SPEED) < 0.3,
			"one profile: glide cruise %.2f m/s ~ %.1f" % [got["glide_v"], Hunter.GLIDE_SPEED])

## One mode's numbers against the Expedition solo's, key by key.
func _same(mode: String, got: Dictionary, base: Dictionary) -> void:
	var diff := []
	for k in base:
		if not got.has(k) or absf(float(got[k]) - float(base[k])) > TOL:
			diff.append("%s %s vs %.3f" % [k, "%.3f" % got[k] if got.has(k) else "none", base[k]])
	mfc.ok(diff.is_empty(), "one profile: %s = expedition solo (run, brake, air, jump, glide, dash) %s"
			% [mode, ", ".join(diff)])

# ---------------------------------------------------------------- the match modes
func _match_mode(mode: String, rules: Dictionary) -> Dictionary:
	Save.no_write = true
	Save.d = Save.fresh()
	var o: Dictionary = SOLO.duplicate()
	match mode:
		"expedition trio": o["squad"] = 3
		"arena": o = Match.arena_opts(ARCH)
		"training grounds":
			o = {"training": true, "practice": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9,
					"seed": 4242, "no_drop": true}
		"duel ring": o = Match.duel_opts()
	var m := Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	if P.arch != ARCH: P.reclass(Arch.weight(ARCH), ARCH)
	var row: Dictionary = rules[ARCH]
	var bad := []
	for h in m.hunters:
		var r: Dictionary = rules.get(h.arch, rules["default"])
		if h.base_speed != float(r["speed"]) or h.ground_accel != float(r["accel"]):
			bad.append("%s %s %.2f/%.0f" % [h.pname, h.arch, h.base_speed, h.ground_accel])
	mfc.ok(bad.is_empty(), "one profile: %s: every hunter has its hunter_move.json row %s" % [mode, ", ".join(bad)])
	mfc.ok(P.base_speed == float(row["speed"]) and P.ground_accel == float(row["accel"]),
			"one profile: %s: the player is %s's row" % [mode, ARCH])
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		if h != P:
			h.teleport(Vector3(-500, 50, -500))
			h.out = true
	if P.kin: (P.kin as Kin).stow()
	P.ctrl = "local"
	P.unlock_all()
	m.biomes = null      # the map's ice and wind are terrain, not a mode's numbers
	mfc.m = m
	mfc.w = m.world
	mfc.P = P
	var spot := _match_spot(m)
	var got := _measure_match(m, P, spot)
	m.queue_free()
	await main.get_tree().process_frame
	return got

## Open ground along +x: 6 m of flat floor, a body wide, nothing to block, push or lift the runs.
func _match_spot(m: Match) -> Vector3:
	var w := m.world
	var props := []      # the practice rooms' dummies and props stand on the floor without being blocks
	for n in m.get_children():
		if n is Node3D and n != m.player: props.append(Vector2(n.global_position.x, n.global_position.z))
	for k in 6000:
		var g: Vector3 = w.random_ground()
		var clear := not w.is_void(g.x, g.z)
		for i in 13:
			for z in [-0.6, 0.0, 0.6]:
				var x := g.x + i * 0.5
				clear = clear and not w.is_void(x, g.z + z) and not w.is_block(x, g.z + z) \
						and absf(w.ground_at(x, g.z + z) - g.y) < 0.01
		for pp in props:
			clear = clear and (pp.x < g.x - 1.5 or pp.x > g.x + 8.0 or absf(pp.y - g.z) > 1.5)
		if clear: return Vector3(floorf(g.x) + 0.5, g.y, floorf(g.z) + 0.5)
	mfc.ok(false, "one profile: no 6 m open floor along +x")
	return w.random_ground()

func _hv(P: Hunter) -> Vector2:
	return Vector2(P.vel.x, P.vel.z)

func _measure_match(m: Match, P: Hunter, f: Vector3) -> Dictionary:
	var out := {}
	var right := Vector2(1, 0)
	mfc._reset(f)
	P.inp["move"] = right
	mfc._steps(3)
	out["run_3"] = _hv(P).length()
	mfc._steps(20)
	out["run"] = _hv(P).length()
	P.inp["move"] = Vector2.ZERO
	var x0 := P.pos.x
	mfc._steps(60)
	out["stop_m"] = P.pos.x - x0
	mfc._reset(f)
	P.inp["jump"] = true
	var apex := 0.0
	for i in 60:
		m.step(DT)
		P.inp["jump"] = false
		apex = maxf(apex, P.pos.y - f.y)
	out["apex"] = apex
	mfc._reset(f + Vector3(0, 3, 0), false)
	P.vel = Vector3(-3, 0, 0)
	P.inp["move"] = right
	mfc._steps(18)
	out["air_vx"] = P.vel.x
	mfc._reset(f + Vector3(0, 6, 0), false)
	mfc._steps(1)
	P.inp["jump"] = true
	P.inp["glide"] = true
	P.inp["glide_btn"] = true
	m.step(DT)
	P.inp["jump"] = false
	P.inp["move"] = right
	mfc.ok(P.gliding, "one profile: the glider opens in the air (match)")
	mfc._steps(36)
	out["glide_v"] = _hv(P).length()
	out["glide_vy"] = P.vel.y
	mfc._reset(f)
	P.dash_with({"speed": 16.0, "time": 0.15, "dir": right})
	x0 = P.pos.x
	for i in 18:
		m.step(DT)
		if i == 4: out["dash_mid"] = _hv(P).length()
	out["dash_m"] = P.pos.x - x0
	return out

# ---------------------------------------------------------------- the garden
## The farm avatar (Home): the same inputs through its own body, which shares Loco and HunterMove.
func _garden() -> Dictionary:
	Save.no_write = true
	Save.d = Save.fresh()
	var pk := Save.new_kin("zapple", "Pip")
	Save.d["roster"].append(pk)
	Save.d["active"] = pk["uid"]
	Save.d["tutorial"]["home"] = true
	Save.d["tutorial"]["day1_done"] = true
	Save.d["arch"] = ARCH
	Econ.ensure()
	var hm = load("res://scripts/home/home.gd").new()
	main.add_child(hm)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	while hm.building: await main.get_tree().process_frame
	hm.set_process(false)
	var at := _garden_spot(hm)
	var out := {}
	var dir := Vector2(1, 0)
	_garden_reset(hm, at)
	_hold(Vector2(1, 0))
	await _gsteps(hm, 3)
	out["run_3"] = Vector2(hm.pvel.x, hm.pvel.z).length()
	await _gsteps(hm, 20)
	var v := Vector2(hm.pvel.x, hm.pvel.z)
	out["run"] = v.length()
	dir = v.normalized()
	_hold(Vector2.ZERO)
	var p0: Vector3 = hm.ppos
	await _gsteps(hm, 60)
	out["stop_m"] = (hm.ppos - p0).length()
	_garden_reset(hm, at)
	Input.action_press("jump")
	var apex := 0.0
	for i in 60:
		hm._move_player(DT)
		await main.get_tree().process_frame
		Input.action_release("jump")
		apex = maxf(apex, hm.py - at.y)
	out["apex"] = apex
	_garden_reset(hm, at, 3.0)
	hm.pvel = Vector3(-3 * dir.x, 0, -3 * dir.y)
	_hold(Vector2(1, 0))
	await _gsteps(hm, 18)
	out["air_vx"] = Vector2(hm.pvel.x, hm.pvel.z).dot(dir)
	_garden_reset(hm, at, 6.0)
	_hold(Vector2.ZERO)
	await _gsteps(hm, 1)
	Input.action_press("glide")
	hm._move_player(DT)
	await main.get_tree().process_frame
	Input.action_release("glide")
	Input.action_press("jump")
	_hold(Vector2(1, 0))
	await _gsteps(hm, 36)
	Input.action_release("jump")
	mfc.ok(hm.gliding, "one profile: the glider opens in the air (garden)")
	out["glide_v"] = Vector2(hm.pvel.x, hm.pvel.z).length()
	out["glide_vy"] = hm.pvy
	_hold(Vector2.ZERO)
	_garden_reset(hm, at)
	hm.start_dash(dir, 16.0, 0.15)
	p0 = hm.ppos
	for i in 18:
		hm._move_player(DT)
		await main.get_tree().process_frame
		if i == 4: out["dash_mid"] = Vector2(hm.pvel.x, hm.pvel.z).length()
	out["dash_m"] = (hm.ppos - p0).length()
	hm.queue_free()
	return out

func _hold(dir: Vector2) -> void:
	for a in ["left", "right", "up", "down"]: Input.action_release(a)
	if dir.x > 0.1: Input.action_press("right", dir.x)
	if dir.x < -0.1: Input.action_press("left", -dir.x)

func _gsteps(hm, n: int) -> void:
	for i in n:
		hm._move_player(DT)
		await main.get_tree().process_frame

func _garden_reset(hm, at: Vector3, up := 0.0) -> void:
	hm.ppos = Vector3(at.x, 0, at.z)
	hm.py = at.y + up
	hm.pvy = 0.0
	hm.pvel = Vector3.ZERO
	hm.gliding = false
	hm.dash_t = 0.0

## Open ground 8 m all round, nearest the spawn: flat (the same height) and nothing to occupy.
func _garden_spot(hm) -> Vector3:
	for k in 400:
		var c: Vector3 = hm.ppos
		if k > 0: c += Vector3(randf_range(-30, 30), 0, randf_range(-30, 30))
		var g: float = hm._ground_h(c.x, c.z)
		var clear: bool = g > World.VOID + 1.0
		for i in 16:
			for d in [3.0, 6.0, 8.0]:
				var x: float = c.x + cos(TAU * i / 16.0) * d
				var z: float = c.z + sin(TAU * i / 16.0) * d
				clear = clear and absf(hm._ground_h(x, z) - g) < 0.01 and hm.world.occupy(x, z, 0.38, g, true) == 0.0
		if clear: return Vector3(c.x, g, c.z)
	mfc.ok(false, "one profile: garden has no open ground 8 m all round")
	return Vector3(hm.ppos.x, hm._ground_h(hm.ppos.x, hm.ppos.z), hm.ppos.z)
