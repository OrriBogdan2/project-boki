class_name KinReveal
extends CanvasLayer
## A closer look right after an egg hatches, shared by the first egg and nest eggs. The world
## behind dims a little, the Boki sits in a pool of warm light, glancing about; then it turns,
## looks right at you, blinks and calls to you in its own voice. After that you can turn it round
## (drag it, or A/D, the arrow keys or the right stick) and read its card. "Name it" closes this
## and hands over to whatever naming step the caller has.
##
## Intimate and grounded on purpose (docs/POSITIONING.md): no flash, fanfare, light rays, star
## bursts or rarity colours. A shimmer shows in the Boki's own coat (and a faint sparkle in it);
## where a rare one came from is a line of provenance on the card.
##
##   var rv := KinReveal.new(species_id, rec)     # rec: the kin's save record ({} for a starter)
##   add_child(rv); rv.proceed.connect(func(): _show_name())

signal proceed

const RATE := 22050

var species := "cindle"
var rec: Dictionary = {}
var sp: Dictionary = {}
var col := Color.WHITE
var glow := Color.WHITE

var root: Control
var bg: ColorRect
var pool: Control            # the warm light it sits in (drawn behind the 3D view)
var vp: SubViewport
var vpc: SubViewportContainer
var turn: Node3D             # the turntable the kin sits on (rotate this)
var kin: Node3D
var title_lbl: Label
var sub_lbl: Label
var info: PanelContainer
var name_btn: Button
var hint: Label

var t := 0.0
var spin_v := 0.0            # turntable speed from input (rad/s)
var dragging := false
var ready_to_name := false
var met := false             # it has looked at you (the imprint moment is done)
var moves: BokiMoves = null   # the move tiles on the card (hover or focus one for its tip)
var rare := false            # hatched from a boss's Rare Egg (said on the card, never shouted)
var moment: Tween

func _init(sp_id: String, kin_rec := {}) -> void:
	species = sp_id if Data.KIN.has(sp_id) else String(Data.KIN.keys()[0])
	rec = kin_rec
	layer = 60

func _ready() -> void:
	sp = Data.KIN[species]
	col = Shiny.col(species, rec, "color")
	glow = Shiny.col(species, rec, "glow") if sp.has("glow") or rec.get("shimmer", false) else col
	rare = bool(rec.get("rare", false)) or Data.is_rare(species)
	_build()
	_play_intro()

# ------------------------------------------------------------------ layout
func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	# the world behind stays there, just dimmed: this is a closer look, not another place
	bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.025, 0.03, 0.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	pool = Control.new()
	pool.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pool.modulate.a = 0.0
	pool.draw.connect(_draw_pool)
	root.add_child(pool)
	# the kin, in a little 3D world of its own drawn over the dimmed scene
	vpc = SubViewportContainer.new()
	vpc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vpc.stretch = true
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vpc.modulate.a = 0.0
	root.add_child(vpc)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vpc.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("cfc8d8")
	e.ambient_light_energy = 0.55
	# the same filmic colour as the outdoor scenes, so the kin looks as it does in the world
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.05
	e.tonemap_white = 6.0
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.05
	e.adjustment_saturation = 1.0
	env.environment = e
	vp.add_child(env)
	# a warm, low key light (a lantern's) and a soft cool rim from behind
	var key := DirectionalLight3D.new(); key.rotation = Vector3(-0.55, 0.7, 0); key.light_energy = 1.15
	key.light_color = Color("ffe2c0")
	key.shadow_enabled = true; key.shadow_opacity = 0.55; key.shadow_blur = 2.0
	key.directional_shadow_max_distance = 8.0
	vp.add_child(key)
	var back := DirectionalLight3D.new(); back.rotation = Vector3(-0.3, PI, 0); back.light_energy = 0.45
	back.light_color = Color("b8c4e8")
	vp.add_child(back)
	var cam := Camera3D.new()
	cam.fov = 32.0
	# aimed to the kin's right, so the kin sits left of centre and the card fits on the right; a
	# little low, at the height of someone kneeling to meet it
	cam.position = Vector3(0.62, 0.82, 3.9)
	vp.add_child(cam)
	cam.look_at(Vector3(0.62, 0.36, 0))
	turn = Node3D.new()
	vp.add_child(turn)
	# it sits in the straw of a nest, not on a stage
	var nest := Models.nest()
	for ch in nest.get_children():
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh is SphereMesh:
			ch.visible = false
	nest.scale = Vector3.ONE * 0.62        # a nest it fits in, not a stage it sits on
	turn.add_child(nest)
	kin = Models.kin(species, rec)
	kin.rotation.y = PI + 0.9      # glancing off to one side, until it notices you
	kin.position.y = 0.06
	turn.add_child(kin)
	var pt: CPUParticles3D = kin.get_node_or_null("Aura")
	if pt: pt.emitting = true
	if rec.get("shimmer", false):
		kin.add_child(_fur_sparkle())
	# titles: quiet, set small
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.offset_top = 40
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	title_lbl = UI.title("", 34, UI.INK)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.05, 0.8))
	title_lbl.add_theme_constant_override("outline_size", 6)
	top.add_child(title_lbl)
	sub_lbl = UI.label("", 16, UI.MUTED)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(sub_lbl)
	title_lbl.modulate.a = 0.0
	sub_lbl.modulate.a = 0.0
	# the info card on the right
	info = _info_card()
	info.modulate.a = 0.0
	root.add_child(info)
	_place_card.call_deferred()      # once in the tree, so it is sized from its real fonts
	# the hint under the kin
	hint = UI.label("Drag to turn it round  ·  A / D", 15, UI.MUTED)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_bottom = -40
	hint.offset_top = -64
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate.a = 0.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

