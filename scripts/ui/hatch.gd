extends Node3D
## The first screens of a new game, on a floating dais at dusk: one short card after the prologue, then making
## yourself (one of the Empty); then the farm opens and your first Boki hatches there (GardenHatch). The dais
## comes back for your first Relic: the farm portal brings you here while ClassUnlock.needs_starters(), you pick
## Lace, Kael or Vex (HobOffer), the Relic drifts to you and goes on (MaskMoment), and the combat tutorial
## starts (or the farm opens again when you skip it).

const CARD_TEXT := "Every new adventurer starts as one of the Empty, with no face of their own."
const CARD_BUTTON := "Make yourself"
const TUTORIAL_TOGGLE := "Learn to fight first (the combat tutorial)"
const BOKI_FROM := Vector3(1.6, 0.0, 2.2)        # m: where your Boki waits before it trots up to you

const CREATE_CAM := Vector3(0.05, 1.2, 4.75)     # m: the creator's fixed camera, the whole body in frame
const CREATE_LOOK := Vector3(0.2, 0.98, 1.6)

var cam: Camera3D
var fx: Fx
var stage := "intro"          # intro (the card) | create (yourself) | mask (your first Relic)
var card_box: Control
var t := 0.0
var kin_node: Node3D          # your Boki, beside you while the first Relic comes
var tutorial := true          # the first Relic leads into the combat tutorial (off: back to the farm)
var ui: CanvasLayer
var root_ui: Control
var bottom: VBoxContainer
var title: Label
var cam_from := Vector3(0, 3.6, 6.4)
var look: Dictionary = {}
var preview: Node3D
var look_at_t := Vector3(0, 0.25, 0.5)
var edit_only := false        # opened from the menu just to change how you look
var create_box: Control
var sub_lbl: Label
var top_box: VBoxContainer    # the title and its line: centred, or over the preview while you make yourself
var cam_to := Vector3(0, 3.6, 6.4)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play_music("title")
	Sfx.play_ambience("home")
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": Color("1a1440"), "mid": Color("7a3a9a"), "horizon": Color("ffa860"), "below": Color("2a1e4a"),
		"sun_dir": Vector3(0.2, 0.12, -0.97), "sun_col": Color("ffd09a"),
		"ambient": Color("c8cdf0"), "ambient_energy": 0.5, "fog": Color("6a5aa8"), "fog_height": -6.0, "stars": 0.7})
	add_child(env)
	Look.lights(self, Color("ffe2c4"), 1.0, Vector3(-40, -25, 0), 30.0)
	# a warm rim light from behind, so everything on the dais gets a glowing outline
	var rim := DirectionalLight3D.new(); rim.light_color = Color("9ad8ff"); rim.light_energy = 0.55
	rim.rotation_degrees = Vector3(-20, 180, 0); add_child(rim)
	fx = Fx.new(); add_child(fx)
	cam = Camera3D.new(); cam.fov = 40.0; add_child(cam)
	cam.position = cam_from
	cam.look_at(Vector3(0, 0.6, 0))
	_build_set()
	_build_ui()
	cam_from = Vector3(-9, 7.5, 16); cam.position = cam_from
	cam_to = Vector3(-3.5, 4.2, 9.0)
	if not edit_only and not Save.d["roster"].is_empty() and ClassUnlock.needs_starters():
		_first_relic()
	elif edit_only:
		stage = "intro"
		_end_intro()
	elif "--skip-intro" in OS.get_cmdline_user_args() or Save.d["tutorial"].get("intro", false):
		_end_intro()
	else:
		_show_card()

