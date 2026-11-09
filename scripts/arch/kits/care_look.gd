class_name CareLook
extends RefCounted
## Pooled looks of the support pair (docs/heroes/tender.md, docs/heroes/rimewright.md): every node is
## built once per kind and kept hidden when free, so a held LMB never creates nodes per shot.
##   Pip: the starlit comet, the burr orb, the Burrseed root disc, light column and root beam, the lantern
##   plus, the Hearthlight disc with its floating lantern and the Kindle foot glow.
##   Claire: the ice shard, the skate beam, the star-headed spear (thrown, and held while aiming), the
##   slow-zone flake with its crystal, the Shatter spikes, the frost shell, the frost glow, the skate's
##   ice plates, her air dash's frost streaks and the Rink Wall's ice pillars.
## Three shaders of our own: shaders/care_disc.gdshader, care_ice.gdshader, care_glow.gdshader.
## Shots: skin(s, kind) hides the shared round (its drawn radius only; the hit radius is unchanged) and
## rides a pooled node on it; when the shot ends the node goes back and the kind's impact plays.
## Timed one-offs: burst(kind, at, p). Held looks (refresh every step, gone 0.1 s after the last call):
## keep(key, kind, at, p).

const DISC: Shader = preload("res://shaders/care_disc.gdshader")
const ICE: Shader = preload("res://shaders/care_ice.gdshader")
const GLOW: Shader = preload("res://shaders/care_glow.gdshader")
const KEEP := 0.1             # s a held look stays after its last refresh
const CAP := 24               # per kind: past this the oldest live one is reused
const EMBER_R := 0.22         # m: the ember's head radius as built; the kit scales it to the shot's hit radius
const EMBER_HIT_R := 0.6      # m: the leaf flash where an ember lands, about a small foe's hit circle
static var LEAF := HeroVfx.col("tender", "main")      # Meeko's leaf green and its tints (her palette)
static var LEAF_HOT := HeroVfx.col("tender", "hot")
static var LEAF_PALE := HeroVfx.col("tender", "pale")
static var LEAF_HEAL := HeroVfx.col("tender", "heal")

var m: Node
var h: Hunter
var root: Node3D
var free_pool := {}              # kind -> Array[Node3D] (hidden)
var skins: Array = []         # {s: shot, n: Node3D, kind}
var live: Array = []          # {n, kind, t, dur, at, p}
var held := {}                # key -> {n, kind, last, p}
var made := 0                 # nodes built (tests: stays flat while firing)

func _init(match_node: Node, hunter: Hunter) -> void:
	m = match_node
	h = hunter
	root = Node3D.new()
	root.name = "CareLook"
	root.top_level = true
	m.add_child(root)

func teardown() -> void:
	if is_instance_valid(root):
		root.queue_free()
	skins.clear()
	live.clear()
	held.clear()
	free_pool.clear()

# ------------------------------------------------------------------ materials
static func ice_mat(c: Color, a := 0.75, glow := 0.0, edge := Color(0, 0, 0, 0)) -> ShaderMaterial:
	var mt := ShaderMaterial.new()
	mt.shader = ICE
	mt.set_shader_parameter("color", Color(c, a))
	mt.set_shader_parameter("edge", c.lightened(0.6) if edge.a <= 0.0 else edge)
	mt.set_shader_parameter("glow", glow)
	return mt

static func glow_mat(c: Color, fade := 1.0) -> ShaderMaterial:
	var mt := ShaderMaterial.new()
	mt.shader = GLOW
	mt.set_shader_parameter("color", c)
	mt.set_shader_parameter("fade_end", fade)
	return mt

## A soft ball of light (care_glow in orb mode), mixed so it keeps its colour on bright ground.
static func orb_mat(c: Color) -> ShaderMaterial:
	var mt := glow_mat(c)
	mt.set_shader_parameter("orb", 1.0)
	return mt

static func disc_mat(c: Color, rim: Color, pattern: float) -> ShaderMaterial:
	var mt := ShaderMaterial.new()
	mt.shader = DISC
	mt.set_shader_parameter("color", c)
	mt.set_shader_parameter("rim", rim)
	mt.set_shader_parameter("pattern", pattern)
	return mt

