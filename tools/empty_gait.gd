extends RefCounted
## The Empty rows of --anim-audit (tools/anim_audit.gd): the player body on the farm, the Models.hunter rig that
## HunterAnim walks, at the shortest, average and tallest height and build. Per body it measures
##  - walk and run: foot slide (m/s and % of the speed, same definition as the Hunters) and steps a second;
##  - turning on the spot: the biggest one-frame jump of a foot, the hips or the head, and the feet's drift;
##  - the idle: how far the planted feet creep.
## The gate is the Hunters': a planted foot slides at most MAX_SLIDE of the run speed.

const DT := 1.0 / 60.0
const WARM_S := 1.0
const SAMPLE_S := 2.4
const SPEEDS := [2.2, 3.4, 5.0]      # m/s: walk, a jog, the farm's full stick (home.gd SPEED)
const TURN_RATE := 6.0               # rad/s: a quick turn on the spot
const TURN_S := 2.0
const IDLE_S := 4.0
const MAX_SLIDE := 0.25              # of the run speed (the Hunters' gate)
const MAX_POP_CM := 8.0              # cm: the biggest one-frame jump while turning on the spot
const MAX_IDLE_CM := 2.0             # cm: the planted feet's creep while standing
const PLANT_Y := 0.03                # m: a foot is planted while its lowest boot point is this near the floor...
const PLANT_V := 0.3                 # m/s: ...and is going back against the body (not at rest or swinging forward)
## Look rows measured: [height, build]: the three heights at an average build, the three builds at an average height.
const BODIES := [[0, 1], [1, 1], [2, 1], [1, 0], [1, 2], [0, 0], [2, 2]]

var bad := 0
var rows := {}

func run(main: Node, holder: Node3D) -> void:
	Save.d = Save.fresh()
	for b in BODIES:
		await _body(main, holder, int(b[0]), int(b[1]))

func _body(main: Node, holder: Node3D, h: int, b: int) -> void:
	var look := Unmasked.clean({"unmasked": true, "height": h, "build": b})
	var m := Models.hunter("medium", Data.TEAM_COLORS[0], "", "", look, Arch.of_save())
	m.get_node("Rig/Torso/Aim/Gun").free()
	holder.add_child(m)
	await main.get_tree().process_frame
	var an := HunterAnim.new(m)
	var id := "empty_h%db%d" % [h, b]
	var row := {"leg_m": m.get_node("Rig/Legs/LegL/Knee").global_position.y + 0.265}
	var live := {}
	for s in SPEEDS:
		live[str(s)] = _gait(m, an, s)
	row["live"] = live
	row["turn"] = _turn(m, an)
	row["idle"] = _idle(m, an)
	rows[id] = row
	var top: Dictionary = live[str(SPEEDS[2])]
	var walk: Dictionary = live[str(SPEEDS[0])]
	print("AUDIT %-12s leg %.2f m run: slide %.2f m/s (%d%%) steps %.1f/s | walk slide %d%% steps %.1f/s | " % [
			id, row["leg_m"], top["slide"], round(100.0 * top["slide"] / SPEEDS[2]), top["steps_hz"],
			round(100.0 * walk["slide"] / SPEEDS[0]), walk["steps_hz"]]
			+ "turn pop %.1f cm | idle creep %.1f cm" % [row["turn"]["pop_cm"], row["idle"]["creep_cm"]])
	_gate(id, row)
	m.free()

func _gate(id: String, row: Dictionary) -> void:
	var share: float = row["live"][str(SPEEDS[2])]["slide"] / SPEEDS[2]
	if share > MAX_SLIDE:
		print("FAIL %s: feet slide %d%% of the run speed (limit %d%%)" % [
				id, round(100.0 * share), round(100.0 * MAX_SLIDE)])
		bad += 1
	if row["turn"]["pop_cm"] > MAX_POP_CM:
		print("FAIL %s: a turn on the spot jumps %.1f cm in one frame (limit %.0f)" % [
				id, row["turn"]["pop_cm"], MAX_POP_CM])
		bad += 1
	if row["idle"]["creep_cm"] > MAX_IDLE_CM:
		print("FAIL %s: planted feet creep %.1f cm standing (limit %.0f)" % [id, row["idle"]["creep_cm"], MAX_IDLE_CM])
		bad += 1