## The set for a new game: a carved stone dais floating at dusk, a rune circle glowing under your
## feet, a broken arch behind with the old world's heart-crystal turning inside it, lanterns and
## banners, rocks drifting round in a slow orbit, wild kin watching from the edges, fireflies,
## a waterfall pouring off into the clouds, and the islands and a skyship far behind.
var orbit: Node3D
var runes: Array = []
var crystal: Node3D
func _build_set() -> void:
	var rr := RandomNumberGenerator.new(); rr.seed = 3
	var stone := Models.toon(Color("d9d2c4"))
	var stone_d := Models.toon(Color("8f8aa0"))
	var gold := Models.toon(Color("f2c46a"), true, 0.4)
	# the floating rock and the dais on top
	var base := Models.float_island(rr, 3.9, 8.0, Color("b9ad96"), Color("8a6f5a"), Color("3a2a4a"))
	base.position.y = -0.32
	add_child(base)
	var dais := Models.part(self, Models.cyl(3.9, 4.1, 0.5, 40), stone, Vector3(0, -0.24, 0))
	dais.name = "Ground"
	Models.part(self, Models.cyl(3.2, 3.2, 0.04, 40), Models.toon(Color("a99c86")), Vector3(0, 0.02, 0))
	for i in 24:
		var a := TAU * i / 24.0
		var bl := Models.part(self, Models.box(0.6, 0.22, 0.3), stone_d if i % 2 == 0 else stone, Vector3(cos(a) * 3.95, 0.06, sin(a) * 3.95))
		bl.rotation.y = -a
	# rune circles: a wide gold one and a smaller cyan one turning the other way
	for spec in [[6.6, Color(1.0, 0.8, 0.4, 0.85), 0.05, 0.25], [4.2, Color(0.55, 0.95, 1.0, 0.7), 0.07, -0.4]]:
		var rn := MeshInstance3D.new(); rn.mesh = Models.flat_quad(float(spec[0]))
		rn.material_override = Models.ring_mat(spec[1], float(spec[2]))
		rn.position.y = 0.05
		rn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rn)
		runes.append([rn, float(spec[3])])
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		var gl := Models.part(self, Models.box(0.12, 0.03, 0.34), Models.glow_mat(Color(1.0, 0.85, 0.5, 0.9)), Vector3(cos(a) * 3.0, 0.05, sin(a) * 3.0))
		gl.rotation.y = -a
	# a waterfall pouring off the edge into the clouds
	var wf := Models.waterfall(1.1, 12.0); wf.position = Vector3(3.3, -0.1, -1.6); wf.rotation.y = -0.9
	add_child(wf)
	# the broken arch behind, and the heart-crystal turning inside it
	var arch_c := Vector3(0, -0.2, -5.2)
	for i in 15:
		if i in [10, 11]:
			continue                       # broken off near the top
		var a := PI * i / 14.0
		var bp := arch_c + Vector3(cos(a) * 4.6, sin(a) * 4.6, 0)
		var blk := Models.part(self, Models.box(0.95, 0.75, 0.9), stone if i % 3 else stone_d, bp)
		blk.rotation.z = a - PI * 0.5
	for k in 3:
		var fr := Models.rock(rr, rr.randf_range(0.25, 0.45), Color("cdbfa6"))
		fr.position = arch_c + Vector3(-2.6 + k * 0.7, 4.6 + k * 0.5, 0.3)
		add_child(fr)
		PropAnim.on(fr, 0.3, 0.25, 0.6 + k * 0.2)
	crystal = Node3D.new(); crystal.position = arch_c + Vector3(0, 2.8, 0); add_child(crystal)
	var cm := Models.toon(Color("8ae8ff"), true, 1.4)
	var pm := Models.crystal(0.6, 2.4, 7)
	cm.set_shader_parameter("gloss", 0.8)
	Models.part(crystal, pm, cm, Vector3(0, 0.6, 0))
	Models.part(crystal, pm, cm, Vector3(0, -0.8, 0), Vector3(1.0, 0.6, 1.0), Vector3(PI, 0, 0))
	for i in 5:
		var a := TAU * i / 5.0
		Models.part(crystal, pm, cm, Vector3(cos(a) * 0.8, -0.2, sin(a) * 0.8), Vector3(0.35, 0.4, 0.35), Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5))
	var cl := OmniLight3D.new(); cl.light_color = Color("8ae8ff"); cl.light_energy = 2.2; cl.omni_range = 9.0; crystal.add_child(cl)
	var beam := Models.part(self, Models.cyl(0.5, 1.4, 30.0, 16), Models.glow_mat(Color(0.55, 0.9, 1.0, 0.16)), arch_c + Vector3(0, 14.0, -0.4))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# lantern posts and banners either side
	for sx in [-1.0, 1.0]:
		var post := Vector3(sx * 3.35, 0, -1.9)
		Models.part(self, Models.cyl(0.16, 0.22, 2.4, 10), stone_d, post + Vector3(0, 1.2, 0))
		Models.part(self, Models.box(0.5, 0.12, 0.5), gold, post + Vector3(0, 2.45, 0))
		var lan := Models.part(self, Models.sphere(0.22, 12), Models.glow_mat(Color(1.0, 0.75, 0.4, 0.95)), post + Vector3(0, 2.75, 0))
		lan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ol := OmniLight3D.new(); ol.light_color = Color("ffb36a"); ol.light_energy = 1.6; ol.omni_range = 5.5
		ol.position = post + Vector3(0, 2.75, 0); add_child(ol)
		var bn := Models.banner(UI.ACCENT if sx < 0 else Color("8ae8ff")); bn.position = post + Vector3(sx * -0.5, 0, 0.35); add_child(bn)
	# rocks drifting round in a slow orbit
	orbit = Node3D.new(); add_child(orbit)
	for k in 12:
		var a := TAU * k / 12.0 + rr.randf_range(-0.2, 0.2)
		var rad := rr.randf_range(7.5, 12.0)
		var rk := Models.rock(rr, rr.randf_range(0.4, 1.3), Color("8fb86a"))
		rk.position = Vector3(cos(a) * rad, rr.randf_range(-3.0, 3.5), sin(a) * rad)
		orbit.add_child(rk)
	# wild kin watching from little rocks at the edges
	for spec in [["zapple", Vector3(-5.6, -0.4, -2.4)], ["wisplet", Vector3(5.9, 0.4, -3.2)], ["pebbit", Vector3(-7.4, 1.2, -6.0)]]:
		var perch := Models.float_island(rr, 0.9, 1.6, Color("7ab85a"), Color("8a6f5a"), Color("3a2a4a"))
		perch.position = spec[1]; add_child(perch)
		PropAnim.on(perch, 0.0, 0.18, 0.5 + rr.randf() * 0.4)
		if Data.KIN.has(spec[0]):
			var wk := Models.kin(spec[0], {"level": 3})
			wk.position = Vector3(0, 0.05, 0); wk.rotation.y = atan2(-(0.0 - (spec[1] as Vector3).x), -(2.0 - (spec[1] as Vector3).z))
			wk.set_meta("happy", true)
			perch.add_child(wk)
	# fireflies over the dais and petals drifting past
	var ff := CPUParticles3D.new()
	ff.amount = 60; ff.lifetime = 5.0; ff.preprocess = 5.0
	ff.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; ff.emission_box_extents = Vector3(7.0, 2.0, 5.0)
	ff.position = Vector3(0, 1.8, -1.0)
	ff.direction = Vector3.UP; ff.spread = 180.0; ff.initial_velocity_min = 0.1; ff.initial_velocity_max = 0.4; ff.gravity = Vector3(0, 0.05, 0)
	var fgr := Gradient.new(); fgr.set_color(0, Color(1, 0.85, 0.4, 0)); fgr.set_color(1, Color(1, 0.85, 0.4, 0)); fgr.add_point(0.5, Color(1, 0.9, 0.5, 1))
	ff.color_ramp = fgr
	var fm := SphereMesh.new(); fm.radius = 0.04; fm.height = 0.08; fm.radial_segments = 6; fm.rings = 3
	var fmat := StandardMaterial3D.new(); fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; fmat.vertex_color_use_as_albedo = true
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; fmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.material = fmat; ff.mesh = fm
	add_child(ff)
	var pt := CPUParticles3D.new()
	pt.amount = 40; pt.lifetime = 7.0; pt.preprocess = 7.0
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; pt.emission_box_extents = Vector3(10.0, 1.0, 6.0)
	pt.position = Vector3(-4.0, 5.0, -2.0)
	pt.direction = Vector3(1, -0.3, 0.2); pt.spread = 25.0; pt.initial_velocity_min = 0.6; pt.initial_velocity_max = 1.2; pt.gravity = Vector3(0, -0.25, 0)
	pt.angular_velocity_min = -90.0; pt.angular_velocity_max = 90.0
	var pq := QuadMesh.new(); pq.size = Vector2(0.09, 0.06)
	var pmat := StandardMaterial3D.new(); pmat.albedo_color = Color("ffb3d0"); pmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pq.material = pmat; pt.mesh = pq
	add_child(pt)
	# the cloud sea, far islands and a skyship passing
	var sea := MeshInstance3D.new()
	var spm := PlaneMesh.new(); spm.size = Vector2(4000, 4000)
	sea.mesh = spm
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/clouds.gdshader")
	sm.set_shader_parameter("deep", Color("221a4e")); sm.set_shader_parameter("light", Color("8f86d4"))
	sm.set_shader_parameter("glow", Color("ffb070")); sm.set_shader_parameter("glow_amount", 0.9)
	sm.set_shader_parameter("sun_xz", Vector2(0.2, -0.97))
	sea.material_override = sm
	sea.position = Vector3(0, -14.0, -20.0)
	add_child(sea)
	for k in 7:
		var isl := Scenery.island(rr, rr.randf_range(3.0, 7.0), true, rr.randf() < 0.5)
		isl.position = Vector3(rr.randf_range(-60, 60), rr.randf_range(-8, 6), rr.randf_range(-70, -30))
		add_child(isl)
	ship = Models.skyship(); ship.position = Vector3(-40, 9, -45); ship.rotation.y = -PI / 2; ship.scale = Vector3.ONE * 1.2
	add_child(ship)
