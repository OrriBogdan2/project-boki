class_name AbilityClip
extends PanelContainer
## One ability of a Relic, shown working: a small looping scene in its own SubViewport, the Hunter (the
## real model, side on) using the ability on a training dummy, with the kit's own move on the body, the
## effect in the ability's colour (shots, a thrown charge, a beam, a strike from above...), the hit
## sparks, the dummy's flinch and the damage. Under it the key (Settings.key_cap), the name and one
## short line. Used by HunterViewer (the Relics screen, the Relic moments and the reveal). Only a clip that is
## playing builds its scene (one a frame: PreviewBuild) and renders; one out of focus holds a still frame, or
## its ability's icon until it has played once.
##
##   add_child(AbilityClip.make("gunslinger", "rmb", Vector2(230, 130)))

const LOOP_S := 2.8            # s: one loop of the clip
const ACT_AT := 0.35           # s: when the ability goes off in the loop
const HUNTER_AT := Vector3(-1.5, 0.0, 0.0)
const DUMMY_AT := Vector3(1.7, 0.0, 0.0)
const MELEE_AT := Vector3(0.55, 0.0, 0.0)  # where a melee Hunter stands to swing at the dummy
const LINE_CHARS := 64         # the fallback line's length, cut at a word
## The effect each delivery reads as (an archetype's "clip" block can name its own per slot in "fx").
const FX_BY_DELIVERY := {"projectile": "bolt", "cone": "cone", "zone": "zone", "wall": "wall"}
static var _paren: RegEx        # "(...)" asides cut from a fallback line, compiled once

var id := ""
var slot := ""
var stage_size := Vector2(230, 130)
var fx := ""
var t := 0.0
var col := Color.WHITE
var playing := true            # play() sets it: the clip in focus plays, the others hold still
var vp: SubViewport
var model: Node3D
var anim: HunterAnim
var dummy: Node3D
var _cam: Camera3D
var _view: TextureRect
var _still: Control            # the ability's icon on the empty stage until the clip is built
var _moves: Array = []
var _melee := false
var _parts := {}               # the effect's meshes, made once and shown or hidden each frame
var _sparks: CPUParticles3D
var _number: Label3D
var _hits: Array = []          # loop times the dummy is struck
var _hit_i := 0
var _flinch := 0.0

static func make(hunter_id: String, ability: String, px := Vector2(230, 130)) -> AbilityClip:
	var c := AbilityClip.new()
	c.id = hunter_id
	c.slot = ability
	c.stage_size = px
	return c

## The effect a slot plays: the archetype's own "clip" choice, else one from how the ability is delivered.
static func fx_for(hunter_id: String, ability: String) -> String:
	var d := Arch.def(hunter_id)
	var own := String((d.get("clip", {}) as Dictionary).get("fx", {}).get(ability, ""))
	if own != "":
		return own
	match ability:
		"dash":
			return "dash"
		"x":
			return "strike"
		"lmb":
			var w: Dictionary = Data.weapon_stats(Arch.signature(hunter_id))
			return "swing" if bool(w.get("melee", false)) else "shots"
	var sd: Dictionary = d.get(ability, {})
	var how := String(sd.get("delivery", ""))
	if how == "burst":
		return "beam" if float(sd.get("range", 0.0)) >= 8.0 else "nova"
	return String(FX_BY_DELIVERY.get(how, "nova"))

## One short line for the clip: the archetype's own ("clip" > "lines"), else the first clause of its card text.
static func line_for(hunter_id: String, ability: String) -> String:
	var d := Arch.def(hunter_id)
	var own := String((d.get("clip", {}) as Dictionary).get("lines", {}).get(ability, ""))
	if own != "":
		return own
	var text := String(HunterViewer.slot_info(hunter_id, ability)["line"])
	if _paren == null:
		_paren = RegEx.create_from_string("\\s*\\([^)]*\\)")
	text = _paren.sub(text, "", true)
	if text.find(": ") >= 0 and text.find(": ") < 30:
		text = text.substr(text.find(": ") + 2)
	for stop in [". ", "; "]:
		if text.find(stop) > 0:
			text = text.substr(0, text.find(stop))
	if text.length() > LINE_CHARS:
		text = text.substr(0, text.rfind(" ", LINE_CHARS)) + "..."
	return text.trim_suffix(".").capitalize().substr(0, 1) + text.trim_suffix(".").substr(1) + "."

