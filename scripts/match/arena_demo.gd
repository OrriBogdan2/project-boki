class_name ArenaDemo
extends RefCounted
## Screenshot tooling for the Arena: --arena-demo=<what> --arena-shot=<png> plays a scripted moment
## and saves the frame at the scripted time, then quits.
##   thief       SMG hits stack Marks on the dummy (3 = the coin), Vault Primes the next hit (gold glint)
##   primed      the same, ending on the Primed hit landing (VAULT RESET, the payoff)
##   bola        the Thief's Bola catching two dummies: Grounded, TANGLED
##   juggernaut  greatsword slashes fill Rage (the shoulder glow), the Enraged form
##   sweetspot   then a Finishing Slam winds up and lands its sweet spot (--hold-shot: the wind-up)
##   encore / encorehit   Sable's X: the ring growing (the telegraph), then a volley landing (the impact)
##   riposte / ripostehit Kael's X: the guard with its strip (the telegraph), then the cleave landing
##   wave        the greatsword held into a Searing Wave (--hold-shot: at full charge)
##   archer      a rooted dummy: the aim line and crosshairs over it
##   hero_<id>_<move>   Ryzz (mage) and Vex (gunslinger) moments, see scripts/arch/hero_demo.gd
##   bulwark     the shield raised and burning gold, Guard pips full (Shield Slam armed)
##   crushed     the same, then letting go: a Shield Slam into the pillar, Crushed
##   e_<a> / r_<a> / rmb_<a>   any archetype's E, R or RMB on the still dummy (--e-recast: press E again)
##   card / card_<archetype>   the kit card (K); card_detail: the RMB detail page
##   menu        the loadout panel (L)
##   anim_<move> a strip of frames of one kit move (ANIM_DEMO: arc_* and bul_* for the Archer and Bulwark;
##               PairDemo.ANIM for Dolm and Ostra; DJDemo.ANIM thf_* and jug_* for Sable and Juggernaut)
##   pose        the Hunter standing turned 3/4 toward the camera (--demo-zoom=1 for the match camera)
##   smg         the SMG firing at the dummy; add --legacy-shots for the old look and numbers (before)

const OLD_SMG := {
	"dmg": 2.76,
	"rate": 0.07,
	"speed": 55.0,
	"mag": 36,
	"kb": 0.5,
	"size": 0.1,
	"kick": 0.0,
	"tracer": 0.5
}


