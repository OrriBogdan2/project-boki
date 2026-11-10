class_name WallImpact
extends Node3D
## Where a body hit the wall it was stunned on: a short crack decal on the surface and a small dust puff,
## about LIFE s, stone-coloured with the attacker's colour on the rim. A fixed pool of POOL decals (the oldest
## is reused); no ring on the ground. It listens to CombatBus.wall_stunned, which KnockWall raises once per
## stun, so no kit draws it. Checked by --wall-stun-check.

const POOL := 6                 # decals alive at once
const LIFE := 0.6               # s from stamp to gone
const HOLD := 0.3               # s the crack stays full strength before it fades
const SIZE := 1.8               # m, the quad's side
const LEAN := 0.7071          # sin 45: the quad's top edge sits on the wall at the contact point
const LIFT := 0.04              # m off the wall, so the quad is not inside it
const DEDUPE := 0.5             # s: a second source stunning the same body on the same wall is the same stun
const STONE_DUST := Color(0.62, 0.6, 0.56, 0.85)
const STONE := Color(0.16, 0.15, 0.14)
const NEUTRAL_RIM := Color(0.85, 0.82, 0.74)
const TEX := 64                 # px, the crack texture's side
const ARMS := 6                 # cracks running out from the point of impact

static var _tex: ImageTexture

var placed := 0                 # decals stamped so far (--wall-stun-check reads it)
var last_at := Vector3.ZERO     # where the latest one went
var last_normal := Vector3.ZERO
var _slots: Array[MeshInstance3D] = []
var _age: Array[float] = []     # s since each slot was stamped (LIFE or more = free)
var _next := 0
var _seen := {}                 # body id -> match time of its last decal
var _fx: Fx

func _init(fx: Fx = null) -> void:
	_fx = fx

func _ready() -> void:
	var sh: Shader = load("res://shaders/wall_crack.gdshader")
	for i in POOL:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(SIZE, SIZE)
		mi.mesh = q
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("crack", _crack_tex())
		mat.set_shader_parameter("stone", Vector3(STONE.r, STONE.g, STONE.b))
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_slots.append(mi)
		_age.append(LIFE)
	set_process(false)
	CombatBus.wall_stunned.connect(_on_wall_stunned)

func _on_wall_stunned(target: Node, at: Vector3, normal: Vector3, by: Node) -> void:
	var e := target as Ent
	if e == null or e.m == null or (e.m as Match).fx != _fx:
		return
	var now: float = (e.m as Match).time
	if now - float(_seen.get(e.get_instance_id(), -9.0)) < DEDUPE:
		return
	_seen[e.get_instance_id()] = now
	stamp(at, normal, _rim_of(by))

## One decal hanging from `at` on the wall (`normal` points out of the wall) and a puff of dust in front of it.
## The quad leans out 45 degrees from the wall to the floor, so the top-down camera sees it on any wall face.
func stamp(at: Vector3, normal: Vector3, rim: Color) -> void:
	placed += 1
	last_at = at
	last_normal = normal
	var mi := _slots[_next]
	var mat := mi.material_override as ShaderMaterial
	mat.set_shader_parameter("rim", Vector3(rim.r, rim.g, rim.b))
	mat.set_shader_parameter("fade", 1.0)
	var lean := (normal + Vector3.UP).normalized()
	var look := Basis.looking_at(-lean, Vector3.UP).rotated(lean, TAU * float(placed % 7) / 7.0)
	mi.global_transform = Transform3D(look, at + (normal - Vector3.UP) * (SIZE * 0.5 * LEAN) + normal * LIFT)
	mi.visible = true
	_age[_next] = 0.0
	_next = (_next + 1) % POOL
	set_process(true)
	if _fx != null:
		_fx.dust(at + normal * 0.15, 8, STONE_DUST)

func _process(dt: float) -> void:
	var live := false
	for i in POOL:
		if _age[i] >= LIFE:
			continue
		_age[i] += dt
		var mi := _slots[i]
		if _age[i] >= LIFE:
			mi.visible = false
			continue
		live = true
		var fade := clampf((LIFE - _age[i]) / (LIFE - HOLD), 0.0, 1.0)
		(mi.material_override as ShaderMaterial).set_shader_parameter("fade", fade)
	set_process(live)

## The attacker's hero colour (a Hunter or a Kin's owner); stone-pale for anything else.
static func _rim_of(by: Node) -> Color:
	var h: Ent = by as Ent
	if h is Kin and (h as Kin).owner_h:
		h = (h as Kin).owner_h
	if h is Hunter and (h as Hunter).arch != "":
		return Arch.color((h as Hunter).arch)
	return NEUTRAL_RIM

## Cracks running out of the middle: R is the crack (3 px wide), G a halo one pixel wider on each side.
static func _crack_tex() -> ImageTexture:
	if _tex != null:
		return _tex
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var c := Vector2(TEX, TEX) * 0.5
	for a in ARMS:
		var dir := Vector2.from_angle(TAU * (a + rng.randf_range(-0.2, 0.2)) / ARMS)
		var p := c
		for s in int(TEX * rng.randf_range(0.28, 0.46)):
			dir = dir.rotated(rng.randf_range(-0.35, 0.35))
			p += dir
			for oy in range(-2, 3):
				for ox in range(-2, 3):
					var px := Vector2i(p) + Vector2i(ox, oy)
					var reach := absi(ox) + absi(oy)
					if reach > 2 or px.x < 0 or px.y < 0 or px.x >= TEX or px.y >= TEX:
						continue
					var old := img.get_pixelv(px)
					img.set_pixelv(px, Color(1.0 if reach <= 1 else old.r, 1.0, 0, 1.0))
	_tex = ImageTexture.create_from_image(img)
	return _tex