var ship: Node3D

func _build_ui() -> void:
	ui = CanvasLayer.new(); add_child(ui)
	root_ui = Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root_ui)
	# a soft dark vignette pulls the eye to the middle, like a stage
	var vg := TextureRect.new()
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL; gt.fill_from = Vector2(0.5, 0.45); gt.fill_to = Vector2(1.05, 1.05)
	var gg := Gradient.new(); gg.set_color(0, Color(0.05, 0.02, 0.1, 0.0)); gg.set_color(1, Color(0.05, 0.02, 0.1, 0.7)); gg.add_point(0.55, Color(0.05, 0.02, 0.1, 0.0))
	gt.gradient = gg
	vg.texture = gt; vg.stretch_mode = TextureRect.STRETCH_SCALE
	vg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(vg)
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.position.y = 36
	top_box = top
	title = UI.title("Make yourself", 40, UI.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.09, 0.85))
	top.add_child(title)
	var sub := UI.label("", 16, Color(1, 0.95, 0.88, 0.9))
	sub.add_theme_constant_override("outline_size", 6)
	sub.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.09, 0.8))
	sub_lbl = sub
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(sub)
	root_ui.add_child(top)
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	holder.offset_top = -330
	holder.offset_bottom = -14
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN     # a tall card grows up, never off the bottom
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(holder)
	bottom = UI.vbox(10)
	holder.add_child(bottom)

