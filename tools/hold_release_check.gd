extends RefCounted
## How a hold ends, for the five holds that matter (docs/heroes/hold_release_rules.md): Kael's RMB Lunge, Lace's
## Heavy Shot and bow draw, Sparkle's Skycall drag, Albert's Crushing Blow whirl and Tenzo's Basalt Spine drag.
## Each is driven through its endings (let go, stunned mid-hold, downed, another key) and asserted. The kits'
## --<hero>-combo-checks call their hero's function; A is the archetype check that carries the helpers.

const HOLD_T := 0.7      # s a hold runs before its ending (past every tap threshold, short of every auto-release)
const STUN_T := 0.5      # s the stun lasts

## Runs a hold for HOLD_T, applies the ending `ev` ("release" is none: the caller lets go next; "stun" | "down" |
## "key") and runs on 0.3 s with the input still down. `key` presses the other key for "key".
static func _ending(A, m: Match, P: Hunter, ev: String, key: Callable, held: Callable) -> void:
	A.step(m, HOLD_T, held)
	match ev:
		"stun": P.stun_t = STUN_T
		"down": m.knock(P, null, {})
		"key": key.call()
	A.step(m, 0.3, held)

static func _press_key(P: Hunter, which: String) -> void:
	match which:
		"rmb": P.ak.press_rmb()
		"e": P.ak.use_e()

