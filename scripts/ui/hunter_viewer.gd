class_name HunterViewer
extends PanelContainer
## The Hunter viewer (docs/decisions/0005): one Mask, shown rather than described. On top its face, name
## and title and what it brings (health, dashes, weapon). Below, the real model on a slow turntable in its
## own SubViewport (it powers up while you hold to unlock it: HoldUnlock drives power() and burst()), and
## beside it every ability shown working in its own clip (AbilityClip: the ability used on a dummy, with
## its key and one short line). The passive and the Boki Fusion are one line each. Used on the Masks
## screen (HomeClasses), the Mask moments and the reveal. Kit move lists: content/rules/hunter_viewer.json.
##
##   var v := HunterViewer.make("thief", Vector2(220, 300))
##   v.slot_changed.connect(func(slot): ...)

signal slot_changed(slot: String)

const RULES_PATH := "res://content/rules/hunter_viewer.json"
const SLOT_NAMES := {"dash": "Dash", "passive": "Passive", "lmb": "Attack", "rmb": "Right click", "e": "Utility",
		"x": "Ultimate", "r": "Fusion with your Boki"}
## The input action behind each slot, so the key caps follow the player's bindings.
const SLOT_ACTIONS := {"dash": "dash", "lmb": "fire", "rmb": "secondary", "e": "signature", "x": "hunter_ult",
		"r": "ultimate"}
## The slots that get a clip; the rest (passive, the Boki Fusion) are a line each.
const CLIP_SLOTS := ["lmb", "rmb", "e", "dash", "x"]
const PORTRAIT_PX := 64.0     # px: the Hunter's face beside its name
static var _rules: Dictionary = {}

var id := ""
var stage_size := Vector2(220, 300)
var clip_size := Vector2(200, 112)
var clip_cols := 2
var slots: Array = []
var slot_i := 0
var power_k := 0.0            # 0..1 while the unlock is held (HoldUnlock)
var burst_t := -1.0           # s since the reveal burst, -1 when none
var spin_t := 0.0             # s the stage has run

var vp: SubViewport
var pivot: Node3D
var model: Node3D
var anim: HunterAnim
var glow: OmniLight3D
var rim: DirectionalLight3D
var plinth: StandardMaterial3D
var cam: Camera3D
var fx: Control               # the 2D sparks, rings and flash over the stage
var rows: Array = []          # one Control per ability, in `slots` order (an AbilityClip or a line)
var _body: Control            # everything but the stage, rebuilt when the Hunter changes
var _cols: HBoxContainer

## The abilities shown, in order. "x" (the Hunter's own ultimate on R) shows once a Hunter's data has an
## "x" entry; "r", the Boki Fusion, is always last.
static func slots_for(hunter_id: String) -> Array:
	var out: Array = KitCard.slots_of(hunter_id).filter(func(s): return s != "r" and s != "x")
	if Arch.def(hunter_id).has("x"): out.append("x")
	out.append("r")
	return out

## A slot's name, icon, colour and plain line (KitCard's, plus the X ultimate from its own data).
static func slot_info(hunter_id: String, slot: String) -> Dictionary:
	if slot != "x":
		return KitCard.slot_text(hunter_id, slot)
	var d := Arch.def(hunter_id)
	var xd: Dictionary = d.get("x", {})
	return {"name": String(xd.get("name", "")), "icon": String(xd.get("icon", "burst")),
			"col": Color(String(xd.get("col", "#ffffff"))), "tag": "", "line": String(d.get("card", {}).get("x",
			xd.get("desc", "")))}

## The key a slot is on, from the player's own bindings ("auto" for the passive).
static func key_for(slot: String) -> String:
	if not SLOT_ACTIONS.has(slot):
		return "auto"
	return Settings.key_cap(String(SLOT_ACTIONS[slot]))

## "Vex, the Hired Gun": the Mask's name and title (a title starting with "The" keeps one "the").
static func display_name(hunter_id: String) -> String:
	var title := Arch.name_of(hunter_id)
	if title.begins_with("The "):
		title = title.substr(4)
	var base := HeroTitle.base_name(hunter_id)
	return "%s, the %s" % [base, title] if base != "" else title

static func rules() -> Dictionary:
	if _rules.is_empty():
		var p = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_rules = p if typeof(p) == TYPE_DICTIONARY else {}
	return _rules

