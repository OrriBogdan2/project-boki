class_name StunMark
extends Node3D
## The stun marker: while a Hunter or a monster is stunned, a spiral turns over its head with three stars
## circling it, and it fades out as the stun runs out. The source shows a marker on every stun
## (briefs/hero-ref: dredge.md "a dark spiral over its head", dancer.md "a stun swirl over the target",
## breah.md "stun stars"); its size and colour are not recorded [?], so it takes the overhead plate's STUNNED
## yellow. One look for every stun, whoever caused it. Boki keep their own dizzy stars (KinPuppet).
## One node per match (StunMark.of(m)) with a fixed pool built once: a body's render asks for its mark every
## frame while it is stunned, and a mark nobody asked for since the last frame goes back to the pool.

const SPIRAL: Shader = preload("res://shaders/ld_fx.gdshader")
const SPIRAL_GLOW: Shader = preload("res://shaders/ld_fx_glow.gdshader")
const POOL := 8                # marks at once; a ninth stunned body shows only its plate word
const SIZE := 0.3              # m, the spiral's half width
const STAR_R := 0.36           # m, the stars' orbit
const STAR_SIZE := 0.13        # m, a star's width
const SPIN := 6.5              # rad/s the stars circle
const FADE_OUT := 0.2          # s before the stun ends that the mark fades
const UNDER_PLATE := 0.2       # m under a Hunter's overhead plate (HudPlate.plate_offset): just over the head
const ABOVE_OTHER := 1.5       # m over a monster's feet
const COL := Color("fff27a")   # the STUNNED word's colour (HudPlate.statuses)
const DARK := Color("3a3008")  # the spiral's dark inner band, so it reads on bright ground

var marks: Array[Node3D] = []
var spirals: Array[ShaderMaterial] = []
var whose: Array = []                  # the body each mark is on, null when free
var seen := PackedInt64Array()         # the frame each mark was last asked for
var fades := PackedFloat32Array()

static func of(match_node: Node) -> StunMark:
	var n: StunMark = match_node.get_node_or_null("StunMark")
	if n == null:
		n = StunMark.new()
		n.name = "StunMark"
		match_node.add_child(n)
		n._build()
	return n

func _build() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var star_mesh := Models.box(STAR_SIZE, STAR_SIZE, 0.04)
	var star_mat := Models.glow_mat(COL)
	for i in POOL:
		var mark := Node3D.new()
		mark.top_level = true
		mark.visible = false
		add_child(mark)
		var body := ShaderMaterial.new()
		body.shader = SPIRAL
		body.next_pass = ShaderMaterial.new()
		(body.next_pass as ShaderMaterial).shader = SPIRAL_GLOW
		for mt: ShaderMaterial in [body, body.next_pass]:
			mt.set_shader_parameter("mode", LDFx.M_SPIRAL)
			mt.set_shader_parameter("color", COL)
			mt.set_shader_parameter("color2", DARK)
			mt.set_shader_parameter("billboard", true)
		var spiral := MeshInstance3D.new()
		spiral.mesh = quad
		spiral.material_override = body
		spiral.scale = Vector3.ONE * SIZE
		spiral.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.add_child(spiral)
		var stars := Node3D.new()
		stars.name = "Stars"
		mark.add_child(stars)
		for s in 3:
			var a := TAU * s / 3.0
			Models.part(stars, star_mesh, star_mat, Vector3(cos(a) * STAR_R, 0.0, sin(a) * STAR_R), Vector3.ONE,
				Vector3(0, a, PI * 0.25))
		marks.append(mark)
		spirals.append(body)
		whose.append(null)
	seen.resize(POOL)
	fades.resize(POOL)
	set_process(false)

## Shows `e`'s mark this frame: call it every rendered frame while `e.stun_t` > 0.
func show_on(e: Ent) -> void:
	var i := whose.find(e)
	if i < 0:
		i = whose.find(null)
		if i < 0:
			return
		whose[i] = e
		fades[i] = -1.0
		marks[i].visible = true
	seen[i] = Engine.get_process_frames()
	var up := HudPlate.plate_offset(e as Hunter) - UNDER_PLATE if e is Hunter else ABOVE_OTHER
	marks[i].global_position = e.global_position + Vector3(0, up, 0)
	var fade := clampf(e.stun_t / FADE_OUT, 0.0, 1.0)
	if fade != fades[i]:
		fades[i] = fade
		marks[i].scale = Vector3.ONE * (0.6 + 0.4 * fade)
		spirals[i].set_shader_parameter("strength", fade)
		(spirals[i].next_pass as ShaderMaterial).set_shader_parameter("strength", fade)
	set_process(true)

## Whether `e` shows a stun mark now (checks).
func on(e: Ent) -> bool:
	var i := whose.find(e)
	return i >= 0 and marks[i].visible

## One mark held up where the loading screen looks, so the spiral's shader compiles before the first stun.
func prewarm(at: Vector3) -> void:
	marks[0].global_position = at
	marks[0].visible = true
	seen[0] = Engine.get_process_frames()
	set_process(true)

func _process(delta: float) -> void:
	var stale := Engine.get_process_frames() - 1
	var busy := false
	for i in POOL:
		if not marks[i].visible:
			continue
		if seen[i] < stale or (whose[i] != null and not is_instance_valid(whose[i])):
			marks[i].visible = false
			whose[i] = null
			continue
		busy = true
		(marks[i].get_child(1) as Node3D).rotate_y(delta * SPIN)
	set_process(busy)
