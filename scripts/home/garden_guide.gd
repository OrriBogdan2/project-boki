class_name GardenGuide
extends RefCounted
## The garden tutorial on screen (FarmGuide owns one and ticks it; the rules are GardenTutorial).
## Follows the "first 10 minutes" rule: the player always knows what to do next.
##  - the instruction shows as a centred card when a step starts, then shrinks to a pill at the bottom;
##    standing still for idle_reprompt_s brings the card back
##  - a tall light beam on the target (your Boki, then the portal) and a marker with the distance: a
##    diamond over it on screen, an arrow at the screen edge when it is off screen; never hidden, but it
##    fades back under speech bubbles and message cards (MsgLane), so two lines never print over each other
##  - your Boki leads: it comes to you to say hi, stays close while you care for it, and runs ahead to
##    the portal at the end, waiting and looking back when you fall behind (lead_goal, from home._move_kin)
## Nothing shows while a menu, a talk or the training game is up.

const GOLD := Color("ffd36a")
const PILL_UP := 150.0          # px from the bottom: above the interact prompt and the key row

var h
var beam: MeshInstance3D = null
var mark: Control = null
var card: PanelContainer = null
var card_title: Label = null
var card_lbl: Label = null
var pill: PanelContainer = null
var pill_lbl: Label = null
var step := ""
var card_t := 0.0
var idle_t := 0.0
var last_p := Vector3.INF
var t := 0.0
var poll_t := 0.0
var look_t := 0.0
var mark_a := 1.0
var was_active := false
var hidden := true

class Mark extends Control:
	var g
	func _draw() -> void:
		if g:
			g._draw_mark(self)

func _init(home) -> void:
	h = home
	was_active = GardenTutorial.active()

func tick(dt: float, quiet: bool) -> void:
	if not h.visit.is_empty() or h.root_ui == null:
		return
	t += dt
	poll_t -= dt
	if poll_t <= 0.0:
		poll_t = 0.5
		_poll()
	var cur := GardenTutorial.current()
	if cur != step:
		step = cur
		_on_step()
	hidden = cur == "" or quiet or h.panel_open != "" or not h.train.is_empty() or h.chat_open \
			or (h.hob != null and h.hob.chat.busy())
	_update(dt)

func _poll() -> void:
	var rec := Save.active_kin()
	var line := GardenTutorial.prepare(rec)
	if line != "":
		h._toast(line)
	if GardenTutorial.current() == "meet":
		var k: Dictionary = h._kin_entry(rec) if not rec.is_empty() else {}
		if not k.is_empty() and Vector2(k["pos"].x - h.ppos.x, k["pos"].z - h.ppos.z).length() < float(GardenTutorial.option("meet_m")):
			GardenTutorial.event("meet")
			h._emote(k, "♥", true)
	var now := GardenTutorial.active()
	if was_active and not now and bool(GardenTutorial.state().get("done", false)):
		h._toast(GardenTutorial.fill(String(GardenTutorial.rules()["done_toast"])))
		Sfx.play("unlock", null, -6.0)
	was_active = now
	h.refresh_hub()      # Build joins the hub bar once the farm opens
	if GardenTutorial.farm_open():
		var ft := GardenTutorial.take_farm_toast()
		if ft != "":
			h._toast(ft)
			Sfx.play("unlock", null, -8.0)

func _on_step() -> void:
	if step == "":
		clear()
		return
	_build()
	card_t = float(GardenTutorial.option("card_s"))
	idle_t = 0.0
	var i := GardenTutorial.index_of(step)
	card_title.text = "%d/%d  %s" % [i + 1, GardenTutorial.steps().size(), String(GardenTutorial.step_def(step).get("title", ""))]
	if step != "meet":
		Sfx.play("ping", null, -12.0)

## The instruction line for the current step (the card and the pill show the same words).
func text() -> String:
	return GardenTutorial.hint_text(step)

## Where the current step's thing is: your Boki, or the portal at the end.
func target() -> Vector3:
	if step == "":
		return Vector3.INF
	if step == "out":
		return h.spots.get("portal", Vector3.INF)
	var k: Dictionary = h._kin_entry(Save.active_kin())
	return (k["node"] as Node3D).position if not k.is_empty() else Vector3.INF

