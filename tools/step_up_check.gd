extends RefCounted
## --step-up-check: a running hunter walks over lips up to the step height (hunter_move.json
## physics.step_height) and does it smoothly: no body pop, no camera pop. Sable, Vex and Albert (light,
## medium, heavy) run at lips of 0.10 to 0.60 m in 0.05 m steps and at a terrace (World.LEVEL), head-on and
## at 45 degrees. Each try prints a STEPUP row: pass (over the lip) or stop, and whether the drawn body or
## the camera jumped more than half the lip in one frame (a pop). The lip is a standable rock (a Verbs wall
## with a "top", Tenzo's rocks): the ground, step and camera code it runs is the terrain's.

const DT := 1.0 / 60.0
const HEROES := {"thief": "Sable", "gunslinger": "Vex", "bulwark": "Albert"}
const LIP_MIN := 0.10
const LIP_MAX := 0.60
const LIP_STEP := 0.05
const FACE_AT := 1.5          # m ahead of the start where the lip's face stands
const LIP_DEPTH := 1.6        # m: half the rock's depth, so the hunter can stand fully on it
const RUN_STEPS := 90         # 1.5 s of running at most: the run ends once the hunter is past the face
const SETTLE_STEPS := 150     # 2.5 s standing first, so the camera has settled on the hunter
const POP_SHARE := 0.5        # one frame covering more than this share of the lip is a pop

var bad := 0
var m: Match
var w: World
var P: Hunter
var cam: CamRig
var rows := []                # the ones that failed a rule, for the summary

func ok(cond: bool, what: String) -> void:
	print("STEPUP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": true})
	m.set_process(false)
	w = m.world
	cam = m.cam
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	P = m.player
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		if h != P:
			h.teleport(Vector3(-500, 50, -500))
			h.out = true
	if P.kin: (P.kin as Kin).stow()
	P.ctrl = "local"
	P.unlock_all()
	var flat := _flat_spot(6.5)
	print("STEPUP step height %.2f m; flat %s" % [World.STEP, str(flat)])
	var lips := []
	for k in int(round((LIP_MAX - LIP_MIN) / LIP_STEP)) + 1:
		lips.append(LIP_MIN + LIP_STEP * k)
	lips.append(World.LEVEL)
	for arch in HEROES:
		P.reclass(Arch.weight(arch), arch)
		for ang in [0.0, 45.0]:
			var dir := Vector2(cos(deg_to_rad(ang)), sin(deg_to_rad(ang)))
			for lip in lips:
				var wall := _lip(flat, dir, lip)
				_judge(arch, ang, lip, _try(flat, dir, lip))
				w.dyn_walls.erase(wall)
				if is_instance_valid(wall["node"]): (wall["node"] as Node3D).queue_free()
	ok(rows.is_empty(), "every try passed the rules (%d broke them: %s)" % [rows.size(), ", ".join(rows)])
	print("STEP UP CHECK DONE, failures: ", bad)
	main.get_tree().quit()

## A standable rock `lip` metres tall across the run, its face FACE_AT ahead of `from`.
func _lip(from: Vector3, dir: Vector2, lip: float) -> Dictionary:
	var c := from + Vector3(dir.x, 0.0, dir.y) * (FACE_AT + LIP_DEPTH)
	var spec := {"length": 8.0, "time": 1e9, "move": true, "block": "all"}
	var wall: Dictionary = m.verbs.add_wall(P, Vector3(c.x, from.y, c.z), dir, spec, 1.0)
	wall["top"] = lip
	wall["th"] = LIP_DEPTH
	return wall

