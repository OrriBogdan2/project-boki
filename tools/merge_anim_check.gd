extends RefCounted
## --merge-anim-check: what a Hero's AnimationTree really plays while merged into a Boki (KinMerge). Each Hero runs
## the same moves unmerged, merged into each form, and again after the merge ends:
## idle, walk, run, jump, glide, LMB, RMB, dash (Shift), E. Read off the Hero's own clip player after it stepped
## (WardenClips: which channel carries the body and what clip is on it), plus that the bones move under the walk.
## Merged and after must show exactly what unmerged shows (its first and second pass). Never touches the save.
## Run fewer: --merge-anim-heroes=gunslinger,juggernaut --merge-anim-forms=titan

## form -> a Boki that merges into it
const FORM_BOKI := {"titan": "pebbit", "stormwing": "zephyrak", "tidal_shell": "puddlet"}
const STATES := ["idle", "walk", "run", "jump", "glide", "lmb", "rmb", "dash", "e"]
const PRESS := {"lmb": "fire", "rmb": "sec", "dash": "dash", "e": "sig"}
const WINDOW := 0.7       # s: how long after a press a move is watched for
const ON := 0.5           # a channel's weight above this carries the body
const MOVING_BONES := 0.05   # rad: summed bone turn over the walk sample below this = a frozen body

var bad := 0
var mf                    # the merge-form check, for its match setup (fresh match, flat ground)
var m: Match

