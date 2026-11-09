class_name DropReticle
extends Node3D
## Where you will land if you keep steering as you are: a team-coloured ring on the ground with a soft
## pulse and a beam up to you, red with a warning over the void. Squadmates still dropping show smaller.

const RADIUS := 3.0           # m, your ring
const MATE_RADIUS := 1.5      # m, a squadmate's
const BEAM_R := 0.14          # m
const STEP := 0.1             # s, projection step
const MAX_STEPS := 120
const PULSE_HZ := 0.8
const RED := Color(1.0, 0.25, 0.2)

var ring: MeshInstance3D
var beam: MeshInstance3D
var tag: Label3D
var ring_mat: ShaderMaterial
var beam_mat: StandardMaterial3D
var t := 0.0

## Per frame, from the local hunter's render: makes the reticle on first use, hides it once landed.
static func tick(h: Hunter, delta: float) -> void:
	var r: DropReticle = h.get_node_or_null("DropReticle")
	if r == null:
		if not (h.dropping and h.is_local()):
			return
		r = DropReticle.new()
		r.name = "DropReticle"
		r.top_level = true
		h.add_child(r)
		r._build()
	r.visible = h.dropping and not h.grounded
	if r.visible:
		r._update(h, delta)

## Where `h` comes down (x, y = ground height, z) and whether that's over the void, if it keeps steering with `mv`.
static func project(h: Hunter, mv: Vector2) -> Dictionary:
	var w: World = h.m.world
	var hv := Vector2(h.vel.x, h.vel.z)
	var p := h.pos
	var vy := h.vel.y
	var diving := h.diving
	for i in MAX_STEPS:
		var void_here := w.is_void(p.x, p.z)
		var gy: float = World.VOID if void_here else w.ground_at(p.x, p.z)
		var above := p.y - (0.0 if void_here else gy)
		if above <= 0.0:
			return {"at": Vector3(p.x, 0.0 if void_here else gy, p.z), "void": void_here}
		diving = diving and above >= Hunter.DEPLOY_H
		hv = DropFeel.steer(hv, mv, diving, STEP)
		var sink := Hunter.DIVE_FALL if diving else Hunter.DROP_FALL
		vy = DropFeel.fall_vy(vy, sink, Hunter.DIVE_VY_RATE if diving else Hunter.DROP_VY_RATE, above, STEP)
		p += Vector3(hv.x, vy, hv.y) * STEP
	return {"at": Vector3(p.x, 0.0, p.z), "void": true}

func _build() -> void:
	ring = MeshInstance3D.new()
	ring.mesh = Models.flat_quad(2.0)
	ring_mat = Models.ring_mat(Color.WHITE, 0.12)
	ring_mat.set_shader_parameter("fill", 0.18)
	ring.material_override = ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = BEAM_R
	cyl.bottom_radius = BEAM_R
	cyl.height = 1.0
	cyl.radial_segments = 8
	beam.mesh = cyl
	beam_mat = StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = beam_mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	tag = Label3D.new()
	tag.text = "OVER THE VOID"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.font_size = 64
	tag.pixel_size = 0.012
	tag.modulate = RED
	add_child(tag)

func _update(h: Hunter, delta: float) -> void:
	t += delta
	var land := project(h, h.inp["move"])
	var at: Vector3 = land["at"]
	var over_void: bool = land["void"]
	var col: Color = RED if over_void else Data.TEAM_COLORS[h.team % Data.TEAM_COLORS.size()]
	var pulse := 1.0 + 0.07 * sin(t * TAU * PULSE_HZ)
	_place(at, RADIUS * pulse, col, h.pos.y, 1.0)
	tag.visible = over_void
	tag.position = Vector3(0, 2.2, 0)
	var k := 0
	for o in h.m.hunters:
		if o == h or o.team != h.team or not o.dropping or o.out:
			continue
		var mate := _mate(k)
		var mv := (Vector2(o.vel.x, o.vel.z) / Hunter.GLIDE_SPEED).limit_length(1.0)
		var ml := project(o, mv)
		mate._place(ml["at"], MATE_RADIUS, RED if ml["void"] else col, o.pos.y, 0.55)
		mate.visible = true
		k += 1
	for j in range(k, get_child_count()):
		var c := get_child(j)
		if c is DropReticle:
			c.visible = false

## A squadmate's marker: another reticle without a tag, kept as a child.
func _mate(i: int) -> DropReticle:
	var mates := get_children().filter(func(c): return c is DropReticle)
	if i < mates.size():
		return mates[i]
	var r := DropReticle.new()
	r.top_level = true
	add_child(r)
	r._build()
	r.tag.queue_free()
	return r

func _place(at: Vector3, radius: float, col: Color, top_y: float, alpha: float) -> void:
	var base := Vector3(at.x, at.y + 0.12, at.z)
	ring.global_position = base
	ring.scale = Vector3.ONE * radius
	col.a = alpha
	ring_mat.set_shader_parameter("color", col)
	var hgt := maxf(top_y - base.y, 0.1)
	beam.global_position = base + Vector3(0, hgt * 0.5, 0)
	beam.scale = Vector3(1.0, hgt, 1.0)
	col.a = 0.35 * alpha
	beam_mat.albedo_color = col