## A shimmer: a few faint motes that catch the light in its coat, close to the body.
func _fur_sparkle() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "FurSparkle"
	p.amount = 6
	p.lifetime = 1.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.position = Vector3(0, 0.38, 0)
	p.gravity = Vector3(0, 0.05, 0)
	p.initial_velocity_min = 0.0; p.initial_velocity_max = 0.05
	p.scale_amount_min = 0.5; p.scale_amount_max = 1.0
	var q := QuadMesh.new(); q.size = Vector2(0.025, 0.025)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p.material_override = m
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0)); g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(glow.lightened(0.6), 0.55))
	p.color_ramp = g
	return p

## The card hugs the middle of the right edge at its own height.
func _place_card() -> void:
	info.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE)
	info.offset_right = -48
	info.offset_left = -48 - 400
	info.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info.grow_vertical = Control.GROW_DIRECTION_BOTH

func _info_card() -> PanelContainer:
	var card := PanelContainer.new()       # the theme's torn void panel with the neon edge
	card.custom_minimum_size = Vector2(400, 0)
	var v := UI.vbox(8); card.add_child(v)
	var head := UI.hbox(10)
	var nm := UI.title(String(sp["name"]), 30, UI.DARK_INK)
	nm.add_theme_stylebox_override("normal", UI.title_tab())
	nm.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	head.add_child(nm)
	head.add_child(UI.fill())
	head.add_child(UI.tag(String(sp.get("type", "")), _bright(col)))
	v.add_child(head)
	# one line on what it is, then who this one is: the Boki itself leads, its moves are tiles (item 82)
	var desc := String(sp.get("desc", "")).get_slice(". ", 0).trim_suffix(".")
	if desc != "":
		v.add_child(_note(desc + "."))
	if rare:
		var boss := String(Data.MOBS.get(String(sp.get("boss", rec.get("from_boss", ""))), {}).get("name", "a lair boss"))
		v.add_child(_note("Its egg was guarded by %s. Few of its kind are ever seen." % boss))
	if rec.get("shimmer", false):
		v.add_child(_note("Its coat came out in rare colours (about %s)." % Shiny.odds_text(Shiny.WILD)))
	for mid in Mutations.of(rec):
		v.add_child(_note("%s: %s" % [Mutations.name_of(mid), Mutations.perk_text(mid)]))
	if rec.has("parents"):
		v.add_child(UI.label("Child of %s and %s" % [rec["parents"][0], rec["parents"][1]], 14, UI.MUTED))
	var who := UI.hbox(8)
	if Unique.sex(rec) != "":
		who.add_child(UI.sex_icon(rec, 15.0))
		who.add_child(UI.label(Unique.sex_name(rec), 15, UI.SEX_COL[Unique.sex(rec)], UI.semi))
	var bits := PackedStringArray()
	if rec.has("traits"):
		bits.append("%s nature" % Care.nature(rec))
	if not Unique.of(rec).is_empty():
		bits.append(String(AboutView.HABIT_SHORT.get(String(Unique.of(rec).get("quirk", "")), Unique.quirk_name(rec))).to_lower())
	if not bits.is_empty():
		who.add_child(UI.label(("·  " if who.get_child_count() > 0 else "") + "  ·  ".join(bits), 15, UI.INK))
	if who.get_child_count() > 0:
		v.add_child(who)
	moves = BokiMoves.new(species, rec)
	if not moves.tiles.is_empty():
		v.add_child(UI.spacer(2))
		v.add_child(UI.section("Moves  ·  hover one"))
		v.add_child(moves)
	v.add_child(UI.spacer(6))
	name_btn = UI.primary("Name it", _go, 360)
	name_btn.disabled = true
	v.add_child(name_btn)
	return card

