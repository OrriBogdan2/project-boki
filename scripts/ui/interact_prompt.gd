class_name InteractPrompt
extends PanelContainer
## The one interact prompt, in the match, on the farm, in town and indoors: a keycap with the live
## binding (Settings.key_cap, redrawn from the binding on every show), a short verb, what it works on,
## an optional detail line, and a ring round the keycap that fills while a hold action is held.
## Whoever picks the target (Match, Home, Town, Interior) shows exactly one dictionary; hide when none.
## Fields: action (default "interact"), verb ("" for a line that only informs), who, note, hold (a hold
## action: the ring shows), frac (0..1 ring fill), col, more ([[action, what, ok], ...] extra keys beside it;
## ok false greys one out, it can't be done now). With no verb and no note, the more keys are the whole line.

const RING_PAD := 9.0        # px between the keycap and the ring
const RING_W := 3.0          # px: ring thickness
const MATCH_BOTTOM := 210.0  # px from the screen's bottom to the match prompt's bottom edge (clear of the kit bar)
const GREY_A := 0.35         # alpha of a more key that can't be done now

## The ring round the keycap: a faint full circle, and the held part on top.
class Ring extends Control:
	var frac := 0.0
	var col := Color.WHITE
	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5 - 2.0
		draw_arc(size * 0.5, r, 0.0, TAU, 40, Color(1, 1, 1, 0.16), RING_W, true)
		if frac > 0.0:
			draw_arc(size * 0.5, r, -PI * 0.5, -PI * 0.5 + TAU * clampf(frac, 0.0, 1.0), 40, col, RING_W, true)

var ring: Ring            # (read by tools/interact_prompt_check.gd)
var cap_lbl: Label
var line: Label
var _cap: PanelContainer
var _note: Label
var _more: HBoxContainer
var _sig := ""

func _init() -> void:
	add_theme_stylebox_override("panel", UI.glass(10, 16).get_theme_stylebox("panel"))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UI.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	ring = Ring.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ring)
	_cap = UI.keycap("F", 16)
	_cap.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cap.grow_vertical = Control.GROW_DIRECTION_BOTH
	_cap.set_anchors_preset(Control.PRESET_CENTER)
	cap_lbl = _cap.get_child(0)
	ring.add_child(_cap)
	var col := UI.vbox(0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	line = UI.label("", 18, UI.GOLD, UI.big)
	line.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(line)
	_note = UI.label("", 13, UI.MUTED)
	_note.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(_note)
	_more = UI.hbox(10)
	_more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_more)
	visible = false

## Shows the prompt for `it` (a dictionary with the fields above), or hides it for an empty one.
func show_for(it: Dictionary) -> void:
	var more: Array = it.get("more", [])
	if it.is_empty() or (String(it.get("verb", "")) == "" and String(it.get("note", "")) == "" and more.is_empty()):
		visible = false
		return
	var verb := String(it.get("verb", ""))
	var who := String(it.get("who", ""))
	var col: Color = it.get("col", UI.GOLD)
	var has_key := verb != ""
	var key := Settings.key_cap(String(it.get("action", "interact")))
	var caps := more.map(func(m): return Settings.key_cap(String(m[0])))
	var sig := "%s|%s|%s|%s|%s|%s|%s" % [has_key, key, verb, who, it.get("note", ""), str(more), str(caps)]
	if sig != _sig:
		_sig = sig
		ring.visible = has_key
		cap_lbl.text = key
		_cap.custom_minimum_size.x = maxf(26.0, 12.0 + 10.0 * key.length())
		line.text = ("%s  ·  %s" % [verb, who]) if who != "" and has_key else verb
		line.visible = has_key
		_note.text = String(it.get("note", ""))
		_note.visible = _note.text != ""
		line.get_parent().visible = has_key or _note.visible
		_note.add_theme_color_override("font_color", UI.INK if not has_key else UI.MUTED)
		_rebuild_more(more)
		ring.custom_minimum_size = _cap.get_combined_minimum_size() + Vector2.ONE * RING_PAD * 2.0
		reset_size()
	line.add_theme_color_override("font_color", col)
	ring.col = col
	ring.frac = clampf(float(it.get("frac", 0.0)), 0.0, 1.0) if bool(it.get("hold", false)) else 0.0
	ring.queue_redraw()
	visible = true

func _rebuild_more(more: Array) -> void:
	for ch in _more.get_children():
		ch.free()
	for m in more:
		var one := UI.key_hints([[Settings.key_cap(String(m[0])), m[1]]], 14, UI.INK)
		if m.size() > 2 and not m[2]:
			one.modulate.a = GREY_A
		_more.add_child(one)

## What the match's interact target `it` (Match.interact) shows: its fields plus how far the hold has got.
## One prompt at a time: while a tutorial tip card pops in, the prompt yields to it (unless a hold is under way).
static func match_item(m: Match, p: Hunter, it: Dictionary) -> Dictionary:
	var out := it.duplicate()
	var prog := 0.0
	match it["kind"]:
		"revive": prog = it["ent"].revive
		"finish": prog = p.finish_t / Life.R["stomp_commit"]
		"stomping": prog = float(p.stomp.get("t", 0.0)) / Life.R["stomp_time"]
		"boxrev": prog = p.box_t / BoxRevive.time_for()
		"loot": prog = p.box_t / Life.R["loot_time"]
		"catch": prog = CaptureHud.progress(p)
		"chest": prog = it["chest"]["prog"]
		"exit": prog = float(it["x"]["hold"].get(p.nid, 0.0)) / float(it["need"]) if it.has("need") else 0.0
		"lair": prog = float(it["rune"]["prog"]) if it.has("rune") else 0.0
		"heart": prog = float(it.get("prog", 0.0))
		"wisp": prog = float(p.get_meta("wgrab", 0.0)) / float(KinSteal.rules()["grab_s"])
	if prog <= 0.0 and m.tut != null and m.tut.card_up():
		return {}
	out["frac"] = prog
	return out

## Bottom-centre of `vp` with its bottom edge at `y`.
func place(vp: Vector2, y: float) -> void:
	position = Vector2((vp.x - size.x) * 0.5, y - size.y)

## Centred over the world point `at` (its bottom edge there); hidden when `at` is behind the camera.
func place_over(cam: Camera3D, at: Vector3) -> void:
	visible = visible and not cam.is_position_behind(at)
	position = cam.unproject_position(at) - Vector2(size.x * 0.5, size.y)
