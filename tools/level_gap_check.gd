extends RefCounted
## --level-gap-check: a rival's plate level badge shows who out-levels you (LevelGap). Plain within
## one level, warm and an up triangle at 2+ above, cool and a down triangle at 2+ below; teammates and
## yourself stay plain; the colours stay apart in luminance (so they survive colour-vision loss).
## --level-gap-shots --shots-dir=<dir> [--res=WxH]: under a real renderer, also asserts the three rivals'
## plates drew with their gap, and saves the screen.

var bad := 0
var dir := ""
var res := Vector2i(1280, 720)

func ok(cond: bool, what: String) -> void:
	print("LEVELGAP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node, mode = "check") -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		elif String(a).begins_with("--res="):
			var wh := String(a).substr(6).split("x")
			res = Vector2i(int(wh[0]), int(wh[1]))
	if mode == "shots":
		DirAccess.make_dir_recursive_absolute(dir)
		DisplayServer.window_set_size(res)
		main.get_window().size = res
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 4, "squad": 1, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true,
		"arch": "thief", "cls": Arch.weight("thief"), "weapon": Arch.signature("thief")})
	m.set_process(false)
	var P: Hunter = m.player
	var rivals: Array = m.hunters.filter(func(x): return x.team != P.team)
	for i in rivals.size():
		rivals[i].ctrl = "idle"
		rivals[i].teleport(P.pos + Vector3(-6.0 + 6.0 * i, 0, -4.0))
	P.lvl = 4
	rivals[0].lvl = 2
	rivals[1].lvl = 3
	rivals[2].lvl = 6
	rivals[2].downed = false
	var gap_below := LevelGap.of(P, rivals[0])
	ok(gap_below == -2 and LevelGap.band(gap_below) == -1, "two below: cool band")
	ok(LevelGap.tint(gap_below) == LevelGap.COOL, "two below: the blue entry")
	ok(LevelGap.band(LevelGap.of(P, rivals[1])) == 0, "one below: plain")
	var gap_above := LevelGap.of(P, rivals[2])
	ok(gap_above == 2 and LevelGap.band(2) == 1, "two above: warm band")
	ok(LevelGap.tint(2) == LevelGap.WARM, "two above: the orange entry")
	ok(LevelGap.band(1) == 0 and LevelGap.band(0) == 0 and LevelGap.band(-1) == 0, "within one level: plain")
	ok(LevelGap.band(9) == 1 and LevelGap.band(-9) == -1, "far above and far below keep their side")
	ok(LevelGap.of(P, P) == 0 and LevelGap.of(null, rivals[2]) == 0, "yourself and no viewer: plain")
	var mate := Hunter.new()
	mate.team = P.team
	mate.lvl = 9
	ok(LevelGap.of(P, mate) == 0, "a teammate keeps their plain level at any gap")
	mate.free()
	var dl := absf(LevelGap.WARM.get_luminance() - LevelGap.COOL.get_luminance())
	ok(dl > 0.25, "warm and cool differ in luminance, not hue alone")
	ok(m.hud != null, "a match with a HUD")
	if mode == "shots":
		var fade = main.get("fade")
		if fade != null:
			await fade.reveal(0.01)
		for i in 8:
			m.cam.snap(P.pos)
			await main.get_tree().process_frame
		for i in 3:
			var sh: Dictionary = m.hud.plates.shown.get(rivals[i].nid, {})
			var want: int = rivals[i].lvl - P.lvl
			ok(int(sh.get("gap", 99)) == want, "rival %d's plate drew with gap %s" % [i, str(sh.get("gap"))])
		var img := main.get_viewport().get_texture().get_image()
		img.save_png(dir.path_join("level_gap_%dp.png" % img.get_height()))
	print("LEVEL GAP CHECK DONE, failures: ", bad)
	m.over = true
	m.queue_free()
	main.get_tree().quit(1 if bad > 0 else 0)
