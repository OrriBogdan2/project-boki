class_name ArenaDemo
extends RefCounted
## Screenshot tooling for the Arena: --arena-demo=<what> --arena-shot=<png> plays a scripted moment
## and saves the frame at the scripted time, then quits.
##   thief       SMG hits stack Marks on the dummy (3 = the coin), Vault Primes the next hit (gold glint)
##   primed      the same, ending on the Primed hit landing (VAULT RESET, the payoff)
##   bola        the Thief's Bola catching two dummies: Grounded, TANGLED
##   juggernaut  greatsword slashes fill Rage (the shoulder glow), the Enraged form
##   sweetspot   then a rank-3 Execution Slam winds up and lands its sweet spot (--hold-shot: the wind-up);
##               it also brings the crash down and heals
##   crash       the same, framed on the crash and the heal that follows the slam
##   jackpot     the Thief's fifth Mark releases the knife burst (the knives in flight)
##   jackpotpay  the same, on the last knife: the JACKPOT payoff and the free Vault
##   wave        the greatsword held into a Searing Wave (--hold-shot: at full charge)
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
##   anim_<move> a strip of frames of one kit move (ANIM_DEMO: thf_shot thf_blades thf_vault thf_primed
##               thf_bola thf_knife thf_volley jug_slash jug_wave jug_slam jug_lunge jug_meteor jug_dash
##               jug_chain jug_chainlunge jug_haul jug_spin)
##   smg         the SMG firing at the dummy; add --legacy-shots for the old look and numbers (before)

const OLD_SMG := {"dmg": 2.76, "rate": 0.07, "speed": 55.0, "mag": 36, "kb": 0.5, "size": 0.1, "kick": 0.0, "tracer": 0.5}


