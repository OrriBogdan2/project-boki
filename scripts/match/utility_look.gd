class_name UtilityLook
extends RefCounted
## The look of the belt items that change a fight (briefs/UTILITY_PARITY.md), readable at match zoom:
## Skyfall Charge's fuse ring, the Blight Flask's patch edge, the two Twin Gate portals and the link
## between them, Thorn Wall's spikes and Warp Seed's anomaly. Our own shapes; the source's readability:
## where it hurts, when it lands, and where you come out. Everything hangs on a node the game already
## frees (the field, the wall) or frees itself on a step timer, and sits in group GROUP.

const GROUP := "util_look"
const FUSE_END_PAD := 0.3       # s a fuse ring lingers after the blast
const WARHEAD_HEIGHT := 28.0    # m above the target the Skyfall warhead starts
const BLIGHT_EDGE := Color("c9e84a")     # a sickly lime: never a friendly colour
const BLIGHT_BAND := Color("3a1a52")
const BLOBS := 22               # bubbles round the Blight patch edge
const SPIKE_GAP := 0.5          # m between Thorn Wall spikes
const BEADS := 4                # lights running along the Twin Gate link
const PORTAL_R := 1.0           # m, the Twin Gate ring's radius
const MOTES := 5                # lights orbiting the Warp Seed anomaly

## Item looks that need the cast point or the thing it made: called once the item's effects ran.
static func cast(h: Hunter, id: String) -> void:
	var m = h.m
	match id:
		"skyfall_charge":
			var d := UtilityBelt.def(id)
			var p := Effects._aim_point(h, {})
			p.y = m.world.ground_at(p.x, p.z) if not m.world.is_void(p.x, p.z) else h.pos.y
			var fx: Dictionary = (d["effects"] as Array)[0]
			fuse(m, p, float(fx["radius"]), float(fx["time"]), Color(String(fx["color"])))
		"blight_flask":
			if not m.fields.list.is_empty():
				blight_edge(m.fields.list.back())
		"thorn_wall":
			if not m.verbs.walls.is_empty():
				spikes(m.verbs.walls.back())

static func _tag(n: Node, nm: String) -> Node:
	n.name = nm
	n.add_to_group(GROUP)
	return n