## px: the widest strip PNG written (the owner's review shots stay at most this wide)
const STRIP_MAX_W := 1280
## --arena-demo=anim_<move>: a strip of frames of one kit move, cropped round the hunter, side by side
## (the frame times are in seconds of the demo; the move is triggered at 0.5 unless noted).
const ANIM_DEMO := {
	"arc_draw": ["archer", "longbow", [0.45, 0.6, 0.8, 1.0, 1.35, 1.5]],
	"arc_loose": ["archer", "longbow", [0.8, 0.88, 0.94, 1.0, 1.12, 1.3]],
	"arc_heavy_wind": ["archer", "longbow", [0.55, 0.7, 0.9, 1.1, 1.3, 1.6]],
	"arc_heavy": ["archer", "longbow", [1.2, 1.35, 1.42, 1.48, 1.58, 1.8]],
	"arc_hail": ["archer", "longbow", [0.5, 0.56, 0.64, 0.74, 0.95, 1.2]],
	"pin_roll": ["archer", "longbow", [0.5, 0.56, 0.62, 0.7, 0.8, 0.95]],
	"arc_super": ["archer", "longbow", [1.6, 1.66, 1.7, 1.75, 1.85, 2.1]],
	"arc_tap": ["archer", "longbow", [0.5, 0.56, 0.6, 0.66, 0.74, 0.9]],
	"arc_perfect": ["archer", "longbow", [0.98, 1.06, 1.12, 1.2, 1.32, 1.5]],
	"arc_over": ["archer", "longbow", [1.5, 1.95, 2.05, 2.15, 2.25, 2.4]],
	"arc_over_loose": ["archer", "longbow", [2.3, 2.42, 2.48, 2.56, 2.7, 2.95]],
	"pin_walk": ["archer", "longbow", [0.5, 0.6, 0.8, 1.2, 1.8, 2.6]],
	"pin_flick": ["archer", "longbow", [0.5, 0.54, 0.58, 0.63, 0.7, 0.85]],
	"bul_throw": ["bulwark", "tower_shield", [0.5, 0.6, 0.7, 0.78, 0.92, 1.12]],
	"bul_recall": ["bulwark", "tower_shield", [0.98, 1.05, 1.12, 1.2, 1.3, 1.5]],
	"bul_smash_wind": ["bulwark", "tower_shield", [0.5, 0.7, 0.9, 1.1, 1.4, 1.7]],
	"bul_smash": ["bulwark", "tower_shield", [1.1, 1.2, 1.25, 1.3, 1.4, 1.65]],
	"bul_smash_late": ["bulwark", "tower_shield", [1.75, 1.97, 2.03, 2.1, 2.2, 2.45]],
	"bul_launch": ["bulwark", "tower_shield", [1.68, 1.74, 1.8, 1.88, 1.98, 2.15]],
	"bul_launch_glide": ["bulwark", "tower_shield", [1.68, 1.76, 1.86, 1.98, 2.15, 2.5]],
	"bul_ult_walk": ["bulwark", "tower_shield", [0.75, 0.92, 1.25, 1.45, 1.65]],
	"bul_jump_swing": ["bulwark", "tower_shield", [0.95, 1.08, 1.2, 1.28, 1.36, 1.6]],
	"bul_dash_hold": ["bulwark", "tower_shield", [0.88, 0.95, 1.05, 1.2, 1.43, 1.62]],
	"bul_jump_launch": ["bulwark", "tower_shield", [1.45, 1.6, 1.7, 1.76, 1.88, 2.1]],
	"bul_whirl": ["bulwark", "tower_shield", [0.5, 0.58, 0.7, 0.76, 0.84, 1.0]],
	"bul_charge": ["bulwark", "tower_shield", [0.7, 0.75, 0.82, 0.9, 1.0, 1.2]],
	"bul_short": ["bulwark", "tower_shield", [0.85, 0.92, 0.98, 1.05, 1.15, 1.35]],
	"bul_mend": ["bulwark", "tower_shield", [0.5, 0.56, 0.64, 0.74, 0.95, 1.25]],
	"pin_ult_cast": ["archer", "longbow", [0.5, 0.56, 0.62, 0.7, 0.8, 0.95]],
	"pin_ult_nock": ["archer", "longbow", [0.5, 0.58, 0.66, 0.74, 0.8]],
	"pin_ult_loose": ["archer", "longbow", [0.8, 0.86, 0.92, 1.0, 1.1, 1.25]],
	"pin_ult_final": ["archer", "longbow", [0.8, 0.86, 0.92, 1.0, 1.08, 1.25]],
	"bul_ult_wind": ["bulwark", "tower_shield", [0.5, 0.58, 0.66, 0.76, 0.86]],
	"bul_ult_slam": ["bulwark", "tower_shield", [0.86, 0.91, 1.2, 1.5, 1.8]],
	"bul_guard": ["bulwark", "tower_shield", [0.5, 0.56, 0.62, 0.7, 0.9, 1.2]],
	"bul_crush": ["bulwark", "tower_shield", [0.5, 0.58, 0.64, 0.72, 0.85, 1.05]],
	"bul_slamshield": ["bulwark", "tower_shield", [0.5, 0.62, 0.76, 0.84, 0.95, 1.2]],
	"bul_break": ["bulwark", "tower_shield", [0.5, 0.54, 0.58, 0.68, 0.85, 1.1]],
	"bul_armed": ["bulwark", "tower_shield", [0.5, 0.55, 0.6, 0.68, 0.76, 0.86]],
	"bul_lumber": ["bulwark", "tower_shield", [0.5, 0.56, 0.62, 0.72, 0.85, 1.05]],
}

static func what() -> String:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--arena-demo="): return String(a).substr(13)
	return ""

static func shot_path() -> String:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--arena-shot="): return String(a).substr(13)
	return ""

## The demo's camera zoom: --demo-zoom=<z> (1.0 is the gameplay default) or the close-up `close`.
static func zoom_or(close: float) -> float:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--demo-zoom="): return float(String(a).substr(12))
	return close