## --arena-demo=anim_<move>: a strip of frames of one kit move, cropped round the hunter, side by side
## (the frame times are in seconds of the demo; the move is triggered at 0.5 unless noted).
const ANIM_DEMO := {
	"thf_shot": ["thief", "smg", [0.62, 0.66, 0.7, 0.74, 0.78, 0.82]],
	"thf_blades": ["thief", "twin_blades", [0.52, 0.58, 0.64, 0.84, 0.9, 0.96]],
	"thf_vault": ["thief", "smg", [0.5, 0.56, 0.62, 0.68, 0.76, 0.86, 1.0]],
	"thf_primed": ["thief", "smg", [0.5, 0.6, 0.78, 0.81, 0.85, 0.95]],
	"thf_bola": ["thief", "smg", [0.5, 0.55, 0.6, 0.65, 0.7, 0.85]],
	"thf_knife": ["thief", "twin_blades", [0.5, 0.57, 0.63, 0.7, 0.96, 1.02, 1.15]],
	"thf_volley": ["thief", "smg", [0.5, 0.56, 0.62, 0.68, 0.76, 0.86, 1.0]],
	"jug_slash": ["juggernaut", "greatsword", [0.42, 0.48, 0.56, 0.78, 0.84, 0.92]],
	"jug_wave": ["juggernaut", "greatsword", [0.4, 0.8, 1.3, 1.46, 1.52, 1.62, 1.85]],
	"jug_slam": ["juggernaut", "greatsword", [0.55, 0.75, 0.92, 0.98, 1.02, 1.15, 1.45]],
	"jug_lunge": ["juggernaut", "greatsword", [0.7, 1.0, 1.4, 1.53, 1.6, 1.75, 2.0]],
	"jug_meteor": ["juggernaut", "greatsword", [0.5, 0.56, 0.62, 0.68, 0.8, 1.0]],
	"jug_dash": ["juggernaut", "greatsword", [0.5, 0.56, 0.62, 0.68, 0.78, 0.95]],
	"jug_chain": ["juggernaut", "greatsword", [0.52, 0.58, 0.66, 0.92, 0.98, 1.06, 1.2]],
	"jug_chainlunge": ["juggernaut", "greatsword", [1.0, 1.5, 1.78, 1.84, 1.9, 2.05, 2.3]],
	"jug_haul": ["juggernaut", "greatsword", [1.0, 1.24, 1.32, 1.42, 1.52, 1.62, 1.9]],
	"jug_spin": ["juggernaut", "greatsword", [0.88, 0.92, 0.98, 1.04, 1.1, 1.18, 1.35]],
}

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
		"thief", "primed":
			# kits2: SMG hits on the dummy stack Marks (gold diamonds, one per Mark), Vault Primes the next
			# hit (the gold glint, PRIMED), then (primed) the Primed hit lands: VAULT RESET
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
			if _at(t, dt, 1.3): P.dashes = P.max_dashes(); P.inp["move"] = Vector2(-1, 0); P.do_dash()
			if w == "thief":
				at_t = 1.62
			else:
				if t > 1.6 and t < 1.75: P.inp["fire"] = true
				if TK.primed_hits > 0 and not A.has_meta("ph_at"): A.set_meta("ph_at", t)
				at_t = float(A.get_meta("ph_at", 9.0)) + 0.06
		"bola":
			# the Bola wraps the dummy and the heavy dummy beside it: both Grounded, TANGLED, stunned
			var H: Hunter = A.dummies[2]["h"]
			if t < 0.05:
				if P.arch != "thief": A.set_arch("thief", "smg")
				A.set_kin("puddlet")
				P.teleport(D.pos + Vector3(-3.4, 0, 0.2))
				A.home = P.pos
			if t < 0.6: H.teleport(D.pos + (D.pos - P.pos).normalized() * 2.6); H.vel = Vector3.ZERO     # behind the dummy, along the throw
			_aim(P, D)
			P.inp["move"] = Vector2.ZERO
			if _at(t, dt, 0.4): P.ak.ch_rmb = 1.0; P.ak.press_rmb()
			if (P.ak as ThiefKit).bola_pairs > 0 and not A.has_meta("bp_at"): A.set_meta("bp_at", t)
			at_t = float(A.get_meta("bp_at", 9.0)) + 0.12
		"juggernaut", "sweetspot", "crash":
			# greatsword slashes fill Rage (the shoulder glow) into the Enraged form; (sweetspot) then an
			# Execution Slam (rank 3) winds up (the warning) and lands its sweet spot: the crash comes down and heals
			if t < 0.05:
				if P.arch != "juggernaut" or P.wid != "greatsword": A.set_arch("juggernaut", "greatsword")
				A.set_kin("cindle")
				P.slot_lv["sec"] = 3                 # rank 3: the sweet spot also crashes
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
				if _at(t, dt, 1.2): P.teleport(H2.pos - Vector3(H2.pos.x - P.pos.x, 0, H2.pos.z - P.pos.z).normalized() * 2.5)
				if _at(t, dt, 1.25): P.hp = P.max_hp * 0.6; P.ak.ch_rmb = 1.0; P.ak.cd["rmb"] = 0.0; P.inp["sec_hold"] = false; P.ak.press_rmb()
				if w == "sweetspot" and "--hold-shot" in OS.get_cmdline_user_args(): at_t = 1.5
				else:
					if JK.crashes > 0 and not A.has_meta("ss_at"): A.set_meta("ss_at", t)
					at_t = float(A.get_meta("ss_at", 9.0)) + (0.08 if w == "sweetspot" else 0.3)
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
		"jackpot", "jackpotpay":
			# kits2-nor: the Thief's fifth Mark on the dummy releases Jackpot: a burst of knives, Marks
			# refreshed, one free Vault; (jackpotpay) the last knife lands and the payoff goes off
			if t < 0.05:
				if P.arch != "thief" or P.wid != "smg": A.set_arch("thief", "smg")
				A.set_kin("puddlet")
				P.teleport(D.pos + Vector3(-3.4, 0, 1.4))
				A.home = P.pos
			_aim(P, D)
			P.inp["move"] = Vector2.ZERO
			var JT := P.ak as ThiefKit
			if _at(t, dt, 0.3): JT.add_mark(D, 4, true)
			P.inp["fire"] = t > 0.35 and t < 0.6
			if P.ammo < 3: P.ammo = int(P.wpn["mag"])
			if JT.jackpots > 0 and not A.has_meta("jp_at"): A.set_meta("jp_at", t)
			at_t = float(A.get_meta("jp_at", 9.0)) + (0.2 if w == "jackpot" else 0.46)
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
		_ when w.begins_with("anim_"):
			var mv := w.substr(5)
			var spec: Array = ANIM_DEMO.get(mv, ["thief", "smg", [1.0]])
			if t < 0.05:
				if P.arch != String(spec[0]) or P.wid != String(spec[1]): A.set_arch(String(spec[0]), String(spec[1]))
				A.set_kin("")
				P.teleport(D.pos + Vector3(-4.0, 0, 0))
				A.home = P.pos
				if m.cam: m.cam.zoom = 0.42
				m.set_meta("zoom_hold", 0.42)
			_aim(P, D)
			P.inp["move"] = Vector2.ZERO
			P.hp = P.max_hp
			_anim_trigger(A, P, D, mv, t, dt)
			var times: Array = spec[2]
			for i in times.size():
				if _at(t, dt, float(times[i])):
					var last := i == times.size() - 1
					m.get_tree().process_frame.connect(func(): _grab(A, P, last), CONNECT_ONE_SHOT)
			at_t = 99.0
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
		"card", "card_juggernaut", "card_detail", "card_detail_passive", "card_archer", "card_mage", "card_gunslinger", "card_bulwark":
			if t < 0.05:
				var ca: String = {"card_juggernaut": "juggernaut", "card_archer": "archer", "card_mage": "mage", "card_gunslinger": "gunslinger", "card_bulwark": "bulwark"}.get(w, "thief")
				A.set_arch(ca)
				A.set_kin("cindle" if ca in ["juggernaut", "mage", "bulwark"] else "puddlet")
			if _at(t, dt, 0.3):
				A.toggle_card()
				if w == "card_detail" or w == "card_detail_passive":
					var c := A.card_layer.find_children("*", "KitCard", true, false)
					if not c.is_empty(): (c[0] as KitCard)._show_detail("rmb" if w == "card_detail" else "passive")
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

