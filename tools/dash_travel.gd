extends RefCounted
## The clip against the body's travel (--dash-frames-check, owner bug 181: a dash that reads as a blink). Each frame
## of a ground dash on the kit clock: how far the body went, how far the clip's feet went with it (the rest is
## skating), the lean, and who owns the body (the Hero's clip or the run). The verdicts per dash:
##   early: the run plays while the body still travels (the clip ended before the move);
##   ride:  the dash pose stays on the body after the travel, while the run carries him (decision 0020 hands the
##          dash over at run speed, so the clip must hand over too): at most RIDE_S, one footage frame;
##   pop:   a jerk in the hand-over: one frame turns the main joints far more than the frames beside it (a
##          crossfade spreads a pose change evenly, a seek or a clip swap lands it on one frame).
## A dash with no travel (Motley's Trade is a lob) only reports what played.

const RIDE_S := 0.28           # s: the dash pose may ride the run this long: one 5 fps footage frame of recovery
                               # (every sheet lands its dash "within a frame") plus the half of the 0.16 s blend
                               # into the run that still shows the pose
## Per archetype, s more the pose may ride: a dash whose hit comes on arrival plays it out on the body.
const AFTER := {"bulwark": 0.4}    # the 360 Smash spins on arrival and settles over ~0.4 s (bjorn.md 0371-0372)
const EARLY_S := 0.05          # s: the run may show this long inside the travel (a frame or two of fade)
const POP_RATE := 30.0         # rad/s over the frames beside it, summed on JOINTS: a jerk the eye catches
const OWN := 0.5               # act_w from which the clip owns the body
const MOVING := 1.0            # m/s: the body is going somewhere
const FADE_IN := 0.12          # s from the press the loco may still show (WardenClips.FADE)
const AFTER_S := 0.6           # s after the travel the hand-over is watched
const FEET := [["foot.L", "shin.L"], ["foot.R", "shin.R"]]
const JOINTS := ["root", "hips", "upper_arm.L", "upper_arm.R", "thigh.L", "thigh.R"]

var sk: Skeleton3D
var hips := -1
var head := -1
var feet: Array = []            # bone index per foot, -1 if the rig has none
var joints: Array = []
var prev_feet: Array = []       # world positions relative to the body, last frame
var prev_q: Array = []
var hips0 := Vector3.INF        # the hips relative to the body at the press

func _init(skel: Skeleton3D) -> void:
	sk = skel
	if sk == null:
		return
	hips = sk.find_bone("hips")
	head = sk.find_bone("head")
	for f in FEET:
		var i: int = sk.find_bone(f[0])
		feet.append(i if i >= 0 else sk.find_bone(f[1]))
	for j in JOINTS:
		joints.append(sk.find_bone(j))

func _rel(i: int, body: Vector3) -> Vector3:
	return sk.global_transform * sk.get_bone_global_pose(i).origin - body

## One frame: the clip on the body and what it does with the legs and the spine.
func sample(P: Hunter, m: Match, step: float) -> Dictionary:
	var e := {"clip": "", "act": 0.0, "up": 0.0, "kt": -1.0, "lean": 0.0, "slip": 0.0, "drift": 0.0, "dpose": 0.0}
	var sync := P.model.get_node_or_null("Warden/Sync")
	if sync != null and sync.get("clips") != null:
		var c: WardenClips = sync.get("clips")
		e["clip"] = c.cur
		e["act"] = c.act_w
		e["up"] = c.up_w
	if P.ak != null and P.ak.anim_id != "":
		e["kt"] = m.time - P.ak.anim_at
	if sk == null or hips < 0:
		return e
	var body := P.global_position
	var fwd := Vector3(-sin(P.face), 0.0, -cos(P.face))
	var h := _rel(hips, body)
	if hips0 == Vector3.INF:
		hips0 = h
	e["drift"] = Vector2(h.x - hips0.x, h.z - hips0.z).length()
	if head >= 0:
		var up := _rel(head, body) - h
		e["lean"] = rad_to_deg(atan2(Vector2(up.x, up.z).dot(Vector2(fwd.x, fwd.z)), maxf(up.y, 0.001)))
	var foot_step := step          # (the first frame has no last one to step from: no slip)
	var now: Array = []
	for i in feet.size():
		var f: Vector3 = _rel(feet[i], body) if feet[i] >= 0 else Vector3.ZERO
		now.append(f)
		if not prev_feet.is_empty():
			var d: Vector3 = f - prev_feet[i]
			foot_step = maxf(foot_step if i > 0 else 0.0, Vector2(d.x, d.z).length())
	prev_feet = now
	e["slip"] = maxf(step - foot_step, 0.0)
	var q: Array = []
	var turned := 0.0
	for i in joints.size():
		var r: Quaternion = sk.get_bone_pose_rotation(joints[i]) if joints[i] >= 0 else Quaternion.IDENTITY
		q.append(r)
		if not prev_q.is_empty():
			turned += r.angle_to(prev_q[i])
	prev_q = q
	e["dpose"] = turned
	return e

