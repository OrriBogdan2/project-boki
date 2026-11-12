extends RefCounted
## --feel-golden-check [--update]: nothing may silently change how a Hunter moves.
## Every Hunter plays the same nine fixed input scripts (run, stop, jump, dash tap, dash hold, wall kick,
## double-press glide, dive, crouch walk) on the real match step at 60 Hz. Position (relative to the start)
## and velocity are recorded every 0.1 s into content/rules/feel_golden.json. The check replays them and fails
## if any sample is more than TOL_POS m or TOL_VEL m/s off. --update rewrites the golden (the commit message
## must say why the feel changed; see docs/MOVEMENT_FEEL.md). Never touches the save.
## Prints "FEELGOLD ok|FAIL ..." lines and "FEELGOLD DONE, failures: N".

const GOLDEN := "res://content/rules/feel_golden.json"
const TOL_POS := 0.05           # m, largest allowed position drift at any sample
const TOL_VEL := 0.1            # m/s, largest allowed velocity drift at any sample
const EVERY := 6                # sim steps per sample (0.1 s at 60 Hz)
const STEPS := 150              # sim steps per script (2.5 s)
const SETTLE := 30              # sim steps to land and settle before a script starts
const CLEAR := 20               # cells flattened each way round the start
const WALL_AT := 6              # cells east of the start where the wall begins
const WALL_UP := 5              # terraces high (too tall to climb, so the kick dance never tops it)
const DIVE_H := 60.0            # m above the ground the dive starts
const SCRIPTS := ["run", "stop", "jump", "dash_tap", "dash_hold", "wall_kick", "glide_double", "dive", "crouch_walk"]
const WEST := Vector2(-1, 0)
const EAST := Vector2(1, 0)

var bad := 0
var m: Match
var h: Hunter
var wall_x := 0.0       # world x of the wall face

func ok(cond: bool, what: String) -> void:
	print("FEELGOLD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var update := "--update" in OS.get_cmdline_user_args()
	var got := {}
	for arch in Arch.ORDER:
		_start(main, arch)
		got[arch] = {}
		for script in SCRIPTS:
			got[arch][script] = _record(script)
		m.queue_free()
		await main.get_tree().process_frame
	if update:
		_write(got)
	else:
		_compare(got)
	print("FEELGOLD DONE, failures: %d" % bad)
	main.get_tree().quit()

## A training match for one Hunter on a flat square with a tall wall to the east.
func _start(main: Node, arch: String) -> void:
	m = Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 1109, "no_drop": true,
		"cls": Arch.weight(arch), "arch": arch, "weapon": Arch.signature(arch)})
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	h = m.player
	h.set_arch(arch)
	h.unlock_all()
	for other in m.hunters:
		if other != h:
			other.ctrl = "idle"
			other.teleport(h.pos + Vector3(80, 0, 80))
	var w: World = m.world
	var hx := int(floor(h.pos.x))
	var hz := int(floor(h.pos.z))
	var hi: int = w.idx(hx, hz)
	var lv: int = int(w.level[hi])
	for dz in range(-CLEAR, CLEAR + 1):
		for dx in range(-CLEAR, CLEAR + 1):
			if not w.inb(hx + dx, hz + dz):
				continue
			var i: int = w.idx(hx + dx, hz + dz)
			w.kind[i] = World.T_GROUND
			w.level[i] = lv + (WALL_UP if dx >= WALL_AT and absi(dz) <= 3 else 0)
			w.island[i] = w.island[hi]
			w.stairs.erase(i)
			w.walls.erase(i)
			w.props.erase(i)
			w.bush.erase(i)
	h.teleport(Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5))
	wall_x = hx + WALL_AT
	_steps(SETTLE)

func _steps(n: int) -> void:
	for i in n:
		m.step(Match.DT)

