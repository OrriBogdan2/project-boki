extends RefCounted
## --mastery-look-check: "the mask takes hold" (scripts/core/mastery_look.gd, content/rules/class_unlock.json "looks").
## A Hunter's mastery level gives a feature on your own character (Vex: green eye glow, Kael: a white-hot scar):
## locked until its level, then shown at home (the Unmasked model), never in a match (the Hunter's own look), faded
## and kept again by the creator's toggle, and an old save's look gains the key and any feature it already earned.
## With --shots-dir=<dir>: mastery_look_creator.png (both features on, front view) and mastery_look_faded.png.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("MASTERYLOOK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	_data()
	_unlock_and_show()
	await _creator_toggle(main)
	_migration()
	print("MASTERYLOOK CHECK DONE, failures: %d" % bad)
	main.get_tree().quit()

func _fresh() -> void:
	Save.d = Save.fresh()
	Save.d["look"] = Unmasked.default_look()

## Gives a Hunter its first n mastery goals.
func _master(id: String, n: int) -> void:
	for i in ClassUnlock.mastery(id).size():
		var g: Dictionary = ClassUnlock.mastery(id)[i]
		ClassUnlock.state()["hunters"].get_or_add(id, {})[String(g["stat"])] = int(g["target"]) if i < n else 0
	Unmasked.migrate(Save.d)     # what a finished expedition does (Game.apply_result)

## The glowing pieces drawn for a feature on a model built from this look ([] if it isn't drawn).
func _pieces(lk: Dictionary, id: String) -> Array:
	var model := Models.hunter("medium", Data.TEAM_COLORS[0], "smg", "", lk)
	var node := model.find_child("Mastery_%s" % id, true, false)
	var out: Array = node.get_children() if node else []
	model.free()
	return out

func _data() -> void:
	var feats := MasteryLook.features()
	var valid := feats.size() >= 2
	for f in feats:
		valid = valid and Arch.exists(String(f["hunter"])) and String(f["shape"]) in ["eyes", "scar"] \
			and int(f["level"]) >= 1 and int(f["level"]) <= ClassUnlock.mastery(String(f["hunter"])).size() \
			and String(f["col"]).is_valid_html_color()
	ok(valid, "%d features, each a real Hunter, a reachable level, a known shape, a colour" % feats.size())
	ok(MasteryLook.features().any(func(f): return f["hunter"] == "gunslinger" and f["shape"] == "eyes")
		and MasteryLook.features().any(func(f): return f["hunter"] == "juggernaut" and f["shape"] == "scar"),
		"Vex has an eye glow and Kael a scar")

func _unlock_and_show() -> void:
	_fresh()
	var vex: Dictionary = MasteryLook.features().filter(func(f): return f["id"] == "vex_glow")[0]
	var kael: Dictionary = MasteryLook.features().filter(func(f): return f["id"] == "kael_scar")[0]
	ok(_pieces(Unmasked.worn(), "vex_glow").is_empty() and MasteryLook.shown(Unmasked.worn()).is_empty(),
		"a new save shows nothing")
	_master("gunslinger", int(vex["level"]) - 1)
	ok(Unmasked.worn()["features"].is_empty() and _pieces(Unmasked.worn(), "vex_glow").is_empty(),
		"one mastery level short of the glow: still locked")
	_master("gunslinger", int(vex["level"]))
	var home := Unmasked.worn()
	ok(home["features"] == {"vex_glow": true}, "at its level Vex's glow is earned and kept (%s)" % home["features"])
	ok(_pieces(home, "vex_glow").size() == 2, "shown at home: two glowing eyes on the Unmasked")
	ok(_pieces(home, "kael_scar").is_empty(), "Kael's scar is not (Kael is unplayed)")
	ok(_pieces(Unmasked.mask_look(), "vex_glow").is_empty(), "a match wears the Hunter's own look, not yours")
	_master("juggernaut", int(kael["level"]))
	ok(_pieces(Unmasked.worn(), "kael_scar").size() == 1 and _pieces(Unmasked.worn(), "vex_glow").size() == 2,
		"Kael's mastery adds the scar next to the glow")
	var lk: Dictionary = Save.d["look"]
	ok(MasteryLook.toggle(lk, "vex_glow") and _pieces(Unmasked.worn(), "vex_glow").is_empty()
		and _pieces(Unmasked.worn(), "kael_scar").size() == 1, "faded: the glow is gone at home, the scar stays")
	Unmasked.migrate(Save.d)
	ok(Save.d["look"]["features"]["vex_glow"] == false, "a faded feature does not come back by itself")
	lk = Save.d["look"]      # (migrating wrote a cleaned copy)
	ok(MasteryLook.toggle(lk, "vex_glow") and _pieces(Unmasked.worn(), "vex_glow").size() == 2, "kept again: shown")
	ok(not MasteryLook.toggle(lk, "nobody"), "a feature that isn't earned can't be toggled")

func _creator_toggle(main: Node) -> void:
	var tree := main.get_tree()
	_fresh()
	_master("gunslinger", int(MasteryLook.features()[0]["level"]))
	var hx = load("res://scripts/ui/hatch.gd").new()
	hx.edit_only = true
	main.add_child(hx)
	hx._show_create()
	await tree.process_frame
	var btn := hx.find_child("Feature_vex_glow", true, false) as Button
	ok(btn != null and btn.text == "Keep" and hx.find_child("Feature_kael_scar", true, false) == null,
		"the creator has a Keep button for the earned feature only")
	btn.pressed.emit()
	await tree.process_frame
	btn = hx.find_child("Feature_vex_glow", true, false) as Button
	ok(hx.look["features"]["vex_glow"] == false and btn.text == "Faded" and _pieces(hx.look, "vex_glow").is_empty(),
		"the toggle fades it on the character")
	btn.pressed.emit()
	await tree.process_frame
	ok(hx.look["features"]["vex_glow"] == true and _pieces(hx.look, "vex_glow").size() == 2, "and keeps it again")
	await _shots(main, hx, tree)
	hx.queue_free()
	await tree.process_frame

func _shots(main: Node, hx: Node, tree: SceneTree) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	if dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(dir)
	if main.fade != null:
		main.fade.reveal(0.05)
	_master("juggernaut", ClassUnlock.mastery("juggernaut").size())
	MasteryLook.refresh(hx.look)
	hx.preview_yaw = PI
	for file in ["mastery_look_creator", "mastery_look_faded"]:
		hx._show_create()
		await tree.create_timer(1.0).timeout
		tree.root.get_texture().get_image().save_png(dir.path_join(file + ".png"))
		for id in hx.look["features"]:
			MasteryLook.toggle(hx.look, String(id))

func _migration() -> void:
	_fresh()
	Save.d["look"] = {"unmasked": true, "height": 2, "marks": []}      # a look from before features
	_master("gunslinger", 4)
	ok(Save.d["look"]["features"] == {"vex_glow": true}, "an old look gains the key and any feature it had earned")
	ok(Save.d["look"]["height"] == 2, "and keeps what it had")
	for junk in ["no", 5, [1], null]:
		var cleaned := Unmasked.clean({"unmasked": true, "features": junk})
		ok(cleaned["features"] == {}, "a junk features value (%s) cleans to none" % str(junk))
	var again: Dictionary = Save.d["look"].duplicate(true)
	Unmasked.migrate(Save.d)
	ok(Save.d["look"] == again, "migrating twice changes nothing")