static func _off(mi: MeshInstance3D) -> MeshInstance3D:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## A ribbon behind a moving head: a flat and an upright strip along +Z (the head flies toward -Z).
static func _tail(n: Node3D, w: float, length: float, c: Color) -> Node3D:
	var t := Node3D.new()
	t.name = "Tail"
	n.add_child(t)
	for up in [false, true]:
		var pm := PlaneMesh.new()
		pm.size = Vector2(w, length)
		var mi := _off(Models.part(t, pm, glow_mat(c), Vector3(0, 0, length * 0.5)))
		if up: mi.rotation = Vector3(0, 0, PI * 0.5)
	return t

# ------------------------------------------------------------------ builders
func _build(kind: String) -> Node3D:
	made += 1
	var n := Node3D.new()
	n.name = kind
	match kind:
		"ember":
			# a mote of her lantern's light in her leaf green (#5fdc6a, Arch.color): a teardrop head the size of the
			# shot's hit circle with a near-white core, a thin pale-leaf halo and a tail as wide as the head
			var head := Models.sphere(EMBER_R, 12)
			_off(Models.part(n, head, orb_mat(Color(LEAF, 1.0)), Vector3.ZERO, Vector3(1, 1, 1.5)))
			_off(Models.part(n, Models.sphere(EMBER_R * 0.45, 8), orb_mat(Color(LEAF_HOT, 1.0)), Vector3(0, 0, -0.06)))
			_off(Models.part(n, Models.sphere(EMBER_R * 1.35, 10), orb_mat(Color(LEAF_PALE, 0.35)), Vector3.ZERO))
			_tail(n, EMBER_R * 1.8, 1.6, Color(LEAF_PALE, 0.9))
		"burr":
			# a spiky green burr that tumbles, a fluff halo and a pale seed-down tail
			var sp := Node3D.new()
			sp.name = "Spin"
			n.add_child(sp)
			_off(Models.part(sp, Models.sphere(0.16, 10), Models.toon(Color("9cc04a"), true, 0.8), Vector3.ZERO))
			for i in 12:
				var a := TAU * i / 12.0
				var b := (0.6 if i % 2 == 0 else -0.6)
				var dv := Vector3(cos(a) * cos(b), sin(b), sin(a) * cos(b))
				var sm := _off(Models.part(
						sp, Models.cyl(0.0, 0.035, 0.16, 5), Models.toon(Color("e6f2a0"), true, 0.9), dv * 0.18))
				sm.basis = Basis(Quaternion(Vector3.UP, dv.normalized()))
			_off(Models.part(n, Models.sphere(0.34, 10), orb_mat(Color("c8e07a", 0.3)), Vector3.ZERO))
			_tail(n, 0.22, 1.4, Color("e8f6b8", 0.55))
		"shard":
			# an ice dart: a long frost-cyan (her signature) four-sided crystal with dark teal edges, tip first,
			# a white-hot core down its length and a short pale frost streak
			var dart_ice := ice_mat(Color("8ae6ff"), 0.8, 0.15, Color("1f8a96"))
			var c := _off(Models.part(n, Models.crystal(0.11, 0.8, 4), dart_ice, Vector3.ZERO))
			c.rotation = Vector3(-PI * 0.5, 0, PI * 0.25)
			_off(Models.part(n, Models.sphere(0.045, 8), orb_mat(Color("f2ffff", 1.0)), Vector3.ZERO, Vector3(1, 1, 7)))
			_off(Models.part(n, Models.sphere(0.07, 8), orb_mat(Color("e8ffff", 0.9)), Vector3(0, 0, -0.34)))
			_tail(n, 0.16, 1.1, Color("6fd8f0", 0.75))
		"beam":
			# the skating dart: a thick (0.3 m) straight lance of frost-cyan ice round a white-hot core, a soft
			# cyan glow body and a long streak
			var lance_ice := ice_mat(Color("8ae6ff"), 0.8, 0.3, Color("1f8a96"))
			var c2 := _off(Models.part(n, Models.crystal(0.15, 1.3, 5), lance_ice, Vector3.ZERO))
			c2.rotation = Vector3(-PI * 0.5, 0, 0)
			_off(Models.part(n, Models.sphere(0.07, 8), orb_mat(Color("f8ffff", 1.0)), Vector3.ZERO, Vector3(1, 1, 8)))
			_off(Models.part(n, Models.sphere(0.2, 10), orb_mat(Color("8ae6ff", 0.45)), Vector3.ZERO, Vector3(1, 1, 4)))
			_tail(n, 0.3, 2.8, Color("4fd0f0", 0.85))
		"spear":
			# the Ice Spear: an ice-blue shaft and four-point star head with dark teal edges, so it reads blue
			# on grass at gameplay zoom; white is kept to the tip glint and a short frost streak
			var spear_ice := ice_mat(Color("9af0ff"), 0.95, 0.2, Color("1f8a96"))
			var sh := _off(Models.part(n, Models.crystal(0.12, 1.7, 4), spear_ice, Vector3(0, 0, 0.35)))
			sh.rotation = Vector3(-PI * 0.5, 0, 0)
			var st := Node3D.new()
			st.name = "Spin"
			st.position = Vector3(0, 0, -0.55)
			n.add_child(st)
			for i in 4:
				var a2 := TAU * i / 4.0
				var point_at := Vector3(cos(a2), sin(a2), 0) * 0.24
				var pt := _off(Models.part(st, Models.crystal(0.09, 0.5, 4), spear_ice, point_at))
				pt.rotation = Vector3(0, 0, a2 - PI * 0.5)
			_off(Models.part(n, Models.sphere(0.1, 8), orb_mat(Color("f2ffff", 0.95)), Vector3(0, 0, -0.66)))
			var spear_tail := _tail(n, 0.34, 4.0, Color("4fc8ec", 0.85))
			# the short white frost streak rides on the tail, so it is hidden with it while the spear is held
			var streak_mat := orb_mat(Color("e8ffff", 0.8))
			_off(Models.part(spear_tail, Models.box(0.04, 0.04, 0.5), streak_mat, Vector3(0, 0, 0.6)))
		"plus":
			# the lantern plus: a big soft glowing cross with a halo
			var gc := LEAF_HEAL
			_off(Models.part(n, Models.box(0.32, 1.2, 0.12), orb_mat(Color(gc, 0.9)), Vector3.ZERO))
			_off(Models.part(n, Models.box(1.2, 0.32, 0.12), orb_mat(Color(gc, 0.9)), Vector3.ZERO))
			_off(Models.part(n, Models.sphere(0.75, 12), orb_mat(Color(gc.lightened(0.3), 0.3)), Vector3.ZERO))
		"column", "beam_root":
			# upright light planes (a column falls over a foe; the root beam holds)
			for i in 3:
				var pm2 := PlaneMesh.new()
				pm2.size = Vector2(1.0, 3.0)
				var mi := _off(Models.part(n, pm2, glow_mat(Color(1, 1, 1, 0.8), 0.0), Vector3.ZERO))
				mi.position = Vector3(0, 1.5, 0)
				mi.rotation = Vector3(PI * 0.5, TAU * i / 3.0 * 0.5 + PI * 0.25, 0)
		"disc", "flare", "zone", "kindle", "hearth":
			var pm3 := PlaneMesh.new()
			pm3.size = Vector2(2, 2)
			_off(Models.part(n, pm3, disc_mat(Color.WHITE, Color.WHITE, 0.0), Vector3(0, 0.06, 0))).name = "Disc"
			if kind == "hearth":
				_build_lamp(n)
			if kind == "zone":
				# the slow zone's crystal that spins over its middle
				var cr := Node3D.new()
				cr.name = "Spin"
				cr.position = Vector3(0, 0.9, 0)
				n.add_child(cr)
				_off(Models.part(cr, Models.crystal(0.16, 0.7, 4), ice_mat(Color("e8ffff"), 0.85, 0.5), Vector3.ZERO))
				for i in 3:
					var a4 := TAU * i / 3.0
					_off(Models.part(
							cr, Models.crystal(0.06, 0.3, 4), ice_mat(Color("bff7ef"), 0.8, 0.3),
							Vector3(cos(a4) * 0.32, -0.2, sin(a4) * 0.32), Vector3.ONE, Vector3(0, 0, 0.5)))
		"spikes":
			# Shatter: a starburst of ice spikes thrown up round the foe
			for i in 12:
				var a5 := TAU * i / 12.0 + (0.12 if i % 2 else 0.0)
				var ln := 1.0 if i % 2 == 0 else 0.7
				var sk := _off(Models.part(
						n, Models.crystal(0.11, 1.0, 4), ice_mat(Color("6fe0f0"), 0.97, 0.1, Color("e8ffff")),
						Vector3.ZERO))
				sk.set_meta("dir", Vector3(cos(a5), 0, sin(a5)))
				sk.set_meta("ln", ln)
				sk.basis = Basis(Quaternion(
						Vector3.UP, Vector3(cos(a5), 0.75, sin(a5)).normalized())).scaled(Vector3(1, ln, 1))
		"shell":
			# the frost shell: crystals grown round a body
			for i in 7:
				var a6 := TAU * i / 7.0
				var s2 := _off(Models.part(
						n, Models.crystal(0.16, 1.1 - 0.12 * (i % 3), 5), ice_mat(Color("bff7ef"), 0.55, 0.2),
						Vector3(cos(a6) * 0.32, 0.6 + 0.12 * (i % 2), sin(a6) * 0.32)))
				s2.basis = Basis(Quaternion(Vector3.UP, Vector3(cos(a6) * 0.35, 1.0, sin(a6) * 0.35).normalized()))
		"frost":
			_off(Models.part(n, Models.capsule(0.42, 1.5), orb_mat(Color("2fb0e0", 0.55)), Vector3(0, 0.8, 0)))
		"slab":
			# a plate of ice laid under her blades
			_off(Models.part(
					n, Models.box(1.0, 0.05, 0.7), ice_mat(Color("bff7ef"), 0.7, 0.35, Color("e8ffff")),
					Vector3(0, 0.04, 0)))
		"wall":
			_build_wall(n)
	root.add_child(n)
	return n

