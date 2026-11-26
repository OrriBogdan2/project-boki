extends RefCounted
## --glide-anim-check (docs/art/wardens/MESHY_NATIVE.md "Glide and dive"): every Hunter's body under an open glider
## plays its glide clip, never the walk, run, idle or jump; in the glider's dive its dive clip; on touchdown the ground
## clip again. On Meshy's skeleton the shared pose (WardenGlidePose) holds the hands up on the lines over the shoulders
## and the feet together under or behind the hips; the dive sweeps the hands down past the shoulders. On the contract
## path (Breaker) the clips' glide layer owns the body. The farm avatar (the Empty, on the procedural rig) hangs its
## legs together under the glider.

const DT := 1.0 / 60.0
const SETTLE := 0.6  # s past the open before the pose is read (WardenNative.AIR_FADE is 0.3)
const FEET_GAP := 2.2  # the feet stay within this many hip widths of each other (a stride is ~4)
const FEET_AHEAD := 0.05  # m, Meshy scale: the feet hang no farther forward of the hips than this
const FARM_LEGS_APART := 0.1  # rad: the farm avatar's hips swing at most this far apart in a glide (a stride: ~1)
const GLIDE := {"grounded": false, "gliding": true, "vel": Vector3(0.0, -1.5, -6.0), "cast": 99.0}
const DIVE := {"grounded": false, "diving": true, "vel": Vector3(0.0, -14.0, -9.0), "cast": 99.0}
const RUN := {"grounded": true, "vel": Vector3(0.0, 0.0, -4.6), "cast": 99.0}

var bad := 0
var n := 0
var holder: Node3D


