extends RefCounted
## --home-verbs-check: the garden moves on your body at home (HunterVerbs, HomeVerbs).
##   1. each move plays on a rig: the act is picked up, the pose is the move's (crouched and reaching;
##      the pat bobs; the lift goes down then up to the chest; the toss swings back then through; arms up
##      for the cheer), then it ends and the body goes back to standing
##   2. the Empty (the home body, planted feet by EmptyGait) pats, feeds and lifts a small and a big Boki:
##      the hand reaches the head, the mouth or both flanks, the hips go lower for the small one, and no
##      sole point slides; the cheer keeps the feet planted too
##   3. the existing paths trigger them: petting, tossing a ball, feeding, picking up (the lift hands
##      over to the carry hold, the Boki comes up with the hands), a great drill mark
## reach() is shared with --clip-check (the hand on its target at the peak of each care move).
## --home-verbs-shots=<dir> makes the strip. Never touches the real save.

const FPS := 60.0
const SETTLE := 40
const LIFT := 0.3         # m: how far a hand goes above or below its rest for "up" and "low"
const DOWN := 0.1         # m: the lift's hands this far below their rest at the grip (held at the chest, above it)
const HOLD := {"pat": 0.7, "feed": 0.58, "lift": 0.31, "cheer": 0.45}      # s: the middle of each move's hold
const CARE := ["pat", "feed", "lift"]      # the moves that reach for the Boki
## Boki stand-ins: [height, width] m, the smallest and the biggest Boki (Models.kin: 0.5 to 1.23 m tall).
const BOKI := {"small": Vector2(0.5, 0.8), "big": Vector2(1.25, 0.8)}
const TOUCH_CM := 8.0     # cm: the hand this near the Boki's surface (head, mouth; a head out of reach: face)
const DEEPER_CM := 8.0    # cm: feeding, the hips this much lower for the small Boki than the big one
const HIGHER_CM := 40.0   # cm: petting, the hand this much higher on the big Boki's head than the small one's
const PLANT_Y := 0.012    # m: a sole point is on the floor while this near it (as --home-gait-check)
const FEET_CM := 1.0      # cm: a sole point on the floor slides no further (the heel may lift: no ankle)

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("HOMEVERBS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--home-verbs-shots="):
			await load("res://tools/home_verbs_shots.gd").new().run(m, String(a).substr(19))
			return
	Save.no_write = true
	_rig()
	await _empty_reach()
	await _paths()
	print("HOMEVERBS DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ the rig
func _hands(a: HunterAnim) -> Array:
	var m := a.model
	return [m.to_local(a.hand_l.global_position), m.to_local(a.hand_r.global_position)]

func _rest(a: HunterAnim, v: HomeVerbs) -> void:
	for i in SETTLE:
		a.update(1.0 / FPS, {"vel": Vector3.ZERO, "face": 0.0, "grounded": true, "holster": true}.merged(v.step(0.0)))

## Plays `verb` for its length; calls probe(a, t) every frame.
func _play(a: HunterAnim, verb: String, probe: Callable) -> void:
	var v := HomeVerbs.new()
	v.play(verb)
	var n := int(float(HunterVerbs.LENGTH[verb]) * FPS)
	for i in n:
		var s := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true}.merged(v.step(1.0 / FPS))
		a.update(1.0 / FPS, s)
		probe.call(a, float(i) / FPS)