func _ready() -> void:
	var info := HunterViewer.slot_info(id, slot)
	col = Color(info["col"]).lerp(Arch.color(id), 0.3)
	fx = fx_for(id, slot)
	_melee = bool(Data.weapon_stats(Arch.signature(id)).get("melee", false))
	_moves = HunterViewer.moves_for(id, slot)
	add_theme_stylebox_override("panel", UI.frame(Color(0.04, 0.035, 0.07, 0.96), 10, Color(col, 0.35), 1, 6, 6))
	set_meta("slot", slot)
	var v := UI.vbox(4)
	add_child(v)
	v.add_child(_stage())
	var head := UI.hbox(6)
	var key := UiWidgets.keycap(HunterViewer.key_for(slot), 11)
	head.add_child(key)
	var nm := UiText.label(String(info["name"]), UI.T_BODY, col.lightened(0.25), UI.semi)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(nm)
	v.add_child(head)
	var ln := UiText.para(line_for(id, slot), 12, UI.MUTED)
	ln.custom_minimum_size = Vector2(stage_size.x, 0)
	v.add_child(ln)
	t = fmod(float(hash(id + slot) % 1000) / 1000.0 * LOOP_S, LOOP_S)     # clips side by side don't beat together

# ------------------------------------------------------------------ the stage
func _stage() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = stage_size
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	holder.add_child(vp)
	_view = TextureRect.new()
	_view.texture = vp.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.visible = false
	holder.add_child(_view)
	var info := HunterViewer.slot_info(id, slot)
	_still = CenterContainer.new()
	_still.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_still.add_child(UiWidgets.IconDot.new(String(info["icon"]), col, stage_size.y * 0.32))
	holder.add_child(_still)
	holder.resized.connect(func(): _fit(holder))
	return holder

## Plays the clip (its scene is built on a later frame the first time) or holds it on a still frame.
func play(on: bool) -> void:
	playing = on
	if model:
		vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if on else SubViewport.UPDATE_ONCE

## Builds the clip's scene now (the playing clip does it on its own turn; checks call it to step a clip by hand).
func build() -> void:
	if model:
		return
	_build_world()
	_still.queue_free()
	_view.visible = true
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if playing else SubViewport.UPDATE_ONCE

## The viewport renders at the screen's real pixels (the UI may be scaled up), so the clip stays sharp.
func _fit(holder: Control) -> void:
	var k := get_tree().root.content_scale_factor if is_inside_tree() else 1.0
	vp.size = Vector2i((holder.size * maxf(k, 1.0)).round())

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.045, 0.085)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8a93b8")
	e.ambient_light_energy = 0.8
	e.glow_enabled = true
	e.glow_intensity = 0.6
	env.environment = e
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 30, 0)
	key.light_color = Color("fff1dc")
	key.light_energy = 1.1
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 200, 0)
	rim.light_color = col.lerp(Color.WHITE, 0.4)
	rim.light_energy = 0.8
	vp.add_child(rim)
	_floor()
	model = PreviewBuild.model(id)
	model.rotation.y = -PI / 2.0
	vp.add_child(model)
	anim = HunterAnim.new(model)
	dummy = _dummy()
	vp.add_child(dummy)
	_effects()
	_cam = Camera3D.new()
	_cam.fov = 30.0
	vp.add_child(_cam)
	var mid := (HUNTER_AT + DUMMY_AT) * 0.5 + Vector3(0, 0.8, 0)
	_cam.transform = Transform3D(Basis(), mid + Vector3(0.0, 0.9, 5.0)).looking_at(mid, Vector3.UP)
	_cam.current = true

func _floor() -> void:
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 9.0
	cm.bottom_radius = 9.0
	cm.height = 0.04
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.11, 0.17)
	mat.roughness = 0.9
	cm.material = mat
	disc.mesh = cm
	disc.position.y = -0.02
	vp.add_child(disc)
	var lane := MeshInstance3D.new()
	lane.mesh = Models.flat_quad(6.4)
	lane.material_override = Models.ring_mat(Color(col, 0.22), 0.01)
	lane.position.y = 0.01
	vp.add_child(lane)

## A straw training dummy on a post, with a target painted on its chest.
func _dummy() -> Node3D:
	var root := Node3D.new()
	root.position = DUMMY_AT
	var straw := Models.toon(Color("c9a96a"))
	var wood := Models.toon(Color("6e4a30"))
	Models.part(root, Models.cyl(0.05, 0.06, 0.7, 8), wood, Vector3(0, 0.35, 0))
	Models.part(root, Models.cyl(0.24, 0.2, 0.7, 14), straw, Vector3(0, 0.95, 0))
	Models.part(root, Models.sphere(0.2, 14), straw, Vector3(0, 1.48, 0))
	Models.part(root, Models.cyl(0.03, 0.03, 0.9, 6), wood, Vector3(0, 1.1, 0), Vector3.ONE, Vector3(0, 0, PI / 2))
	for k in 2:
		var ring := Models.part(root, Models.cyl(0.17 - k * 0.08, 0.17 - k * 0.08, 0.02, 18),
				Models.toon(Color("d84a3a") if k == 0 else Color("f3eee2")), Vector3(-0.235 - k * 0.003, 1.0, 0))
		ring.rotation.z = PI / 2
	return root