func _build() -> void:
	if is_instance_valid(card):
		return
	card = UI.card(Color(0.06, 0.07, 0.11, 0.94), 18, 22)
	UI.set_card_border(card, Color(UI.GOLD, 0.6), 2)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := UI.vbox(8)
	card.add_child(col)
	card_title = UI.label("", 15, UI.GOLD, UI.semi)
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(card_title)
	card_lbl = UI.label("", 24, UI.INK, UI.big)
	card_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_lbl.custom_minimum_size.x = 460.0
	col.add_child(card_lbl)
	pill = UI.card(Color(0.06, 0.07, 0.11, 0.9), 22, 10)
	UI.set_card_border(pill, Color(UI.GOLD, 0.45), 1)
	pill.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pill.offset_top = -PILL_UP
	pill.offset_bottom = -PILL_UP
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_lbl = UI.label("", 17, UI.INK, UI.semi)
	pill.add_child(pill_lbl)
	mark = Mark.new()
	mark.g = self
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.root_ui.add_child(mark)
	h.root_ui.add_child(pill)
	h.root_ui.add_child(card)
	if is_instance_valid(h.panel_host):
		for c in [mark, pill, card]:
			h.root_ui.move_child(c, h.panel_host.get_index())      # menus open on top
	beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9
	cyl.bottom_radius = 0.9
	cyl.height = 60.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(GOLD, 0.3)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cyl.material = mat
	beam.mesh = cyl
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	h.add_child(beam)

func clear() -> void:
	for c in [card, pill, mark, beam]:
		if is_instance_valid(c):
			c.queue_free()
	card = null
	pill = null
	mark = null
	beam = null

func _update(dt: float) -> void:
	if not is_instance_valid(card):
		return
	if hidden:
		for c in [card, pill, mark, beam]:
			c.visible = false
		return
	# standing still a while: the card comes back
	if last_p != Vector3.INF and Vector2(h.ppos.x - last_p.x, h.ppos.z - last_p.z).length() < 0.05:
		idle_t += dt
	else:
		idle_t = 0.0
	last_p = h.ppos
	if idle_t >= float(GardenTutorial.option("idle_reprompt_s")) and card_t <= 0.0:
		idle_t = 0.0
		card_t = float(GardenTutorial.option("card_s"))
	card_t -= dt
	var s := text()
	card_lbl.text = s
	pill_lbl.text = s
	card.visible = card_t > 0.0
	pill.visible = not card.visible
	card.reset_size()
	card.position = Vector2((h.root_ui.size.x - card.size.x) * 0.5, h.root_ui.size.y * 0.3 - card.size.y * 0.5)
	# a message card on top of the instruction card: the instruction steps back until it goes
	var lane := MsgLane.of(h.root_ui).rects()
	var under := lane.any(func(r: Rect2): return r.intersects(card.get_rect()))
	card.modulate.a = move_toward(card.modulate.a, 0.15 if under else 1.0, dt * 6.0)
	var at := target()
	beam.visible = at.x != INF and at.x > -100.0
	if beam.visible:
		var wide := 0.55 if step != "out" else 1.0
		beam.scale = Vector3(wide, 1.0, wide)
		beam.position = Vector3(at.x, 30.0, at.z)
	mark.visible = beam.visible
	if mark.visible:
		mark_a = move_toward(mark_a, 0.15 if _mark_covered(at, lane) else 1.0, dt * 6.0)
		mark.queue_redraw()

## The marker's box on screen (where _draw_mark puts it), or an empty rect when it sits at the edge.
func _mark_rect(at: Vector3) -> Rect2:
	var cam: Camera3D = h.cam
	var tp := cam.unproject_position(at + Vector3(0, 2.6, 0))
	if cam.is_position_behind(at) or not _on_screen(tp):
		return Rect2()
	return Rect2(tp - Vector2(110, 26), Vector2(220, 110))

func _on_screen(tp: Vector2) -> bool:
	var sz: Vector2 = h.root_ui.size
	return Rect2(Vector2(40, 110), sz - Vector2(80, 260)).has_point(tp)

## Covered by a message card, a Boki's (or Hob's) speech bubble or the instruction card?
func _mark_covered(at: Vector3, lane: Array[Rect2]) -> bool:
	var mine := _mark_rect(at)
	if mine.size == Vector2.ZERO:
		return false
	var covers: Array[Rect2] = lane.duplicate()
	for k in h.kins:
		var say: Label3D = k.get("say")
		if say and say.visible:
			covers.append(MsgLane.label_rect(say, h.cam))
	if card.visible:
		covers.append(card.get_rect())
	return covers.any(func(r: Rect2): return r.intersects(mine))

