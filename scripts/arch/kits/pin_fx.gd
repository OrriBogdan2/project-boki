class_name PinFx
extends Node3D
## Pin's own effects, every one pooled (built once when the kit starts, then shown, moved and hidden):
## - stars: the stage-ready flash at the bow, the gold perfect-release star with its ring, the white
##   Supercharged star held at the bow, the teal X-star on a Supercharged hit
## - arrows: the look of each of her shots (Empowered green bolt, Supercharged white-teal beam, a dull
##   overdrawn shaft, the gold Impaling arrow with violet fins, the snare), each with its own trail, drawn
##   over the shot the match moves (the round's own sphere is shrunk away)
## - spent arrows: one that lands with no hit stays stuck in the ground glowing teal for 4 s
## - the Rain of Arrows: the curved panels with fletch posts, a ground glow, arrows streaking down, blue
##   burn flames on foes inside
## - the Spirit Walk screen tint while she is inside something (her own screen only)

const STARS := 8
const ARROWS := 10
const SPENT := 8
const STREAKS := 26
const FLAMES := 4
const SPENT_T := 4.0           # s a spent arrow stays in the ground
const GREEN := Color("8dffa8")
const TEAL := Color("5ff2d8")
const GOLD := Color("ffd25a")
const VIOLET := Color("b884ff")

var h: Hunter
var stars: Array = []          # {node, t, dur, size, follow}
var arrows: Array = []         # pooled arrow nodes
var live := {}                 # shot sid -> {node, kind, pos, life}
var spent: Array = []          # {node, t}
var hits: Array = []           # [pos, time] of shot hits (a shot that hit someone isn't planted)
var bow_star: MeshInstance3D   # held at the bow while Supercharged
var rain := {}                 # the live wall: {center, dir, radius, deg, t, every}
var panels: Array = []
var posts: Array = []
var glow: MeshInstance3D
var streaks: Array = []        # {node, t, from, to}
var flames: Array = []         # {node, foe}
var tint: ColorRect = null
var tint_k := 0.0
var tint_want := 0.0
var planted := 0               # spent arrows planted (checks)

func _init(hunter: Hunter) -> void:
	h = hunter
	top_level = true
	name = "PinFx"

func _ready() -> void:
	for i in STARS:
		stars.append({"node": KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("star")), "t": 0.0, "dur": 0.0})
	bow_star = KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("star", Color.WHITE))
	for i in ARROWS:
		arrows.append(_arrow_node())
	for i in SPENT:
		var n := _arrow_node()
		spent.append({"node": n, "t": 0.0})
	for i in 8:
		panels.append(KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("panel", GREEN)))
	for i in 9:
		var p := KitMeshes.inst(self, Models.box(0.06, 1.0, 0.06), Models.glow_mat(Color(GREEN.lightened(0.4), 0.95)))
		var fl := MeshInstance3D.new()
		fl.mesh = Models.prism_tip(); fl.material_override = Models.glow_mat(Color(GREEN, 0.9))
		fl.scale = Vector3(0.22, 0.24, 0.05); fl.position = Vector3(0, 0.62, 0); fl.rotation = Vector3(PI, 0, 0)
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.add_child(fl)
		posts.append(p)
	glow = KitMeshes.inst(self, KitMeshes.band(1.0, 1.0, -1.0, 1.0), KitShaders.mat("swirl", GREEN))
	for i in STREAKS:
		streaks.append({"node": KitMeshes.inst(self, KitMeshes.quad(0.09, 1.3), KitShaders.mat("streak", GREEN)), "t": 0.0})
	for i in FLAMES:
		var fm := KitShaders.mat("flame", Color("5aa8ff"))
		fm.set_shader_parameter("seed", float(i) * 1.7)
		flames.append({"node": KitMeshes.inst(self, KitMeshes.quad(0.9, 1.3), fm), "foe": null})

func _arrow_node() -> Node3D:
	var n := Node3D.new()
	n.top_level = true
	n.visible = false
	add_child(n)
	var trail := MeshInstance3D.new()
	trail.name = "Trail"
	trail.mesh = KitMeshes.quad(1.0, 1.0)
	trail.material_override = KitShaders.mat("streak", GREEN)
	trail.rotation = Vector3(-PI * 0.5, PI * 0.5, 0)     # lies flat, runs back along +Z
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(trail)
	var shaft := Models.part(n, Models.box(0.035, 0.035, 0.75), Models.glow_mat(GREEN), Vector3(0, 0, 0.3), Vector3.ONE, Vector3.ZERO, "Shaft")
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var head := Models.part(n, Models.prism_tip(), Models.glow_mat(TEAL), Vector3(0, 0, -0.1), Vector3(0.12, 0.2, 0.05), Vector3(-PI * 0.5, 0, 0), "Head")
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for sx in [-1.0, 1.0]:
		var f := Models.part(n, Models.box(0.16, 0.012, 0.2), Models.glow_mat(Color(GREEN, 0.8)), Vector3(sx * 0.07, 0, 0.62), Vector3.ONE, Vector3(0, sx * 0.35, 0), "Fin%d" % int(sx + 1.0))
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

