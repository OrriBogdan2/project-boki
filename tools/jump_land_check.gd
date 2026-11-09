extends RefCounted
## The plain jump through a Hero's hand-keyed clips (part of --clip-check): the game's arc (tools/jump_land_shots.gd)
## fed to the clips, running and standing, twice over. Measures what the player sees at the match camera: the take-off
## reads within 0.1 s of the press (the pose leaves the run), it reads the same on the next jump (the rise clip starts
## over), the apex turns the pose (rise into fall), the landing dips at once and the body is back on the run quickly:
## no long recovery, and running, the legs are not held by the land clip. Prints "JL <id> <run|still> ..." per Hero.

const DT := 1.0 / 30.0
const READ_AT := 0.1          # s after the press the take-off has to show
const AGAIN_AT := 0.15        # s after the press, past the air fade: the rise clip alone
const APEX_HALF := 0.15       # s either side of the apex the turn is read over
const DIP_WINDOW := 0.15      # s after touchdown the absorb has to bottom out in
const SETTLE_M := 0.02        # m: the hips this close to their run height count as recovered
const RUN_REF := 0.3          # s of the run-up before the press whose lowest hips give the run height

var ids_seen := 0

## {off, again, apex, dip, dip_t, legs, back, settle} per variant, all in deg, m or s.
static func measure(m: Node3D, sync: Node, clips: WardenClips, running: bool) -> Dictionary:
	var shots := preload("res://tools/jump_land_shots.gd")
	var skel := WardenGlb.skeleton(m.get_node("Warden"))
	var hips_bi := WardenSkeleton.find(skel, "hips")
	var air := 2.0 * Hunter.JUMP_V / Hunter.H_GRAV
	var r := {}
	var first_off: Array = []
	for jump in 2:
		var t := -0.6
		var before: Array = []
		var apex_in: Array = []
		var run_y := INF
		var land_at := -1.0
		var dip := 0.0
		var dip_t := 0.0
		var legs := 0.0
		var back := -1.0
		var settle := -1.0
		while t < air + 1.0:
			var s: Dictionary = shots.arc(t, running)
			m.set_meta(WardenClips.STATE, s)
			sync.call("_process", DT)
			var y := skel.get_bone_global_pose(hips_bi).origin.y
			if t < -DT * 0.5 and t >= -RUN_REF:
				run_y = minf(run_y, y)
			if t < -DT * 0.5 and t >= -DT * 1.5:
				before = _pose(skel)
			if absf(t - READ_AT) < DT * 0.5:
				r["off"] = _diff(before, _pose(skel))
			if absf(t - AGAIN_AT) < DT * 0.5:
				if jump == 0:
					first_off = _pose(skel)
				else:
					r["again"] = _diff(first_off, _pose(skel))
			if absf(t - (air * 0.5 - APEX_HALF)) < DT * 0.5:
				apex_in = _pose(skel)
			if absf(t - (air * 0.5 + APEX_HALF)) < DT * 0.5:
				r["apex"] = _diff(apex_in, _pose(skel))
			if t >= air:
				if land_at < 0.0:
					land_at = t
				var since := t - land_at
				if since <= DIP_WINDOW and y - run_y < dip:
					dip = y - run_y
					dip_t = since
				if clips.act_w > 0.5:
					legs = since
				if back < 0.0 and since > DT and clips.act_w <= 0.0:
					back = since
				if y < run_y - SETTLE_M:
					settle = -1.0
				elif settle < 0.0:
					settle = since
			t += DT
		r["dip"] = dip
		r["dip_t"] = dip_t
		r["legs"] = legs
		r["back"] = back
		r["settle"] = settle
	return r

## The rig-contract bones' rotations (the bones the clips key; the spring bones jiggle with their own history).
static func _pose(skel: Skeleton3D) -> Array:
	var out: Array = []
	for b in WardenGlb.BONES:
		var bi := WardenSkeleton.find(skel, b)
		if bi >= 0:
			out.append(skel.get_bone_pose_rotation(bi))
	return out

## deg: the bone that turned the most between two poses.
static func _diff(a: Array, b: Array) -> float:
	var worst := 0.0
	for i in a.size():
		worst = maxf(worst, rad_to_deg((a[i] as Quaternion).angle_to(b[i])))
	return worst
