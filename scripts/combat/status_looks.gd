class_name StatusLooks
extends Node3D
## The plain statuses on a Hunter's body (and on a Boki's or a mob's), readable at match distance:
## one pooled node per match (StatusLooks.of(m)), driven by content/rules/status_looks.json
## (docs/STATUS_LOOKS.md). Each status has its own look with its own shape, place and motion: stars
## spinning round the head (stun), a wobbling crystal ring high over it (Daze), thorns at the feet
## (root), cords round the legs (Grounded), rings sliding down the legs (slow), an ice shell (Chill),
## flame tongues (burning), bolts jumping across the body (Static), streaks draining upward
## (Anti-Heal), sinking wisps (resurrection sickness). Combo marks and their timers are the overhead
## tags'; this is only the body.
##
## Where a status comes from: the timers on the body (the game that owns it runs them), or put()/keep()
## for what this game only hears about: a kit's own status (Chill, Static), a remote body's kit status
## (KitStatus "kst"), and a hit sent to someone else's game (from_hit). Presentation only.
## Cost: one rig per (Hunter, status) shown, a few shared meshes and materials, pooled per status;
## nothing is made per frame and nothing draws past LOD_FAR from the camera focus.

const RULES_PATH := "res://content/rules/status_looks.json"
const LOD_FAR := 34.0          # m from the camera focus: no status drawn beyond (as HeroVfx)
const BODIES := ["hunters", "kins", "mobs"]      # the Match lists whose bodies' own timers are read
const MOB_K := 0.8             # a look's scale on a Boki or a mob (a Hunter's comes from its own scale)
const ARROW_Y := 2.1          # m over the feet: the Grounded arrow's tip at rest (just over the head)
const KEEP := 0.15             # s a keep() outlives its last ask

static var _rules := {}
static var _meshes := {}       # name -> Mesh, shared by every rig
static var _mats := {}         # "<hex>" -> unshaded material, shared by every rig

var m: Node
var rigs := {}                 # "<hunter id>/<status>" -> {n, h, st, look, t, seen}
var pool := {}                 # status -> hidden rigs to reuse
var told := {}                 # "<hunter id>/<status>" -> {h, st, until}
var made := 0                  # rigs built so far (tests: it stops growing once warm)
var _frame := 0

static func of(match_node: Node) -> StatusLooks:
	if match_node.has_meta("status_looks"):
		var f = match_node.get_meta("status_looks")
		if is_instance_valid(f):
			return f
	var n := StatusLooks.new()
	n.m = match_node
	n.name = "StatusLooks"
	match_node.add_child(n)
	match_node.set_meta("status_looks", n)
	return n

static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_rules = (parsed as Dictionary).get("statuses", {}) if parsed is Dictionary else {}
	return _rules

## True while the body's own timers carry `st` (the game that owns the body runs them).
static func carries(e: Ent, st: String) -> bool:
	match st:
		"stun": return e.stun_t > 0.0
		"daze": return KitStatus.rattled(e)
		"root": return e.root_t > 0.0
		"gnd": return KitStatus.grounded(e)
		"slow": return e.slow_t > 0.0
		"burn": return e.burn_t > 0.0
		"antiheal": return e.blight_t > 0.0
		"sick": return e is Hunter and (e as Hunter).sick_t > 0.0
	return false

## Whether the body carries any status at all (the cheap test before asking for each one).
static func _any(e: Ent) -> bool:
	return e.stun_t > 0.0 or e.root_t > 0.0 or e.slow_t > 0.0 or e.burn_t > 0.0 or e.blight_t > 0.0 \
		or e.has_meta("rat_until") or e.has_meta("gnd_until") or (e is Hunter and (e as Hunter).sick_t > 0.0)

## Shows `st` on `e` for `secs`: what this game only hears about (a remote body, a kit's own status).
func put(e: Ent, st: String, secs: float) -> void:
	if e == null or not rules().has(st) or secs <= 0.0:
		return
	var key := "%d/%s" % [e.get_instance_id(), st]
	var until := float(m.time) + secs
	if told.has(key):
		told[key]["until"] = maxf(float(told[key]["until"]), until)
	else:
		told[key] = {"h": e, "st": st, "until": until}

## Shows `st` on `e` while a kit keeps asking, once per tick (Chill, Static: the kit's own timers).
func keep(e: Ent, st: String) -> void:
	put(e, st, KEEP)

## A hit sent to the game that owns the body: show what it carries here until that game would end it.
func from_hit(e: Ent, o: Dictionary) -> void:
	for st in ["stun", "root", "slow"]:
		put(e, st, float(o.get(st, 0.0)))
	put(e, "antiheal", float(o.get("blight", 0.0)))
	if float(o.get("burn", 0.0)) > 0.0:
		put(e, "burn", float(o.get("burn_for", 3.0)))