## Each kind's look: [shaft colour, head colour, fin colour, trail colour, trail length m, trail width m, body scale]
const LOOK := {
	"tap": [Color("cfe8b0"), Color("e8ffd0"), Color("9fe0a8"), Color(0.6, 1.0, 0.65, 0.5), 1.2, 0.07, 0.8],
	"arrow": [GREEN, TEAL, GREEN, Color(0.45, 1.0, 0.6, 0.85), 2.4, 0.12, 1.0],
	"super": [Color("e8fffa"), Color.WHITE, TEAL, Color(0.75, 1.0, 0.95, 1.0), 4.2, 0.36, 1.35],
	"over": [Color("9fb8a0"), Color("c8d8c0"), Color("7a9a80"), Color(0.6, 0.75, 0.62, 0.35), 1.0, 0.06, 0.9],
	"heavy": [GOLD, Color("fff0b0"), VIOLET, Color(1.0, 0.78, 0.3, 0.9), 2.6, 0.3, 1.5],
	"snare": [Color("b8f06a"), Color("e8ffb0"), Color("d8ff8a"), Color(0.75, 1.0, 0.4, 0.6), 1.4, 0.08, 0.9],
}

func _dress(n: Node3D, kind: String) -> void:
	var lk: Array = LOOK.get(kind, LOOK["arrow"])
	(n.get_node("Shaft") as MeshInstance3D).material_override.set_shader_parameter("color", lk[0])
	(n.get_node("Head") as MeshInstance3D).material_override.set_shader_parameter("color", lk[1])
	for f in ["Fin0", "Fin2"]:
		(n.get_node(f) as MeshInstance3D).material_override.set_shader_parameter("color", lk[2])
	var tr := n.get_node("Trail") as MeshInstance3D
	tr.material_override.set_shader_parameter("color", lk[3])
	tr.scale = Vector3(float(lk[4]), float(lk[5]), 1.0)
	tr.position = Vector3(0, 0, float(lk[4]) * 0.5 + 0.2)
	tr.visible = true
	var s := float(lk[6])
	(n.get_node("Shaft") as Node3D).scale = Vector3(s * (2.2 if kind == "super" else 1.0), s * (2.2 if kind == "super" else 1.0), s)
	(n.get_node("Head") as Node3D).scale = Vector3(0.12, 0.2, 0.05) * s * (1.6 if kind == "heavy" else 1.0)
	for f in ["Fin0", "Fin2"]:
		(n.get_node(f) as Node3D).scale = Vector3.ONE * s * (1.7 if kind == "heavy" else 1.0)

# ------------------------------------------------------------------ stars
## A star flash at `at`: size m across, held `dur` s (it pops in and fades), with an optional ring.
func star(at: Vector3, size: float, col: Color, dur := 0.12, ring := 0.0, rot := 0.0) -> void:
	var s: Dictionary = stars[0]
	for c in stars:
		if float(c["t"]) >= float(c["dur"]):
			s = c; break
	var n: MeshInstance3D = s["node"]
	n.visible = true
	n.global_position = at
	n.material_override.set_shader_parameter("color", col)
	n.material_override.set_shader_parameter("ring", ring)
	n.material_override.set_shader_parameter("rot", rot)
	s["t"] = 0.0; s["dur"] = dur; s["size"] = size

## The white star held at the bow while Supercharged (k 0 = off); dim when overdrawn.
func hold_bow_star(at: Vector3, k: float) -> void:
	bow_star.visible = k > 0.01
	if bow_star.visible:
		bow_star.global_position = at
		var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.02)
		bow_star.scale = Vector3.ONE * lerpf(0.5, 1.0, k) * pulse
		bow_star.material_override.set_shader_parameter("power", k)

# ------------------------------------------------------------------ shots and spent arrows
## Skins a shot of ours as `kind` (the match keeps moving it; we draw over it).
func skin(s: Dictionary, kind: String) -> void:
	var x: Dictionary = s["x"]
	x["pin"] = kind
	x["tracer"] = 0.0
	s["vr"] = 0.001
	for n in arrows:
		if not (n as Node3D).visible:
			_dress(n, kind)
			n.visible = true
			live[int(s["sid"])] = {"node": n, "kind": kind, "pos": s["pos"], "life": float(s["life"]), "s": s}
			return

func note_hit(at: Vector3) -> void:
	hits.append([at, Time.get_ticks_msec()])

