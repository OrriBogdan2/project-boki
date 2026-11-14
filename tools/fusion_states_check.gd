extends RefCounted
## --fusion-states-check: every built merge form (content/merge_forms) x every state has a move: owner priority 4.
## Each hero is played merged into each form and through the same states once unmerged; what the model shows is read
## off the hero's own clip picker (WardenClips) or, for a move it has no clip for, the keyed pose
## (HunterAnim.km_sample):
##   idle walk run, LMB RMB E dash, a hit: exactly what the hero shows unmerged (the form keeps your own moves, 0004)
##   xform: the transformation's move; ult: the form's own "mf_ult_<id>" with a key on every beat of its r.beats;
##   release: "mf_release" after the merge ends
## A state showing nothing keyed (a move with no keys left, "FALLBACK") fails. Prints the table. Never touches the save.
## Run fewer: --fusion-heroes=gunslinger,juggernaut

## form -> a Boki that merges into it
const FORM_BOKI := {"titan": "pebbit", "stormwing": "zephyrak", "tidal_shell": "puddlet"}
const HERO_STATES := ["idle", "walk", "run", "lmb", "rmb", "e", "dash", "hit"]
const WINDOW := 0.7  # s: how long after a press a state is watched for its move
const BEAT_SLACK := 0.02  # s: an ultimate's key may sit this far off its beat
const WALK_MAX := 4.0  # m/s: slower than this reads as the walk ring

var bad := 0
var mf  # the merge-form check, for its match setup (fresh match, flat ground, merged)
var m: Match


