extends RefCounted
## --home-gait-check: the Empty (the player body at home, Models.hunter walked by HunterAnim + EmptyGait) at three
## body presets (short and slight, average, tall and sturdy) and the female average. Per body: at the farm's walk and
## full stick, every planted sole point stays within SLIDE_CM of where it came down (step by step, the worst one),
## the steps a second, no sole point under the floor, the hip bob; a turn at a run holds the same bar; after a stop
## the feet settle within SETTLE_S; turning on the spot pops no point more than POP_CM a frame and standing feet
## creep under CREEP_CM. Never touches the save. Add --json=<file> for the rows.

const DT := 1.0 / 60.0
const WARM_S := 1.2           # s: the run-up before a sample (the gait's first steps settle into step)
const SAMPLE_S := 2.4
const SPEEDS := [2.2, 5.0]    # m/s: a walk on a half stick, the farm's full stick (home.gd SPEED)
const TURN_RUN := 1.5         # rad/s: a run bending round a corner
const TURN_RATE := 6.0        # rad/s: a quick turn on the spot
const TURN_S := 2.0
const IDLE_S := 4.0
const PLANT_Y := 0.012        # m: a sole point is on the floor while this near it
const CONTACT_MIN := 3        # frames: fewer on the floor is a brush, not a contact
const SLIDE_CM := 3.0         # cm: a planted sole point may move this far before it lifts (the task's bar)
const SINK_CM := 3.0          # cm: no sole point goes further under the floor (the boot has no ankle: the toe dips)
const SETTLE_S := 0.8         # s: from a stop at full stick to still feet
const STILL_MPS := 0.02       # m/s: a foot this slow is still
const POP_CM := 8.0           # cm: the biggest one-frame jump turning on the spot
const CREEP_CM := 2.0         # cm: the planted feet's creep while standing
## [sex, height, build] of the Unmasked look: Male short slight, Male average, Male tall sturdy, Female average.
const FLICK_M := 0.5          # m: the cast's wind-back to the flick moves the rod tip at least this far
const ROD_HAND_CM := 8.0      # cm: the rod's grip may sit this far from the rear hand
const BODIES := [[1, 0, 0], [1, 1, 1], [1, 2, 2], [0, 1, 1]]

var bad := 0
var rows := {}
var json_path := ""
var holder: Node3D

