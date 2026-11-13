extends RefCounted
## --ride-pick-check: the Boki riding with you (RidePick), shown and swapped in one place before you
## leave. The count rule (one, as Match.TWO_KIN and KinSummon say), the swap list (your garden roster
## minus Boki held away), a swap is what the match brings (Save.active_kin), the carry and summon lines
## come from the species, and the panel in the pre-match lobby: swap row open, gone once locked or online.
## --ride-pick-shots --shots-dir=<dir>: the lobby with the panel (renderer needed for the portraits).

var bad := 0
const EXPEDITION := {"teams": 10, "squad": 2, "tier": 0}
const SHOT_PX := Vector2i(2560, 1080)     # px: the UI scales by height and the Hunter grid takes ~1150 of 1280
const SPECIES := ["cindle", "zapple", "mossgrade", "selenfin", "burrlet"]

func ok(cond: bool, what: String) -> void:
	print("RIDEPICK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node, mode: String = "check") -> void:
	Save.no_write = true
	_garden()
	if mode == "shots":
		await _shots(main)
		main.get_tree().quit(0)
		return
	_rules()
	_lines()
	_card()
	await _panel(main)
	await _lobby(main)
	print("RIDEPICK DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A save with five garden Boki; the last one is held for ransom (can't ride).
func _garden() -> void:
	var d := Save.fresh()
	d["name"] = "Tester"
	d["roster"] = []
	Save.d = d
	for sp in SPECIES:
		if Data.KIN.has(sp):
			d["roster"].append(Save.new_kin(sp))
	d["roster"][-1]["ransom"] = {"price": 100}
	d["active"] = d["roster"][0]["uid"]

func _rules() -> void:
	ok(RidePick.COUNT == 1 and not Match.TWO_KIN, "one Boki rides with you (Match.TWO_KIN off)")
	var held: Dictionary = Save.d["roster"][-1]
	var ids: Array = RidePick.choices().map(func(r): return r["uid"])
	ok(ids.size() == Save.d["roster"].size() - 1 and not ids.has(held["uid"]),
		"the swap list is the garden roster minus a held Boki (%d)" % ids.size())
	var two: Dictionary = Save.d["roster"][1]
	ok(RidePick.swap(two["uid"]) and Save.active_kin()["uid"] == two["uid"], "a swap = the Boki the match brings")
	ok(not RidePick.swap(held["uid"]), "a held Boki can't be swapped in")
	ok(not RidePick.swap("nobody"), "an unknown id can't be swapped in")
	ok(Save.active_kin()["uid"] == two["uid"], "a refused swap changes nothing")
	RidePick.swap(Save.d["roster"][0]["uid"])

func _lines() -> void:
	for r in RidePick.choices():
		var ks := KinLib.kin(String(r["species"]))
		var t := KinSummon.times(ks)
		var s := RidePick.summon_line(r)
		var c := RidePick.carry_line(r)
		ok(c == KinText.carry(ks) and c != "", "%s carry line: %s" % [r["species"], c])
		var want := "Summon: out %d s, rest %d s" % [int(t.x), int(t.y)]
		ok(s.begins_with(want), "%s summon window: %s" % [r["species"], s])

## The portal card's numbers for two species, worked out by hand from the rules, not from the helpers.
func _card() -> void:
	var well: Dictionary = Save.d["roster"][0]      # cindle, raised hard: all needs high, trained stats
	well["needs"] = {"food": 80.0, "energy": 80.0, "joy": 80.0, "clean": 80.0}
	well["trust"] = 50.0
	well["stats"] = {"power": 25, "guard": 12, "speed": 8, "focus": 40}
	var poor: Dictionary = Save.d["roster"][1]      # zapple, neglected: low needs, no training
	poor["needs"] = {"food": 20.0, "energy": 20.0, "joy": 20.0, "clean": 20.0}
	poor["trust"] = 50.0
	poor["stats"] = {"power": 0, "guard": 0, "speed": 0, "focus": 0}
	# condition 80 -> x1.1: damage 1+25*.004, health 1+12*.005, speed 1+8*.0025, skill 40*.3% faster
	# condition 20 -> x0.82
	var good := "Care: +21% damage, +17% health, +2% speed, skill 12% faster"
	ok(RidePick.care_line(well) == good, "well-raised care line: " + RidePick.care_line(well))
	var bad_care := "Care: -18% damage, -18% health"
	ok(RidePick.care_line(poor) == bad_care, "neglected care line: " + RidePick.care_line(poor))
	for r in [well, poor]:
		var ks := KinLib.kin(String(r["species"]))
		var cell: Array = KinSummon.rules()["table"][String(ks.ai["role"])][ks.size]
		var lean: Dictionary = Evo.AFF[Evo.leading(r)]
		var tip := RidePick.tip(r, "x")
		var want := "Summon: out %d s, rest %d s" % [int(cell[0]), int(cell[1])]
		ok(RidePick.summon_line(r).begins_with(want), "%s summon tempo from the table (%s %s): %s" % [
			r["species"], ks.ai["role"], ks.size, RidePick.summon_line(r)])
		var leans := "Leans %s: %s" % [lean["name"], lean["why"]]
		ok(tip.contains(RidePick.summon_line(r)) and tip.contains(RidePick.care_line(r)) and tip.contains(leans),
			"%s hover card carries summon, care and lean" % r["species"])

func _tiles(root: Node) -> Array:
	var out: Array = []
	for c in root.find_children("*", "PanelContainer", true, false):
		if c.has_meta("swap_uid"): out.append(c)
	return out

func _rider(root: Node) -> String:
	for c in root.find_children("*", "PanelContainer", true, false):
		if c.has_meta("ride_uid"): return String(c.get_meta("ride_uid"))
	return ""

func _panel(main: Node) -> void:
	var swaps := [0]
	var p := RidePick.build(main, "", func(): swaps[0] += 1)
	main.add_child(p)
	await main.get_tree().process_frame
	var tiles := _tiles(p)
	ok(_rider(p) == String(Save.active_kin()["uid"]), "the panel shows the riding Boki")
	ok(tiles.size() == RidePick.choices().size(), "one swap tile per Boki that can ride (%d)" % tiles.size())
	var pick: Control = tiles[2]
	pick.gui_input.emit(_click())
	var swapped: bool = Save.active_kin()["uid"] == pick.get_meta("swap_uid") and swaps[0] == 1
	ok(swapped, "clicking a tile swaps it in and tells the screen")
	p.queue_free()
	var shut := RidePick.build(main, "Locked in.", Callable())
	ok(_tiles(shut).is_empty() and _rider(shut) != "", "with a reason given the rider shows and the swap row is gone")
	shut.free()

func _view(main: Node, o: Dictionary) -> Control:
	var view: Control = load("res://scripts/ui/prematch_view.gd").new()
	view.setup(o)
	main.add_child(view)
	await main.get_tree().process_frame
	return view

func _lobby(main: Node) -> void:
	var o := EXPEDITION.duplicate()
	Prematch.deal_mates(o)
	var view := await _view(main, o)
	ok(_tiles(view.ride_box).size() == RidePick.choices().size(), "the lobby shows the swap row while picks are open")
	var col: float = (view.ride_box.get_parent() as Control).custom_minimum_size.x
	var need: float = view.ride_box.get_combined_minimum_size().x
	ok(need <= col, "the panel fits the lobby side column (%d of %d px)" % [need, col])
	var to: Control = _tiles(view.ride_box)[0]
	var uid := String(to.get_meta("swap_uid"))
	to.gui_input.emit(_click())
	await main.get_tree().process_frame
	ok(_rider(view.ride_box) == uid and Save.active_kin()["uid"] == uid, "a lobby swap shows the new rider")
	view.pm.left = 0.0
	view._process(0.0)
	await main.get_tree().process_frame
	ok(_tiles(view.ride_box).is_empty() and _rider(view.ride_box) != "", "once picks lock: rider stays, no swap")
	view.set_process(false)
	view.queue_free()
	var on := EXPEDITION.duplicate()
	on["net"] = {"roster": []}
	var online := await _view(main, on)
	ok(_tiles(online.ride_box).is_empty(), "online the Boki stays as you joined with")
	online.set_process(false)
	online.queue_free()

func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e

## The lobby with the panel open (wisps on), then the same once picks lock. Portraits fill in over frames.
func _shots(main: Node) -> void:
	var dir := "user://ride_pick_shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	if main.fade: main.fade.reveal(0.05)      # the boot splash still covers a screen made straight from a tool
	main.get_window().size = SHOT_PX
	await main.get_tree().process_frame      # the root is still adding Main: KinPortrait can't hang its holder yet
	Settings.set_v("boki_wisps", true, false)
	var o := EXPEDITION.duplicate()
	Prematch.deal_mates(o)
	var view := await _view(main, o)
	view.set_process(false)
	for f in ["ride_pick_open", "ride_pick_locked"]:
		for _i in 20:
			await main.get_tree().process_frame
		main.get_viewport().get_texture().get_image().save_png(dir.path_join(f + ".png"))
		view.pm.left = 0.0
		view.pm.locked = true
		view._fill_ride()
		view._fill_hunters()
	print("RIDEPICK shots in %s" % dir)
