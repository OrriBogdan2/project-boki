class_name LookLocker
extends Node3D
## Making yourself (the Empty, Unmasked) in a locker: your model on a lit turntable (a key light, a rim
## light in your glow's colour, a shadow under your feet, the set behind softly out of focus), four tabs
## with their own camera shot (Body, Hollow, Shroud, Glider), every choice as a tile or a swatch you can
## hover to try on, a pop when you pick one, and gliders in their rarity colours. Drag (or A / D) turns the
## turntable, the wheel zooms. The hatch screen opens it (a new game, or Change your look) and saves the
## locker's look on `finished`.
##
##   var locker := LookLocker.open(self, root_ui, cam, fx, look)
##   locker.finished.connect(func(): save(locker.look))

signal finished

const TABS := ["Body", "Hollow", "Shroud", "Glider"]
const TAB_ICONS := {"Body": "ruler", "Hollow": "eye", "Shroud": "cloak", "Glider": "updraft"}
## The look keys each tab shows, in order (the rows come from Unmasked.ROWS and Shrouds.ROWS; "accent" is the
## trim's colour, "Match" first). The Glider tab lists Gliders.LIST instead.
const TAB_KEYS := {"Body": ["gender", "height", "build"], "Hollow": ["hollow", "glow", "ghost", "aura"],
	"Shroud": ["shroud", "colour", "accent", "hood", "trim", "accessory"]}
const AT := Vector3(0.8, 0, 1.6)            # m: the turntable's centre on the hatch dais
const TOP := 0.07                           # m: the turntable's top, where your feet stand
## Each tab's shot, from the turntable's centre: [camera, the point it looks at] (m). The look point sits left
## of you so you stand right of the panel; Hollow is a close-up of the head, Glider pulls back to the canopy.
const SHOTS := {"Body": [Vector3(-0.75, 1.2, 3.15), Vector3(-0.6, 0.98, 0)],
	"Hollow": [Vector3(-0.4, 1.6, 1.7), Vector3(-0.3, 1.45, 0)],
	"Shroud": [Vector3(-0.62, 1.12, 2.45), Vector3(-0.48, 0.86, 0)],
	"Glider": [Vector3(-1.05, 1.75, 4.3), Vector3(-0.85, 1.75, 0)]}
const CAM_EASE := 5.0                       # 1/s: how fast the camera settles on a new shot or zoom
const ZOOM_MIN := 0.6                       # x the shot's distance, wheel in
const ZOOM_MAX := 1.35                      # ... wheel out
const ZOOM_STEP := 0.08                     # per wheel notch
const DRAG_TURN := 0.012                    # rad per pixel dragged
const KEY_TURN := 2.5                       # rad/s while A / D is held
const SPIN_DECAY := 6.0                     # 1/s: how fast a flicked turntable slows to a stop
const GLIDE_LIFT := 0.35                    # m: you hang this high over the turntable under an open glider
const GLIDER_TILT := 0.25                   # rad: the open canopy leans back over you, as in flight
const TRY_SETTLE := 0.06                    # s: a hovered choice rebuilds the model at most this often
const POP_SCALE := 1.07                     # x your size at the top of the pick pop
const PANEL_W := 540.0
const LIST_H := 420.0                       # px: the choices scroll past this height
const TILE := Vector2(156, 40)              # px: a named choice
const SWATCH := 34.0                        # px: a colour choice

var look: Dictionary = {}
var tab := "Body"
var model: Node3D
var _anim: HunterAnim
var _cam: Camera3D
var _fx: Fx
var _turn: Node3D                           # the turntable and you on it (drag turns this)
var _ring_mat: StandardMaterial3D
var _rim: SpotLight3D
var _halo_mat: StandardMaterial3D
var _panel: Control
var _tabs: Control
var _list: VBoxContainer
var _look_at := Vector3.ZERO
var _zoom := 1.0
var _spin := 0.0                            # rad/s left from a flick
var _dragging := false
var _trial: Dictionary = {}                 # the look being tried on (hovered), {} when none
var _shown := 0                             # hash of the look the model was built from
var _settle := 0.0

static func open(host: Node3D, ui_root: Control, cam: Camera3D, fx: Fx, start: Dictionary) -> LookLocker:
	var lk := LookLocker.new()
	lk.look = start.duplicate(true)
	lk._cam = cam
	lk._fx = fx
	host.add_child(lk)
	lk._build_stage()
	lk._build_panel(ui_root)
	lk._rebuild_model(lk.look)
	lk._look_at = AT + SHOTS["Body"][1]
	return lk

