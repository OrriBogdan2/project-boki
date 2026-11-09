class_name PinFx
extends Node3D
## Hem's own effects, every one pooled (built once when the kit starts, then shown, moved and hidden). The
## coloured ones are layered (KitShaders): an alpha-blended body in her orchid, its pale half and gold with the glow
## on top, so they keep their colour on bright grass.
## - fletch bursts (her own motif: feathers radiating from a core): the orchid stage-ready flash at the bow,
##   the gold perfect-release burst with its ring, the glint at the bow hand (only while a stage is ready:
##   orchid Empowered, pale orchid Supercharged and a full Heavy Shot)
## - stars: the orchid X-star on a Supercharged hit, the orchid-white Heavy Shot impact
## - arrows: the look of each of her shots (Empowered orchid bolt, Supercharged white-orchid beam, a dull
##   overdrawn shaft, the big orchid Heavy Shot with a hot core), each with its own trail, drawn
##   over the shot the match moves (the round's own sphere is shrunk away)
## - spent arrows: one that lands with no hit stays stuck in the ground, thread attached, for 4 s
## - the Rain of Arrows: the curved panels with fletch posts, a ground glow, arrows streaking down, blue
##   burn flames on foes inside
## - the Spirit Walk screen tint while she is inside something (her own screen only)

const STARS := 8
const BURSTS := 3
const ARROWS := 10
const SPENT := 8
const STREAKS := 26
const FLAMES := 4
## her dash after-image: orchid fletch streaks left at hip, chest and shoulder height, how long each lasts
## (s), how many are pooled and how often a set is left (s)
const WISP_T := 0.26
const WISPS := 12
const WISP_EVERY := 0.05
const SPENT_T := 4.0           # s a spent arrow stays in the ground
const STAKE_T := 7.0           # s the stake a wall pin leaves in the wall stays
## the Heavy Shot's arrow is this many times a normal arrow (the Empowered bolt is 1.0): unmistakable
const HEAVY_SCALE := 6.0
const ULT_WIDTH := 0.6          # m: Starpiercer's arrow head and trail, its hit width (2 x the 0.3 shot radius)
const THREAD := Color("e04aff")     # her signature orchid (archetypes/archer.json "color"): thread, trails, glows
const PALE := Color("f4c8ff")       # the pale half of her orchid: heads and hot cores
const DEEP := Color("8a1aa8")       # the deep shade of her orchid: the overdrawn trail
const GOLD := Color("ffc02a")       # the perfect-release cue only (a timing signal, not her body colour)
const SILVER := Color("dfe6f0")     # her needles
const FLETCH := Color("c8b48c")     # the feathers

var h: Hunter
var stars: Array = []          # {node, t, dur, size, follow}
var arrows: Array = []         # pooled arrow nodes
var live := {}                 # shot sid -> {node, kind, pos, life}
var spent: Array = []          # {node, t}
var hits: Array = []           # [pos, time] of shot hits (a shot that hit someone isn't planted)
var bursts: Array = []         # fletch bursts {node, t, dur, size, pow}
var bow_glint: MeshInstance3D  # the fletch glint at the bow hand while a stage is ready
var rain := {}                 # the live wall: {center, dir, radius, deg, t, every}
var panels: Array = []
var posts: Array = []
var glow: MeshInstance3D
var streaks: Array = []        # {node, t, from, to}
var flames: Array = []         # {node, foe}
var wisps: Array = []          # {node, t}
var wisp_next := 0
var wisp_at := -1.0
var tint: ColorRect = null
var tint_k := 0.0
var tint_want := 0.0
var planted := 0               # spent arrows planted (checks)
var staked := 0                # Heavy Shot stakes left in walls (checks)
var fx_clock := 0.0            # the match time effects last advanced to

func _init(hunter: Hunter) -> void:
	h = hunter
	top_level = true
	name = "PinFx"

