class_name HunterViewer
extends PanelContainer
## The Hunter viewer (docs/decisions/0005): one Hunter, big. On the left the real model on a slow
## turntable in its own SubViewport, playing its abilities one after another (the same kit moves the
## kits play in a match, HunterAnim.KMOVES, looped), with the key, name and plain-words line of the one
## playing under it. On the right the name, health and dashes, the fantasy, "how it plays" (the card
## text the L loadout picker shows) and every ability with its key; click one to watch it. Used on the
## Hunters screen (HomeClasses) and at character creation (hatch.gd). Moves and timings:
## content/rules/hunter_viewer.json. HoldUnlock drives power() and burst() while you hold to unlock.
##
##   var v := HunterViewer.make("thief", Vector2(320, 380))
##   v.slot_changed.connect(func(slot): ...)

signal slot_changed(slot: String)

const RULES_PATH := "res://content/rules/hunter_viewer.json"
const SLOT_NAMES := {"dash": "Dash", "passive": "Passive", "lmb": "Attack", "rmb": "Right click", "e": "Utility", "r": "with your Boki"}
static var _rules: Dictionary = {}

var id := ""
var stage_size := Vector2(320, 380)
var slots: Array = []
var slot_i := 0
var slot_t := 0.0             # s into the current slot
var move_t := 0.0             # s into the current loop of its move
var cycling := true           # steps to the next ability by itself (a click on one holds it a full turn)
var power_k := 0.0            # 0..1 while the unlock is held (HoldUnlock)
var burst_t := -1.0           # s since the reveal burst, -1 when none

var vp: SubViewport
var pivot: Node3D
var model: Node3D
var anim: HunterAnim
var glow: OmniLight3D
var fx: Control               # 2D sparks, the rings and the flash over the stage
var cap_key: PanelContainer
var cap_name: Label
var cap_line: Label
var cap_dots: HBoxContainer
var rows: Array = []          # one Button per ability, in `slots` order
var _swing_n := 0
var _swing_at := 0.0
var _melee := false

static func rules() -> Dictionary:
	if _rules.is_empty():
		var p = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_rules = p if typeof(p) == TYPE_DICTIONARY else {}
	return _rules

static func make(hunter_id: String, size := Vector2(320, 380)) -> HunterViewer:
	var v := HunterViewer.new()
	v.id = hunter_id
	v.stage_size = size
	return v

## The kit moves a slot plays, from the rules (only ids the animation knows).
static func moves_for(hunter_id: String, slot: String) -> Array:
	var list: Array = (rules().get("moves", {}) as Dictionary).get(hunter_id, {}).get(slot, [])
	return list.filter(func(mv): return move_len(String(mv)) > 0.0)

## How long a kit move runs (its last key), 0 for an id the animation doesn't have. Held poses get 0.9 s.
static func move_len(mv: String) -> float:
	var d: Dictionary = HunterAnim.KMOVES.get(mv, KMovesPair.MOVES.get(mv, {}))
	if d.is_empty() or (d.get("keys", []) as Array).is_empty():
		return 0.0
	return 0.9 if d.get("hold", false) else float((d["keys"] as Array)[-1][0])

## "145 health  ·  1 dash  ·  Twin Blades": what the Hunter brings, with no weight label.
static func stat_line(hunter_id: String) -> String:
	var cd: Dictionary = Data.CLASSES.get(Arch.weight(hunter_id), {})
	var w := String(Data.weapon_stats(Arch.signature(hunter_id)).get("name", ""))
	var dn := int(cd.get("dashes", 1))
	return "%d health  ·  %d dash%s%s" % [int(cd.get("hp", 0)), dn, "es" if dn > 1 else "", ("  ·  " + w) if w != "" else ""]

func _ready() -> void:
	var col := Arch.color(id)
	add_theme_stylebox_override("panel", KitCard._box(Color(0.05, 0.045, 0.08, 0.96), 14, Color(col, 0.45), 1, 14, 12))
	set_meta("hunter_viewer", id)
	slots = KitCard.slots_of(id)
	if not slots.has("r"): slots.append("r")      # (R is the Boki Merge for every Hunter: shown last)
	var w: Dictionary = Data.weapon_stats(Arch.signature(id))
	_melee = bool(w.get("melee", false))
	var row := UI.hbox(16)
	add_child(row)
	row.add_child(_stage(col))
	row.add_child(_info(col))
	select(0, false)