## The pose demo's facing: --demo-face=dx,dz turns the Hunter toward that offset (default: 3/4 toward the camera,
## her right side to it; Hem's review uses 5,3.5 so the bow in her left hand is on the camera's side).
static func _face(fallback: Vector3) -> Vector3:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--demo-face="):
			var f := String(a).get_slice("=", 1).split(",")
			if f.size() == 2:
				return Vector3(float(f[0]), 0.9, float(f[1]))
	return fallback

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
		m.set_meta("zoom_hold", zoom_or(0.6))      # close enough to read the hits
		m.cam.zoom = zoom_or(0.6)
	if w.begins_with("care_"):
		CareDemo.tick(A, dt, w)          # the support pair (care_demo.gd)
		return
	P.hp = P.max_hp
	if w == "pose_clear":
		at_t = _pose_clear(A, P, t)      # (the review frame, below)
	match w:
		_ when w.begins_with("pr_") or w in ["card_dredge", "card_ashwick"]:
			at_t = ArenaDemoPair.tick(A, w, t, dt)      # Dredge and Cinder (arena_demo_pair.gd)
		"thief", "primed":
			# kits2: SMG hits on the dummy stack Marks (gold diamonds, one per Mark), Vault Primes the next
			# hit (the gold glint, PRIMED), then (primed) the Primed hit lands: VAULT RESET
			if t < 0.05:
				if P.arch != "thief" or P.wid != "arc_bolts": A.set_arch("thief", "arc_bolts")
				A.set_kin("puddlet")
				P.teleport(D.pos + Vector3(1.6, 0, 1.9))
				A.home = P.pos
			_aim(P, D)
			P.inp["move"] = Vector2.ZERO
			P.inp["fire"] = t > 0.2 and t < 1.2
			if P.ammo < 3: P.ammo = int(P.wpn["mag"])
			var TK := P.ak as ThiefKit
			if _at(t, dt, 1.3):
				P.dashes = P.max_dashes()
				P.inp["move"] = Vector2(-1, 0)
				P.do_dash()
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
				if P.arch != "thief": A.set_arch("thief", "arc_bolts")
				A.set_kin("puddlet")
				P.teleport(D.pos + Vector3(-3.4, 0, 0.2))
				A.home = P.pos
			if t < 0.6: # behind the dummy, along the throw
				H.teleport(D.pos + (D.pos - P.pos).normalized() * 2.6)
				H.vel = Vector3.ZERO
			_aim(P, D)
			P.inp["move"] = Vector2.ZERO
			if _at(t, dt, 0.4):
				P.ak.ch_rmb = 1.0
				P.ak.press_rmb()
			if (P.ak as ThiefKit).bola_pairs > 0 and not A.has_meta("bp_at"): A.set_meta("bp_at", t)
			at_t = float(A.get_meta("bp_at", 9.0)) + 0.12
		"juggernaut", "sweetspot":
			# greatsword slashes fill Rage (the shoulder glow) into the Enraged form; (sweetspot) then a
			# Finishing Slam winds up (the warning) and lands its sweet spot
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
				if _at(t, dt, 1.2):
					P.teleport(H2.pos - Vector3(H2.pos.x - P.pos.x, 0, H2.pos.z - P.pos.z).normalized() * 2.5)
				if _at(t, dt, 1.25):
					P.hp = P.max_hp * 0.6
					P.ak.ch_rmb = 1.0
					P.ak.cd["rmb"] = 0.0
					P.inp["sec_hold"] = false
					P.ak.press_rmb()
				if w == "sweetspot" and "--hold-shot" in OS.get_cmdline_user_args(): at_t = 1.5
				else:
					if JK.sweet_spots > 0 and not A.has_meta("ss_at"): A.set_meta("ss_at", t)
					at_t = float(A.get_meta("ss_at", 9.0)) + 0.08
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
		"encore", "encorehit":
			# Sable's Encore: the dummy stands in the ring's outer band, a second one inside it
			if t < 0.05:
				if P.arch != "thief" or P.wid != "arc_bolts": A.set_arch("thief", "arc_bolts")
				A.set_kin("puddlet")
				P.teleport(D.pos + Vector3(-4.6, 0, 0.6))
				A.home = P.pos
			_aim(P, D)
			P.inp["move"] = Vector2.ZERO
			if _at(t, dt, 0.3): DJDemo.cast_ult(P)
			at_t = 0.55 if w == "encore" else 1.24
		"riposte", "ripostehit":
			# Kael's Gilded Riposte: the guard with the strip toward the dummy, then the cleave through it
			if t < 0.05:
				if P.arch != "juggernaut" or P.wid != "greatsword": A.set_arch("juggernaut", "greatsword")
				A.set_kin("cindle")
				P.teleport(D.pos + Vector3(-2.6, 0, 0.4))
				A.home = P.pos
			_aim(P, D)
			P.inp["move"] = Vector2.ZERO
			if _at(t, dt, 0.3): DJDemo.cast_ult(P)
			at_t = 0.75 if w == "riposte" else 1.07
		"archer":
			if t < 0.05:
				if P.arch != "archer": A.set_arch("archer", "longbow")
				A.set_kin("puddlet")
				P.teleport(D.pos + Vector3(0.5, 0, -2.2))
				A.home = P.pos
			_aim(P, D)
			P.inp["move"] = Vector2.ZERO
			# (keep it pinned for the frame)
			if t > 0.35 and t < 2.0: D.root_t = maxf(D.root_t, 0.8)
			at_t = 1.9
		_ when w.begins_with("hero_"):
			at_t = HeroDemo.tick(A, P, D, t, dt, w)         # Ryzz and Vex (scripts/arch/hero_demo.gd)
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
				if _at(t, dt, go):
					P.ak.cd["e"] = 0.0
					P.ak.use_e()
				# (the Shadow Step / the haul)
				if "--e-recast" in OS.get_cmdline_user_args() and _at(t, dt, go + 0.45): P.ak.use_e()
				at_t = go + float(
					A.get_meta("e_shot_after", 0.9 if "--e-recast" not in OS.get_cmdline_user_args() else 0.62)
				)
			elif w.begins_with("r_"):
				if _at(t, dt, go):
					P.ak.cd["r"] = 0.0
					P.ak.use_r()
				# (an empowered-shot ult fires through)
				if t > go + P.ak.fuse_time() + 0.1 and t < go + P.ak.fuse_time() + 1.2: P.inp["fire"] = true
				at_t = go + P.ak.fuse_time() + (1.3 if "--late-shot" in OS.get_cmdline_user_args() else 0.75)
				# (before: the wind-up)
				if "--fuse-shot" in OS.get_cmdline_user_args(): at_t = go + P.ak.fuse_time() * 0.7
				# (the moment it lands)
				if "--impact-shot" in OS.get_cmdline_user_args(): at_t = go + P.ak.fuse_time() + 0.1
			else:
				if _at(t, dt, go):
					P.ak.ch_rmb = float(P.ak.rmb_charges())
					P.ak.bot_hold["rmb"] = 0.9
					P.ak.press_rmb()
				at_t = go + 0.7 if "--hold-shot" in OS.get_cmdline_user_args() else go + 1.05
		_ when w.begins_with("dj_"):
			at_t = DJDemo.still(A, P, D, w.substr(3), t, dt)      # Sable and Kael stills (scripts/arch/dj_demo.gd)
			if m.hud: m.hud.msgs.clear()
		_ when w.begins_with("pair_"):
			at_t = PairDemo.tick(A, P, D, t, dt, w)          # Tarek and Ostra (scripts/arch/pair_demo.gd)
		_ when w.begins_with("anim_"):
			var mv := w.substr(5)
			var spec: Array = ANIM_DEMO.get(mv,
					PairDemo.ANIM.get(mv, DJDemo.ANIM.get(mv, ["thief", "arc_bolts", [1.0]])))
			if t < 0.05:
				if P.arch != String(spec[0]) or P.wid != String(spec[1]): A.set_arch(String(spec[0]), String(spec[1]))
				A.set_kin("")
				P.teleport(D.pos + Vector3(-4.0, 0, 0))
				A.home = P.pos
				var strip_zoom := _anim_zoom()
				if m.cam: m.cam.zoom = strip_zoom
				m.set_meta("zoom_hold", strip_zoom)
				m.get_viewport().warp_mouse(Vector2(4, 4))      # the cursor's crosshair off the hunter
				if m.cam: m.cam.lead = 0.0                       # ... without the camera leaning toward it
			_aim(P, D)
			P.inp["move"] = Vector2.ZERO
			P.hp = P.max_hp
			_anim_trigger(A, P, D, mv, t, dt)
			if m.hud: m.hud.msgs.clear()        # the hero line from the swap would sit over the frames
			var times: Array = spec[2]
			for i in times.size():
				if _at(t, dt, float(times[i])):
					var last := i == times.size() - 1
					m.get_tree().process_frame.connect(func(): _grab(A, P, last), CONNECT_ONE_SHOT)
			at_t = 99.0
		"pose":
			# the Hunter standing at the match camera, turned three-quarters toward it (Warden model shots);
			# --demo-at=dx,dz first moves it onto clear ground (review shots: no prop over the hero). pose_clear is
			# the review frame (_pose_clear, above the match)
			if t < 0.05:
				for a in OS.get_cmdline_user_args():
					if String(a).begins_with("--demo-at="):
						var at := String(a).get_slice("=", 1).split(",")
						P.teleport(P.pos + Vector3(float(at[0]), 0.0, float(at[1])))
						A.home = P.pos
			P.inp["move"] = Vector2.ZERO
			P.inp["aim"] = P.pos + _face(Vector3(-5.0, 0.9, 3.5))
			at_t = 2.0
		"bulwark", "crushed":
			var H: Hunter = A.dummies[2]["h"]
			if t < 0.05:
				if P.arch != "bulwark": A.set_arch("bulwark", "tower_shield")
				A.set_kin("cindle")
				P.teleport(H.pos + Vector3(-1.1, 0, 1.6))
				A.home = P.pos
			_aim(P, H)
			P.inp["move"] = Vector2.ZERO
			if _at(t, dt, 0.25): # raise the shield
				P.ak.bot_hold["rmb"] = 0.95 if w == "crushed" else 3.0
				P.ak.press_rmb()
			# (blocked fire becomes Guard)
			if t > 0.3 and t < 1.2: P.ak.add_guard(dt * 70.0)
			if w == "bulwark":
				at_t = 1.6
			else:
				if int(P.ak.get("crushes")) > 0 and not A.has_meta("cr_at"): A.set_meta("cr_at", t)
				at_t = float(A.get_meta("cr_at", 9.0)) + 0.06
		"card", "card_juggernaut", "card_detail", "card_detail_passive", "card_archer", "card_mage", "card_gunslinger", "card_bulwark", "card_tender", "card_rimewright":
			if t < 0.05:
				var ca: String = {
					"card_juggernaut": "juggernaut",
					"card_archer": "archer",
					"card_mage": "mage",
					"card_gunslinger": "gunslinger",
					"card_bulwark": "bulwark",
					"card_tender": "tender",
					"card_rimewright": "rimewright"
				}.get(w, "thief")
				A.set_arch(ca)
				A.set_kin("cindle" if ca in ["juggernaut", "mage", "bulwark", "tender"] else "puddlet")
			if _at(t, dt, 0.3):
				A.toggle_card()
				if w == "card_detail" or w == "card_detail_passive":
					var c := A.card_layer.find_children("*", "KitCard", true, false)
					if not c.is_empty(): (c[0] as KitCard)._show_detail("rmb" if w == "card_detail" else "passive")
				_shot_later(A, 0.7)       # the card pauses the match: shoot on a wall-clock timer
			at_t = 99.0
		"menu":
			if t < 0.05:
				A.give_glove("blink", 0)
				A.give_glove("grapple", 1)
			if _at(t, dt, 0.3):
				A.open_menu()
				_shot_later(A, 0.7)
			at_t = 99.0
		"smg":
			if not A.has_meta("demo_set"):
				A.set_meta("demo_set", true)
				A.set_arch("thief", "arc_bolts")
				P.teleport(D.pos + Vector3(-4.0, 0, 2.5))
				A.home = P.pos
				if legacy:
					for k in OLD_SMG: P.wpn[k] = OLD_SMG[k]
			_aim(P, D)
			P.inp["fire"] = t > 0.3
			if P.ammo < 3: P.ammo = int(P.wpn["mag"])
			at_t = 1.05
	for a in OS.get_cmdline_user_args():
		# (any moment, in demo seconds)
		if String(a).begins_with("--shot-at=") and not w.begins_with("anim_"): at_t = float(String(a).substr(10))
	if t >= at_t and not A.has_meta("demo_shot"):
		A.set_meta("demo_shot", true)
		var path := shot_path()
		if path != "":
			# one more drawn frame so this step's effects are on screen, then save and quit
			m.get_tree().process_frame.connect(func():
				m.get_tree().process_frame.connect(func():
					m.get_viewport().get_texture().get_image().save_png(path)
					print("ARENASHOT ", path)
					if A.has_meta("demo_hero_rect"):      # (pose_clear: where the hero is, for the review crop)
						var hr: Rect2 = A.get_meta("demo_hero_rect")
						print("DEMO_HERO_RECT %d,%d,%d,%d" % [hr.position.x, hr.position.y, hr.size.x, hr.size.y])
					m.get_tree().quit(), CONNECT_ONE_SHOT), CONNECT_ONE_SHOT)