func _note(text: String) -> Label:
	var l := UI.label(text, 14, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 360
	return l

## The kin's colour, lifted until it reads on a dark card.
func _bright(c: Color) -> Color:
	var out := c
	while out.get_luminance() < 0.55:
		out = out.lerp(Color.WHITE, 0.2)
	return out

func _stat(name: String, val: float, top: float) -> HBoxContainer:
	var h := UI.hbox(10)
	var l := UI.label(name, 14, UI.MUTED); l.custom_minimum_size.x = 70
	h.add_child(l)
	var b := UI.bar(clampf(val / top, 0.05, 1.0), Color("cfc6b8"), 230.0, 10.0)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	h.add_child(UI.label(str(snappedf(val, 0.1)).trim_suffix(".0"), 14, UI.INK))
	return h

# ------------------------------------------------------------------ the moment
## The dim comes up, it glances about, then finds you: turns, looks up, blinks, calls. Only then
## does its card slide in.
func _play_intro() -> void:
	var ft := create_tween().set_parallel(true)
	ft.tween_property(bg, "color:a", 0.62, 0.6).set_trans(Tween.TRANS_SINE)
	ft.tween_property(pool, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	ft.tween_property(vpc, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	var body := kin.get_node_or_null("Body") as Node3D
	moment = create_tween()
	moment.tween_interval(0.7)
	moment.tween_property(kin, "rotation:y", PI - 0.7, 0.8).set_trans(Tween.TRANS_SINE)
	moment.tween_interval(0.4)
	moment.tween_callback(_blink)
	moment.tween_interval(0.35)
	# it finds you
	moment.tween_property(kin, "rotation:y", PI, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if body:
		moment.tween_property(body, "rotation:x", 0.22, 0.3).set_trans(Tween.TRANS_SINE)
	moment.tween_interval(0.25)
	moment.tween_callback(_blink)
	moment.tween_interval(0.3)
	moment.tween_callback(func():
		_play(_cry())
		title_lbl.text = String(sp["name"])
		sub_lbl.text = "It's looking at you. It knows your face now."
		var tt := create_tween().set_parallel(true)
		tt.tween_property(title_lbl, "modulate:a", 1.0, 0.5)
		tt.tween_property(sub_lbl, "modulate:a", 1.0, 0.7).set_delay(0.2))
	moment.tween_interval(0.8)
	if body:
		moment.tween_property(body, "rotation:x", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	moment.tween_callback(func():
		met = true
		info.position.x += 30
		var it := create_tween().set_parallel(true)
		it.tween_property(info, "modulate:a", 1.0, 0.4)
		it.tween_property(info, "position:x", info.position.x - 30, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		create_tween().tween_property(hint, "modulate:a", 1.0, 0.5)
		ready_to_name = true
		name_btn.disabled = false
		name_btn.grab_focus())

func _blink() -> void:
	for ch in kin.get_children():
		if ch is KinPuppet:
			(ch as KinPuppet).blink_t = 0.0

func _a_an(w: String) -> String:
	return "an" if w.length() > 0 and w[0].to_lower() in "aeiou" else "a"

func _centre() -> Vector2:
	var sz := root.size if root and root.size.x > 1.0 else Vector2(1280, 720)
	return Vector2(sz.x * 0.36, sz.y * 0.56)

func _go() -> void:
	if not ready_to_name:
		return
	ready_to_name = false
	Sfx.play("click")
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		proceed.emit()
		queue_free())

# ------------------------------------------------------------------ per frame
func _process(dt: float) -> void:
	t += dt
	# turning it round: keys and right stick (once it has met you)
	var ax := Input.get_axis("left", "right") if not (get_viewport().gui_get_focus_owner() is LineEdit) else 0.0
	var stick := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X) if Input.get_connected_joypads().size() > 0 else 0.0
	if absf(stick) < 0.2: stick = 0.0
	var input := ax + stick
	if met and absf(input) > 0.05:
		spin_v = lerpf(spin_v, input * 2.6, minf(1.0, dt * 10.0))
	elif not dragging:
		spin_v = lerpf(spin_v, 0.0, minf(1.0, dt * 3.0))
	if not dragging:
		turn.rotation.y += spin_v * dt
	pool.queue_redraw()

func _input(ev: InputEvent) -> void:
	if not met:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed and not info.get_global_rect().has_point(ev.position):
			dragging = true
			spin_v = 0.0
		elif not ev.pressed:
			dragging = false
	elif ev is InputEventMouseMotion and dragging:
		var d: float = ev.relative.x * 0.012
		turn.rotation.y += d
		spin_v = d / maxf(get_process_delta_time(), 0.001) * 0.5      # a little fling when let go
	elif ev is InputEventScreenDrag:
		turn.rotation.y += ev.relative.x * 0.012
	elif ready_to_name and (ev.is_action_pressed("ui_accept")) and not (get_viewport().gui_get_focus_owner() is LineEdit):
		get_viewport().set_input_as_handled()
		_go()

## A soft pool of warm light on the ground where it sits, breathing very slightly.
func _draw_pool() -> void:
	var c := _centre() + Vector2(0, 40)
	var br := 0.94 + 0.06 * sin(t * 0.9)
	for i in 7:
		var r := lerpf(330.0, 70.0, i / 6.0) * br
		pool.draw_set_transform(c, 0.0, Vector2(1.0, 0.42))
		pool.draw_circle(Vector2.ZERO, r, Color(1.0, 0.78, 0.55, 0.035 + 0.006 * i))
	pool.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ------------------------------------------------------------------ sound (made here, no files)
func _play(s: AudioStreamWAV) -> void:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = s
	p.volume_db = -8.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

## The kin's own little cry: two chirpy syllables, pitched and shaped by its species.
func _cry() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new(); rng.seed = species.hash() * 7 + 3
	var base := lerpf(300.0, 820.0, rng.randf())
	var spd := float(sp.get("speed", 6.5))
	base *= clampf(spd / 6.5, 0.75, 1.3)
	base *= Unique.voice(rec)       # its own voice, a little higher or deeper than its kind's
	var dur := 0.62
	var buf := PackedFloat32Array(); buf.resize(int(dur * RATE))
	var syl := [[0.0, 0.2, 1.0, 1.45], [0.25, 0.34, 1.3, 0.9]]   # start, length, pitch from, pitch to
	var ph := 0.0
	for sy in syl:
		var s0 := int(float(sy[0]) * RATE)
		var len := int(float(sy[1]) * RATE)
		ph = 0.0
		for i in len:
			var k := float(i) / len
			var f := base * lerpf(float(sy[2]), float(sy[3]), k * k * (3.0 - 2.0 * k))
			f *= 1.0 + sin(TAU * 22.0 * k * float(sy[1])) * 0.04
			ph += TAU * f / RATE
			var env := sin(PI * minf(1.0, k * 1.15)) * (1.0 - k * 0.3)
			var v := sin(ph) * 0.7 + sin(ph * 2.0) * 0.22 + sin(ph * 3.0) * 0.08
			var j := s0 + i
			if j < buf.size(): buf[j] += v * env * 0.4
	return _wav(buf)

func _wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray(); data.resize(buf.size() * 2)
	for i in buf.size():
		var s := int(clampf(tanh(buf[i] * 1.2), -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