## The Hearthlight's lantern: a small caged lantern of light floating over the disc's middle, with a halo.
func _build_lamp(n: Node3D) -> void:
	var lamp := Node3D.new()
	lamp.name = "Lamp"
	lamp.position = Vector3(0, 1.3, 0)
	n.add_child(lamp)
	_off(Models.part(lamp, Models.sphere(0.2, 12), orb_mat(Color(LEAF_PALE, 1.0)), Vector3.ZERO, Vector3(1, 1.3, 1)))
	_off(Models.part(lamp, Models.sphere(0.5, 12), orb_mat(Color(LEAF, 0.45)), Vector3.ZERO))
	var cage := Models.toon(Color("5a3d28"))
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		_off(Models.part(lamp, Models.box(0.025, 0.4, 0.025), cage, Vector3(cos(a) * 0.17, 0, sin(a) * 0.17)))
	_off(Models.part(lamp, Models.cyl(0.0, 0.2, 0.12, 8), cage, Vector3(0, 0.26, 0)))
	_off(Models.part(lamp, Models.cyl(0.18, 0.14, 0.05, 8), cage, Vector3(0, -0.22, 0)))

## The Rink Wall: a row of leaning ice pillars on a frosted footing, each its own height.
func _build_wall(n: Node3D) -> void:
	for i in 9:
		var hh := 1.6 + 0.7 * absf(sin(float(i) * 2.3)) + (0.4 if i == 4 else 0.0)
		var p := _off(Models.part(
				n, Models.crystal(0.34, hh, 5), ice_mat(Color("9fe9e4"), 0.62, 0.15), Vector3(0, hh * 0.5, 0)))
		p.name = "P%d" % i
		p.set_meta("h", hh)
		p.rotation = Vector3(0.12 * sin(float(i) * 1.7), float(i) * 0.9, 0.16 * cos(float(i) * 1.3))
	var foot := _off(Models.part(
			n, Models.box(1.0, 0.35, 0.8), ice_mat(Color("dffcff"), 0.45, 0.1), Vector3(0, 0.17, 0)))
	foot.name = "Foot"
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.0, 1.6)
	var mist := _off(Models.part(n, pm, disc_mat(Color("bff7ef", 0.5), Color("e8ffff", 0.6), 2.0), Vector3(0, 0.05, 0)))
	mist.name = "Mist"