## The scripted input for each kit move's strip.
static func _anim_trigger(A: Arena, P: Hunter, D: Hunter, mv: String, t: float, dt: float) -> void:
	var K: ArchKit = P.ak
	if PairDemo.ANIM.has(mv):
		PairDemo.trigger(P, D, mv, t, dt)
		return
	if DJDemo.ANIM.has(mv):
		DJDemo.trigger(P, D, mv, t, dt)          # Sable and Juggernaut (scripts/arch/dj_demo.gd)
		return
	match mv:
		"arc_draw", "arc_loose", "arc_heavy_wind", "arc_heavy", "arc_hail", "pin_roll", "arc_super", "arc_tap", "arc_perfect", "arc_over", "arc_over_loose", "pin_walk", "pin_flick", "bul_guard", "bul_crush", "bul_slamshield", "bul_break", "bul_armed", "bul_lumber", "bul_throw", "bul_recall", "bul_smash_wind", "bul_smash", "bul_whirl", "bul_charge", "bul_short", "bul_mend":
			_anim_hero(A, P, mv, t, dt)
		"pin_ult_cast", "pin_ult_nock", "pin_ult_loose", "pin_ult_final", "bul_ult_wind", "bul_ult_slam":
			_anim_ult(P, mv, t, dt)
		"bul_smash_late", "bul_launch", "bul_launch_glide", "bul_ult_walk", "bul_jump_swing", "bul_dash_hold", \
				"bul_jump_launch":
			_anim_bjorn(A, P, mv, t, dt)