func _ready() -> void:
	for i in STARS:
		var star_node := KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("star", THREAD, true))
		KitShaders.param(star_node, "white", 0.3)
		stars.append({"node": star_node, "t": 0.0, "dur": 0.0})
	for i in BURSTS:
		var burst_node := KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("rosette", GOLD, true))
		burst_node.sorting_offset = 2.0         # drawn over the bow hand and the body
		bursts.append({"node": burst_node, "t": 0.0, "dur": 0.0})
	bow_glint = KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("rosette", THREAD, true))
	KitShaders.param(bow_glint, "leaves", 4.0)
	for i in ARROWS:
		arrows.append(_arrow_node())
	for i in SPENT:
		var n := _arrow_node()
		spent.append({"node": n, "t": 0.0})
	for i in 8:
		panels.append(KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("panel", THREAD)))
	for i in 9:
		var p := KitMeshes.inst(self, Models.box(0.05, 1.0, 0.05), Models.glow_mat(Color(SILVER, 0.95)))
		var fl := MeshInstance3D.new()
		fl.mesh = Models.prism_tip()
		fl.material_override = Models.glow_mat(Color(THREAD, 0.9))
		fl.scale = Vector3(0.22, 0.24, 0.05)
		fl.position = Vector3(0, 0.62, 0)
		fl.rotation = Vector3(PI, 0, 0)
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.add_child(fl)
		posts.append(p)
	glow = KitMeshes.inst(self, KitMeshes.band(1.0, 1.0, -1.0, 1.0), KitShaders.mat("swirl", THREAD))
	for i in STREAKS:
		var streak_node := KitMeshes.inst(self, KitMeshes.quad(0.07, 1.3), KitShaders.mat("streak", SILVER))
		streaks.append({"node": streak_node, "t": 0.0})
	for i in WISPS:
		var wisp := KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("streak", THREAD, true))
		wisps.append({"node": wisp, "t": 0.0})
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
	trail.material_override = KitShaders.mat("streak", THREAD, true)
	trail.rotation = Vector3(-PI * 0.5, PI * 0.5, 0)     # lies flat, runs back along +Z
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(trail)
	# solid toon parts with a soft glow: they keep their colour on bright grass (no additive wash)
	var shaft := Models.part(n, Models.box(0.03, 0.03, 0.75), Models.toon(THREAD, true, 0.6), Vector3(0, 0, 0.3),
		Vector3.ONE, Vector3.ZERO, "Shaft")
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var head := Models.part(n, Models.prism_tip(), Models.toon(PALE, true, 0.8), Vector3(0, 0, -0.1),
		Vector3(0.12, 0.2, 0.05), Vector3(-PI * 0.5, 0, 0), "Head")
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the red thread binding the shaft behind the head and before the feathers
	for at_z in [0.08, 0.5]:
		var bind := Models.part(n, Models.box(0.06, 0.06, 0.09), Models.toon(THREAD, true, 0.8), Vector3(0, 0, at_z),
			Vector3.ONE, Vector3.ZERO, "Bind%d" % int(at_z * 10.0))
		bind.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a bright core riding the head (the Heavy Shot's alone)
	var core := KitMeshes.inst(n, KitMeshes.quad(1.0, 1.0), KitShaders.mat("star", GOLD, true))
	core.name = "Core"
	core.visible = false
	core.position = Vector3(0, 0, 0.1)
	for sx in [-1.0, 1.0]:
		var f := Models.part(n, Models.box(0.16, 0.012, 0.2), Models.toon(THREAD, false, 0.6),
			Vector3(sx * 0.07, 0, 0.62), Vector3.ONE, Vector3(0, sx * 0.35, 0), "Fin%d" % int(sx + 1.0))
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

## Each kind's look: [shaft colour, head colour, fin colour, trail colour, trail length m, trail width m, body scale].
## Trails are streaks (a white-hot centre line in an orchid body): the widths hold at the match camera.
const LOOK := {
	"tap": [SILVER, Color.WHITE, FLETCH, Color(THREAD, 0.7), 1.6, 0.16, 0.8],
	"arrow": [SILVER, Color.WHITE, FLETCH, Color(THREAD, 0.85), 2.6, 0.22, 1.0],
	"super": [Color.WHITE, Color.WHITE, THREAD, Color(THREAD, 0.95), 5.0, 0.4, 1.35],
	"over": [Color("8fa0b4"), Color("c0c8d4"), Color("7a6a58"), Color(DEEP, 0.4), 1.0, 0.1, 0.9],
	"ult": [Color.WHITE, Color.WHITE, THREAD, Color(THREAD, 0.95), 5.0, ULT_WIDTH, 5.0],
	"heavy": [THREAD, PALE, THREAD, Color(THREAD, 1.0), 7.0, 0.9, HEAVY_SCALE],
}

func _dress(n: Node3D, kind: String) -> void:
	var lk: Array = LOOK.get(kind, LOOK["arrow"])
	(n.get_node("Shaft") as MeshInstance3D).material_override.set_shader_parameter("albedo", lk[0])
	(n.get_node("Head") as MeshInstance3D).material_override.set_shader_parameter("albedo", lk[1])
	for f in ["Fin0", "Fin2"]:
		(n.get_node(f) as MeshInstance3D).material_override.set_shader_parameter("albedo", lk[2])
	var tr := n.get_node("Trail") as MeshInstance3D
	KitShaders.param(tr, "color", lk[3])
	tr.scale = Vector3(float(lk[4]), float(lk[5]), 1.0)
	tr.position = Vector3(0, 0, float(lk[4]) * 0.5 + 0.2)
	KitShaders.param(tr, "power", 2.2 if kind in ["super", "heavy"] else 1.4)
	tr.visible = true
	var s := float(lk[6])
	var core := n.get_node("Core") as MeshInstance3D
	core.visible = false      # (the Heavy Shot is the bow's arrow, just bigger: owner Nov 4)
	core.scale = Vector3.ONE * s * 0.5
	KitShaders.param(core, "color", Color("fff0b0"))
	KitShaders.param(core, "power", 2.4)
	var thick := s * (2.2 if kind == "super" else 1.0)
	(n.get_node("Shaft") as Node3D).scale = Vector3(thick, thick, s)
	(n.get_node("Head") as Node3D).scale = Vector3(0.12, 0.2, 0.05) * s * (1.6 if kind == "heavy" else 1.0)
	for b in ["Bind0", "Bind5"]:
		(n.get_node(b) as Node3D).scale = Vector3(s, s, s)
	for f in ["Fin0", "Fin2"]:
		(n.get_node(f) as Node3D).scale = Vector3.ONE * s * (1.7 if kind == "heavy" else 1.0)

# ------------------------------------------------------------------ stars
## A star flash at `at`: size m across, held `dur` s (it pops in and fades), with an optional ring.
func star(at: Vector3, across: float, col: Color, dur := 0.12, ring := 0.0, rot := 0.0, power := 1.6) -> void:
	var s: Dictionary = stars[0]
	for c in stars:
		if float(c["t"]) >= float(c["dur"]):
			s = c
			break
	var n: MeshInstance3D = s["node"]
	n.visible = true
	n.global_position = at
	KitShaders.param(n, "color", col)
	KitShaders.param(n, "ring", ring)
	KitShaders.param(n, "rot", rot)
	s["t"] = 0.0
	s["dur"] = dur
	s["size"] = across
	s["pow"] = power

## A fletch burst at `at`: `across` m wide, `leaves` feathers, at full strength for `hold` s then gone over
## `fade` s, with an optional ring (the perfect release, a stage coming up).
func fletch_burst(at: Vector3, across: float, col: Color, hold: float, fade: float, ring := 0.0, leaves := 6.0) -> void:
	var b: Dictionary = bursts[0]
	for c in bursts:
		if float(c["t"]) >= float(c["dur"]):
			b = c
			break
	var n: MeshInstance3D = b["node"]
	n.visible = true
	n.global_position = at
	n.scale = Vector3.ONE * across
	KitShaders.param(n, "color", col)
	KitShaders.param(n, "ring", ring)
	KitShaders.param(n, "leaves", leaves)
	KitShaders.param(n, "rot", randf() * TAU)
	KitShaders.param(n, "power", 1.6)
	b["t"] = 0.0
	b["dur"] = hold + fade
	b["hold"] = hold

## The fletch glint at the bow hand while a stage is ready (k 0 = off; it swells as k rises), in `col`.
func bow_glint_at(at: Vector3, k: float, col: Color) -> void:
	bow_glint.visible = k > 0.01
	if bow_glint.visible:
		bow_glint.global_position = at
		var pulse := 1.0 + 0.1 * sin(Time.get_ticks_msec() * 0.02)
		bow_glint.scale = Vector3.ONE * lerpf(0.35, 0.75, k) * pulse
		KitShaders.param(bow_glint, "color", col)
		KitShaders.param(bow_glint, "power", lerpf(0.6, 1.4, k))
		KitShaders.param(bow_glint, "rot", Time.get_ticks_msec() * 0.002)

# ------------------------------------------------------------------ shots and spent arrows
## Skins a shot of ours as `kind` (the match keeps moving it; we draw over it).
func skin(s: Dictionary, kind: String) -> Node3D:
	var x: Dictionary = s["x"]
	x["pin"] = kind
	x["tracer"] = 0.0
	s["vr"] = 0.001
	for n in arrows:
		if not (n as Node3D).visible:
			_dress(n, kind)
			n.visible = true
			live[int(s["sid"])] = {"node": n, "kind": kind, "pos": s["pos"], "life": float(s["life"]), "s": s}
			return n
	return null

func note_hit(at: Vector3) -> void:
	hits.append([at, h.m.time])

## Moves the skinned arrows and plants the spent ones (the kit calls it every step; _process too, for smooth frames).
func tick_shots() -> void:
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
		e["pos"] = s["pos"]
		e["life"] = float(s["life"])
	var now: float = h.m.time
	hits = hits.filter(func(hh): return now - float(hh[1]) < 0.2)
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

## A spent needle stuck in the ground where the shot ended, its thread lying behind it, gone after SPENT_T.
func _plant(at: Vector3, v: Vector2, kind: String) -> void:
	var best: Dictionary = spent[0]
	for c in spent:
		if float(c["t"]) <= 0.0:
			best = c
			break
		if float(c["t"]) < float(best["t"]): best = c
	var n: Node3D = best["node"]
	_dress(n, kind)
	(n.get_node("Trail") as Node3D).visible = false
	var g: Vector3 = AimMode.ground(h.m, at)
	if g.y < at.y - 1.6: g = at
	n.global_position = g + Vector3(0, 0.22, 0)
	n.rotation = Vector3(-0.75, atan2(-v.x, -v.y), 0)
	n.visible = true
	best["t"] = SPENT_T
	planted += 1
	HeroVfx.of(h.m).play(h, "needle_stuck", g, -v.normalized(), {"t": SPENT_T})

## The Heavy Shot's stake: a wall pin leaves its big arrow standing in the wall at `at`, pointing along `dir`
## (into the wall), for STAKE_T s.
func stake(at: Vector3, dir: Vector2) -> void:
	var best: Dictionary = spent[0]
	for c in spent:
		if float(c["t"]) <= 0.0:
			best = c
			break
		if float(c["t"]) < float(best["t"]): best = c
	var n: Node3D = best["node"]
	_dress(n, "heavy")
	(n.get_node("Trail") as Node3D).visible = false
	n.global_position = at
	n.rotation = Vector3(0, atan2(-dir.x, -dir.y), 0)
	n.visible = true
	best["t"] = STAKE_T
	staked += 1
	star(at, 1.6, GOLD, 0.2, 0.0, PI * 0.25, 2.2)

## Her dash after-image: three orchid fletch streaks at hip, chest and shoulder height, lying along the way
## she faces and fading behind her (pooled, a set every WISP_EVERY s).
func afterimage(at: Vector3, yaw: float, body_scale: float) -> void:
	var now := float(h.m.time)
	if now - wisp_at < WISP_EVERY and now >= wisp_at:
		return
	wisp_at = now
	for lift in [0.55, 1.0, 1.4]:
		var w: Dictionary = wisps[wisp_next]
		wisp_next = (wisp_next + 1) % WISPS
		var n: MeshInstance3D = w["node"]
		n.visible = true
		n.global_position = at + Vector3(0, lift * body_scale, 0)
		n.rotation = Vector3(-PI * 0.5, yaw + PI * 0.5, 0)
		n.scale = Vector3(1.3, 0.16, 1.0) * body_scale
		w["t"] = WISP_T

## Hail Wall's cast: orchid arrows streaking up out of the bow, lobbed toward `dir`.
func lob(at: Vector3, dir: Vector2) -> void:
	var launched := 0
	for c in streaks:
		if float(c["t"]) > 0.0:
			continue
		var spread := Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
		c["t"] = 0.32
		c["from"] = at
		c["to"] = at + Vector3(dir.x * 2.0, 5.5, dir.y * 2.0) + spread
		c["up"] = true
		launched += 1
		if launched >= 5:
			return

func _tick_wisps(delta: float) -> void:
	for w in wisps:
		if float(w["t"]) <= 0.0:
			continue
		w["t"] = float(w["t"]) - delta
		var n: MeshInstance3D = w["node"]
		KitShaders.param(n, "power", 1.6 * clampf(float(w["t"]) / WISP_T, 0.0, 1.0))
		n.visible = float(w["t"]) > 0.0

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
		if i > 0:
			_stitch(_arc_pt(center, yaw, radius, lerpf(-half, half, float(i - 1) / n)), q, t)
	for i in n:
		var u0 := lerpf(-half, half, float(i) / n)
		var u1 := lerpf(-half, half, float(i + 1) / n)
		var q0 := _arc_pt(center, yaw, radius, u0)
		var q1 := _arc_pt(center, yaw, radius, u1)
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

## The thread running from one needle post to the next, stitching the wall to the ground.
func _stitch(a: Vector3, b: Vector3, t: float) -> void:
	var to := Vector2(b.x - a.x, b.z - a.z)
	HeroVfx.of(h.m).play(h, "rain_thread", a, to.normalized(), {"len": to.length(), "t": t})

func _arc_pt(center: Vector3, yaw: float, radius: float, u: float) -> Vector3:
	var a := yaw + u
	var q := center + Vector3(-sin(a), 0, -cos(a)) * radius
	return AimMode.ground(h.m, q)

func rain_off() -> void:
	rain = {}
	for p in panels + posts: (p as Node3D).visible = false
	glow.visible = false
	for f in flames:
		(f["node"] as Node3D).visible = false
		f["foe"] = null

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
		var depth := float(rain["radius"]) + randf_range(-0.45, 0.45)
		var q := _arc_pt(rain["center"], yaw, depth, randf_range(-half, half))
		for c in streaks:
			if float(c["t"]) <= 0.0:
				c["t"] = 0.32
				c["to"] = q
				c["from"] = q + Vector3(randf_range(-0.8, 0.8), 6.5, randf_range(-0.8, 0.8))
				c["up"] = false
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
		var from: Vector3 = c["from"]
		var to: Vector3 = c["to"]
		var p := from.lerp(to, u * u)
		n.visible = true
		n.global_position = p + (from - to).normalized() * 0.6
		var cam := get_viewport().get_camera_3d() if get_viewport() else null
		n.rotation = Vector3(0, cam.global_rotation.y if cam else 0.0, 0)
		if u >= 0.98:
			n.visible = false
			c["t"] = 0.0
			if not c.get("up", false):
				h.m.fx.spark(to + Vector3(0, 0.05, 0), Vector3.UP, SILVER, 3, 3.0, 70.0, 0.18, 8.0, 0.7)

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

func _process(_delta: float) -> void:
	if not is_instance_valid(h) or h.m == null:
		return
	# effects run on match time (a slow frame or a screenshot never skips them), long steps clamped
	var delta := clampf(float(h.m.time) - fx_clock, 0.0, 1.0 / 30.0)
	fx_clock = float(h.m.time)
	for s in stars:
		var n: MeshInstance3D = s["node"]
		if float(s["t"]) >= float(s["dur"]):
			n.visible = false
			continue
		s["t"] = float(s["t"]) + delta
		var u := clampf(float(s["t"]) / maxf(0.01, float(s["dur"])), 0.0, 1.0)
		n.scale = Vector3.ONE * float(s["size"]) * (0.6 + 0.6 * sin(minf(u * 2.2, 1.0) * PI * 0.5))
		KitShaders.param(n, "power", float(s.get("pow", 1.6)) * (1.0 - u * u))
	_tick_bursts(delta)
	_tick_wisps(delta)
	for c in spent:
		if float(c["t"]) > 0.0:
			c["t"] = float(c["t"]) - delta
			var n2: Node3D = c["node"]
			var f := clampf(float(c["t"]) / 1.0, 0.0, 1.0)
			n2.scale = Vector3.ONE * f
			if float(c["t"]) <= 0.0: n2.visible = false
	tick_shots()
	_tick_rain(delta)
	_tick_streaks(delta)
	if tint:
		tint_k = move_toward(tint_k, tint_want, delta * 5.0)
		tint.material.set_shader_parameter("power", tint_k)
		tint.visible = tint_k > 0.01

func _tick_bursts(delta: float) -> void:
	for b in bursts:
		var n: MeshInstance3D = b["node"]
		if float(b["t"]) >= float(b["dur"]):
			n.visible = false
			continue
		b["t"] = float(b["t"]) + delta
		var fade := float(b["dur"]) - float(b["hold"])
		var u := clampf((float(b["t"]) - float(b["hold"])) / maxf(0.01, fade), 0.0, 1.0)
		KitShaders.param(n, "power", 1.6 * (1.0 - u))

# ------------------------------------------------------------------ Spirit Walk aura
var aura: MeshInstance3D = null

## A soft orchid shell over her while she walks as a spirit (k 0 = off).
func aura_on(k: float) -> void:
	if aura == null:
		aura = KitMeshes.inst(self, Models.capsule(0.42, 1.7), KitShaders.mat("beam", Color(THREAD, 0.9)))
		aura.material_override.set_shader_parameter("bands", 3.0)
	aura.visible = k > 0.01
	if aura.visible:
		aura.global_position = h.position + Vector3(0, 0.9 * float(h.cdat.get("scale", 1.0)), 0)
		aura.material_override.set_shader_parameter("power", k * 0.8)