# ------------------------------------------------------------------ pool
func _take(kind: String) -> Node3D:
	var fl: Array = free_pool.get(kind, [])
	while not fl.is_empty():
		var n: Node3D = fl.pop_back()
		if is_instance_valid(n):
			n.visible = true
			return n
	var count := 0
	for e in live:
		if String(e["kind"]) == kind: count += 1
	if count >= CAP:
		for e in live:
			if String(e["kind"]) == kind:
				live.erase(e)
				return e["n"]
	var nn := _build(kind)
	return nn

func _give(kind: String, n: Node3D) -> void:
	if not is_instance_valid(n):
		return
	n.visible = false
	var fl: Array = free_pool.get(kind, [])
	fl.append(n)
	free_pool[kind] = fl

# ------------------------------------------------------------------ shots
## Rides a pooled look on a shot (the shared round shrinks to nothing, its hit radius stays). `lob`: the look
## arcs from the shot's height down to lob.y over lob.dist metres (a thrown spear), peaking lob.h above the line.
func skin(s: Dictionary, kind: String, lob := {}, look_scale := 1.0) -> void:
	s["vr"] = 0.001
	var n := _take(kind)
	n.scale = Vector3.ONE * look_scale
	n.global_position = s["pos"]
	var tail := n.get_node_or_null("Tail") as Node3D
	if tail: tail.visible = true
	skins.append({"s": s, "n": n, "kind": kind, "last": s["pos"], "lob": lob})