## The scripted input for the Archer's and Bulwark's kit moves (the accuracy pass).
static func _anim_hero(A: Arena, P: Hunter, mv: String, t: float, dt: float) -> void:
	var K: ArchKit = P.ak
	var fire := false
	if mv != "bul_slamshield":
		K.res = 0.0            # no Guard tell in the strips (the Shield Slam needs its Guard)
	# dashes go across the screen, clear of the dummy ahead (a strip used to end inside its model)
	if mv in ["pin_roll", "pin_walk", "pin_flick", "bul_lumber", "bul_whirl", "bul_short"]:
		P.inp["move"] = Vector2(0, 1)
	match mv:
		"arc_draw": fire = t > 0.4 and t < 1.7
		"arc_loose": fire = t > 0.4 and t < 0.9
		"arc_heavy_wind":
			if _at(t, dt, 0.5):
				K.ch_rmb = 2.0
				K.cd["rmb"] = 0.0
				K.bot_hold["rmb"] = 1.6
				K.press_rmb()
		"arc_heavy":
			if _at(t, dt, 0.5):
				K.ch_rmb = 2.0
				K.cd["rmb"] = 0.0
				K.bot_hold["rmb"] = 0.9
				K.press_rmb()
		"arc_hail":
			if _at(t, dt, 0.5):
				K.cd["e"] = 0.0
				K.use_e()
		"pin_roll":
			if _at(t, dt, 0.5):
				P.dashes = P.max_dashes()
				P.do_dash()
		"arc_super": fire = t > 0.4 and t < 1.6
		"bul_throw": fire = t > 0.5 and t < 0.53
		"bul_recall": fire = (t > 0.4 and t < 0.43) or (t > 1.0 and t < 1.03)
		"bul_smash_wind": fire = t > 0.4 and t < 2.0
		"bul_smash": fire = t > 0.4 and t < 1.2
		"bul_whirl":
			if _at(t, dt, 0.5):
				P.dashes = P.max_dashes()
				P.do_dash()
		"bul_charge":
			if _at(t, dt, 0.3):
				K.ch_rmb = 1.0
				K.cd["rmb"] = 0.0
				K.bot_hold["rmb"] = 3.0
				K.press_rmb()
			if _at(t, dt, 0.7):
				P.dashes = P.max_dashes()
				P.do_dash()
		"bul_short":
			fire = t > 0.4 and t < 1.6
			if _at(t, dt, 0.9):
				P.dashes = P.max_dashes()
				P.do_dash()
		"bul_mend":
			if _at(t, dt, 0.5):
				K.cd["e"] = 0.0
				K.use_e()
		"arc_tap": fire = t > 0.4 and t < 0.5
		"arc_perfect": fire = t > 0.35 and t < 0.35 + 0.62
		"arc_over", "arc_over_loose": fire = t > 0.4 and t < 2.3
		"pin_walk":
			if _at(t, dt, 0.5):
				P.dashes = P.max_dashes()
				P.do_dash()
		"pin_flick", "bul_lumber":
			if _at(t, dt, 0.5):
				P.dashes = 0.0
				P.ex_cd = 0.0
				P.do_dash()
		"bul_crush", "bul_break", "bul_armed": if _at(t, dt, 0.5): K.play(mv)
		"bul_guard":
			P.inp["sec_hold"] = t > 0.45
			if _at(t, dt, 0.5):
				K.ch_rmb = 1.0
				K.cd["rmb"] = 0.0
				K.set("lock_t", 0.0)
				K.press_rmb()
		"bul_slamshield":
			K.res = maxf(K.res, 60.0)
			if _at(t, dt, 0.3):
				K.ch_rmb = 1.0
				K.cd["rmb"] = 0.0
				K.bot_hold["rmb"] = 3.0
				K.press_rmb()
			if _at(t, dt, 0.7):
				P.dashes = P.max_dashes()
				P.do_dash()
	P.inp["fire"] = fire

