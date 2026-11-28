extends RefCounted
## --kael-tap-clip --shots-dir=<dir>: Kael's tap Smash, charged hold, and ult cast mid-sprint and mid-jump, in the
## Training Area at the match camera, 15 fps: <dir>/<case>/f000.png... Needs a renderer (jobq --needs gpu).
## Never touches the save.

const AKCheck := preload("res://tools/archetype_check.gd")
const STEPS := 4  # 60 Hz steps per 15 fps frame
const FRAMES := 24

var main: Node


func run(mn: Node, _who := "") -> void:
	main = mn
	Save.no_write = true
	var dir := "user://kael_tap_clip"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	for c in ["tap", "hold", "ult_sprint", "ult_jump"]:
		await _case(c, dir.path_join(c))
	main.get_tree().quit()


func _case(c: String, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var chk := AKCheck.new()
	chk.main = main
	var r = chk.setup("juggernaut", 2.5)
	var m: Match = r[0]
	var pl: Hunter = r[1]
	var tgt: Hunter = r[2]
	var kt: JuggernautKit = pl.ak
	if main.get("fade") != null:
		await main.fade.reveal(0.01)
	if m.hud:
		m.hud.visible = false
	kt.ch_rmb = 1.0
	kt.cd["rmb"] = 0.0
	chk.aim_at(pl, tgt.pos)
	for i in 10:
		await _frame(m)
	for n in FRAMES:
		for s in STEPS:
			_drive(c, chk, m, pl, kt, n * STEPS + s)
			m.step(Match.DT)
		await _frame(m)
		m.get_viewport().get_texture().get_image().save_png(out.path_join("f%03d.png" % n))
	print(
		(
			"KCLIP %s %d frames, foe took %.0f, vel %s -> %s"
			% [c, FRAMES, chk.dmg(tgt), kt.riposte.vel_before, kt.riposte.vel_after]
		)
	)
	m.queue_free()
	await main.get_tree().process_frame


## What the player does at step `i` of the case.
func _drive(c: String, chk, m: Match, pl: Hunter, kt: JuggernautKit, i: int) -> void:
	chk.aim_at(pl, pl.pos + Vector3(4.0, 0, 0))
	match c:
		"tap":
			if i == 0:
				chk.tap(m, pl)
		"hold":
			pl.inp["sec_hold"] = i < 40
			if i == 0:
				kt.press_rmb()
		"ult_sprint":
			pl.inp["move"] = Vector2(1, 0)
			if i == 30:
				kt.cd["x"] = 0.0
				kt.riposte.start()
		"ult_jump":
			if i == 10:
				pl.vel.y = 6.0
			if i == 20:
				kt.cd["x"] = 0.0
				kt.riposte.start()


func _frame(m: Match) -> void:
	var span := STEPS * Match.DT
	if m.cam and m.player:
		Input.warp_mouse(m.cam.unproject_position(m.player.pos))
	m.hitstop = 0.0
	m.slowmo = 0.0
	m.acc = Match.DT * 0.999 - DashPace.frame_dt(m, span)
	m._process(span)
	await main.get_tree().process_frame
