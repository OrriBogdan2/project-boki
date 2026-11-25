class_name HeroVfxZone
extends RefCounted
## The ground zones of a Hero's kit (Gil's slime puddle, Meeko's seed field and Hearthlight, Motley's well) on the
## games that don't run that kit. A remote hunter is a puppet, so its kit's zone looks never draw there; the zone
## rides its move's "hvfx" message instead (HeroVfx.play: `o` "life", "zone_r", "follow", "zone") and this draws it
## for that long: the zone rule's lit rim on the radius over a soft inside (docs/VFX_QUALITY.md), a white flare as
## it lands and an ease-out fade before it ends. Gil's own puddle is this same look (make + glow).
## A kit that moves or ends its zone early sends it again under the same key on a beat it already plays (its
## motes): the zone moves there and lives on for `life` more, so a zone ended on its caster's game goes within
## one beat plus FADE here. Colours: the move's data "zone" {"rim", "in"} (palette names or hex), else the Hero's.

const PEAK := 0.05  # s the rim holds its white flare as it lands (3 frames at 60 fps)
const SETTLE := 0.25  # s from landing to its steady glow (the flare eases out)
const FADE := 0.4  # s it fades on an ease-out curve before it ends
const FLARE := 0.6  # how far toward white the rim flares as it lands
const RIM_W := 0.06  # share of the radius the lit rim takes
const RIM_A := 0.85  # the rim's steady alpha
const IN_A := 0.8  # the inside's alpha: the ring shader's wash tops out at 0.3 of it (0.24 by the rim)
const PAD := 0.1  # s a refreshed zone's life runs past its beat plus FADE, so it never dims between beats

var vfx: HeroVfx
var live := {}  # key -> the look (make) plus {t, left, follow}
var _n := 0  # for keys of zones sent once (each its own)


func _init(owner_vfx: HeroVfx) -> void:
	vfx = owner_vfx


## The look, radius r at `at`: the inside's wash in `in_col` under a lit rim in `rim_col`. Returns
## {node, rim, inside, sig}; glow() runs its life.
static func make(parent: Node, at: Vector3, r: float, rim_col: Color, in_col: Color) -> Dictionary:
	var n := Node3D.new()
	var quad := Models.flat_quad(r * 2.0)
	var inside := Models.ring_mat(Color(in_col, IN_A), 0.0)
	inside.set_shader_parameter("wash", 1.0)
	var rim := Models.ring_mat(rim_col, RIM_W)
	rim.set_shader_parameter("halo", 1.0)
	Models.part(n, quad, inside, Vector3(0, 0.06, 0))
	Models.part(n, quad, rim, Vector3(0, 0.08, 0))
	ShadowPolicy.off(n)
	parent.add_child(n)
	n.global_position = at
	return {"node": n, "rim": rim, "inside": inside, "sig": rim_col}


## The glow `age` s after it landed with `left` s to go: the rim's flare, then steady, then the ease-out fade.
static func glow(z: Dictionary, age: float, left: float) -> void:
	if age > SETTLE and left > FADE:
		return
	var flare := pow(1.0 - clampf((age - PEAK) / (SETTLE - PEAK), 0.0, 1.0), 2.0)
	var fade := pow(clampf(left / FADE, 0.0, 1.0), 2.0)
	var sig: Color = z["sig"]
	(z["rim"] as ShaderMaterial).set_shader_parameter(
		"color", Color(sig.lerp(Color.WHITE, FLARE * flare), lerpf(RIM_A, 1.0, flare) * fade)
	)
	var inside: ShaderMaterial = z["inside"]
	inside.set_shader_parameter("color", Color(inside.get_shader_parameter("color"), IN_A * fade))


## A remote hunter's zone arrived: draw it for `life` s, or move and renew the one under the same key.
func put(h: Hunter, key: String, look: Dictionary, at: Vector3, r: float, life: float, follow: Ent) -> void:
	if key == "":
		_n += 1
		key = "#%d" % _n
	key = "%s/%s" % [h.nid, key]
	var z: Dictionary = live.get(key, {})
	if z.is_empty() or not is_equal_approx(float(z["r"]), r):
		_drop(key)
		var rim := vfx.color(h, String(look["rim"])) if look.has("rim") else Arch.color(h.arch)
		var in_col := vfx.color(h, String(look["in"])) if look.has("in") else rim
		z = make(vfx.m, at, r, rim, in_col)
		z.merge({"t": 0.0, "r": r})
		live[key] = z
	(z["node"] as Node3D).global_position = at
	z["left"] = life
	z["follow"] = follow


func tick(dt: float) -> void:
	for key: String in live.keys():
		var z: Dictionary = live[key]
		z["t"] = float(z["t"]) + dt
		z["left"] = float(z["left"]) - dt
		if float(z["left"]) <= 0.0:
			_drop(key)
			continue
		var f: Variant = z["follow"]
		if f != null and is_instance_valid(f):
			(z["node"] as Node3D).global_position = (f as Ent).pos
		glow(z, float(z["t"]), float(z["left"]))


func _drop(key: String) -> void:
	var z: Dictionary = live.get(key, {})
	if not z.is_empty():
		(z["node"] as Node3D).queue_free()
		live.erase(key)