## The X ultimates' strips: Starpiercer cast at 0.5 (its beams from a press at 0.5 after a cast at 0.3, the
## last one with a single shot left), Faultline cast at 0.5.
static func _anim_ult(P: Hunter, mv: String, t: float, dt: float) -> void:
	var K: ArchKit = P.ak
	P.lvl = 6
	K.res = 0.0                # no resource tell in the strip
	var cast_at := 0.5 if mv in ["pin_ult_cast", "bul_ult_wind", "bul_ult_slam"] else 0.3
	if _at(t, dt, cast_at):
		K.cd["x"] = 0.0
		HunterKeys.ult_pressed(P)
		if mv == "pin_ult_final":
			(K as ArcherKit).ult.left = 1
	P.inp["fire"] = mv.begins_with("pin_ult_") and mv != "pin_ult_cast" and t > 0.5 and t < 0.6

## Breaker's owner-review strips (#48, #49, #51): a full swing let go after the perfect window, one let go in it,
## one in it at an island's edge (it carries him over and he glides), Faultline cast with him walking off
## across the lane after the plant; the hold through a jump let go in the air, through a Shift dash let go
## after it, and through a jump let go in the window (the launch from the air).
static func _anim_bjorn(A: Arena, P: Hunter, mv: String, t: float, dt: float) -> void:
	P.ak.res = 0.0
	if mv in ["bul_smash_late", "bul_launch", "bul_jump_swing", "bul_dash_hold", "bul_jump_launch"]:
		if _at(t, dt, 0.1):
			P.teleport(P.pos + Vector3(-1.0, 0, 3.0))      # a lane south of the dummy: the travel reads clear of it
			A.home = P.pos
		P.inp["aim"] = P.pos + Vector3(8.0, 0.9, 0)
	match mv:
		"bul_smash_late": P.inp["fire"] = t > 0.4 and t < 1.95
		"bul_launch": P.inp["fire"] = t > 0.4 and t < 1.7
		"bul_launch_glide":
			if _at(t, dt, 0.1):
				P.teleport(_edge_spot(A.m, P.pos))
				A.home = P.pos
			P.inp["aim"] = P.pos + Vector3(8.0, 0.9, 0)
			P.inp["fire"] = t > 0.4 and t < 1.7
		"bul_ult_walk":
			_anim_ult(P, "bul_ult_wind", t, dt)
			P.inp["move"] = Vector2(0, 1) if t > 0.5 else Vector2.ZERO
		"bul_jump_swing":
			P.inp["move"] = Vector2(1, 0) if t > 0.6 else Vector2.ZERO
			P.inp["fire"] = t > 0.4 and t < 1.25
			P.inp["jump"] = _at(t, dt, 1.0)
		"bul_dash_hold":
			P.inp["fire"] = t > 0.4 and t < 1.4
			if _at(t, dt, 0.9):
				P.dashes = P.max_dashes()
				P.do_dash()
		"bul_jump_launch":
			P.inp["fire"] = t > 0.4 and t < 1.71
			P.inp["jump"] = _at(t, dt, 1.45)

