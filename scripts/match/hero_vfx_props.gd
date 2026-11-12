class_name HeroVfxProps
extends RefCounted
## The solid props a Hero's look sets in the world: a layer {"p": "prop", "prop": <name>} names one of the Hero's
## "props" in content/vfx/<arch>.json (Grimble's anchor and bone hook). A prop is a few boxes and tapered cylinders in
## one shader: "iron" (opaque with a lit rim, dithered away by its fade) or "bone" (lit, a rim, drawn through walls).
## Played once, it bites into the ground with a squash, stands, then fades over the last `fade` s of its `life`.
## Held, it follows the hold every frame: at the layer's anchor (its `hang` point there, never under the ground with
## "floor"), or with "at": "to" at the hold's point, turned along the reach from the `from` anchor. Pooled per prop.

const IRON: Shader = preload("res://shaders/hero_prop_iron.gdshader")
const BONE: Shader = preload("res://shaders/hero_prop_bone.gdshader")
const POOL_CAP := 4            # nodes per prop at most; past it the oldest is taken back
const SQUASH_T := 0.15         # s a one-shot's squash takes to settle
const CYL_SIDES := 6           # a cylinder part's sides unless it gives "sides"

var vfx: HeroVfx
var pools := {}                # "<arch>/<prop>" -> nodes made for it
var live: Array = []           # one-shots running: {node, layer, at, t}

func _init(played_by: HeroVfx) -> void:
	vfx = played_by

## A pooled node of the Hero's prop, painted with the layer's colours: a hidden one, else a new one (up to
## POOL_CAP), else the oldest in use.
func take(layer: Dictionary, h: Hunter) -> Node3D:
	var key := "%s/%s" % [h.arch, layer["prop"]]
	var arr: Array = pools.get(key, [])
	pools[key] = arr
	var n: Node3D = null
	for each: Node3D in arr:
		if not each.visible:
			n = each
			break
	if n == null and arr.size() < POOL_CAP:
		n = _build(HeroVfx.data(h.arch)["props"][layer["prop"]])
		n.top_level = true
		vfx.add_child(n)
		arr.append(n)
		vfx.made += 1
	elif n == null:
		n = arr.pop_front()
		arr.append(n)
		vfx.drop_entry(n)
		live = live.filter(func(e: Dictionary): return e["node"] != n)
	n.visible = true
	var mt: ShaderMaterial = n.get_meta("mat")
	for key_col: Array in [["c", "color"], ["c2", "color2"]]:
		if layer.has(key_col[0]): mt.set_shader_parameter(key_col[1], vfx.pal(h, layer[key_col[0]], "main"))
	mt.set_shader_parameter("fade", 1.0)
	return n

## The prop's parts: {"box": [x, y, z], "at": [x, y, z], "rot": [x, y, z] rad} or {"cyl": [r at from, r at to],
## "from": [x, y, z], "to": [x, y, z], "sides"}, all in m with +y its own up and -z the way it reaches.
func _build(d: Dictionary) -> Node3D:
	var n := Node3D.new()
	var mt := ShaderMaterial.new()
	mt.shader = BONE if d.get("shader") == "bone" else IRON
	n.set_meta("mat", mt)
	for part: Dictionary in d["parts"]:
		var mi := MeshInstance3D.new()
		mi.material_override = mt
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if part.has("box"):
			var dims := HeroVfx.vec(part["box"])
			mi.mesh = Models.box(dims.x, dims.y, dims.z)
			mi.transform = Transform3D(Basis.from_euler(HeroVfx.vec(part.get("rot", [0, 0, 0]))),
					HeroVfx.vec(part["at"]))
		else:
			var a := HeroVfx.vec(part["from"])
			var b := HeroVfx.vec(part["to"])
			var r: Array = part["cyl"]
			mi.mesh = Models.cyl(float(r[1]), float(r[0]), a.distance_to(b), int(part.get("sides", CYL_SIDES)))
			mi.transform = Transform3D(
				Basis.looking_at(a.direction_to(b), Vector3.UP) * Basis(Vector3.RIGHT, -PI / 2), (a + b) * 0.5)
		n.add_child(mi)
	return n

## A one-shot at `at`: it lands squashed, settles, stands and fades.
func start(layer: Dictionary, h: Hunter, at: Vector3) -> void:
	var e := {"node": take(layer, h), "layer": layer, "at": at, "t": 0.0}
	live.append(e)
	_pose_shot(e)

func tick(delta: float) -> void:
	for i in range(live.size() - 1, -1, -1):
		var e: Dictionary = live[i]
		e["t"] = float(e["t"]) + delta
		if float(e["t"]) >= float(e["layer"].get("life", 0.5)):
			(e["node"] as Node3D).visible = false
			live.remove_at(i)
			continue
		_pose_shot(e)

func _pose_shot(e: Dictionary) -> void:
	var layer: Dictionary = e["layer"]
	var t := float(e["t"])
	var squash := 1.0 + float(layer.get("squash", 0.0)) * (1.0 - clampf(t / SQUASH_T, 0.0, 1.0))
	_place(e["node"], layer, e["at"], 0.0, Vector3(squash, 1.0 / squash, squash))
	var fade := float(layer.get("fade", 0.0))
	var left := float(layer.get("life", 0.5)) - t
	(e["node"].get_meta("mat") as ShaderMaterial).set_shader_parameter(
		"fade", clampf(left / fade, 0.0, 1.0) if fade > 0.0 else 1.0)

## A held prop this frame (the hold `e` from HeroVfx.hold): see the header.
func pose_held(lay: Dictionary, h: Hunter, e: Dictionary) -> void:
	var layer: Dictionary = lay["layer"]
	var n: Node3D = lay["node"]
	if layer.get("at") != "to":
		var at := vfx.layer_pos(layer, h, h.pos, Vector2.ZERO)
		var floor_y: float = vfx.m.world.ground_at(h.pos.x, h.pos.z) if layer.get("floor", false) else -INF
		_place(n, layer, at, 0.0, Vector3.ONE, floor_y)
	elif e["to"] is Vector3:
		var out: Vector3 = e["to"] - vfx.anchor_pos(h, String(layer.get("from", "h")))
		_place(n, layer, e["to"], atan2(-out.x, -out.z), Vector3.ONE)

## Its `hang` point (m up its own axis, times its size) at `at`, leaned back `lean` rad so its face turns to the
## camera, turned to `yaw`, its base kept at or over `floor_y`.
func _place(n: Node3D, layer: Dictionary, at: Vector3, yaw: float, squash: Vector3, floor_y := -INF) -> void:
	var scl := float(layer.get("size", 1.0))
	var turn := Basis.from_euler(Vector3(float(layer.get("lean", 0.0)), yaw, 0.0))
	var p := at - turn * Vector3(0, float(layer.get("hang", 0.0)) * scl, 0)
	p.y = maxf(p.y, floor_y)
	n.global_transform = Transform3D(turn * Basis.from_scale(squash * scl), p)
