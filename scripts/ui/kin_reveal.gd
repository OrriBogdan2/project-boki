class_name KinReveal
extends CanvasLayer
## A closer look right after an egg hatches, shared by the first egg and nest eggs. The world
## behind dims under a painted vignette and the Boki appears in the cracked void window of a big
## torn card (UI_STYLE.md on ext/agent-briefs), glancing about; then it turns, looks right at you,
## blinks and calls to you in its own voice. After that its name banner, its moves on parchment
## strips and the stamps come up, and you can turn it round (drag it, or A/D, the arrow keys or
## the right stick). "Name it" closes this and hands over to whatever naming step the caller has.
##
## Intimate and grounded on purpose (docs/POSITIONING.md): no flash, fanfare, light rays, star
## bursts or rarity colours. A shimmer shows in the Boki's own coat (and a faint sparkle in it);
## where a rare one came from is a line of provenance on the card.
##
##   var rv := KinReveal.new(species_id, rec)     # rec: the kin's save record ({} for a starter)
##   add_child(rv); rv.proceed.connect(func(): _show_name())

signal proceed

const RATE := 22050
const WINDOW := Vector2(290, 370)      # px, the void window the Boki sits in
const CARD_W := 900.0                  # px, the whole card
const RUST := Color("d8613c")          # the LOGGED stamp
const VIOLET := Color("b48cff")        # the VOID-TOUCHED stamp

var species := "cindle"
var rec: Dictionary = {}
var sp: Dictionary = {}
var col := Color.WHITE
var glow := Color.WHITE

var root: Control
var bg: ColorRect
var vp: SubViewport
var vpc: SubViewportContainer
var window: VoidPortrait     # the cracked void window around the 3D view
var turn: Node3D             # the turntable the kin sits on (rotate this)
var kin: Node3D
var title_lbl: Label         # its name on the parchment banner
var sub_lbl: Label
var info: PanelContainer     # the card
var words: VBoxContainer     # the card's right column: the banner, the notes, the moves
var name_btn: Button
var hint: Label

var t := 0.0
var spin_v := 0.0            # turntable speed from input (rad/s)
var dragging := false
var ready_to_name := false
var met := false             # it has looked at you (the imprint moment is done)
var moves: BokiMoves = null   # the move strips on the card (hover or focus one for its tip)
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
	# the world behind stays there, dimmed under the void: this is a closer look, not another place
	bg = UI.backdrop()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	_build_view()
	info = _card()
	info.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	info.grow_horizontal = Control.GROW_DIRECTION_BOTH
	info.grow_vertical = Control.GROW_DIRECTION_BOTH
	info.modulate.a = 0.0
	root.add_child(info)

## The kin in a little 3D world of its own, drawn inside the void window.
func _build_view() -> void:
	vpc = SubViewportContainer.new()
	vpc.stretch = true
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.55, 0.7, 0)
	key.light_energy = 1.15
	key.light_color = Color("ffe2c0")
	key.shadow_enabled = true
	key.shadow_opacity = 0.55
	key.shadow_blur = 2.0
	key.directional_shadow_max_distance = 8.0
	vp.add_child(key)
	var back := DirectionalLight3D.new()
	back.rotation = Vector3(-0.3, PI, 0)
	back.light_energy = 0.45
	back.light_color = Color("b8c4e8")
	vp.add_child(back)
	var cam := Camera3D.new()
	cam.fov = 30.0
	# a little low, at the height of someone kneeling to meet it, the kin filling the window
	cam.position = Vector3(0.0, 0.7, 3.2)
	cam.basis = Basis.looking_at(Vector3(0.0, 0.42, 0) - cam.position)
	vp.add_child(cam)
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
	if pt:
		pt.emitting = true
	if rec.get("shimmer", false):
		kin.add_child(_fur_sparkle())
	window = VoidPortrait.window(vpc, WINDOW)

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
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.05
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.025)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p.material_override = m
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(glow.lightened(0.6), 0.55))
	p.color_ramp = g
	return p