func _rig() -> void:
	var holder := Node3D.new()
	main.add_child(holder)
	var model := Models.hunter("medium", Data.TEAM_COLORS[0], "smg", "", Unmasked.default_look(), "")
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	var a := HunterAnim.new(model)
	_rest(a, HomeVerbs.new())
	var rest: Array = _hands(a)
	for verb in HunterVerbs.ACTS:
		var seen := {"act": false, "lo": INF, "hi": -INF, "fwd_l": 0.0, "fwd_r": 0.0, "back_r": -INF, "up": 0.0}
		_play(a, verb, func(an: HunterAnim, _t: float):
			var h := _hands(an)
			seen["act"] = seen["act"] or an.act_kind == verb
			seen["lo"] = minf(seen["lo"], h[1].y)
			seen["hi"] = maxf(seen["hi"], h[1].y)
			seen["fwd_l"] = minf(seen["fwd_l"], h[0].z - rest[0].z)
			seen["fwd_r"] = minf(seen["fwd_r"], h[1].z - rest[1].z)
			seen["back_r"] = maxf(seen["back_r"], h[1].z - rest[1].z)
			seen["up"] = maxf(seen["up"], minf(h[0].y, h[1].y) - rest[1].y))
		ok(seen["act"], "%s: the body takes the move" % verb)
		var bob: float = seen["hi"] - seen["lo"]
		match verb:
			"feed":
				ok(seen["fwd_l"] < -LIFT and seen["fwd_r"] < -LIFT, "feed: both hands held out in front")
			"pat":
				ok(bob > 0.05 and seen["fwd_r"] < -LIFT, "pat: the right hand reaches out and bobs (%.2f)" % bob)
			"lift":
				var lift := "lift: the hands go down to it, then up to the chest (%.2f to %.2f, rest %.2f)"
				var down_up: bool = seen["lo"] < rest[1].y - DOWN and seen["hi"] > rest[1].y + 0.02
				ok(down_up, lift % [seen["lo"], seen["hi"], rest[1].y])
			"toss":
				ok(seen["back_r"] > 0.1 and seen["fwd_r"] < -LIFT, "toss: the hand goes back then through")
			"cheer":
				ok(seen["up"] > LIFT, "cheer: both hands above where they rest (+%.2f)" % seen["up"])
		for i in SETTLE * 2:
			a.update(1.0 / FPS, {"vel": Vector3.ZERO, "face": 0.0, "grounded": true, "holster": true})
		ok(a.act_kind == "" and _hands(a)[1].distance_to(rest[1]) < 0.08, "%s: ends and the body stands again" % verb)
	holder.free()
	var held := HunterVerbs.hands("lift", HunterVerbs.LENGTH["lift"], Vector3(-0.2, 0, 0), Vector3(0.2, 0, 0))
	ok(held[1].is_equal_approx(Vector3(0.2, 0, 0) + HunterVerbs.CARRY_L * Vector3(-1, 1, 1)),
			"lift: ends on the carry hold, so the carry takes over with no pop")
	var legs := [HunterVerbs.legs("feed", 0.55), HunterVerbs.legs("cheer", 0.17), HunterVerbs.STAND]
	ok(legs[0].y < legs[2].y - 1.0 and legs[0].x > legs[2].x + 0.5, "feed: knees well bent, a crouch")
	ok(HunterVerbs.pitch("pat", 1.0) > 0.2 and HunterVerbs.pitch("toss", 0.5) > 0.2, "pat and toss lean in")
	ok(HunterVerbs.LENGTH.keys() == HunterVerbs.ACTS, "every move has a length")

# ------------------------------------------------------------------ the Empty reaching for a Boki
## The Empty's care moves at a small and a big Boki stand-in: "verb.size" -> _hold()'s numbers, plus the cheer.
func reach() -> Dictionary:
	var holder := Node3D.new()
	main.add_child(holder)
	var model := Models.hunter("medium", Data.TEAM_COLORS[0], "", "", Unmasked.default_look(), Arch.of_save())
	model.get_node("Rig/Torso/Aim/Gun").free()
	holder.add_child(model)
	await main.get_tree().process_frame
	var a := HunterAnim.new(model)
	var out := {"gait": a.gait != null}
	_rest(a, HomeVerbs.new())
	for size in BOKI:
		var boki := _stand_in(holder, BOKI[size])
		for verb in CARE:
			out["%s.%s" % [verb, size]] = _hold(a, verb, boki)
		boki.free()
	out["cheer"] = _hold(a, "cheer", null)
	holder.free()
	return out