## The shot dictionary spawned last by this hunter (spawn_shot appends it).
func last_shot() -> Dictionary:
	for i in range(m.shots.size() - 1, -1, -1):
		if m.shots[i]["by"] == h:
			return m.shots[i]
	return {}

func _tick_skins(dt: float) -> void:
	for sk in skins.duplicate():
		var s: Dictionary = sk["s"]
		var n: Node3D = sk["n"]
		var kind := String(sk["kind"])
		if not m.shots.has(s):
			skins.erase(sk)
			_give(kind, n)
			impact(kind, sk["last"], s)
			continue
		var p: Vector3 = s["pos"]
		sk["last"] = p
		if not is_instance_valid(n):
			continue
		var v: Vector2 = s["vel"]
		var slope := 0.0
		if not (sk["lob"] as Dictionary).is_empty():
			var arc := _lob_at(sk["lob"], s)
			p.y = arc.x
			slope = arc.y
			sk["last"] = p
		n.global_position = p
		if v.length() > 0.5:
			n.look_at(p + Vector3(v.x, v.length() * slope, v.y), Vector3.UP)
		var sp := n.get_node_or_null("Spin") as Node3D
		if sp and kind == "spear":
			sp.rotate_z(dt * 14.0)
		elif sp:
			sp.rotate_x(dt * 18.0)
		# the tail grows out of the hand over the first few metres
		var tl := n.get_node_or_null("Tail") as Node3D
		if tl:
			var gone := Vector2(p.x - (s["start"] as Vector3).x, p.z - (s["start"] as Vector3).z).length()
			tl.scale = Vector3(1, 1, clampf(gone / 2.0, 0.15, 1.0))

