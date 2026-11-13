class_name MaskBeat
extends Node
## Putting on a Relic, staged as one beat of about five seconds, slow enough to read (the put-on beat in
## briefs/LORE_MASKS.md): you touch the Relic, a ghostly porcelain face flickers over yours, and the fallen
## Hunter settles over you.
##   1. reach:   the Empty's hand reaches out and touches the Relic, which glides to the face (REACH_S)
##   2. flicker: the Relic hangs at the face while a ghostly porcelain face flickers over it, three times
##               (FLICKER_S)
##   3. fade:    the Hunter's model fades in from the feet up (Unmasked.blend, as Unmasked.worn) while the Empty
##               fades out the same way, then goes to its idle (FADE_S)
## Its sounds follow the beats, never the clock: a porcelain chime on each flicker of the ghost face, a swell
## that rises over the fade, a soft settle at the end (so a longer beat only stretches them).
## With `swap` false (the farm: you stay yourself) it ends after the flicker; the name and title come up at the
## end of the flicker and stay up long enough to read (name_hold). Once a player has seen one
## (Save.d.tutorial.mask_seen) any key skips it. `finished` gets the body standing there at the end.
##
##   MaskBeat.play(relic, you, func(body): ...)
# "mask" in code = "Relic" in game, owner 2026-11-07

signal finished(body: Node3D)

const REACH_S := 1.0           # s the hand takes to touch the Relic
const FLICKER_S := 2.1         # s the porcelain face flickers over yours (0.7 s a flicker)
const FADE_S := 1.9            # s the Hunter takes to fade in from the feet up
const FLICKERS := 3            # how many times the ghost face lights
const FACE_GAP := 0.27         # m in front of the head where the Relic settles (times the body's scale)
const GHOST_GAP := 0.12        # m in front of the head where the ghost face hangs (times the body's scale)
const GHOST_ALPHA := 0.7       # the ghost face at its brightest
const ARM_RAD := 1.5           # rad the reaching arm swings forward from the shoulder
const SPREAD := 0.35           # share of the fade each part takes: the parts come in one after another
const READ_MIN_S := 3.0        # s the name and title stay up at the least (they outlast the beat)
const READ_CHAR_S := 0.06      # s of reading per character, for a longer name and title
const CHIME_AT := 0.17         # share of each flicker gone when its chime sounds (the ghost face is lighting)
const CHIME_RISE := 1.26       # pitch step from one flicker's chime to the next (a major third)
const SWELL_PITCH := Vector2(0.7, 1.5)   # pitch_scale of the swell at the start and the end of the fade
const SWELL_DB := Vector2(-26.0, -8.0)   # volume of the swell at the start and the end of the fade

var id := ""
var mask: MaskRelic
var body: Node3D
var swap := true
var phase := "reach"           # reach | flicker | fade | done
var t := 0.0                   # s into this phase
var skip_hint: Control
var _hunter: Node3D            # the model that fades in (swap only)
var _from_tiers: Array = []    # [part, rank] of the body that fades out, feet (0) to head (1)
var _to_tiers: Array = []      # the same for the Hunter
var _arm: Node3D
var _arm_from := 0.0
var _head := Vector3.ZERO
var _front := Vector3.FORWARD
var _mask_from := Vector3.ZERO
var _ghost: MeshInstance3D
var _anim: HunterAnim
var _chimes := 0               # flickers whose chime has sounded
var heard: Array = []          # [sound, phase, progress 0..1 in it] per sound made (--relic-puton-check)

static func play(relic: MaskRelic, who: Node3D, done: Callable, swap_body := true) -> MaskBeat:
	var b := MaskBeat.new()
	b.mask = relic
	b.id = relic.id
	b.body = who
	b.swap = swap_body
	b.finished.connect(done)
	who.get_parent().add_child(b)
	return b

## Whether the player has seen a Relic go on before (then the beat can be skipped).
static func seen() -> bool:
	return bool(Save.d.get("tutorial", {}).get("mask_seen", false))