## The state HunterAnim reads, facing -Z.
func _state(vel: Vector3, face: float) -> Dictionary:
	return {"vel": vel, "face": face, "grounded": true, "fired": 99.0}

## Where the feet and the points that must not pop are, world frame (the holder sits at the origin).
func _read(m: Node3D) -> Dictionary:
	var out := {}
	for side in ["L", "R"]:
		var knee := m.get_node("Rig/Legs/Leg" + side + "/Knee") as Node3D
		var low := knee.global_transform * (FootPlant.SOLE[0] as Vector3)
		for p in FootPlant.SOLE:
			var w := knee.global_transform * (p as Vector3)
			if w.y < low.y:
				low = w
		out["foot." + side] = low     # the lowest point of the boot: what touches the floor
	out["hips"] = (m.get_node("Rig/Torso") as Node3D).global_position
	out["head"] = (m.get_node("Rig/Torso/HeadPivot") as Node3D).global_position
	return out

func _run_for(m: Node3D, an: HunterAnim, secs: float, vel: Vector3, face: float, keep: bool) -> Array:
	var fr: Array = []
	for k in int(secs / DT):
		an.update(DT, _state(vel, face))
		if keep:
			fr.append(_read(m))
	return fr

func _gait(m: Node3D, an: HunterAnim, s: float) -> Dictionary:
	m.rotation.y = 0.0
	_run_for(m, an, WARM_S, Vector3(0, 0, -s), 0.0, false)
	var ph0 := an.ph
	var fr := _run_for(m, an, SAMPLE_S, Vector3(0, 0, -s), 0.0, true)
	var out := _slide(fr, s)
	out["steps_hz"] = (an.ph - ph0) / PI / SAMPLE_S     # a step every half turn of the walk phase
	_run_for(m, an, 1.0, Vector3.ZERO, 0.0, false)
	return out

## Foot slide, as tools/anim_audit.gd: planted, a foot's ground speed is the speed minus how fast the leg pulls it back.
func _slide(fr: Array, s: float) -> Dictionary:
	var slide := 0.0
	var peak := 0.0
	var n := 0
	for f in ["foot.L", "foot.R"]:
		for i in range(1, fr.size() - 1):
			var v: float = ((fr[i + 1][f] as Vector3).z - (fr[i - 1][f] as Vector3).z) / (2.0 * DT)
			if (fr[i][f] as Vector3).y > PLANT_Y or v < PLANT_V:
				continue
			slide += absf(s - v)
			peak = maxf(peak, absf(s - v))
			n += 1
	return {"slide": slide / maxi(n, 1), "slide_max": peak, "planted": n}

## Turning on the spot at TURN_RATE: the biggest one-frame jump of a foot, the hips or the head.
func _turn(m: Node3D, an: HunterAnim) -> Dictionary:
	var face := 0.0
	_run_for(m, an, 1.0, Vector3.ZERO, face, false)
	var prev := _read(m)
	var pop := 0.0
	for k in int(TURN_S / DT):
		face += TURN_RATE * DT
		an.update(DT, _state(Vector3.ZERO, face))
		var cur := _read(m)
		for key in ["foot.L", "foot.R", "hips", "head"]:
			pop = maxf(pop, ((cur[key] as Vector3) - (prev[key] as Vector3)).length())
		prev = cur
	return {"pop_cm": 100.0 * pop}

## Standing: the feet's biggest move from where they first stood.
func _idle(m: Node3D, an: HunterAnim) -> Dictionary:
	_run_for(m, an, 1.0, Vector3.ZERO, 0.0, false)
	var fr := _run_for(m, an, IDLE_S, Vector3.ZERO, 0.0, true)
	var creep := 0.0
	for f in ["foot.L", "foot.R"]:
		for p in fr:
			var d: Vector3 = (p[f] as Vector3) - (fr[0][f] as Vector3)
			creep = maxf(creep, Vector2(d.x, d.z).length())
	return {"creep_cm": 100.0 * creep}