func ok(cond: bool, what: String) -> void:
	n += 1
	print("GLIDEANIM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	holder = Node3D.new()
	main.add_child(holder)
	ok(Arch.ids().size() == 13, "13 Hunters (%d)" % Arch.ids().size())
	for a in Arch.ids():
		var m := Models.hunter(Arch.weight(a), Data.TEAM_COLORS[0], Arch.signature(a), "", PlayerLook.neutral(), a)
		holder.add_child(m)
		if WardenNative.on(a):
			await _native(main, a, m)
		else:
			await _contract(main, a, m)
		m.free()
	await _farm(main)
	print("GLIDEANIM DONE %d checks, %d failed" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)


func _feed(main: Node, m: Node3D, s: Dictionary, secs: float) -> void:
	m.set_meta(WardenClips.STATE, s.duplicate())
	for i in maxi(2, ceili(secs / DT)):
		await main.get_tree().process_frame


func _native(main: Node, a: String, m: Node3D) -> void:
	var nat := m.get_node("Warden/Native") as WardenNative
	var p := nat.player
	var ground := ["walk", "run", "idle", "jump"].map(func(st): return String(nat.plays[st]))
	await _feed(main, m, RUN, 0.1)
	await _feed(main, m, GLIDE, DT)
	var glide := String(nat.plays.get("glide", ""))
	ok(
		p.current_animation == glide and glide not in ground,
		"%s: gliding plays %s (%s)" % [a, glide, p.current_animation]
	)
	p.advance(SETTLE)
	_glide_pose(a, nat)
	await _feed(main, m, DIVE, DT)
	var dive := String(nat.plays.get("dive", ""))
	ok(p.current_animation == dive and dive not in ground, "%s: diving plays %s (%s)" % [a, dive, p.current_animation])
	p.advance(SETTLE)
	var b := _body(nat.skel)
	ok(
		b["hand"].y < b["shoulder"].y,
		"%s: the dive sweeps the hands down (%.2f under the shoulders)" % [a, b["shoulder"].y - b["hand"].y]
	)
	await _feed(main, m, RUN, DT)
	ok(p.current_animation == String(nat.plays["run"]), "%s: touchdown runs again (%s)" % [a, p.current_animation])


## The glide pose as drawn: both hands over their shoulders, the feet together, under or behind the hips.
func _glide_pose(a: String, nat: WardenNative) -> void:
	var b := _body(nat.skel)
	ok(
		b["hand"].y > b["shoulder"].y,
		"%s: the hands hold the lines over the shoulders (+%.2f)" % [a, b["hand"].y - b["shoulder"].y]
	)
	ok(
		b["feet_gap"] < FEET_GAP * b["hip_w"],
		"%s: the feet hang together (%.2f hip widths)" % [a, b["feet_gap"] / b["hip_w"]]
	)
	ok(
		b["foot"].z < b["hips"].z + FEET_AHEAD,
		"%s: the feet trail (%.2f m ahead of the hips)" % [a, b["foot"].z - b["hips"].z]
	)


## The posed skeleton in its rest body frame (x left, y up, z forward): the lower of the two hands and the lower
## shoulder, the forward-most foot, the hips, the feet's gap and the hips' width.
func _body(sk: Skeleton3D) -> Dictionary:
	var inv := WardenGlidePose.frame(sk).inverse()
	var at := func(nm: String) -> Vector3: return inv * sk.get_bone_global_pose(sk.find_bone(nm)).origin
	var hl: Vector3 = at.call("LeftHand")
	var hr: Vector3 = at.call("RightHand")
	var fl: Vector3 = at.call("LeftFoot")
	var fr: Vector3 = at.call("RightFoot")
	var sl: Vector3 = at.call("LeftArm")
	var sr: Vector3 = at.call("RightArm")
	return {
		"hand": hl if hl.y < hr.y else hr,
		"shoulder": sl if sl.y < sr.y else sr,
		"foot": fl if fl.z > fr.z else fr,
		"hips": at.call("Hips"),
		"feet_gap": fl.distance_to(fr),
		"hip_w": (at.call("LeftUpLeg") as Vector3).distance_to(at.call("RightUpLeg")),
	}


## The contract path: the clips' glide layer owns the body (its clip none of the ground ones), and lets go on landing.
func _contract(main: Node, a: String, m: Node3D) -> void:
	var clips: WardenClips = m.get_node("Warden/Sync").clips
	var air: Dictionary = clips.d["air"]
	var lc: Dictionary = clips.d["loco"]
	var ground := [lc["idle"], lc["walk"], lc["run"], air["rise"], air["fall"]]
	ok(
		String(air["glide"]) not in ground,
		"%s: the glide clip %s is none of the ground or jump clips" % [a, air["glide"]]
	)
	await _feed(main, m, RUN, 0.1)
	await _feed(main, m, GLIDE, SETTLE)
	ok(
		clips.glide_w >= 0.999 and clips.air_w >= 0.999,
		"%s: gliding, the glide clip owns the body (%.2f)" % [a, clips.glide_w]
	)
	await _feed(main, m, DIVE, SETTLE)
	ok(clips.glide_w >= 0.999, "%s: diving holds the glide clip (%.2f)" % [a, clips.glide_w])
	await _feed(main, m, RUN, SETTLE * 2.0)
	ok(clips.air_w <= 0.001, "%s: touchdown, the legs again (air %.2f)" % [a, clips.air_w])


## The farm: a fresh save's avatar (your own Empty, on the procedural rig: no Hunter model) opens its glider in the air
## over the farm; its legs hang together and trailing, swaying as one, never a stride's or a paddle's opposite swing.
func _farm(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Save.d["tutorial"]["home"] = true
	Save.d["tutorial"]["day1_done"] = true
	Econ.ensure()
	var hm = load("res://scripts/home/home.gd").new()
	main.add_child(hm)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	while hm.building:
		await main.get_tree().process_frame
	hm.set_process(false)
	hm.py = hm._ground_h(hm.ppos.x, hm.ppos.z) + 12.0
	hm.pvy = 0.0
	hm.gliding = false
	var apart := 0.0
	var fwd := -9.0
	for i in 100:
		if i == 10:  # (a press once it is falling: the first steps still read the ground)
			Input.action_press("glide")
		hm._move_player(DT)
		await main.get_tree().process_frame
		var an: HunterAnim = hm.p_anim
		if i >= 55:  # (the glide eased in)
			apart = maxf(apart, absf(an.leg_l.rotation.x - an.leg_r.rotation.x))
			fwd = maxf(fwd, maxf(an.leg_l.rotation.x, an.leg_r.rotation.x))
	Input.action_release("glide")
	var k: float = hm.p_anim.glide_k
	ok(hm.gliding and k > 0.95, "farm: the avatar glides (gliding %s, glide pose %.2f)" % [hm.gliding, k])
	ok(apart <= FARM_LEGS_APART, "farm: the legs hang together, no paddle (at most %.2f rad apart)" % apart)
	ok(fwd <= 0.0, "farm: the legs trail (hips %.2f rad forward at most)" % fwd)
	hm.queue_free()
