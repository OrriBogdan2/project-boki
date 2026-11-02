class_name KitLooks
extends Node3D
## Pooled looks of Breah's and Ostra's projectiles and lingering effects (one node per match, made on
## first use, like AimKit's layer). Nothing here is gameplay: the shots stay ordinary Match shots
## (spawn_shot, so the height rules and Net behave as for every shot); a skin only replaces the shared
## shot sphere with a mesh of the hero's own and leaves a trail. Every mesh comes from a pool and goes
## back to it, so a burst of rocks or a stream of orbs never creates nodes per frame.
##
## Skins (shape, colour, trail, impact):
##   boulder    Breah's tap throw: a lumpy molten rock tumbling end over end, ember trail
##   rock       a launched rock: bigger, hotter, flaming trail
##   dashrock   Landslide's rock: rolls along the ground, dust and embers
##   orb        Ostra's Gravity Orb: a violet teardrop, short trail
##   orb_hot    the charged orb: a long blue-violet bolt with a bright core
##   spear      Void Snap: a tight bundle of five violet crystal shards
## Lingering: aura (Ostra's Empowered sphere), crown (stun stars over a head), scorch (Breah's crater),
## column (the grown Anomaly's light), hand (an orb held at the hand: Ostra's charge, the snap's dark
## orb, Breah's glowing fists).

const ROCK_SH := preload("res://shaders/molten_rock.gdshader")
const GLASS_SH := preload("res://shaders/void_glass.gdshader")
## Looks draw their variety from their own generator, never the global one (bots and rolls share it,
## so a rock's crack pattern must not change what a bot decides).
static var vis_rng := RandomNumberGenerator.new()
const KEEP := 0.12            # s: a refreshed effect (hand, aura) stays this long without a refresh

var m: Node
var pools := {}               # kind -> Array[Node3D] (hidden, free)
var live: Array = []          # {s, n, kind, t, trail}
var held := {}                # key -> {n, kind, t, ent}
var timed: Array = []         # {n, kind, t, dur, ent, at}

static func of(match_node: Node) -> KitLooks:
	var k := match_node.get_node_or_null("KitLooks") as KitLooks
	if k == null:
		k = KitLooks.new()
		k.name = "KitLooks"
		k.m = match_node
		match_node.add_child(k)
	return k

# ------------------------------------------------------------------ materials and meshes
static func rock_mat(heat: float, seed_v: float) -> ShaderMaterial:
	var mt := ShaderMaterial.new()
	mt.shader = ROCK_SH
	mt.set_shader_parameter("heat", heat)
	mt.set_shader_parameter("seed", seed_v)
	return mt

static func glass_mat(core: Color, rim: Color, a := 1.0) -> ShaderMaterial:
	var mt := ShaderMaterial.new()
	mt.shader = GLASS_SH
	mt.set_shader_parameter("core", core)
	mt.set_shader_parameter("rim", rim)
	mt.set_shader_parameter("alpha", a)
	return mt

