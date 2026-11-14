extends RefCounted
## --stride-check: a Hunter's run start and stop through the real match code (WardenStride). Per Hero with clips:
## a start leans forward and the lean is gone once the speed is built; a let-go from a run slides 0.3-0.55 m with the
## weight shifted back and the planted foot sliding under 3 cm; a dash the frame after the stop, a knock, and a keyed
## move show none of it. Never touches the save.

const DT := 1.0 / 60.0
const SLIDE_MIN := 0.30        # m: the stop slide (decision 0020's 0.3-0.5 m, a little over for the heavy)
const SLIDE_MAX := 0.55
const FOOT_MAX := 0.03         # m: a planted foot may stray this far from where its contact began
const PLANT_Y := 0.015         # m: a foot this near its standing sole height is planted
const RUN_UP := 40             # frames: a run-up reaches the Hero's run speed in 6 and the strip is 10 m either way
const HEROES := ["gunslinger", "juggernaut", "bulwark", "dolm", "rimewright"]

var A
var bad := 0
var sole := [0.0, 0.0]         # m: each foot's height over the ground while he stands

func ok(cond: bool, what: String) -> void:
	print("STRIDE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frame(m: Match, P: Hunter) -> void:
	m.step(DT)
	P.render(DT, 1.0)
	var sync: Node = P.model.get_node("Warden/Sync")
	sync.set_process(false)
	sync.call("_process", DT)

func _stride(P: Hunter) -> WardenStride:
	return (P.model.get_node("Warden/Sync").get("clips") as WardenClips).stride

func _feet(P: Hunter) -> Array:
	var sk := WardenGlb.skeleton(P.model.get_node("Warden"))
	var out := []
	for sd in ["L", "R"]:
		var knee := sk.get_bone_global_pose(WardenSkeleton.find(sk, "shin." + sd))
		var hip := sk.get_bone_global_pose(WardenSkeleton.find(sk, "thigh." + sd))
		var shin := knee.basis.y.normalized() * knee.origin.distance_to(hip.origin)
		out.append(sk.global_transform * (knee.origin + shin))
	return out

## Back to the start of the strip, standing and settled.
func _home(m: Match, P: Hunter, home: Vector3) -> void:
	P.inp["move"] = Vector2.ZERO
	P.teleport(home)
	P.vel = Vector3.ZERO
	_frames(m, P, 90)

func _frames(m: Match, P: Hunter, n: int) -> void:
	for f in n:
		_frame(m, P)

func _shown(P: Hunter) -> bool:
	var st := _stride(P)
	return st.phase != 0 or st.stop_w > 0.0 or st.lean_w > 0.0 or st.pin_w > 0.0

## Lets go of a run and follows the planted feet to a stop: [slide m, worst planted-foot slide m, peak weight].
## A foot is planted while it sits within PLANT_Y of its standing sole height; its slide is how far it strays from where
## that contact began.
func _stop(m: Match, P: Hunter) -> Array:
	P.inp["move"] = Vector2(0.0, -1.0)
	_frames(m, P, RUN_UP)
	var from := P.pos
	P.inp["move"] = Vector2.ZERO
	var start := [Vector3.INF, Vector3.INF]
	var worst := 0.0
	var peak := 0.0
	for f in 40:
		_frame(m, P)
		var now := _feet(P)
		for i in 2:
			var foot: Vector3 = now[i]
			if foot.y - P.pos.y > sole[i] + PLANT_Y:
				start[i] = Vector3.INF
				continue
			if start[i] == Vector3.INF:
				start[i] = foot
			worst = maxf(worst, Vector2(foot.x - start[i].x, foot.z - start[i].z).length())
		peak = maxf(peak, _stride(P).stop_w)
	return [from.distance_to(P.pos), worst, peak]

## A run-up's first frames: how far the start lean got, and whether any is left at the steady run.
func _start(m: Match, P: Hunter) -> Array:
	P.inp["move"] = Vector2(0.0, -1.0)
	var lean := 0.0
	for f in RUN_UP:
		_frame(m, P)
		lean = maxf(lean, _stride(P).lean_w)
	return [lean, _stride(P).lean_w]

func _skips(id: String, m: Match, P: Hunter, home: Vector3) -> void:
	P.inp["move"] = Vector2(0.0, -1.0)
	_frames(m, P, RUN_UP)
	P.inp["move"] = Vector2.ZERO
	_frames(m, P, 3)
	ok(_stride(P).phase == 1 and _stride(P).stop_w > 0.0, "%s: the stop is on three frames into the slide" % id)
	P.inp["dash"] = true
	_frame(m, P)
	P.inp["dash"] = false
	ok(P.dashes < P.max_dashes() and not _shown(P), "%s: a dash the frame after shows no stop pose" % id)
	_home(m, P, home)
	P.vel = Vector3(0.0, 0.0, -9.0)
	var knocked := false
	for f in 40:
		_frame(m, P)
		knocked = knocked or _shown(P)
	ok(not knocked, "%s: a knock slows to a halt with no stop pose" % id)
	P.inp["move"] = Vector2(0.0, -1.0)
	_frames(m, P, RUN_UP)
	P.inp["move"] = Vector2.ZERO
	_frames(m, P, 3)
	P.ak.anim_id = "cast"
	P.ak.anim_at = m.time
	_frame(m, P)
	ok(not _shown(P), "%s: a keyed move the frame after shows no stop pose" % id)
	P.ak.anim_id = ""

func run(main: Node) -> void:
	Save.no_write = true
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	for id in HEROES:
		var r: Array = A.setup(id, 11.0, "", true)
		var m: Match = r[0]
		var P: Hunter = r[1]
		_frames(m, P, 90)
		if (P.model.get_node("Warden/Sync").get("clips") as WardenClips) == null:
			continue
		var rest := _feet(P)
		sole = [rest[0].y - P.pos.y, rest[1].y - P.pos.y]
		var go := _start(m, P)
		ok(go[0] >= 0.3 and go[1] <= 0.001, "%s: start lean %.2f, gone at the run %.2f" % [id, go[0], go[1]])
		_home(m, P, r[4])
		var s := _stop(m, P)
		ok(s[0] >= SLIDE_MIN and s[0] <= SLIDE_MAX, "%s: the stop slides %.3f m" % [id, s[0]])
		ok(s[1] <= FOOT_MAX, "%s: the planted foot slides %.3f m in the stop" % [id, s[1]])
		ok(s[2] >= 0.9, "%s: the weight shifts back (%.2f)" % [id, s[2]])
		_home(m, P, r[4])
		_skips(id, m, P, r[4])
		m.queue_free()
	print("STRIDE_CHECK_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
