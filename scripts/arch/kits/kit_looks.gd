class_name KitLooks
extends Node3D
## Pooled looks of Tarek's and Ostra's projectiles and lingering effects (one node per match, made on
## first use, like AimKit's layer). Nothing here is gameplay: the shots stay ordinary Match shots
## (spawn_shot, so the height rules and Net behave as for every shot); a skin only replaces the shared
## shot sphere with a mesh of the hero's own and leaves a trail. Every mesh comes from a pool and goes
## back to it, so a burst of rocks or a stream of orbs never creates nodes per frame.
##
## Skins (shape, colour, trail, impact):
##   boulder    Tarek's tap throw: a lumpy molten rock tumbling end over end, ember trail
##   rock       a launched rock: bigger, hotter, flaming trail
##   dashrock   Rock Hop's last rock: rolls along the ground, dust and embers
##   footrock   the slab under Tarek's foot through a Rock Hop (held)
##   orb        Motley's Gravity Orb: a violet glass teardrop with a magenta tail; skin_orb grows and
##              brightens it with its charge
##   spear      Shard Snap: a long bundle of dark violet crystal prisms with bright rims
## Lingering: aura (Ostra's Swollen sphere), crown (stun stars over a head), burst and crater (Tarek's slam:
## a molten starburst, then a dark red cracked crater), shard (a rock chip flying off an impact), column (the
## grown seed's light), mote (a coloured glow at a hand: Tarek's fists, Ostra's charge), dark (the Snap's
## black wind-up orb), star (the Trade's lobbed star-orb).
## Colour and darkness are alpha-blended (shade_mat, the void glass); only small hot cores add light, so
## nothing washes out to white on bright grass.

const ROCK_SH := preload("res://shaders/molten_rock.gdshader")
const GLASS_SH := preload("res://shaders/void_glass.gdshader")
## Looks draw their variety from their own generator, never the global one (bots and rolls share it,
## so a rock's crack pattern must not change what a bot decides).
static var vis_rng := RandomNumberGenerator.new()
const KEEP := 0.12            # s: a refreshed effect (a mote, the aura) stays this long without a refresh
const TRAIL_DT := 0.016       # s: a skinned shot leaves its trail every frame
const ORB_CORE := [Color("3a0d5c"), Color("8a3fe0")]      # the orb's glass core, plain and at full charge
const ORB_RIM := [Color("e070ff"), Color("ffeaff")]       # its rim, the same
const ORB_HOT_K := 2.2        # how much the orb's white-hot core grows at full charge
const SHARD_GRAV := 22.0      # m/s2: rock chips fall a little faster than bodies (they read as heavy)
const SIGIL_SEGS := 16        # arc segments in Ostra's rune sigil ring

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

