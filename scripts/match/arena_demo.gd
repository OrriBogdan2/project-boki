class_name ArenaDemo
extends RefCounted
## Screenshot tooling for the Arena: --arena-demo=<what> --arena-shot=<png> plays a scripted moment
## and saves the frame at the scripted time, then quits.
##   thief       SMG hits stack Marks on the dummy (3 = the coin), Vault Primes the next hit (gold glint)
##   cashin      the same, ending on the Primed hit's Cash In payoff
##   bola        the Thief's Bola catching two dummies: Grounded, TANGLED
##   juggernaut  greatsword slashes heat Rage (the shoulder glow), the Enraged form (ragesmash: + the Rage Smash)
##   wave        the greatsword held into a Searing Wave (--hold-shot: at full charge)
##   ult         the Juggernaut's R fuse (wind-up) a moment before Avalanche fires
##   archer      a snare roots the dummy, full Focus: the lens glint, the aim line, crosshairs over it
##   deadeye     the same, ending on the Deadeye payoff
##   mage        a Guided Bolt Runes the dummy; Overcharged: white-hot runes orbiting the Mage
##   flashpoint  the same, then a second bolt detonates the Rune: the Flashpoint payoff
##   hex         the Hex turning the dummy into a critter
##   gunslinger  rifle hits fill the gold cylinder over the hat; at 6 the gun glows (Called Shot armed)
##   calledshot  the same, ending on the Called Shot payoff
##   bulwark     the shield raised and burning gold, Guard pips full (Shield Slam armed)
##   crushed     the same, then letting go: a Shield Slam into the pillar, Crushed
##   e_<a> / r_<a> / rmb_<a>   any archetype's E, R or RMB on the still dummy (--e-recast: press E again)
##   card / card_<archetype>   the kit card (K); card_detail: the RMB detail page
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
			# kits2: SMG hits on the dummy stack Marks (gold diamonds, the coin at 3), Vault Primes the next
			# hit (the gold glint, CASH IN READY), then (cashin) the Primed hit Cashes In
			if t < 0.05:
				if P.arch != "thief" or P.wid != "smg": A.set_arch("thief", "smg")
				A.set_kin("puddlet")
				P.teleport(D.pos + Vector3(1.6, 0, 1.9))
				A.home = P.pos
			_aim(P, D)
			P.inp["move"] = Vector2.ZERO
			P.inp["fire"] = t > 0.2 and t < 1.2
			if P.ammo < 3: P.ammo = int(P.wpn["mag"])
			var TK := P.ak as ThiefKit
			if _at(t, dt, 1.25) and TK.marks_on(D) < 3: TK.add_mark(D, 3 - TK.marks_on(D), true)
			if _at(t, dt, 1.3): P.dashes = P.max_dashes(); P.inp["move"] = Vector2(-1, 0); P.do_dash()
			if w == "thief":
				at_t = 1.62
			else:
				if t > 1.6 and t < 1.75: P.inp["fire"] = true
				if TK.cash_ins > 0 and not A.has_meta("ci_at"): A.set_meta("ci_at", t)
				at_t = float(A.get_meta("ci_at", 9.0)) + 0.06
		"bola":
			# the Bola wraps the dummy and the heavy dummy beside it: both Grounded, TANGLED, stunned
			var H: Hunter = A.dummies[2]["h"]
			if t < 0.05:
				if P.arch != "thief": A.set_arch("thief", "smg")
				A.set_kin("puddlet")
				P.teleport(D.pos + Vector3(-3.4, 0, 0.2))
				A.home = P.pos
			if t < 0.6: H.teleport(D.pos + Vector3(0.0, 0, 2.0)); H.vel = Vector3.ZERO
			_aim(P, D)
			P.inp["move"] = Vector2.ZERO
			if _at(t, dt, 0.4): P.ak.ch_rmb = 1.0; P.ak.press_rmb()
			if (P.ak as ThiefKit).bola_pairs > 0 and not A.has_meta("bp_at"): A.set_meta("bp_at", t)
			at_t = float(A.get_meta("bp_at", 9.0)) + 0.12
		"juggernaut", "ragesmash":
			# greatsword slashes heat Rage (the shoulder glow grows), Enraged form, then the Rage Smash
			if t < 0.05:
				if P.arch != "juggernaut" or P.wid != "greatsword": A.set_arch("juggernaut", "greatsword")
				A.set_kin("cindle")
				var H: Hunter = A.dummies[2]["h"]
				P.teleport(H.pos + Vector3(-1.6, 0, 2.2))
				A.home = P.pos
				P.ak.res = 40.0
			var H2: Hunter = A.dummies[2]["h"]
			_aim(P, H2)
			P.inp["move"] = Vector2.ZERO
			P.inp["fire"] = t > 0.1 and t < 1.1 and fmod(t, 0.36) < 0.12        # tap, tap: quick slashes
			var JK := P.ak as JuggernautKit
			if _at(t, dt, 1.15) and JK.enraged_t <= 0.0: JK.gain_rage(100.0)
			if w == "juggernaut":
				at_t = 1.45
			else:
				if _at(t, dt, 1.55): P.ak.ch_rmb = 1.0; P.ak.cd["rmb"] = 0.0; P.inp["sec_hold"] = false; P.ak.press_rmb()
				if JK.rage_smashes > 0 and not A.has_meta("rs_at"): A.set_meta("rs_at", t)
				at_t = float(A.get_meta("rs_at", 9.0)) + 0.08
		"wave":
			# the greatsword held: the wind-up (ring, glow, rising thump), then the Searing Wave rolls out
			if t < 0.05:
				if P.arch != "juggernaut" or P.wid != "greatsword": A.set_arch("juggernaut", "greatsword")
				A.set_kin("cindle")
				P.teleport(D.pos + Vector3(-7.0, 0, -1.0))
				A.home = P.pos
			_aim(P, D)
			P.inp["move"] = Vector2.ZERO
			P.inp["fire"] = t > 0.3 and t < 1.45
			at_t = 1.3 if "--hold-shot" in OS.get_cmdline_user_args() else 1.56
		"ult":
			if t < 0.05:
				if P.arch != "juggernaut": A.set_arch("juggernaut")
				A.set_kin("cindle")
				P.ult = 1.0; P.merge_cd = 0.0
			_aim(P, D)
			if _at(t, dt, 0.5): P.ak.cd["r"] = 0.0; P.ak.use_r()
			at_t = 0.5 + P.ak.fuse_time() * 0.7
		"archer", "deadeye":
			if t < 0.05:
				if P.arch != "archer": A.set_arch("archer", "longbow")
				A.set_kin("puddlet")
				P.teleport(D.pos + Vector3(0.5, 0, -2.2))
				A.home = P.pos
			_aim(P, D)
			P.inp["move"] = Vector2.ZERO
			if _at(t, dt, 0.3): P.inp["sec_hold"] = false; P.ak.ch_rmb = 2.0; P.ak.press_rmb()       # the snare roots it
			if t > 0.35 and t < 2.0: D.root_t = maxf(D.root_t, 0.8)                                  # (keep it pinned for the frame)
			if w == "archer":
				if t > 0.9: P.ak.res = P.ak.res_max()
				at_t = 1.9
			else:
				if _at(t, dt, 1.75): P.ak.res = P.ak.res_max(); P.fire_cd = 0.0; P.ammo = maxi(P.ammo, 1); P.inp["fire"] = true
				if _at(t, dt, 1.8): P.inp["fire"] = false
				if P.ak.get("deadeyes") and int(P.ak.get("deadeyes")) > 0 and not A.has_meta("de_at"): A.set_meta("de_at", t)
				at_t = float(A.get_meta("de_at", 9.0)) + 0.06
		"mage", "flashpoint", "hex":
			if t < 0.05:
				if P.arch != "mage": A.set_arch("mage", "spellstaff")
				A.set_kin("cindle")
				P.teleport(D.pos + Vector3(-3.6, 0, -1.2))
				A.home = P.pos
			_aim(P, D)
			P.inp["move"] = Vector2.ZERO
			if w == "hex":
				if _at(t, dt, 0.4): P.ak.cd["e"] = 0.0; P.ak.use_e()
				if Hex.active(D) and not A.has_meta("hx_at"): A.set_meta("hx_at", t)
				at_t = float(A.get_meta("hx_at", 9.0)) + 0.35
			else:
				if _at(t, dt, 0.3): P.ak.ch_rmb = 1.0; P.ak.bot_hold["rmb"] = 0.3; P.ak.press_rmb()     # a Guided Bolt Runes the dummy
				if t > 0.7 and t < 1.5: P.ak.res = maxf(P.ak.res, 82.0); P.ak.res_wait = 1.0        # ride it Overcharged
				if w == "mage":
					at_t = 1.45
				else:
					if _at(t, dt, 1.5): P.ak.ch_rmb = 1.0; P.ak.cd["rmb"] = 0.0; P.ak.res = 74.0; P.ak.press_rmb()   # the second spell: Flashpoint
					if int(P.ak.get("flashpoints")) > 0 and not A.has_meta("fp_at"): A.set_meta("fp_at", t)
					at_t = float(A.get_meta("fp_at", 9.0)) + 0.06
		"gunslinger", "calledshot":
			if t < 0.05:
				if P.arch != "gunslinger": A.set_arch("gunslinger", "rifle")
				A.set_kin("puddlet")
				P.teleport(D.pos + Vector3(-3.6, 0, -1.0))
				A.home = P.pos
			_aim(P, D)
			P.inp["move"] = Vector2.ZERO
			P.inp["fire"] = t > 0.2 and t < 1.0                                            # hits load the cylinder
			if t > 0.2 and t < 1.0: P.ak.res_wait = 4.0
			if _at(t, dt, 1.05) and P.ak.res < 6.0: P.ak.res = 5.0; P.ak.load_at = -9.0; P.ak.load_chambers(1, true)
			if w == "gunslinger":
				at_t = 1.7
			else:
				if _at(t, dt, 1.7): P.ak.ch_rmb = 1.0; P.ak.cd["rmb"] = 0.0; P.inp["sec_hold"] = false; P.ak.press_rmb()
				if int(P.ak.get("called_shots")) > 0 and not A.has_meta("cs_at"): A.set_meta("cs_at", t)
				at_t = float(A.get_meta("cs_at", 9.0)) + 0.06
		_ when w.begins_with("e_") or w.begins_with("r_") or w.begins_with("rmb_"):
			# any archetype's E, R or RMB on the still dummy: e_<arch>, r_<arch>, rmb_<arch> (rmb holds 0.9s)
			var ar := w.split("_")[1]
			if t < 0.05:
				if P.arch != ar: A.set_arch(ar)
				A.set_kin("puddlet")
				P.teleport(D.pos + Vector3(-4.2, 0, -1.2))
				A.home = P.pos
			_aim(P, D)
			P.inp["move"] = Vector2.ZERO
			var go := 0.5
			if w.begins_with("e_"):
				if _at(t, dt, go): P.ak.cd["e"] = 0.0; P.ak.use_e()
				if "--e-recast" in OS.get_cmdline_user_args() and _at(t, dt, go + 0.45): P.ak.use_e()   # (the Shadow Step / the haul)
				at_t = go + float(A.get_meta("e_shot_after", 0.9 if "--e-recast" not in OS.get_cmdline_user_args() else 0.62))
			elif w.begins_with("r_"):
				if _at(t, dt, go): P.ak.cd["r"] = 0.0; P.ak.use_r()
				if t > go + P.ak.fuse_time() + 0.1 and t < go + P.ak.fuse_time() + 1.2: P.inp["fire"] = true   # (an empowered-shot ult fires through)
				at_t = go + P.ak.fuse_time() + (1.3 if "--late-shot" in OS.get_cmdline_user_args() else 0.75)
				if "--fuse-shot" in OS.get_cmdline_user_args(): at_t = go + P.ak.fuse_time() * 0.7     # (before: the wind-up)
				if "--impact-shot" in OS.get_cmdline_user_args(): at_t = go + P.ak.fuse_time() + 0.1  # (the moment it lands)
			else:
				if _at(t, dt, go): P.ak.ch_rmb = float(P.ak.rmb_charges()); P.ak.bot_hold["rmb"] = 0.9; P.ak.press_rmb()
				at_t = go + 0.7 if "--hold-shot" in OS.get_cmdline_user_args() else go + 1.05
		"bulwark", "crushed":
			var H: Hunter = A.dummies[2]["h"]
			if t < 0.05:
				if P.arch != "bulwark": A.set_arch("bulwark", "tower_shield")
				A.set_kin("cindle")
				P.teleport(H.pos + Vector3(-1.1, 0, 1.6))
				A.home = P.pos
			_aim(P, H)
			P.inp["move"] = Vector2.ZERO
			if _at(t, dt, 0.25): P.ak.bot_hold["rmb"] = 0.95 if w == "crushed" else 3.0; P.ak.press_rmb()   # raise the shield
			if t > 0.3 and t < 1.2: P.ak.add_guard(dt * 70.0)                                    # (blocked fire becomes Guard)
			if w == "bulwark":
				at_t = 1.6
			else:
				if int(P.ak.get("crushes")) > 0 and not A.has_meta("cr_at"): A.set_meta("cr_at", t)
				at_t = float(A.get_meta("cr_at", 9.0)) + 0.06
		"card", "card_juggernaut", "card_detail", "card_archer", "card_mage", "card_gunslinger", "card_bulwark":
			if t < 0.05:
				var ca: String = {"card_juggernaut": "juggernaut", "card_archer": "archer", "card_mage": "mage", "card_gunslinger": "gunslinger", "card_bulwark": "bulwark"}.get(w, "thief")
				A.set_arch(ca)
				A.set_kin("cindle" if ca in ["juggernaut", "mage", "bulwark"] else "puddlet")
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
			if not A.has_meta("demo_set"):
				A.set_meta("demo_set", true)
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
	var w := when - 0.0001          # (a step landing exactly on `when` must count once, whatever the rounding)
	return t >= w and t - dt < w

static func _aim(P: Hunter, T: Ent) -> void:
	P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
	P.inp["aim_y"] = T.pos.y