## A spot 2.5 m back from an island's east edge (flat ground behind, the abyss in front), nearest `near`.
static func _edge_spot(m: Match, near: Vector3) -> Vector3:
	var W: World = m.world
	var best := near
	var best_d := INF
	for z in range(4, W.h - 4):
		for x in range(8, W.w - 12):
			var lv := int(W.level[W.idx(x, z)])
			var ok := true
			for dz in range(-2, 3):
				for dx in range(-5, 11):
					var i := W.idx(x + dx, z + dz)
					var want_ground := dx <= 0
					if (W.kind[i] == World.T_GROUND) != want_ground or (want_ground and int(W.level[i]) != lv):
						ok = false
						break
				if not ok:
					break
			var q := Vector3(x - 2.0, lv * World.LEVEL, z + 0.5)
			if ok and q.distance_to(near) < best_d:
				best = q
				best_d = q.distance_to(near)
	return best

## One frame of the strip: a square round the hunter (--strip-w=<px> widens it toward the dummy, east, so a
## shot's flight and impact fit, and the frames then stack top to bottom; --strip-fixed holds it on the spot
## the move started from, so the hunter's travel shows); the last one writes the strip, at
## most STRIP_MAX_W wide, and quits.
static func _grab(A: Arena, P: Hunter, last: bool) -> void:
	var m := A.m
	var img := m.get_viewport().get_texture().get_image()
	var cam := m.get_viewport().get_camera_3d()
	var c := Vector2(img.get_width() * 0.5, img.get_height() * 0.5)
	var anchor := A.home if "--strip-fixed" in OS.get_cmdline_user_args() else P.position
	if cam: c = cam.unproject_position(anchor + Vector3(0, 0.9, 0))
	var S := 300
	var wide := S
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--strip-w="): wide = maxi(S, int(String(a).substr(10)))
	var r := Rect2i(Vector2i(int(c.x) - S / 2, int(c.y) - S / 2), Vector2i(wide, S))
	r.position.x = clampi(r.position.x, 0, img.get_width() - wide)
	r.position.y = clampi(r.position.y, 0, img.get_height() - S)
	var frames: Array = A.get_meta("strip", [])
	frames.append(img.get_region(r))
	A.set_meta("strip", frames)
	if not last:
		return
	# wide frames stack top to bottom, square ones side by side
	var down := wide > S
	var n := frames.size()
	var out_w := wide if down else wide * n + 4 * (n - 1)
	var out := Image.create(out_w, S * n + 4 * (n - 1) if down else S, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.06, 0.06, 0.08))
	for i in n:
		var f: Image = frames[i]
		f.convert(Image.FORMAT_RGBA8)
		var at := Vector2i(0, i * (S + 4)) if down else Vector2i(i * (wide + 4), 0)
		out.blit_rect(f, Rect2i(Vector2i.ZERO, Vector2i(wide, S)), at)
	if out.get_width() > STRIP_MAX_W:
		out.resize(STRIP_MAX_W, out.get_height() * STRIP_MAX_W / out.get_width(), Image.INTERPOLATE_LANCZOS)
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

## The camera zoom of an anim strip: 0.42 (close) unless --anim-zoom=<z> asks for another (1.0 is the
## default gameplay zoom).
static func _anim_zoom() -> float:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--anim-zoom="):
			return float(String(a).substr(12))
	return 0.42

static func _at(t: float, dt: float, when: float) -> bool:
	var w := when - 0.0001          # (a step landing exactly on `when` must count once, whatever the rounding)
	return t >= w and t - dt < w

static func _aim(P: Hunter, T: Ent) -> void:
	P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
	P.inp["aim_y"] = T.pos.y


## --arena-demo=pose_clear, the review frame for Warden model shots (tools/meshy/recipe.py shots): the Hunter
## standing at the match camera turned 3/4 toward it, as "pose", on clear ground it finds near the start
## (--demo-at=dx,dz picks the spot by hand), with no HUD, caption, buttons, sign, aim line or prop over the hero
## (_clear_frame); the shot prints DEMO_HERO_RECT x,y,w,h, the hero on screen, for the x4 crop.
static func _pose_clear(A: Arena, P: Hunter, t: float) -> float:
	var m := A.m
	if t < 0.05:
		var at := _clear_spot(A)
		for a in OS.get_cmdline_user_args():
			if String(a).begins_with("--demo-at="):
				var d := String(a).get_slice("=", 1).split(",")
				at = P.pos + Vector3(float(d[0]), 0.0, float(d[1]))
		P.teleport(at)
		A.home = P.pos
		if m.cam:
			m.cam.lead = 0.0
			m.cam.snap(P.pos)
	_clear_frame(A, P, t)
	P.inp["move"] = Vector2.ZERO
	P.inp["aim"] = P.pos + _face(Vector3(-5.0, 0.9, 3.5))
	return 2.0