# ---- the card
func _show_card() -> void:
	stage = "intro"
	_clear_bottom()
	title.get_parent().visible = false
	var shade := ColorRect.new(); shade.color = Color(0.02, 0.03, 0.06, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.name = "Shade"
	root_ui.add_child(shade)
	card_box = UI.vbox(22)
	card_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_box.alignment = BoxContainer.ALIGNMENT_CENTER
	card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := UI.title(CARD_TEXT, 30, UI.INK)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = 640
	line.add_theme_constant_override("outline_size", 10)
	line.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.07))
	card_box.add_child(line)
	var go := UI.primary(CARD_BUTTON, _end_intro, 260)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_box.add_child(go)
	root_ui.add_child(card_box)
	Sfx.play("whoosh", null, -16.0)

func _end_intro() -> void:
	if stage != "intro":
		return
	stage = "create"
	Save.d["tutorial"]["intro"] = true
	var shade := root_ui.get_node_or_null("Shade")
	if shade: shade.queue_free()
	if card_box: card_box.queue_free()
	title.get_parent().visible = true
	if edit_only or "--create" in OS.get_cmdline_user_args() or not Save.d.has("look"):
		_show_create()      # a new game starts with making yourself (Settings, Change your look, reopens it)
	else:
		Game.goto("home")   # (made already: your first Boki hatches on the farm, GardenHatch)

