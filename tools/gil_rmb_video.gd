extends RefCounted
## --gil-rmb-video --shots-dir=<dir>: Gil's RMB is a press, and R again leaps him off the wave (owner 11-17), through
## the game's own camera and HUD, for the owner's review. Recorded like tools/gameplay_media.gd (a child Godot under the
## movie writer, 30 fps, <dir>/clip1.avi); encode with ffmpeg. Run it on a GPU worker (jobq --needs gpu).
##   0-1 s     he stands, the next potion glowing
##   1-4.4 s   RMB held down for 3 s: one potion flies, then nothing more (no longer throw, no aim ring)
##   5.4 s     R: the wave starts; at 5.7 s R again: he leaps off at once, shield up, the wave gone
##   8.6 s     the clip ends

const GAP := 7.0
const HOLD_AT := 1.0
const HOLD_S := 3.0
const WAVE_AT := 5.4
const LEAP_AT := 5.7
const END_AT := 8.6

var main: Node

func run(main_node: Node) -> void:
	main = main_node
	var gm = load("res://tools/gameplay_media.gd").new()
	gm.main = main
	var child := false
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		child = child or arg == "--media-child"
		if arg.begins_with("--shots-dir="):
			gm.dir = arg.substr(12)
	if String(gm.dir).is_relative_path():
		gm.dir = ProjectSettings.globalize_path("res://").path_join(gm.dir)
	DirAccess.make_dir_recursive_absolute(gm.dir)
	gm.clip = 1
	if not child:
		gm._record("1920x1080")
		return
	Save.no_write = true
	Settings.v["tips"] = false
	await gm._start("gil", "cindle")
	var P: Hunter = gm.m.player
	var K: GilKit = P.ak
	P.lvl = 6
	var base: Vector3 = gm._ground(P.pos)
	var foe: Hunter = gm._hunter("foe", 1, "juggernaut", "pebbit", gm._ground(base + Vector3(GAP, 0, 0)))
	foe.teleport(foe.pos)
	gm._zoom(0.9)
	gm._mark("start")
	var sent := {"hold": false, "wave": false, "leap": false}
	await gm._go(END_AT, func(t: float):
		foe.hp = foe.max_hp
		P.inp["aim"] = foe.pos + Vector3(0, 0.9, 0)
		K.ch_rmb = 2.0
		var holding := t >= HOLD_AT and t < HOLD_AT + HOLD_S
		P.inp["sec_hold"] = holding
		P.inp["sec"] = holding
		if holding and not sent["hold"]:
			sent["hold"] = true
			K.press_rmb()
			gm._mark("rmb_down")
		if t >= WAVE_AT and not sent["wave"]:
			sent["wave"] = true
			HunterKeys.ult_pressed(P)
			gm._mark("wave")
		if t >= LEAP_AT and not sent["leap"]:
			sent["leap"] = true
			HunterKeys.ult_pressed(P)
			gm._mark("leap_off wave_gone=%s" % str(K.wave.is_empty())),
		func(_t: float): return P.pos, true)
	print("MEDIA_DONE clip=1 thrown_hold=%s" % str(sent["hold"]))
	main.get_tree().quit(0)