## The effect pieces: one of each, reused every loop (no nodes made while it plays).
func _effects() -> void:
	for nm in ["orb", "flash"]:
		var mi := MeshInstance3D.new()
		mi.mesh = Models.sphere(0.12 if nm == "orb" else 0.5, 12)
		mi.material_override = Models.glow_mat(col.lightened(0.3))
		mi.visible = false
		vp.add_child(mi)
		_parts[nm] = mi
	for nm in ["lane", "beam", "tracer", "trail"]:
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		mi.material_override = Models.glow_mat(Color(col.lightened(0.2), 0.8))
		mi.visible = false
		vp.add_child(mi)
		_parts[nm] = mi
	for nm in ["ring", "disc"]:
		var mi := MeshInstance3D.new()
		mi.mesh = Models.flat_quad(1.0)
		mi.material_override = Models.ring_mat(col, 0.08 if nm == "ring" else 0.05)
		if nm == "disc":
			(mi.material_override as ShaderMaterial).set_shader_parameter("fill", 0.35)
		mi.visible = false
		vp.add_child(mi)
		_parts[nm] = mi
	var wall := MeshInstance3D.new()
	wall.mesh = Models.box(0.25, 1.4, 1.6)
	wall.material_override = Models.toon(col.lerp(Color.WHITE, 0.45), true, 0.4)
	wall.visible = false
	vp.add_child(wall)
	_parts["wall"] = wall
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.explosiveness = 1.0
	_sparks.amount = 14
	_sparks.lifetime = 0.45
	_sparks.direction = Vector3(-1, 0.5, 0)
	_sparks.spread = 60.0
	_sparks.initial_velocity_min = 2.0
	_sparks.initial_velocity_max = 4.5
	_sparks.gravity = Vector3(0, -6, 0)
	_sparks.scale_amount_min = 0.5
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.06
	sm.material = Models.glow_mat(col.lightened(0.5))
	_sparks.mesh = sm
	vp.add_child(_sparks)
	_number = Label3D.new()
	_number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_number.font_size = 64
	_number.outline_size = 14
	_number.pixel_size = 0.006
	_number.modulate = col.lightened(0.5)
	_number.outline_modulate = Color(0.05, 0.03, 0.08, 0.9)
	_number.no_depth_test = true
	_number.render_priority = 10
	_number.visible = false
	vp.add_child(_number)
	_hits = _hit_times()

## When the dummy is struck in the loop, for this effect.
func _hit_times() -> Array:
	match fx:
		"shots":
			return [ACT_AT + 0.05, ACT_AT + 0.2, ACT_AT + 0.35, ACT_AT + 0.5, ACT_AT + 0.65]
		"swing":
			return [ACT_AT + 0.25, ACT_AT + 0.7, ACT_AT + 1.15]
		"bolt":
			return [ACT_AT + 0.75]
		"beam":
			return [ACT_AT + 0.75]
		"nova", "cone":
			return [ACT_AT + 0.25]
		"zone":
			return [ACT_AT + 0.4, ACT_AT + 0.9, ACT_AT + 1.4]
		"strike":
			return [ACT_AT + 1.35]
		"spray":
			return [ACT_AT + 0.3, ACT_AT + 0.6, ACT_AT + 0.9]
	return []

# ------------------------------------------------------------------ playing it
func _process(dt: float) -> void:
	if model == null and playing and PreviewBuild.turn(id):
		build()
	if playing:
		tick(minf(dt, 0.1))

## One step of the clip (also stepped straight by checks).
func tick(dt: float) -> void:
	if model == null:
		return
	var before := t
	t = fmod(t + dt, LOOP_S)
	if t < before:
		_hit_i = 0
	while _hit_i < _hits.size() and t >= float(_hits[_hit_i]):
		_hit()
		_hit_i += 1
	model.position = _hunter_pos()
	anim.update(dt, _state())
	_flinch = move_toward(_flinch, 0.0, dt * 3.0)
	dummy.rotation.z = -0.35 * _flinch * _flinch
	_number.position.y += dt * 0.6
	_number.modulate.a = move_toward(_number.modulate.a, 0.0, dt * 1.6)
	_show_fx()