## The RMB hold of `arch` (Kael's Lunge, Lace's Heavy Shot): whether the charge was spent, and the pose left behind.
static func _rmb_hold(A, arch: String, ev: String, which := "") -> Dictionary:
	var r = A.setup(arch, 14.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home := P.pos
	var held := func(): P.inp["sec_hold"] = true
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	_ending(A, m, P, ev, func(): _press_key(P, which), held)
	var out := {"held": P.ak.rmb_down, "anim": P.ak.anim_id}
	P.inp["sec_hold"] = false
	A.step(m, 0.4)
	out["spent"] = P.ak.ch_rmb < 1.0 or float(P.ak.cd["rmb"]) > 0.0
	out["moved"] = P.pos.distance_to(home)
	await A.done(m)
	return out

static func kael(A) -> void:
	var rel := await _rmb_hold(A, "juggernaut", "release")
	A.ok("hold kael RMB: let go lunges", rel["spent"] and rel["moved"] > 4.0, str(rel))
	for ev in ["stun", "down"]:
		var d := await _rmb_hold(A, "juggernaut", ev)
		A.ok("hold kael RMB: %s mid-hold drops it, no lunge, nothing spent" % ev,
				not d["spent"] and d["moved"] < 0.5 and not d["held"] and d["anim"] != "jug_lunge_wind", str(d))
	var key := await _rmb_hold(A, "juggernaut", "key", "e")
	A.ok("hold kael RMB: E mid-hold [?]: the charge goes on, lunges at let go",
			key["held"] and key["spent"], str(key))

## Lace's bow draw (LMB): whether she is still drawing after the ending, and what the dummy took once she let go.
static func _draw(A, ev: String, which := "") -> Dictionary:
	var r = A.setup("archer", 14.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var held := func():
		P.inp["fire"] = true
		A.aim_at(P, T.pos)
	P.inp["fire"] = true
	_ending(A, m, P, ev, func(): _press_key(P, which), held)
	var out := {"drawing": P.draw_t >= 0.0, "anim": P.ak.anim_id}
	P.inp["fire"] = false
	A.step(m, 1.2)
	out["dmg"] = A.dmg(T)
	await A.done(m)
	return out

static func lace(A) -> void:
	var rel := await _rmb_hold(A, "archer", "release")
	A.ok("hold lace Heavy Shot: let go looses it", rel["spent"], str(rel))
	for ev in ["stun", "down"]:
		var d := await _rmb_hold(A, "archer", ev)
		A.ok("hold lace Heavy Shot: %s mid-hold drops it, no arrow, nothing spent" % ev,
				not d["spent"] and not d["held"] and d["anim"] != "arc_heavy_wind", str(d))
	var key := await _rmb_hold(A, "archer", "key", "e")
	A.ok("hold lace Heavy Shot: E mid-hold [?]: the draw goes on, looses at let go",
			key["held"] and key["spent"], str(key))
	var dr := await _draw(A, "release")
	A.ok("hold lace draw: let go looses the arrow", dr["dmg"] > 0.0, str(dr))
	for ev in ["stun", "down"]:
		var d := await _draw(A, ev)
		A.ok("hold lace draw: %s mid-draw drops it, no arrow" % ev,
				not d["drawing"] and d["dmg"] == 0.0 and d["anim"] != "arc_draw", str(d))
	for which in ["rmb", "e"]:
		var k := await _draw(A, "key", which)
		A.ok("hold lace draw: %s mid-draw [?]: the draw goes on, looses at let go" % which,
				k["drawing"] and k["dmg"] > 0.0, str(k))

## Albert's Crushing Blow whirl (LMB): whether the whirl is up after the ending, and the swings it let go.
static func _whirl(A, ev: String, which := "") -> Dictionary:
	var r = A.setup("bulwark", 3.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var held := func():
		P.inp["fire"] = true
		A.aim_at(P, T.pos)
	P.inp["fire"] = true
	_ending(A, m, P, ev, func(): _press_key(P, which), held)
	var out := {"whirling": P.ak.lmb_t >= 0.0, "anim": P.ak.anim_id, "cut_slams": P.ak.slams}
	P.inp["fire"] = false
	A.step(m, 0.4)
	out["slams"] = P.ak.slams
	await A.done(m)
	return out

static func albert(A) -> void:
	var rel := await _whirl(A, "release")
	A.ok("hold albert whirl: let go swings the Crushing Blow", rel["slams"] == 1, str(rel))
	for ev in ["stun", "down"]:
		var d := await _whirl(A, ev)
		A.ok("hold albert whirl: %s mid-hold drops it, no swing" % ev,
				d["slams"] == 0 and not d["whirling"] and d["anim"] != "bul_smash_wind", str(d))
	for which in ["rmb", "e"]:
		var k := await _whirl(A, "key", which)
		# held fire (content/dash_flow/bulwark.json held_fire): the key still down starts a fresh hold once he is free
		A.ok("hold albert whirl: %s mid-hold [?] ends it with no swing, the held key holds again" % which,
				k["cut_slams"] == 0 and k["whirling"], str(k))

## Sparkle's Skycall (E held to drag): the drag phase right after the ending, and what the strike did to the dummy.
static func _skycall(A, ev: String, which := "") -> Dictionary:
	var r = A.setup("mage", 8.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var held := func(): P.inp["e_down"] = true
	P.inp["e_down"] = true
	A.aim_at(P, T.pos)
	P.ak.use_e()
	_ending(A, m, P, ev, func(): _press_key(P, which), held)
	var out := {"phase": String(P.ak.strikes[0]["phase"]) if not P.ak.strikes.is_empty() else ""}
	P.inp["e_down"] = false
	A.step(m, 1.4)
	out["hurt"] = A.dmg(T)
	await A.done(m)
	return out

static func sparkle(A) -> void:
	var rel := await _skycall(A, "release")
	A.ok("hold sparkle E: let go fixes the drag and the strike lands", rel["hurt"] > 0.0, str(rel))
	for ev in ["stun", "down"]:
		var d := await _skycall(A, ev)
		A.ok("hold sparkle E: %s [?]: the circle is already placed, the strike still lands at let go" % ev,
				d["hurt"] > 0.0, str(d))
	var k := await _skycall(A, "key", "rmb")
	A.ok("hold sparkle E: RMB mid-drag [?]: both go, the strike lands", k["hurt"] > 0.0, str(k))

## Tenzo's Basalt Spine (X held to drag): the aim after the ending, what X cost, and the ridge after let go.
static func _spine(A, ev: String, which := "") -> Dictionary:
	var r = A.setup("dolm", 9.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var held := func(): P.inp["x_down"] = true
	P.lvl = 6
	A.aim_at(P, P.pos + Vector3(7, 0, 0))
	P.inp["x_down"] = true
	HunterKeys.ult_pressed(P)
	m.step(Match.DT)
	_ending(A, m, P, ev, func(): _press_key(P, which), held)
	var out := {"aiming": P.ak.spine.aiming(), "anim": P.ak.anim_id}
	P.inp["x_down"] = false
	A.step(m, 0.2)
	out["phase"] = P.ak.spine.phase
	out["cd"] = float(P.ak.cd["x"])
	await A.done(m)
	return out

static func tenzo(A) -> void:
	var rel := await _spine(A, "release")
	A.ok("hold tenzo X: let go raises the ridge and X is spent", rel["phase"] == "tell" and rel["cd"] > 0.0, str(rel))
	for ev in ["stun", "down"]:
		var d := await _spine(A, ev)
		A.ok("hold tenzo X: %s mid-aim drops it, no ridge, X not spent" % ev,
				d["phase"] == "" and d["cd"] == 0.0 and not d["aiming"] and d["anim"] != "breah_spine_aim", str(d))
	for which in ["rmb", "e"]:
		var k := await _spine(A, "key", which)
		A.ok("hold tenzo X: %s mid-aim [?]: the aim goes on, casts at let go" % which,
				k["aiming"] and k["phase"] == "tell", str(k))