## (tests) Whether `st`'s look is up on `e` now.
func showing(e: Ent, st: String) -> bool:
	tick(0.0)
	var r: Dictionary = rigs.get("%d/%s" % [e.get_instance_id(), st], {})
	return not r.is_empty() and (r["n"] as Node3D).visible

func _process(delta: float) -> void:
	tick(delta)

func tick(dt: float) -> void:
	_frame += 1
	var now := float(m.time)
	var viewer: Variant = m.get("player")
	for list_name in BODIES:
		var bodies: Variant = m.get(list_name)
		if bodies == null:
			continue
		for e: Ent in bodies:
			if not _any(e) or not _seen(e, viewer):
				continue
			for st: String in rules():
				if carries(e, st):
					_show(e, st, dt)
	for key: String in told.keys():
		var e: Dictionary = told[key]
		var hv: Variant = e["h"]
		if now >= float(e["until"]) or not is_instance_valid(hv):
			told.erase(key)
		elif _seen(hv, viewer):
			_show(hv, String(e["st"]), dt)
	for key: String in rigs.keys():
		var r: Dictionary = rigs[key]
		if int(r["seen"]) != _frame:
			(r["n"] as Node3D).visible = false
			(pool[r["st"]] as Array).append(r["n"])
			rigs.erase(key)

## A body whose statuses draw: alive, up, in sight and near the camera focus.
func _seen(e: Ent, viewer: Variant) -> bool:
	if e.dead or not e.visible:
		return false
	if e is Hunter and ((e as Hunter).out or (e as Hunter).downed or ((e as Hunter).unseen and e != viewer)):
		return false
	return Vector2(e.pos.x - Sfx.listener.x, e.pos.z - Sfx.listener.z).length() <= LOD_FAR

func _show(h: Ent, st: String, dt: float) -> void:
	var key := "%d/%s" % [h.get_instance_id(), st]
	var r: Dictionary = rigs.get(key, {})
	if r.is_empty():
		var d: Dictionary = rules()[st]
		r = {"n": _take(st, d), "h": h, "st": st, "look": String(d["look"]), "t": 0.0, "seen": -1,
			"pace": float(d.get("pace", 1.0))}
		rigs[key] = r
	elif int(r["seen"]) == _frame:
		return                 # (carried and told on the same frame)
	r["seen"] = _frame
	r["t"] = float(r["t"]) + dt * float(r["pace"])
	var n: Node3D = r["n"]
	n.visible = true
	n.global_position = h.pos
	n.scale = Vector3.ONE * (float((h as Hunter).cdat.get("scale", 1.0)) if h is Hunter else MOB_K)
	_pose(n, String(r["look"]), float(r["t"]))

# ------------------------------------------------------------------ rigs
func _take(st: String, d: Dictionary) -> Node3D:
	var spare: Array = pool.get(st, [])
	pool[st] = spare
	if not spare.is_empty():
		return spare.pop_back()
	var n := Node3D.new()
	n.name = "Status_" + st
	var body := Node3D.new()
	body.name = "Body"
	body.position.y = float(d.get("y", 0.0))
	body.scale = Vector3.ONE * float(d.get("size", 1.0))
	n.add_child(body)
	_build(body, String(d["look"]), _mat(String(d["col"])), _mat(String(d.get("dark", d["col"]))),
		_mat(String(d.get("hot", d["col"]))))
	add_child(n)
	made += 1
	return n

static func _mat(hex: String) -> StandardMaterial3D:
	if not _mats.has(hex):
		_mats[hex] = DJFx.solid(Color(hex))
	return _mats[hex]

static func _mesh(key: String) -> Mesh:
	if _meshes.has(key):
		return _meshes[key]
	var mesh: Mesh
	match key:
		"star":
			var b := BoxMesh.new()
			b.size = Vector3(0.26, 0.26, 0.08)
			mesh = b
		"disc":
			mesh = _tube(0.42, 0.0, 0.02)
		"crystal", "crystal_big":
			var p := PrismMesh.new()
			p.size = Vector3(0.12, 0.34, 0.12) if key == "crystal" else Vector3(0.16, 0.5, 0.16)
			mesh = p
		"thorn":
			mesh = _tube(0.0, 0.1, 0.95)
		"arrow_head":
			mesh = _tube(0.26, 0.0, 0.34)
		"arrow_shaft":
			mesh = _tube(0.08, 0.08, 0.32)
		"ring", "ring_wide", "ring_thin":
			var t := TorusMesh.new()
			var r := {"ring": [0.32, 0.4], "ring_wide": [0.5, 0.62], "ring_thin": [0.36, 0.41]}[key] as Array
			t.inner_radius = float(r[0])
			t.outer_radius = float(r[1])
			t.rings = 20
			t.ring_segments = 6
			mesh = t
		"tongue":
			mesh = _tube(0.0, 0.17, 0.9)
		"core":
			mesh = _tube(0.0, 0.1, 0.55)
		"shell":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 16
			s.rings = 8
			mesh = s
		"bolt":
			mesh = _zigzag(0.07)
		"bolt_core":
			mesh = _zigzag(0.03)
		"streak":
			var bx := BoxMesh.new()
			bx.size = Vector3(0.11, 0.75, 0.11)
			mesh = bx
		"wisp":
			var w := SphereMesh.new()
			w.radius = 0.15
			w.height = 0.3
			w.radial_segments = 8
			w.rings = 4
			mesh = w
	_meshes[key] = mesh
	return mesh