## Where the Hunter stands now: still, sliding through a dash, or stepped up to the dummy to swing.
func _hunter_pos() -> Vector3:
	var home := MELEE_AT if fx == "swing" or (fx == "cone" and _melee) else HUNTER_AT
	if fx == "dash":
		var go := clampf((t - ACT_AT) / 0.45, 0.0, 1.0)
		var back := clampf((t - ACT_AT - 1.0) / 1.0, 0.0, 1.0)
		return home + Vector3(2.0 * ease(go, 0.4) * (1.0 - ease(back, -1.8)), 0, 0)
	if fx == "beam":
		var kick := clampf((t - ACT_AT - 0.75) / 0.12, 0.0, 1.0) * (1.0 - clampf((t - ACT_AT - 1.2) / 0.6, 0.0, 1.0))
		return home - Vector3(0.35 * kick, 0, 0)
	return home

## The animation state: the kit's own move when it has one, else the weapon's swing or shots, or a cast.
func _state() -> Dictionary:
	var s := {"fired": 99.0, "face": -PI / 2.0, "grounded": true, "wid": Arch.signature(id)}
	var mt := t - ACT_AT
	if mt >= 0.0 and not _moves.is_empty():
		for m in _moves:
			var length := HunterViewer.move_len(String(m))
			if mt < length:
				s["kmove"] = String(m)
				s["kmove_t"] = mt
				return s
			mt -= length
		return s
	if mt < 0.0:
		return s
	match fx:
		"shots", "spray":
			if mt < 0.7:
				s["fired"] = fmod(mt, 0.15)
				s["recoil"] = clampf(1.0 - fmod(mt, 0.15) / 0.12, 0.0, 1.0)
		"swing":
			if mt < 1.3:
				s["swing_n"] = int(mt / 0.45) + 1
				s["combo"] = int(mt / 0.45) % 3
		"dash":
			if mt < 0.45:
				s["rolling"] = true
				s["dash_dir"] = Vector2(1, 0)
				s["vel"] = Vector3(6.0, 0, 0)
			elif mt > 1.0 and mt < 2.0:
				s["vel"] = Vector3(-2.0, 0, 0)
		_:
			s["cast_slot"] = {"rmb": "secondary", "e": "utility", "x": "ult"}.get(slot, "secondary")
			s["cast"] = mt
	return s

## The dummy is struck: sparks, a flinch, the damage rising off it.
func _hit() -> void:
	if fx in ["heal", "tether", "wall", "dash"]:
		return
	_sparks.position = DUMMY_AT + Vector3(-0.25, 1.0, 0)
	_sparks.restart()
	_flinch = 1.0 if fx in ["bolt", "beam", "strike", "nova", "cone"] else 0.55
	var dmg := _damage()
	if dmg > 0:
		_number.text = str(dmg)
		_number.position = DUMMY_AT + Vector3(0.1, 1.8, 0.3)
		_number.modulate.a = 1.0
		_number.visible = true

## The hit's damage from the ability's own numbers (0 when it has none to show).
func _damage() -> int:
	if slot == "lmb":
		return int(Data.weapon_stats(Arch.signature(id)).get("dmg", 0.0))
	var sd: Dictionary = Arch.def(id).get(slot, {})
	for k in ["dmg", "hit_dmg", "damage"]:
		if sd.has(k):
			return int(sd[k])
	for sub in sd.values():
		if sub is Dictionary and (sub as Dictionary).has("hit_dmg"):
			return int(sub["hit_dmg"])
	return 0

func _place(nm: String, from: Vector3, to: Vector3, width: float, height := 0.0) -> void:
	var mi: MeshInstance3D = _parts[nm]
	var d := to - from
	mi.visible = d.length() > 0.01
	if not mi.visible:
		return
	var up := Vector3.UP if absf(d.normalized().y) < 0.9 else Vector3.BACK
	var spot := Transform3D(Basis.looking_at(d.normalized(), up), (from + to) * 0.5)
	mi.transform = spot.scaled_local(Vector3(width, maxf(height, width), d.length()))