func _ready() -> void:
	process_priority = 100      # (after whatever animates the body, so the reaching arm wins)
	_head = (body.get_node("Rig/Torso/HeadPivot") as Node3D).global_position
	_front = Vector3(-body.global_basis.z.x, 0.0, -body.global_basis.z.z).normalized()      # (the farm leans you)
	_mask_from = mask.global_position
	mask.bobbing = false
	mask.face_to = _head + _front * 3.0
	_arm = body.get_node_or_null("Rig/Torso/ArmRPivot")
	if _arm:
		_arm_from = _arm.rotation.x
	if swap:
		_build_hunter()
	if seen():
		skip_hint = UI.label("Any key: skip", 13, Color(1, 1, 1, 0.55))
		skip_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		skip_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		skip_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
		skip_hint.offset_right = -24
		skip_hint.offset_bottom = -18
		var layer := CanvasLayer.new()
		layer.layer = 70
		layer.add_child(skip_hint)
		add_child(layer)

## The Hunter stands where you do, unseen until the fade reaches each part.
func _build_hunter() -> void:
	_hunter = PreviewBuild.model(id)
	Unmasked.blend(_hunter)
	_hunter.position = body.position
	_hunter.rotation = body.rotation
	body.get_parent().add_child(_hunter)
	_anim = HunterAnim.new(_hunter)
	_to_tiers = _tiers(_hunter)
	_from_tiers = _tiers(body)
	_wipe(_to_tiers, 0.0, true)

