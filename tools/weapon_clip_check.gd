extends RefCounted
## --weapon-clip-check: no held weapon ever goes into the ground. Every weapon on every class (its
## Warden at both slider ends) and on a player's own person of every folk is stepped through
## HunterAnim's poses (idle and each fidget, walk, run, sprint, strafe, backpedal, crouch, firing,
## melee combos, charged attacks, charging, hops, long falls
## with their flips and landing squash, each dodge, stomps, casts, drinks, hits, stuns, revives,
## the base channel, emotes), and the lowest point of the weapon's bounds is measured against the
## ground under the feet every frame. Prints the worst clearance and PASS/FAIL.

const DT := 1.0 / 30.0
const MIN_CLEAR := 0.045       # HunterAnim keeps 5 cm; a hair of slack for rounding

var worst := INF
var worst_at := ""
var worst_raw := INF
var worst_raw_at := ""
var updates := 0
var per_sc := {}               # scenario -> [worst after, worst before, where]

func _scen() -> Array:
	var out: Array = ["idle", "walk", "run", "sprint", "strafe", "back", "crouch", "fire",
		"run_fire", "combo", "run_combo", "charged", "charging", "hop", "fall", "stomp", "cast", "cast_ult",
		"drink", "hit", "stun", "revive", "base", "emote", "turn"]
	for f in ["look", "shoulders", "weapon", "stretch", "bounce", "neck", "kin", "owl", "bob", "tail"]:
		out.append("fidget:" + f)
	for k in ["phase", "roll", "charge", "lunge", "rush"]:
		out.append("dash:" + k)
	return out

## The bodies each weapon is tried on: the class's Warden with every slider at either end (the most a
## player can change it, MantleLook), and a player's own person of every folk (at home).
func _looks() -> Array:
	var out: Array = []
	for v in [0.0, 1.0]:
		var lk := PlayerLook.neutral()
		for k in lk["sliders"]:
			lk["sliders"][k] = v
		out.append(lk)
	for ri in Models.RACES.size():
		out.append(MantleLook.at_home({"race": ri, "gender": ri % 2, "skin": int(Models.RACES[ri]["skin"]), "hair": 1,
			"hair_col": 2, "outfit": ri % 5}))
	return out

func _look_tag(i: int) -> String:
	if i < 2:
		return "mantle-%s" % ("min" if i == 0 else "max")
	return String(Models.RACES[i - 2]["id"])