## Ends the locker: the stage, the panel and the camera's soft focus go.
func close() -> void:
	set_process(false)
	_cam.attributes = null
	if _panel:
		_panel.queue_free()
	queue_free()

## Shows these choices on the model and the panel (Random, the shot tools).
func set_look(lk: Dictionary) -> void:
	look = lk.duplicate(true)
	_trial = {}
	_rebuild_model(look)
	_fill()

## Opens a tab: its choices, and the camera moves to its shot.
func show_tab(t: String) -> void:
	tab = t
	_zoom = 1.0
	_trial = {}
	var old := _tabs
	_tabs = _tab_row()
	old.replace_by(_tabs)
	old.queue_free()
	_dress_for_tab()
	_fill()

## Picks a choice: the look takes it, the model pops and the turntable flashes.
func pick(key: String, value: Variant) -> void:
	if key == "glider":
		if not Gliders.equip(String(value)):
			return
	look[key] = value
	_trial = {}
	_rebuild_model(look)
	_fill()
	_pop()

## The turntable's turn (rad); the shot tools set it.
func set_yaw(yaw: float) -> void:
	_turn.rotation.y = yaw
	_spin = 0.0

# ---- the stage

func _build_stage() -> void:
	_turn = Node3D.new()
	_turn.position = AT
	_turn.rotation.y = PI
	add_child(_turn)
	var plinth := MeshInstance3D.new()
	plinth.mesh = LookProps.mesh("dais")
	plinth.material_override = LookProps.mat("dais")
	plinth.position.y = TOP
	_turn.add_child(plinth)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 0.86
	ring.mesh = torus
	_ring_mat = _glow_mat(Color.WHITE)
	ring.material_override = _ring_mat
	ring.position.y = TOP
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_turn.add_child(ring)
	_turn.add_child(_soft_disc(Vector3(0, TOP + 0.004, 0), 1.3, Color(0, 0, 0, 0.6), true))
	# the light: a warm key from the front left that casts your shadow, a rim from behind in your glow's colour,
	# a cool fill low in front, and a halo on the set behind you
	add_child(_spot(AT + Vector3(-1.7, 3.3, 2.4), Color("ffe6cc"), 3.2, true))
	_rim = _spot(AT + Vector3(0.9, 2.7, -2.3), Color.WHITE, 5.0, false)
	add_child(_rim)
	var fill := OmniLight3D.new()
	fill.light_color = Color("a8b8ff")
	fill.light_energy = 0.45
	fill.omni_range = 4.0
	fill.position = AT + Vector3(0.6, 0.5, 1.8)
	add_child(fill)
	var halo := _soft_disc(AT + Vector3(0.2, 1.3, -1.7), 4.2, Color.WHITE, false)
	_halo_mat = halo.material_override
	add_child(halo)
	var dof := CameraAttributesPractical.new()
	dof.dof_blur_far_enabled = true
	dof.dof_blur_far_transition = 5.0
	dof.dof_blur_amount = 0.07
	_cam.attributes = dof

func _spot(at: Vector3, col: Color, energy: float, shadow: bool) -> SpotLight3D:
	var s := SpotLight3D.new()
	s.light_color = col
	s.light_energy = energy
	s.spot_range = 9.0
	s.spot_angle = 26.0
	s.shadow_enabled = shadow
	s.position = at
	s.look_at_from_position(at, AT + Vector3(0, 1.0, 0))
	return s

func _glow_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	return m

## A round soft spot: lying flat (the shadow under your feet) or standing up facing the camera (the halo).
func _soft_disc(at: Vector3, width: float, col: Color, flat: bool) -> MeshInstance3D:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	var m := _glow_mat(col)
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if not flat:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var q := QuadMesh.new()
	q.size = Vector2(width, width)
	if flat:
		q.orientation = PlaneMesh.FACE_Y
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	return mi

## Your glow's colour on the turntable's ring, the rim light and the halo.
func _tint() -> void:
	var col: Color = Unmasked.GLOWS[int(look["glow"])]
	_ring_mat.albedo_color = col.lerp(Color.WHITE, 0.2)
	_rim.light_color = col.lerp(Color.WHITE, 0.45)
	_halo_mat.albedo_color = Color(col, 0.16)

func _rebuild_model(lk: Dictionary) -> void:
	_shown = lk.hash()
	if model:
		model.free()
	model = Models.hunter(Data.class_of_save(), Data.TEAM_COLORS[0], "", "", lk)      # empty-handed: just you
	model.get_node("Rig/Torso/Aim/Gun").free()
	_turn.add_child(model)
	_anim = HunterAnim.new(model)
	_dress_for_tab()
	_tint()