## The scripted input for each kit move's strip.
static func _anim_trigger(A: Arena, P: Hunter, D: Hunter, mv: String, t: float, dt: float) -> void:
	var K: ArchKit = P.ak
	match mv:
		"thf_shot":
			P.inp["fire"] = t > 0.55 and t < 0.9
			if P.ammo < 3: P.ammo = int(P.wpn["mag"])
		"thf_blades":
			if t < 0.45: P.teleport(Vector3(D.pos.x - 1.9, P.pos.y, D.pos.z))
			P.inp["fire"] = (t > 0.5 and t < 0.53) or (t > 0.82 and t < 0.85)
		"thf_vault":
			if _at(t, dt, 0.5): P.dashes = P.max_dashes(); P.inp["move"] = Vector2(0, 1); P.do_dash()
		"thf_primed":
			if _at(t, dt, 0.5): P.dashes = P.max_dashes(); P.inp["move"] = Vector2(0, 1); P.do_dash()
			P.inp["fire"] = t > 0.76 and t < 0.8
			if P.ammo < 3: P.ammo = int(P.wpn["mag"])
		"thf_bola":
			if _at(t, dt, 0.5): K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; P.inp["sec_hold"] = false; K.press_rmb()
		"thf_knife":
			if _at(t, dt, 0.5): K.cd["e"] = 0.0; K.use_e()
			if _at(t, dt, 0.95): K.use_e()
		"thf_volley":
			if _at(t, dt, 0.4): (K as ThiefKit).add_mark(D, 4, true)
			P.inp["fire"] = t > 0.45 and t < 0.6
			if P.ammo < 3: P.ammo = int(P.wpn["mag"])
		"jug_slash":
			if t < 0.35: P.teleport(Vector3(D.pos.x - 2.4, P.pos.y, D.pos.z))
			P.inp["fire"] = (t > 0.4 and t < 0.42) or (t > 0.76 and t < 0.78)
		"jug_wave":
			P.inp["fire"] = t > 0.3 and t < 1.44
		"jug_slam":
			P.slot_lv["sec"] = 3          # rank 3: the sweet spot (2.6m out) also crashes
			if t < 0.45: P.teleport(Vector3(D.pos.x - 2.6, P.pos.y, D.pos.z))
			if _at(t, dt, 0.5): K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; P.inp["sec_hold"] = false; K.press_rmb()
		"jug_lunge":
			if _at(t, dt, 0.5): K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; K.bot_hold["rmb"] = 1.0; K.press_rmb()
		"jug_meteor":
			if _at(t, dt, 0.4): P.teleport(Vector3(D.pos.x - 1.2, P.pos.y + 3.0, D.pos.z)); P.grounded = false; P.vel = Vector3.ZERO
			if _at(t, dt, 0.5): K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; K.press_rmb()
		"jug_dash":
			if _at(t, dt, 0.5): P.dashes = P.max_dashes(); P.do_dash()
		"jug_chain":
			if _at(t, dt, 0.5): K.cd["e"] = 0.0; K.use_e()
			if _at(t, dt, 0.9): K.use_e()
		"jug_chainlunge":
			if _at(t, dt, 0.5): K.cd["e"] = 0.0; K.use_e()
			if _at(t, dt, 0.8): K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; K.bot_hold["rmb"] = 1.0; K.press_rmb()
		"jug_haul":
			if _at(t, dt, 0.5): K.cd["e"] = 0.0; K.use_e()
			if _at(t, dt, 0.8): K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; K.bot_hold["rmb"] = 1.5; K.press_rmb()
			if _at(t, dt, 1.2): K.use_e()
		"jug_spin":
			if _at(t, dt, 0.5): K.cd["e"] = 0.0; K.use_e()
			if _at(t, dt, 0.84): K.use_e()
			if _at(t, dt, 0.88): K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; P.inp["sec_hold"] = false; K.press_rmb()

