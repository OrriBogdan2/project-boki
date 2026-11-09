extends RefCounted
## --home-verbs-check: the garden moves on your body at home (HunterVerbs, HomeVerbs).
##   1. each move plays on a rig: the act is picked up, the pose is the move's (crouched and reaching;
##      the pat bobs; the toss swings back then through; arms up for the cheer), then it ends and the
##      body goes back to standing
##   2. the existing paths trigger them: petting, tossing a ball, feeding, a great drill mark
## --home-verbs-shots=<dir> makes the strip. Never touches the real save.

const FPS := 60.0
const SETTLE := 40
const LIFT := 0.3         # m: how far a hand goes above or below its rest for "up" and "low"

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
			seen["lo"] = minf(seen["lo"], h[1].y); seen["hi"] = maxf(seen["hi"], h[1].y)
			seen["fwd_l"] = minf(seen["fwd_l"], h[0].z - rest[0].z); seen["fwd_r"] = minf(seen["fwd_r"], h[1].z - rest[1].z)
			seen["back_r"] = maxf(seen["back_r"], h[1].z - rest[1].z)
			seen["up"] = maxf(seen["up"], minf(h[0].y, h[1].y) - rest[1].y))
		ok(seen["act"], "%s: the body takes the move" % verb)
		match verb:
			"feed": ok(seen["fwd_l"] < -LIFT and seen["fwd_r"] < -LIFT, "feed: both hands held out in front (%.2f, %.2f)" % [seen["fwd_l"], seen["fwd_r"]])
			"pat": ok(seen["hi"] - seen["lo"] > 0.05 and seen["fwd_r"] < -LIFT, "pat: the right hand reaches out and bobs (%.2f)" % (seen["hi"] - seen["lo"]))
			"toss": ok(seen["back_r"] > 0.1 and seen["fwd_r"] < -LIFT, "toss: the hand goes back (%.2f) then through (%.2f)" % [seen["back_r"], seen["fwd_r"]])
			"cheer": ok(seen["up"] > LIFT, "cheer: both hands above where they rest (+%.2f)" % seen["up"])
		for i in SETTLE * 2:
			a.update(1.0 / FPS, {"vel": Vector3.ZERO, "face": 0.0, "grounded": true, "holster": true})
		ok(a.act_kind == "" and _hands(a)[1].distance_to(rest[1]) < 0.08, "%s: ends and the body stands again" % verb)
	holder.free()
	var legs := [HunterVerbs.legs("feed", 1.0), HunterVerbs.legs("cheer", 0.17), HunterVerbs.STAND]
	ok(legs[0].y < legs[2].y - 1.0 and legs[0].x > legs[2].x + 0.5, "feed: knees well bent, a crouch")
	ok(HunterVerbs.pitch("pat", 1.0) > 0.2 and HunterVerbs.pitch("toss", 0.5) > 0.2, "pat and toss lean in")
	ok(HunterVerbs.LENGTH.keys() == HunterVerbs.ACTS, "every move has a length")

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
	home.train["m"] = home.train["zone"]
	home._train_hit()
	ok(home.verbs.act == "cheer", "a great drill mark plays the cheer")
	for i in 30:
		await main.get_tree().process_frame
	ok(home.p_anim != null and home.p_anim.model == home.player, "the home player body is animated")
	home.queue_free()
	await main.get_tree().process_frame
