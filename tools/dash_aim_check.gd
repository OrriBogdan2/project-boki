extends RefCounted
## --dash-aim-check (item 109): every ranged Hunter's primary across its dash. Dash east with LMB held and the cursor
## north: where the rounds go, whether the body turns to the aim, and how long the rounds stop. A hero whose dash row
## fires LMB keeps its body on the cursor (ArchKit.aims_in_dash); a "buffer" row sends no round in the dash, and the
## first one after it goes along the live aim. Nobody's aim stays locked to the dash.
## Steady part (feel-aim-steady): the cursor held still on screen 15 m out while the view moves (a dash, a 10 m
## knock), through the real frame (Match._process): every round must leave on the line to the reticle's world point
## as that frame's camera shows it, as in the source. Aim taken before the camera moved trails it by a frame.

const DT := 1.0 / 60.0
const FIRES := ["gunslinger", "thief", "rimewright"]      # LMB goes mid-dash and the body stays on the aim
const FAN_DEG := 25.0        # a round's widest allowed miss of the cursor (the widest shotgun fan, the widest sway)
const RANGED := ["gunslinger", "thief", "rimewright", "ostra", "archer", "mage", "ashwick", "tender", "dredge", "dolm"]

const STEADY := ["gunslinger", "archer", "mage", "rimewright"]      # Vex, Lace (on the release), Sparkle, Neve
const STEADY_AT := 15.0      # m, how far out the reticle sits
const STEADY_M := 0.25       # m, the widest a round may pass the reticle at STEADY_AT
const KNOCK := 23.5          # the shove east (Ent.impulse), about a 10 m knock on a medium body

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("DASHAIM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _match(main: Node, arch: String) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({
		"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
		"cls": Arch.weight(arch), "arch": arch, "weapon": Arch.signature(arch),
	})
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	var w: World = m.world
	var cx := int(floor(P.pos.x))
	var cz := int(floor(P.pos.z))
	var home_i: int = w.idx(cx, cz)
	var level: int = int(w.level[home_i]) if w.kind[home_i] != World.T_VOID else 0
	for dz in range(-24, 25):
		for dx in range(-24, 25):
			if not w.inb(cx + dx, cz + dz):
				continue
			var i: int = w.idx(cx + dx, cz + dz)
			w.kind[i] = World.T_GROUND
			w.level[i] = level
			w.island[i] = w.island[home_i]
			w.walls.erase(i)
			w.props.erase(i)
			w.stairs.erase(i)
	P.teleport(Vector3(cx + 0.5, level * World.LEVEL, cz + 0.5))
	P.set_arch(arch)
	P.unlock_all()
	for other in m.hunters:
		if other != P:
			other.ctrl = "idle"
			other.teleport(P.pos + Vector3(40, 0, 40))
	for i in 20:
		m.step(DT)
	return m

## Aim north of her wherever she is now, as a player holding the cursor out there would.
func _aim_north(P: Hunter) -> void:
	P.inp["aim"] = P.pos + Vector3(0, 0.9, -8)

func _deg(a: Vector2, b: Vector2) -> float:
	return absf(rad_to_deg(a.angle_to(b)))

func _face_dir(P: Hunter) -> Vector2:
	return Vector2(-sin(P.face), -cos(P.face))

## {rounds, worst (deg off the aim), face (the body's worst, deg), gap (longest s between rounds), dash_s, dash_rounds}
func probe(m: Match, in_air: bool) -> Dictionary:
	var P: Hunter = m.player
	var out := {"rounds": 0, "worst": 0.0, "face": 0.0, "gap": 0.0, "dash_s": 0.0, "dash_rounds": 0}
	var north := Vector2(0, -1)
	var clock := {"t": 0.0, "last": -1.0}
	var count := func(dashing: bool):
		var n := 0
		for s in m.shots:
			if s["by"] == P and not s.has("_seen"):
				s["_seen"] = true
				n += 1
				out["rounds"] = int(out["rounds"]) + 1
				out["worst"] = maxf(float(out["worst"]), _deg(s["vel"] as Vector2, north))
				if dashing:
					out["dash_rounds"] = int(out["dash_rounds"]) + 1
		if n > 0:
			if float(clock["last"]) >= 0.0:
				out["gap"] = maxf(float(out["gap"]), float(clock["t"]) - float(clock["last"]))
			clock["last"] = clock["t"]
	P.inp["move"] = Vector2.ZERO
	P.inp["fire"] = true
	for i in 45:
		_aim_north(P)
		P.ammo = int(P.wpn.get("mag", 30))
		m.step(DT)
		clock["t"] = float(clock["t"]) + DT
		count.call(false)
	if in_air:
		P.do_jump()
		for i in 9:
			_aim_north(P)
			m.step(DT)
			clock["t"] = float(clock["t"]) + DT
			count.call(false)
	P.dashes = P.max_dashes()
	P.ex_cd = 0.0
	P.inp["move"] = Vector2(1, 0)
	_aim_north(P)
	P.inp["dash_down"] = true
	P.do_dash()
	var i := 0
	while i < 75:
		_aim_north(P)
		P.ammo = int(P.wpn.get("mag", 30))
		P.inp["dash_down"] = i < 30
		m.step(DT)
		clock["t"] = float(clock["t"]) + DT
		var dashing: bool = P.roll_t > 0.0 or (P.ak != null and P.ak.in_dash())
		count.call(dashing)
		if dashing:
			out["dash_s"] = float(out["dash_s"]) + DT
			if i >= 8:         # (the body has had 8 steps to turn)
				out["face"] = maxf(float(out["face"]), _deg(_face_dir(P), north))
		i += 1
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	return out