func ok(cond: bool, what: String) -> void:
	print("GAIT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--json="):
			json_path = String(a).substr(7)
	holder = Node3D.new()
	main.add_child(holder)
	for b in BODIES:
		await _body(main, int(b[0]), int(b[1]), int(b[2]))
	if json_path != "":
		var f := FileAccess.open(json_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(rows, "\t"))
	print("HOME_GAIT_CHECK_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _body(main: Node, sex: int, h: int, b: int) -> void:
	var look := Unmasked.clean({"unmasked": true, "gender": sex, "height": h, "build": b})
	var m := Models.hunter("medium", Data.TEAM_COLORS[0], "", "", look, Arch.of_save())
	m.get_node("Rig/Torso/Aim/Gun").free()
	holder.add_child(m)
	await main.get_tree().process_frame
	var an := HunterAnim.new(m)
	var id := "empty_%s_h%db%d" % ["f" if sex == 0 else "m", h, b]
	var row := {"hip_m": (m.get_node("Rig/Legs/LegL") as Node3D).global_position.y}
	for s in SPEEDS:
		row["gait_%.1f" % s] = _gait(m, an, float(s), 0.0)
	row["turn_run"] = _gait(m, an, float(SPEEDS[1]), TURN_RUN)
	row["stop"] = _stop(m, an)
	row["turn"] = _turn(m, an)
	row["idle"] = _idle(m, an)
	row["fishing"] = _fishing(m, an)
	rows[id] = row
	print("GAIT %-14s hip %.2f m | walk slide %.1f cm %.1f steps/s | run slide %.1f cm %.1f steps/s bob %.1f cm | "
			% [id, row["hip_m"], row["gait_2.2"]["slide_cm"], row["gait_2.2"]["steps_hz"],
			row["gait_5.0"]["slide_cm"], row["gait_5.0"]["steps_hz"], row["gait_5.0"]["bob_cm"]]
			+ "turning run slide %.1f cm | stop %.2f s | turn pop %.1f cm | idle creep %.1f cm"
			% [row["turn_run"]["slide_cm"], row["stop"]["settle_s"], row["turn"]["pop_cm"], row["idle"]["creep_cm"]])
	_gate(id, row)
	m.free()

func _gate(id: String, row: Dictionary) -> void:
	for key in ["gait_2.2", "gait_5.0", "turn_run"]:
		var g: Dictionary = row[key]
		ok(g["slide_cm"] <= SLIDE_CM, "%s %s: planted feet stay within %.0f cm a step (worst %.1f cm, %d steps)"
				% [id, key, SLIDE_CM, g["slide_cm"], g["steps"]])
		ok(g["sink_cm"] <= SINK_CM, "%s %s: no sole point under the floor (worst %.1f cm)" % [id, key, g["sink_cm"]])
		ok(g["steps"] >= 4, "%s %s: the legs step (%d steps in %.1f s)" % [id, key, g["steps"], SAMPLE_S])
	ok(row["stop"]["settle_s"] <= SETTLE_S, "%s: feet still %.2f s after a stop (limit %.1f)"
			% [id, row["stop"]["settle_s"], SETTLE_S])
	ok(row["turn"]["pop_cm"] <= POP_CM, "%s: turning on the spot jumps %.1f cm a frame at most (limit %.0f)"
			% [id, row["turn"]["pop_cm"], POP_CM])
	ok(row["idle"]["creep_cm"] <= CREEP_CM, "%s: standing feet creep %.1f cm (limit %.0f)"
			% [id, row["idle"]["creep_cm"], CREEP_CM])
	var fish: Dictionary = row["fishing"]
	ok(fish["creep_cm"] <= CREEP_CM, "%s: fishing (wait, cast, bite, reel, land) feet creep %.1f cm (limit %.0f)"
			% [id, fish["creep_cm"], CREEP_CM])
	ok(fish["rod_miss"] == 0, "%s: the rod is up for every fishing pose, the line leaves its tip (%d frames wrong)"
			% [id, fish["rod_miss"]])
	ok(fish["flick_m"] >= FLICK_M, "%s: the cast moves the rod tip %.2f m (at least %.1f)"
			% [id, fish["flick_m"], FLICK_M])
	ok(fish["hand_cm"] <= ROD_HAND_CM, "%s: the rod stays in the hands (%.1f cm off, limit %.0f)"
			% [id, fish["hand_cm"], ROD_HAND_CM])
	ok(fish["hidden"], "%s: the rod is gone once fishing ends" % id)

## The state HunterAnim reads; the body faces `face` and the tool moves the model as the farm would.
func _state(vel: Vector3, face: float) -> Dictionary:
	return {"vel": vel, "face": face, "grounded": true, "fired": 99.0}

## World positions of the six sole points (three a boot), the hips and the head.
func _read(m: Node3D) -> Dictionary:
	var out := {}
	for side in ["L", "R"]:
		var knee := m.get_node("Rig/Legs/Leg" + side + "/Knee") as Node3D
		for i in FootPlant.SOLE.size():
			out["sole.%s%d" % [side, i]] = knee.global_transform * (FootPlant.SOLE[i] as Vector3)
	out["hips"] = (m.get_node("Rig/Torso") as Node3D).global_position
	out["head"] = (m.get_node("Rig/Torso/HeadPivot") as Node3D).global_position
	return out

## Runs `secs` of the animation with the body moving at speed `s` and turning at `yaw_rate`; frames if `keep`.
func _run_for(m: Node3D, an: HunterAnim, secs: float, s: float, yaw_rate: float, keep: bool) -> Array:
	var fr: Array = []
	for _k in int(secs / DT):
		var face := m.rotation.y + yaw_rate * DT
		var vel := Vector3(-sin(face), 0.0, -cos(face)) * s
		m.rotation.y = face
		m.position += vel * DT
		an.update(DT, _state(vel, face))
		if keep:
			fr.append(_read(m))
	return fr

## A steady run at `s` (bending round at `yaw_rate`): the slide of every planted sole point, steps a second,
## the deepest a sole point sinks, the hip bob.
func _gait(m: Node3D, an: HunterAnim, s: float, yaw_rate: float) -> Dictionary:
	_run_for(m, an, 1.0, 0.0, 0.0, false)
	_run_for(m, an, WARM_S, s, yaw_rate, false)
	var fr := _run_for(m, an, SAMPLE_S, s, yaw_rate, true)
	var out := _slide(fr)
	out["steps_hz"] = float(out["steps"]) / SAMPLE_S
	var lo := INF
	var hi := -INF
	var sink := 0.0
	for f in fr:
		lo = minf(lo, (f["hips"] as Vector3).y)
		hi = maxf(hi, (f["hips"] as Vector3).y)
		for key in f:
			if String(key).begins_with("sole."):
				sink = maxf(sink, -(f[key] as Vector3).y)
	out["bob_cm"] = 100.0 * (hi - lo)
	out["sink_cm"] = 100.0 * sink
	return out

## Each sole point's contacts: a run of CONTACT_MIN or more frames on the floor; its slide is how far it moved
## between its second frame down and its last but one (the frames it comes down and lifts on are its approach).
## A step is a foot (any of its sole points) coming down after CONTACT_MIN frames or more off the floor.
func _slide(fr: Array) -> Dictionary:
	var worst := 0.0
	var steps := 0
	for side in ["L", "R"]:
		var up := CONTACT_MIN      # frames the foot has been off the floor
		for f in fr:
			var low := INF
			for i in FootPlant.SOLE.size():
				low = minf(low, (f["sole.%s%d" % [side, i]] as Vector3).y)
			if low <= PLANT_Y:
				if up >= CONTACT_MIN:
					steps += 1
				up = 0
			else:
				up += 1
		for i in FootPlant.SOLE.size():
			var key := "sole.%s%d" % [side, i]
			var down: Array = []
			for f in range(fr.size() + 1):
				if f < fr.size() and (fr[f][key] as Vector3).y <= PLANT_Y:
					down.append(fr[f][key])
					continue
				if down.size() >= CONTACT_MIN:
					var at: Vector3 = down[1]
					for p in down.slice(1, down.size() - 1):
						worst = maxf(worst, Vector2((p as Vector3).x - at.x, (p as Vector3).z - at.z).length())
				down.clear()
	return {"slide_cm": 100.0 * worst, "steps": steps}

## Full stick, then the stick let go: how long until every sole point is still, and how far the feet travel.
func _stop(m: Node3D, an: HunterAnim) -> Dictionary:
	_run_for(m, an, WARM_S, float(SPEEDS[1]), 0.0, false)
	var fr := _run_for(m, an, 1.5, 0.0, 0.0, true)
	var settle := 1.5
	var travel := 0.0
	for i in range(1, fr.size()):
		var fastest := 0.0
		for key in fr[i]:
			if String(key).begins_with("sole."):
				var d: float = ((fr[i][key] as Vector3) - (fr[i - 1][key] as Vector3)).length()
				fastest = maxf(fastest, d / DT)
				travel = maxf(travel, ((fr[i][key] as Vector3) - (fr[0][key] as Vector3)).length())
		if fastest < STILL_MPS:
			settle = i * DT
			break
	return {"settle_s": settle, "travel_cm": 100.0 * travel}

## Turning on the spot at TURN_RATE: the biggest one-frame jump of a sole point, the hips or the head.
func _turn(m: Node3D, an: HunterAnim) -> Dictionary:
	_run_for(m, an, 1.0, 0.0, 0.0, false)
	var prev := _read(m)
	var pop := 0.0
	for f in _run_for(m, an, TURN_S, 0.0, TURN_RATE, true):
		for key in f:
			pop = maxf(pop, ((f[key] as Vector3) - (prev[key] as Vector3)).length())
		prev = f
	return {"pop_cm": 100.0 * pop}

## Standing: the sole points' biggest move from where they first stood.
func _idle(m: Node3D, an: HunterAnim) -> Dictionary:
	_run_for(m, an, 1.0, 0.0, 0.0, false)
	var fr := _run_for(m, an, IDLE_S, 0.0, 0.0, true)
	return {"creep_cm": _creep(fr)}

## The sole points' biggest move (cm) from where they first stood, while both stood on the floor.
func _creep(fr: Array) -> float:
	var creep := 0.0
	for key in fr[0]:
		if not String(key).begins_with("sole."):
			continue
		for f in fr:
			var d: Vector3 = (f[key] as Vector3) - (fr[0][key] as Vector3)
			var down: bool = (f[key] as Vector3).y < PLANT_Y and (fr[0][key] as Vector3).y < PLANT_Y
			if down:
				creep = maxf(creep, Vector2(d.x, d.z).length())
	return 100.0 * creep

## Fishing on the spot: the held pose with the cast, bite, reel and land played over it (HomeVerbs, as the game does),
## then the rod put away. The feet creep, the rod shown (and its tip a node the line can leave from) for every frame
## a pose is up, how far the tip flicks in the cast, the rod's grip from the rear hand, whether it hides.
func _fishing(m: Node3D, an: HunterAnim) -> Dictionary:
	_run_for(m, an, 1.0, 0.0, 0.0, false)
	var verbs := HomeVerbs.new()
	var fr: Array = []
	var miss := 0
	var hand := 0.0
	var tip_lo := INF
	var tip_hi := -INF
	var plan := [["wait", ""], ["wait", "cast"], ["wait", "bite"], ["reel", ""], ["wait", "land"], ["wait", ""]]
	var rod: Node3D = null
	for step in plan:
		verbs.hold(step[0])
		if step[1] != "":
			verbs.play(step[1])
		for _k in int(1.2 / DT):
			an.update(DT, _state(Vector3.ZERO, m.rotation.y).merged(verbs.step(DT)))
			fr.append(_read(m))
			rod = m.get_node_or_null("Rig/Torso/Rod")
			if rod == null or not rod.visible or HunterRod.tip(an) == null:
				miss += 1
				continue
			if step[1] == "cast" and verbs.act == "cast":
				var y := (HunterRod.tip(an) as Node3D).global_position.y
				tip_lo = minf(tip_lo, y)
				tip_hi = maxf(tip_hi, y)
			var rear := an.arm_r.transform * (an.el_r.transform * an.hand_r.position)
			hand = maxf(hand, 100.0 * (rod.position + rod.basis.y * HunterRod.BUTT).distance_to(rear))
	verbs.hold("")
	for _k in int(1.0 / DT):
		an.update(DT, _state(Vector3.ZERO, m.rotation.y).merged(verbs.step(DT)))
	rod = m.get_node_or_null("Rig/Torso/Rod")
	return {"creep_cm": _creep(fr), "rod_miss": miss, "flick_m": tip_hi - tip_lo, "hand_cm": hand,
			"hidden": rod == null or not rod.visible}