## A lobbed look's height and slope (dy per metre) where its shot is now, from the throw's start.
func _lob_at(lob: Dictionary, s: Dictionary) -> Vector2:
	var start: Vector3 = s["start"]
	var p: Vector3 = s["pos"]
	var dist := maxf(0.5, float(lob["dist"]))
	var u := clampf(Vector2(p.x - start.x, p.z - start.z).length() / dist, 0.0, 1.0)
	var top := float(lob["h"])
	var y := lerpf(start.y, float(lob["y"]), u) + sin(u * PI) * top
	var slope := (float(lob["y"]) - start.y + cos(u * PI) * PI * top) / dist
	return Vector2(y, slope)

## The kind's own impact where the shot stopped.
func impact(kind: String, at: Vector3, s: Dictionary) -> void:
	var d2: Vector2 = (s.get("vel", Vector2.ZERO) as Vector2).normalized()
	var back := Vector3(-d2.x, 0.4, -d2.y)
	match kind:
		"ember":
			m.fx.flash(at, LEAF_HOT, 0.6, 0.07)
			m.fx.spark(at, back, LEAF, 8, 6.0, 70.0, 0.25, 6.0)
			var hit_p := {"col": LEAF, "rim": LEAF_HOT, "r": EMBER_HIT_R, "dur": 0.3, "glow": 1.0}
			burst("star", at, hit_p)
		"shard":
			HeroVfx.of(m).play(h, "dart_hit", at, d2)          # content/vfx/rimewright.json
		"beam":
			HeroVfx.of(m).play(h, "beam_hit", at, d2)
		"spear":
			m.fx.flash(at, Color("9af0ff"), 0.6, 0.06)
		"burr":
			m.fx.flash(at, Color("c8e07a"), 0.6, 0.06)

# ------------------------------------------------------------------ timed one-offs
## A one-off look that plays out by itself. p: col, r (size), dur, ent (follow a body), dir (Vector2), and for a
## flare: rim, pattern, glow.
func burst(kind: String, at: Vector3, p := {}) -> void:
	var node_kind := "flare" if kind == "star" else kind
	var n := _take(node_kind)
	n.global_position = at
	n.scale = Vector3.ONE * 0.01
	var e := {"n": n, "kind": node_kind, "fx": kind, "t": 0.0, "dur": float(p.get("dur", 0.4)), "at": at, "p": p}
	_style(e, 0.0)
	live.append(e)

func _tick_live(dt: float) -> void:
	for e in live.duplicate():
		e["t"] = float(e["t"]) + dt
		var k := float(e["t"]) / maxf(0.01, float(e["dur"]))
		if k >= 1.0:
			live.erase(e)
			_give(String(e["kind"]), e["n"])
			continue
		var ev = (e["p"] as Dictionary).get("ent")
		if ev != null:
			if not is_instance_valid(ev):
				e["t"] = e["dur"]
				continue
			e["at"] = (ev as Node3D).global_position
		(e["n"] as Node3D).global_position = e["at"]
		_style(e, k)