static func make(hunter_id: String, stage_px := Vector2(220, 300), clip_px := Vector2(200, 112),
		cols := 2) -> HunterViewer:
	var v := HunterViewer.new()
	v.id = hunter_id
	v.stage_size = stage_px
	v.clip_size = clip_px
	v.clip_cols = cols
	return v

## The kit moves a slot plays, from the rules (only ids the animation knows).
static func moves_for(hunter_id: String, slot: String) -> Array:
	var list: Array = (rules().get("moves", {}) as Dictionary).get(hunter_id, {}).get(slot, [])
	return list.filter(func(mv): return move_len(String(mv)) > 0.0)

## How long a kit move runs (its last key), 0 for an id the animation doesn't have. Held poses get 0.9 s.
static func move_len(mv: String) -> float:
	var d := HunterAnim.km_def(mv)
	if d.is_empty() or (d.get("keys", []) as Array).is_empty():
		return 0.0
	return 0.9 if d.get("hold", false) else float((d["keys"] as Array)[-1][0])

## "145 health  ·  1 dash  ·  Twin Blades": what the Hunter brings.
static func stat_line(hunter_id: String) -> String:
	var cd: Dictionary = Data.CLASSES.get(Arch.weight(hunter_id), {})
	var w := String(Data.weapon_stats(Arch.signature(hunter_id)).get("name", ""))
	var dn := int(cd.get("dashes", 1))
	return "%d health  ·  %d dash%s%s" % [int(cd.get("hp", 0)), dn, "es" if dn > 1 else "",
			("  ·  " + w) if w != "" else ""]

func _ready() -> void:
	add_theme_stylebox_override("panel", _frame(Arch.color(id)))
	set_meta("hunter_viewer", id)
	slots = slots_for(id)
	_cols = UI.hbox(14)
	if stage_size != Vector2.ZERO:      # (the Mask moment shows the Hunter in the world instead)
		_cols.add_child(_stage(Arch.color(id)))
	_rebuild_body()

## Shows another Hunter in this viewer without rebuilding the stage: the model swaps on the same turntable
## (it keeps turning from where it was), the colours, header and clips follow.
func set_hunter(hunter_id: String) -> void:
	if hunter_id == id or not Arch.exists(hunter_id):
		return
	id = hunter_id
	var col := Arch.color(id)
	slots = slots_for(id)
	add_theme_stylebox_override("panel", _frame(col))
	set_meta("hunter_viewer", id)
	_rebuild_body()
	if model == null:
		return
	model.queue_free()
	_build_model()
	rim.light_color = col.lerp(Color.WHITE, 0.35)
	glow.light_color = col.lerp(Color.WHITE, 0.2)
	plinth.albedo_color = col.darkened(0.55)
	fx.get_parent().get_child(0).queue_redraw()

func _frame(col: Color) -> StyleBox:
	return UI.frame(Color(0.05, 0.045, 0.08, 0.96), 14, Color(col, 0.45), 1, 14, 12)

func _rebuild_body() -> void:
	if _body:
		_cols.get_parent().remove_child(_cols)
		_body.queue_free()
	var col := Arch.color(id)
	var v := UI.vbox(10)
	_body = v
	add_child(v)
	v.add_child(_header(col))
	v.add_child(_cols)
	var keep := 0 if stage_size == Vector2.ZERO else 1      # (the stage stays)
	for i in range(_cols.get_child_count() - 1, keep - 1, -1):
		_cols.get_child(i).queue_free()
	rows.clear()
	var right := UI.vbox(8)
	var grid := GridContainer.new()
	grid.columns = clip_cols
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	right.add_child(grid)
	var lines := UI.vbox(8)
	lines.custom_minimum_size.x = clip_size.x
	for s in slots:
		var slot := String(s)
		var row: Control = AbilityClip.make(id, slot, clip_size) if slot in CLIP_SLOTS else _line(slot, col)
		row.set_meta("slot", slot)
		rows.append(row)
		(grid if slot in CLIP_SLOTS else lines).add_child(row)
	# the one-line abilities fill the grid's last gap when there is one, else go under it
	var gap := grid.get_child_count() % clip_cols != 0
	(grid if gap else right).add_child(lines)
	_cols.add_child(right)
	select(0)

