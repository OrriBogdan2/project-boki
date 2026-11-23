extends RefCounted
## --a7-posedump --out=<json> [--hunter=gil]: scratch (never committed). Plays a scripted run of the real game for one
## Hunter and dumps every frame's skinning matrices (bone global pose * inverse bind) with a phase label, so the
## stretch can be measured offline on any mesh that shares the skeleton.

var main: Node
var gm
var bones: Array = []
var sk: Skeleton3D
var ibm: Array = []
var frames: Array = []
var labels: Array = []
var phase := "idle"

func run(main_node: Node) -> void:
	main = main_node
	var out := "/tmp/a6_posedump.json"
	var id := "gil"
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--out="): out = arg.substr(6)
		if arg.begins_with("--hunter="): id = arg.substr(9)
	gm = load("res://tools/gameplay_media.gd").new()
	gm.main = main
	Save.no_write = true
	Settings.v["tips"] = false
	await gm._start(id, "cindle")
	var P: Hunter = gm.m.player
	P.lvl = 6
	var base: Vector3 = gm._ground(P.pos)
	var foe: Hunter = gm._hunter("foe", 1, "juggernaut", "pebbit", gm._ground(base + Vector3(7, 0, 0)))
	foe.teleport(foe.pos)
	gm._zoom(0.9)
	for k in 10:
		gm.m.step(1.0 / 60.0)
		for h in gm.m.hunters:
			h.render(1.0 / 30.0, 1.0)
		await main.get_tree().process_frame
	sk = P.find_child("Skeleton3D", true, false) as Skeleton3D
	var skin: Skin
	for mi in sk.get_parent().find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).skin != null and (mi as MeshInstance3D).name == "Body":
			skin = (mi as MeshInstance3D).skin
	for i in sk.get_bone_count():
		bones.append(sk.get_bone_name(i))
		ibm.append(Transform3D())
	for i in skin.get_bind_count():
		var bi := skin.get_bind_bone(i)
		if bi < 0:
			bi = sk.find_bone(skin.get_bind_name(i))
		ibm[bi] = skin.get_bind_pose(i)
	var circ := func(t: float) -> Vector2: return Vector2(cos(t * 2.2), sin(t * 2.2))
	var aim_foe := func(): P.inp["aim"] = foe.pos + Vector3(0, 0.9, 0)
	var done := {}
	var once := func(key: String, t: float, now: float) -> bool:
		if now >= t and not done.has(key):
			done[key] = true
			return true
		return false
	var K: GilKit = P.ak as GilKit
	await gm._go(36.0, func(t: float):
		foe.hp = foe.max_hp
		if t < 31.0:
			P.hp = P.max_hp
		P.inp["fire"] = false
		P.inp["sec_hold"] = false
		if t < 1.2:
			phase = "idle"
		elif t < 2.7:
			phase = "walk"
			gm._keys(P, circ.call(t) * 0.46, false, false)
		elif t < 4.7:
			phase = "run"
			gm._keys(P, circ.call(t), false, false)
		elif t < 5.2:
			phase = "stop"
			gm._keys(P, Vector2.ZERO, false, false)
		elif t < 8.5:
			gm._keys(P, circ.call(t), false, false)
			if once.call("jump", 5.2, t):
				P.inp["jump"] = true
				phase = "jump"
			if once.call("glide", 5.9, t):
				P.inp["glide"] = true
				P.inp["glide_press_only"] = true
				phase = "glide"
			if t >= 7.6:
				phase = "land"
		elif t < 9.0:
			if once.call("tp", 8.5, t):
				P.teleport(base)
			phase = "idle2"
			gm._keys(P, Vector2.ZERO, false, false)
		elif t < 12.0:
			aim_foe.call()
			if once.call("dash", 9.0, t):
				P.inp["dash"] = true
				P.inp["move"] = Vector2(1, 0)
				phase = "dash_ground"
			if once.call("jump2", 10.2, t):
				P.inp["jump"] = true
				P.inp["move"] = Vector2(1, 0)
				phase = "jump_up"
			if once.call("dash2", 10.7, t):
				P.inp["dash"] = true
				P.inp["move"] = Vector2(1, 0)
				phase = "dash_air"
			if t >= 11.2 and phase == "dash_air":
				phase = "fall"
		elif t < 17.0:
			aim_foe.call()
			if once.call("tp2", 12.0, t):
				P.teleport(base)
				P.inp["move"] = Vector2.ZERO
			if t >= 12.5 and t < 15.0:
				phase = "lmb"
				P.inp["fire"] = true
			if once.call("rmb", 15.2, t):
				phase = "rmb"
				K.press_rmb()
			if t >= 15.2 and t < 15.5:
				P.inp["sec_hold"] = true
				P.inp["sec"] = true
			if once.call("e1", 16.0, t):
				phase = "e"
				P.inp["sig"] = true
		elif t < 25.0:
			aim_foe.call()
			if once.call("e2", 17.5, t):
				phase = "e_recast"
				P.inp["sig"] = true
			if once.call("ult", 19.0, t):
				phase = "ult"
				HunterKeys.ult_pressed(P)
			if once.call("leap", 22.5, t):
				phase = "ult_leap"
				HunterKeys.ult_pressed(P)
			if t >= 24.0:
				phase = "idle3"
		elif t < 31.0:
			# emotes (wave, laugh, thanks, gg): the truce bubble drives the gesture
			if once.call("em1", 25.0, t):
				phase = "emote_wave"
				if gm.m.truce: gm.m.truce.emote(P, "wave")
			if once.call("em2", 26.0, t):
				phase = "emote_laugh"
				if gm.m.truce: gm.m.truce.emote(P, "laugh")
			if once.call("em3", 27.0, t):
				phase = "emote_thanks"
				if gm.m.truce: gm.m.truce.emote(P, "thanks")
			if once.call("em4", 28.0, t):
				phase = "emote_gg"
				if gm.m.truce: gm.m.truce.emote(P, "gg")
			if once.call("sp", 29.0, t):
				phase = "sprint"
			if t >= 29.0:
				gm._keys(P, circ.call(t), false, false)
		elif t < 33.0:
			if once.call("tp3", 31.0, t):
				P.teleport(base)
				P.inp["move"] = Vector2.ZERO
			gm._keys(P, Vector2.ZERO, false, false)
			if once.call("hit", 31.0, t):
				phase = "hit"
				P.hurt(20.0, foe)
			if once.call("hit2", 32.0, t):
				P.hurt(20.0, foe)
		else:
			if once.call("die", 33.0, t):
				phase = "death"
				P.hp = 0.0
				P.hurt(99999.0, foe)
		_record(),
		func(_t: float): return P.pos, true)
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"bones": bones, "labels": labels, "frames": frames}))
	f.close()
	print("POSEDUMP_DONE frames=%d bones=%d out=%s" % [frames.size(), bones.size(), out])
	main.get_tree().quit(0)

func _record() -> void:
	# (the rig poses at render(): this runs before the frame's steps, so it reads the previous frame's pose)
	var row := PackedFloat32Array()
	for i in sk.get_bone_count():
		var m: Transform3D = sk.get_bone_global_pose(i) * (ibm[i] as Transform3D)
		var b := m.basis
		row.append_array([b.x.x, b.y.x, b.z.x, m.origin.x, b.x.y, b.y.y, b.z.y, m.origin.y, b.x.z, b.y.z, b.z.z, m.origin.z])
	frames.append(Array(row))
	labels.append(phase)
