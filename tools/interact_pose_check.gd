extends RefCounted
## --interact-pose-check: every Hunter plays a body action, not idle, for each interact state (a pickup's reach-lift-settle,
## a chest's lid, a deathbox, a revive, a hatch key, a console). Per Hunter and state, the pose is read off the skeleton
## through the real render path (Match.step, Hunter.render, the Sync node) and compared with the same Hunter standing in
## idle: a hand or the head must move at least POSE_MIN of the Hunter's height. Moving off cancels the pose at once, and
## the lift beat ends on its own. Never touches the save.

const DT := 1.0 / 60.0
const STATES := ["lift", "chest", "loot", "revive", "key", "console"]
const POSE_MIN := 0.08         # of the Hunter's height: how far a hand (against the hips) or the head must move off idle
const CANCEL_S := 0.25         # s: after the Hunter walks off, the pose is gone

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("INTERACT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frame(m: Match, h: Hunter) -> void:
	m.step(DT)
	h.render(DT, 1.0)
	var sync: Node = h.model.get_node("Warden/Sync")
	sync.set_process(false)
	sync.call("_process", DT)

## Hand and head places for the pose now: [hand.L, hand.R, head] against the hips, and the head's height.
func _read(h: Hunter) -> Array:
	var sk := h.model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var hips := sk.get_bone_global_pose(WardenSkeleton.find(sk, "hips")).origin
	var out: Array = []
	for nm in ["hand.L", "hand.R"]:
		out.append(sk.get_bone_global_pose(WardenSkeleton.find(sk, nm)).origin - hips)
	var head := sk.get_bone_global_pose(WardenSkeleton.find(sk, "head")).origin
	out.append(head)
	return out

## How far this pose is from the idle one, in Hunter heights.
func _off(a: Array, idle: Array, height: float) -> float:
	var d := maxf((a[0] as Vector3).distance_to(idle[0]), (a[1] as Vector3).distance_to(idle[1]))
	return maxf(d, (a[2] as Vector3).distance_to(idle[2])) / height

func run(main: Node) -> void:
	Save.no_write = true
	var A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var clip = load("res://tools/clip_check.gd")
	for arch in clip.OWN_MODELS:
		var r: Array = A.setup(String(arch), 11.0, "", true)
		var m: Match = r[0]
		var h: Hunter = r[1]
		for f in 30:
			_frame(m, h)
		var idle := _read(h)
		var height := (idle[2] as Vector3).length() * 1.3
		var line := "%s:" % arch
		for st in STATES:
			var peak := 0.0
			for f in 54:
				h.set_hold(String(st), 0.15)
				_frame(m, h)
				peak = maxf(peak, _off(_read(h), idle, height))
			line += " %s %.2f" % [st, peak]
			ok(peak >= POSE_MIN, "%s plays a pose for %s (%.2f of its height)" % [arch, st, peak])
			for f in 40:
				_frame(m, h)
		print("INTERACT peaks ", line)
		h.set_hold("lift", HunterAnim.LIFT_T)
		var t := 0.0
		while t < HunterAnim.LIFT_T + 0.3:
			_frame(m, h); t += DT
		ok(h.holding() == "" and h.anim.act_k < 0.2, "%s: the lift beat ends on its own" % arch)
		h.set_hold("chest", 5.0)
		for f in 30:
			_frame(m, h)
		h.vel = Vector3(4.0, 0.0, 0.0)
		h.inp["move"] = Vector2(1, 0)
		h.ctrl = "idle"
		var k_held: float = h.anim.act_k
		var steps := int(CANCEL_S / DT)
		for f in steps:
			h.vel = Vector3(4.0, 0.0, 0.0)
			_frame(m, h)
		ok(k_held > 0.8 and h.anim.act_k < 0.1, "%s: moving off blends the pose out (%.2f -> %.2f in %.2fs)" % [arch, k_held, h.anim.act_k, CANCEL_S])
		h.set_hold("", 0.0)
		m.queue_free()
	print("INTERACT_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