# ------------------------------------------------------------------ the stage
func _stage(col: Color) -> Control:
	var v := UI.vbox(6)
	var holder := Control.new()
	holder.custom_minimum_size = stage_size
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(holder)
	var back := Control.new()      # a soft pool of the Hunter's colour behind it
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.draw.connect(func():
		var c := back.size * Vector2(0.5, 0.62)
		for i in 6:
			back.draw_circle(c, back.size.x * (0.52 - 0.07 * i), Color(col, 0.035 + 0.012 * i))
		back.draw_arc(c + Vector2(0, back.size.y * 0.3), back.size.x * 0.3, 0, TAU, 48, Color(col, 0.25), 2.0, true))
	holder.add_child(back)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(svc)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.size = Vector2i(stage_size)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(vp)
	_build_world(col)
	fx = Control.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.draw.connect(_draw_fx.bind(col))
	holder.add_child(fx)
	# the caption: the key, the ability's name and its plain line, and a dot per ability
	var cap := UI.hbox(8)
	cap_key = UI.keycap("LMB", 14)
	cap.add_child(cap_key)
	cap_name = UI.label("", UI.T_BODY, col, UI.big)
	cap.add_child(cap_name)
	cap.add_child(UI.fill())
	cap_dots = UI.hbox(4)
	cap_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.add_child(cap_dots)
	v.add_child(cap)
	cap_line = UI.para("", 12, UI.MUTED)
	cap_line.custom_minimum_size = Vector2(stage_size.x, 34)
	v.add_child(cap_line)
	return v

func _build_world(col: Color) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8a93b8")
	e.ambient_light_energy = 0.85
	env.environment = e
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 160, 0)
	key.light_color = Color("fff1dc"); key.light_energy = 1.2
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-12, -20, 0)
	rim.light_color = col.lerp(Color.WHITE, 0.35); rim.light_energy = 0.7
	vp.add_child(rim)
	pivot = Node3D.new()
	vp.add_child(pivot)
	model = Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", Save.d.get("look", {}), id)
	var ring := model.get_node_or_null("TeamRing")
	if ring: (ring as Node3D).visible = false
	pivot.add_child(model)
	anim = HunterAnim.new(model)
	var floor_disc := MeshInstance3D.new()      # a low plinth so the feet stand on something
	var cm := CylinderMesh.new(); cm.top_radius = 0.75; cm.bottom_radius = 0.8; cm.height = 0.06
	var mat := StandardMaterial3D.new(); mat.albedo_color = col.darkened(0.55); mat.roughness = 0.8
	cm.material = mat
	floor_disc.mesh = cm
	floor_disc.position.y = -0.03
	vp.add_child(floor_disc)
	glow = OmniLight3D.new()
	glow.light_color = col.lerp(Color.WHITE, 0.2)
	glow.omni_range = 3.5
	glow.light_energy = 0.0
	glow.position = Vector3(0, 1.0, -0.6)
	vp.add_child(glow)
	var s := model.scale.y
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.transform = Transform3D(Basis(), Vector3(-1.0, 1.45, -5.3) * s).looking_at(Vector3(0, 0.95 * s, 0), Vector3.UP)
	cam.current = true

# ------------------------------------------------------------------ the info column
func _info(col: Color) -> Control:
	var v := UI.vbox(6)
	v.custom_minimum_size.x = 400
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.title(Arch.name_of(id), 30, col))
	v.add_child(UI.label(stat_line(id), 13, UI.MUTED))
	var fan := UI.para(String(Arch.def(id).get("fantasy", "")), 13, UI.INK)
	fan.custom_minimum_size.x = 390
	v.add_child(fan)
	# the plain-words card, as the L loadout picker shows it
	var card := UI.card(Color(col, 0.09), 10, 10)
	card.set_meta("plain_card", true)
	var cv := UI.vbox(3); card.add_child(cv)
	cv.add_child(UI.label("How it plays", 12, Color(col, 0.95), UI.caps))
	var lp := UI.para(String(Arch.def(id).get("card", {}).get("loop", "")), 13, col.lightened(0.25))
	lp.custom_minimum_size.x = 370
	cv.add_child(lp)
	v.add_child(card)
	v.add_child(UI.label("Abilities", 12, UI.MUTED, UI.caps))
	var list := UI.vbox(2)
	for i in slots.size():
		var b := _row(String(slots[i]), i, col)
		rows.append(b)
		list.add_child(b)
	v.add_child(list)
	return v