func ok(cond: bool, what: String) -> void:
	if not cond:
		print("MERGEANIM FAIL ", what)
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	mf = load("res://tools/merge_form_check.gd").new()
	mf.main = main
	var heroes: Array = Arch.ids()
	var forms: Array = FORM_BOKI.keys()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--merge-anim-heroes="):
			heroes = Array(a.substr(20).split(","))
		elif a.begins_with("--merge-anim-forms="):
			forms = Array(a.substr(19).split(","))
	for hero in heroes:
		var base := _sweep(hero, "")
		print("MERGEANIM %s unmerged | %s" % [hero, _row(base)])
		for id in forms:
			var got := _sweep(hero, id)
			print("MERGEANIM %s as %s | %s" % [hero, id, _row(got)])
			print("MERGEANIM %s after %s | %s" % [hero, id, _row(got["after"])])
			for st in STATES:
				ok(got[st] == base[st], "%s as %s, %s: plays %s, unmerged %s" % [hero, id, st, got[st], base[st]])
				var was: String = base["after"][st]
				var now: String = got["after"][st]
				ok(now == was, "%s after %s, %s: plays %s, unmerged %s" % [hero, id, st, now, was])
			if got["clips"]:
				var turn := float(got["walk_turn"])
				ok(turn >= MOVING_BONES, "%s as %s: the bones move under the walk (%.3f rad)" % [hero, id, turn])
			var xf_want := "clip " if got["clips"] else "rig mf_xform"
			ok(got["xform"].begins_with(xf_want), "%s as %s: the transformation plays (%s)" % [hero, id, got["xform"]])
			var back: Vector3 = got["scale_after"]
			var was_k: Vector3 = base["scale"]
			ok(back.is_equal_approx(was_k), "%s after %s: model scale back (%s, was %s)" % [hero, id, back, was_k])
	print("MERGEANIM DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _row(r: Dictionary) -> String:
	var out := []
	for st in STATES:
		out.append("%s=%s" % [st, r[st]])
	return " ".join(out)

## One Hero through every move, merged into `form` ("" unmerged), then once more ("after": after the merge ended;
## unmerged, the second pass, so a kit's own carried state, a thrown shield, the next hand, is compared like for like).
func _sweep(hero: String, form: String) -> Dictionary:
	m = mf._fresh(FORM_BOKI.get(form, "pebbit"), Arch.weight(hero), hero)
	var P: Hunter = m.player
	if P.ak:
		P.ak.cd_off = true       # (each press finds its move ready, merged or not)
	if P.ak is MageKit:
		(P.ak as MageKit).gum.wait = INF     # (her idle bubble comes on its own clock: not a move under test)
	_settle(P, 0.3)              # (the clip player's first steps hand over from the rig)
	var out := {"scale": P.model.scale, "clips": _clips(P) != null}
	if form != "":
		P.kin.stow()
		P.ult = 1.0
		KinMerge.press(P)
		out["xform"] = _watch(P, 0.4)
		_settle(P, float(MergeForm.data()["xform_s"]))
		ok(MergeKit.is_live(P) and String(MergeForm.of(P)["id"]) == form, "%s: merged into %s" % [hero, form])
	_moves(P, out)
	if form != "":
		ok(MergeKit.is_live(P), "%s as %s: still merged after the moves" % [hero, form])
		KinMerge.end(P, "test")
	_settle(P, 1.5)
	ok(not KinMerge.active(P), "%s: the merge ended" % hero)
	var after := {}
	_moves(P, after)
	out["after"] = after
	out["scale_after"] = P.model.scale
	return out

func _moves(P: Hunter, out: Dictionary) -> void:
	out["idle"] = _watch(P, 0.2, 0.5)
	out["walk"] = _move(P, 0.35, out)
	out["run"] = _move(P, 1.0)
	P.inp["jump"] = true
	out["jump"] = _watch(P, 0.15, 0.0, func(): P.inp["jump"] = false)
	P.inp["glide"] = true
	out["glide"] = _watch_for(P, 0.6, "glide")
	P.inp["glide"] = false
	_land(P)
	for st in ["lmb", "rmb", "dash", "e"]:
		var key: String = PRESS[st]
		P.inp[key] = true
		out[st] = _watch(P, WINDOW, 0.0, func(): P.inp[key] = false)
		P.inp[key] = false
		_settle(P, 1.6)

## Steps the match and the Hero's clip player the way a frame does; the merge timer is held full.
func _settle(P: Hunter, secs: float) -> void:
	var t := 0.0
	while t < secs:
		if KinMerge.active(P) and not MergeKit.of(P).ulting():
			P.merge_st["t"] = maxf(float(P.merge_st.get("t", 0.0)), 5.0)
		m.step(Match.DT)
		P.render(Match.DT, 1.0)
		var sync := P.model.get_node_or_null("Warden/Sync")
		if sync:
			sync._process(Match.DT)
		mf._clear_mobs()
		t += Match.DT

func _land(P: Hunter) -> void:
	var left := 3.0
	while not P.grounded and left > 0.0:
		_settle(P, Match.DT)
		left -= Match.DT
	_settle(P, 0.6)

## Walk (k < 1) or run toward +x; `out` given: also how far the bones turn over the stride.
func _move(P: Hunter, k: float, out := {}) -> String:
	P.inp["move"] = Vector2(k, 0.0)
	_settle(P, 0.5)
	var before := _bone_rots(P)
	var got := _watch(P, 0.2)
	if before.size() > 0 and out.size() > 0:
		var after := _bone_rots(P)
		var turn := 0.0
		for i in before.size():
			turn += (before[i] as Quaternion).angle_to(after[i])
		out["walk_turn"] = turn
	P.inp["move"] = Vector2.ZERO
	_settle(P, 0.6)
	return got

func _bone_rots(P: Hunter) -> Array:
	var r := []
	if _clips(P) == null:
		return r
	var sk: Skeleton3D = _clips(P).skel
	for i in sk.get_bone_count():
		r.append(sk.get_bone_pose_rotation(i))
	return r

## Watches `secs` (after `lead` s): the first move the body starts playing, else what it plays at the end
## (a move already on before, an idle fidget, is not the press's).
func _watch(P: Hunter, secs: float, lead := 0.0, after_first := Callable()) -> String:
	_settle(P, lead)
	var was := _shown(P)
	var last := ""
	var t := 0.0
	while t < secs:
		_settle(P, Match.DT)
		if after_first.is_valid():
			after_first.call()
			after_first = Callable()
		t += Match.DT
		last = _shown(P)
		if not last.begins_with("loco") and last != was:
			return last
	return last

func _watch_for(P: Hunter, secs: float, want: String) -> String:
	var last := ""
	var t := 0.0
	while t < secs:
		_settle(P, Match.DT)
		t += Match.DT
		last = _shown(P)
		if last == want:
			return last
	return last

func _clips(P: Hunter) -> WardenClips:
	var sync := P.model.get_node_or_null("Warden/Sync") if P.model else null
	return sync.get("clips") if sync else null

## What the clip player carries the body with after this frame's step: "rig <move>" (handed to the retargeted rig),
## "clip <name>" (a full-body move), "upper <name>" (a move over running legs), "flinch", "glide", "air",
## "loco <idle|move>".
func _shown(P: Hunter) -> String:
	var c := _clips(P)
	if c == null:
		return _shown_rig(P)
	if c.proc_w >= ON:
		return "rig " + String(P.anim_s.get("kmove", ""))
	if c.act_w >= ON:
		return "clip " + c.cur
	if c.up_w >= ON:
		return "upper " + c.cur_u
	if c.flinch_w >= ON:
		return "flinch"
	if c.air_w >= ON:
		return "glide" if c.glide_w >= ON else "air"
	return "loco idle" if c.loco_pos.length() < 0.05 else "loco move"

## A Hero with no hand-keyed clips (Gil): the rig shows the keyed move playing, else the air or the legs.
func _shown_rig(P: Hunter) -> String:
	var s: Dictionary = P.anim_s
	var km := String(s.get("kmove", ""))
	if km != "" and not HunterAnim.km_sample(km, float(s.get("kmove_t", 99.0))).is_empty():
		return "rig " + km
	if not bool(s.get("grounded", true)):
		return "glide" if bool(s.get("gliding", false)) else "air"
	var v: Vector3 = s.get("vel", Vector3.ZERO)
	return "loco idle" if Vector2(v.x, v.z).length() < WardenClips.STILL else "loco move"