func _empty_reach() -> void:
	var got := await reach()
	ok(got["gait"], "the Empty walks on planted feet (EmptyGait)")
	for size in BOKI:
		for verb in CARE:
			var g: Dictionary = got["%s.%s" % [verb, size]]
			print(("HOMEVERBS %s %s Boki: hand %.1f cm off at %.2f m, %.1f cm from its aim,"
					+ " hips %.2f m, feet slid %.2f cm")
					% [verb, size, g["off_cm"], g["hand"], 100.0 * g["aim_m"], g["hip"], g["feet_cm"]])
			ok(g["off_cm"] <= TOUCH_CM, "%s, %s Boki: the hand touches it (%.1f cm off)" % [verb, size, g["off_cm"]])
			ok(g["feet_cm"] <= FEET_CM, "%s, %s Boki: the feet stay planted (%.2f cm)" % [verb, size, g["feet_cm"]])
	var deeper: float = 100.0 * (got["feed.big"]["hip"] - got["feed.small"]["hip"])
	ok(deeper >= DEEPER_CM, "feed: the hips go %.0f cm lower for the small Boki" % deeper)
	var higher: float = 100.0 * (got["pat.big"]["hand"] - got["pat.small"]["hand"])
	ok(higher >= HIGHER_CM, "pat: the hand goes %.0f cm higher for the big Boki's head" % higher)
	ok(got["cheer"]["feet_cm"] <= FEET_CM, "cheer: the feet stay planted (%.2f cm)" % got["cheer"]["feet_cm"])

## A box the size of a Boki, at its hold spot in front of the body (which faces -z).
func _stand_in(holder: Node3D, hw: Vector2) -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(hw.y, hw.x, hw.y)
	mi.mesh = box
	mi.position.y = hw.x * 0.5
	n.add_child(mi)
	holder.add_child(n)
	n.position = HomeVerbs.hold_spot(Vector3.ZERO, Vector3.FORWARD, n)
	return n

## Plays `verb` at `boki`: at the hold, the hips' height, the right hand's height, how far the hand (the
## further of both for the lift) is from the Boki's surface and from its aim (HunterVerbs.aim; the lift's two
## grips GRIP_W either side of it), and how far any sole point slid while it was on the floor.
func _hold(a: HunterAnim, verb: String, boki: Node3D) -> Dictionary:
	var v := HomeVerbs.new()
	v.play(verb, boki)
	var on := {}       # sole index -> where it touched the floor
	var out := {"off_cm": 0.0, "aim_m": 0.0, "hip": 0.0, "hand": 0.0, "feet_cm": 0.0}
	for i in int(float(HunterVerbs.LENGTH[verb]) * FPS):
		a.update(1.0 / FPS, {"vel": Vector3.ZERO, "face": 0.0, "grounded": true}.merged(v.step(1.0 / FPS)))
		var now := _soles(a.model)
		for j in now.size():
			var p: Vector3 = now[j]
			if p.y > PLANT_Y:
				on.erase(j)
				continue
			if not on.has(j):
				on[j] = p
			out["feet_cm"] = maxf(out["feet_cm"], 100.0 * Vector2(p.x - on[j].x, p.z - on[j].z).length())
		if i == int(float(HOLD[verb]) * FPS):
			out["hip"] = (a.model.get_node("Rig/Legs/LegL") as Node3D).global_position.y
			out["hand"] = a.hand_r.global_position.y
			if boki != null:
				var hands: Array = [a.hand_r] if verb != "lift" else [a.hand_l, a.hand_r]
				for j in hands.size():
					var hand: Vector3 = (hands[j] as Node3D).global_position
					var aim := a.act_aim
					if verb == "lift":
						var side := Vector3(HunterVerbs.GRIP_W * (2 * j - 1), 0.0, 0.0)
						aim = a.torso.to_global(a.torso.to_local(aim) + side)
					out["off_cm"] = maxf(out["off_cm"], 100.0 * _off_surface(HomeVerbs.bounds(boki), hand))
					out["aim_m"] = maxf(out["aim_m"], hand.distance_to(aim))
	_rest(a, v)
	return out