static func _tube(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 8
	c.rings = 1
	return c

## A jagged bolt 1.3 m tall as two crossed flat ribbons (it reads from any side).
static func _zigzag(w: float) -> ArrayMesh:
	var pts := [Vector2(0, 0), Vector2(0.14, 0.28), Vector2(-0.1, 0.55), Vector2(0.16, 0.82), Vector2(-0.06, 1.05),
		Vector2(0.08, 1.3)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in [Vector3.RIGHT, Vector3.BACK]:
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var a0: Vector3 = axis * a.x + Vector3.UP * a.y
			var b0: Vector3 = axis * b.x + Vector3.UP * b.y
			var off: Vector3 = axis * w
			for v in [a0 - off, b0 - off, b0 + off, a0 - off, b0 + off, a0 + off]:
				st.add_vertex(v)
	return st.commit()

## The look's parts under `b`, named so _pose finds them ("P0", "P1", ...).
func _build(b: Node3D, look: String, col: Material, dark: Material, hot: Material) -> void:
	match look:
		"stars":
			Models.part(b, _mesh("disc"), _mat_a(dark, 0.55), Vector3(0, -0.06, 0), Vector3.ONE, Vector3.ZERO, "Back")
			for i in 4:
				var a := TAU * i / 4.0
				Models.part(b, _mesh("star"), col, Vector3(cos(a) * 0.4, 0, sin(a) * 0.4), Vector3.ONE,
					Vector3(0, -a, PI * 0.25), "P%d" % i)
		"halo":
			Models.part(b, _mesh("ring_thin"), dark, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, "Ring")
			for i in 5:
				var a2 := TAU * i / 5.0
				Models.part(b.get_node("Ring"), _mesh("crystal"), col, Vector3(cos(a2) * 0.4, 0.05, sin(a2) * 0.4),
					Vector3.ONE * 1.5, Vector3(0, -a2, 0))
		"stakes":
			Models.part(b, _mesh("ring_wide"), col, Vector3(0, 0.03, 0), Vector3(1, 0.4, 1), Vector3.ZERO, "Ring")
			for i in 5:
				var a3 := TAU * i / 5.0
				var thorn := Models.part(b, _mesh("thorn"), col, Vector3(cos(a3) * 0.5, 0.3, sin(a3) * 0.5))
				thorn.basis = Basis(Vector3(-sin(a3), 0, cos(a3)), -0.45)       # leaning in over the feet
		"cords":
			for i in 3:
				Models.part(b, _mesh("ring"), col if i != 1 else dark, Vector3(0, 0.25 + 0.24 * i, 0),
					Vector3(1.0 - 0.06 * i, 0.6, 1.0 - 0.06 * i), Vector3(0.22 * (1 - i), 0, 0.25 * (i - 1)), "P%d" % i)
			var arrow := Models.part(b, _mesh("arrow_shaft"), col, Vector3(0, ARROW_Y + 0.33, 0), Vector3.ONE,
				Vector3.ZERO, "Arrow")        # a down arrow over the head: pinned to the ground
			Models.part(arrow, _mesh("arrow_head"), col, Vector3(0, -0.33, 0))
		"anklets":
			for i in 3:
				var mat := col if i != 2 else dark
				Models.part(b, _mesh("ring"), mat, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, "P%d" % i)
		"frost":
			Models.part(b, _mesh("shell"), _mat_a(col, 0.32), Vector3(0, 1.0, 0), Vector3(1.25, 2.1, 1.25))
			for i in 7:
				var a4 := TAU * i / 7.0
				var up := 0.15 if i % 2 == 0 else 1.45
				var spike := Models.part(b, _mesh("crystal_big"), hot if i % 3 != 0 else dark,
					Vector3(cos(a4) * 0.5, up, sin(a4) * 0.5))
				spike.basis = Basis(Vector3(-sin(a4), 0, cos(a4)), 0.7)        # jutting out of the shell
		"flames":
			for i in 6:
				var a5 := TAU * i / 6.0
				var at := Vector3(cos(a5) * 0.32, 0.45 + 0.4 * (i % 3), sin(a5) * 0.32)
				var t := Models.part(b, _mesh("tongue"), col, at, Vector3.ONE, Vector3.ZERO, "P%d" % i)
				Models.part(t, _mesh("core"), hot, Vector3(0, -0.08, 0))
		"arcs":
			for i in 4:
				var bolt := Models.part(b, _mesh("bolt"), col, Vector3(0, 0.3, 0), Vector3.ONE, Vector3.ZERO, "P%d" % i)
				Models.part(bolt, _mesh("bolt_core"), hot, Vector3.ZERO)
		"streaks":
			Models.part(b, _mesh("ring_wide"), dark, Vector3(0, 0.03, 0), Vector3(0.85, 0.3, 0.85))
			for i in 6:
				Models.part(b, _mesh("streak"), col, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, "P%d" % i)
		"wisps":
			Models.part(b, _mesh("ring_wide"), _mat_a(col, 0.5), Vector3(0, 0.03, 0), Vector3(0.8, 0.3, 0.8))
			for i in 4:
				Models.part(b, _mesh("wisp"), col, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, "P%d" % i)
	for c in b.find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _mat_a(base: StandardMaterial3D, a: float) -> StandardMaterial3D:
	var key := "%s|%.2f" % [base.albedo_color.to_html(), a]
	if not _mats.has(key):
		_mats[key] = DJFx.solid(Color(base.albedo_color, a))
	return _mats[key]

## A value 0..1 that jumps `rate` times a second, different per `i` (no rng: looks never touch it).
static func _jump(t: float, i: int, rate: float) -> float:
	return fposmod(sin(float(i) * 12.9898 + floor(t * rate) * 78.233) * 43758.5453, 1.0)

## The look's motion at `t` s since it came up.
func _pose(n: Node3D, look: String, t: float) -> void:
	var b: Node3D = n.get_child(0)
	match look:
		"stars":
			b.rotation.y = -t * 7.0
		"halo":
			b.rotation = Vector3(sin(t * 3.2) * 0.45, t * 1.5, cos(t * 3.2) * 0.45)
		"stakes":
			b.get_node("Ring").scale = Vector3.ONE * (1.0 + 0.06 * sin(t * 8.0)) * Vector3(1, 0.4, 1)
		"cords":
			for i in 3:
				(b.get_node("P%d" % i) as Node3D).rotation.y = t * (1.4 if i % 2 == 0 else -1.4)
			(b.get_node("Arrow") as Node3D).position.y = ARROW_Y + 0.33 - 0.12 * absf(sin(t * 4.0))   # a stamp down
		"anklets":
			for i in 3:
				var u := fposmod(t * 0.9 + i / 3.0, 1.0)      # top of the shin to the ground, again
				var p: Node3D = b.get_node("P%d" % i)
				p.position.y = 0.75 * (1.0 - u)
				p.scale = Vector3.ONE * (0.8 + 0.5 * u)
		"flames":
			for i in 6:
				var p2: Node3D = b.get_node("P%d" % i)
				p2.scale = Vector3(1.0, 0.55 + 0.65 * absf(sin(t * 9.0 + i * 1.7)), 1.0)
				p2.rotation.z = 0.25 * sin(t * 6.0 + i)
			b.rotation.y = t * 0.8
		"arcs":
			for i in 4:
				var p3: Node3D = b.get_node("P%d" % i)
				p3.visible = _jump(t, i, 14.0) < 0.7
				p3.rotation = Vector3(0.3 * (_jump(t, i + 7, 14.0) - 0.5), TAU * _jump(t, i + 3, 14.0), 0.0)
				p3.position = Vector3(0.0, 0.2 + 0.4 * _jump(t, i + 11, 14.0), 0.0)
		"streaks":
			for i in 6:
				var u2 := fposmod(t * 0.8 + i / 6.0, 1.0)
				var a := TAU * i / 6.0 + 0.4 * i
				var p4: Node3D = b.get_node("P%d" % i)
				p4.position = Vector3(cos(a) * 0.38, 0.4 + 2.0 * u2, sin(a) * 0.38)
				p4.scale = Vector3.ONE * (1.0 - u2 * 0.8)
		"wisps":
			for i in 4:
				var u3 := fposmod(t * 0.35 + i / 4.0, 1.0)
				var a2 := TAU * i / 4.0 + t * 0.8
				(b.get_node("P%d" % i) as Node3D).position = Vector3(cos(a2) * 0.45, 1.9 - 1.7 * u3, sin(a2) * 0.45)