var turning := false
func _unhandled_input(event: InputEvent) -> void:
	if stage == "create" and preview:
		# drag with the mouse (or hold A / D) to turn yourself round
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			turning = event.pressed
		elif event is InputEventMouseMotion and turning:
			preview.rotation.y += event.relative.x * 0.012
	elif stage == "intro" and (event.is_action_pressed("jump") or event.is_action_pressed("ui_accept")):
		_end_intro()


func _clear_bottom() -> void:
	for ch in bottom.get_children():
		ch.queue_free()

# ---- yourself: the Empty (Unmasked)
func _show_create() -> void:
	stage = "create"
	if look.is_empty():
		look = Unmasked.clean(Save.d.get("look", {}))
	title.text = "Make yourself"
	_clear_bottom()
	if create_box: create_box.queue_free()
	_rebuild_preview()
	if sub_lbl: sub_lbl.text = "You are one of the Empty. Drag (or hold A / D) to turn round."
	_top_over(0.73)       # over you, clear of the tall creator card on the left
	cam_to = CREATE_CAM          # fixed, so a change of height or build shows as one
	look_at_t = CREATE_LOOK
	var card := UI.card(UI.CARD, 14, 16)
	card.custom_minimum_size = Vector2(500, 0)
	create_box = card
	var v := UI.vbox(8); card.add_child(v)
	for r in Unmasked.ROWS.size():
		var row: Array = Unmasked.ROWS[r]
		if r == 0 or r == Unmasked.HOLLOW_ROW:
			v.add_child(UI.section("Body" if r == 0 else "The hollow"))
		var key: String = row[0]
		var opts: Array = row[2]
		var hr := UI.hbox(8)
		var l := UI.label(row[1], UI.T_BODY, UI.MUTED); l.custom_minimum_size.x = 120
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if row.size() > 3:
			l.tooltip_text = row[3]
			l.mouse_filter = Control.MOUSE_FILTER_STOP
		hr.add_child(l)
		hr.add_child(UI.icon_button("back", func(): _step_look(key, -1, opts.size()), "Previous", 12.0))
		var i := int(look[key])
		if opts[0] is Color:
			var sw := Panel.new(); sw.custom_minimum_size = Vector2(170, 26)
			sw.add_theme_stylebox_override("panel", UI.frame(opts[i], 13, Color(1, 1, 1, 0.25)))
			sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hr.add_child(sw)
		else:
			var val := UI.label(String(opts[i]), UI.T_BODY, UI.INK, UI.semi); val.custom_minimum_size.x = 170
			val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hr.add_child(val)
		hr.add_child(UI.icon_button("next", func(): _step_look(key, 1, opts.size()), "Next", 12.0))
		v.add_child(hr)
	var nr := UI.hbox(8)
	var nl := UI.label("Your name", UI.T_BODY, UI.MUTED); nl.custom_minimum_size.x = 120
	nr.add_child(nl)
	var ne := LineEdit.new(); ne.text = Save.d.get("name", "Hunter"); ne.max_length = 16; ne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ne.text_changed.connect(func(t): Save.d["name"] = t.strip_edges() if t.strip_edges() != "" else "Hunter")
	nr.add_child(ne)
	v.add_child(nr)
	var br := UI.hbox(10)
	br.alignment = BoxContainer.ALIGNMENT_END
	br.add_child(UI.ghost("Random", func():
		look = Unmasked.random_look()
		_show_create(), 120, "swap"))
	br.add_child(UI.primary("Looks good", _looks_good, 200))
	v.add_child(br)
	root_ui.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 48)
	card.offset_top += 46; card.offset_bottom += 46       # clear of the title

func _looks_good() -> void:
	Save.d["look"] = look.duplicate()
	Save.save_game()
	Sfx.play("click")
	Game.goto("home")       # (a new save: the eggs wait on the farm, GardenHatch)


## Centres the title block at this fraction of the window's width.
func _top_over(x_frac: float) -> void:
	if top_box:
		top_box.anchor_left = x_frac
		top_box.anchor_right = x_frac