## The void glass (shaders/void_glass): `body` is how opaque the dark core is.
static func glass_mat(core: Color, rim: Color, a := 1.0, body := 0.35) -> ShaderMaterial:
	var mt := ShaderMaterial.new()
	mt.shader = GLASS_SH
	mt.set_shader_parameter("core", core)
	mt.set_shader_parameter("rim", rim)
	mt.set_shader_parameter("alpha", a)
	mt.set_shader_parameter("body", body)
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
			_build_rock(n, kind)
		"footrock":
			_build_footrock(n)
		"orb", "spear":
			_build_void_shot(n, kind)
		"aura":
			Models.part(
				n, Models.sphere(1.25, 20), glass_mat(Color("7a1a68"), Color("ff4fd8"), 0.6, 0.12), Vector3(0, 1.0, 0)
			)
			Models.part(n, Models.cyl(1.3, 1.3, 0.03, 28), shade_mat(Color(0.75, 0.12, 0.6, 0.45)), Vector3(0, 0.05, 0))
		"crown":
			_build_crown(n)
		"burst", "crater":
			_build_impact(n, kind)
		"shard":
			Models.part(n, lump(0.13), rock_mat(0.7, vis_rng.randf() * 10.0), Vector3.ZERO, Vector3(1.0, 0.7, 1.3))
		"column":
			Models.part(
				n, Models.cyl(0.35, 0.55, 6.0, 16), glass_mat(Color("20003a"), Color("b06bff"), 0.75, 0.3),
				Vector3(0, 3.0, 0)
			)
		"well_dome":
			Models.part(n, Models.sphere(1.0, 24), glass_mat(Color("0a2440"), Color("a8e4ff"), 0.45, 0.1), Vector3.ZERO)
			Models.part(
				n,
				Models.sphere(0.3, 16),
				Models.glow_mat(Color(1.0, 0.31, 0.85, 0.55)),
				Vector3(0, 0.15, 0)
			).name = "Core"
		"well":
			_build_well(n)
		"mote":
			Models.part(n, Models.sphere(0.2, 12), shade_mat(Color(1, 1, 1, 0.85)), Vector3.ZERO).name = "Halo"
			Models.part(n, Models.sphere(0.08, 10), Models.glow_mat(Color(1, 1, 1, 0.9)), Vector3.ZERO).name = "Core"
		"dark":
			Models.part(n, Models.sphere(0.22, 16), glass_mat(Color("0a0012"), Color("f2eaff"), 1.0, 1.0), Vector3.ZERO)
		"star":
			_build_star(n)
		"sigil":
			_build_sigil(n)
	for c2 in n.find_children("*", "MeshInstance3D", true, false):
		(c2 as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	return n

## Tarek's rocks in flight: opaque molten basalt lumps with a warm (alpha-blended) heat haze.
func _build_rock(n: Node3D, kind: String) -> void:
	var r := {"boulder": 0.3, "rock": 0.45, "dashrock": 0.5}[kind] as float
	var heat := {"boulder": 0.8, "rock": 0.95, "dashrock": 0.75}[kind] as float
	# Rock Hop's last rock stands tall: a tumbling crag, not a ball
	var tall := Vector3(1.0, 1.8, 1.0) if kind == "dashrock" else Vector3.ONE
	var body := Models.part(
		n, lump(r), rock_mat(heat, vis_rng.randf() * 10.0), Vector3.ZERO, tall, Vector3(0.3, 0.5, 0.2)
	)
	body.name = "Spin"
	Models.part(body, lump(r * 0.55), rock_mat(heat, vis_rng.randf() * 10.0), Vector3(r * 0.55, r * 0.3, 0.0))
	Models.part(body, lump(r * 0.45), rock_mat(heat, vis_rng.randf() * 10.0), Vector3(-r * 0.4, -r * 0.2, r * 0.45))
	Models.part(n, Models.sphere(r * 1.45, 10), shade_mat(Color(1.0, 0.42, 0.1, 0.28)), Vector3.ZERO)

## The slab he rides through a Rock Hop, like a board: long along +Z (he turns it along the hop), a pale sunlit
## top so the match camera reads it under his feet, a hot underside.
func _build_footrock(n: Node3D) -> void:
	Models.part(n, Models.box(0.5, 0.14, 1.0), Models.toon(RockLook.STONE_HI, true, 0.6), Vector3(0, -0.07, 0))
	var top := Models.toon(RockLook.STONE_HI.lerp(RockLook.CAP, 0.4), true, 0.6)
	Models.part(n, Models.box(0.42, 0.04, 0.86), top, Vector3(0, 0.01, 0))
	Models.part(n, Models.box(0.3, 0.12, 0.7), Models.glow_mat(Color("ff7a2a")), Vector3(0, -0.17, 0))

## Ostra's shots: dark violet glass with bright rims, each with its own length and tail (the tail points
## back along the flight, -Z being forward after look_at).
func _build_void_shot(n: Node3D, kind: String) -> void:
	match kind:
		"orb":
			var o := Models.part(
				n, Models.sphere(0.28, 12), glass_mat(Color("3a0d5c"), Color("e070ff"), 1.0, 0.75), Vector3.ZERO,
				Vector3(1.0, 1.0, 1.45)
			)
			o.name = "Spin"
			var hot := Models.glow_mat(Color("ffd6ff"))
			hot.render_priority = 1      # always over the glass (same-node alpha sorting flickers in flight)
			Models.part(n, Models.sphere(0.09, 8), hot, Vector3(0, 0, -0.12)).name = "Hot"
			_tail(n, 0.22, 1.2, Color(0.88, 0.25, 0.85, 0.55))
		"spear":
			var b := Node3D.new()
			b.name = "Spin"
			n.add_child(b)
			for i in 5:
				var a := TAU * i / 5.0
				var off := Vector3(cos(a), sin(a), 0.0) * (0.0 if i == 0 else 0.2)
				var len_ := 2.7 if i == 0 else 2.0
				Models.part(
					b, PrismMesh.new(), glass_mat(Color("240838"), Color("d8a8ff"), 1.0, 0.85),
					off + Vector3(0, 0, 0.15 * float(i % 2)), Vector3(0.26, len_, 0.26), Vector3(-PI * 0.5, 0, a)
				)

## A tapering tail of `col` behind a shot: `w` wide at the shot, `len_` long.
func _tail(n: Node3D, w: float, len_: float, col: Color) -> void:
	var mat := shade_mat(col)
	mat.render_priority = -1      # always under the shot's glass
	Models.part(n, Models.cyl(0.0, w, len_, 10), mat, Vector3(0, 0, len_ * 0.5), Vector3.ONE, Vector3(PI * 0.5, 0, 0))

func _build_crown(n: Node3D) -> void:
	var c := Node3D.new()
	c.name = "Spin"
	n.add_child(c)
	for i in 3:
		var a2 := TAU * i / 3.0
		Models.part(
			c, Models.box(0.16, 0.16, 0.05), Models.glow_mat(Color("fff27a")),
			Vector3(cos(a2) * 0.38, 0.0, sin(a2) * 0.38), Vector3.ONE, Vector3(0, a2, PI * 0.25)
		)
	Models.part(n, Models.cyl(0.42, 0.42, 0.02, 20), shade_mat(Color(1.0, 0.85, 0.2, 0.4)), Vector3.ZERO)

## Tarek's slam, radius 1: a molten starburst of rays (burst), or the dark red crater it leaves with radial
## cracks and ember flecks (crater). Both alpha-blended, in her molten colours.
func _build_impact(n: Node3D, kind: String) -> void:
	if kind == "burst":
		Models.part(n, Models.cyl(0.42, 0.42, 0.02, 20), shade_mat(Color(1.0, 0.82, 0.3, 0.85)), Vector3(0, 0.06, 0))
		for i in 12:
			var a := TAU * i / 12.0 + vis_rng.randf() * 0.2
			var long_ray := i % 2 == 0
			var len_ := (0.7 if long_ray else 0.45) + vis_rng.randf() * 0.3
			var col := Color(1.0, 0.48, 0.12, 0.9) if long_ray else Color(1.0, 0.78, 0.25, 0.9)
			Models.part(
				n, PrismMesh.new(), shade_mat(col), Vector3(cos(a), 0.05, sin(a)) * (0.3 + len_ * 0.5),
				Vector3(0.16, len_, 0.02), Vector3(-PI * 0.5, -a - PI * 0.5, 0)
			)
		return
	Models.part(n, Models.cyl(1.0, 1.0, 0.02, 24), shade_mat(Color(0.3, 0.05, 0.02, 0.78)), Vector3(0, 0.03, 0))
	Models.part(n, Models.cyl(0.55, 0.55, 0.02, 20), shade_mat(Color(0.12, 0.03, 0.02, 0.85)), Vector3(0, 0.04, 0))
	for i in 8:
		var a3 := TAU * i / 8.0 + vis_rng.randf() * 0.3
		var len3 := 0.55 + vis_rng.randf() * 0.4
		Models.part(
			n, Models.box(0.05, 0.015, len3), shade_mat(Color(1.0, 0.45, 0.1, 0.95)),
			Vector3(cos(a3), 0.05, sin(a3)) * (0.35 + len3 * 0.5), Vector3.ONE, Vector3(0, -a3 + PI * 0.5, 0)
		)
	for i in 10:
		var a4 := vis_rng.randf() * TAU
		Models.part(
			n, Models.box(0.06, 0.03, 0.06), shade_mat(Color(1.0, 0.72, 0.25, 1.0)),
			Vector3(cos(a4), 0.06, sin(a4)) * (0.3 + vis_rng.randf() * 0.65)
		)

## Ostra's rune sigil, radius 1: a ring of sixteen arc segments that light one by one as it fills, a
## hexagram inscribed in it that brightens, and six glyph ticks outside. Alpha-blended in one colour.
func _build_sigil(n: Node3D) -> void:
	var seg_mat := shade_mat(Color.WHITE)
	var star_mat := shade_mat(Color.WHITE)
	n.set_meta("seg_mat", seg_mat)
	n.set_meta("star_mat", star_mat)
	var segs := Node3D.new()
	segs.name = "Segs"
	n.add_child(segs)
	for i in SIGIL_SEGS:
		var a := TAU * (i + 0.5) / SIGIL_SEGS
		var seg_at := Vector3(cos(a), 0.0, sin(a))
		Models.part(segs, Models.box(0.36, 0.015, 0.07), seg_mat, seg_at, Vector3.ONE, Vector3(0, -a + PI * 0.5, 0))
	for tri in 2:
		for i in 3:
			var a0 := TAU * i / 3.0 + PI * tri / 3.0
			var a1 := a0 + TAU / 3.0
			var p0 := Vector3(cos(a0), 0.0, sin(a0)) * 0.85
			var p1 := Vector3(cos(a1), 0.0, sin(a1)) * 0.85
			var mid := (p0 + p1) * 0.5
			var along := atan2(p1.x - p0.x, p1.z - p0.z)
			var edge := Models.box(0.035, 0.012, p0.distance_to(p1))
			Models.part(n, edge, star_mat, mid, Vector3.ONE, Vector3(0, along, 0))
	for i in 6:
		var a2 := TAU * i / 6.0
		var tick_at := Vector3(cos(a2), 0.0, sin(a2)) * 1.16
		Models.part(n, Models.box(0.05, 0.015, 0.16), seg_mat, tick_at, Vector3.ONE, Vector3(0, -a2, 0))
	Models.part(n, Models.box(0.14, 0.015, 0.14), star_mat, Vector3.ZERO, Vector3.ONE, Vector3(0, PI * 0.25, 0))

## The Trade's lobbed star-orb: a dark indigo glass orb with short violet spikes, turning.
func _build_star(n: Node3D) -> void:
	var spin := Node3D.new()
	spin.name = "Spin"
	n.add_child(spin)
	Models.part(spin, Models.sphere(0.3, 14), glass_mat(Color("120838"), Color("8a6bff"), 1.0, 0.9), Vector3.ZERO)
	for i in 6:
		var a := TAU * i / 6.0
		Models.part(
			spin, PrismMesh.new(), shade_mat(Color(0.62, 0.42, 1.0, 0.95)), Vector3(cos(a), sin(a), 0.0) * 0.36,
			Vector3(0.12, 0.3, 0.06), Vector3(0, 0, a - PI * 0.5)
		)
	Models.part(n, Models.sphere(0.08, 8), Models.glow_mat(Color("d8c8ff")), Vector3.ZERO)

## Ostra's Nightwell, radius 1 (scaled to the well): a dark violet disc, four spiral arms of light turning
## on it, small black orbs riding the rim, and a pink core shown when she cast it Swollen.
func _build_well(n: Node3D) -> void:
	Models.part(n, Models.cyl(1.0, 1.0, 0.03, 32), shade_mat(Color(0.14, 0.03, 0.3, 0.88)), Vector3.ZERO)
	var spin := Node3D.new()
	spin.name = "Spin"
	n.add_child(spin)
	var arm_mat := shade_mat(Color(0.7, 0.36, 1.0, 0.95))
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

## The loading screen's rehearsal (ArchKit.warm_fx): kind -> how many of it a cast takes at once, built into the
## pools, so the first slam or sigil builds nothing mid-fight (Tarek's first Slam built 38 meshes in one frame).
func prewarm(kinds: Dictionary) -> void:
	for kind in kinds:
		for i in int(kinds[kind]) - pooled(String(kind)):
			_give(String(kind), _build(String(kind)))

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

## Dresses Motley's last orb at charge k (0..1): `scl` times the plain orb, its glass and core brighter.
## (Pooled, so a plain orb sets its looks back too.)
func skin_orb(by: Ent, k: float, scl: float) -> void:
	if not skin_last(by, "orb"):
		return
	var e: Dictionary = live.back()
	e["k"] = k
	var n: Node3D = e["n"]
	n.scale = Vector3.ONE * scl
	var glass := (n.get_node("Spin") as MeshInstance3D).material_override as ShaderMaterial
	glass.set_shader_parameter("core", (ORB_CORE[0] as Color).lerp(ORB_CORE[1], k))
	glass.set_shader_parameter("rim", (ORB_RIM[0] as Color).lerp(ORB_RIM[1], k))
	(n.get_node("Hot") as Node3D).scale = Vector3.ONE * lerpf(1.0, ORB_HOT_K, k)

func skins_live(kind: String) -> int:
	return live.filter(func(e): return e["kind"] == kind).size()

## The trail behind a skinned shot (every TRAIL_DT): colour as alpha-blended puffs, embers as sparks.
func _trail(e: Dictionary, p: Vector3, back: Vector3) -> void:
	var fx: Fx = m.fx
	match String(e["kind"]):
		"boulder":
			fx.burst(p, Color(1.0, 0.5, 0.15, 0.8), 2, 1.0, 0.3, -1.0, 1.1, back, 25.0)
			fx.spark(p, back, Color("ff9a3c"), 2, 2.5, 30.0, 0.25, 4.0, 0.8)
		"rock":
			fx.burst(p, Color(1.0, 0.42, 0.1, 0.85), 3, 1.5, 0.35, -1.0, 1.5, back, 30.0)
			fx.spark(p, back + Vector3(0, 0.3, 0), Color("ffb347"), 4, 4.0, 40.0, 0.3, 2.0, 1.3)
		"dashrock":
			var dust := Color(0.62, 0.48, 0.34, 0.85)
			fx.burst(p - Vector3(0, 0.4, 0), dust, 3, 2.0, 0.4, 4.0, 1.4, back + Vector3.UP, 50.0)
			fx.spark(p, back, Color("ff8a2c"), 2, 2.0, 30.0, 0.25, 4.0, 0.8)
		"orb":
			var k := float(e["k"])
			var col := Color(0.9, 0.3 + 0.4 * k, 0.9, 0.7)
			fx.burst(p, col, 1 + roundi(k * 2.0), 0.6, 0.25, 0.0, 0.9 + 0.6 * k, back, 15.0)
		"spear":
			fx.burst(p, Color(0.5, 0.2, 0.8, 0.8), 2, 1.5, 0.25, 0.0, 1.0, back, 20.0)

func _impact(e: Dictionary, p: Vector3) -> void:
	var fx: Fx = m.fx
	match String(e["kind"]):
		"orb":
			var k := float(e["k"])
			fx.burst(p, Color(0.88, 0.3, 0.9, 0.85), 8 + roundi(k * 14.0), 3.0 + k * 2.5, 0.25, 0.0, 1.0 + 0.7 * k)
			fx.flash(p, Color("e070ff"), 0.4 + 0.7 * k, 0.06 + 0.05 * k)
			if k > 0.0:
				fx.ring(p, 0.4 + k, Color("e070ff"), 0.22 + 0.1 * k)
		"boulder":
			fx.dust(p, 6)

func _process(delta: float) -> void:
	_tick_skins(delta)
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
		var u := float(e2["t"]) / maxf(0.01, float(e2["dur"]))
		var ent2 = e2.get("ent")
		if u >= 1.0 or (bool(e2.get("follows", false)) and not is_instance_valid(ent2)):
			timed.erase(e2)
			_give(String(e2["kind"]), e2["n"])
			continue
		_tick_timed(e2, u, delta)

## Moves every skin onto its shot, turns it, and leaves its trail; a shot that ended gets its impact.
func _tick_skins(delta: float) -> void:
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
			e["trail"] = TRAIL_DT
			_trail(e, p, -fwd)

func _tick_timed(e2: Dictionary, u: float, delta: float) -> void:
	var n2: Node3D = e2["n"]
	match String(e2["kind"]):
		"crown":
			var ent2: Ent = e2["ent"]
			n2.global_position = ent2.pos + Vector3(0, 2.15 if ent2 is Hunter else 1.5, 0)
			(n2.get_node("Spin") as Node3D).rotate_y(delta * 6.5)
			if ent2.stun_t <= 0.0 and float(e2["t"]) > 0.2:
				e2["t"] = e2["dur"]
		"burst":
			var r := float(e2["r"]) * (0.55 + 0.45 * minf(1.0, u * 3.0))
			n2.scale = Vector3(r, 1.0, r)
			_fade(n2, 1.0 - smoothstep(0.35, 1.0, u))
		"crater":
			_fade(n2, 1.0 - smoothstep(0.6, 1.0, u))
		"shard":
			var v: Vector3 = e2["vel"]
			v.y -= SHARD_GRAV * delta
			e2["vel"] = v
			n2.global_position += v * delta
			n2.rotate_x(delta * 9.0)
			if n2.global_position.y < float(e2["floor"]):
				e2["t"] = e2["dur"]
		"column":
			n2.scale = Vector3(1.0, clampf(u * 4.0, 0.1, 1.0), 1.0)

## Every alpha-blended material of a pooled look at `k` of its built alpha (cached on the node at build).
func _fade(n: Node3D, k: float) -> void:
	if not n.has_meta("fade"):
		var mats: Array = []
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var mat := (mi as MeshInstance3D).material_override as StandardMaterial3D
			if mat != null:
				mats.append([mat, mat.albedo_color.a])
		n.set_meta("fade", mats)
	for pair in n.get_meta("fade"):
		var mat2: StandardMaterial3D = pair[0]
		mat2.albedo_color.a = float(pair[1]) * k

func _timed(kind: String, at: Vector3, r: float, secs: float) -> Node3D:
	var n := _take(kind)
	n.global_position = at
	n.scale = Vector3(r, 1.0, r)
	n.rotation.y = vis_rng.randf() * TAU
	_fade(n, 1.0)
	timed.append({"n": n, "kind": kind, "t": 0.0, "dur": secs, "ent": null, "r": r})
	return n

# ------------------------------------------------------------------ lingering effects
## A refreshed effect held on an entity (call every step while it should show). key: unique per use.
## A mote takes `col` (its halo, and a paler hot core).
func hold_on(key: String, kind: String, ent: Node3D, at: Vector3, scl := 1.0, col := Color.WHITE) -> Node3D:
	var hd: Dictionary = held.get(key, {})
	if hd.is_empty():
		hd = {"n": _take(kind), "kind": kind, "ent": ent, "t": 0.0}
		held[key] = hd
	hd["t"] = float(m.time)
	var n: Node3D = hd["n"]
	n.global_position = at
	n.scale = Vector3.ONE * scl
	if kind == "mote":
		((n.get_node("Halo") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Color(col, 0.85)
		var core := (n.get_node("Core") as MeshInstance3D).material_override as ShaderMaterial
		core.set_shader_parameter("color", Color(col.lightened(0.45), 0.9))
	return n

## Ends a held effect now instead of after KEEP.
func release(key: String) -> void:
	if held.has(key):
		_give(String(held[key]["kind"]), held[key]["n"])
		held.erase(key)

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

## Tarek's heavy impacts (the slam, the leap's landing) at `at`, radius `r`, strength k 0..1: a molten
## starburst, rock chips flying out, a dust ring at the edge, and a dark red cracked crater left `secs`.
func impact(at: Vector3, r: float, k: float, secs := 1.0) -> void:
	_timed("burst", at, r * 0.7, 0.32)
	_timed("crater", at, r * 0.5, secs)
	chips(at, int(5 + 6 * k), k)
	m.fx.ring(at, r, Color(0.62, 0.47, 0.32, 0.95), 0.42)
	m.fx.burst(at + Vector3(0, 0.25, 0), Color(0.66, 0.52, 0.38, 0.9), int(14 + 12 * k), 6.0, 0.5, 5.0, 1.8)

## Rock chips thrown out from `at`.
func chips(at: Vector3, count: int, k: float) -> void:
	for i in count:
		var a := vis_rng.randf() * TAU
		var out := 3.0 + vis_rng.randf() * 4.0 * (0.6 + k)
		var chip := _take("shard")
		chip.global_position = at + Vector3(cos(a) * 0.4, 0.3, sin(a) * 0.4)
		chip.scale = Vector3.ONE * (0.8 + vis_rng.randf() * 0.8)
		var vel := Vector3(cos(a) * out, 5.0 + vis_rng.randf() * 4.0, sin(a) * out)
		timed.append({"n": chip, "kind": "shard", "t": 0.0, "dur": 1.2, "ent": null, "vel": vel, "floor": at.y})

## Ostra's rune sigil at `at` (radius `r`), its ring lit to `fill` 0..1 in `col` (refresh every step).
func sigil(key: String, ent: Node3D, at: Vector3, r: float, fill: float, col: Color) -> void:
	var n := hold_on(key, "sigil", ent, at + Vector3(0, 0.06, 0))
	n.scale = Vector3(r, 1.0, r)
	n.rotation.y = fill * PI * 0.5
	var segs := n.get_node("Segs")
	var lit := int(round(fill * SIGIL_SEGS))
	for i in SIGIL_SEGS:
		(segs.get_child(i) as Node3D).visible = i < maxi(1, lit)
	(n.get_meta("seg_mat") as StandardMaterial3D).albedo_color = Color(col, 0.95)
	(n.get_meta("star_mat") as StandardMaterial3D).albedo_color = Color(col, 0.3 + 0.65 * fill)

## Something arriving out of nowhere at `at`: motes rushing in to a point, a dark core and a ring.
func implode(at: Vector3, col: Color) -> void:
	m.fx.burst(at + Vector3(0, 1.0, 0), Color(col, 0.9), 22, -6.0, 0.3, 0.0, 1.3)
	m.fx.burst(at + Vector3(0, 1.0, 0), Color(0.08, 0.02, 0.14, 0.9), 8, -3.0, 0.25, 0.0, 1.8)
	m.fx.ring(at, 1.2, Color(col, 0.9), 0.2)

## The grown seed's light column (it rises quickly, stays `secs`).
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
