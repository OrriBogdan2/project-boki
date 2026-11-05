extends RefCounted
## --ryzz-live-check: Ryzz's clips through the real match code (tools/clip_live_check.gd for her kit): a Match,
## the kit's own presses and the render path. Each ability plays its clip, the rods blaze in Kitefall and at no
## other time, and a knock-out plays the death clip.
## Never touches the save.

const DT := 1.0 / 60.0

var A
var bad := 0

func ok(cond: bool, what: String) -> void:
	print("LIVE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frame(m: Match, h: Hunter) -> void:
	m.step(DT)
	h.render(DT, 1.0)
	if h.model and h.model.has_node("Warden/Sync"):
		var sync: Node = h.model.get_node("Warden/Sync")
		sync.set_process(false)
		if h.visible or h.out:
			sync.call("_process", DT)

func _clips(h: Hunter) -> WardenClips:
	return h.model.get_node("Warden/Sync").get("clips") as WardenClips

## How far the rods' glow sleeves are flared right now (1 = hidden inside the rod).
func _flare(h: Hunter) -> float:
	var sk := WardenGlb.skeleton(h.model.get_node("Warden"))
	var bi := sk.find_bone("rodlit.1")
	return sk.get_bone_pose_scale(bi).x if bi >= 0 else 0.0

func _run(m: Match, P: Hunter, frames: int, seen: Dictionary) -> float:
	var top := 0.0
	for f in frames:
		_frame(m, P)
		var c := _clips(P)
		seen[c.cur] = true
		if c.up_w > 0.5:
			seen[String(c._node("anim_u").animation)] = true
		top = maxf(top, _flare(P))
	return top

func run(main: Node) -> void:
	Save.no_write = true
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var r: Array = A.setup("mage", 11.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var seen := {}
	_run(m, P, 10, seen)
	ok(_clips(P) != null, "Ryzz wears her clips in a match")
	var K: MageKit = P.ak
	T.teleport(home + Vector3(0, 0, -9.0))
	A.aim_at(P, T.pos)
	for shot in 3:
		P.inp["fire"] = true
		_frame(m, P)
		P.inp["fire"] = false
		_run(m, P, 54, seen)
	ok(seen.has("lmb_l") and seen.has("lmb_r"), "the finger bolts play lmb_l and lmb_r")
	var calm := _flare(P)
	K.press_rmb()
	_run(m, P, 70, seen)
	K._release_rmb()
	_run(m, P, 50, seen)
	ok(seen.has("rmb_hold") and seen.has("rmb"), "Storm Rod plays its hold and its throw")
	K.on_dash(false)
	_run(m, P, 90, seen)
	ok(seen.has("dash") or seen.has("dash_go"), "Wirerun plays its clips")
	K.cast_e()
	_run(m, P, 150, seen)
	ok(seen.has("sky"), "Skycall plays sky")
	ok(calm <= 1.05, "the rods sit dark outside the ult (flare %.2f)" % calm)
	K.cast_ult()
	var blaze := _run(m, P, 90, seen)
	K.ult_recast()
	blaze = maxf(blaze, _run(m, P, 90, seen))
	ok(seen.has("ult") and seen.has("ult_air"), "Kitefall plays its crouch and its hang")
	ok(blaze >= 3.0, "the rods blaze on Kitefall (flare %.2f)" % blaze)
	print("LIVE clips seen: ", seen.keys())
	P.lives = 1
	_run(m, P, 30, seen)
	m.eliminate(P, T, "finished")
	var dead_seen := false
	var was_visible := false
	for f in 60:
		_frame(m, P)
		dead_seen = dead_seen or _clips(P).cur == "death"
		was_visible = was_visible or P.visible
	ok(dead_seen and was_visible, "a knock-out stays on screen and plays the death clip")
	print("RYZZ_LIVE_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
