extends RefCounted
## --loot-window-check: the deathbox loot window (LootWindow), at the window's size (headless runs set
## 1280x720, the tightest; run with --resolution 1920x1080 under a renderer for the other), with a small
## and a long box: it builds in one go (no layout wait) and sits fully on screen, nothing in it pokes out
## of the window, every thing in the box has one button and that button takes it (the box empties in as
## many presses as it had things), what you wear is marked WORN in the same list as your backpack, no
## perks are shown, better gear from a box backpack goes on when taken, and Esc closes it.
## Never touches the save.

const OPEN_MS := 100.0      # ms, the most building the window may take (it is ~40 controls)
const HEADLESS_SIZE := Vector2i(1280, 720)     # px, the tightest screen we ship for
const POP_S := 0.3          # s, past UI.pop_in's grow-in, so the window is measured at its real size
const INV_SHOTS := preload("res://tools/inv_shots.gd")
const LOOT_FULL := preload("res://tools/loot_full_check.gd")

var bad := 0
var main: Node
var m: Match

func ok(cond: bool, what: String) -> void:
	print("LOOTWIN %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m.set_process(false)
	var p: Hunter = m.player
	var q: Hunter = m.hunters.filter(func(x): return x != p)[0]
	if DisplayServer.get_name() == "headless":
		main.get_window().size = HEADLESS_SIZE
	await _frames(4)
	var view := main.get_viewport().get_visible_rect().size
	var tag := "%dx%d" % [int(view.x), int(view.y)]
	INV_SHOTS.dress(p)
	await _layout(_box(q, p, 0), tag + " small box")
	await _layout(_box(q, p, 12), tag + " long box")
	await _all_takeable(p, q)
	await _wears_upgrade(p, q)
	print("LOOT WINDOW CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A deathbox with a bit of everything, and `extra` more treasure for a long list.
func _box(q: Hunter, p: Hunter, extra: int) -> Dictionary:
	var things: Array = [Loot.valuable("old_coin"), Loot.valuable("kin_idol"), Loot.gear("blink", 3)]
	for i in extra:
		things.append(Loot.valuable("sky_pearl"))
	var bx: Dictionary = LOOT_FULL.make_box(q, p.pos, things)
	bx["gear"] = [{"id": "vest", "rar": 3}, {"id": "skylark_boots", "rar": 2}]
	bx["gems"] = 14
	bx["seeds"] = {"berry": 2}
	bx["belt"] = [{"id": "medkit", "n": 1}]
	bx["chest_keys"] = 1
	m.boxes.append(bx)
	return bx

func _layout(bx: Dictionary, tag: String) -> void:
	var p: Hunter = m.player
	var t0 := Time.get_ticks_usec()
	m.hud.open_loot(bx)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	ok(ms < OPEN_MS, "%s: opens in %.1f ms (under %d)" % [tag, ms, OPEN_MS])
	var w: LootWindow = m.hud.loot_panel
	await main.get_tree().create_timer(POP_S).timeout
	var view := w.get_viewport_rect()
	var r := w.get_global_rect()
	print("LOOTWIN %s window %s in %s" % [tag, r, view])
	ok(view.encloses(r), "%s: the window is fully on screen" % tag)
	var out: Array = []
	var parts: Array = w.find_children("*", "Label", true, false) + w.find_children("*", "Button", true, false) \
		+ w.find_children("*", "PanelContainer", true, false)
	for c in parts:
		var cr := (c as Control).get_global_rect()
		var inside_scroll := _in_scroll(c, w)
		if cr.position.x < r.position.x - 0.5 or cr.end.x > r.end.x + 0.5:
			out.append(c.name)
		elif not inside_scroll and (cr.position.y < r.position.y - 0.5 or cr.end.y > r.end.y + 0.5):
			out.append(c.name)
	ok(out.is_empty(), "%s: nothing pokes out of the window %s" % [tag, out.slice(0, 5)])
	var texts := _texts(w)
	var worn := p.gear.filter(func(g): return not (g as Dictionary).is_empty()).size()
	ok(texts.count("WORN") == worn, "%s: the %d worn pieces are marked WORN in place" % [tag, worn])
	ok(p.pack.all(func(it): return texts.has(Loot.name_of(it))), "%s: your backpack is in the same list" % tag)
	ok(not texts.any(func(s): return String(s).to_lower().contains("perk")), "%s: no perks on this screen" % tag)
	var takes := _take_buttons(w)
	var n := Life.box_items(m, p, bx).size()
	ok(takes.size() == n, "%s: one button for each of the %d things in the box (%d)" % [tag, n, takes.size()])
	ok(not m.hud.pack_open(), "%s: no second inventory window beside it" % tag)
	m.hud.close_loot()
	m.boxes.erase(bx)

func _in_scroll(c: Node, w: Node) -> bool:
	var at := c.get_parent()
	while at != null and at != w:
		if at is ScrollContainer:
			return true
		at = at.get_parent()
	return false

## Nothing worn, lots of room: pressing the first button again and again empties the box, one press a thing.
func _all_takeable(p: Hunter, q: Hunter) -> void:
	p.gear = Gear.empty_slots()
	p.refresh_gear()
	p.pack = []
	p.pack_cap = 30
	for k in p.belt.size():
		p.belt[k] = {}
	var bx := _box(q, p, 3)
	var n := Life.box_items(m, p, bx).size()
	m.hud.open_loot(bx)
	var presses := 0
	while m.hud.loot_open != null and presses < n + 5:
		var takes := _take_buttons(m.hud.loot_panel)
		if takes.is_empty():
			break
		(takes[0] as Button).pressed.emit()
		presses += 1
		await _frames(1)
	ok(bx.get("empty", false) and presses == n,
		"every thing is takeable: %d presses emptied a box of %d" % [presses, n])
	ok(m.hud.loot_open == null, "an emptied box closes its window")
	m.boxes.erase(bx)

## A better glove in the box's backpack: it says UPGRADE and Wear, and taking it puts it on.
func _wears_upgrade(p: Hunter, q: Hunter) -> void:
	INV_SHOTS.dress(p)
	var bx: Dictionary = LOOT_FULL.make_box(q, p.pos, [Loot.gear("blink", 3)])
	m.boxes.append(bx)
	m.hud.open_loot(bx)
	var takes := _take_buttons(m.hud.loot_panel)
	ok(takes.size() == 1 and (takes[0] as Button).text == "Wear" and _texts(m.hud.loot_panel).has("UPGRADE"),
		"a better glove reads UPGRADE with Wear")
	(takes[0] as Button).pressed.emit()
	ok(p.gear.any(func(g): return String((g as Dictionary).get("id", "")) == "blink"), "taking it puts it on")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	if m.hud.loot_open == null:
		m.hud.open_loot(bx)
	main.get_viewport().push_input(esc)
	ok(m.hud.loot_open == null, "Esc closes the window")
	m.boxes.erase(bx)

## The take buttons of the box column (the first column's buttons; your column has none unless holding).
func _take_buttons(w: Control) -> Array:
	return w.find_children("*", "Button", true, false).filter(
		func(b): return (b as Button).text in ["Take", "Wear", "Full"])

func _texts(root: Node) -> Array:
	var out: Array = []
	for l in root.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out

func _frames(k: int) -> void:
	for i in k:
		await main.get_tree().process_frame