func _draw_mark(c: Control) -> void:
	var at := target()
	if at.x == INF or hidden:
		return
	var cam: Camera3D = h.cam
	var col := Color(GOLD, mark_a)
	var shade := Color(0, 0, 0, 0.5 * mark_a)
	var label := GardenTutorial.world_text(step)
	var dist := int(round(Vector2(at.x - h.ppos.x, at.z - h.ppos.z).length()))
	var bob := sin(t * 4.0) * 4.0
	var tp := cam.unproject_position(at + Vector3(0, 2.6, 0))
	var behind := cam.is_position_behind(at)
	if not behind and _on_screen(tp):
		var p := tp + Vector2(0, bob)
		c.draw_circle(p, 22.0, shade)
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -18), p + Vector2(14, 0), p + Vector2(0, 18), p + Vector2(-14, 0)]), col)
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(-11, 25), p + Vector2(11, 25), p + Vector2(0, 42)]), col)
		_ctext(c, p + Vector2(0, 66), "%s  ·  %dm" % [label, dist] if dist >= 2 else label, 20, col)
		var gp := cam.unproject_position(at + Vector3(0, 0.05, 0))
		c.draw_arc(gp, 26.0 + bob, 0, TAU, 28, Color(col, 0.85 * mark_a), 4.0, true)
		return
	var sz := c.size
	var ctr := Vector2(sz.x * 0.5, sz.y * 0.47)
	var d := (tp - ctr).normalized() if not behind else (ctr - tp).normalized()
	if d.length() < 0.1:
		d = Vector2.UP
	var hx := sz.x * 0.5 - 70.0
	var hy := sz.y * 0.26
	var k := minf(hx / maxf(0.001, absf(d.x)), hy / maxf(0.001, absf(d.y)))
	var edge := ctr + d * k + d * bob * 0.5
	var perp := Vector2(-d.y, d.x)
	c.draw_colored_polygon(PackedVector2Array([edge + d * 44.0, edge - d * 12.0 + perp * 28.0, edge - d * 12.0 - perp * 28.0]), shade)
	c.draw_colored_polygon(PackedVector2Array([edge + d * 38.0, edge - d * 9.0 + perp * 23.0, edge - d * 9.0 - perp * 23.0]), col)
	_ctext(c, edge - d * 62.0, "%s  %dm" % [label, dist], 20, col)

func _ctext(c: Control, at: Vector2, s: String, px: int, col: Color) -> void:
	var f: Font = UI.big
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var p := at - Vector2(w * 0.5, 0)
	c.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 6, Color(0, 0, 0, 0.8 * col.a))
	c.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)

# ------------------------------------------------------------------ your Boki leads
## Where your Boki should head for the tutorial right now (INF: its own idea). home._move_kin asks
## every frame for each Boki; only the active one answers to it, and never while it fetches, works,
## naps or trains.
func lead_goal(k: Dictionary) -> Vector3:
	var cur := GardenTutorial.current()
	if cur == "" or h.panel_open != "" or k.get("busy", false) or k.has("fetch") or k.has("job") or k.has("called_t"):
		return Vector3.INF
	if k.has("bath") or k.has("indoors") or k.has("eat"):
		return Vector3.INF
	if String(k["rec"].get("uid", "")) != String(Save.active_kin().get("uid", "")):
		return Vector3.INF
	# no naps or wandering off indoors in the middle of it
	if float(k.get("nap_t", 0.0)) > 0.0:
		k["nap_t"] = 0.01
	k.erase("going_in"); k.erase("nap_go"); k.erase("chase"); k.erase("stare")
	var pos: Vector3 = k["pos"]
	var pp: Vector3 = h.ppos
	var gap := Vector2(pp.x - pos.x, pp.z - pos.z)
	if cur != "out":
		# say hi: it trots over; then it stays close while you look after it
		if gap.length() < (2.0 if cur == "meet" else 3.2):
			return pos
		var back := Vector3(-gap.x, 0, -gap.y).normalized()
		return pp + back * 1.4
	var portal: Vector3 = h.spots.get("portal", Vector3.INF)
	if portal == Vector3.INF:
		return Vector3.INF
	var way := Vector3(portal.x - pp.x, 0, portal.z - pp.z)
	if gap.length() > 6.0:
		# too far ahead: it waits and looks back at you
		look_t -= h.get_process_delta_time()
		if look_t <= 0.0:
			look_t = 2.5
			h._emote(k, "!")
		return pos
	if way.length() < 4.0:
		return portal - way.normalized() * 0.8      # at the portal, waiting for you
	return pp + way.normalized() * 3.5
