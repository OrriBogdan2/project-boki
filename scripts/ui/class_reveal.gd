class_name ClassReveal
extends CanvasLayer
## The reveal moment when a Hunter unlocks (the end of the hold, HoldUnlock): a white flash and a
## shockwave of its colour burst out, the screen dims, the Hunter steps into a ring of light with a
## chime, and says what it is. "Play it" switches your hunter to it (HomeHero.pick), "Later" keeps
## the one you have. Both mark it seen (ClassUnlock.reveal_done), so it never plays twice.
##
##   ClassReveal.show_for(home, id)  # right after a hold
##   ClassReveal.maybe_show(home)    # arriving on the farm: a reveal still queued (older saves), or a
##                                   # toast when an unlock became ready

signal closed(played: bool)

var id := ""
var host: Node
var root: Control
var glow: Control
var t := 0.0
const CLIP := Vector2(200, 112)      # px: each ability clip beside the Hunter

## Shows the reveal for the first waiting Hunter, if any. Returns the overlay (or null). With none
## waiting, a Hunter unlock that became ready since you were last told gets a toast instead.
static func maybe_show(home: Node) -> ClassReveal:
	if home == null or not home.is_inside_tree():
		return null
	if MaskOffer.offer(home):
		return null
	var waiting := ClassUnlock.pending_reveal()
	if waiting.is_empty():
		announce_fresh(home)
		var news := ClassUnlock.take_news()
		if news > 0 and home.has_method("_toast"):
			home._toast("A Relic unlock is ready. Open Relics (%s) and hold to unlock it." % Settings.key_cap("hero"))
			Save.save_game()
		return null
	return show_for(home, String(waiting[0]))

## "Hem and Kael are open now" once the starters have opened (after the first expedition): a toast as soon
## as no panel (the welcome, make-home) covers the farm.
static func announce_fresh(home: Node) -> void:
	if not (ClassUnlock.state().get("fresh", []) as Array).is_empty():
		if home.panel_open != "" or home.building_now or not Save.d["tutorial"].get("home", false):
			home.get_tree().create_timer(1.0).timeout.connect(func():
				if is_instance_valid(home) and home.is_inside_tree(): announce_fresh(home))
			return
		home._toast(ClassUnlock.take_fresh())
		Save.save_game()

## The reveal for one Hunter, over `home`.
static func show_for(home: Node, hunter_id: String) -> ClassReveal:
	var rv := ClassReveal.new()
	rv.id = hunter_id
	rv.host = home
	rv.layer = 60
	home.add_child(rv)
	return rv

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.06, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var col := Arch.color(id)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var v := UI.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	var kick := UI.label("NEW RELIC", UI.T_HEAD, UI.GOLD, UI.caps)
	kick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(kick)
	# the ring of light, with the Hunter standing in it, beside its name and its abilities working
	var row := UI.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(320, 310)
	stage.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stage)
	glow = Control.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.draw.connect(_draw_glow.bind(col))
	stage.add_child(glow)
	var tex := ClassCard.portrait(id, 280.0, true)
	tex.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	tex.offset_left = -140
	tex.offset_right = 140
	tex.offset_top = -140
	tex.offset_bottom = 140
	tex.pivot_offset = Vector2(140, 140)
	tex.scale = Vector2(0.2, 0.2)
	tex.modulate.a = 0.0
	stage.add_child(tex)
	var right := UI.vbox(8)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	var nm := UI.title(HunterViewer.display_name(id), 44, col)
	right.add_child(nm)
	var wl := UI.label(HunterViewer.stat_line(id), UI.T_SMALL, UI.MUTED)
	right.add_child(wl)
	var clips := GridContainer.new()
	clips.columns = 3
	clips.add_theme_constant_override("h_separation", 8)
	clips.add_theme_constant_override("v_separation", 8)
	for slot in HunterViewer.CLIP_SLOTS:
		if slot in HunterViewer.slots_for(id):
			clips.add_child(AbilityClip.make(id, slot, CLIP))
	right.add_child(clips)
	var btns := UI.hbox(12)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_child(UI.ghost("Later", func(): _finish(false), 140))
	var play := UI.primary("Play %s" % Arch.name_of(id, true), func(): _finish(true), 220)
	btns.add_child(play)
	v.add_child(btns)
	root.set_meta("class_id", id)
	# the moment: the burst, a chime, the Hunter pops into the ring, text eases in
	Sfx.play("unlock", null, -4.0, 0.0, 1.0)
	Sfx.play("whoosh", null, -9.0, 0.0, 0.8)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(tex, "modulate:a", 1.0, 0.25)
	tw.tween_property(tex, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for c in [kick, right, btns]:
		(c as Control).modulate.a = 0.0
		tw.tween_property(c, "modulate:a", 1.0, 0.4).set_delay(0.35)
	play.call_deferred("grab_focus")

func _process(dt: float) -> void:
	t += dt
	if glow:
		glow.queue_redraw()

## Soft rings and slow rays in the Hunter's colour behind the portrait; first the burst (a white flash
## and three shockwave rings racing out).
func _draw_glow(col: Color) -> void:
	var c := glow.size * 0.5
	if t < 0.9:
		var bk := clampf(t / 0.8, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - bk, 3.0)
		glow.draw_circle(c, 40.0 + 260.0 * e, Color(1, 1, 1, 0.5 * maxf(0.0, 1.0 - t / 0.3)))
		for i in 3:
			var kk := clampf(e - 0.14 * i, 0.0, 1.0)
			glow.draw_arc(c, 30.0 + 420.0 * kk, 0, TAU, 80, Color(col.lightened(0.3), 0.9 * (1.0 - kk)),
					7.0 - 2.0 * i, true)
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