## The face, "Vex, the Hired Gun" and what it brings. No story or gender here: the clips do the talking.
func _header(col: Color) -> Control:
	var head := UI.hbox(12)
	head.add_child(ClassCard.portrait(id, PORTRAIT_PX))
	var names := UI.vbox(2)
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nm := UI.title(display_name(id), 28, col)
	nm.set_meta("mask_name", id)
	names.add_child(nm)
	names.add_child(UI.label(stat_line(id), 13, UI.MUTED))
	head.add_child(names)
	return head

## A one-line ability (the passive, the Boki Fusion): key, icon and name, its short line under them.
func _line(slot: String, col: Color) -> Control:
	var info := slot_info(id, slot)
	var v := UI.vbox(2)
	var r := UI.hbox(8)
	r.add_child(UI.keycap(key_for(slot), 11))
	r.add_child(UI.IconDot.new(String(info["icon"]), info["col"], 20.0))
	var nl := UI.label(String(info["name"]), 14, col.lightened(0.25), UI.semi)
	nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(nl)
	v.add_child(r)
	var ln := UI.para(AbilityClip.line_for(id, slot), 12, UI.MUTED)
	ln.custom_minimum_size.x = clip_size.x
	v.add_child(ln)
	return v

# ------------------------------------------------------------------ the stage
func _stage(col: Color) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = stage_size
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := Control.new()      # a soft pool of the Hunter's colour behind it
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.draw.connect(func():
		var tint := Arch.color(id)
		var c := back.size * Vector2(0.5, 0.62)
		for i in 6:
			back.draw_circle(c, back.size.x * (0.52 - 0.07 * i), Color(tint, 0.035 + 0.012 * i))
		back.draw_arc(c + Vector2(0, back.size.y * 0.3), back.size.x * 0.3, 0, TAU, 48, Color(tint, 0.25), 2.0, true))
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
	# drawn only while it is on screen (not scrolled away or hidden under another page)
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	svc.add_child(vp)
	_build_world(col)
	fx = Control.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.draw.connect(func(): _draw_fx(Arch.color(id)))
	holder.add_child(fx)
	return holder

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
	key.light_color = Color("fff1dc")
	key.light_energy = 1.2
	vp.add_child(key)
	rim = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-12, -20, 0)
	rim.light_color = col.lerp(Color.WHITE, 0.35)
	rim.light_energy = 0.7
	vp.add_child(rim)
	pivot = Node3D.new()
	vp.add_child(pivot)
	_build_model()
	var floor_disc := MeshInstance3D.new()      # a low plinth so the feet stand on something
	var cm := CylinderMesh.new()
	cm.top_radius = 0.75
	cm.bottom_radius = 0.8
	cm.height = 0.06
	plinth = StandardMaterial3D.new()
	plinth.albedo_color = col.darkened(0.55)
	plinth.roughness = 0.8
	cm.material = plinth
	floor_disc.mesh = cm
	floor_disc.position.y = -0.03
	vp.add_child(floor_disc)
	glow = OmniLight3D.new()
	glow.light_color = col.lerp(Color.WHITE, 0.2)
	glow.omni_range = 3.5
	glow.light_energy = 0.0
	glow.position = Vector3(0, 1.0, -0.6)
	vp.add_child(glow)
	cam = Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	_aim_camera()
	cam.current = true

## The Hunter's model on the turntable, standing at ease in its signature stance.
func _build_model() -> void:
	model = Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", Unmasked.mask_look(), id)
	var ring := model.get_node_or_null("TeamRing")
	if ring: (ring as Node3D).visible = false
	pivot.add_child(model)
	anim = HunterAnim.new(model)
	if cam:
		_aim_camera()

func _aim_camera() -> void:
	var s := model.scale.y
	cam.transform = Transform3D(Basis(), Vector3(-1.0, 1.45, -5.3) * s).looking_at(Vector3(0, 0.95 * s, 0), Vector3.UP)

## Marks ability `i` (wraps) as the one picked: its clip lights up.
func select(i: int) -> void:
	if slots.is_empty():
		return
	slot_i = posmod(i, slots.size())
	var col := Arch.color(id)
	for j in rows.size():
		var row: Control = rows[j]
		if row is AbilityClip:
			var edge := Color(col, 0.95) if j == slot_i else Color(col, 0.35)
			row.add_theme_stylebox_override("panel", UI.frame(Color(0.04, 0.035, 0.07, 0.96), 10, edge, 1, 6, 6))
	slot_changed.emit(current_slot())

