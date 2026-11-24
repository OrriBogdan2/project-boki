extends RefCounted
## --anim-audit's run turn: the stick flipped 180 degrees at full run, the speed ramped as the game's walking step
## ramps it (HunterMove.walk with the Hunter's run and accel), read at the game's frame rate. Two cases:
##  - "back": the cursor held ahead, so the body keeps its facing (the body faces the cursor) and the legs leave the
##    run ring through the idle into the backward run (the strafe ring's back clip);
##  - "about": the cursor flips with the stick, so the body turns at HunterMove.turn_rate while the speed reverses.
## Per case: "share", a planted foot's mean speed against the ground over TURN_S after the flip as a share of the run
## (the mean of PHASES flips through the stride, as the stops), "skate_m", how far one foot skates, "dip", the least
## the loco blend gets from the idle (0: the idle plays) and "ring", where the blend ends ("run_b": backward run,
## "run_f": forward run).

const DT := 1.0 / 60.0
const LEAD_S := 0.3
const TURN_S := 0.4
const AFTER_S := 0.4  # s of the steady run the other way after the turn, the slide it is held against
const PHASES := 8


## The ground velocity (x, z) frame by frame: n_lead frames running -Z at the run, then the flip held for n frames.
static func turn_vel(id: String, n_lead: int, n: int) -> PackedVector2Array:
	var run := HunterMove.speed(id)
	var hv := Vector2(0.0, -run)
	var out := PackedVector2Array()
	for i in n_lead:
		out.append(hv)
	for i in n:
		hv = HunterMove.walk(hv, Vector2(0.0, run), HunterMove.accel(id), 1.0, DT)
		out.append(hv)
	return out


## Both cases for one Hunter: case -> {share, skate_m, dip, ring}.
static func turns(audit, m: Node3D, sync: Node, clips: WardenClips, sk: Skeleton3D, id: String) -> Dictionary:
	var out := {}
	var run := HunterMove.speed(id)
	var n_lead := int(LEAD_S / DT)
	var n_turn := int(TURN_S / DT)
	var vel := turn_vel(id, n_lead, n_turn + int(AFTER_S / DT))
	var rate := float(clips.tree.get("parameters/loco_rate/scale"))
	var cycle := clips.lib.get_animation(String(clips.d["loco"]["run"]["f"])).length / maxf(rate, 0.1)
	for about in [false, true]:
		var row := {"share": 0.0, "skate_m": 0.0, "dip": 0.0, "ring": "", "lead": 0.0, "after": 0.0}
		# the body's yaw frame by frame: the model stays unturned at the origin (its axes are the body's) and is fed
		# the world velocity and the facing (the clips and the stride read the velocity against it), so a planted foot
		# moves at -vel in body axes minus the turn's own swing (omega x r)
		var faces := PackedFloat32Array()
		var face := 0.0
		for i in vel.size():
			if about and i >= n_lead:
				face = rotate_toward(face, PI, HunterMove.turn_rate * DT)
			faces.append(face)
		var body := PackedVector2Array()
		for i in vel.size():
			body.append(vel[i].rotated(faces[i]))
		for p in PHASES:
			_pose(m, sync, vel[0], 0.0, (1.0 + p * cycle / PHASES) / DT)
			var fr: Array = []
			var dip := INF
			for i in vel.size():
				_pose(m, sync, vel[i], faces[i], 1)
				fr.append(audit.points(sk))
				if i >= n_lead and i < n_lead + n_turn:
					dip = minf(dip, clips.loco_pos.length())
			var one := _slide(fr, body, faces, n_lead, n_lead + n_turn, run, n_lead)
			row["lead"] += _slide(fr, body, faces, 1, n_lead, run, n_lead).x / PHASES
			row["after"] += _slide(fr, body, faces, n_lead + n_turn, fr.size(), run, n_lead).x / PHASES
			row["share"] += one.x / PHASES
			row["skate_m"] = maxf(row["skate_m"], one.y)
			row["dip"] += dip / PHASES
			row["ring"] = _ring(clips.loco_pos.y)
		out["about" if about else "back"] = row
	m.set_meta(WardenClips.STATE, {})
	return out


static func _pose(m: Node3D, sync: Node, hv: Vector2, face: float, frames: float) -> void:
	m.set_meta(WardenClips.STATE, {"vel": Vector3(hv.x, 0.0, hv.y), "face": face, "grounded": true, "crouch": 0.0})
	for k in int(frames):
		sync.call("_process", DT)


## Frames `from` to `to`: a planted foot's mean speed against the ground (the body stays at the origin and the ground
## runs under it at -vel, so a planted foot moves at -vel, less the turn's swing) as a share of `run`, and the
## longest skate of one foot (m). A foot is planted in the low 30% of its height over the steady run (frames before
## `band`), so a turn that lifts or holds a foot does not move what the steady run counts as planted.
static func _slide(
	fr: Array, vel: PackedVector2Array, faces: PackedFloat32Array, from: int, to: int, run: float, band: int
) -> Vector2:
	var slide := 0.0
	var n := 0
	var skate := 0.0
	for f in ["foot.L", "foot.R"]:
		var lo := INF
		var hi := -INF
		for i in band:
			lo = minf(lo, (fr[i][f] as Vector3).y)
			hi = maxf(hi, (fr[i][f] as Vector3).y)
		var foot := 0.0
		for i in range(maxi(from, 1), mini(to, fr.size() - 1)):
			if (fr[i][f] as Vector3).y > lo + 0.3 * maxf(hi - lo, 0.02):
				continue
			var v := ((fr[i + 1][f] as Vector3) - (fr[i - 1][f] as Vector3)) / (2.0 * DT)
			var r := fr[i][f] as Vector3
			var w := (faces[i + 1] - faces[i - 1]) / (2.0 * DT)
			var s := Vector2(v.x + vel[i].x + w * r.z, v.z + vel[i].y - w * r.x).length()
			slide += s
			n += 1
			foot += s * DT
		skate = maxf(skate, foot)
	return Vector2(slide / maxi(n, 1) / run, skate)


## Where the loco blend ends: the backward run, the forward run or between.
static func _ring(y: float) -> String:
	if y < -0.5:
		return "run_b"
	return "run_f" if y > 0.5 else "mixed"