func _tick_shots() -> void:
	var a := Engine.get_physics_interpolation_fraction()
	var seen := {}
	for s in h.m.shots:
		var sid := int(s["sid"])
		if not live.has(sid):
			continue
		seen[sid] = true
		var e: Dictionary = live[sid]
		var n: Node3D = e["node"]
		var p := (s["prev"] as Vector3).lerp(s["pos"], a)
		var v: Vector2 = s["vel"]
		n.global_position = p
		if v.length() > 0.5:
			n.rotation = Vector3(0, atan2(-v.x, -v.y), 0)
		e["pos"] = s["pos"]; e["life"] = float(s["life"])
	var now := Time.get_ticks_msec()
	hits = hits.filter(func(hh): return now - int(hh[1]) < 200)
	for sid in live.keys():
		if seen.has(sid):
			continue
		var e: Dictionary = live[sid]
		(e["node"] as Node3D).visible = false
		live.erase(sid)
		var kind := String(e["kind"])
		var at: Vector3 = e["pos"]
		var hit := hits.any(func(hh): return (hh[0] as Vector3).distance_to(at) < 1.6)
		if not hit and kind in ["tap", "arrow", "over", "heavy"]:
			_plant(at, (e["s"]["vel"] as Vector2), kind)

## A spent arrow stuck in the ground where the shot ended, glowing teal, fading over SPENT_T.
func _plant(at: Vector3, v: Vector2, kind: String) -> void:
	var best: Dictionary = spent[0]
	for c in spent:
		if float(c["t"]) <= 0.0:
			best = c; break
		if float(c["t"]) < float(best["t"]): best = c
	var n: Node3D = best["node"]
	_dress(n, kind)
	(n.get_node("Trail") as Node3D).visible = false
	(n.get_node("Head") as MeshInstance3D).material_override.set_shader_parameter("color", TEAL)
	var g: Vector3 = AimMode.ground(h.m, at)
	if g.y < at.y - 1.6: g = at
	n.global_position = g + Vector3(0, 0.22, 0)
	n.rotation = Vector3(-0.75, atan2(-v.x, -v.y), 0)
	n.visible = true
	best["t"] = SPENT_T
	planted += 1
	star(g + Vector3(0, 0.15, 0), 0.5, TEAL, 0.1)

# ------------------------------------------------------------------ Rain of Arrows
## Shows the wall for `t` s: an arc of `deg` round `center` at `radius`, facing `dir`.
func rain_on(center: Vector3, dir: Vector2, radius: float, deg: float, t: float) -> void:
	rain = {"center": center, "dir": dir, "radius": radius, "deg": deg, "t": t, "t0": t, "every": 0.0}
	var yaw := atan2(-dir.x, -dir.y)
	var half := deg_to_rad(deg) * 0.5
	var n := panels.size()
	for i in n + 1:
		var u := lerpf(-half, half, float(i) / n)
		var q := _arc_pt(center, yaw, radius, u)
		(posts[i] as Node3D).global_position = q + Vector3(0, 0.5, 0)
		(posts[i] as Node3D).visible = true
	for i in n:
		var u0 := lerpf(-half, half, float(i) / n); var u1 := lerpf(-half, half, float(i + 1) / n)
		var q0 := _arc_pt(center, yaw, radius, u0); var q1 := _arc_pt(center, yaw, radius, u1)
		var pn: MeshInstance3D = panels[i]
		var mid := (q0 + q1) * 0.5
		pn.global_position = mid + Vector3(0, 1.0, 0)
		pn.scale = Vector3(q0.distance_to(q1), 2.0, 1.0)
		pn.rotation = Vector3(0, -atan2(q1.z - q0.z, q1.x - q0.x), 0)
		pn.visible = true
	glow.mesh = KitMeshes.band(radius - 0.5, radius + 0.5, -half, half, 28)
	glow.global_position = AimMode.ground(h.m, center) + Vector3(0, 0.05, 0)
	glow.rotation = Vector3(0, yaw, 0)
	glow.visible = true

func _arc_pt(center: Vector3, yaw: float, radius: float, u: float) -> Vector3:
	var a := yaw + u
	var q := center + Vector3(-sin(a), 0, -cos(a)) * radius
	return AimMode.ground(h.m, q)

func rain_off() -> void:
	rain = {}
	for p in panels + posts: (p as Node3D).visible = false
	glow.visible = false
	for f in flames:
		(f["node"] as Node3D).visible = false; f["foe"] = null

## Blue burn flames on the foes inside (the anti-heal burn); `foes` is this step's list.
func burn(foes: Array) -> void:
	for i in flames.size():
		var f: Dictionary = flames[i]
		var foe: Ent = foes[i] if i < foes.size() else null
		f["foe"] = foe
		(f["node"] as Node3D).visible = foe != null and is_instance_valid(foe)

