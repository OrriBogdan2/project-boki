class_name PrologueVault
extends Node3D
## Malgrave's vault, the set for two prologue panels: THE MASK (her red-and-gold mask over the Wyrmheart on
## its pedestal) and THE THIEF (Sable lifts the Heart, the quake shakes it out of her hands, and it hits the
## floor). Built at the set's centre; the prologue drives it with mask(st) and theft(st). The mask faces +Z,
## where both panels' cameras stand.

const PEDESTAL_TOP := 1.1                  # m: where the Heart rests
const HEART_SIZE := 0.42                   # m: the Heart's lobe radius
const HELD := Vector3(0.55, 1.35, 0.55)    # m: the Heart in Sable's hands
const LIFT_S := Vector2(0.6, 1.8)          # s into THE THIEF: she lifts it off the pedestal
const SLIP_AT := 2.6                       # s: the quake shakes it loose
const FALL_S := 0.45                       # s: its fall to the floor
const MASK_AT := Vector3(0, 3.4, -2.6)     # m: the mask, hung over the pedestal

var heart: Node3D
var heart_light: OmniLight3D
var sable: Node3D
var mask_eyes: Array = []                  # the mask's eye glows (their materials)
var cracked := false                       # the Heart has hit the floor (THE THIEF's beat)

func build(rng: RandomNumberGenerator) -> void:
	var stone := Models.toon(Color("4a3a40"))
	var red := Models.toon(Color("a8142a"))
	var gold := Models.toon(Color("e8b24a"), true, 0.25)
	Models.part(self, Models.cyl(7.5, 8.0, 1.0, 24), stone, Vector3(0, -0.5, 0))
	for i in 8:
		var a := TAU * i / 8.0 + rng.randf_range(-0.05, 0.05)
		var at := Vector3(cos(a), 0, sin(a)) * 6.4
		Models.part(self, Models.cyl(0.5, 0.6, 7.0, 10), stone, at + Vector3(0, 3.5, 0))
		# Solmere's red banners between the pillars, gold-hemmed
		var b := TAU * (i + 0.5) / 8.0
		var hang := Vector3(cos(b), 0, sin(b)) * 6.2 + Vector3(0, 4.0, 0)
		var banner := Models.part(self, Models.box(1.4, 3.2, 0.06), red, hang)
		banner.rotation.y = -b + PI / 2.0
		Models.part(banner, Models.box(1.5, 0.16, 0.08), gold, Vector3(0, -1.6, 0))
	Models.part(self, Models.cyl(0.55, 0.75, PEDESTAL_TOP, 12), stone, Vector3(0, PEDESTAL_TOP / 2.0, 0))
	Models.part(self, Models.cyl(0.62, 0.62, 0.08, 12), gold, Vector3(0, PEDESTAL_TOP, 0))
	_mask(red, gold)
	heart = wyrmheart(self, HEART_SIZE)
	heart.position = Vector3(0, PEDESTAL_TOP + HEART_SIZE * 1.3, 0)
	heart_light = OmniLight3D.new()
	heart_light.light_color = Color("ff5a72")
	heart_light.omni_range = 9.0
	heart_light.light_energy = 2.2
	heart.add_child(heart_light)
	sable = Models.hunter(Arch.weight("thief"), Arch.color("thief"), Arch.signature("thief"), "", {}, "thief")
	(sable.get_node("TeamRing") as Node3D).visible = false
	sable.position = Vector3(1.3, 0, 1.3)
	sable.rotation.y = atan2(1.3, 1.3)      # facing the pedestal
	sable.visible = false
	add_child(sable)