## The model's parts with a rank from its feet (0) to its head (1), by the height of each part's middle.
func _tiers(model: Node3D) -> Array:
	var out: Array = []
	var lo := INF
	var hi := -INF
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var y := ((m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()).get_center().y
		out.append([m, y])
		lo = minf(lo, y)
		hi = maxf(hi, y)
	for pair in out:
		pair[1] = inverse_lerp(lo, hi, float(pair[1]))
	return out

## Each part is `appear`ing (or going) as the fade k (0..1) passes its rank: feet first, head last.
func _wipe(tiers: Array, k: float, appear: bool) -> void:
	for pair in tiers:
		var a := clampf((k * (1.0 + SPREAD) - float(pair[1])) / SPREAD, 0.0, 1.0)
		var m: MeshInstance3D = pair[0]
		if not appear:
			a = 1.0 - a
		m.visible = a > 0.0
		m.transparency = 1.0 - a

func _process(dt: float) -> void:
	t += dt
	match phase:
		"reach":
			_reach()
		"flicker":
			_flicker()
		"fade":
			_fade(dt)

func _next(to: String) -> void:
	phase = to
	t = 0.0

## The hand comes up and touches the Relic as it glides to the face.
func _reach() -> void:
	var k := clampf(t / REACH_S, 0.0, 1.0)
	var e := 0.5 - 0.5 * cos(PI * k)
	var settle := _head + _front * FACE_GAP * body.scale.y
	mask.global_position = _mask_from.lerp(settle, e) + Vector3.UP * sin(PI * e) * 0.1
	mask.scale = Vector3.ONE * lerpf(MaskRelic.FLOAT_SCALE, body.scale.y * 1.1, e)
	_raise_arm(e)
	if k >= 1.0:
		_next("flicker")
		_ghost_face()

func _raise_arm(e: float) -> void:
	if _arm:
		_arm.rotation.x = lerpf(_arm_from, ARM_RAD, e)

func _ghost_face() -> void:
	_ghost = MeshInstance3D.new()
	_ghost.mesh = MaskRelic.plate_mesh()
	_ghost.material_override = Models.glow_mat(Color(0.97, 0.95, 0.9, 0.0))
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.get_parent().add_child(_ghost)
	var turn := Basis.looking_at(_front, Vector3.UP).scaled(Vector3.ONE * body.scale.y * 1.05)
	_ghost.global_transform = Transform3D(turn, _head + _front * GHOST_GAP * body.scale.y)

## The ghost face lights FLICKERS times, each a little brighter, and the arm settles.
func _flicker() -> void:
	var k := clampf(t / FLICKER_S, 0.0, 1.0)
	_raise_arm(1.0 - smoothstep(0.7, 1.0, k))
	var pulse := pow(sin(PI * k * FLICKERS), 2.0) * lerpf(0.55, 1.0, k)
	(_ghost.material_override as ShaderMaterial).set_shader_parameter("color",
			Color(0.97, 0.95, 0.9, GHOST_ALPHA * pulse))
	while _chimes < FLICKERS and k >= chime_k(_chimes):
		_hear("mask_flicker", k, pow(CHIME_RISE, _chimes))
		_chimes += 1
	if k >= 1.0:
		_settled()

## How far through the flicker (0..1) the ghost face's n-th light gets its chime.
static func chime_k(n: int) -> float:
	return (n + CHIME_AT) / FLICKERS

## One sound of the beat (our own, tools/gen_sfx_mask.py); Sfx lets it ring out after the beat has gone.
func _hear(sound: String, k: float, pitch := 1.0) -> void:
	heard.append([sound, phase, k])
	Sfx.play(sound, null, 0.0, 0.0, pitch)

## The Relic is spent; with `swap` the Hunter starts to come in, else the beat is over.
func _settled() -> void:
	mask.queue_free()
	_ghost.queue_free()
	_show_name()
	if swap:
		_next("fade")
	else:
		_hear("mask_settle", 1.0)
		_finish()

func _fade(dt: float) -> void:
	var k := clampf(t / FADE_S, 0.0, 1.0)
	_wipe(_to_tiers, k, true)
	_wipe(_from_tiers, k, false)
	_idle(dt)
	if not Sfx.loop_on("mask_swell"):
		heard.append(["mask_swell", phase, k])
	Sfx.loop_hold("mask_swell", "mask_swell", null, lerpf(SWELL_DB.x, SWELL_DB.y, k),
			lerpf(SWELL_PITCH.x, SWELL_PITCH.y, k))
	if k >= 1.0:
		Sfx.loop_stop("mask_swell")
		_hear("mask_settle", 1.0)
		_finish()

func _idle(dt: float) -> void:
	_anim.update(dt, {"fired": 99.0, "face": _hunter.rotation.y, "grounded": true, "wid": Arch.signature(id)})

## "Vex, the Hired Gun" across the lower screen, in the Hunter's colour; it outlasts the beat.
func _show_name() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 70
	var box := UI.vbox(0)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.offset_top = -170
	box.set_meta("mask_name", id)
	var text := HunterViewer.display_name(id)
	var nm := UI.title(text, 46, Arch.color(id).lightened(0.15))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_constant_override("outline_size", 12)
	nm.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.06))
	box.add_child(nm)
	layer.add_child(box)
	get_tree().root.add_child(layer)
	UI.pop_in(box)
	var tw := layer.create_tween()
	tw.tween_interval(name_hold(text))
	tw.tween_property(box, "modulate:a", 0.0, 0.3)
	tw.tween_callback(layer.queue_free)

## How long a name and title stay up: long enough to read them.
static func name_hold(text: String) -> float:
	return maxf(READ_MIN_S, READ_CHAR_S * text.length())

func _unhandled_input(event: InputEvent) -> void:
	var press := event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton
	if press and event.is_pressed() and not event.is_echo() and seen() and phase != "done":
		get_viewport().set_input_as_handled()
		skip_now()

## Jumps to the end (the Hunter standing there).
func skip_now() -> void:
	if phase == "done":
		return
	Sfx.loop_stop("mask_swell")
	if phase in ["reach", "flicker"]:
		mask.queue_free()
		if is_instance_valid(_ghost):
			_ghost.queue_free()
	if _arm:
		_arm.rotation.x = _arm_from
	if swap:
		_wipe(_to_tiers, 1.0, true)
		_wipe(_from_tiers, 1.0, false)
	if phase != "fade":
		_show_name()
	_finish()

func _finish() -> void:
	if phase == "done":
		return
	phase = "done"
	Save.d["tutorial"]["mask_seen"] = true
	if _arm:
		_arm.rotation.x = _arm_from
	if swap:
		body.queue_free()
		body = _hunter
	finished.emit(body)
	queue_free()
