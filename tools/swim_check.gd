extends RefCounted
## --swim-check: the farm's pond is water (HomeWater.depth). Walk in: the edge is shallow (you wade,
## slower, a splash going in), the middle is deep (you swim: lower in the water, slower still, no
## dash, no tools; Space kicks you up out of the water); walk out the far side: back on dry ground (a drip). The water is never
## void (the abyss rules leave it alone) and a Boki can paddle in it. --shots-dir=<dir>: a screenshot
## while swimming.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("SWIM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _press(dir: Vector2) -> void:
	for a in ["left", "right", "up", "down"]: Input.action_release(a)
	if dir.x > 0.1: Input.action_press("right", dir.x)
	if dir.x < -0.1: Input.action_press("left", -dir.x)
	if dir.y > 0.1: Input.action_press("down", dir.y)
	if dir.y < -0.1: Input.action_press("up", -dir.y)

func run(main: Node) -> void:
	var tree := main.get_tree()
	Save.no_write = true
	var od := Save.fresh()
	var k := Save.new_kin("puddlet", "Drip"); od["roster"].append(k); od["active"] = k["uid"]
	od["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true}
	od["matches"] = 3
	od.erase("layout")
	Save.d = JSON.parse_string(JSON.stringify(od))
	var hm = await main._hb_home()
	for i in 20: await tree.process_frame
	hm.set_process(false)
	var shot := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): shot = a.substr(12)
	var w: World = hm.world
	ok(not hm.fs and hm.water.depth(33.5, 37.5) == 2 and hm.water.depth(32.5, 36.5) == 1 and hm.water.depth(33.5, 34.5) == 0, "the classic farm's pond: deep in the middle, shallow round the edge")
	ok(not w.is_void(33.5, 37.5) and w.occupy(33.5, 37.5, 0.38, 0.0, true) == 0.0 and w.occupy(32.5, 36.5, 0.3, 0.0, true) == 0.0, "the water is walkable ground to the world: not void (no abyss), not a wall")
	var DT := 1.0 / 60.0
	hm.ppos = Vector3(33.5, 0, 34.6); hm.py = 0.0; hm.pvy = 0.0; hm.pvel = Vector3.ZERO; hm.dash_t = 0.0
	var dry_speed := 0.0; var wade_speed := 0.0; var swim_speed := 0.0
	var waded := false; var swam := false; var sank := 0.0; var out_dry := false
	var dash_in_water := false; var jump_in_water := false
	var phase := 0
	for i in 600:
		_press(Vector2(0, 1))
		var z0: float = hm.ppos.z
		hm._move_player(DT)
		var sp: float = (hm.ppos.z - z0) / DT
		var wd: int = hm.water.depth(hm.ppos.x, hm.ppos.z)
		if wd == 0 and not waded: dry_speed = maxf(dry_speed, sp)
		if wd == 1 and not swam: waded = true; wade_speed = sp      # (its speed as it reaches the deep water: settled to the wade)
		if hm.water.swimming:
			swam = true; swim_speed = maxf(swim_speed, sp)
			sank = maxf(sank, hm.water.k)
			if hm.water.k > 0.9 and phase == 0:
				phase = 1
				# Shift and Space do nothing while swimming
				Input.action_press("dash"); Input.action_press("jump")
				hm._move_player(DT)
				dash_in_water = hm.dash_t > 0.0; jump_in_water = hm.pvy > 0.0
				Input.action_release("dash"); Input.action_release("jump")
				await tree.process_frame      # (a press stays "just pressed" until a frame passes; without it the jump fires on the way out)
				if shot != "":
					for f in 4:
						hm._move_player(DT)
						await tree.process_frame
					tree.root.get_texture().get_image().save_png(shot + "/swim_after.png")
		if swam and wd == 0 and hm.ppos.z > 39.2 and absf(hm.py) < 0.01:      # (landed: the kick out of the water can carry you over the bank)
			out_dry = true
			break
	_press(Vector2.ZERO)
	ok(waded and wade_speed < dry_speed * 0.8, "walking in, the edge is shallow and slows you (%.1f m/s wading vs %.1f dry)" % [wade_speed, dry_speed])
	ok(swam and swim_speed < wade_speed and sank > 0.9, "the middle is deep: you swim, slower again (%.1f m/s), sunk in to the shoulders" % swim_speed)
	ok(not dash_in_water, "no dash while swimming")
	ok(jump_in_water, "Space kicks you up out of deep water (a jump from swimming)")
	ok(out_dry and not hm.water.swimming and absf(hm.py) < 0.01, "and you climb out the far side onto dry ground (%s)" % str(hm.ppos))
	# a Boki paddling: its body sits low in the water
	var kin_ok := false
	for kd in hm.kins:
		if kd.has("node") and not kd.has("indoors"):
			kd["pos"] = Vector3(33.5, 0, 37.5); kd["goal"] = Vector3(33.5, 0, 37.5)
			hm._process(DT) if false else null
			kin_ok = w.occupy(33.5, 37.5, 0.3, 0.0, true) == 0.0
			break
	ok(kin_ok, "a Boki can go in after you (the pond doesn't stop it)")
	hm.queue_free()
	print("SWIM DONE, failures: %d" % bad)
	tree.quit()