## The window's drawn frames folded onto the sim's steps (Match.DT): headless with no --fixed-fps draws several
## frames per step, each showing the same pose, so a per-frame delta would read as zero then a whole step.
static func sim_frames(fs: Array) -> Array:
	var out: Array = []
	for e: Dictionary in fs:
		if not out.is_empty() and is_equal_approx(float(e["t"]), float(out[-1]["t"])):
			var m: Dictionary = e.duplicate()
			for k in ["dpose", "step", "slip"]:
				m[k] = float(e[k]) + float(out[-1][k])
			out[-1] = m
		else:
			out.append(e.duplicate())
	for i in out.size():
		out[i]["dt"] = float(out[i]["t"]) - float(out[i - 1]["t"]) if i > 0 else Match.DT
	return out

## The verdicts for one dash: `fs` its window's sim frames (sim_frames), `trav` the travel's.
## Returns [[what, good, detail], ...].
static func judge(arch: String, fs: Array, trav: Array) -> Array:
	var out: Array = []
	var clips := {}
	for e: Dictionary in fs:
		if String(e["clip"]) != "" and float(e["act"]) >= OWN:
			clips[e["clip"]] = true
	if trav.is_empty():
		out.append(["travel", true, "no body travel; clips %s" % str(clips.keys())])
		return out
	var t0 := float(trav[0]["t"])
	var t1 := float(trav[-1]["t"])
	var press := float(fs[0]["t"])
	var early := 0.0
	var went := 0.0
	var slip := 0.0
	var lean_max := 0.0
	for e: Dictionary in trav:
		var dt := float(e["dt"])
		went += float(e["step"])
		slip += float(e["slip"])
		lean_max = maxf(lean_max, float(e["lean"]))
		if float(e["t"]) - press > FADE_IN and float(e["act"]) < OWN and float(e["up"]) < OWN:
			early += dt
	var ride := 0.0
	var pop := 0.0
	var pop_at := ""
	var lean_end := float(trav[-1]["lean"])
	for i in range(1, fs.size() - 1):
		var e: Dictionary = fs[i]
		var t := float(e["t"])
		if t <= t1 or t > t1 + AFTER_S:
			continue
		var dt := float(e["dt"])
		if float(e["act"]) >= OWN and float(e["step"]) / maxf(dt, 1e-4) >= MOVING:
			ride += dt
		var beside := maxf(float(fs[i - 1]["dpose"]), float(fs[i + 1]["dpose"]))
		var jerk := (float(e["dpose"]) - beside) / maxf(dt, 1e-4)
		if jerk > pop:
			pop = jerk
			pop_at = "%.2f s after, %s" % [t - t1, e["clip"]]
	var about := "travel %.2f m in %.2f s (%s), lean %.0f deg peak / %.0f at the end, feet slip %.0f%%" % [
			went, t1 - t0 + float(trav[0]["dt"]), str(clips.keys()), lean_max, lean_end,
			100.0 * slip / maxf(went, 0.01)]
	var ride_s: float = RIDE_S + float(AFTER.get(arch, 0.0))
	out.append(["no run inside the travel", early <= EARLY_S,
			"run shown %.2f s of the travel (limit %.2f); %s" % [early, EARLY_S, about]])
	out.append(["the dash pose hands over with the travel", ride <= ride_s,
			"dash pose rode the run %.2f s after the travel (limit %.2f)" % [ride, ride_s]])
	out.append(["no pop into the run", pop <= POP_RATE,
			"hand-over jerk %.0f rad/s (%s; limit %.0f)" % [pop, pop_at if pop_at != "" else "none", POP_RATE]])
	return out
