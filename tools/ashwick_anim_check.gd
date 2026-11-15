extends RefCounted
## Cinder's animation timing against the footage (docs/heroes/ashwick.md, "Animation timing"), for
## --ashwick-combo-check: each fix of the timing pass, on the kit's move clock (kmove_t = time - anim_at) that
## WardenClips seeks her clips on, and the clip lengths in the glb.

const MAP := "res://content/rules/warden_anim/cinder.json"

var ak = null
var ok_fn: Callable

func _init(arch_check, ok_cb: Callable) -> void:
	ak = arch_check
	ok_fn = ok_cb

func ok(label: String, cond: bool, info := "") -> void:
	ok_fn.call(label, cond, info)

func run() -> void:
	var r: Array = ak.setup("ashwick", 16.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: AshwickKit = P.ak
	var km: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP))["kmoves"]
	# the ram into a foe: contact early, and the clip jumps to the struck pose then (not the free ram's 0.36)
	T.teleport(home + Vector3(3.0, 0, 0))
	ak.aim_at(P, T.pos)
	K.on_dash(false)
	var hit_at := -1.0
	var kt := -1.0
	var tt := 0.0
	while tt < 0.4 and hit_at < 0.0:
		ak.step(m, ak.DT)
		tt += ak.DT
		if K.bash_hits > 0:
			hit_at = tt
			kt = m.time - K.anim_at
	ok(
		"timing: a ram into a foe shows the struck pose on contact ([F] contact ~0.12 s)",
		hit_at > 0.0 and hit_at < K.RAM_IMPACT_KEY - 0.05 and K.anim_id == "as_leap" and kt >= K.RAM_IMPACT_KEY - 0.001,
		"contact %.2f s, clip at %.2f s" % [hit_at, kt]
	)
	# Flue Flight: flying 0.1 s after the press; the landing hands the legs back to her walk
	ak.step(m, 1.0)
	T.teleport(home + Vector3(0, 0, 9.0))
	P.lvl = 6
	K.cd["x"] = 0.0
	ak.aim_at(P, P.pos + Vector3(10, 0, 0))
	HunterKeys.ult_pressed(P)
	var fly_at := float((KMovesPair.MOVES["lw_jet"]["keys"] as Array)[2][0]) - (m.time - K.anim_at)
	ok(
		"timing: Flue Flight is flying 0.1 s after the press ([F] f25 burst, flying from f26)",
		K.jet.running() and K.anim_id == "lw_jet" and absf(fly_at - 0.1) < 0.02, "fly pose at %.2f s" % fly_at
	)
	ak.step(m, 0.3)
	HunterKeys.ult_pressed(P)
	ok(
		"timing: the landing has no stop, her legs walk on out of it ([F] f39-f41)",
		K.anim_id == "lw_land" and km["lw_land"].get("upper") == "moving", "%s %s" % [K.anim_id, km["lw_land"]]
	)
