class_name CareDemo
extends RefCounted
## Screenshot and frame-strip tooling for the support pair (Arena). Hooked from ArenaDemo with one line.
##   --arena-demo=care_<tender|rimewright>_<lmb|rmb|e|dash|carry|payoff|pose> --arena-shot=<png>
## Saves <png> (the last frame) and <png without .png>_strip.png: crops of the hero at the times in
## TIMES, side by side (anticipation, impact, follow-through).

const TIMES := {
	"rmb": [0.28, 0.34, 0.4, 0.47, 0.6, 0.9, 2.6],
	"e": [0.28, 0.36, 0.45, 0.6, 0.9, 2.0, 3.0],
	"dash": [0.28, 0.34, 0.4, 0.5, 0.7, 0.9, 1.1],
	"lmb": [0.35, 0.5, 0.65, 0.8, 1.0, 1.2, 1.4],
	"carry": [0.3, 0.6, 1.0, 1.5, 2.0, 2.4, 2.8],
	"payoff": [0.4, 0.8, 1.2, 1.6, 2.0, 2.2, 2.5],
	"pose": [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5],
}

static func tick(A: Arena, dt: float, w: String) -> void:
	var parts := w.split("_")
	if parts.size() < 3: return
	var arch := String(parts[1]); var what := String(parts[2])
	var m := A.m
	var P: Hunter = m.player
	var t := float(A.get_meta("care_t", 0.0)) + dt
	A.set_meta("care_t", t)
	var D: Hunter = A.dummies[0]["h"]
	if m.cam:
		var zm: float = {"carry": 0.3, "pose": 0.3}.get(what, 0.3)          # (the carry wants the pair in frame, the portrait the hero close)
		m.cam.zoom = zm
		if what in ["carry", "pose"]: m.cam.zoom_to = zm
		m.cam.pitch = deg_to_rad(24.0)          # a low three-quarter view so the poses read
		m.cam.yaw = 2.5 if what not in ["pose", "carry"] else 0.5
		m.cam.yaw_to = m.cam.yaw
	if m.hud: m.hud.guide_hidden = true
	if not A.has_meta("care_lbl"):
		A.set_meta("care_lbl", true)
		for l in m.find_children("*", "Label3D", true, false):
			if String((l as Label3D).text).contains("KIT CARD"): (l as Label3D).visible = false
	P.hp = P.max_hp
	var Al: Hunter = (A.get_meta("care_ally") if A.has_meta("care_ally") else null)
	if Al == null:
		A.set_arch(arch, "lantern_crook" if arch == "tender" else "hoar_fan")
		A.set_kin("puddlet")
		P.teleport(D.pos + Vector3(-1.0, 0, 7.5))
		A.home = P.pos
		Al = m.make_hunter("Ally", P.team, "medium", "Ally", "idle", {}, P.pos + Vector3(2.6, 0, 1.2), {"arch": "none"})
		Al.max_hp = 145.0; Al.hp = 60.0
		A.set_meta("care_ally", Al)
		if what in ["carry"]:
			m.knock(Al, null, {})
			Al.ctrl = "idle"; Al.down_hp = 80.0
			Al.teleport(P.pos + Vector3(3.0, 0, 0.0))
	P.inp["aim"] = D.pos + Vector3(0, 0.9, 0)
	P.inp["aim_y"] = D.pos.y
	var K: ArchKit = P.ak
	var go := 0.3
	match what:
		"rmb":
			if _at(t, dt, go): K.ch_rmb = float(K.rmb_charges()); P.inp["sec_hold"] = false; K.press_rmb()
		"e":
			if _at(t, dt, go): K.cd["e"] = 0.0; K.use_e()
			if arch == "tender" and _at(t, dt, 1.0): K.use_e()
			if arch == "rimewright" and _at(t, dt, 1.4): K.use_e()
		"dash":
			if arch == "tender":
				P.dashes = P.max_dashes()
				if t < go:
					Al.teleport(P.pos + Vector3(2.0, 0, 0)); P.inp["move"] = Vector2(1, 0)
				if _at(t, dt, go): P.inp["aim"] = P.pos + Vector3(5, 0.9, 0); P.do_dash()
			else:
				P.inp["move"] = Vector2(0, -1)
				if _at(t, dt, go): P.dashes = P.max_dashes(); P.inp["dash_down"] = true; P.do_dash()
				if t > 1.0: P.inp["dash_down"] = false
		"lmb":
			P.inp["fire"] = t > 0.3 and t < 1.5
		"carry":
			if t > 0.3 and t < 3.0: P.inp["move"] = Vector2(-1, 0) if t > 1.0 else Vector2(1, 0)
			else: P.inp["move"] = Vector2.ZERO
		"payoff":
			if arch == "rimewright":
				if _at(t, dt, 0.3):
					(K as RimewrightKit).add_chill(D)
					D.hp = 1.0
				P.inp["fire"] = t > 0.5 and t < 1.0
			else:
				if _at(t, dt, 0.3): Al.hp = 20.0; K.cd["e"] = 0.0; K.use_e()
		"pose":
			pass
	# capture the strip
	var times: Array = TIMES.get(what, TIMES["rmb"])
	var frames: Array = A.get_meta("care_frames", [])
	for i in times.size():
		if _at(t, dt, float(times[i]) + 0.05):
			m.get_tree().process_frame.connect(func():
				var img := m.get_viewport().get_texture().get_image()
				var fr: Array = A.get_meta("care_frames", [])
				fr.append(img)
				A.set_meta("care_frames", fr), CONNECT_ONE_SHOT)
	if t >= float(times[-1]) + 0.2 and not A.has_meta("care_done"):
		A.set_meta("care_done", true)
		m.get_tree().process_frame.connect(func():
			m.get_tree().process_frame.connect(func():
				var path := ArenaDemo.shot_path()
				var last := m.get_viewport().get_texture().get_image()
				if path != "":
					last.save_png(path)
					_strip(A.get_meta("care_frames", []), path.trim_suffix(".png") + "_strip.png")
					print("ARENASHOT ", path)
				m.get_tree().quit(), CONNECT_ONE_SHOT), CONNECT_ONE_SHOT)

static func _at(t: float, dt: float, when: float) -> bool:
	return t >= when - 0.0001 and t - dt < when - 0.0001

## Crops around the middle of each frame (the hero is centred by the camera), scaled, side by side.
static func _strip(frames: Array, path: String) -> void:
	if frames.is_empty(): return
	var cw := 360; var ch := 360
	var out := Image.create(cw * frames.size(), ch, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		var img: Image = frames[i]
		var cx := img.get_width() / 2 - cw / 2
		var cy := int(img.get_height() * 0.56) - ch / 2
		var crop := img.get_region(Rect2i(maxi(0, cx), maxi(0, cy), mini(cw, img.get_width()), mini(ch, img.get_height())))
		out.blit_rect(crop, Rect2i(0, 0, crop.get_width(), crop.get_height()), Vector2i(i * cw, 0))
	out.save_png(path)