## The Wyrmheart: a real heart's shape in smooth, glossy crimson glass with a soft
## pink-red glow from inside. No gold, no crack. `r` is a lobe's radius in m.
static func wyrmheart(parent: Node3D, r: float) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	var glass := Models.toon(Color("c0122e"), false, 0.9)
	var deep := Models.toon(Color("8a0a22"), false, 0.6)
	Models.part(n, Models.sphere(r, 16), glass, Vector3(-r * 0.45, 0, 0), Vector3(1.0, 1.1, 0.9))
	Models.part(n, Models.sphere(r, 16), glass, Vector3(r * 0.5, 0.1 * r, 0), Vector3(0.9, 1.0, 0.85))
	Models.part(n, Models.cyl(r * 1.05, 0.05, r * 1.5, 16), glass, Vector3(0, -r * 0.95, 0), Vector3.ONE,
		Vector3(0, 0, 0.25))
	# the aorta's arch and the arteries off the top
	Models.part(n, Models.cyl(r * 0.28, r * 0.32, r * 1.1, 10), deep, Vector3(r * 0.1, r * 1.1, 0), Vector3.ONE,
		Vector3(0, 0, -0.3))
	Models.part(n, Models.cyl(r * 0.16, r * 0.2, r * 0.8, 8), deep, Vector3(-r * 0.4, r * 1.0, 0.1 * r), Vector3.ONE,
		Vector3(0, 0, 0.35))
	Models.part(n, Models.cyl(r * 0.14, r * 0.18, r * 0.7, 8), deep, Vector3(r * 0.55, r * 1.25, 0), Vector3.ONE,
		Vector3(0, 0, -0.9))
	return n

## Malgrave's mask, the first mask: a pale-faced woman's mask in red and gold, with eyes that glow.
func _mask(red: Material, gold: Material) -> void:
	var m := Node3D.new()
	m.position = MASK_AT
	add_child(m)
	Models.part(m, Models.sphere(1.0, 20), red, Vector3.ZERO, Vector3(0.85, 1.15, 0.35))
	Models.part(m, Models.box(1.5, 0.12, 0.3), gold, Vector3(0, 0.32, 0.22))
	Models.part(m, Models.cyl(0.0, 0.12, 0.7, 6), gold, Vector3(0, -0.15, 0.3), Vector3.ONE,
		Vector3(-0.2, 0, 0))
	for k in 5:
		var a := -0.9 + k * 0.45
		var tip := Vector3(sin(a) * 0.75, 0.95 + cos(a) * 0.35, 0)
		Models.part(m, Models.cyl(0.0, 0.14, 0.7, 6), gold, tip, Vector3.ONE, Vector3(0, 0, -a))
	for sx in [-1.0, 1.0]:
		var eye := Models.toon(Color("ff6a7a"), false, 0.0)
		Models.part(m, Models.sphere(0.17, 10), eye, Vector3(sx * 0.32, 0.1, 0.3), Vector3(1.4, 0.6, 0.4))
		mask_eyes.append(eye)
		Models.part(m, Models.box(0.5, 0.05, 0.05), gold, Vector3(sx * 0.32, -0.08, 0.33), Vector3.ONE,
		Vector3(0, 0, sx * 0.25))

## THE MASK, `st` s in: the mask's eyes kindle and the Heart beats under it.
func mask(st: float) -> void:
	for e: ShaderMaterial in mask_eyes:
		e.set_shader_parameter("glow", clampf((st - 1.5) / 2.0, 0.0, 1.0) * 1.6)
	_beat(st)

## THE THIEF, `st` s in: Sable lifts the Heart, the quake shakes it loose, it falls and hits the floor
## (`cracked`; the crack itself is never shown).
func theft(st: float) -> void:
	sable.visible = true
	var rest := Vector3(0, PEDESTAL_TOP + HEART_SIZE * 1.3, 0)
	var floor_at := Vector3(0.9, HEART_SIZE * 1.1, 1.2)
	if st < SLIP_AT:
		var k := smoothstep(LIFT_S.x, LIFT_S.y, st)
		heart.position = rest.lerp(HELD, k)
	else:
		var k := clampf((st - SLIP_AT) / FALL_S, 0.0, 1.0)
		heart.position = HELD.lerp(floor_at, k * k)
		heart.rotation.z = k * 1.2
		cracked = k >= 1.0
	_beat(st)
	if cracked:
		heart_light.light_energy = 2.2 + 3.0 * exp(-(st - SLIP_AT - FALL_S) * 3.0)

func _beat(st: float) -> void:
	var b := pow(maxf(0.0, sin(st * 5.2)), 6.0)
	heart.scale = Vector3.ONE * (1.0 + 0.06 * b)
	heart_light.light_energy = 2.0 + 1.2 * b