func _row(slot: String, i: int, col: Color) -> Button:
	var info := KitCard.slot_text(id, slot)
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(390, 28)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.set_meta("slot", slot)
	b.pressed.connect(func(): select(i, true))
	var r := UI.hbox(8)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.offset_left = 8; r.offset_right = -8
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(r)
	var kc := UI.keycap(_key(slot), 11)
	kc.custom_minimum_size.x = 46
	r.add_child(kc)
	r.add_child(UI.IconDot.new(String(info["icon"]), info["col"], 22.0))
	var nl := UI.label(String(info["name"]), 15, UI.INK, UI.semi)
	nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(nl)
	var tg := UI.label(String(SLOT_NAMES.get(slot, "")), 11, UI.FAINT)
	tg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(tg)
	return b

func _key(slot: String) -> String:
	var k := String(KitCard.KEYS.get(slot, ""))
	return k if k != "" else "auto"

## Shows ability `i` (wraps). `held`: a click, so it stays a full turn before the cycle moves on.
func select(i: int, held := false) -> void:
	if slots.is_empty():
		return
	slot_i = posmod(i, slots.size())
	slot_t = 0.0
	move_t = 0.0
	_swing_at = 0.0
	var slot := String(slots[slot_i])
	var info := KitCard.slot_text(id, slot)
	var col := Arch.color(id)
	if cap_name:
		(cap_key.get_child(0) as Label).text = _key(slot)
		cap_name.text = String(info["name"])
		cap_line.text = String(info["line"])
		for c in cap_dots.get_children(): c.queue_free()
		for j in slots.size():
			var d := ColorRect.new()
			d.custom_minimum_size = Vector2(14 if j == slot_i else 6, 6)
			d.color = col if j == slot_i else Color(1, 1, 1, 0.22)
			d.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cap_dots.add_child(d)
	for j in rows.size():
		var b: Button = rows[j]
		var on := j == slot_i
		b.add_theme_stylebox_override("normal", KitCard._box(Color(col, 0.16) if on else Color(1, 1, 1, 0.03), 8, Color(col, 0.8) if on else Color(0, 0, 0, 0), 1 if on else 0, 4, 2))
		b.add_theme_stylebox_override("hover", KitCard._box(Color(col, 0.2) if on else Color(1, 1, 1, 0.07), 8, Color(col, 0.6), 1, 4, 2))
		b.add_theme_stylebox_override("pressed", b.get_theme_stylebox("hover"))
	if held: Sfx.play("hover", null, -8.0)
	slot_changed.emit(slot)

func current_slot() -> String:
	return String(slots[slot_i]) if not slots.is_empty() else ""

# ------------------------------------------------------------------ playing it
## How long one loop of the current ability's move takes.
func loop_len() -> float:
	var mv := moves_for(id, current_slot())
	var n := 0.0
	for m in mv: n += move_len(String(m))
	return (n if n > 0.0 else 1.1) + float(rules().get("gap_s", 0.35))

func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	if model == null or anim == null:
		return
	tick(dt)

## One step of the viewer (also driven straight by the unlock check).
func tick(dt: float) -> void:
	slot_t += dt
	move_t += dt
	if move_t >= loop_len():
		move_t = 0.0
	if cycling and slot_t >= float(rules().get("slot_s", 3.2)) and power_k <= 0.0:
		select(slot_i + 1)
	var playing := power_k <= 0.0 and move_t < loop_len() - float(rules().get("gap_s", 0.35))
	pivot.rotation.y += dt * float(rules().get("turn_rate", 0.45)) * (0.33 if playing else 1.0) * (1.0 - power_k)
	var s := _state()
	anim.update(dt, s)
	# powering up: the Hunter's light builds and the body thrums; the burst pops it
	glow.light_energy = 6.0 * power_k + (5.0 * maxf(0.0, 1.0 - burst_t / 0.6) if burst_t >= 0.0 else 0.0)
	var shake := 0.018 * power_k * power_k
	model.position = Vector3(sin(slot_t * 61.0) * shake, 0.04 * power_k, cos(slot_t * 47.0) * shake)
	if burst_t >= 0.0:
		burst_t += dt
		var k := clampf(burst_t / 0.45, 0.0, 1.0)
		var pop := 1.0 + 0.18 * sin(k * PI)
		model.scale = Vector3.ONE * model.get_meta("base_scale", model.scale.y) * pop
		if burst_t > 1.4:
			burst_t = -1.0
			model.scale = Vector3.ONE * float(model.get_meta("base_scale", model.scale.y))
	if fx: fx.queue_redraw()