## Shape and fade of a one-off at k (0..1 of its life).
func _style(e: Dictionary, k: float) -> void:
	var n: Node3D = e["n"]
	var p: Dictionary = e["p"]
	var r := float(p.get("r", 1.0))
	var col: Color = p.get("col", Color.WHITE)
	var pop := _out_back(clampf(k * 4.0, 0.0, 1.0))
	var fade := 1.0 - smoothstep(0.55, 1.0, k)
	match String(e["fx"]):
		"plus":
			n.scale = Vector3.ONE * r * pop
			n.rotation.y = k * 1.2
			_tint(n, col, fade)
		"column", "beam_root":
			var w := r * (1.0 if String(e["fx"]) == "column" else 0.45)
			n.scale = Vector3(w, lerpf(1.4, 1.0, pop) if String(e["fx"]) == "column" else 1.0, w)
			_tint(n, col, fade * (0.9 if String(e["fx"]) == "column" else 0.6 + 0.2 * sin(k * 40.0)))
		"flare", "star":
			n.scale = Vector3.ONE * r * lerpf(0.4, 1.0, sqrt(k))
			_disc(
					n, col, p.get("rim", col.lightened(0.5)), fade, float(p.get("pattern", 0.0)), -1.0, k * 2.0,
					float(p.get("glow", 0.0)))
		"spikes":
			# up fast, hold, then sink back into the ground
			var up := clampf(k * 7.0, 0.0, 1.0)
			var sink := smoothstep(0.6, 1.0, k)
			n.scale = Vector3.ONE
			for c in n.get_children():
				var mi := c as MeshInstance3D
				if mi == null: continue
				var dv3: Vector3 = mi.get_meta("dir", Vector3.FORWARD)
				mi.position = dv3 * r * 0.55 * up + Vector3(0, -sink * 0.7, 0)
				mi.scale = Vector3(
						r * 0.6, r * 1.1 * float(mi.get_meta("ln", 1.0)) * _out_back(up), r * 0.6) * (1.0 - sink * 0.5)
			_tint(n, col, 1.0 - sink * 0.8)
		"shell":
			n.scale = Vector3.ONE * lerpf(
					0.4, 1.0, _out_back(clampf(k * 6.0, 0.0, 1.0))) * (1.0 - 0.3 * smoothstep(0.8, 1.0, k))
			_tint(n, col, 1.0 - smoothstep(0.8, 1.0, k))
		"slab":
			var dv4: Vector2 = p.get("dir", Vector2(0, -1))
			n.rotation = Vector3(0, atan2(-dv4.x, -dv4.y), 0)
			var forms := lerpf(0.6, 1.0, clampf(k * 15.0, 0.0, 1.0))          # frozen in under the blade at once
			n.scale = Vector3(r * forms, 1.0, r * forms)
			_tint(n, Color.WHITE, 1.0 - smoothstep(0.3, 1.0, k))
		_:
			n.scale = Vector3.ONE * r
			_tint(n, col, fade)

static func _out_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)

## Fades every material under n (shader "color" alpha or "alpha"), keeping each part's own colour
## unless `col` is given (white means: keep).
func _tint(n: Node, col: Color, a: float) -> void:
	for c in n.get_children():
		var mi := c as MeshInstance3D
		if mi and mi.material_override is ShaderMaterial:
			var sm := mi.material_override as ShaderMaterial
			if sm.shader == ICE:
				sm.set_shader_parameter("alpha", a)
			else:
				var base: Color = mi.get_meta("c0") if mi.has_meta("c0") else sm.get_shader_parameter("color")
				if not mi.has_meta("c0"): mi.set_meta("c0", base)
				var cc := base if col == Color.WHITE else Color(col.r, col.g, col.b, base.a)
				sm.set_shader_parameter("color", Color(cc.r, cc.g, cc.b, base.a * a))
		if c.get_child_count() > 0:
			_tint(c, col, a)

func _disc(n: Node3D, col: Color, rim: Color, a: float, pattern: float, sweep: float, spin: float, glow := 0.0) -> void:
	var mi := n.get_node_or_null("Disc") as MeshInstance3D
	if mi == null: return
	var sm := mi.material_override as ShaderMaterial
	sm.set_shader_parameter("color", Color(col, col.a * a))
	sm.set_shader_parameter("rim", Color(rim, rim.a * a))
	sm.set_shader_parameter("pattern", pattern)
	sm.set_shader_parameter("sweep", sweep)
	sm.set_shader_parameter("spin", spin)
	sm.set_shader_parameter("glow", glow)

