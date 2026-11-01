class_name ArenaDemo
extends RefCounted
## Screenshot tooling for the Arena: --arena-demo=<what> --arena-shot=<png> plays a scripted moment
## and saves the frame at the scripted time, then quits.
##   thief       Knife, Shadow Step behind the dummy, blades from behind stack Marks (3 pips / coin)
##   cashin      the same, ending on the Cash In payoff
##   juggernaut  Rage fills on the dummies, Enraged form, an empowered Smash
##   ult         the Juggernaut's R fuse (wind-up) a moment before Avalanche fires
##   card / card_juggernaut   the kit card (K); card_detail: the RMB detail page
##   menu        the loadout panel (L)
##   smg         the SMG firing at the dummy; add --legacy-shots for the old look and numbers (before)

const OLD_SMG := {"dmg": 2.76, "rate": 0.07, "speed": 55.0, "mag": 36, "kb": 0.5, "size": 0.1, "kick": 0.0, "tracer": 0.5}

static func what() -> String:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--arena-demo="): return String(a).substr(13)
	return ""

static func shot_path() -> String:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--arena-shot="): return String(a).substr(13)
	return ""

static func tick(A: Arena, dt: float) -> void:
	var w := what()
	if w == "":
		return
	var m := A.m
	var P: Hunter = m.player
	var t := float(A.get_meta("demo_t", 0.0)) + dt
	A.set_meta("demo_t", t)
	var D: Hunter = A.dummies[0]["h"]
	var at_t := 1.0
	var legacy := "--legacy-shots" in OS.get_cmdline_user_args()
	Oomph.legacy = legacy
	if m.hud: m.hud.guide_hidden = true
	if m.cam and not w.begins_with("card") and w != "menu" and not m.has_meta("zoom_hold"):
		m.set_meta("zoom_hold", 0.6)      # close enough to read the hits
		m.cam.zoom = 0.6
	P.hp = P.max_hp
	match w:
		"thief", "cashin":
			if t < 0.05:
				if P.arch != "thief": A.set_arch("thief")
				A.set_kin("puddlet")
				P.teleport(D.pos + Vector3(0.6, 0, 4.2))
				A.home = P.pos
			_aim(P, D)
			if _at(t, dt, 0.25): P.inp["sec_hold"] = false; P.ak.press_rmb()        # the knife
			if _at(t, dt, 0.6):
				if (P.ak as ThiefKit).recast.is_empty(): (P.ak as ThiefKit)._shadow_step(D, false)   # (if the knife's recast didn't open)
				else: P.ak.press_rmb()                                    # Shadow Step behind
			if t > 0.75 and t < 1.6: P.inp["fire"] = true
			if w == "thief":
				if _at(t, dt, 1.3) and (P.ak as ThiefKit).marks_on(D) < 3: (P.ak as ThiefKit).add_mark(D, 3 - (P.ak as ThiefKit).marks_on(D), true)
				at_t = 1.42
			else:
				if _at(t, dt, 1.5) and (P.ak as ThiefKit).marks_on(D) < 3: (P.ak as ThiefKit).add_mark(D, 3 - (P.ak as ThiefKit).marks_on(D), true)
				if _at(t, dt, 1.75): P.inp["fire"] = false; (P.ak as ThiefKit).recast = {}; P.ak.ch_rmb = 1.0; P.inp["sec_hold"] = false; P.ak.press_rmb()
				at_t = 1.84
		"juggernaut":
			if t < 0.05:
				if P.arch != "juggernaut": A.set_arch("juggernaut")
				A.set_kin("cindle")
				var H: Hunter = A.dummies[2]["h"]
				P.teleport(H.pos + Vector3(-1.6, 0, 2.4))
				A.home = P.pos
				P.ak.res = 70.0
			var H2: Hunter = A.dummies[2]["h"]
			_aim(P, H2)
			if t > 0.1 and t < 1.1: P.inp["fire"] = true
			if _at(t, dt, 1.15):
				P.inp["fire"] = false
				if (P.ak as JuggernautKit).enraged_t <= 0.0: (P.ak as JuggernautKit).gain_rage(100.0)
			if _at(t, dt, 1.55): P.ak.ch_rmb = 1.0; P.inp["sec_hold"] = false; P.ak.press_rmb()
			at_t = 1.5 if "--before-smash" in OS.get_cmdline_user_args() else 1.62
		"ult":
			if t < 0.05:
				if P.arch != "juggernaut": A.set_arch("juggernaut")
				A.set_kin("cindle")
				P.ult = 1.0; P.merge_cd = 0.0
			_aim(P, D)
			if _at(t, dt, 0.5): P.ak.cd["r"] = 0.0; P.ak.use_r()
			at_t = 0.5 + P.ak.fuse_time() * 0.7
		"card", "card_juggernaut", "card_detail":
			if t < 0.05:
				A.set_arch("juggernaut" if w == "card_juggernaut" else "thief")
				A.set_kin("cindle" if w == "card_juggernaut" else "puddlet")
			if _at(t, dt, 0.3):
				A.toggle_card()
				if w == "card_detail":
					var c := A.card_layer.find_children("*", "KitCard", true, false)
					if not c.is_empty(): (c[0] as KitCard)._show_detail("rmb")
				_shot_later(A, 0.7)       # the card pauses the match: shoot on a wall-clock timer
			at_t = 99.0
		"menu":
			if t < 0.05: A.give_glove("blink")
			if _at(t, dt, 0.3):
				A.open_menu()
				_shot_later(A, 0.7)
			at_t = 99.0
		"smg":
			if t < 0.05:
				A.set_arch("thief", "smg")
				P.teleport(D.pos + Vector3(-4.0, 0, 2.5))
				A.home = P.pos
				if legacy:
					for k in OLD_SMG: P.wpn[k] = OLD_SMG[k]
			_aim(P, D)
			P.inp["fire"] = t > 0.3
			if P.ammo < 3: P.ammo = int(P.wpn["mag"])
			at_t = 1.05
	if t >= at_t and not A.has_meta("demo_shot"):
		A.set_meta("demo_shot", true)
		var path := shot_path()
		if path != "":
			# one more drawn frame so this step's effects are on screen, then save and quit
			m.get_tree().process_frame.connect(func():
				m.get_tree().process_frame.connect(func():
					m.get_viewport().get_texture().get_image().save_png(path)
					print("ARENASHOT ", path)
					m.get_tree().quit(), CONNECT_ONE_SHOT), CONNECT_ONE_SHOT)

static func _shot_later(A: Arena, secs: float) -> void:
	A.set_meta("demo_shot", true)
	var path := shot_path()
	if path == "":
		return
	A.m.get_tree().create_timer(secs).timeout.connect(func():
		A.m.get_viewport().get_texture().get_image().save_png(path)
		print("ARENASHOT ", path)
		A.m.get_tree().quit())

static func _at(t: float, dt: float, when: float) -> bool:
	return t >= when and t - dt < when

static func _aim(P: Hunter, T: Ent) -> void:
	P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
	P.inp["aim_y"] = T.pos.y
