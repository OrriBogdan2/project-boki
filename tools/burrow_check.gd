extends RefCounted
## --burrow-check: the island's cap on Boki out at once comes from content/rules/burrow.json (with a
## unit and a reason), the quick Burrow panel lists who is out and who sleeps, a swap is two clicks,
## the cap holds, the swapped Boki walk out of and into the door, and a swap changes nothing on
## the records but where they sleep (bonds, journal, trust, level survive). --shots-dir=<dir> saves
## burrow.png (needs a renderer). Never touches the real save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("BURROW %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _kin(sp: String, nm: String, lvl: int) -> Dictionary:
	var r := Save.new_kin(sp, nm)
	r["level"] = lvl
	return r

## The record with the sleep markers taken off, to compare before and after a swap.
func _core(rec: Dictionary) -> Dictionary:
	var c: Dictionary = rec.duplicate(true)
	for key in ["boxed", "box_slot", "needs_t", "needs"]: c.erase(key)
	return c

func _walk(h: Node, secs: float) -> void:
	for i in int(secs / 0.1): h._move_kin(0.1)

func _dist(pos: Vector3, to: Vector3) -> float:
	return Vector2(pos.x - to.x, pos.z - to.z).length()

func _roster() -> void:
	Save.d = Save.fresh()
	Econ.ensure()
	var sps: Array = Data.KIN.keys().filter(func(k): return not Data.KIN[k].get("rare", false))
	var first := _kin(sps[0], "Start", 9)
	first["starter"] = true
	Save.d["roster"] = [first]
	Save.d["active"] = first["uid"]
	Save.d["tutorial"] = {"home": true, "day1_done": true}
	for j in 8:
		var r := _kin(sps[(j + 1) % sps.size()], "B%d" % j, 2 + j)
		Save.d["roster"].append(r)
		KinBox.route_new(r)

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	var rules := KinBox.rules()
	var documented: bool = rules.has("farm_caps_unit") and rules.has("farm_caps_reason")
	ok(KinBox.farm_caps()[0] == 6 and documented, "the cap is 6, from content/rules/burrow.json, with unit and reason")
	_roster()
	var cap := KinBox.farm_cap()
	ok(KinBox.farm().size() == cap and KinBox.boxed().size() == 3, "nine Boki: %d out (the cap), 3 asleep" % cap)
	var H = load("res://scripts/home/home.gd").new()
	main.add_child(H)
	for _f in 900:
		await main.get_tree().process_frame
		if H.kins.size() == cap and is_instance_valid(H.burrow_node) and H.panel_host != null: break
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	BurrowPanel.open(H)
	for _f in 10: await main.get_tree().process_frame
	var rows: Array = H.find_children("Row_*", "PanelContainer", true, false)
	ok(H.panel_open == "Boki Burrow" and rows.size() == 9, "the panel lists all nine Boki, out and asleep")
	await _shot(H)
	# ---------------------------------------------------------------- two clicks to swap
	var out_rec: Dictionary = KinBox.farm().filter(func(r): return KinBox.pinned(r) == "")[0]
	var in_rec: Dictionary = KinBox.boxed()[0]
	out_rec["bonds"] = {"someone": 0.6}
	out_rec["journal"] = [{"day": 3, "text": "found a shiny pebble"}]
	in_rec["bonds"] = {"someone": -0.4}
	in_rec["journal"] = [{"day": 1, "text": "slept in"}]
	var out_before := _core(out_rec)
	var in_before := _core(in_rec)
	BurrowPanel.click(H, out_rec)
	ok(BurrowPanel.picked == String(out_rec["uid"]) and not KinBox.is_boxed(out_rec), "one click only picks")
	BurrowPanel.click(H, in_rec)
	ok(KinBox.is_boxed(out_rec) and not KinBox.is_boxed(in_rec), "the second click swaps them")
	ok(KinBox.farm().size() == cap, "the cap holds after the swap (%d out)" % KinBox.farm().size())
	var kept := _core(out_rec) == out_before and _core(in_rec) == in_before
	ok(kept, "bonds, journal, trust and level are untouched on both Boki")
	var door := BurrowSwap.door(H)
	var waking: Dictionary = BurrowSwap.kin_of(H, in_rec)
	var leaving: Dictionary = BurrowSwap.kin_of(H, out_rec)
	ok(not waking.is_empty() and _dist(waking["pos"], door) < 0.3, "the one waking up starts at the Burrow door")
	ok(not leaving.is_empty() and leaving.has("burrow_in"), "the one going to sleep heads for the door")
	_walk(H, 12.0)
	var gone := BurrowSwap.kin_of(H, out_rec).is_empty()
	ok(gone and H.kins.size() == cap, "it slips in and leaves the island: %d out" % H.kins.size())
	var away: Dictionary = BurrowSwap.kin_of(H, in_rec)
	ok(not away.has("burrow_t") and _dist(away["pos"], door) > 1.0, "the new one walked out and wandered off")
	# ---------------------------------------------------------------- who may sleep, and the cap
	var partner: Dictionary = Save.active_kin()
	BurrowPanel.click(H, partner)
	BurrowPanel.click(H, KinBox.boxed()[0])
	ok(not KinBox.is_boxed(partner) and KinBox.farm().size() == cap, "the partner won't swap out: stays on the island")
	BurrowPanel.picked = ""
	var spare: Dictionary = KinBox.boxed()[0]
	BurrowPanel.click(H, spare)
	var only_picked := KinBox.is_boxed(spare) and BurrowPanel.picked == String(spare["uid"])
	ok(only_picked and KinBox.farm().size() == cap, "a lone sleeper click on a full island only picks: the cap holds")
	BurrowPanel.picked = ""
	KinBox.to_box(KinBox.farm().filter(func(r): return KinBox.pinned(r) == "")[0])
	BurrowPanel.click(H, spare)
	ok(not KinBox.is_boxed(spare) and KinBox.farm().size() == cap, "with a free spot one click brings a sleeper out")
	H.queue_free()
	print("BURROW DONE failures: %d" % bad)
	main.get_tree().quit()

func _shot(h: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): dir = a.substr(12)
	if dir == "" or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	h.get_viewport().get_texture().get_image().save_png(dir.path_join("burrow.png"))
