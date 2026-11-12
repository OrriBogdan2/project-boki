class_name HeroDemo
extends RefCounted
## Screenshot tooling for Sparkle and Vex (used by ArenaDemo): --arena-demo=hero_<id>_<move> with
##   --arena-shot=<png>                      one frame at the moment of the move
##   --hero-frames=<png> --hero-times=a,b,c  a contact sheet: one cropped frame per time (seconds
##                                           after the ability is pressed), for the animation strips
## Moves: mage_live, mage_wire, mage_blowout, mage_coil, mage_sky, mage_card
##        gunslinger_fever, gunslinger_burr, gunslinger_wall, gunslinger_needle, gunslinger_skewer, gunslinger_dash,
##        gunslinger_railrest, gunslinger_railwind, gunslinger_railbeam (the Palm Lance's view, item 68),
##        <hero>_dashaim (any hero: a slide east with the cursor north, LMB held; item 109)

const GO := 0.4

static func arg(name_: String) -> String:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with(name_ + "="): return String(a).substr(name_.length() + 1)
	return ""

static func times() -> Array:
	var out: Array = []
	for x in arg("--hero-times").split(",", false): out.append(float(x))
	return out

static func tick(A: Arena, P: Hunter, D: Hunter, t: float, dt: float, w: String) -> float:
	var parts := w.split("_")
	var who := parts[1]
	var mv := parts[2] if parts.size() > 2 else ""
	var at_t := 1.0
	if t < 0.05:
		if P.arch != who: A.set_arch(who)
		A.set_kin("puddlet")
		P.teleport(D.pos + Vector3(-4.2 if who == "mage" else -4.4, 0, -1.2))
		A.home = P.pos
		D.max_hp = 600.0; D.hp = D.max_hp
		var zk := 0.34 if arg("--hero-frames") != "" else 0.5
		A.m.set_meta("zoom_hold", zk)
		if A.m.cam: A.m.cam.zoom = zk
	ArenaDemo._aim(P, D)
	P.inp["move"] = Vector2.ZERO
	P.hp = P.max_hp
	D.hp = D.max_hp
	var K = P.ak
	if who == "mage":
		match mv:
			"live":
				if ArenaDemo._at(t, dt, 0.3): K.add_spark(D, 4)
				at_t = 0.8
			"wire":
				if ArenaDemo._at(t, dt, GO): P.dashes = P.max_dashes(); P.inp["dash_down"] = true; P.do_dash()
				if t > GO: P.inp["dash_down"] = t < GO + 0.45
				at_t = GO + 0.5
			"blowout":
				if ArenaDemo._at(t, dt, 0.2): K.add_spark(D, 4)
				if ArenaDemo._at(t, dt, GO): P.dashes = P.max_dashes(); P.inp["dash_down"] = true; P.do_dash()
				if t > GO: P.inp["dash_down"] = t < GO + 0.3
				at_t = GO + 0.3 + 0.2 if int(K.blowouts) == 0 else 99.0
				if int(K.blowouts) > 0 and not A.has_meta("bo_at"): A.set_meta("bo_at", t)
				if A.has_meta("bo_at"): at_t = float(A.get_meta("bo_at")) + 0.08
				else: at_t = 99.0
			"coil":
				if ArenaDemo._at(t, dt, GO): K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; K.bot_hold["rmb"] = 1.0; K.press_rmb()
				at_t = GO + 1.12
			"sky":
				if ArenaDemo._at(t, dt, GO): K.cd["e"] = 0.0; K.use_e()
				at_t = GO + 0.62
	else:
		match mv:
			"fever":
				K.res = 6.0; K.res_wait = 3.0
				P.inp["fire"] = t > 0.2
				at_t = 1.0
			"burr":
				if ArenaDemo._at(t, dt, GO): K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; K.press_rmb()
				at_t = GO + 0.5
			"wall":
				if t < 0.05:
					var W = A.m.world
					for k in range(-2, 3):
						var wx := int(floor(D.pos.x + 3.0)); var wz := int(floor(D.pos.z + 1.0 + k))
						W.kind[W.idx(wx, wz)] = World.T_BLOCK
				if ArenaDemo._at(t, dt, GO):
					P.inp["aim"] = D.pos + Vector3(3.5, 0.9, 1.0)
					K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; K.press_rmb()
				if t > GO and t < GO + 1.3: P.inp["aim"] = D.pos + Vector3(3.5, 0.9, 1.0)
				at_t = GO + 1.18
			"needle", "skewer":
				if mv == "skewer" and ArenaDemo._at(t, dt, 0.1): KitStatus.apply(D, "rat", 4.0)
				if ArenaDemo._at(t, dt, GO): K.cd["e"] = 0.0; K.use_e()
				if mv == "needle": at_t = GO + 0.9
				else:
					if int(K.skewers) > 0 and not A.has_meta("sk_at"): A.set_meta("sk_at", t)
					at_t = float(A.get_meta("sk_at", 99.0)) + 0.08
			"dash":
				if ArenaDemo._at(t, dt, GO): P.dashes = P.max_dashes(); P.inp["move"] = Vector2(0, 1); P.inp["dash_down"] = true; P.do_dash()
				if t > GO: P.inp["dash_down"] = t < GO + 0.6
				at_t = GO + 0.3
			"railrest", "railwind", "railbeam":       # item 68, at the match's own zoom: before, the wind-up, the beam
				A.m.set_meta("zoom_hold", 1.0)
				if t < 0.1: P.teleport(D.pos + Vector3(-7.0, 0, 1.5))
				if ArenaDemo._at(t, dt, GO + 0.4):
					K.cd["e"] = 0.0
					K.use_e()
				at_t = {"railrest": GO, "railwind": GO + 0.4 + 0.45, "railbeam": GO + 0.4 + 0.67}[mv]
			"dashaim":       # item 109: slide across the screen, the rifle kept up the screen and firing
				P.inp["aim"] = P.pos + Vector3(0, 0.9, -8.0)
				P.inp["fire"] = t > 0.2
				if ArenaDemo._at(t, dt, GO):
					P.dashes = P.max_dashes()
					P.inp["dash_down"] = true
					P.do_dash()
				if t > GO:
					P.inp["move"] = Vector2(1, 0)
					P.inp["dash_down"] = t < GO + 0.6
				at_t = GO + 0.3
	# contact sheet
	var fr := arg("--hero-frames")
	if fr != "":
		var ts := times()
		var cap: Array = A.get_meta("hero_caps", []) if A.has_meta("hero_caps") else []
		var n_done := int(A.get_meta("hero_n", 0))
		if n_done < ts.size() and t >= GO + float(ts[n_done]):
			A.set_meta("hero_n", n_done + 1)
			var m: Node = A.m
			var idx := n_done
			m.get_tree().process_frame.connect(func():
				m.get_tree().process_frame.connect(func():
					var img: Image = m.get_viewport().get_texture().get_image()
					var cc: Array = A.get_meta("hero_caps", []) if A.has_meta("hero_caps") else []
					cc.append(img)
					A.set_meta("hero_caps", cc)
					if cc.size() >= ts.size():
						_sheet(cc, fr)
						m.get_tree().quit(), CONNECT_ONE_SHOT), CONNECT_ONE_SHOT)
		at_t = 999.0
		A.set_meta("demo_shot", true)
	return at_t

## Crop the middle of each frame and lay them side by side.
static func _sheet(imgs: Array, path: String) -> void:
	var cw := 300; var ch := 340
	var sheet := Image.create(cw * imgs.size(), ch, false, Image.FORMAT_RGBA8)
	for i in imgs.size():
		var im: Image = imgs[i]
		var x0 := maxi(0, im.get_width() / 2 - cw / 2); var y0 := maxi(0, int(im.get_height() * 0.5) - ch / 2 - 20)
		sheet.blit_rect(im, Rect2i(x0, y0, cw, ch), Vector2i(i * cw, 0))
	sheet.save_png(path)
	print("HEROSHEET ", path)