## Back to a clean standing (or airborne) start at `at`, everything ready, then settled.
func _reset(at: Vector3, grounded: bool) -> void:
	h.hp = h.max_hp
	h.teleport(at)
	h.vel = Vector3.ZERO
	h.grounded = grounded
	h.roll_t = 0.0
	h.lfloat = {}
	h.gliding = false
	h.glide_fuel = 1.0
	h.glide_cd = 0.0
	h.knock_t = 0.0
	h.fly_t = 0.0
	h.stun_t = 0.0
	h.root_t = 0.0
	h.dropping = false
	h.last_gy = at.y
	h.air_t = 0.0 if grounded else 0.5
	h.wall_moves.land()
	h.wall_touch_t = 0.0
	h.dashes = h.max_dashes()
	h.ex_cd = 0.0
	for key in h.ak.cd:
		h.ak.cd[key] = 0.0
	h.ak.ch_rmb = float(h.ak.rmb_charges())
	for k in h.inp:
		if h.inp[k] is bool:
			h.inp[k] = false
	h.inp["move"] = Vector2.ZERO
	_steps(SETTLE)

## The keys held on step `i` of a script (the ground start is `at`, the wall's one is placed against it).
func _press(script: String, i: int) -> void:
	var inp: Dictionary = h.inp
	match script:
		"run":
			inp["move"] = WEST
		"stop":
			inp["move"] = WEST if i < 60 else Vector2.ZERO
		"jump":
			inp["move"] = WEST
			inp["jump"] = i == 10
		"dash_tap":
			inp["move"] = WEST
			inp["dash"] = i == 10
		"dash_hold":
			inp["move"] = WEST
			inp["dash"] = i >= 10 and i < 40
		"wall_kick":
			inp["move"] = EAST
			inp["jump"] = i == 6 or i == 40 or i == 70
		"glide_double":
			inp["move"] = WEST
			inp["jump"] = i == 6 or i >= 20
		"dive":
			inp["move"] = WEST
			inp["jump"] = true
			inp["glide"] = true
			inp["crouch"] = i >= 30
		"crouch_walk":
			inp["move"] = WEST
			inp["crouch"] = true

## One script's trace: [x, y, z, vx, vy, vz] every 0.1 s, position relative to the start.
func _record(script: String) -> Array:
	var ground: Vector3 = h.pos
	var start := Vector3(ground.x, ground.y, ground.z)
	if script == "wall_kick":
		start.x = wall_x - h.r - 1.0
	elif script == "dive":
		start.y += DIVE_H
	_reset(start, script != "dive")
	var trace := []
	for i in STEPS:
		_press(script, i)
		m.step(Match.DT)
		if (i + 1) % EVERY == 0:
			var d := h.pos - start
			trace.append([_r(d.x), _r(d.y), _r(d.z), _r(h.vel.x), _r(h.vel.y), _r(h.vel.z)])
	_reset(Vector3(ground.x, ground.y, ground.z), true)
	return trace

func _r(v: float) -> float:
	return snappedf(v, 0.001)

func _write(got: Dictionary) -> void:
	var out := {
		"doc": "Golden movement traces, one per Hunter and script (--feel-golden-check). Each sample is "
			+ "[x, y, z, vx, vy, vz] every 0.1 s: position in m relative to the start, velocity in m/s. "
			+ "Rewrite only with --update and say why in the commit (docs/MOVEMENT_FEEL.md).",
		"tol_pos_m": TOL_POS, "tol_vel_ms": TOL_VEL, "hunters": got}
	var f := FileAccess.open(GOLDEN, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "", false, true) + "\n")
	f.close()
	print("FEELGOLD wrote %s" % GOLDEN)

func _compare(got: Dictionary) -> void:
	var gold: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN)).get("hunters", {})
	for arch in Arch.ORDER:
		for script in SCRIPTS:
			var want: Array = gold.get(arch, {}).get(script, [])
			var have: Array = got[arch][script]
			var dp := 0.0
			var dv := 0.0
			var first := -1
			for k in mini(want.size(), have.size()):
				var a: Array = want[k]
				var b: Array = have[k]
				var ep := Vector3(a[0] - b[0], a[1] - b[1], a[2] - b[2]).length()
				var ev := Vector3(a[3] - b[3], a[4] - b[4], a[5] - b[5]).length()
				if first < 0 and (ep > TOL_POS or ev > TOL_VEL):
					first = k
				dp = maxf(dp, ep)
				dv = maxf(dv, ev)
			var note := ""
			if first >= 0:
				note = " (first off at %.1f s)" % ((first + 1) * 0.1)
			if want.size() != have.size():
				note += " (samples %d vs %d)" % [have.size(), want.size()]
			ok(first < 0 and want.size() == have.size() and not want.is_empty(),
				"%s %s: max drift %.3f m, %.3f m/s%s" % [arch, script, dp, dv, note])