func _show_fx() -> void:
	for p in _parts.values():
		(p as Node3D).visible = false
	var mt := t - ACT_AT
	var muzzle := _hunter_pos() + Vector3(0.45, 1.05, 0.05)
	var chest := DUMMY_AT + Vector3(-0.2, 1.0, 0)
	match fx:
		"shots":
			if mt >= 0.0 and mt < 0.7 and fmod(mt, 0.15) < 0.06:
				_place("tracer", muzzle, chest + Vector3(0, randf_range(-0.08, 0.08), 0), 0.03)
		"spray":
			if mt >= 0.0 and mt < 1.0:
				var reach := minf(1.0, mt / 0.15)
				_place("beam", muzzle, muzzle.lerp(chest, reach), 0.18 + 0.1 * sin(t * 40.0))
		"bolt":
			if mt >= 0.0 and mt < 0.5:
				_place("lane", HUNTER_AT + Vector3(0.3, 0.03, 0), DUMMY_AT + Vector3(0.6, 0.03, 0), 0.5, 0.01)
			elif mt >= 0.5 and mt < 0.75:
				_parts["orb"].visible = true
				var fly := (mt - 0.5) / 0.25
				_parts["orb"].position = muzzle.lerp(chest, fly) + Vector3(0, sin(fly * PI) * 0.3, 0)
			elif mt >= 0.75 and mt < 1.0:
				_burst(chest, (mt - 0.75) / 0.25, 1.2)
		"beam":
			if mt >= 0.0 and mt < 0.75:
				_place("lane", muzzle, muzzle + Vector3(5.0, 0, 0), lerpf(0.6, 0.04, mt / 0.75), 0.01)
			elif mt >= 0.75 and mt < 1.0:
				_place("beam", muzzle, muzzle + Vector3(5.0, 0, 0), 0.16 * (1.0 - (mt - 0.75) / 0.25) + 0.03)
		"nova", "heal":
			if mt >= 0.0 and mt < 0.6:
				var r := ease(mt / 0.6, 0.4) * (4.2 if fx == "nova" else 2.0)
				_disc("ring", _hunter_pos(), r, 1.0 - mt / 0.6)
		"cone":
			if mt >= 0.1 and mt < 0.45:
				_place("lane", _hunter_pos() + Vector3(0.3, 0.6, 0), chest + Vector3(0.4, 0, 0), 0.9 * (mt / 0.45), 0.6)
		"zone":
			if mt >= 0.0 and mt < 1.6:
				_disc("disc", DUMMY_AT, 2.2, 0.6 + 0.3 * sin(mt * 9.0))
		"strike":
			if mt >= 0.1 and mt < 1.3:
				_disc("ring", DUMMY_AT, 2.6, 1.0)
				_disc("disc", DUMMY_AT, 2.6 * (mt - 0.1) / 1.2, 0.7)
			if mt >= 1.15 and mt < 1.35:
				_parts["orb"].visible = true
				_parts["orb"].position = DUMMY_AT + Vector3(0, 6.0 * (1.0 - (mt - 1.15) / 0.2), 0)
			elif mt >= 1.35 and mt < 1.75:
				_burst(DUMMY_AT + Vector3(0, 0.3, 0), (mt - 1.35) / 0.4, 2.2)
		"wall":
			if mt >= 0.0 and mt < 1.8:
				var w: MeshInstance3D = _parts["wall"]
				w.visible = true
				w.position = Vector3(0.3, -0.7 + 1.4 * ease(minf(1.0, mt / 0.25), 0.3), 0)
		"tether":
			if mt >= 0.0 and mt < 1.8:
				_place("beam", muzzle, chest, 0.05 + 0.03 * sin(mt * 14.0))
		"dash":
			if mt >= 0.0 and mt < 0.6:
				var tail := HUNTER_AT + Vector3(0, 0.7, 0)
				_place("trail", tail, _hunter_pos() + Vector3(-0.2, 0.7, 0), 0.5 * (1.0 - mt / 0.6), 0.9)

func _disc(nm: String, at: Vector3, radius: float, alpha: float) -> void:
	var mi: MeshInstance3D = _parts[nm]
	mi.visible = radius > 0.01
	mi.position = at + Vector3(0, 0.03, 0)
	mi.scale = Vector3(radius, 1.0, radius)
	(mi.material_override as ShaderMaterial).set_shader_parameter("color", Color(col, clampf(alpha, 0.0, 1.0)))

## A soft flash at a hit: it swells and fades over k = 0..1.
func _burst(at: Vector3, k: float, big: float) -> void:
	var f: MeshInstance3D = _parts["flash"]
	f.visible = true
	f.position = at
	f.scale = Vector3.ONE * (0.3 + big * ease(k, 0.3))
	(f.material_override as ShaderMaterial).set_shader_parameter("color", Color(col.lightened(0.4), 1.0 - k))