## On the Glider tab you hang over the turntable under your open glider; elsewhere you stand, glider packed.
func _dress_for_tab() -> void:
	var gliding := tab == "Glider"
	model.position.y = TOP + (GLIDE_LIFT if gliding else 0.0)
	var gl := model.get_node("Rig/Torso/Glider") as Node3D
	gl.visible = gliding
	gl.rotation.x = GLIDER_TILT

func _pop() -> void:
	var tw := model.create_tween()
	tw.tween_property(model, "scale", Vector3.ONE * POP_SCALE, 0.09).set_trans(Tween.TRANS_SINE)
	tw.tween_property(model, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var col: Color = Unmasked.GLOWS[int(look["glow"])]
	_fx.ring(AT + Vector3(0, TOP, 0), 1.1, col)
	_fx.burst(AT + Vector3(0, 1.0, 0), col, 16, 2.6, 0.55, 3.0, 0.8)
	Sfx.play("unlock", null, -10.0, 0.05, 1.3)

# ---- every frame: the camera, the turntable, trying a choice on

func _process(delta: float) -> void:
	var shot: Array = SHOTS[tab]
	var aim: Vector3 = AT + shot[1]
	var k := 1.0 - exp(-CAM_EASE * delta)
	_look_at = _look_at.lerp(aim, k)
	_cam.position = _cam.position.lerp(aim + (shot[0] - shot[1]) * _zoom, k)
	_cam.look_at(_look_at)
	(_cam.attributes as CameraAttributesPractical).dof_blur_far_distance = _cam.position.distance_to(_look_at) + 1.6
	if not (get_viewport().gui_get_focus_owner() is LineEdit):
		_turn.rotation.y += Input.get_axis("left", "right") * KEY_TURN * delta
	if not _dragging:
		_turn.rotation.y += _spin * delta
		_spin *= exp(-SPIN_DECAY * delta)
	_settle -= delta
	var want: Dictionary = _trial if not _trial.is_empty() else look
	if want.hash() != _shown and _settle <= 0.0:
		_settle = TRY_SETTLE
		_rebuild_model(want)
	var st := {"fired": 99.0, "face": _turn.rotation.y}
	if tab == "Glider":
		st.merge({"grounded": false, "gliding": true, "vel": Vector3(0, -1.0, 0)})
	_anim.update(delta, st)

func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var d := -ZOOM_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else ZOOM_STEP
			_zoom = clampf(_zoom + d, ZOOM_MIN, ZOOM_MAX)
	elif event is InputEventMouseMotion and _dragging:
		var dx: float = (event as InputEventMouseMotion).relative.x * DRAG_TURN
		_turn.rotation.y += dx
		_spin = dx / maxf(get_process_delta_time(), 0.001)

# ---- the panel

func _build_panel(ui_root: Control) -> void:
	var card := UI.card(UI.CARD, 14, 16)
	card.custom_minimum_size = Vector2(PANEL_W, 0)
	_panel = card
	var v := UI.vbox(10)
	card.add_child(v)
	_tabs = _tab_row()
	v.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = LIST_H
	_list = UI.vbox(6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	v.add_child(scroll)
	v.add_child(_name_row())
	var foot := UI.hbox(10)
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_child(UI.ghost("Random", _random, 120, "swap"))
	foot.add_child(UI.primary("Looks good", func(): finished.emit(), 200))
	v.add_child(foot)
	ui_root.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 48)
	card.offset_top += 46       # clear of the title
	card.offset_bottom += 46
	_fill()

## The four tabs, big, each with its icon.
func _tab_row() -> Control:
	var tabs := UI.tabs(TABS, tab, show_tab, {}, 118)
	for b in tabs.get_child(0).get_children():
		UI.set_icon(b, String(TAB_ICONS[String(b.get_meta("tab"))]), 18)
		(b as Button).custom_minimum_size.y = 48
	return tabs

func _name_row() -> Control:
	var row := UI.hbox(8)
	var l := UI.label("Your name", UI.T_BODY, UI.MUTED)
	l.custom_minimum_size.x = 120
	row.add_child(l)
	var ne := LineEdit.new()
	ne.text = Save.d.get("name", "Hunter")
	ne.max_length = 16
	ne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ne.text_changed.connect(func(t): Save.d["name"] = t.strip_edges() if t.strip_edges() != "" else "Hunter")
	row.add_child(ne)
	return row

## The tab's choices, the current ones lit.
func _fill() -> void:
	for ch in _list.get_children():
		_list.remove_child(ch)
		ch.queue_free()
	if tab == "Glider":
		_glider_grid()
		return
	for key in TAB_KEYS[tab]:
		var row := _row(String(key))
		if row.is_empty():
			continue
		_list.add_child(UI.section(String(row[1])))
		_list.add_child(_grid(String(key), row[2], int(look.get(key, 0)), 1 if key == "accent" else 0))

## A look key's row ([key, label, choices, tip?]); {} for the hood on a cut that has none.
func _row(key: String) -> Array:
	if key == "accent":
		return ["accent", "Trim colour", ["Match"] + Unmasked.COLOURS]
	if key == "hood" and not Shrouds.has_hood(int(look["shroud"])):
		return []
	for row in Unmasked.ROWS + Shrouds.ROWS:
		if row[0] == key:
			return row
	return []

## Choices as tiles (names) or swatches (colours). `shift`: the first choice saves as -shift (accent's Match is -1).
func _grid(key: String, opts: Array, cur: int, shift: int) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for i in opts.size():
		var val := i - shift
		var on := val == cur
		var c: Control = _swatch(key, opts[i], on, val) if opts[i] is Color else _tile(key, String(opts[i]), on, val)
		c.mouse_entered.connect(_try.bind(key, val))
		c.focus_entered.connect(_try.bind(key, val))
		c.mouse_exited.connect(_untry)
		flow.add_child(c)
	return flow

func _tile(key: String, text: String, on: bool, val: Variant) -> Control:
	var t := UI.tile_card(on, func(): pick(key, val), 6)
	t.custom_minimum_size = TILE
	t.set_meta("look_opt", "%s:%s" % [key, str(val)])
	var l := UI.label(text, UI.T_SMALL, UI.INK if on else UI.MUTED, UI.semi)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.add_child(l)
	return t

func _swatch(key: String, col: Color, on: bool, val: Variant) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(SWATCH, SWATCH)
	b.set_meta("look_opt", "%s:%s" % [key, str(val)])
	var edge := UI.ACCENT if on else Color(1, 1, 1, 0.22)
	b.add_theme_stylebox_override("normal", UI.frame(col, UI.R_PILL, edge, 3 if on else 1))
	b.add_theme_stylebox_override("hover", UI.frame(col.lightened(0.12), UI.R_PILL, UI.ACCENT_HI, 3))
	b.add_theme_stylebox_override("pressed", UI.frame(col, UI.R_PILL, UI.ACCENT, 3))
	b.add_theme_stylebox_override("focus", UI.frame(col, UI.R_PILL, UI.ACCENT_HI, 3))
	b.pressed.connect(func(): pick(key, val))
	return b

## Every glider skin as a tile in its rarity's colour: owned ones glide on at a click, the rest say how to get
## them (you can still hover any to see it on you).
func _glider_grid() -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	var cur := Gliders.equipped()
	for g in Gliders.LIST:
		var gid := String(g["id"])
		var owned := Gliders.owned(gid)
		var rar := Gliders.rarity(gid)
		var rc := UI.rarity_col(rar)
		var t := UI.tile_card(gid == cur, (func(): pick("glider", gid)) if owned else Callable(), 8, rc)
		t.custom_minimum_size = Vector2(244, 0)
		t.set_meta("look_opt", "glider:" + gid)
		t.tooltip_text = String(g["desc"]) if owned else _glider_how(gid)
		var row := UI.hbox(8)
		var bar := ColorRect.new()
		bar.color = rc
		bar.custom_minimum_size = Vector2(4, 30)
		row.add_child(bar)
		var names := UI.vbox(0)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_child(UI.label(String(g["name"]), UI.T_SMALL, UI.INK if owned else UI.MUTED, UI.semi))
		names.add_child(UI.label(String(Data.RARITY[rar]["name"]), 11, rc, UI.caps))
		row.add_child(names)
		if gid == cur:
			row.add_child(UI.IconDot.new("check", UI.GOOD, 16))
		elif not owned:
			row.add_child(UI.IconDot.new("lock", UI.FAINT, 16))
		t.add_child(row)
		t.mouse_entered.connect(_try.bind("glider", gid))
		t.mouse_exited.connect(_untry)
		flow.add_child(t)
	_list.add_child(UI.section("Glider"))
	_list.add_child(flow)

func _glider_how(gid: String) -> String:
	var how := Gliders.how(gid)
	if how != "":
		return "Earned: " + how
	return "%d gems at the glider rack" % int(Gliders.get_skin(gid).get("cost", 0))

## A random person, still on your glider.
func _random() -> void:
	var lk := Unmasked.random_look()
	lk["glider"] = look.get("glider", "classic")
	set_look(lk)

## Tries a choice on the model while it's hovered (or focused).
func _try(key: String, val: Variant) -> void:
	_trial = look.duplicate(true)
	_trial[key] = val

func _untry() -> void:
	_trial = {}