func _tick_rain(dt: float) -> void:
	if rain.is_empty():
		return
	rain["t"] = float(rain["t"]) - dt
	var k := clampf(float(rain["t"]) / 0.4, 0.0, 1.0) * clampf((float(rain["t0"]) - float(rain["t"])) / 0.25, 0.0, 1.0)
	for p in panels:
		(p as MeshInstance3D).material_override.set_shader_parameter("power", k)
	glow.material_override.set_shader_parameter("life", k * 0.8)
	if float(rain["t"]) <= 0.0:
		rain_off()
		return
	# arrows streaking down all along the arc
	rain["every"] = float(rain["every"]) - dt
	if float(rain["every"]) <= 0.0:
		rain["every"] = 0.035
		var yaw := atan2(-(rain["dir"] as Vector2).x, -(rain["dir"] as Vector2).y)
		var half := deg_to_rad(float(rain["deg"])) * 0.5
		var q := _arc_pt(rain["center"], yaw, float(rain["radius"]) + randf_range(-0.45, 0.45), randf_range(-half, half))
		for c in streaks:
			if float(c["t"]) <= 0.0:
				c["t"] = 0.32; c["to"] = q; c["from"] = q + Vector3(randf_range(-0.8, 0.8), 6.5, randf_range(-0.8, 0.8))
				break
	for f in flames:
		var foe: Ent = f["foe"]
		if foe != null and is_instance_valid(foe) and not foe.dead:
			(f["node"] as Node3D).global_position = foe.position + Vector3(0, 0.75, 0)
		else:
			(f["node"] as Node3D).visible = false

func _tick_streaks(dt: float) -> void:
	for c in streaks:
		var n: MeshInstance3D = c["node"]
		if float(c["t"]) <= 0.0:
			n.visible = false
			continue
		c["t"] = float(c["t"]) - dt
		var u := 1.0 - clampf(float(c["t"]) / 0.32, 0.0, 1.0)
		var from: Vector3 = c["from"]; var to: Vector3 = c["to"]
		var p := from.lerp(to, u * u)
		n.visible = true
		n.global_position = p + (from - to).normalized() * 0.6
		var cam := get_viewport().get_camera_3d() if get_viewport() else null
		n.rotation = Vector3(0, cam.global_rotation.y if cam else 0.0, 0)
		if u >= 0.98:
			n.visible = false
			c["t"] = 0.0
			h.m.fx.spark(to + Vector3(0, 0.05, 0), Vector3.UP, GREEN, 3, 3.0, 70.0, 0.18, 8.0, 0.7)

# ------------------------------------------------------------------ Spirit Walk tint
func tint_to(k: float) -> void:
	tint_want = k
	if tint == null and k > 0.0 and h.is_local():
		var cl := CanvasLayer.new()
		cl.layer = 5
		add_child(cl)
		tint = ColorRect.new()
		tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tint.material = KitShaders.mat("tint", Color(0.04, 0.08, 0.3))
		cl.add_child(tint)

func _process(delta: float) -> void:
	if not is_instance_valid(h) or h.m == null:
		return
	for s in stars:
		var n: MeshInstance3D = s["node"]
		if float(s["t"]) >= float(s["dur"]):
			n.visible = false
			continue
		s["t"] = float(s["t"]) + delta
		var u := clampf(float(s["t"]) / maxf(0.01, float(s["dur"])), 0.0, 1.0)
		n.scale = Vector3.ONE * float(s["size"]) * (0.6 + 0.6 * sin(minf(u * 2.2, 1.0) * PI * 0.5))
		n.material_override.set_shader_parameter("power", 1.6 * (1.0 - u * u))
	for c in spent:
		if float(c["t"]) > 0.0:
			c["t"] = float(c["t"]) - delta
			var n2: Node3D = c["node"]
			var f := clampf(float(c["t"]) / 1.0, 0.0, 1.0)
			n2.scale = Vector3.ONE * f
			if float(c["t"]) <= 0.0: n2.visible = false
	_tick_shots()
	_tick_rain(delta)
	_tick_streaks(delta)
	if tint:
		tint_k = move_toward(tint_k, tint_want, delta * 5.0)
		tint.material.set_shader_parameter("power", tint_k)
		tint.visible = tint_k > 0.01

# ------------------------------------------------------------------ Spirit Walk aura
var aura: MeshInstance3D = null

## A soft green shell over her while she walks as a spirit (k 0 = off).
func aura_on(k: float) -> void:
	if aura == null:
		aura = KitMeshes.inst(self, Models.capsule(0.42, 1.7), KitShaders.mat("beam", Color(GREEN, 0.9)))
		aura.material_override.set_shader_parameter("bands", 3.0)
	aura.visible = k > 0.01
	if aura.visible:
		aura.global_position = h.position + Vector3(0, 0.9 * float(h.cdat.get("scale", 1.0)), 0)
		aura.material_override.set_shader_parameter("power", k * 0.8)