## Unlit and alpha-blended: a dark tint that stays dark on bright ground (additive glow would wash out).
static func shade_mat(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = c
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

static func lump(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 1.7
	s.radial_segments = 7
	s.rings = 4
	return s

func _build(kind: String) -> Node3D:
	var n := Node3D.new()
	n.top_level = true
	match kind:
		"boulder", "rock", "dashrock":
			var r := {"boulder": 0.24, "rock": 0.42, "dashrock": 0.5}[kind] as float
			var heat := {"boulder": 0.55, "rock": 0.95, "dashrock": 0.7}[kind] as float
			var body := Models.part(
				n, lump(r), rock_mat(heat, vis_rng.randf() * 10.0), Vector3.ZERO, Vector3.ONE, Vector3(0.3, 0.5, 0.2)
			)
			body.name = "Spin"
			Models.part(body, lump(r * 0.55), rock_mat(heat, vis_rng.randf() * 10.0), Vector3(r * 0.55, r * 0.3, 0.0))
			Models.part(
				body, lump(r * 0.45), rock_mat(heat, vis_rng.randf() * 10.0), Vector3(-r * 0.4, -r * 0.2, r * 0.45)
			)
			var halo := Models.part(
				n, Models.sphere(r * 1.5, 10), Models.glow_mat(Color(1.0, 0.45, 0.12, 0.22 + heat * 0.15)), Vector3.ZERO
			)
			halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"orb":
			var o := Models.part(
				n, Models.sphere(0.16, 10), glass_mat(Color("3a0d5c"), Color("e070ff")), Vector3.ZERO,
				Vector3(1.0, 1.0, 1.9)
			)
			o.name = "Spin"
			Models.part(n, Models.sphere(0.07, 8), Models.glow_mat(Color("ffd6ff")), Vector3(0, 0, -0.1))
		"orb_hot":
			Models.part(
				n, Models.sphere(0.13, 10), glass_mat(Color("1c1a6a"), Color("9fb8ff")), Vector3.ZERO,
				Vector3(1.0, 1.0, 5.2)
			)
			Models.part(
				n, Models.sphere(0.06, 8), Models.glow_mat(Color("f2f6ff")), Vector3.ZERO, Vector3(1.0, 1.0, 6.0)
			)
		"spear":
			var b := Node3D.new()
			b.name = "Spin"
			n.add_child(b)
			for i in 5:
				var a := TAU * i / 5.0
				var off := Vector3(cos(a), sin(a), 0.0) * (0.0 if i == 0 else 0.17)
				var len_ := 2.2 if i == 0 else 1.6
				var sh := Models.part(
					b, PrismMesh.new(), glass_mat(Color("240838"), Color("c48cff")),
					off + Vector3(0, 0, 0.1 * float(i % 2)), Vector3(0.2, len_, 0.2), Vector3(-PI * 0.5, 0, a)
				)
				sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"aura":
			Models.part(
				n, Models.sphere(1.25, 20), glass_mat(Color("2a0020"), Color("ff4fd8"), 0.45), Vector3(0, 1.0, 0)
			)
			var disc := Models.part(
				n, Models.cyl(1.3, 1.3, 0.03, 28), Models.glow_mat(Color(1.0, 0.3, 0.85, 0.22)), Vector3(0, 0.05, 0)
			)
			disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"crown":
			var c := Node3D.new()
			c.name = "Spin"
			n.add_child(c)
			for i in 3:
				var a2 := TAU * i / 3.0
				var st := Models.part(
					c, Models.box(0.16, 0.16, 0.05), Models.glow_mat(Color("fff27a")),
					Vector3(cos(a2) * 0.38, 0.0, sin(a2) * 0.38), Vector3.ONE, Vector3(0, a2, PI * 0.25)
				)
				st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			Models.part(n, Models.cyl(0.42, 0.42, 0.02, 20), Models.glow_mat(Color(1.0, 0.95, 0.5, 0.35)), Vector3.ZERO)
		"scorch":
			var d := Models.part(
				n, Models.cyl(1.0, 1.0, 0.02, 24), Models.glow_mat(Color(0.35, 0.05, 0.02, 0.55)), Vector3(0, 0.03, 0)
			)
			d.name = "Disc"
			for i in 6:
				var a3 := TAU * i / 6.0 + 0.4
				Models.part(
					n, Models.box(0.08, 0.02, 0.5), Models.glow_mat(Color(1.0, 0.7, 0.2, 0.75)),
					Vector3(cos(a3) * 0.55, 0.04, sin(a3) * 0.55), Vector3.ONE, Vector3(0, -a3, 0)
				)
		"column":
			Models.part(
				n, Models.cyl(0.35, 0.55, 6.0, 16), glass_mat(Color("20003a"), Color("b06bff"), 0.7), Vector3(0, 3.0, 0)
			)
		"well_dome":
			Models.part(n, Models.sphere(1.0, 24), glass_mat(Color("0a2440"), Color("a8e4ff"), 0.3), Vector3.ZERO)
			Models.part(
				n,
				Models.sphere(0.3, 16),
				Models.glow_mat(Color(1.0, 0.31, 0.85, 0.55)),
				Vector3(0, 0.15, 0)
			).name = "Core"
		"well":
			_build_well(n)
		"hand":
			Models.part(n, Models.sphere(0.16, 12), Models.glow_mat(Color(1, 1, 1, 0.9)), Vector3.ZERO).name = "Core"
			Models.part(n, Models.sphere(0.3, 12), Models.glow_mat(Color(1, 1, 1, 0.25)), Vector3.ZERO).name = "Halo"
	for c2 in n.find_children("*", "MeshInstance3D", true, false):
		(c2 as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	return n

## Ostra's Nightwell, radius 1 (scaled to the well): a dark violet disc, four spiral arms of light turning
## on it, small black orbs riding the rim, and a pink core shown when she cast it Swollen.
func _build_well(n: Node3D) -> void:
	Models.part(n, Models.cyl(1.0, 1.0, 0.03, 32), shade_mat(Color(0.14, 0.03, 0.3, 0.88)), Vector3.ZERO)
	var spin := Node3D.new()
	spin.name = "Spin"
	n.add_child(spin)
	var arm_mat := Models.glow_mat(Color(0.72, 0.3, 1.0, 0.95))
	for arm in 4:
		for j in 6:
			var u := float(j + 1) / 6.0
			var ang := TAU * arm / 4.0 + u * 2.2
			var at := Vector3(cos(ang), 0.03, sin(ang)) * u * 0.92
			Models.part(spin, Models.box(0.03 + 0.05 * u, 0.01, 0.16), arm_mat, at, Vector3.ONE, Vector3(0, -ang, 0))
	for i in 8:
		var a := TAU * i / 8.0
		Models.part(
			spin,
			Models.sphere(0.07, 8),
			Models.toon(Color("0c0414"), false, 0.0),
			Vector3(cos(a), 0.12, sin(a))
		)
	Models.part(
		n,
		Models.sphere(0.22, 14),
		Models.glow_mat(Color(1.0, 0.31, 0.85, 0.85)),
		Vector3(0, 0.1, 0)
	).name = "Core"

func _take(kind: String) -> Node3D:
	var p: Array = pools.get(kind, [])
	while not p.is_empty():
		var n: Node3D = p.pop_back()
		if is_instance_valid(n):
			n.visible = true
			n.scale = Vector3.ONE
			return n
	return _build(kind)

func _give(kind: String, n: Node3D) -> void:
	if not is_instance_valid(n):
		return
	n.visible = false
	if not pools.has(kind): pools[kind] = []
	pools[kind].append(n)

func pooled(kind: String) -> int:
	return (pools.get(kind, []) as Array).size()

# ------------------------------------------------------------------ shot skins
## Dresses a Match shot in a skin (the shot dictionary spawn_shot just appended). The shared sphere goes
## back to Match's pool at once, so it can't be drawn under ours.
func skin(s: Dictionary, kind: String) -> void:
	var sn = s.get("node")
	if sn != null and is_instance_valid(sn):
		(sn as Node3D).visible = false
	s["node"] = null
	var n := _take(kind)
	n.global_position = s["pos"]
	live.append({"s": s, "n": n, "kind": kind, "t": 0.0, "trail": 0.0, "last": s["pos"]})

## The last shot `by` fired, dressed (weapon shots the kit didn't spawn itself).
func skin_last(by: Ent, kind: String) -> bool:
	for i in range(m.shots.size() - 1, -1, -1):
		var s: Dictionary = m.shots[i]
		if s["by"] == by and s.get("node") != null:
			skin(s, kind)
			return true
	return false

func skins_live(kind: String) -> int:
	return live.filter(func(e): return e["kind"] == kind).size()

func _trail(e: Dictionary, p: Vector3, back: Vector3) -> void:
	var fx: Fx = m.fx
	match String(e["kind"]):
		"boulder":
			fx.spark(p, back, Color("ff9a3c"), 2, 2.5, 30.0, 0.25, 4.0, 0.8)
		"rock":
			fx.spark(p, back + Vector3(0, 0.3, 0), Color("ffb347"), 4, 4.0, 40.0, 0.3, 2.0, 1.3)
			fx.spark(p, back, Color("ff5a1f"), 2, 2.0, 25.0, 0.35, -1.0, 1.0)
		"dashrock":
			fx.spark(p - Vector3(0, 0.4, 0), back + Vector3(0, 0.5, 0), Color("c9a27a"), 3, 3.0, 50.0, 0.35, 6.0, 1.0)
			fx.spark(p, back, Color("ff8a2c"), 2, 2.0, 30.0, 0.25, 4.0, 0.8)
		"orb":
			fx.spark(p, back, Color("e070ff"), 1, 1.5, 15.0, 0.18, 0.0, 0.7)
		"orb_hot":
			fx.spark(p, back, Color("a8c0ff"), 3, 3.0, 12.0, 0.22, 0.0, 0.9)
		"spear":
			fx.spark(p, back, Color("c48cff"), 3, 3.5, 20.0, 0.22, 0.0, 1.0)

func _impact(e: Dictionary, p: Vector3) -> void:
	var fx: Fx = m.fx
	match String(e["kind"]):
		"orb":
			fx.flash(p, Color("f0a0ff"), 0.45, 0.06)
			fx.spark(p, Vector3.UP, Color("e070ff"), 6, 3.0, 160.0, 0.2, 0.0, 0.8)
		"orb_hot":
			fx.flash(p, Color("d8e2ff"), 0.8, 0.08)
			fx.ring(p, 0.7, Color("9fb8ff"), 0.22)
			fx.spark(p, Vector3.UP, Color("b8c8ff"), 10, 4.5, 170.0, 0.25, 0.0, 1.0)
		"boulder":
			fx.dust(p, 4)

func _process(delta: float) -> void:
	var alive := {}
	if not live.is_empty():
		for s0 in m.shots: alive[int(s0["sid"])] = true
	for e in live.duplicate():
		var s: Dictionary = e["s"]
		var n: Node3D = e["n"]
		var p: Vector3 = s["pos"]
		if not alive.has(int(s["sid"])):
			_impact(e, e["last"])
			live.erase(e)
			_give(String(e["kind"]), n)
			continue
		e["t"] = float(e["t"]) + delta
		e["last"] = p
		var v: Vector2 = s["vel"]
		var fwd := Vector3(v.x, 0, v.y).normalized() if v.length() > 0.1 else Vector3.FORWARD
		n.global_position = p
		if fwd.length() > 0.1:
			n.look_at(p + fwd, Vector3.UP)
		var spin := n.get_node_or_null("Spin") as Node3D
		if spin:
			match String(e["kind"]):
				"boulder", "rock": spin.rotate_x(-delta * 14.0)
				"dashrock": spin.rotate_x(-delta * 9.0)
				"spear": spin.rotate_z(delta * 6.0)
				_: spin.rotate_z(delta * 3.0)
		e["trail"] = float(e["trail"]) - delta
		if float(e["trail"]) <= 0.0:
			e["trail"] = 0.03
			_trail(e, p, -fwd)
	var now := float(m.time)
	for key in held.keys():
		var hd: Dictionary = held[key]
		var ent = hd["ent"]
		if now - float(hd["t"]) > KEEP or not is_instance_valid(ent) or (
			ent is Hunter and ((ent as Hunter).downed or KinMerge.active(ent))
		):
			_give(String(hd["kind"]), hd["n"])
			held.erase(key)
	for e2 in timed.duplicate():
		e2["t"] = float(e2["t"]) + delta
		var n2: Node3D = e2["n"]
		var u := float(e2["t"]) / maxf(0.01, float(e2["dur"]))
		var ent2 = e2.get("ent")
		if u >= 1.0 or (bool(e2.get("follows", false)) and not is_instance_valid(ent2)):
			timed.erase(e2)
			_give(String(e2["kind"]), n2)
			continue
		match String(e2["kind"]):
			"crown":
				var head := (ent2 as Ent).pos + Vector3(0, 2.15 if ent2 is Hunter else 1.5, 0)
				n2.global_position = head
				(n2.get_node("Spin") as Node3D).rotate_y(delta * 6.5)
				if (ent2 as Ent).stun_t <= 0.0 and float(e2["t"]) > 0.2:
					e2["t"] = e2["dur"]
			"scorch":
				n2.scale = Vector3(float(e2["r"]), 1.0, float(e2["r"])) * (1.0 - 0.15 * u)
			"column":
				n2.scale = Vector3(1.0, clampf(u * 4.0, 0.1, 1.0), 1.0)

# ------------------------------------------------------------------ lingering effects
## A refreshed effect held on an entity (call every step while it should show). key: unique per use.
func hold_on(key: String, kind: String, ent: Node3D, at: Vector3, scl := 1.0, col := Color.WHITE) -> Node3D:
	var hd: Dictionary = held.get(key, {})
	if hd.is_empty():
		hd = {"n": _take(kind), "kind": kind, "ent": ent, "t": 0.0}
		held[key] = hd
	hd["t"] = float(m.time)
	var n: Node3D = hd["n"]
	n.global_position = at
	n.scale = Vector3.ONE * scl
	if kind == "hand":
		(n.get_node("Core") as MeshInstance3D).material_override.set_shader_parameter("color", Color(col, 0.95))
		(n.get_node("Halo") as MeshInstance3D).material_override.set_shader_parameter("color", Color(col, 0.3))
	return n

func holding(key: String) -> bool:
	return held.has(key) and float(m.time) - float(held[key]["t"]) <= KEEP

## Stun stars circling over a head until the stun ends (or `secs`).
func crown(e: Ent, secs: float) -> void:
	for t in timed:
		if t["kind"] == "crown" and is_instance_valid(t["ent"]) and t["ent"] == e:
			t["dur"] = maxf(float(t["dur"]), float(t["t"]) + secs)
			return
	timed.append({"n": _take("crown"), "kind": "crown", "t": 0.0, "dur": secs, "ent": e, "follows": true})

func crowned(e: Ent) -> bool:
	return timed.any(func(t): return t["kind"] == "crown" and is_instance_valid(t["ent"]) and t["ent"] == e)

## Breah's slam crater: a dark red scorch with gold flecks, fading over `secs`.
func scorch(at: Vector3, r: float, secs := 1.0) -> void:
	var n := _take("scorch")
	n.global_position = at
	n.scale = Vector3(r, 1.0, r)
	timed.append({"n": n, "kind": "scorch", "t": 0.0, "dur": secs, "ent": null, "r": r})

## The grown Anomaly's light column (it rises quickly, stays `secs`).
func column(at: Vector3, secs: float) -> Node3D:
	var n := _take("column")
	n.global_position = at
	timed.append({"n": n, "kind": "column", "t": 0.0, "dur": secs, "ent": null})
	return n

func end_column(n: Node3D) -> void:
	for t in timed.duplicate():
		if t["n"] == n:
			timed.erase(t)
			_give("column", n)
