extends RefCounted
## --farm-tut-3p-check: draft
var main: Node
var bad := 0


func ok(cond: bool, what: String) -> void:
	print("T3P %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(m: Node, _mode := "") -> void:
	main = m
	Save.no_write = true
	FarmUnlocks.rules()["base_mode"] = false
	Save.d = Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["uid"] = "t3p0"
	k["level"] = 5
	k["starter"] = true
	Care.ensure(k)
	Save.d["roster"].append(k)
	Save.d["active"] = k["uid"]
	Save.d["tutorial"] = {"hatched": true, "intro": true, "hob_intro": true}
	HomeLayout.ensure(Save.d)
	var home = await main._hb_home()
	var t0 := CheckClock.own_msec()
	while home.panel_host == null and CheckClock.own_msec() - t0 < 60000:
		await main.get_tree().process_frame
	home._close_panel()
	print("T3P start ppos=%s focus=%s cam=%s yaw=%s farm_k=%s" % [home.ppos, home.cam.focus, home.cam.position, home.farm_cam.yaw, home.farm_cam.k])
	for i in 90:
		await main.get_tree().process_frame
	print("T3P settled k=%s cam=%s size=%s" % [home.farm_cam.k, home.cam.position, main.get_viewport().get_visible_rect().size])
	main.get_tree().root.size = Vector2i(1920, 1080)
	await main.get_tree().process_frame
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	print("T3P vp ", vp)
	var safe := HudStyle.safe_rect(vp)
	for s in FarmTutorial.steps():
		var id := String(s["id"])
		var at: Vector3 = home.guide.target(id)
		if at.x == INF or at.x == 0.0:
			continue
		var row := ""
		for d in [4.0, 9.0, 16.0]:
			for a in 8:
				var ang := a * TAU / 8.0
				home.ppos = at + Vector3(sin(ang), 0, cos(ang)) * d
				home.cam.snap(home.ppos)
				home.farm_cam.yaw = 0.0
				for f in 12:
					await main.get_tree().process_frame
				var c: Camera3D = home.cam
				var t_on := not c.is_position_behind(at) and safe.has_point(c.unproject_position(at + Vector3.UP))
				var mk := at + Vector3(0, 3.6, 0)
				var m_on := not c.is_position_behind(mk) and safe.has_point(c.unproject_position(mk))
				if a == 0 and d == 9.0:
					print("T3P dbg ", id, " cam ", c.position, " ppos ", home.ppos, " at ", at, " px ", c.unproject_position(at), " beh ", c.is_position_behind(at), " yaw ", c.rotation_degrees)
				row += "%s%s " % ["T" if t_on else "-", "M" if m_on else "-"]
			row += "| "
		print("T3P %s: %s" % [id, row])
	print("T3P DONE, failures: %d" % bad)
	main.get_tree().quit()
