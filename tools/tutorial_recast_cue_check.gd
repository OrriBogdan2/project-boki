extends RefCounted
## --tutorial-recast-cue-check: the two-step ability cue (RecastCue, DECISIONS 2026-11-08 "two-step abilities must be
## obvious and in your face") reaches a new player on the three starters (Lace, Kael, Vex) at 1280x720:
##   1. the fighting tutorial, played through by the driver: every starter whose kit teaches a recast (a
##      `recast_hint` in its archetype data) opens its window on the course (not only in a lab), the local cue carries
##      it, and the real HUD draws the slot on screen at 1280x720; the cue's slot reads "<KEY> AGAIN", the world
##      marker draws no word or key letter on any world object, and the tutorial shows no first-time
##      hint on top of it (it teaches its own way). A starter with no recast in its data opens none.
##   2. the first expedition (a real match with the first-objective card up): the same window, slot on screen, and
##      the one-time hint "<KEY> again to <verb>" reaches the message lane.
## The list of every two-step ability of the 13 kits: docs/HUD.d/1128-recast-cue-all-kits.md.

const STARTERS := ["archer", "juggernaut", "gunslinger"]
const VIEW := Vector2(1280, 720)
const WAIT := 4.0       # s the first expedition's first step gets to open its window

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print("TUTRECAST %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1


## A stand-in for the HUD canvas: the texts a cue draws are recorded.
class StubHud extends Node:
	var c := Control.new()
	var big: Font = ThemeDB.fallback_font
	var texts: Array[String] = []
	func _arc(at: Vector2, rad: float, frac: float, col: Color, w: float) -> void:
		c.draw_arc(at, rad, 0.0, TAU * frac, 24, col, w, true)
	func _ctext(_at: Vector2, text: String, _size: int, _col: Color, _font: Font) -> void:
		texts.append(text)


func run(main_node: Node) -> void:
	main = main_node
	Settings.v["boki_wisps"] = false
	Save.no_write = true
	for id in STARTERS:
		await _tutorial(id)
	await _expedition("juggernaut")
	print("TUTRECAST DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## True when the starter's archetype data names a recast (so the course must show the cue).
func _teaches_recast(p: Hunter) -> bool:
	return not (p.ak.d.get("recast_hint", {}) as Dictionary).is_empty()


func _tutorial(id: String) -> void:
	seed(11)
	Save.d["tutorial"]["tut_beat"] = ""
	Save.d["tutorial"].erase("recast_" + id)
	var m := Match.new()
	main.add_child(m)
	m.start({"tutorial": true, "tut_test": true, "seed": 11, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0,
			"demo_kin": "cindle", "arch": id, "cls": Arch.weight(id)})
	m.set_process(false)
	var p := m.player
	var opened := {}        # slot -> the tutorial step it first opened in
	var carried := false
	var drew := false
	var t := 0.0
	var hint_seen := false
	while t < 400.0 and not p.extracted:
		TutorialDrive.drive(m)
		m.step(Match.DT)
		t += Match.DT
		var w := p.ak.recast_window()
		if m.hud != null:
			hint_seen = hint_seen or m.hud.msgs.texts().any(func(s: String) -> bool: return " again to " in s)
		if w.is_empty() or opened.has(String(w["slot"])):
			continue
		opened[String(w["slot"])] = m.tut.id()
		m.step(Match.DT)      # (the cue tracks the window a step after it opens)
		carried = String(p.ak.cue.get("w", {}).get("slot", "")) == String(w["slot"])
		drew = await _slot_draws(m, String(w["slot"]))
	print("TUTRECAST %s: windows opened %s in %.0f s" % [id, str(opened), t])
	if _teaches_recast(p):
		ok(not opened.is_empty(), "%s: the course opens its recast window" % id)
		ok(carried, "%s: the local cue carries the window (slot pulse, timer)" % id)
		ok(drew, "%s: the slot draws \"<KEY> AGAIN\" on screen at 1280x720, no word on world objects" % id)
	else:
		ok(opened.is_empty(), "%s: no recast in its data, none opens on the course %s" % [id, str(opened)])
	ok(not hint_seen, "%s: the tutorial shows no first-time recast line on top of the cue" % id)
	ok(p.extracted, "%s: the course finishes" % id)
	m.queue_free()
	await main.get_tree().process_frame


## The real HUD at 1280x720 draws the ability row: the slot's face is on screen. Then the cue's slot and world
## draws go to a stub: the slot reads "<KEY> AGAIN" and the world marker adds no text.
func _slot_draws(m: Match, slot: String) -> bool:
	var hud: Node = m.hud
	if hud == null:
		return false
	hud.panels.size = VIEW
	hud.panels.queue_redraw()
	await hud.panels.draw
	var face := RankMarks.face("kin" if slot == "e" else slot)
	var on_screen := face.size.x > 0.0 and Rect2(Vector2.ZERO, VIEW).encloses(face)
	var stub := StubHud.new()
	stub.c.size = VIEW
	var p := m.player
	RecastCue.slot(stub, p, slot, face)
	var slot_texts := stub.texts.duplicate()
	stub.texts.clear()
	RecastCue.world(stub, m.cam, p)
	var world_plain := stub.texts.is_empty()
	var key := RecastCue.key_of(slot)
	var reads := slot_texts.has("%s AGAIN" % key) or slot_texts.has("WAIT")
	stub.free()
	print("TUTRECAST   slot %s face %s texts %s world plain %s" % [slot, str(face), str(slot_texts), str(world_plain)])
	return on_screen and reads and world_plain


func _expedition(id: String) -> void:
	seed(7)
	Save.d["tutorial"].erase("recast_" + id)
	Save.d["tutorial"].erase(FirstObjective.KEY)
	Settings.v["tips"] = true
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4243, "no_drop": true, "arch": id,
			"cls": Arch.weight(id), "demo_kin": "cindle"})
	m.set_process(false)
	var p := m.player
	p.unlock_all()
	p.ult = 0.0
	ok(m.objective != null, "%s: a first expedition (the objective card is up)" % id)
	var foe: Hunter = m.make_hunter("T", 5, "medium", "Target", "idle", {}, p.pos + Vector3(6, 0, 0), {"arch": "none"})
	foe.max_hp = 10000.0
	foe.hp = foe.max_hp
	for i in 5:
		m.step(Match.DT)
	p.inp["aim"] = foe.pos + Vector3(0, 0.9, 0)
	p.inp["aim_y"] = foe.pos.y
	p.ak.use_e()
	var w := {}
	var t := 0.0
	while t < WAIT and w.is_empty():
		w = p.ak.recast_window()
		m.step(Match.DT)
		t += Match.DT
	ok(not w.is_empty(), "%s: E on a foe opens the recast window in a real match" % id)
	if w.is_empty():
		m.queue_free()
		return
	var slot := String(w["slot"])
	m.step(Match.DT)
	var draws := await _slot_draws(m, slot)
	ok(draws, "%s: first expedition: the slot draws \"<KEY> AGAIN\" at 1280x720, no world words" % id)
	var line := RecastCue.hint_line(p.ak, slot)
	var texts: Array[String] = m.hud.msgs.texts()
	ok(texts.any(func(s: String) -> bool: return s.contains(line)) and line != "",
			"%s: first expedition: the one-time hint reaches the message lane ('%s' in %s)" % [id, line, str(texts)])
	m.queue_free()
	await main.get_tree().process_frame