static func _flat(parent: Node3D, r: float, col: Color, thick: float, y: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Models.flat_quad(r * 2.0)
	mi.material_override = Models.ring_mat(col, thick)
	mi.position.y = y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

## A lit, shadowless part.
static func _glow(parent: Node3D, mesh: Mesh, col: Color, pos := Vector3.ZERO, scl := Vector3.ONE,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := Models.part(parent, mesh, Models.glow_mat(col), pos, scl, rot)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

static func _loop(n: Node, prop: String, to: Variant, secs: float, from: Variant = null) -> void:
	var tw := n.create_tween().set_loops()
	var tp := tw.tween_property(n, prop, to, secs)
	if from != null:
		tp.from(from)

# ------------------------------------------------------------------ Skyfall
## A hot disc grows from the middle to the rim over the whole fuse while a warhead falls on it; the
## rim blinks faster as the blast nears. Gameplay-readable: it is exactly where the blast lands.
static func fuse(m: Node, at: Vector3, r: float, secs: float, col: Color) -> Node3D:
	var root := _tag(Node3D.new(), "SkyfallFuse") as Node3D
	m.add_child(root)
	root.global_position = at
	var rim := _flat(root, r * 1.02, Color(col, 0.9), 0.08, 0.1)
	var disc := _glow(root, Models.cyl(r, r, 0.03, 32), Color(col, 0.38), Vector3(0, 0.06, 0))
	disc.scale = Vector3(0.02, 1.0, 0.02)
	var head := _glow(root, Models.sphere(0.55, 12), Color(1.0, 0.9, 0.6, 0.95), Vector3(0, WARHEAD_HEIGHT, 0))
	# Driven by match time, not wall time, so the fill lands exactly on the blast through hitstop and slow frames.
	var t0: float = m.time
	var tw := root.create_tween().set_loops()
	var tick := func(_v): _fuse_step(clampf((m.time - t0) / secs, 0.0, 1.0), rim, disc, head, col, secs)
	tw.tween_method(tick, 0.0, 1.0, 0.05)
	m.later(secs + FUSE_END_PAD, func(): if is_instance_valid(root): root.queue_free())
	return root

static func _fuse_step(k: float, rim: MeshInstance3D, disc: Node3D, head: Node3D, col: Color, secs: float) -> void:
	var s := maxf(0.02, k)
	disc.scale = Vector3(s, 1.0, s)
	head.position.y = 0.6 + (WARHEAD_HEIGHT - 0.6) * (1.0 - k * k)
	var blink := 0.5 + 0.5 * sin(k * secs * (3.0 + 14.0 * k * k))
	var lit := Color(col.lightened(0.3 * blink), 0.6 + 0.4 * blink)
	(rim.material_override as ShaderMaterial).set_shader_parameter("color", lit)

# ------------------------------------------------------------------ Blight Flask
## A dark band at the very edge and a slow ring of lime bubbles: you can see where the patch stops.
static func blight_edge(z: Dictionary) -> void:
	var n: Node3D = z["node"]
	var r: float = z["r"]
	var look := _tag(Node3D.new(), "BlightEdge") as Node3D
	n.add_child(look)
	_flat(look, r * 1.03, Color(BLIGHT_BAND, 0.95), 0.1, 0.075)
	_flat(look, r * 1.03, Color(BLIGHT_EDGE, 0.9), 0.03, 0.09)
	var ring := Node3D.new()
	look.add_child(ring)
	var blob := Models.sphere(0.3, 8)
	for i in BLOBS:
		var a := TAU * float(i) / float(BLOBS)
		var s := 1.0 if i % 2 == 0 else 0.6
		var at := Vector3(cos(a), 0.0, sin(a)) * r * 0.97 + Vector3(0, 0.18 + 0.12 * (1.0 - s), 0)
		_glow(ring, blob, Color(BLIGHT_EDGE, 0.75), at, Vector3.ONE * s)
	_loop(ring, "rotation:y", TAU, 14.0, 0.0)

# ------------------------------------------------------------------ Thorn Wall
## Spikes along the top and out of both faces, so it reads as a hazard and not a shield.
static func spikes(w: Dictionary) -> void:
	var n: Node3D = w["node"]
	var col: Color = w["col"]
	var length: float = w["len"]
	var look := _tag(Node3D.new(), "ThornSpikes") as Node3D
	n.add_child(look)
	var mat := Models.toon(col.darkened(0.45), true, 0.4)
	var tip := Models.glow_mat(Color(col.lightened(0.5), 0.9))
	var cone := Models.cyl(0.0, 0.15, 0.9, 6)
	var count := int(length / SPIKE_GAP)
	for i in count:
		var x := (float(i) + 0.5) / float(count) * length - length * 0.5
		var tall := 1.0 + 0.4 * float(i % 2)
		Models.part(look, cone, mat, Vector3(x, Verbs.WALL_H + 0.3 * tall, 0), Vector3.ONE * tall)
		Models.part(look, Models.sphere(0.07, 6), tip, Vector3(x, Verbs.WALL_H + 0.75 * tall, 0))
		for side in [-1.0, 1.0]:
			var y := 0.55 + 0.8 * float(i % 2)
			Models.part(look, cone, mat, Vector3(x, y, side * 0.5), Vector3.ONE * 0.8, Vector3(side * 1.25, 0, 0))

# ------------------------------------------------------------------ Twin Gate
## Two upright rings that face along the line between them, each with a turning swirl inside, and a
## lit strip on the ground joining them with lights running to the far gate.
static func gate(za: Dictionary, zb: Dictionary) -> void:
	var a: Vector3 = za["at"]
	var d: Vector3 = (zb["at"] as Vector3) - a
	var col: Color = za["col"]
	var flat := Vector3(d.x, 0.0, d.z)
	var face := Basis.looking_at(flat.normalized(), Vector3.UP) if flat.length() > 0.1 else Basis.IDENTITY
	for z in [za, zb]:
		_portal(z["node"], face, col)
	if d.length() < 0.5:
		return
	var link := _tag(Node3D.new(), "GateLink") as Node3D
	(za["node"] as Node3D).add_child(link)
	link.position = d * 0.5 + Vector3(0, 0.14, 0)
	link.basis = Basis.looking_at(d.normalized(), Vector3.UP) if flat.length() > 0.1 else Basis.IDENTITY
	_glow(link, Models.box(0.2, 0.03, d.length()), Color(col, 0.5))
	var half := d.length() * 0.5
	for i in BEADS:
		var bead := _glow(link, Models.sphere(0.16, 8), Color(col.lightened(0.5), 0.95))
		var tw := bead.create_tween().set_loops()
		tw.tween_property(bead, "position:z", half, half * 0.5).from(-half).set_delay(float(i) * 0.25)

static func _portal(n: Node3D, face: Basis, col: Color) -> void:
	var root := _tag(Node3D.new(), "GatePortal") as Node3D
	n.add_child(root)
	root.basis = face
	root.position.y = PORTAL_R + 0.15
	var frame := TorusMesh.new()
	frame.inner_radius = PORTAL_R - 0.12
	frame.outer_radius = PORTAL_R
	var up := Vector3(PI * 0.5, 0, 0)
	_glow(root, frame, Color(col.lightened(0.35), 0.95), Vector3.ZERO, Vector3.ONE, up)
	var pane := Models.cyl(PORTAL_R - 0.1, PORTAL_R - 0.1, 0.03, 24)
	_glow(root, pane, Color(col.darkened(0.2), 0.32), Vector3.ZERO, Vector3.ONE, up)
	var swirl := Node3D.new()
	root.add_child(swirl)
	for k in 3:
		var arc := MeshInstance3D.new()
		arc.mesh = Models.flat_quad((PORTAL_R - 0.15) * (2.0 - 0.45 * k))
		var mat := Models.ring_mat(Color(col.lightened(0.5), 0.9), 0.14)
		mat.set_shader_parameter("arc", 0.55)
		arc.material_override = mat
		arc.basis = Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, float(k) * 2.1)
		arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		swirl.add_child(arc)
	_loop(swirl, "rotation:z", -TAU, 4.0, 0.0)

# ------------------------------------------------------------------ Warp Seed
## A dark core hanging in the air in a lilac shell, motes circling it, a beam up so it shows from
## afar, and two arcs turning on the ground.
static func anomaly(z: Dictionary) -> void:
	var n: Node3D = z["node"]
	var r: float = z["r"]
	var col: Color = z["col"]
	var root := _tag(Node3D.new(), "WarpAnomaly") as Node3D
	n.add_child(root)
	for k in 2:
		var arc := _flat(root, r * (1.0 - 0.3 * k), Color(col.lightened(0.4), 0.9), 0.16, 0.1 + 0.01 * k)
		(arc.material_override as ShaderMaterial).set_shader_parameter("arc", 0.6)
		_loop(arc, "rotation:y", TAU * (1.0 if k == 0 else -1.0), 3.0 + 1.5 * k, 0.0)
	var core := Node3D.new()
	root.add_child(core)
	core.position.y = 1.4
	Models.part(core, Models.sphere(0.42, 12), Models.toon(Color("1a0f2a"), false), Vector3.ZERO)
	_glow(core, Models.sphere(0.62, 12), Color(col, 0.42))
	_glow(root, Models.cyl(0.1, 0.1, 3.2, 8), Color(col, 0.22), Vector3(0, 1.6, 0))
	var orbit := Node3D.new()
	core.add_child(orbit)
	orbit.rotation.x = 0.5
	for i in MOTES:
		var a := TAU * float(i) / float(MOTES)
		_glow(orbit, Models.sphere(0.1, 6), Color(col.lightened(0.6), 0.95), Vector3(cos(a), 0, sin(a)) * 0.95)
	_loop(orbit, "rotation:y", TAU, 2.2, 0.0)
	var bob := core.create_tween().set_loops()
	bob.tween_property(core, "position:y", 1.65, 0.9).from(1.4).set_trans(Tween.TRANS_SINE)
	bob.tween_property(core, "position:y", 1.4, 0.9).set_trans(Tween.TRANS_SINE)