## The card: the void window on the left, the name banner, the notes and the move strips on the
## right, the stamps in the corners and the ticket button hanging off the bottom edge.
func _card() -> PanelContainer:
	var card := PanelContainer.new()       # the theme's torn void panel with the neon edge
	card.custom_minimum_size = Vector2(CARD_W, 0)
	var v := UI.vbox(10)
	card.add_child(v)
	var cols := UI.hbox(28)
	v.add_child(cols)
	var left := UI.vbox(8)
	left.add_child(window)
	hint = UI.label("Drag to turn it round  ·  A / D", 13, UI.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate.a = 0.0
	left.add_child(hint)
	cols.add_child(left)
	words = UI.vbox(10)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(words)
	title_lbl = UI.banner(String(sp["name"]).to_upper(), 40, -2.5)
	title_lbl.modulate.a = 0.0
	words.add_child(title_lbl)
	sub_lbl = UI.label("", UI.T_SMALL, UI.MUTED)
	sub_lbl.modulate.a = 0.0
	words.add_child(sub_lbl)
	_notes(words)
	moves = BokiMoves.new(species, rec, true)
	moves.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(moves)
	words.add_child(UI.fill())
	var foot := UI.hbox(10)
	foot.add_child(UI.stamp("Logged", RUST, 20, -7.0))
	foot.add_child(UI.fill())
	name_btn = UI.primary("Name it", _go, 300)
	name_btn.disabled = true
	foot.add_child(name_btn)
	foot.add_child(UI.fill())
	if rare:
		foot.add_child(UI.stamp("Void-touched", VIOLET, 20, 6.0))
	elif rec.get("shimmer", false):
		foot.add_child(UI.stamp("Shimmer", VIOLET, 20, 6.0))
	v.add_child(foot)
	return card

## One line on what it is, who this one is, and where it came from: the Boki itself leads.
func _notes(v: VBoxContainer) -> void:
	var desc := String(sp.get("desc", "")).get_slice(". ", 0).trim_suffix(".")
	if desc != "":
		v.add_child(_note(desc + ".", UI.T_BODY))
	var who := UI.hbox(8)
	if Unique.sex(rec) != "":
		who.add_child(UI.sex_icon(rec, 16.0))
		who.add_child(UI.label(Unique.sex_name(rec), UI.T_BODY, UI.SEX_COL[Unique.sex(rec)], UI.semi))
	var bits := PackedStringArray()
	if rec.has("traits"):
		bits.append("%s nature" % Care.nature(rec))
	if not Unique.of(rec).is_empty():
		var quirk := String(Unique.of(rec).get("quirk", ""))
		bits.append(String(AboutView.HABIT_SHORT.get(quirk, Unique.quirk_name(rec))).to_lower())
	if not bits.is_empty():
		var lead := "·  " if who.get_child_count() > 0 else ""
		who.add_child(UI.label(lead + "  ·  ".join(bits), UI.T_BODY, UI.INK))
	if who.get_child_count() > 0:
		v.add_child(who)
	if rare:
		var boss_id := String(sp.get("boss", rec.get("from_boss", "")))
		var boss := String(Data.MOBS.get(boss_id, {}).get("name", "a lair boss"))
		v.add_child(_note("Its egg was guarded by %s. Few of its kind are ever seen." % boss))
	if rec.get("shimmer", false):
		v.add_child(_note("Its coat came out in rare colours (about %s)." % Shiny.odds_text(Shiny.WILD)))
	for mid in Mutations.of(rec):
		v.add_child(_note("%s: %s" % [Mutations.name_of(mid), Mutations.perk_text(mid)]))
	if rec.has("parents"):
		v.add_child(UI.label("Child of %s and %s" % [rec["parents"][0], rec["parents"][1]], UI.T_SMALL, UI.MUTED))

func _note(text: String, px := UI.T_SMALL) -> Label:
	var l := UI.label(text, px, UI.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

# ------------------------------------------------------------------ the moment
## The dim and the card come up, it glances about, then finds you: turns, looks up, blinks, calls.
## Only then do its name, its moves and the button come up.
func _play_intro() -> void:
	UI.show_backdrop(bg, true)
	create_tween().tween_property(info, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
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
		sub_lbl.text = "It's looking at you. It knows your face now."
		var tt := create_tween().set_parallel(true)
		tt.tween_property(title_lbl, "modulate:a", 1.0, 0.5)
		tt.tween_property(sub_lbl, "modulate:a", 1.0, 0.7).set_delay(0.2))
	moment.tween_interval(0.8)
	if body:
		moment.tween_property(body, "rotation:x", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	moment.tween_callback(func():
		met = true
		create_tween().tween_property(hint, "modulate:a", 1.0, 0.5)
		ready_to_name = true
		name_btn.disabled = false
		name_btn.grab_focus())

func _blink() -> void:
	for ch in kin.get_children():
		if ch is KinPuppet:
			(ch as KinPuppet).blink_t = 0.0

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
	var typing := get_viewport().gui_get_focus_owner() is LineEdit
	var ax := Input.get_axis("left", "right") if not typing else 0.0
	var stick := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X) if Input.get_connected_joypads().size() > 0 else 0.0
	if absf(stick) < 0.2:
		stick = 0.0
	var input := ax + stick
	if met and absf(input) > 0.05:
		spin_v = lerpf(spin_v, input * 2.6, minf(1.0, dt * 10.0))
	elif not dragging:
		spin_v = lerpf(spin_v, 0.0, minf(1.0, dt * 3.0))
	if not dragging:
		turn.rotation.y += spin_v * dt

func _input(ev: InputEvent) -> void:
	if not met:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed and window.get_global_rect().has_point(ev.position):
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
	elif ready_to_name and ev.is_action_pressed("ui_accept") and not (get_viewport().gui_get_focus_owner() is LineEdit):
		get_viewport().set_input_as_handled()
		_go()

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