## The animation state for this moment: a kit move, a swing or shot, a dodge or a cast.
func _state() -> Dictionary:
	var slot := current_slot()
	var s := {"fired": 99.0, "face": 0.0, "grounded": true, "wid": Arch.signature(id)}
	if power_k > 0.0:
		s["crouch"] = 0.55 * power_k
		s["cast_slot"] = "ult"
		s["cast"] = 0.05
		return s
	var mv := moves_for(id, slot)
	if not mv.is_empty():
		var t := move_t
		for m in mv:
			var L := move_len(String(m))
			if t < L:
				s["kmove"] = String(m)
				s["kmove_t"] = t
				break
			t -= L
		return s
	match slot:
		"lmb":
			if move_t < 1.0:
				if move_t - _swing_at >= 0.42 or _swing_at == 0.0:
					_swing_at = maxf(0.001, move_t)
					_swing_n += 1
				s["swing_n"] = _swing_n
				s["combo"] = _swing_n % 3
				if not _melee:
					s["fired"] = move_t - _swing_at
					s["recoil"] = clampf(1.0 - (move_t - _swing_at) / 0.18, 0.0, 1.0)
		"dash":
			if move_t < 0.45:
				s["rolling"] = true
				s["dash_dir"] = Vector2(0, -1)
				s["vel"] = Vector3(0, 0, -6.0)
		"rmb", "e", "r":
			s["cast_slot"] = {"rmb": "secondary", "e": "utility", "r": "ult"}[slot]
			s["cast"] = move_t
	return s

## 0..1 while the unlock is held: the Hunter crouches into its power, its light builds, the stage thrums.
func power(k: float) -> void:
	power_k = clampf(k, 0.0, 1.0)

## The reveal burst at the end of a full hold.
func burst() -> void:
	if model and not model.has_meta("base_scale"): model.set_meta("base_scale", model.scale.y)
	power_k = 0.0
	burst_t = 0.0
	move_t = 0.0

func _draw_fx(col: Color) -> void:
	var c := fx.size * Vector2(0.5, 0.58)
	if power_k > 0.0:
		# sparks rising round the Hunter, more and faster as the hold fills
		var n := int(8 + 30 * power_k)
		for i in n:
			var ph := fposmod(slot_t * (0.6 + power_k) + float(i) * 0.137, 1.0)
			var x := c.x + sin(float(i) * 12.9898) * fx.size.x * 0.32
			var y := fx.size.y * (0.92 - 0.8 * ph)
			fx.draw_circle(Vector2(x, y), 2.0 + 2.0 * power_k, Color(col.lightened(0.4), (1.0 - ph) * 0.9))
		fx.draw_arc(c, fx.size.x * (0.46 - 0.12 * power_k), 0, TAU * power_k, 64, Color(col, 0.9), 4.0, true)
	if burst_t >= 0.0:
		var k := clampf(burst_t / 0.7, 0.0, 1.0)
		fx.draw_rect(Rect2(Vector2.ZERO, fx.size), Color(1, 1, 1, 0.75 * maxf(0.0, 1.0 - burst_t / 0.25)))
		for i in 3:
			var kk := clampf(k - 0.12 * i, 0.0, 1.0)
			fx.draw_arc(c, 20.0 + fx.size.x * 0.7 * kk, 0, TAU, 72, Color(col.lightened(0.3), (1.0 - kk) * 0.9), 6.0 - i * 1.5, true)
		for i in 16:
			var a := TAU * float(i) / 16.0
			var r0 := fx.size.x * 0.12 * (1.0 + k * 2.0)
			fx.draw_line(c + Vector2(cos(a), sin(a)) * r0, c + Vector2(cos(a), sin(a)) * (r0 + 40.0 * (1.0 - k)), Color(Color.WHITE, 1.0 - k), 3.0, true)
