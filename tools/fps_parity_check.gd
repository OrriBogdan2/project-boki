extends RefCounted
## --fps-parity-check: the same input script gives the same hunter at 30, 60 and 144 fps and through a 20 ms hitch.
## Physics ticks at 60 Hz (Match.DT) inside Match._process, so only gameplay that reads the frame time would drift.
## Each frame this drives the real Match._process with that run's frame length (the tutorial-test option leaves the
## input to the script, as a player's keys are read once per frame), with presses landing on 1/30 s marks of sim time
## so every frame rate can press on the same tick. Script: dash, jump, glide 2 s, hold LMB 3 s, cast E.
## Compared against the 60 fps run: end position, jump apex, glide reach, dash length, swings, shots,
## flame ticks and the E cooldown end.

const HEROES := ["gunslinger", "juggernaut", "ashwick", "thief"]      # Vex, Kael, Cinder, Sparkle
const RUNS := [["30 fps", 30, 0.0], ["60 fps", 60, 0.0], ["144 fps", 144, 0.0], ["60 fps + 20 ms hitches", 60, 0.020]]
const BASE := 1                  # the run the others are measured against (60 fps)
const TOL := 0.02                # agreement allowed between runs (a fraction)
const HITCH_FIRST := 0.15       # s: the first hitch lands inside the dash
const HITCH_EVERY := 0.55        # s of sim time between 20 ms hitches (they land in every phase of the script)
const T_DASH := 0.5              # s: the script's marks
const T_JUMP := 1.0
const T_GLIDE := 1.5
const T_GLIDE_END := 3.5
const T_FIRE := 6.0
const T_FIRE_END := 9.0
const T_CAST := 9.5
const T_END := 12.0

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("FPSPAR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## A fresh match as `arch` on a flat, empty patch of ground, no mobs, nobody else near.
func _match(main: Node, arch: String) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({
		"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
		"tut_test": true,
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
	for dz in range(-30, 31):
		for dx in range(-30, 31):
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
		m.step(Match.DT)
	m.time = 0.0
	return m

func _cd_e(P: Hunter) -> float:
	return float(P.ak.cd["e"]) if P.ak != null else P.sig_cd

## One scripted run of `arch` at `fps` (with `hitch` extra seconds on some frames); returns the measured numbers.
func _run(main: Node, arch: String, fps: int, hitch: float) -> Dictionary:
	Engine.max_fps = fps
	var m := _match(main, arch)
	var P: Hunter = m.player
	var home := P.pos
	var ground_y := P.pos.y
	var out := {"apex": 0.0, "glide": 0.0, "dash": 0.0, "swings": 0, "shots": 0, "flames": 0, "cd_end": -1.0}
	var done := {}                    # script marks already pressed
	var t_cast := -1.0
	var glide_from := Vector3.ZERO
	var glided := false
	var dash_to := Vector3.ZERO
	var hitch_at := HITCH_FIRST
	var clock := 0.0
	var dt := 1.0 / float(fps)
	while m.time < T_END:
		var t := m.time + 1e-4
		var step_dt := dt
		if hitch > 0.0 and m.time >= hitch_at:
			hitch_at += HITCH_EVERY
			step_dt += hitch
		P.inp["aim"] = P.pos + Vector3(0, 0.9, -8)
		P.inp["move"] = Vector2(1, 0) if (t < T_DASH or (t >= T_GLIDE and t < T_GLIDE_END)) else Vector2.ZERO
		P.inp["glide"] = t >= T_GLIDE and t < T_GLIDE_END
		P.inp["fire"] = t >= T_FIRE and t < T_FIRE_END
		if not done.has("dash") and t >= 0.0:
			done["dash"] = true
			m.pending_input["dash"] = true
		if not done.has("jump") and t >= T_JUMP:
			done["jump"] = true
			dash_to = P.pos
			m.pending_input["jump"] = true
		if not done.has("cast") and t >= T_CAST:
			done["cast"] = true
			t_cast = m.time
			m.pending_input["sig"] = true
		m._process(step_dt)
		clock += step_dt
		for s in m.shots:
			if s["by"] == P and not s.has("_seen"):
				s["_seen"] = true
				out["shots"] = int(out["shots"]) + 1
		out["swings"] = P.swing_n
		if P.ak is AshwickKit:
			out["flames"] = (P.ak as AshwickKit).flame_ticks
		if t >= T_JUMP and t < T_GLIDE_END + 3.0:
			out["apex"] = maxf(float(out["apex"]), P.pos.y - ground_y)
		if t >= T_GLIDE and not glided and P.gliding:
			glided = true
			glide_from = P.pos
		if glided and not done.has("glide_end") and (not P.gliding and P.grounded):
			done["glide_end"] = true
			out["glide"] = Vector2(P.pos.x - glide_from.x, P.pos.z - glide_from.z).length()
		if t_cast >= 0.0 and float(out["cd_end"]) < 0.0 and m.time > t_cast:
			var left := _cd_e(P)      # (counts down 1:1 with sim time; Kael's chain starts none until it is pulled)
			out["cd_end"] = m.time + left - t_cast if left > 0.0 else 0.0
	out["clock"] = m.time - clock        # sim time behind (-) the frames drawn: a step cap or a clamp loses it
	out["dash"] = Vector2(dash_to.x - home.x, dash_to.z - home.z).length()
	out["end"] = Vector2(P.pos.x - home.x, P.pos.z - home.z).length()
	m.queue_free()
	return out

func _close(a: float, b: float) -> bool:
	return absf(a - b) <= TOL * maxf(absf(b), 0.5)

func run(main: Node) -> void:
	Save.no_write = true
	var was_fps := Engine.max_fps
	for arch in HEROES:
		var rows := []
		for r in RUNS:
			rows.append(await _run(main, arch, int(r[1]), float(r[2])))
			await main.get_tree().process_frame
		var base: Dictionary = rows[BASE]
		var row := "FPSPAR %-10s base: dash %.2f m  apex %.2f m  glide %.2f m  end %.2f m"
		row += "  swings %d  flame ticks %d  shots %d  E cooldown ends %.2f s"
		print(row % [arch, base["dash"], base["apex"], base["glide"], base["end"],
			base["swings"], base["flames"], base["shots"], base["cd_end"]])
		for i in RUNS.size():
			var late: float = rows[i]["clock"]
			var what := "%s @ %s: sim time keeps up with the frames drawn (off by %.3f s)"
			ok(absf(late) <= TOL * T_END, what % [arch, RUNS[i][0], late])
		var moved: bool = float(base["apex"]) > 0.5 and float(base["glide"]) > 0.5 and float(base["dash"]) > 0.5
		ok(moved, "%s: the script dashes, jumps and glides" % arch)
		for i in RUNS.size():
			if i == BASE:
				continue
			var run_row: Dictionary = rows[i]
			var tag := "%s @ %s" % [arch, RUNS[i][0]]
			for k in ["dash", "apex", "glide", "end", "swings", "flames", "shots", "cd_end"]:
				var got := float(run_row[k])
				ok(_close(got, float(base[k])), "%s: %s %.3f vs %.3f" % [tag, k, got, float(base[k])])
	Engine.max_fps = was_fps
	print("FPSPAR DONE, failures: %d" % bad)
	main.get_tree().quit()