## --arena-demo=pose_clear: the review frame's spot, flat open ground near the start (no block, void or slope
## within 1.6 m, the island's edge 3 m off, 6 m from the sign and the dummies) with the fewest props round it.
static func _clear_spot(A: Arena) -> Vector3:
	var W: World = A.m.world
	var keep_off: Array = [A.home + Vector3(-3.2, 0, 1.2)]
	for dm in A.dummies:
		keep_off.append((dm["h"] as Hunter).pos)
	var props := _props(A.m).map(func(g): return (g as Array)[0])
	var best := A.home
	var best_k := INF
	for ring in 10:
		var rad := float(ring)
		for k in (1 if ring == 0 else 16):
			var x := A.home.x + cos(TAU * k / 16.0) * rad
			var z := A.home.z + sin(TAU * k / 16.0) * rad
			if not W._fits(x, z, 1.6) or W.is_void(x + 3.0, z) or W.is_void(x - 3.0, z) or W.is_void(x, z + 3.0) \
					or W.is_void(x, z - 3.0):
				continue
			var p := Vector3(x, W.ground_at(x, z), z)
			if keep_off.any(func(o): return Vector2(o.x - x, o.z - z).length() < 6.0):
				continue
			var near := props.filter(func(q): return Vector2(q.x - x, q.z - z).length() < 1.6).size()
			var score := float(near) + rad * 0.3
			if score < best_k:
				best_k = score
				best = p
	return best

## The review frame, each tick: no HUD or Arena caption and buttons (every CanvasLayer), no sign, name tags,
## aim line or kit resource tell; at 0.3 s (the camera settled) every prop whose box covers the hero on screen,
## grass tufts included, and the ambient motes go (they read as speckle round the hero at the match camera).
static func _clear_frame(A: Arena, P: Hunter, t: float) -> void:
	var m := A.m
	for n in m.get_tree().root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	if m.hud and m.hud is CanvasItem: (m.hud as CanvasItem).visible = false
	for l in m.find_children("*", "Label3D", true, false):
		(l as Label3D).visible = false
		if String((l as Label3D).text).contains("KIT CARD"):
			for post in m.get_children():
				var off := Vector2(post.position.x - l.position.x, post.position.z - l.position.z) \
						if post is MeshInstance3D else Vector2.ONE
				if off.length() < 0.05:
					(post as MeshInstance3D).visible = false
	if m.aim_line: m.aim_line.layers = 0
	if P.ak: P.ak.res = 0.0        # (no resource tell over the hero)
	var kit_aim := m.get_node_or_null("AimKit") as Node3D      # (a kit's own aim line and reticles)
	if kit_aim: kit_aim.visible = false
	if t < 0.3 or A.has_meta("demo_cleared"):
		return
	A.set_meta("demo_cleared", true)
	var cam := m.get_viewport().get_camera_3d()
	if cam == null:
		return
	var hero := Rect2(cam.unproject_position(P.pos), Vector2.ZERO)
	for y in [0.0, 1.2, 2.6]:
		for s in [Vector3(-1.1, 0, 0), Vector3(1.1, 0, 0), Vector3(0, 0, -1.1), Vector3(0, 0, 1.1)]:
			hero = hero.expand(cam.unproject_position(P.pos + s + Vector3(0, y, 0)))
	A.set_meta("demo_hero_rect", hero)
	hero = hero.grow(16.0)
	for g in _props(m):
		var gi: GeometryInstance3D = g[1]
		var box: AABB = g[2]
		var sr := Rect2(cam.unproject_position(box.position), Vector2.ZERO)
		for c in 8:
			sr = sr.expand(cam.unproject_position(box.get_endpoint(c)))
		if not sr.intersects(hero):
			continue
		if gi is MultiMeshInstance3D:
			var mmi := gi as MultiMeshInstance3D
			if not mmi.has_meta("demo_own"):
				mmi.multimesh = mmi.multimesh.duplicate()
				mmi.set_meta("demo_own", true)
			var gone := Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3.ZERO)
			mmi.multimesh.set_instance_transform(int(g[3]), gone)
		else:
			gi.layers = 0
	for n in m.find_children("*", "GPUParticles3D", true, false) + m.find_children("*", "CPUParticles3D", true, false):
		if not _on_ent(n):
			(n as Node3D).visible = false

## The props round the Arena (no hunter's or dummy's own parts, not the ground): [ground point, instance, its
## world box, multimesh instance index or -1], each grass tuft of a multimesh on its own.
static func _props(m: Node) -> Array:
	var out: Array = []
	for n in m.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if gi is Label3D or not gi.visible or _on_ent(gi):
			continue
		if gi is MultiMeshInstance3D:
			var mm := (gi as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null:
				continue
			var mb := mm.mesh.get_aabb()
			for i in (mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count):
				var box: AABB = (gi.global_transform * mm.get_instance_transform(i)) * mb
				if box.size.x < 5.0 and box.size.z < 5.0:
					out.append([box.get_center() - Vector3(0, box.size.y * 0.5, 0), gi, box, i])
		elif gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
			var box: AABB = gi.global_transform * (gi as MeshInstance3D).mesh.get_aabb()
			if box.size.x < 5.0 and box.size.z < 5.0:
				out.append([box.get_center() - Vector3(0, box.size.y * 0.5, 0), gi, box, -1])
	return out

static func _on_ent(n: Node) -> bool:
	var cur := n
	while cur:
		if cur is Ent:
			return true
		cur = cur.get_parent()
	return false