## How far `p` is from the surface of `b`, outside or in.
func _off_surface(b: AABB, p: Vector3) -> float:
	if not b.has_point(p):
		return p.distance_to(p.clamp(b.position, b.end))
	var lo := p - b.position
	var hi := b.end - p
	return minf(minf(minf(lo.x, lo.y), minf(lo.z, hi.x)), minf(hi.y, hi.z))

## World positions of the six sole points.
func _soles(m: Node3D) -> Array:
	var out: Array = []
	for side in ["L", "R"]:
		var knee := m.get_node("Rig/Legs/Leg" + side + "/Knee") as Node3D
		for p in FootPlant.SOLE:
			out.append(knee.global_transform * (p as Vector3))
	return out

# ------------------------------------------------------------------ the home paths
func _paths() -> void:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["level"] = 5
	Care.ensure(k)
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}
	d["items"]["kibble"] = 3
	Save.d = d
	HomeLayout.ensure(d)
	var home = await main._hb_home()
	for i in 900:
		if home.root_ui != null and home.player != null and home.hb != null:
			break
		await main.get_tree().process_frame
	home._close_panel()
	home.talk_cd = 1.0e9
	var ke: Dictionary = home._kin_entry(k)
	ok(not ke.is_empty(), "the home has the Boki")
	await _pick_up(home, ke)
	home._pet_kin(ke)
	ok(home.verbs.act == "pat", "petting plays the pat")
	home.verbs.act = ""
	home._play_with_kin(ke)
	ok(home.verbs.act == "toss", "tossing a ball plays the toss")
	home.verbs.act = ""
	home._care_feed(k, "kibble")
	ok(home.verbs.act == "feed", "feeding plays the crouch-and-offer")
	home.verbs.act = ""
	if home.yard == null:      # a farm with no training yard built: stand one up so the drill can run
		home.yard = Models.training_yard()
		home.add_child(home.yard)
	home._start_drill(k, "speed")
	for i in 60:
		await main.get_tree().process_frame
	ok(not home.train.is_empty() and home.verbs.act == "", "a drill is running, no cheer yet")
	home.train["wait"] = 0.0
	home.train["bar"].m = home.train["bar"].zone      # marker on the gold: a great press
	home._train_hit()
	ok(home.verbs.act == "cheer", "a great drill mark plays the cheer")
	home.verbs.act = ""
	for i in 30:
		await main.get_tree().process_frame
	ok(home.p_anim != null and home.p_anim.model == home.player, "the home player body is animated")
	home.queue_free()
	await main.get_tree().process_frame

## Holding interact on the Boki (HomeCarry.press_hold) plays the lift: you stand still, it waits on the ground
## until the hands close, rides them up, and the carry hold takes over when the lift ends.
func _pick_up(home, ke: Dictionary) -> void:
	home.carry.press_hold(ke)
	ok(home.carry.carrying() and home.verbs.act == "lift", "picking a Boki up plays the lift")
	var still: bool = home.carry.speed_mul() == 0.0 and home.carry.anim_state().is_empty()
	ok(still, "you stand still for the lift, no carry hold yet")
	var n: Node3D = ke["node"]
	var ground := n.position.y
	var y_grip := INF
	for i in 900:
		await main.get_tree().process_frame
		if home.verbs.act != "lift":
			break
		if home.verbs.t <= HunterVerbs.LIFT_GRIP:
			y_grip = n.position.y
	ok(is_equal_approx(y_grip, ground), "it stays on the ground until the hands have it")
	ok(n.position.y > ground + 0.5, "then it rides up to the chest (+%.2f m)" % (n.position.y - ground))
	ok(home.verbs.act == "" and home.carry.anim_state().get("act", "") == home.carry.mode, "the carry hold takes over")
	home.carry.drop()

