extends RefCounted
## --spring-settle-check: every v2 Hero's spring chains (hair, braids, tails, wings; WardenGlb.Springs) after
## a dash stop, the landing of a jump and a sharp turn (docs/art/secondary_motion/README.md). The chains alone
## (no clips, no wind), the model moved as the hunter moves. Per chain: the tip's swing past its final place
## (peak), the time until it stays within SETTLE_TOL of it, how many times it swings through, and how far a
## joint comes in toward the body's axis past its own rest and its root's (a clip through the body). Fails a
## chain that never settles, swings on, freezes on a dash stop or cuts into the body. Never touches the save.

const DT := 1.0 / 60.0
const STAND_F := 27          # the frame (0.45 s, standing settled) the body distances are taken at
const SETTLE_TOL := 0.015     # m: the tip counts as settled this close to its final place
const SETTLE_MAX := 1.2       # s after the event
const SWINGS_MAX := 3         # times through its final place (each way) before it settles
const SWING_MIN := 0.01       # m: a swing smaller than this doesn't count
const MOVE_MIN := 0.01        # m: a chain that swings less than this on a dash stop is frozen
const CLIP_MAX := 0.03        # m: a joint may come this far inside the body line
const HEAD_UP := 0.25         # the body's axis runs hips -> head and on by this share of it (to the crown)
const RUN := 5.5              # m/s: the run before the turn
const TURN_T := 0.1           # s: a sharp turn, 180 degrees
## Known misses still to tune (README "Open"): reported, not failed. One that starts passing fails the run until
## it is taken off, so each fix removes its own entries.
const OPEN := [
	"hem dash tail", "hem land tail", "hem turn tail", "hem turn scarftailR", "hem turn scarftailL",
	"vex dash braid", "vex turn braid",
	"ostra dash hornR", "ostra dash hornL", "ostra dash tail0", "ostra dash tail3", "ostra dash tail5",
	"ostra land hornR", "ostra land hornL", "ostra land wisp",
	"ostra turn hornL", "ostra turn tail5", "ostra turn wisp",
	"ryzz land pigR",
	"sable dash braid",
	"claire turn scarftail_braid",
	"cinder dash scarftail_hairc", "cinder land scarftail_hairc",
	"pip dash tail", "pip dash capeback", "pip land capeback", "pip turn tail",
]
## each scenario: when the event happens and how long it is watched after it (s)
const SCENES := {"dash": [0.69, 2.5], "land": [1.425, 2.5], "turn": [0.9, 2.5]}

var bad := 0
var holder: Node3D

