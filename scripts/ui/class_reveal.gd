class_name ClassReveal
extends CanvasLayer
## The reveal moment when a class opens: the screen dims, the class steps into a ring of its own
## colour with a short chime, and says what it is. One class at a time; "Play it" switches your
## hunter to it (HomeHero.pick), "Later" keeps your current class. Both mark the reveal as seen
## (ClassUnlock.reveal_done), so it never plays twice.
##
##   ClassReveal.maybe_show(home)    # on the farm: plays for the first class waiting, then the next

signal closed(played: bool)

var id := ""
var host: Node
var root: Control
var glow: Control
var t := 0.0

## Shows the reveal for the first waiting class, if any. Returns the overlay (or null).
static func maybe_show(home: Node) -> ClassReveal:
	var waiting := ClassUnlock.pending_reveal()
	if waiting.is_empty() or home == null or not home.is_inside_tree():
		return null
	var rv := ClassReveal.new()
	rv.id = String(waiting[0])
	rv.host = home
	rv.layer = 60
	home.add_child(rv)
	return rv

func _ready() -> void:
	root = Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new(); dim.color = Color(0.02, 0.01, 0.06, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var col := Arch.color(id)
	var center := CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var v := UI.vbox(10); v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	var kick := UI.label("NEW CLASS", UI.T_HEAD, UI.GOLD, UI.caps)
	kick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(kick)
	# the ring of light, with the class standing in it
	var stage := Control.new(); stage.custom_minimum_size = Vector2(340, 310)
	stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(stage)
	glow = Control.new(); glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.draw.connect(_draw_glow.bind(col))
	stage.add_child(glow)
	var tex := ClassCard.portrait(id, 280.0, true)
	tex.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	tex.offset_left = -140; tex.offset_right = 140; tex.offset_top = -140; tex.offset_bottom = 140
	tex.pivot_offset = Vector2(140, 140)
	tex.scale = Vector2(0.2, 0.2); tex.modulate.a = 0.0
	stage.add_child(tex)
	var nm := UI.title(Arch.name_of(id), 54, col)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	var wl := UI.label(ClassCard.weight_line(id), UI.T_SMALL, UI.MUTED)
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(wl)
	var fan := UI.para(String(Arch.def(id).get("fantasy", "")), UI.T_BODY, UI.INK)
	fan.custom_minimum_size.x = 520
	fan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(fan)
	var loop := UI.para(String(Arch.def(id).get("card", {}).get("loop", "")), UI.T_SMALL, UI.MUTED)
	loop.custom_minimum_size.x = 520
	loop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(loop)
	var btns := UI.hbox(12); btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_child(UI.ghost("Later", func(): _finish(false), 140))
	var play := UI.primary("Play %s" % Arch.name_of(id), func(): _finish(true), 220)
	btns.add_child(play)
	v.add_child(btns)
	root.set_meta("class_id", id)
	# the moment: chime, the class pops into the ring, text eases in
	Sfx.play("unlock", null, -4.0, 0.0, 1.0)
	Sfx.play("whoosh", null, -9.0, 0.0, 0.8)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(tex, "modulate:a", 1.0, 0.25)
	tw.tween_property(tex, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for c in [kick, nm, wl, fan, loop, btns]:
		(c as Control).modulate.a = 0.0
		tw.tween_property(c, "modulate:a", 1.0, 0.4).set_delay(0.35)
	play.call_deferred("grab_focus")

func _process(dt: float) -> void:
	t += dt
	if glow:
		glow.queue_redraw()

## Soft rings and slow rays in the class's colour behind the portrait.
func _draw_glow(col: Color) -> void:
	var c := glow.size * 0.5
	var k := clampf(t / 0.6, 0.0, 1.0)
	for i in 5:
		var r := (70.0 + 26.0 * i) * (0.6 + 0.4 * k)
		glow.draw_circle(c, r, Color(col, 0.06 * (1.0 - i * 0.16)))
	for i in 12:
		var a := t * 0.35 + TAU * float(i) / 12.0
		var from := c + Vector2(cos(a), sin(a)) * 110.0
		var to := c + Vector2(cos(a), sin(a)) * (150.0 + 14.0 * sin(t * 2.0 + i))
		glow.draw_line(from, to, Color(col, 0.35 * k), 3.0, true)
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	glow.draw_arc(c, 128.0 + 4.0 * pulse, 0, TAU, 64, Color(col, 0.85 * k), 3.0, true)

func _finish(play: bool) -> void:
	ClassUnlock.reveal_done(id)
	Save.save_game()
	if play and host:
		HomeHero.pick(host, id)
	closed.emit(play)
	var next := ClassReveal.maybe_show(host)
	queue_free()
	if next:
		next.layer = layer