# ------------------------------------------------------------------ held looks
## A look that stays while the kit keeps calling it (by key). p: col, rim, r, fill, sweep, pattern,
## spin, a (strength), glow (a lit, feathered rim), ent (sit under a body), and for "wall": a, b (Vector2 ends),
## y, hit (0..1).
func keep(key: String, kind: String, at: Vector3, p := {}) -> void:
	var e: Dictionary = held.get(key, {})
	if e.is_empty() or String(e["kind"]) != kind or not is_instance_valid(e["n"]):
		if not e.is_empty(): _give(String(e["kind"]), e["n"])
		e = {"n": _take(kind), "kind": kind}
		held[key] = e
	e["last"] = m.time
	e["p"] = p
	var n: Node3D = e["n"]
	n.global_position = at
	match kind:
		"wall":
			_place_wall(n, p)
		"frost":
			n.scale = Vector3.ONE * float(p.get("r", 1.0))
			_tint(n, Color.WHITE, float(p.get("a", 1.0)))
		"spear":
			n.global_transform = p["xf"]          # the held spear, placed by the kit in her raised hand
			(n.get_node("Tail") as Node3D).visible = false
		_:
			var r := float(p.get("r", 1.0))
			n.scale = Vector3(r, 1.0, r)
			var col: Color = p.get("col", Color.WHITE)
			_disc(
					n, col, p.get("rim", col.lightened(0.4)), float(p.get("a", 1.0)), float(p.get("pattern", 0.0)),
					float(p.get("sweep", -1.0)), float(p.get("spin", 0.0)), float(p.get("glow", 0.0)))
			var dm := n.get_node_or_null("Disc") as MeshInstance3D
			if dm: (dm.material_override as ShaderMaterial).set_shader_parameter("fill", float(p.get("fill", 1.0)))
			var lamp := n.get_node_or_null("Lamp") as Node3D
			if lamp:
				lamp.scale = Vector3(1.0 / maxf(0.1, r), 1.0, 1.0 / maxf(0.1, r))
				lamp.visible = bool(p.get("lamp", true))
				lamp.position.y = 1.3 + 0.06 * sin(m.time * 3.0)
			var sp := n.get_node_or_null("Spin") as Node3D
			if sp:
				sp.rotation.y = m.time * 2.6
				sp.position.y = 0.9 + 0.08 * sin(m.time * 3.0)
				sp.scale = Vector3.ONE / maxf(0.3, r) * 1.6

func drop(key: String) -> void:
	var e: Dictionary = held.get(key, {})
	if e.is_empty(): return
	held.erase(key)
	_give(String(e["kind"]), e["n"])

func showing(key: String) -> bool:
	return held.has(key) and m.time - float(held[key]["last"]) <= KEEP

func _tick_held() -> void:
	for key in held.keys():
		var e: Dictionary = held[key]
		if m.time - float(e["last"]) > KEEP:
			drop(key)

## The Rink Wall's pillars spread over the wall's current span, hit flashes whitening them.
func _place_wall(n: Node3D, p: Dictionary) -> void:
	var a: Vector2 = p["a"]
	var b: Vector2 = p["b"]
	var mid := (a + b) * 0.5
	var ln := maxf(0.4, a.distance_to(b))
	n.global_position = Vector3(mid.x, float(p.get("y", n.global_position.y)), mid.y)
	n.rotation = Vector3(0, -atan2(b.y - a.y, b.x - a.x), 0)
	var rise := clampf(float(p.get("rise", 1.0)), 0.0, 1.0)
	var hit := float(p.get("hit", 0.0))
	for i in 9:
		var pl := n.get_node_or_null("P%d" % i) as MeshInstance3D
		if pl == null: continue
		var hh := float(pl.get_meta("h", 2.0))
		pl.position = Vector3((float(i) / 8.0 - 0.5) * (ln - 0.3), hh * 0.5 * rise, 0)
		pl.scale = Vector3(1.0, maxf(0.05, rise), 1.0) * (1.0 + 0.06 * hit)
		(pl.material_override as ShaderMaterial).set_shader_parameter("glow", 0.15 + 0.8 * hit + 0.25 * (1.0 - rise))
	var ft := n.get_node_or_null("Foot") as MeshInstance3D
	if ft: ft.scale = Vector3(ln, maxf(0.05, rise), 1.0)
	var mist := n.get_node_or_null("Mist") as MeshInstance3D
	if mist:
		mist.scale = Vector3(ln + 0.8, 1.0, 1.0)
		var sm := mist.material_override as ShaderMaterial
		sm.set_shader_parameter("spin", m.time * 0.4)

# ------------------------------------------------------------------ per step
func tick(dt: float) -> void:
	_tick_skins(dt)
	_tick_live(dt)
	_tick_held()

## Live nodes right now (tests: pooled, so this stays bounded).
func node_count() -> int:
	return root.get_child_count() if is_instance_valid(root) else 0