func ok(cond: bool, what: String) -> void:
	print("SETTLE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	for a in WardenGlb.ART:
		for sc in SCENES:
			_audit(String(a), String(sc))
	print("SPRING_SETTLE_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Where the model is at time t (s) of a scenario: [position, yaw]. Forward is -Z at yaw 0.
## dash: still, then a dash (Hunter.DASH_SPEED for DASH_TIME) from 0.5 s and a dead stop. land: a standing jump
## (Hunter.JUMP_V, H_GRAV) from 0.5 s. turn: a run, then a 180-degree turn in TURN_T at 0.8 s, running on.
static func at(sc: String, t: float) -> Array:
	match sc:
		"dash":
			return [Vector3(0, 0, -Hunter.DASH_SPEED * clampf(t - 0.5, 0.0, Hunter.DASH_TIME)), 0.0]
		"land":
			var u := clampf(t - 0.5, 0.0, 2.0 * Hunter.JUMP_V / Hunter.H_GRAV)
			return [Vector3(0, Hunter.JUMP_V * u - 0.5 * Hunter.H_GRAV * u * u, 0), 0.0]
	var t0 := 0.8
	if t <= t0:
		return [Vector3(0, 0, -RUN * t), 0.0]
	var turn := clampf((t - t0) / TURN_T, 0.0, 1.0)
	# (forward turns with the yaw; the arc of the turn is short enough to integrate in steps)
	var p := Vector3(0, 0, -RUN * t0)
	var steps := int(ceil((t - t0) / DT))
	for i in steps:
		var f := clampf((i * DT) / TURN_T, 0.0, 1.0)
		p += Vector3(0, 0, -1).rotated(Vector3.UP, PI * f) * RUN * minf(DT, t - t0 - i * DT)
	return [p, PI * turn]

## Builds the Hero under `parent` alone on its springs, ready to be stepped (null when it has none).
static func model(a: String, parent: Node) -> Node3D:
	var m := Models.hunter(Arch.weight(a), Data.TEAM_COLORS[0], Arch.signature(a), "", PlayerLook.neutral(), a)
	parent.add_child(m)
	var sync := m.get_node_or_null("Warden/Sync") as WardenGlb.Sync
	if sync == null or sync.springs.chains.is_empty():
		m.free()
		return null
	sync.springs.calm = true
	sync.clips = null      # (the chains alone: a clip's idle keeps moving what they hang from)
	return m

func _audit(a: String, sc: String) -> void:
	var m := model(a, holder)
	if m == null:
		return
	var sync := m.get_node("Warden/Sync") as WardenGlb.Sync
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var chains: Array = sync.springs.chains
	var ev: float = SCENES[sc][0]
	var frames := int((ev + float(SCENES[sc][1])) / DT)
	var tips: Array = []          # per chain, the tip in model space each frame from the event on
	var rest_d: Array = []        # per chain, each joint's distance from the body axis standing
	var clip := PackedFloat32Array()
	for ch in chains:
		tips.append([])
		rest_d.append([])
		clip.append(0.0)
	for f in frames:
		var t := f * DT
		var pose := at(sc, t)
		m.position = pose[0]
		m.rotation.y = pose[1]
		sync._process(DT)
		var inv := m.global_transform.affine_inverse()
		var axis := _axis(sk, inv)
		for c in chains.size():
			var pts: PackedVector3Array = chains[c]["pts"]
			if t >= ev:
				(tips[c] as Array).append(inv * pts[pts.size() - 1])
			if f == STAND_F:
				for p in pts:
					(rest_d[c] as Array).append(_dist(inv * p, axis))
			elif f > STAND_F:
				var root_d := _dist(inv * pts[0], axis)
				for j in range(1, pts.size()):
					var inside := minf(root_d, float(rest_d[c][j])) - _dist(inv * pts[j], axis)
					clip[c] = maxf(clip[c], inside)
	for c in chains.size():
		var r := _settle(tips[c])
		var chain := sk.get_bone_name(int(chains[c]["ids"][0])).trim_prefix("spring_").trim_suffix("_0")
		var still := sc == "dash" and float(r["peak"]) < MOVE_MIN
		# (a chain hanging off a fist or a belt has no body line to keep out of)
		var cut := clip[c] > CLIP_MAX and not bool(chains[c]["hang"])
		var good := float(r["settle"]) <= SETTLE_MAX and int(r["swings"]) <= SWINGS_MAX and not cut and not still
		var tag := "%s %s %s" % [WardenGlb.ART[a], sc, chain]
		var line := "%s: peak %.3f m, settles in %.2f s, %d swings, overshoot %.0f%%, into the body %.3f m" \
				% [tag, r["peak"], r["settle"], r["swings"], 100.0 * float(r["over"]), clip[c]]
		if tag in OPEN:
			ok(not good, "(open) " + line + ("" if not good else ": passes now, take it off OPEN"))
		else:
			ok(good, line)
	m.free()

## The body's axis in model space: hips to head, on toward the crown.
static func _axis(sk: Skeleton3D, inv: Transform3D) -> Array:
	var hips := inv * (sk.global_transform * sk.get_bone_global_pose(WardenSkeleton.find(sk, "hips")).origin)
	var head := inv * (sk.global_transform * sk.get_bone_global_pose(WardenSkeleton.find(sk, "head")).origin)
	return [hips, head + (head - hips) * HEAD_UP]

static func _dist(p: Vector3, axis: Array) -> float:
	var a: Vector3 = axis[0]
	var ab: Vector3 = axis[1] - a
	var u := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * u)

## A tip's track after the event: its biggest swing off the final place (m), the time until it stays within
## SETTLE_TOL (s; the whole watch if never), the times it swings through, and the biggest swing back (of the peak).
static func _settle(track: Array) -> Dictionary:
	var end: Vector3 = track[track.size() - 1]
	var peak := Vector3.ZERO
	var last := -1
	for i in track.size():
		var d: Vector3 = track[i] - end
		if d.length() > peak.length():
			peak = d
		if d.length() > SETTLE_TOL:
			last = i
	var dir := peak.normalized() if peak.length() > 1e-5 else Vector3.ZERO
	var swings := 0
	var side := 0
	var back := 0.0
	for p in track:
		var s := ((p as Vector3) - end).dot(dir)
		back = maxf(back, -s)
		var sg := int(signf(s))
		if absf(s) > SWING_MIN and sg != side:
			if side != 0:
				swings += 1
			side = sg
	return {"peak": peak.length(), "settle": (last + 1) * DT, "swings": swings,
			"over": back / maxf(peak.length(), 1e-5)}
