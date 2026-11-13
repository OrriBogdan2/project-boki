extends RefCounted
## --fuse-hud-check: the Fusion on the Boki box, end to end (briefs/DECISIONS.md, Boki HUD). Walks one Fuse and
## asserts what the box shows (BokiHud.fuse_view, the view the HUD draws from) at each step:
##   before   BOND % while the meter fills; FUSE with the key lit when X is ready; TOO FAR / RESCUE when it cannot go
##   during   the form's own ability on the slot with the live key, the time-left ring, ENDS in the last seconds
##   after    RESTING with the seconds: 10 s after a timeout, 6 s after a release; then the box is ready again
## Reuses the scene setup of --merge-form-check. Prints PASS/FAIL lines.
## --fuse-hud-shots --shots-dir=<dir>: the same walk as screenshots (real renderer): the bottom-right HUD, 2x crop.

var bad := 0
var mf                    # the merge-form check, for its match setup helpers

func ok(cond: bool, what: String) -> void:
	print("FUSEHUD %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(mn: Node, mode = null) -> void:
	Save.no_write = true
	mf = load("res://tools/merge_form_check.gd").new()
	mf.main = mn
	if mode == "shots":
		await _shots(mn)
		return
	_before()
	_during_and_timeout()
	_release()
	print("FUSEHUD DONE, failures: ", bad)
	mn.get_tree().quit(1 if bad > 0 else 0)

func _view(P: Hunter) -> Dictionary:
	return BokiHud.fuse_view(P)

func _before() -> void:
	mf._fresh("pebbit")
	var P: Hunter = mf.m.player
	var k: Kin = P.kin
	k.stow()
	var key := Settings.key_cap("ultimate")
	ok(key == "X", "the Fuse key is X (%s)" % key)
	P.ult = 0.4
	var v := _view(P)
	ok(v["stage"] == "bond" and v["tag"] == "40%", "bond filling: the box says the percent (%s)" % v["tag"])
	P.ult = 1.0
	v = _view(P)
	var lit: bool = v["stage"] == "ready" and v["tag"] == "FUSE" and v["key"] == key
	ok(lit, "bond full, Boki on you: FUSE with the key %s" % key)
	k.state = "active"
	k.pos = P.pos + Vector3(float(KinCommand.rules().get("merge_leap_range", 32.0)) + 10.0, 0, 0)
	ok(KinMerge.plan(P) == "far" and _view(P)["tag"] == "TOO FAR", "Boki out of leap range: TOO FAR")
	k.pos = P.pos + Vector3(8.0, 0, 0)
	ok(_view(P)["tag"] == "FUSE", "Boki out but in leap range: still FUSE")
	k.state = "downed"
	var vd := _view(P)
	ok(vd["stage"] == "blocked" and vd["tag"] == "RESCUE", "Boki downed: RESCUE")
	P.slot_lv["ult"] = 0
	ok(_view(P).is_empty(), "the Merge still locked: no Fusion tag (the lock is the slot's)")

func _during_and_timeout() -> void:
	var P: Hunter = mf.merged("pebbit")
	var kit: MergeKit = MergeKit.of(P)
	var key := Settings.key_cap("ultimate")
	var ult_icon := String((Content.merge_form("titan")["r"] as Dictionary)["icon"])
	var v := _view(P)
	var on_slot: bool = v["stage"] == "active" and v["icon"] == ult_icon and v["key"] == key
	ok(on_slot, "fused: the form's ability takes the slot (%s) with the live key %s" % [v["icon"], v["key"]])
	ok(float(v["ring"]) > 0.95, "...the ring starts full (%.2f)" % v["ring"])
	ok(String(v["tag"]).begins_with("ULT "), "...the ability is locked at first and the chip counts it (%s)" % v["tag"])
	kit.age = 2.0
	mf.run_for(1.0)
	v = _view(P)
	var want := String((Content.merge_form("titan")["r"] as Dictionary)["name"]).to_upper()
	ok(v["tag"] == want, "...the lock over: the chip names the ability (%s)" % v["tag"])
	var T := float(P.merge_st["T"])
	var ring_ok: bool = float(v["ring"]) < 0.95 and absf(float(v["ring"]) - float(P.merge_st["t"]) / T) < 0.01
	ok(ring_ok, "...the ring shows the time left (%.2f)" % v["ring"])
	P.merge_st["t"] = 2.0
	mf.run_for(0.1)
	ok(String(_view(P)["tag"]).begins_with("ENDS "), "...the last seconds: ENDS n.ns (%s)" % _view(P)["tag"])
	P.merge_st["t"] = 0.05
	mf.run_for(0.2)
	var k: Kin = P.kin
	v = _view(P)
	var rest := MergeRelease.timeout_rest_s()
	ok(not KinMerge.active(P) and v["stage"] == "rest" and v["tag"] == "RESTING", "timeout: the box says RESTING")
	var secs: float = v["secs"]
	var in_range := secs > rest - 1.0 and secs <= rest
	ok(in_range and rest == 10.0, "...the %.0f s timeout rest is on it (%.1f)" % [rest, secs])
	mf.run_for(4.0)
	v = _view(P)
	ok(float(v["secs"]) < rest - 3.0 and v["stage"] == "rest", "...counting down (%.1f)" % v["secs"])
	mf.run_for(rest)
	v = _view(P)
	var again: bool = not k.resting() and v["stage"] == "ready" and v["tag"] == "FUSE"
	ok(again, "rest over: the bond is kept, FUSE shows again (%s)" % v["tag"])

func _release() -> void:
	var P: Hunter = mf.merged("pebbit")
	var kit: MergeKit = MergeKit.of(P)
	kit.age = 2.0
	var R: Hunter = mf.foe(P.pos + Vector3(3.0, 0, 0))
	mf.aim_at(P, R.pos)
	P.inp["ult"] = true
	mf.run_for(0.05)
	mf.run_for(float(Content.merge_form("titan")["r"]["end"]) + 0.3)
	var v := _view(P)
	var rest := MergeRelease.rest_s()
	ok(not KinMerge.active(P) and v["stage"] == "rest" and v["tag"] == "RESTING", "release: the box says RESTING")
	var secs: float = v["secs"]
	var in_range := secs > rest - 2.0 and secs <= rest
	ok(in_range and rest == 6.0, "...the %.0f s release rest is on it (%.1f)" % [rest, secs])
	ok(P.ult < 0.2, "...and the bond restarted from about 0 (%.2f)" % P.ult)
	mf.run_for(rest + 0.5)
	v = _view(P)
	var back: String = "FUSE" if P.ult >= 1.0 else "%d%%" % int(P.ult * 100.0)
	var meter: bool = v["stage"] in ["bond", "ready"] and v["tag"] == back
	ok(meter, "rest over: the box is back to the bond meter (%s)" % v["tag"])

# ------------------------------------------------------------------ shots
func _shots(mn: Node) -> void:
	var dir := "/tmp/fuse_hud_shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var P: Hunter = mf.merged("pebbit")          # (one Fusion first, so the scene has played its form)
	P.merge_st["t"] = 0.05
	mf.run_for(0.2)
	P.kin.rest_t = 0.0          # (the warm-up timeout is over: the walk starts at a rested Boki)
	P.merge_cd = 0.0
	P.kin.stow()
	var m: Match = mf.m
	if mn.fade:
		await mn.fade.reveal(0.01)
	var steps := [["1_bond", 0.4], ["2_ready", 1.0]]
	for st in steps:
		P.ult = st[1]
		await _shot(mn, m, dir, st[0])
	var k: Kin = P.kin
	k.rest_t = 0.0
	k.state = "active"
	k.pos = P.pos + Vector3(60.0, 0, 0)
	await _shot(mn, m, dir, "3_too_far")
	k.state = "downed"
	await _shot(mn, m, dir, "4_rescue")
	k.state = "shoulder"
	P.merge_cd = 0.0
	P.ult = 1.0
	KinMerge.press(P)
	mf.run_for(float(MergeForm.data()["xform_s"]) + 0.12)
	await _shot(mn, m, dir, "5_fused_locked")
	MergeKit.of(P).age = 2.0
	mf.run_for(2.0)
	await _shot(mn, m, dir, "6_fused_ability_ready")
	P.merge_st["t"] = 2.0
	mf.run_for(0.2)
	await _shot(mn, m, dir, "7_fused_ending")
	P.merge_st["t"] = 0.05
	mf.run_for(0.3)
	await _shot(mn, m, dir, "8_rest_after_timeout")
	mf.run_for(10.5)
	await _shot(mn, m, dir, "9_back_to_fuse")
	print("FUSEHUDSHOTS done in %s" % dir)
	mn.get_tree().quit(0)

func _shot(mn: Node, m: Match, dir: String, what: String) -> void:
	m.cam.snap(m.player.pos)
	for i in 3:
		await mn.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = mn.get_viewport().get_texture().get_image()
	var box := Rect2i(Vector2i(img.get_width() - 560, img.get_height() - 190), Vector2i(560, 190))
	var crop := img.get_region(box)
	crop.resize(box.size.x * 2, box.size.y * 2, Image.INTERPOLATE_LANCZOS)
	crop.save_png(dir.path_join("%s.png" % what))
