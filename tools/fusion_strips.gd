extends "res://tools/breah_shots.gd"
## --fusion-strips --shots-dir=<dir> [--fusion-hero=<id>]: one strip per merge form (content/merge_forms) at 5 fps,
## the hero (Kael unless named) merged into it: the transformation, idle, a run, LMB, a hit, the ultimate and the
## release, in a live Arena match (xvfb with a renderer; the Breah rig's 3-wide grid of crops round the hero).
## <dir>/captions.txt gets "file: caption" per file. What every state plays is asserted by --fusion-states-check.

const FRAME := 0.2  # s between frames (5 fps)
const FORM_BOKI: Dictionary = preload("res://tools/fusion_states_check.gd").FORM_BOKI
## The timeline from the merge press (s): each state's start, in order; the ultimate is pressed at "ult".
const AT := {"xform": 0.0, "idle": 0.9, "run": 1.3, "lmb": 2.2, "hit": 3.0, "ult": 3.5}
const LENGTH := 5.6  # s: the ultimate (up to 1.2 s) and the release (0.5 s) fit after "ult"


func run(main_node: Node) -> void:
	main = main_node
	who = "juggernaut"
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--fusion-hero="):
			who = arg.substr(14)
	DirAccess.make_dir_recursive_absolute(dir)
	var hero := Arch.bare_title(who).to_lower()
	for id in FORM_BOKI:
		if m:
			m.queue_free()
		extra_opts = {"demo_kin": FORM_BOKI[id]}
		hero_name = "%s_%s" % [hero, id]
		await _setup()
		await _form(String(id))
	_write_captions()
	print("FUSIONSTRIPS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)


func _form(id: String) -> void:
	P.kin.stow()
	P.ult = 1.0
	KinMerge.press(P)
	var form_name := String(Content.merge_form(id)["name"])
	var caption := (
		"%s as %s, a frame every %.1fs: transformation 0-0.8s, idle %.1f, run %.1f, LMB %.1f, hit %.1f, "
		% [Arch.bare_title(who), form_name, FRAME, AT["idle"], AT["run"], AT["lmb"], AT["hit"]]
	)
	caption += "ultimate %.1f, then the release" % AT["ult"]
	var times := []
	var t := FRAME
	while t <= LENGTH:
		times.append(t)
		t += FRAME
	await _go(LENGTH, _drive, _strip("fusion", caption, times))


## One step of the timeline (t: seconds since the merge press).
func _drive(t: float) -> void:
	var kit := MergeKit.of(P)
	if kit != null and not kit.ulting():
		P.merge_st["t"] = maxf(float(P.merge_st.get("t", 0.0)), 5.0)  # (held open: the timeline outlasts a merge)
	P.inp["move"] = Vector2(1, 0) if t >= AT["run"] and t < AT["lmb"] - 0.2 else Vector2.ZERO
	P.inp["fire"] = _now(t, "lmb")
	if _now(t, "hit"):
		P.hurt(1.0, T, {"src": "test"})
	if _now(t, "ult") and kit != null:
		kit.age = float(MergeForm.data()["ult_lock_s"]) + 0.1
	P.inp["ult"] = _now(t, "ult")


func _now(t: float, state: String) -> bool:
	return t >= float(AT[state]) and t < float(AT[state]) + DT