func _step_look(key: String, d: int, n: int) -> void:
	look[key] = posmod(int(look[key]) + d, n)
	Sfx.play("hover", null, -6.0)
	_show_create()

var preview_yaw := PI
var preview_anim: HunterAnim
func _rebuild_preview() -> void:
	if preview:
		preview_yaw = preview.rotation.y
		preview.queue_free()
	preview = Models.hunter(Data.class_of_save(), Data.TEAM_COLORS[0], "", "", look)      # empty-handed: just you
	preview.get_node("Rig/Torso/Aim/Gun").free()
	preview.position = Vector3(0.8, 0, 1.6)
	preview.rotation.y = preview_yaw
	add_child(preview)
	preview_anim = HunterAnim.new(preview)

func _process(delta: float) -> void:
	t += delta
	if stage != "mask":
		cam.position = cam.position.lerp(cam_to, minf(1.0, delta * 2.0))
		# a slow breathing drift so the shot is never quite still
		cam.position += Vector3(sin(t * 0.37) * 0.004, sin(t * 0.51) * 0.003, 0)
	for rn in runes:
		(rn[0] as Node3D).rotation.y += delta * float(rn[1])
	if orbit: orbit.rotation.y += delta * 0.04
	if crystal:
		crystal.rotation.y += delta * 0.5
		crystal.position.y = -0.2 + 2.8 + sin(t * 1.1) * 0.15
	if ship:
		ship.position.x += delta * 1.6
		if ship.position.x > 60.0: ship.position.x = -60.0
	if stage == "create":
		cam.look_at(look_at_t)
		if preview and not (get_viewport().gui_get_focus_owner() is LineEdit):
			preview.rotation.y += (Input.get_axis("left", "right")) * delta * 2.5
		# the preview stands at ease (breathing, shifting its weight, glancing round); drag it to turn
		# it (see _unhandled_input)
		if preview and preview_anim:
			preview_anim.update(delta, {"fired": 99.0, "face": preview.rotation.y})
	elif stage != "mask":
		cam.look_at(Vector3(0, 0.55, 0.5))

## Through the farm portal with no Relic yet: your Boki comes along, and the pick of three opens.
func _first_relic() -> void:
	if card_box: card_box.queue_free()
	var rec := Save.active_kin()
	kin_node = Models.kin(String(rec["species"]), rec)
	kin_node.position = BOKI_FROM
	add_child(kin_node)
	_mask_moment(func(): _head_out(tutorial))

## Your first Relic: pick one of the three starters (Lace, Kael or Vex; HobOffer), then it drifts to you and you
## put it on in the world (MaskMoment), then `then`. Under the cards, whether the combat tutorial comes next.
func _mask_moment(then: Callable) -> void:
	stage = "mask"
	_clear_bottom()
	top_box.visible = false
	var holder := ColorRect.new()      # (the island dimmed behind the cards)
	holder.color = Color(0.02, 0.01, 0.05, 0.55)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(centre)
	var picked := func(id: String):
		holder.queue_free()
		_put_on_first(id, then)
	var offer := HobOffer.new(ClassUnlock.starters(), FarmBuilder.rules()["talk"], "starter_title",
			func(id): return ClassUnlock.choose_starters([id]), picked)
	var v := UI.vbox(12)
	v.add_child(offer.build())
	var line := UI.label(MaskMoment.TEXT, 17, UI.INK)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(line)
	var tut := CheckBox.new()
	tut.text = TUTORIAL_TOGGLE
	tut.button_pressed = tutorial
	tut.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tut.toggled.connect(func(on: bool): tutorial = on)
	v.add_child(tut)
	centre.add_child(v)
	ui.add_child(holder)

func _put_on_first(first: String, then: Callable) -> void:
	Save.d["arch"] = first
	Save.d["cls"] = Arch.weight(first)
	Save.d["weapon"] = Arch.signature(first)
	Save.save_game()
	var moment := MaskMoment.make(self, cam, kin_node, first)
	moment.finished.connect(then)
	add_child(moment)

func _head_out(fight: bool) -> void:
	if fight:
		Game.start_match({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0})
	else:
		Save.d["tutorial"]["match"] = true
		Save.save_game()
		Game.goto("home")
