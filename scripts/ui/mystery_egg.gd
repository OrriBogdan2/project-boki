class_name MysteryEgg
extends Node3D
## The mystery egg of the hatch scene (the owner's call in briefs/DECISIONS.md): a black egg in a
## small woven basket, tucked at the back of the dais among rocks and flowers, with a faint glint on
## its shell now and then so a curious player finds it. This node is the basket and the glint (the
## egg itself is an EggHatch the hatch scene puts on top); the draw and the mutation odds come from
## content/rules/mystery_egg.json.

const PATH := "res://content/rules/mystery_egg.json"
const SHELL := Color("17131f")      # the black shell
const SPOTS := Color("3d3352")      # faint plum speckles on it
const GLINT_EVERY := 3.4            # s between two glints on the shell
const GLINT_LEN := 0.4              # s one glint lasts
const GLINT_SIZE := 0.09            # m: the glint's widest

static var _rules: Dictionary = {}

var glint: Node3D
var t := 0.0

static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _rules

## {species: tickets}: each pool species' roster rarity as its share of the draw.
static func weights() -> Dictionary:
	var r := rules()
	var out := {}
	for sp in r["pool"]:
		if Data.KIN.has(sp):
			out[sp] = int(r["weights"][r["pool"][sp]])
	return out

## The species inside: a draw weighted by rarity, so a rare one hatches now and then.
static func roll_species(rng: RandomNumberGenerator) -> String:
	var w := weights()
	var total := 0
	for sp in w:
		total += int(w[sp])
	var ticket := rng.randi_range(1, maxi(1, total))
	for sp in w:
		ticket -= int(w[sp])
		if ticket <= 0:
			return sp
	return "cindle"

## Its mutations at birth: Mutations' own roll at mutation_mult times the base odds.
static func roll_mutations(rng: RandomNumberGenerator) -> Array:
	return Mutations.roll(rng, float(rules()["mutation_mult"]))

## Cover for the basket at `at`: mossy rocks and a few flowers in front, low enough that the top
## of the egg still shows over them.
static func hideout(parent: Node3D, at: Vector3) -> void:
	var rr := RandomNumberGenerator.new()
	rr.seed = 11
	for spec in [[Vector3(-0.45, 0, 0.5), 0.36], [Vector3(0.3, 0, 0.62), 0.27], [Vector3(0.62, 0, 0.12), 0.42]]:
		var rk := Models.rock(rr, spec[1])
		rk.position = at + spec[0]
		parent.add_child(rk)
	var fb := Models.flower_bed(rr, 6)
	fb.position = at + Vector3(-0.1, 0, 0.78)
	fb.scale = Vector3.ONE * 0.75
	parent.add_child(fb)

func _init() -> void:
	var wicker := Models.toon(Color("b4894e"))
	var weave := Models.toon(Color("7d5a30"))
	var straw := Models.toon(Color("e6c873"), false)
	Models.part(self, Models.cyl(0.42, 0.33, 0.24, 18), wicker, Vector3(0, 0.12, 0))
	# woven look: darker bands round the side, upright staves, and a thick rolled rim
	for k in 2:
		var band := Models.cyl(0.37 + 0.04 * k, 0.36 + 0.04 * k, 0.035, 18)
		Models.part(self, band, weave, Vector3(0, 0.06 + 0.09 * k, 0))
	for i in 10:
		var a := TAU * i / 10.0
		var st := Models.part(self, Models.box(0.04, 0.26, 0.03), weave, Vector3(cos(a) * 0.375, 0.12, sin(a) * 0.375))
		st.rotation = Vector3(0, -a, 0.2)
	Models.part(self, Models.cyl(0.45, 0.45, 0.05, 18), weave, Vector3(0, 0.25, 0))
	# straw poking over the rim
	for i in 9:
		var a := TAU * i / 9.0 + 0.3
		var sw := Models.part(self, Models.box(0.02, 0.16, 0.02), straw, Vector3(cos(a) * 0.36, 0.28, sin(a) * 0.36))
		sw.rotation = Vector3(sin(a) * 0.7, 0, -cos(a) * 0.7)
	# the glint: a small four-point star that flashes on the shell now and then
	glint = Node3D.new()
	var gm := Models.glow_mat(Color(1.0, 0.95, 0.85, 0.9))
	for arm in [Vector3(GLINT_SIZE, 0.012, 0.004), Vector3(0.012, GLINT_SIZE, 0.004)]:
		var g := Models.part(glint, Models.box(arm.x, arm.y, arm.z), gm)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glint.position = Vector3(0.15, 0.75, 0.26)      # on the shell's upper front, where the light catches it
	glint.visible = false
	add_child(glint)

func _process(delta: float) -> void:
	t += delta
	var phase := fmod(t, GLINT_EVERY)
	glint.visible = phase < GLINT_LEN
	if glint.visible:
		glint.scale = Vector3.ONE * sin(phase / GLINT_LEN * PI)
		glint.rotation.z = phase * 2.0