## The state for scenario sc at time t (and the air height, when airborne).
func _state(sc: String, t: float, f: int, a: HunterAnim) -> Dictionary:
	var s := {"face": 0.0, "fired": 99.0, "grounded": true, "vel": Vector3.ZERO}
	var fwd := Vector3(0, 0, -1)
	match sc:
		"walk": s["vel"] = fwd * 2.5
		"run": s["vel"] = fwd * 5.5
		"sprint": s["vel"] = fwd * 7.8
		"strafe": s["vel"] = Vector3(5.0, 0, 0)
		"back": s["vel"] = Vector3(0, 0, 5.0)
		"crouch": s["crouch"] = 1.0; s["fired"] = 0.5
		"fire": s["fired"] = fmod(t, 0.25)
		"run_fire": s["vel"] = fwd * 5.5; s["fired"] = fmod(t, 0.2)
		"combo", "run_combo":
			if sc == "run_combo": s["vel"] = fwd * 5.0
			s["fired"] = fmod(t, 0.4)
			s["swing_n"] = int(t / 0.42) + 1; s["combo"] = (int(t / 0.42)) % 3
		"charged":
			s["fired"] = fmod(t, 0.6)
			s["swing_n"] = int(t / 0.65) + 1; s["combo"] = -1
		"charging": s["charge"] = clampf(t / 1.5, 0.0, 1.0); s["fired"] = 0.3
		"hop":
			# a hop every 1.2 s: up at 9 m/s under 30 m/s² (the hunter's gravity)
			var ht := fmod(t, 1.2)
			var h := 9.0 * ht - 15.0 * ht * ht
			if h > 0.0:
				s["grounded"] = false; s["vel"] = fwd * 4.0 + Vector3(0, 9.0 - 30.0 * ht, 0); s["air_h"] = h
			else:
				s["vel"] = fwd * 4.0
		"fall":
			# off a high ledge: 14 m of fall, then a landing and a stand
			var h2 := 14.0 - 15.0 * t * t
			if h2 > 0.0:
				s["grounded"] = false; s["vel"] = fwd * 5.0 + Vector3(0, -30.0 * t, 0); s["air_h"] = h2
			else:
				s["squash"] = maxf(0.0, 0.6 - (t - 0.966) * 2.0)
		"stomp": s["stomp"] = fmod(t, 0.8) / 0.8
		"cast": s["cast"] = fmod(t, 1.0); s["cast_slot"] = "secondary"
		"cast_ult": s["cast"] = fmod(t, 1.4); s["cast_slot"] = "ult"
		"drink": s["drink"] = fmod(t / 1.2, 1.0)
		"hit": s["hit_t"] = fmod(t, 0.5); s["hit_dir"] = Vector2(1, 0.3)
		"stun": s["stun"] = true
		"revive": s["reviving"] = true
		"base": s["base"] = fmod(t / 2.0, 1.0)
		"emote": s["emote"] = ["wave", "laugh", "follow", "truce", "gg", "thanks"][int(t / 0.7) % 6]; s["emote_t"] = fmod(t, 0.7)
		"turn": s["face"] = t * 4.0
	if sc.begins_with("dash:"):
		var on := fmod(t, 0.6) < 0.25
		s["rolling"] = on; s["dash_dir"] = Vector2(0, -1); s["dash_kind"] = sc.substr(5)
		s["vel"] = fwd * (16.0 if on else 3.0)
	if sc.begins_with("fidget:") and f == 0:
		a.idle_t = 5.0
		a.fidget = sc.substr(7); a.fidget_t = 0.0; a.fidget_dur = 2.0
	return s

func run(main: Node) -> void:
	var t0 := Time.get_ticks_msec()
	var wids: Array = Data.weapon_ids()
	var scen := _scen()
	var only := ""
	for ar in OS.get_cmdline_user_args():
		if String(ar).begins_with("--clip-only="): only = String(ar).substr(12)
	if only != "": scen = Array(only.split(","))
	var models := 0
	for cls in ["light", "medium", "heavy"]:
		for wid in wids:
			for vi in _looks().size():
				var m := Models.hunter(cls, Data.TEAM_COLORS[0], String(wid), "", _looks()[vi])
				main.add_child(m)
				models += 1
				for sc in scen:
					var a := HunterAnim.new(m)
					m.rotation.y = 0.0
					var frames := 75 if not sc in ["fall", "charged"] else 100
					for f in frames:
						var s := _state(sc, f * DT, f, a)
						m.rotation.y = float(s["face"])
						a.update(DT, s)
						updates += 1
					var tag := "%s %s %s %s" % [cls, wid, _look_tag(vi), sc]
					if a.clear_min < worst:
						worst = a.clear_min; worst_at = tag
					if a.clear_raw < worst_raw:
						worst_raw = a.clear_raw; worst_raw_at = tag
					var ps: Array = per_sc.get(sc, [INF, INF, ""])
					if a.clear_min < float(ps[0]): ps[0] = a.clear_min; ps[2] = tag
					ps[1] = minf(float(ps[1]), a.clear_raw)
					per_sc[sc] = ps
				m.queue_free()
	print("CLIP %d models, %d scenarios, %d updates in %d ms" % [models, scen.size(), updates, Time.get_ticks_msec() - t0])
	for sc in per_sc:
		print("CLIP  %-16s after %.3f  before %.3f  (%s)" % [sc, per_sc[sc][0], per_sc[sc][1], per_sc[sc][2]])
	print("CLIP before the safeguard: lowest weapon point %.3f m above ground (%s)" % [worst_raw, worst_raw_at])
	print("CLIP worst clearance: %.3f m (%s)" % [worst, worst_at])
	print("CLIP %s" % ("PASS" if worst >= MIN_CLEAR else "FAIL"))
	main.get_tree().quit()