## Run from `from` along `dir` into a lip of `lip` metres. Returns {pass, body_pop, cam_pop} where the pops
## are the biggest one-frame rise of the drawn body and of the camera, as a share of the lip.
func _try(from: Vector3, dir: Vector2, lip: float) -> Dictionary:
	_reset(from)
	cam.snap(P.pos)
	for i in SETTLE_STEPS:
		cam.follow(P.render_pos(1.0), DT, false)
	P.render(DT, 1.0)
	var body_y := P.position.y
	var cam_y := cam.base.y
	var body_pop := 0.0
	var cam_pop := 0.0
	var cam_y0 := cam_y
	P.inp["move"] = dir
	var along := 0.0
	for i in RUN_STEPS:
		m.step(DT)
		P.render(DT, 1.0)
		cam.follow(P.render_pos(1.0), DT, false)
		body_pop = maxf(body_pop, P.position.y - body_y)
		cam_pop = maxf(cam_pop, cam.base.y - cam_y)
		body_y = P.position.y
		cam_y = cam.base.y
		along = Vector2(P.pos.x - from.x, P.pos.z - from.z).dot(dir)
		if along > FACE_AT + 0.6:
			break
	var up := P.pos.y >= from.y + lip - 0.02
	return {"pass": up and along > FACE_AT + 0.5, "body_pop": body_pop / lip, "cam_pop": cam_pop / lip,
		"cam_rise": cam.base.y - cam_y0}

## The rules: a lip up to the step height is walked over; nothing in the ladder pops the body or the camera.
func _judge(arch: String, ang: float, lip: float, r: Dictionary) -> void:
	var tag := "%s %2.0fdeg lip %.2f" % [HEROES[arch], ang, lip]
	var body_pop: bool = r["body_pop"] > POP_SHARE
	var cam_pop: bool = r["cam_pop"] > POP_SHARE
	var verdict := "pass" if r["pass"] else "STOP"
	var body_tag := " POP" if body_pop else ""
	var cam_tag := " POP" if cam_pop else ""
	print("STEPUP %-22s %s  body %3.0f%%/frame%s  cam %3.0f%%/frame%s (rose %.2f m)" % [tag, verdict,
		r["body_pop"] * 100.0, body_tag, r["cam_pop"] * 100.0, cam_tag, r["cam_rise"]])
	var must_pass := lip <= World.STEP + 1e-6 or is_equal_approx(lip, World.LEVEL)
	if (must_pass and not r["pass"]) or (r["pass"] and (body_pop or cam_pop)):
		rows.append(tag)

func _clear_inp() -> void:
	for k in ["sec", "sig", "ult", "util1", "util2", "util3", "util4", "gear1", "gear2", "glide", "glide_btn",
			"jump", "dash", "fire", "crouch", "throw", "reload", "skill", "shift"]:
		P.inp[k] = false
	P.inp["move"] = Vector2.ZERO

## A clean, standing hunter at p.
func _reset(p: Vector3) -> void:
	P.teleport(p)
	P.vel = Vector3.ZERO
	P.grounded = true
	P.out = false
	P.gone = false
	P.downed = false
	P.gliding = false
	P.dropping = false
	P.diving = false
	P.shot_down = false
	P.roll_t = 0.0
	P.knock_t = 0.0
	P.fly_t = 0.0
	P.stun_t = 0.0
	P.root_t = 0.0
	P.mantle_cd = 0.0
	P.air_t = 0.0
	P.step_vis = 0.0
	P.squash = 0.0
	P.pad = {}
	P.grap = {}
	P.lfloat = {}
	P.hp = P.max_hp
	_clear_inp()

## A spot with flat, open ground `r` metres all round (the move-feel check's rule).
func _flat_spot(r: float) -> Vector3:
	for k in 4000:
		var g: Vector3 = w.random_ground()
		var okk := not w.is_void(g.x, g.z) and not w.is_block(g.x, g.z)
		for i in 16:
			var a := TAU * i / 16.0
			for d in [r * 0.33, r * 0.66, r]:
				var x: float = g.x + cos(a) * d
				var z: float = g.z + sin(a) * d
				if w.is_void(x, z) or w.is_block(x, z) or absf(w.ground_at(x, z) - g.y) > 0.01:
					okk = false
		if okk:
			return Vector3(floor(g.x) + 0.5, g.y, floor(g.z) + 0.5)
	return w.random_ground()
