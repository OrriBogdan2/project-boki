extends "res://tools/archetype_check.gd"
## --recast-cue-shots --shots-dir=<dir>: RecastCue's review screenshots (run under a renderer, jobq --needs gpu).
## Every two-step kit with its recast open (the check's CASES), foe state on the target where the kit has one, and
## each frame twice: recast_<hero>_<slot>_own.png as the owner sees it (the cue's slot, marker and badges) and
## recast_<hero>_<slot>_foe.png as the target sees the same moment (the kit's world art only). Then EXPIRED and the
## payoff flash. The match is paused (set_process off) so each frame holds the moment.

const RecastCheck := preload("res://tools/recast_cue_check.gd")

var dir := ""

func _grab(file: String) -> void:
	for i in 6:
		await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join("recast_%s.png" % file))
	print("RECASTSHOT ", file)

func _scene(hero: String) -> Array:
	var s := setup(hero, 6.0)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var P: Hunter = s[1]
	P.ak.cd["e"] = 0.0
	return s

## Steps until `slot`'s window is open, then `extra` seconds more.
func _until(m: Match, P: Hunter, slot: String, extra: float) -> void:
	var t := 0.0
	while String(P.ak.recast_window().get("slot", "")) != slot and t < 4.0:
		m.step(DT)
		t += DT
	step(m, extra)

## The kit's own state on the target, so its world art (pips, marker, glow) shows beside the cue's badge.
func _foe_state(P: Hunter, T: Hunter) -> void:
	var key := T.get_instance_id()
	match P.arch:
		"thief": (P.ak as ThiefKit).add_mark(T, 3, true)
		"mage": (P.ak as MageKit).sparks[key] = {"e": T, "n": int(P.ak.res_def()["max"]), "t": 3.0}
		"rimewright":
			(P.ak as RimewrightKit).add_chill(T)
			(P.ak as RimewrightKit).fan_hits[key] = {"t": T, "n": 5, "left": 3.0}
		"ashwick": (P.ak as AshwickKit).add_char(T, 20.0)
		"juggernaut": (P.ak as JuggernautKit).slam_hit[key] = P.m.time

## The same frame from the target's side: it becomes the viewer (the HUD and AimKit follow Match.player) and the
## kit stops being the local one, then one step lets the kit's art follow.
func _as_foe(m: Match, P: Hunter, T: Hunter, file: String) -> void:
	P.ctrl = "idle"
	T.ctrl = "local"
	m.player = T
	m.step(DT)
	await _grab(file)

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	for c in RecastCheck.CASES:
		var hero := String(c[0])
		var slot := String(c[1])
		var s := await _scene(hero)
		var m: Match = s[0]
		var P: Hunter = s[1]
		var T: Hunter = s[2]
		_foe_state(P, T)
		aim_at(P, T.pos + (Vector3(-1.5, 0, 1.5) if hero == "thief" else Vector3.ZERO))
		RecastCheck.first(m, P, slot)
		await _until(m, P, slot, 0.3)
		await _grab("%s_%s_own" % [hero, slot])
		await _as_foe(m, P, T, "%s_%s_foe" % [hero, slot])
		await done(m)
	# Motley's seed left alone runs out: EXPIRED on the E slot
	var s := await _scene("ostra")
	var m: Match = s[0]
	var P: Hunter = s[1]
	aim_at(P, (s[2] as Hunter).pos)
	P.ak.use_e()
	await _until(m, P, "e", 0.0)
	step(m, P.ak.e_t + 0.2)
	await _grab("ostra_expired")
	await done(m)
	# Sable's payoff on a Marked foe: the white burst on the badge
	s = await _scene("thief")
	m = s[0]
	P = s[1]
	(P.ak as ThiefKit).add_mark(s[2], 3, true)
	m.step(DT)
	RecastCue.payoff(P.ak, s[2])
	(P.ak as ThiefKit)._reset_fx(s[2])
	step(m, 0.08)
	await _grab("thief_payoff_flash")
	await done(m)
	main.get_tree().quit(0)