func current_slot() -> String:
	return String(slots[slot_i]) if not slots.is_empty() else ""

# ------------------------------------------------------------------ playing it
func _process(dt: float) -> void:
	dt = minf(dt, 0.1)
	if model == null or anim == null:
		return
	tick(dt)

## One step of the stage (also driven straight by the unlock check): the turntable, and the power-up.
func tick(dt: float) -> void:
	spin_t += dt
	pivot.rotation.y += dt * float(rules().get("turn_rate", 0.45)) * (1.0 - power_k)
	var s := {"fired": 99.0, "face": 0.0, "grounded": true, "wid": Arch.signature(id)}
	if power_k > 0.0:
		s["crouch"] = 0.55 * power_k
		s["cast_slot"] = "ult"
		s["cast"] = 0.05
	anim.update(dt, s)
	# powering up: the Hunter's light builds and the body thrums; the burst pops it
	glow.light_energy = 6.0 * power_k + (5.0 * maxf(0.0, 1.0 - burst_t / 0.6) if burst_t >= 0.0 else 0.0)
	var shake := 0.018 * power_k * power_k
	model.position = Vector3(sin(spin_t * 61.0) * shake, 0.04 * power_k, cos(spin_t * 47.0) * shake)
	if burst_t >= 0.0:
		burst_t += dt
		var k := clampf(burst_t / 0.45, 0.0, 1.0)
		var pop := 1.0 + 0.18 * sin(k * PI)
		model.scale = Vector3.ONE * model.get_meta("base_scale", model.scale.y) * pop
		if burst_t > 1.4:
			burst_t = -1.0
			model.scale = Vector3.ONE * float(model.get_meta("base_scale", model.scale.y))
	if fx: fx.queue_redraw()

## 0..1 while the unlock is held: the Hunter crouches into its power, its light builds, the stage thrums.
func power(k: float) -> void:
	power_k = clampf(k, 0.0, 1.0)

## The reveal burst at the end of a full hold.
func burst() -> void:
	if model and not model.has_meta("base_scale"): model.set_meta("base_scale", model.scale.y)
	power_k = 0.0
	burst_t = 0.0

func _draw_fx(col: Color) -> void:
	var c := fx.size * Vector2(0.5, 0.58)
	if power_k > 0.0:
		# sparks rising round the Hunter, more and faster as the hold fills
		var n := int(8 + 30 * power_k)
		for i in n:
			var ph := fposmod(spin_t * (0.6 + power_k) + float(i) * 0.137, 1.0)
			var x := c.x + sin(float(i) * 12.9898) * fx.size.x * 0.32
			var y := fx.size.y * (0.92 - 0.8 * ph)
			fx.draw_circle(Vector2(x, y), 2.0 + 2.0 * power_k, Color(col.lightened(0.4), (1.0 - ph) * 0.9))
		fx.draw_arc(c, fx.size.x * (0.46 - 0.12 * power_k), 0, TAU * power_k, 64, Color(col, 0.9), 4.0, true)
	if burst_t >= 0.0:
		var k := clampf(burst_t / 0.7, 0.0, 1.0)
		fx.draw_rect(Rect2(Vector2.ZERO, fx.size), Color(1, 1, 1, 0.75 * maxf(0.0, 1.0 - burst_t / 0.25)))
		for i in 3:
			var kk := clampf(k - 0.12 * i, 0.0, 1.0)
			fx.draw_arc(c, 20.0 + fx.size.x * 0.7 * kk, 0, TAU, 72, Color(col.lightened(0.3), (1.0 - kk) * 0.9),
					6.0 - i * 1.5, true)
		for i in 16:
			var a := TAU * float(i) / 16.0
			var r0 := fx.size.x * 0.12 * (1.0 + k * 2.0)
			fx.draw_line(c + Vector2(cos(a), sin(a)) * r0, c + Vector2(cos(a), sin(a)) * (r0 + 40.0 * (1.0 - k)),
					Color(Color.WHITE, 1.0 - k), 3.0, true)
