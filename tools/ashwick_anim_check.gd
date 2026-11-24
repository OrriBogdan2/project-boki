extends RefCounted
## Cinder's animation timing against the footage (docs/heroes/ashwick.md, "Animation timing"), for
## --ashwick-combo-check: each fix of the timing pass, on the kit's move clock (kmove_t = time - anim_at) that
## WardenClips seeks her clips on, and the clip lengths in the glb.

const MAP := "res://content/rules/warden_anim/cinder.json"
const GLB := "res://art/wardens/cinder/cinder.glb"

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
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var home: Vector3 = r[4]
	var k: AshwickKit = p.ak
	var km: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP))["kmoves"]
	var lens := _clip_lens(["cloak", "run_f"])
	# the ram into a foe: contact early, and the clip jumps to the struck pose then (not the free ram's 0.36)
	t.teleport(home + Vector3(3.0, 0, 0))
	ak.aim_at(p, t.pos)
	k.on_dash(false)
	var hit_at := -1.0
	var kt := -1.0
	var tt := 0.0
	while tt < 0.4 and hit_at < 0.0:
		ak.step(m, ak.DT)
		tt += ak.DT
		if k.bash_hits > 0:
			hit_at = tt
			kt = m.time - k.anim_at
	ok(
		"timing: a ram into a foe shows the struck pose on contact ([F] contact ~0.12 s)",
		hit_at > 0.0 and hit_at < k.RAM_IMPACT_KEY - 0.05 and k.anim_id == "as_leap" and kt >= k.RAM_IMPACT_KEY - 0.001,
		"contact %.2f s, clip at %.2f s" % [hit_at, kt]
	)
	# Flue Flight: flying 0.1 s after the press; the landing hands the legs back to her walk
	ak.step(m, 1.0)
	t.teleport(home + Vector3(0, 0, 9.0))
	p.lvl = 6
	k.cd["x"] = 0.0
	ak.aim_at(p, p.pos + Vector3(10, 0, 0))
	HunterKeys.ult_pressed(p)
	var fly_at := float((KMovesPair.MOVES["lw_jet"]["keys"] as Array)[2][0]) - (m.time - k.anim_at)
	ok(
		"timing: Flue Flight is flying 0.1 s after the press ([F] f25 burst, flying from f26)",
		k.jet.running() and k.anim_id == "lw_jet" and absf(fly_at - 0.1) < 0.02,
		"fly pose at %.2f s" % fly_at
	)
	ak.step(m, 0.3)
	HunterKeys.ult_pressed(p)
	ok(
		"timing: the landing has no stop, her legs walk on out of it ([F] f39-f41)",
		k.anim_id == "lw_land" and km["lw_land"].get("upper") == "moving",
		"%s %s" % [k.anim_id, km["lw_land"]]
	)
	# Furnace Cloak: a quick arms-out flare, settled in 0.24 s (docs/heroes/ashwick.md), legs free while she walks
	var ck: Array = KMovesPair.MOVES["as_cloak"]["keys"]
	var wide := float(ck[2][0]) - float(ck[1][0])
	var end := float(ck[-1][0])
	ok(
		"timing: the cloak's arms flare wide, settled by 0.24 s (the quick flare)",
		(
			wide >= 0.06
			and absf(end - 0.24) < 0.01
			and absf(float(lens["cloak"]) - end) < 0.04
			and k.CLOAK_POSE_T <= end + 0.08
			and km["as_cloak"].get("upper") == "moving"
		),
		"wide %.2f s, end %.2f s, clip %.2f s" % [wide, end, float(lens["cloak"])]
	)
	# the run: a footfall every 0.14-0.2 s at her run speed (walk and run now have their own cycle lengths)
	var rate := clampf(p.base_speed / 4.6, 0.6, 1.5)
	var step := float(lens["run_f"]) / 2.0 / rate
	ok(
		"timing: a running step every 0.14-0.2 s ([F] quick short strides)",
		step >= 0.14 and step <= 0.2,
		"step %.3f s" % step
	)


## The lengths (s) of these clips in her glb as Godot imported it (-1: missing).
static func _clip_lens(names: Array) -> Dictionary:
	var root: Node = (load(GLB) as PackedScene).instantiate()
	var ap := root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var out := {}
	for nm in names:
		out[nm] = ap.get_animation(nm).length if ap.has_animation(nm) else -1.0
	root.free()
	return out
