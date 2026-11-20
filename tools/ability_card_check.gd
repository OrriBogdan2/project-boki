extends RefCounted
## --ability-card-check: the ability card says what the data says (docs/decisions: ability cards).
##   1. for every Hunter and every kit slot: name = the data's name, key = Settings.key_cap, cooldown and range
##      = the numbers in content/archetypes (the dash's "cd", the others' "cooldown", the "card_range" path)
##   2. exactly the two-step abilities say "Press <key> again to ...", and no one-press ability does
##   3. the HUD's card (the kit's live slot_info at rank 1) shows the same numbers as the menus' card
##   4. the widget builds, in a tree, with its numbers line, sentence and key cap on screen
##   5. hovering a row of the Hunter pick's kit card and of the Relic screen puts the card up; in a match, holding
##      Tab over the HUD's ability row puts it up with the kit's live name and cooldown, and letting go drops it
## With --shots-dir=<dir> (xvfb, via jobq --needs gpu): relic, kit_card and hud PNGs, each with a card up.

var main: Node
var fails := 0
var n := 0
var shots := ""      # --shots-dir=<dir> (needs a renderer): relic, kit_card and hud PNGs
## The two-step abilities: who, which slot (counted from the data's "again" phrases).
const TWO_STEP := 8

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("CARDCHECK %-62s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			shots = String(a).substr(12)
	if shots != "" and main.fade != null:
		main.fade.reveal(0.05)      # (the boot splash would cover the screenshots)
	Save.no_write = true
	_numbers()
	await _widget()
	await _hover_and_shots()
	print("CARDCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()

## The number a dotted path names in a slot's data, read here on its own (not through AbilityCard).
func _data_at(sd: Dictionary, path: String) -> float:
	var node: Variant = sd
	for part in path.split("."):
		node = node[part]
	return float(node)

func _numbers() -> void:
	var again_n := 0
	var bad: Array = []
	for a in Arch.ids():
		var ak := String(a)
		var d: Dictionary = Arch.def(ak)
		for slot in ["dash", "rmb", "e", "x"]:
			var sd: Dictionary = d[slot]
			var f := AbilityCard.facts_for(ak, slot)
			var cd := float(sd["cd" if slot == "dash" else "cooldown"])
			var want_name := String(sd["name"])
			var key_ok: bool = f["key"] == Settings.key_cap(String(HunterViewer.SLOT_ACTIONS[slot]))
			var line := AbilityCard.numbers(f)
			var has_range: bool = sd.has("card_range")
			var rng := _data_at(sd, String(sd["card_range"])) if has_range else -1.0
			var good: bool = f["name"] == want_name and key_ok and f["key"] != "?"
			good = good and is_equal_approx(float(f["cooldown"]), cd) and is_equal_approx(float(f["range"]), rng)
			good = good and line.contains("Cooldown %ss" % KinText.n(cd))
			good = good and (line.contains("%sm" % KinText.n(rng)) if has_range else not line.contains("m"))
			var again := AbilityCard.again_line(f)
			var want_again := String(sd.get("again", ""))
			var want_line := "Press %s again to %s." % [f["key"], want_again] if want_again != "" else ""
			good = good and again == want_line
			if want_again != "":
				again_n += 1
			if not good:
				bad.append("%s/%s" % [ak, slot])
		# (a card for the slot with no cooldown: still has its name and key, never a numbers line)
		var lmb := AbilityCard.facts_for(ak, "lmb")
		if AbilityCard.numbers(lmb) != "":
			bad.append(ak + "/lmb numbers")
	ok("12 Hunters x dash, RMB, E, X: name, key, cooldown, range, again = data", bad.is_empty(), ", ".join(bad))
	ok("%d abilities are two-step, each says 'Press <key> again to'" % TWO_STEP, again_n == TWO_STEP, str(again_n))
	ok("at least 12 Hunters (all are checked)", Arch.ids().size() >= 12)

func _widget() -> void:
	var tree := main.get_tree()
	var layer := CanvasLayer.new()
	main.add_child(layer)
	var all_built := true
	var live_ok := true
	for a in Arch.ids():
		for slot in ["dash", "rmb", "e", "x"]:
			var base := AbilityCard.facts_for(String(a), slot)
			var live := {"name": base["name"], "cd_max": base["cooldown"]}
			var live_card := AbilityCard.facts_for(String(a), slot, live)
			if AbilityCard.numbers(live_card) != AbilityCard.numbers(base) or live_card["name"] != base["name"]:
				live_ok = false
			var card := AbilityCard.make(String(a), slot, live)
			layer.add_child(card)
			await tree.process_frame
			var txt := _text_of(card)
			if not (txt.contains(String(base["name"])) and txt.contains(AbilityCard.numbers(base))
					and card.size.x >= AbilityCard.WIDTH - 1.0):
				all_built = false
			card.queue_free()
	ok("the HUD's live card (rank 1) shows the same numbers as the menus' card", live_ok)
	ok("every card builds in a tree and shows its name and numbers", all_built)
	layer.queue_free()

func _text_of(node: Node) -> String:
	var out := String(node.text) if node is Label else ""
	for ch in node.get_children():
		out += "\n" + _text_of(ch)
	return out

func _shot(file: String, frames := 12) -> void:
	if shots == "":
		return
	for i in frames:
		await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	main.get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [shots, file])

## The controls under `node` that show a card for `slot`.
func _rows(node: Node, slot: String, out: Array) -> Array:
	if node is Control and node.get_meta("card_slot", "") == slot:
		out.append(node)
	for ch in node.get_children():
		_rows(ch, slot, out)
	return out

func _cards_under(node: Node) -> Array:
	var out: Array = []
	if node is AbilityCard:
		out.append(node)
	for ch in node.get_children():
		out.append_array(_cards_under(ch))
	return out

## The menus: a mouse on the E row puts its card up (the data's numbers) and off it takes it down.
func _menu_hover(host: Node, shot: String, label: String, arch: String) -> void:
	var tree := main.get_tree()
	var rows := _rows(host, "e", [])
	ok("%s: every kit row shows a card (E row found)" % label, rows.size() >= 1)
	if rows.is_empty():
		return
	var row: Control = rows[0]
	row.mouse_entered.emit()
	for i in 3:
		await tree.process_frame
	var up := _cards_under(row)
	var want := AbilityCard.facts_for(arch, "e")
	ok("%s: hovering E puts one card up with the data's numbers" % label, up.size() == 1
			and up[0].facts["cooldown"] == want["cooldown"] and up[0].facts["name"] == want["name"])
	await _shot(shot)
	row.mouse_exited.emit()
	await tree.process_frame
	ok("%s: the card goes when the mouse leaves" % label, _cards_under(row).is_empty())

func _hover_and_shots() -> void:
	var tree := main.get_tree()
	var layer := CanvasLayer.new()
	layer.layer = 50
	main.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var host := CenterContainer.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.theme = UI.theme()
	layer.add_child(host)
	var viewer := HunterViewer.make("thief", Vector2(250, 300))
	host.add_child(viewer)
	await tree.process_frame
	await _menu_hover(viewer, "relic", "Relic screen", "thief")
	viewer.queue_free()
	var kit := KitCard.make("rimewright", "", func(): pass)
	host.add_child(kit)
	await tree.process_frame
	await _menu_hover(kit, "kit_card", "Hunter pick", "rimewright")
	kit.queue_free()
	layer.queue_free()
	await _hud_hover()

## In a match: Tab held over the E slot shows the card with the kit's live numbers; not held, no card. With
## --hover=k1 on the command line (the HUD's pointing hook) the HUD's own draw pass does it, else the call is direct.
func _hud_hover() -> void:
	var tree := main.get_tree()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true, "arch": "thief",
			"cls": Arch.weight("thief"), "weapon": Arch.signature("thief")})
	for i in 20:
		await tree.process_frame
	var hud = m.hud
	var p: Hunter = m.player
	var hooked: bool = OS.get_cmdline_user_args().has("--hover=k1")
	var live: Dictionary = p.slot_info("k1")
	var spot := Rect2(600, 640, 64, 64)
	for hs in hud.hover_spots:
		if hs[1] == "k1":
			spot = hs[0]
	var shown := func(): return _cards_under(hud.c)
	ok("no Tab: no ability card on the HUD", not AbilityCard.on_hud(hud.c, "k1", spot, p) and shown.call().is_empty())
	Input.action_press("scores")
	if not hooked:
		ok("Tab held on E: the card shows", AbilityCard.on_hud(hud.c, "k1", spot, p))
	else:
		for i in 4:
			await tree.process_frame      # (the HUD's own pass puts it up; a direct call is dropped by its next one)
	var up: Array = shown.call()
	ok("Tab held on E: one card with the kit's live name and cooldown", up.size() == 1
			and up[0].facts["name"] == String(live["name"])
			and up[0].facts["cooldown"] == float(live["cd_max"]), str(live["name"]))
	var data_cd := float(Arch.def("thief")["e"]["cooldown"])
	ok("the live cooldown is the data's at rank 1", p.ability_level("k1") == 1
			and is_equal_approx(float(live["cd_max"]), data_cd), "%s vs %s" % [live["cd_max"], data_cd])
	await _shot("hud")
	Input.action_release("scores")
	for i in 3:
		await tree.process_frame
	ok("Tab let go: the card goes", shown.call().is_empty() or hooked and not AbilityCard.on_hud(hud.c, "", Rect2(), p))
	m.queue_free()
	await tree.process_frame