## The mouse over `p` (a world point), as the OS would move it (in window pixels, which the content scale can stretch).
func _cursor(m: Match, p: Vector3) -> void:
	var at := m.get_viewport().get_screen_transform() * m.cam.unproject_position(p)
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	Input.parse_input_event(mv)
	Input.flush_buffered_events()

## The cursor still on screen 15 m north; on one frame the move (`how`: dash or knock east) and the shot (a press, or
## Lace's release) together, then 40 frames of fire held. The miss is of the aim each round left on (the weapon's
## own spread or bow comes after it). {err (m off the reticle at STEADY_AT, worst), rounds,
## cam (the camera's biggest step in one frame, m), moved (m)}
func steady(m: Match, how: String) -> Dictionary:
	var P: Hunter = m.player
	var out := {"err": 0.0, "rounds": 0, "cam": 0.0, "moved": 0.0}
	m.acc = 0.0
	var release := P.wpn.has("draw")
	for i in 60:
		_cursor(m, P.pos + Vector3(0, 0.95, -STEADY_AT))
		if release and i == 20:
			Input.action_press("fire")
		m._process(DT)
	var start := P.pos
	if release:
		Input.action_release("fire")
	else:
		Input.action_press("fire")
	P.dashes = P.max_dashes()
	P.ex_cd = 0.0
	if how == "dash":
		P.inp["move"] = Vector2(1, 0)
		P.do_dash()
	else:
		P.impulse(Vector2(KNOCK, 0) * P.mass())
	for s in m.shots:
		s["_seen"] = true
	for i in 40:
		var was := m.cam.global_position
		P.ammo = int(P.wpn.get("mag", 30))
		P.fire_cd = 0.0          # a round every frame the gun can, so each frame's camera step is measured
		m._process(DT)
		out["cam"] = maxf(float(out["cam"]), was.distance_to(m.cam.global_position))
		var r: Vector3 = m._mouse_aim()
		for s in m.shots:
			if s["by"] != P or s.has("_seen"):
				continue
			s["_seen"] = true
			var o: Vector3 = s["start"]
			var aim: Vector3 = P.inp["aim"]
			var to := Vector2(r.x - o.x, r.z - o.z)
			var miss := STEADY_AT * absf(sin(Vector2(aim.x - o.x, aim.z - o.z).angle_to(to)))
			out["err"] = maxf(float(out["err"]), miss)
			out["rounds"] = int(out["rounds"]) + 1
	Input.action_release("fire")
	out["moved"] = Vector2(P.pos.x - start.x, P.pos.z - start.z).length()
	return out

func run(main: Node) -> void:
	Save.no_write = true
	for arch in STEADY:
		for how in ["dash", "knock"]:
			var m := _match(main, arch)
			var r := steady(m, how)
			var tag := "%s %s" % [arch, how]
			var row := "DASHAIM steady %-16s rounds %2d  moved %4.1fm  camera step %.2fm  off reticle %.3fm at %.0fm"
			print(row % [tag, r["rounds"], r["moved"], r["cam"], r["err"], STEADY_AT])
			ok(int(r["rounds"]) >= 1 and float(r["err"]) <= STEADY_M, "%s: rounds leave on the reticle" % tag)
			m.queue_free()
			await main.get_tree().process_frame
	for arch in RANGED:
		for in_air in [false, true]:
			var m := _match(main, arch)
			var r := probe(m, in_air)
			var tag := "%s %s" % [arch, "air" if in_air else "ground"]
			var row := "DASHAIM %-18s rounds %2d (in dash %2d) off aim %5.1f  body off aim %5.1f  gap %.2fs  dash %.2fs"
			print(row % [tag, r["rounds"], r["dash_rounds"], r["worst"], r["face"], r["gap"], r["dash_s"]])
			ok(float(r["worst"]) <= FAN_DEG, "%s: rounds track the cursor" % tag)
			if arch in FIRES and float(r["dash_s"]) > 0.0:
				var on_aim: bool = int(r["dash_rounds"]) >= 1 and float(r["face"]) <= 5.0
				ok(on_aim, "%s: fires in the dash, body on the aim" % tag)
			m.queue_free()
			await main.get_tree().process_frame
	print("DASHAIM DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