func ok(cond: bool, what: String) -> void:
	if not cond:
		print("FUSIONSTATES FAIL ", what)
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	mf = load("res://tools/merge_form_check.gd").new()
	mf.main = main
	var heroes: Array = Arch.ids()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fusion-heroes="):
			heroes = Array(a.substr(16).split(","))
	_forms_known()
	for id in FORM_BOKI:
		_beats(id)
	for hero in heroes:
		var base := _hero_states(hero, "")
		for id in FORM_BOKI:
			var got := _hero_states(hero, id)
			var row := []
			for st in HERO_STATES + ["xform", "ult", "release"]:
				row.append("%s=%s" % [st, got.get(st, "-")])
				if st in HERO_STATES:
					var what := "%s as %s, %s" % [hero, id, st]
					ok(String(got[st]) == String(base[st]), "%s: shows %s, unmerged %s" % [what, got[st], base[st]])
					ok(not String(got[st]).contains("FALLBACK"), "%s: no keyed move" % what)
			var who := "%s as %s" % [hero, id]
			var hit := String(got["hit"])
			var xf := String(got["xform"])
			var ult := MergeMoves.ult_move(id)
			ok(hit.begins_with("clip ") or hit == "flinch", "%s: a hit flinches (%s)" % [who, hit])
			ok(xf.contains("mf_xform") or xf.begins_with("clip "), "%s: the transformation plays (%s)" % [who, xf])
			ok(String(got["ult"]).contains(ult) and ult != "mf_ult", "%s: its own ultimate (%s)" % [who, got["ult"]])
			ok(String(got["release"]).contains(MergeMoves.RELEASE), "%s: the release (%s)" % [who, got["release"]])
			print("FUSIONSTATES %s %s | %s" % [hero, id, " ".join(row)])
	print("FUSIONSTATES DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## Every form file has a Boki here, so a new form is swept too.
func _forms_known() -> void:
	for f in DirAccess.get_files_at("res://content/merge_forms"):
		if f.ends_with(".json"):
			ok(FORM_BOKI.has(f.get_basename()), "form %s has a Boki in FORM_BOKI" % f.get_basename())


## The ultimate's move keys every beat of the form (and a leap's landing and delayed blasts).
func _beats(id: String) -> void:
	var r: Dictionary = Content.merge_form(id)["r"]
	var keys: Array = MergeMoves.MOVES[MergeMoves.ult_move(id)]["keys"]
	var times := []
	for b in r["beats"]:
		times.append(float(b["at"]))
		for e in (b as Dictionary).get("effects", []):
			var land := float(b["at"]) + float((e as Dictionary).get("time", 0.0))
			if String(e.get("type", "")) == "leap":
				times.append(land)
				for e2 in e.get("on_land", []):
					times.append(land + float((e2 as Dictionary).get("delay", 0.0)))
			elif b.has("op"):
				times.append(land)
	for t in times:
		var hit := false
		for k in keys:
			hit = hit or absf(float(k[0]) - float(t)) <= BEAT_SLACK
		ok(hit, "%s: the ultimate's move keys its beat at %.2fs" % [id, t])
	ok(float((keys[-1] as Array)[0]) <= float(r["end"]) + BEAT_SLACK, "%s: the ultimate's move ends by r.end" % id)


## One hero through every state, merged into `form` ("" unmerged): state -> what the model showed.
func _hero_states(hero: String, form: String) -> Dictionary:
	var sp: String = FORM_BOKI.get(form, "pebbit")
	m = mf._fresh(sp, Arch.weight(hero), hero)
	var hp: Hunter = m.player
	var out := {}
	if form != "":
		hp.kin.stow()
		hp.ult = 1.0
		KinMerge.press(hp)
		out["xform"] = _watch(hp, 0.4)
		_settle(hp, float(MergeForm.data()["xform_s"]))
		ok(MergeKit.is_live(hp) and String(MergeForm.of(hp)["id"]) == form, "%s: merged into %s" % [hero, form])
	out["idle"] = _watch(hp, 0.2, 0.5)
	out["walk"] = _move(hp, 0.35)
	out["run"] = _move(hp, 1.0)
	for st in ["lmb", "rmb", "e", "dash"]:
		var key: String = {"lmb": "fire", "rmb": "sec", "e": "sig", "dash": "dash"}[st]
		hp.inp[key] = true
		out[st] = _watch(hp, WINDOW, 0.0, func(): hp.inp[key] = false)
		hp.inp[key] = false
		_settle(hp, 1.2)
	hp.hurt(1.0, mf.rival(), {"src": "test"})
	out["hit"] = _watch(hp, 0.3)
	if form != "":
		_settle(hp, 0.3)
		var kit := MergeKit.of(hp)
		kit.age = float(MergeForm.data()["ult_lock_s"]) + 0.1
		hp.inp["ult"] = true
		out["ult"] = _watch(hp, 0.6, 0.0, func(): hp.inp["ult"] = false)
		hp.inp["ult"] = false
		var left := 3.0
		while KinMerge.active(hp) and left > 0.0:
			_settle(hp, Match.DT)
			left -= Match.DT
		ok(not KinMerge.active(hp), "%s as %s: the ultimate ends the merge" % [hero, form])
		out["release"] = _watch(hp, 0.3)
	return out


## Steps the match while the merge timer is held full (states take longer than one merge).
func _settle(hp: Hunter, secs: float) -> void:
	var t := 0.0
	while t < secs:
		if KinMerge.active(hp) and not MergeKit.of(hp).ulting():
			hp.merge_st["t"] = maxf(float(hp.merge_st.get("t", 0.0)), 5.0)
		m.step(Match.DT)
		hp.render(Match.DT, 1.0)  # (the anim state is built in render)
		mf._clear_mobs()
		t += Match.DT


## Run (k = 1) or walk (k < 1) toward +x and read the loco state.
func _move(hp: Hunter, k: float) -> String:
	hp.inp["move"] = Vector2(k, 0.0)
	var got := _watch(hp, 0.2, 0.5)
	hp.inp["move"] = Vector2.ZERO
	_settle(hp, 0.6)
	return got


## Watches `secs` (after `lead` s): the first move shown, else the loco or flinch state at the end.
func _watch(hp: Hunter, secs: float, lead := 0.0, after_first := Callable()) -> String:
	_settle(hp, lead)
	var last := ""
	var t := 0.0
	while t < secs:
		_settle(hp, Match.DT)
		if after_first.is_valid():
			after_first.call()
			after_first = Callable()
		t += Match.DT
		last = _shown(hp)
		if not last.begins_with("loco") and last != "flinch":
			return last
	return last


## What hp's model shows this frame: "clip <name>", "keyed <move>" (the rig plays a keyed pose), "loco <ring>",
## "flinch" (the procedural hit spring), or "FALLBACK <move>" (a move with nothing left to show).
func _shown(hp: Hunter) -> String:
	var s: Dictionary = hp.anim_s
	var km := String(s.get("kmove", ""))
	var kt := float(s.get("kmove_t", 99.0))
	var keyed := not km.is_empty() and not HunterAnim.km_sample(km, kt).is_empty()
	var sync := hp.model.get_node_or_null("Warden/Sync") if hp.model else null
	var clips: WardenClips = sync.get("clips") if sync else null
	if clips != null:
		var r := clips._pick(s, 0.0)
		if r.has("clip"):
			return "clip " + String(r["clip"])
		if r.get("proc", false):
			return ("keyed " + km) if keyed else "FALLBACK " + km
	elif keyed:
		return "keyed " + km
	elif float(s.get("hit_t", 99.0)) < 0.3:
		return "flinch"
	var v: Vector3 = s.get("vel", Vector3.ZERO)
	var sp := Vector2(v.x, v.z).length()
	if sp < WardenClips.STILL:
		return "loco idle"
	return "loco walk" if sp < WALK_MAX else "loco run"
