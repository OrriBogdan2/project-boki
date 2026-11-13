class_name BokiWake
extends MultiMeshInstance3D
## The marks Boki leave in pond water (BokiWade): a ripple ring under each Boki in the water, a wave running
## out from its body every ripple_secs, and a short V wake opening behind it while it moves. Every mark is a
## quad in this one MultiMesh, so all of them together are one draw call (shaders/boki_wake.gdshader draws
## the ring or the V, faded out past the water's edge). Sized by the Boki's body. The pool is made once, when
## the first Boki steps in, and never on Very Low. A Boki's marks fade out once BokiWade stops marking it: it
## left the water (or was carried off).

const SLOTS := 16            # Boki marked at once (GARDEN.md 10.6 has 9 out in a zone); more go unmarked
const RING_R := 0.7          # m: the ring's outer radius for a size-1 body (its waves start at the body's edge)
const WAKE_L := 1.4          # m: how far the V reaches behind a size-1 body
const WAKE_SPREAD := 0.75    # the V's width at its end over its length: arms about 20 degrees off the line
const BOW := 0.25            # m ahead of a size-1 body's centre where the V's arms meet
const WAKE_MIN := 0.3        # m/s: slower than this leaves no V
const WAKE_FULL := 0.9       # m/s: from this speed the V shows fully (a walk through deep water is about 1.1)
const MARK_Y := 0.075        # m above the ground: over the pond's surface (0.05) and its swell
const BODY_MAX := 2.6        # the biggest body a mark grows for (a big evolved partner)
const FADE_S := 0.35         # s for a mark to fade in or out

## One marked Boki.
class Slot:
	var uid := ""                  # the Boki's uid, "" while the slot is free
	var at := Vector3.ZERO
	var back := Vector3.BACK       # unit, along the ground: behind it on its last heading
	var speed := 0.0               # m/s
	var body := 1.0                # its size (its node's scale on the farm)
	var phase := 0.0               # 0..1: its ring's waves' offset in time
	var fresh := false             # BokiWade marked it since the last tick: it is still in the water
	var ring := 0.0                # 0..1: how strongly its ring shows
	var wake := 0.0                # 0..1: how strongly its V shows

var slots: Array[Slot] = []
var mask: Image                   # the water the marks are clipped to: one texel per 1 m tile, 1 for water
var mask_origin := Vector2i.ZERO  # the tile at the mask's first texel

func _init(period: float) -> void:
	name = "BokiWake"
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = SLOTS * 2
	multimesh.visible_instance_count = 0
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/boki_wake.gdshader")
	mat.set_shader_parameter("period", period)
	mat.render_priority = 1      # after the Glasswater shallows' see-through sheet
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	for i in SLOTS:
		slots.append(Slot.new())

func _process(delta: float) -> void:
	tick(delta)

## A Boki in the water this frame: where it is, its velocity (m/s) and its body size.
func mark(uid: String, at: Vector3, vel: Vector3, body: float) -> void:
	var s := _slot_of(uid)
	if s == null:
		return
	s.at = at
	s.speed = Vector2(vel.x, vel.z).length()
	if s.speed > WAKE_MIN:
		s.back = Vector3(-vel.x, 0.0, -vel.z) / s.speed
	s.body = minf(body, BODY_MAX)
	s.fresh = true
	set_process(true)

## Fades every mark toward its Boki's state, frees those faded out and writes the rest into the MultiMesh.
func tick(delta: float) -> void:
	var shown := 0
	for s in slots:
		if s.uid == "":
			continue
		var wet := s.fresh
		s.fresh = false
		var go := clampf((s.speed - WAKE_MIN) / (WAKE_FULL - WAKE_MIN), 0.0, 1.0) if wet else 0.0
		s.ring = move_toward(s.ring, 1.0 if wet else 0.0, delta / FADE_S)
		s.wake = move_toward(s.wake, go, delta / FADE_S)
		if s.ring <= 0.0 and s.wake <= 0.0:
			s.uid = ""
			continue
		multimesh.set_instance_transform(shown, ring_place(s))
		multimesh.set_instance_custom_data(shown, Color(0.0, s.phase, s.ring, 0.0))
		shown += 1
		if s.wake > 0.0:
			multimesh.set_instance_transform(shown, wake_place(s))
			multimesh.set_instance_custom_data(shown, Color(1.0, 0.0, s.wake, 0.0))
			shown += 1
	multimesh.visible_instance_count = shown
	visible = shown > 0
	set_process(shown > 0)      # nothing left to fade: idle until the next mark

## Keeps the marks on the water: a mask of the water tiles (HomeLayout keys, 1 m each) with a dry border, which
## the shader fades the marks by. Called when the marks are made and whenever the water is repainted.
func clip_to(tiles: Dictionary) -> void:
	if tiles.is_empty():
		return
	var cells: Array[Vector2i] = []
	for key in tiles:
		cells.append(HomeLayout.unkey(key))
	var low := cells[0]
	var high := cells[0]
	for c in cells:
		low = low.min(c)
		high = high.max(c)
	low -= Vector2i.ONE
	var span := high - low + Vector2i(2, 2)
	mask = Image.create_empty(span.x, span.y, false, Image.FORMAT_R8)
	mask_origin = low
	for c in cells:
		mask.set_pixelv(c - low, Color.WHITE)
	var mat := material_override as ShaderMaterial
	mat.set_shader_parameter("water_mask", ImageTexture.create_from_image(mask))
	mat.set_shader_parameter("mask_origin", Vector2(low))
	mat.set_shader_parameter("mask_span", Vector2(span))

## Where a Boki's ring lies on the water and how wide it is.
func ring_place(s: Slot) -> Transform3D:
	var across := 2.0 * RING_R * s.body
	return Transform3D(Basis.from_scale(Vector3(across, 1.0, across)), s.at + Vector3(0.0, MARK_Y, 0.0))

## Where a Boki's V lies: the quad's +z runs back from the bow, so its arms open behind the Boki.
func wake_place(s: Slot) -> Transform3D:
	var length := WAKE_L * s.body
	var side := Vector3.UP.cross(s.back)
	var turn := Basis(side * length * WAKE_SPREAD, Vector3.UP, s.back * length)
	return Transform3D(turn, s.at + s.back * (length * 0.5 - BOW * s.body) + Vector3(0.0, MARK_Y, 0.0))

func _slot_of(uid: String) -> Slot:
	var spare: Slot = null
	for s in slots:
		if s.uid == uid:
			return s
		if s.uid == "" and spare == null:
			spare = s
	if spare:
		spare.uid = uid
		spare.phase = randf()
		spare.ring = 0.0
		spare.wake = 0.0
	return spare
