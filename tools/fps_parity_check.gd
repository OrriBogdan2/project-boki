extends RefCounted
## --fps-parity-check: the same input script gives the same hunter at 30, 60, 144 and 240 fps and through a 20 ms hitch,
## and one press of each key gives exactly one action at 60, 144 and 240 fps (the PRESS rows, below).
## Physics ticks at 60 Hz (Match.DT) inside Match._process, so only gameplay that reads the frame time would drift.
## Each frame this drives the real Match._process with that run's frame length (the tutorial-test option leaves the
## input to the script, as a player's keys are read once per frame), with presses landing on 1/30 s marks of sim time
## so every frame rate can press on the same tick. Script: dash, jump, glide 2 s, hold LMB 3 s, cast E.
## Compared against the 60 fps run: end position, jump apex, glide reach, dash length, swings, shots,
## flame ticks and the E cooldown end.
## The PRESS rows drive the real input path (Input.action_press/release, Match._gather_input, the pending_input latch
## and the fixed steps) at each render rate, with the press landing at every phase of the 60 Hz tick: LMB, RMB, E, R,
## Shift and jump are each pressed and released inside one tick (one frame down, so at 144 and 240 the fixed step
## may not run while the key is down) and must give exactly one action: a shot or swing, a spent cooldown or charge,
## a lift-off. The glide key is a hold (the glider opens on a second fixed step with it still down), so it is tapped
## for 3 ticks and must open the glider once.

const HEROES := ["gunslinger", "juggernaut", "ashwick", "thief"]      # Vex, Kael, Cinder, Sparkle
const RUNS := [
	["30 fps", 30, 0.0], ["60 fps", 60, 0.0], ["144 fps", 144, 0.0], ["240 fps", 240, 0.0],
	["60 fps + 20 ms hitches", 60, 0.020],
]
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
const PRESS_HZ := [60, 144, 240]
const PRESS_HERO := "gunslinger"       # Vex: a shot, a cast, a dash and a hero R on every key
const PRESS_WATCH := 0.5               # s: how long a press is watched for its action
const PRESS_GLIDE_UP := 12.0           # m: the glide key is pressed this high above the ground
const PRESS_GLIDE_HOLD := 0.05         # s: a 3-tick tap: the glider opens on a second step with the key down
## key -> [the input action, the Hunter slot that spends]; lmb counts shots and swings, jump counts lift-offs, glide
## counts the glider opening
const PRESS_KEYS := {
	"lmb": ["fire", ""], "rmb": ["secondary", "sec"], "e": ["signature", "e"], "r": ["hunter_ult", "x"],
	"dash": ["dash", "dash"], "jump": ["jump", ""], "glide": ["glide", ""],
}

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("FPSPAR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## A fresh match as `arch` on a flat, empty patch of ground, no mobs, nobody else near.
## `real_input`: the match reads the keys itself (Match._gather_input), as in play; else the script drives the hunter.
func _match(main: Node, arch: String, real_input := false) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({
		"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
		"tut_test": not real_input,
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

## What a key has done so far, as one running count: shots and swings (LMB), lift-offs (jump), glider openings (glide),
## else the times its slot spent a charge or started a cooldown (`watch` carries the last reading between frames).
func _acts(m: Match, key: String, watch: Dictionary) -> int:
	var hunter: Hunter = m.player
	var n := int(watch.get("n", 0))
	match key:
		"lmb":
			for s in m.shots:
				if s["by"] == hunter and not s.has("_seen"):
					s["_seen"] = true
					n += 1
			n += hunter.swing_n - int(watch.get("swings", hunter.swing_n))
			watch["swings"] = hunter.swing_n
		"jump":
			n += int(not hunter.grounded and bool(watch.get("grounded", true)))
			n += hunter.air_jumps - int(watch.get("air", 0))
			watch["grounded"] = hunter.grounded
			watch["air"] = hunter.air_jumps
		"glide":
			n += int(hunter.gliding and not bool(watch.get("gliding", false)))
			watch["gliding"] = hunter.gliding
		_:
			var info: Dictionary = hunter.slot_info(String(PRESS_KEYS[key][1]))
			var cd := float(info["cd"])
			if watch.has("cd"):
				n += int(int(info["charges"]) < int(watch["charges"]) or cd > float(watch["cd"]) + 0.01)
			watch["charges"] = int(info["charges"])
			watch["cd"] = cd
	watch["n"] = n
	return n

## One press of `key` at `hz`, landing `phase` frames into a 60 Hz tick and let go a frame later (inside the same tick
## at 144 and 240); returns the actions counted over the watch.
func _press(main: Node, key: String, hz: int, phase: int) -> int:
	Engine.max_fps = hz
	var m := _match(main, PRESS_HERO, true)
	var hunter: Hunter = m.player
	if key == "glide":
		hunter.teleport(hunter.pos + Vector3(0, PRESS_GLIDE_UP, 0))
		hunter.grounded = false
	if key == "r":
		hunter.lvl = 20
		hunter.ult = 1.0
	var act := String(PRESS_KEYS[key][0])
	var dt := 1.0 / float(hz)
	var down := int(ceil(PRESS_GLIDE_HOLD * hz)) if key == "glide" else 1      # frames the key stays down
	var watch := {}
	_acts(m, key, watch)
	m.acc = phase * dt
	for f in int(ceil(PRESS_WATCH * hz)):
		if f == 0:
			Input.action_press(act)
		elif f == down:
			Input.action_release(act)
		m._process(dt)
		_acts(m, key, watch)
		await main.get_tree().process_frame
	if Input.is_action_pressed(act):
		Input.action_release(act)
	var n := int(watch["n"])
	m.queue_free()
	return n

func _press_rows(main: Node) -> void:
	for hz in PRESS_HZ:
		var phases := maxi(1, int(ceil(float(hz) / 60.0)))      # frames in a tick: the press lands at each
		for key in PRESS_KEYS:
			var got := []
			for ph in phases:
				got.append(await _press(main, String(key), int(hz), ph))
			var all_one := got.all(func(n): return n == 1)
			ok(all_one, "PRESS %3d Hz %-4s: one press, one action (per tick phase: %s)" % [hz, key, str(got)])

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
	await _press_rows(main)
	Engine.max_fps = was_fps
	print("FPSPAR DONE, failures: %d" % bad)
	main.get_tree().quit()