## One frame of the strip: a square round the hunter; the last one writes the strip and quits.
static func _grab(A: Arena, P: Hunter, last: bool) -> void:
	var m := A.m
	var img := m.get_viewport().get_texture().get_image()
	var cam := m.get_viewport().get_camera_3d()
	var c := Vector2(img.get_width() * 0.5, img.get_height() * 0.5)
	if cam: c = cam.unproject_position(P.position + Vector3(0, 0.9, 0))
	var S := 300
	var r := Rect2i(Vector2i(int(c.x) - S / 2, int(c.y) - S / 2), Vector2i(S, S))
	r.position.x = clampi(r.position.x, 0, img.get_width() - S)
	r.position.y = clampi(r.position.y, 0, img.get_height() - S)
	var frames: Array = A.get_meta("strip", [])
	frames.append(img.get_region(r))
	A.set_meta("strip", frames)
	if not last:
		return
	var out := Image.create(S * frames.size() + 4 * (frames.size() - 1), S, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.06, 0.06, 0.08))
	for i in frames.size():
		var f: Image = frames[i]
		f.convert(Image.FORMAT_RGBA8)
		out.blit_rect(f, Rect2i(Vector2i.ZERO, Vector2i(S, S)), Vector2i(i * (S + 4), 0))
	var path := shot_path()
	if path != "":
		out.save_png(path)
		print("ARENASHOT ", path)
	m.get_tree().quit()

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
