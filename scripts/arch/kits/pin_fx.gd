class_name PinFx
extends Node3D
## Hem's own effects, every one pooled (built once when the kit starts, then shown, moved and hidden). The
## coloured ones are layered (KitShaders): an alpha-blended body in her red, its pale half and gold with the glow
## on top, so they keep their colour on bright grass.
## - fletch bursts (her own motif: feathers radiating from a core): the red stage-ready flash at the bow,
##   the gold perfect-release burst with its ring, the glint at the bow hand (only while a stage is ready:
##   red Empowered, white-hot Supercharged and a full Heavy Shot)
## - stars: the red X-star on a Supercharged hit, the red-white Heavy Shot impact
## - arrows: the look of each of her shots (Empowered red bolt, Supercharged white-red beam, a dull
##   overdrawn shaft, the big red Heavy Shot with a hot core), each with its own trail, drawn
##   over the shot the match moves (the round's own sphere is shrunk away)
## - spent arrows: one of the bow's arrows that lands with no hit stays stuck in the ground, thread attached,
##   for 4 s (the Heavy Shot leaves nothing: owner 11-08)
## - the Rain of Arrows (Hail Wall): the strip it covers laced flat on the ground like her corset seen from above
##   (two red thread edges and a red X in every gap: solid thread, not a glowing band, nothing standing up to
##   zigzag across the view), her own arrows lobbed up, then falling into the strip and sticking a moment,
##   blue burn flames on foes inside. No dust or sparks: the arrows and the laces are the whole look.
## - the Spirit Walk screen tint while she is inside something (her own screen only)
## - the Spirit Walk body tint: her whole body darkens toward her deep orchid for the roll and the walk (every game)

const STARS := 8
const BURSTS := 3
const ARROWS := 10
const SPENT := 8
const VOLLEY := 14             # the Hail Wall's arrows: up out of the bow, then falling and sticking (pooled)
const FLAMES := 4
const POSTS := 9               # the Hail Wall's eyelets along each edge (8 gaps, each laced)
const LACE_W := 0.06           # m: an edge lace's thickness, a thread that still holds at the match camera
const LACE_X_K := 0.7          # the X strands' thickness against an edge's (the edges carry the shape)
const LACE_STEP := 0.5         # m of height between a lace's ends past which it is cut (a step, a prop, a dip)
const FALL_T := 0.24           # s a Hail Wall arrow takes to come down
const FALL_H := 4.0            # m above the strip it falls from (higher reads as a stray arrow off the strip)
const STUCK_T := 0.7           # s it then stands in the ground
const UP_T := 0.32             # s the cast's arrows take to fly up out of view
const RAIN_EVERY := 0.06       # s between two falling arrows
const RAIN_SCALE := 1.3        # the falling arrows' size (the bow's Empowered arrow is 1)
const RAIN_TRAIL := 1.6        # m of trail behind a falling arrow (before RAIN_SCALE)
const LACE_IN := 0.25          # s the laces take to draw across as the wall goes up
const LACE_CLEAR := 0.8        # m of ground a lace keeps from a shown Hunter's feet, else it parts (COMBAT_CLARITY)
## her dash after-image: red fletch streaks left at hip, chest and shoulder height, how long each lasts
## (s), how many are pooled and how often a set is left (s)
const WISP_T := 0.26
const WISPS := 12
const WISP_EVERY := 0.05
const SPENT_T := 4.0           # s a spent arrow stays in the ground
## the Heavy Shot's arrow is this many times a normal arrow (the Empowered bolt is 1.0): unmistakable
const HEAVY_SCALE := 6.0
const HEAVY_BACK := 4.5        # m the Heavy Shot's arrow reaches back from its head: it grows in over that much
                               # flight, so it never lies back across her (it leaves the bow)
const ULT_WIDTH := 0.6          # m: Starpiercer's arrow head and trail, its hit width (2 x the 0.3 shot radius)
const THREAD := Color("d41e2e")     # her laces' crimson (archetypes/archer.json "color"; owner 11-11: red, never pink)
const PALE := Color("ffe4d6")       # her white-hot: heads and hot cores (warm white, not a pastel pink)
const DEEP := Color("7a0c14")       # her laces in shade: the overdrawn trail
const GOLD := Color("ffc02a")       # the perfect-release cue only (a timing signal, not her body colour)
const SILVER := Color("dfe6f0")     # her needles
const FLETCH := Color("c8b48c")     # the feathers
const TINT_WALK := 0.45         # the Spirit Walk wash while she walks clear of everything (1 = inside something)
const WASH_COL := Color("2e0c3e")   # her orchid darkened: the body colour while she phases (pin.md frame 0360)
const WASH_MAX := 0.75              # 0..1: how far the body mixes toward WASH_COL at the full tint
const WASH_RATE := 5.0              # 1/s: the tint fades in and out in 0.2 s

var h: Hunter
var stars: Array = []          # {node, t, dur, size, follow}
var arrows: Array = []         # pooled arrow nodes
var live := {}                 # shot sid -> {node, kind, pos, life}
var spent: Array = []          # {node, t}
var hits: Array = []           # [pos, time] of shot hits (a shot that hit someone isn't planted)
var bursts: Array = []         # fletch bursts {node, t, dur, size, pow}
var bow_glint: MeshInstance3D  # the fletch glint at the bow hand while a stage is ready
var rain := {}                 # the live wall: {center, dir, radius, deg, t, every}
var laces: Array = []          # {node, a, b}: the Hail Wall's threads, a -> b in the world
var volley: Array = []         # {node, t, phase ("up", "fall", "stuck"), from, to}
var flames: Array = []         # {node, foe}
var wisps: Array = []          # {node, t}
var wisp_next := 0
var wisp_at := -1.0
var tint: ColorRect = null
var tint_k := 0.0
var tint_want := 0.0
var wash_k := 0.0              # 0..1: the body tint now
var planted := 0               # spent arrows planted (checks)
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
	# the laces: solid toon thread (no added glow, so the red holds on bright grass); per gap the two edges and
	# an X, its second strand in shade (passing under)
	for i in (POSTS - 1) * 4:
		var tone := THREAD.darkened(0.3) if i % 4 == 3 else THREAD
		var lace := KitMeshes.inst(self, Models.box(LACE_W, LACE_W * 0.5, 1.0), Models.toon(tone, false, 0.5))
		laces.append({"node": lace, "a": Vector3.ZERO, "b": Vector3.ZERO, "k": LACE_X_K if i % 4 >= 2 else 1.0})
	for i in VOLLEY:
		volley.append({"node": _arrow_node(), "t": 0.0, "phase": ""})
	for i in WISPS:
		var wisp := KitMeshes.inst(self, KitMeshes.quad(1.0, 1.0), KitShaders.mat("streak", THREAD, true))
		wisps.append({"node": wisp, "t": 0.0})
	for i in FLAMES:
		var fm := KitShaders.mat("flame", Color("ff4a3a"))
		fm.set_shader_parameter("seed", float(i) * 1.7)
		flames.append({"node": KitMeshes.inst(self, KitMeshes.quad(0.9, 1.3), fm), "foe": null})
	aura = KitMeshes.inst(self, Models.capsule(0.42, 1.7), KitShaders.mat("beam", Color(THREAD, 0.9)))
	aura.material_override.set_shader_parameter("bands", 3.0)

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
## Trails are streaks (a white-hot centre line in a red body): the widths hold at the match camera.
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
	n.scale = Vector3.ONE
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
	KitShaders.param(core, "color", PALE)
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
	KitShaders.param(n, "rot", KitLooks.vis_rng.randf() * TAU)
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
	Oomph.hide_orb(s)
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
		if e["kind"] == "heavy":
			n.scale = Vector3.ONE * clampf(p.distance_to(s["start"]) / HEAVY_BACK, 0.15, 1.0)
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
		if kind in ["tap", "arrow", "over"] and not _ended_on_body(e["s"], at):
			_plant(at, (e["s"]["vel"] as Vector2), kind)

## Whether shot `s`, last seen at `at`, ended on someone: a hit arrow leaves nothing on the floor, only a miss
## plants one (the owner's rule). A hit our side dealt (note_hit, at the contact) counts, and so does a shot that
## ended touching a body it could hit: that covers a hit soaked by a shield or a dodge, and another player's screen,
## where the damage is the shooter's and on_deal never runs. Both look one step past `at` (the match may have
## moved the shot on before it hit).
func _ended_on_body(s: Dictionary, at: Vector3) -> bool:
	var reach := (s["vel"] as Vector2).length() / maxf(1.0, float(Engine.physics_ticks_per_second)) + 0.3
	var flat := func(a: Vector3, b: Vector3) -> float: return Vector2(a.x - b.x, a.z - b.z).length()
	if hits.any(func(hh): return flat.call(hh[0] as Vector3, at) < reach + 0.6):
		return true
	var m: Match = h.m
	var rivals := func(o: Ent) -> bool: return o.team != h.team and o.hittable()
	var alive := func(o: Ent) -> bool: return not o.dead
	var bodies: Array = m.hunters.filter(rivals) + m.kins.filter(rivals) + m.mobs.filter(alive)
	for b in bodies:
		var e: Ent = b
		if flat.call(e.pos, at) < e.r + float(s["r"]) + Match.HIT_SLACK + reach and \
				(m.shot_height_ok(e, at.y) or m.shot_from_above_ok(s, e, at.y)):
			return true
	return false

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

## Her dash after-image: three red fletch streaks at hip, chest and shoulder height, lying along the way
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

## Hail Wall's cast: five of her arrows flying up out of the bow, lobbed toward `dir`.
func lob(at: Vector3, dir: Vector2) -> void:
	var vr := KitLooks.vis_rng
	for i in 5:
		var spread := Vector3(vr.randf_range(-0.6, 0.6), vr.randf_range(-0.3, 0.3), vr.randf_range(-0.6, 0.6))
		_volley_arrow("up", at, at + Vector3(dir.x * 2.0, 5.5, dir.y * 2.0) + spread, UP_T)

## Starts a free arrow of the volley flying `from` -> `to` over `t` s ("up" out of view, or "fall" into the strip).
func _volley_arrow(phase: String, from: Vector3, to: Vector3, t: float) -> void:
	for c in volley:
		if float(c["t"]) > 0.0:
			continue
		var n: Node3D = c["node"]
		_dress(n, "arrow")
		n.scale = Vector3.ONE * RAIN_SCALE
		for f in ["Fin0", "Fin2"]:      # (red fletching: her red and white, no tan wings at this size)
			(n.get_node(f) as MeshInstance3D).material_override.set_shader_parameter("albedo", THREAD)
		var tr := n.get_node("Trail") as Node3D
		tr.scale.x = RAIN_TRAIL
		tr.position.z = RAIN_TRAIL * 0.5 + 0.2
		n.visible = true
		c["phase"] = phase
		c["t"] = t
		c["t0"] = t
		c["from"] = from
		c["to"] = to
		_point(n, from, to - from)
		return

## Puts arrow `n` at `at`, its head toward `v`, its flat trail turned to face the camera.
func _point(n: Node3D, at: Vector3, v: Vector3) -> void:
	n.global_position = at
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	var up := Vector3.UP
	if cam != null:
		up = (cam.global_position - at).normalized()
	if v.length() < 0.001 or absf(v.normalized().dot(up)) > 0.98:
		up = Vector3.FORWARD
	n.look_at(at + v, up)

func _tick_wisps(delta: float) -> void:
	for w in wisps:
		if float(w["t"]) <= 0.0:
			continue
		w["t"] = float(w["t"]) - delta
		var n: MeshInstance3D = w["node"]
		KitShaders.param(n, "power", 1.6 * clampf(float(w["t"]) / WISP_T, 0.0, 1.0))
		n.visible = float(w["t"]) > 0.0

# ------------------------------------------------------------------ Rain of Arrows
## Shows the wall for `t` s: an arc of `deg` round `center` at `radius`, facing `dir`, `width` m deep. The
## laces draw across over LACE_IN (_tick_rain).
func rain_on(center: Vector3, dir: Vector2, radius: float, deg: float, width: float, t: float) -> void:
	rain = {"center": center, "dir": dir, "radius": radius, "deg": deg, "t": t, "t0": t, "every": 0.0}
	var yaw := atan2(-dir.x, -dir.y)
	var half := deg_to_rad(deg) * 0.5
	var gaps := POSTS - 1
	var w := width * 0.5
	var gnd := Vector3(0, 0.05, 0)
	for i in range(1, POSTS):
		var u0 := lerpf(-half, half, float(i - 1) / gaps)
		var u1 := lerpf(-half, half, float(i) / gaps)
		var in0 := _arc_pt(center, yaw, radius - w, u0) + gnd
		var in1 := _arc_pt(center, yaw, radius - w, u1) + gnd
		var out0 := _arc_pt(center, yaw, radius + w, u0) + gnd
		var out1 := _arc_pt(center, yaw, radius + w, u1) + gnd
		var n := (i - 1) * 4
		# all flat on the ground: the inner and outer edge, then the X across the strip
		_lace(n, in0, in1)
		_lace(n + 1, out0, out1)
		_lace(n + 2, in0, out1)
		_lace(n + 3, out0, in1)
	_pull_laces(0.0, 1.0)

## Lace `i` runs a -> b; across a step in the ground it is cut (it would stand up as a tall line on screen).
func _lace(i: int, a: Vector3, b: Vector3) -> void:
	laces[i]["a"] = a
	laces[i]["b"] = b
	laces[i]["cut"] = absf(a.y - b.y) > LACE_STEP

## Every lace drawn `grow` (0..1) of the way from its start, `thick` (0..1) of its thickness.
func _pull_laces(grow: float, thick: float) -> void:
	for l in laces:
		var n: MeshInstance3D = l["node"]
		var a: Vector3 = l["a"]
		var b: Vector3 = a.lerp(l["b"], maxf(grow, 0.01))
		n.visible = not l.get("cut", false)
		n.global_position = (a + b) * 0.5
		n.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.98 else Vector3.RIGHT)
		var k := thick * float(l.get("k", 1.0))
		n.scale = Vector3(k, k, a.distance_to(b))

## A lace that runs within LACE_CLEAR of a shown Hunter's feet (ground distance), or crosses its box on screen (the
## camera looks down at a slant, so a lace on its side of a body cuts across it), is hidden while it does: the wall's
## red threads never cut across a body (docs/COMBAT_CLARITY.md); the rest of the laces and the arrows still mark it.
func _part_laces() -> void:
	var feet: Array[Vector2] = []
	var zones: Array[Rect2] = []
	for o: Hunter in h.m.hunters:
		if not o.out and not o.unseen:
			feet.append(Vector2(o.pos.x, o.pos.z))
			var z: Rect2 = HunterZone.rect_of(h.m, o)
			if z.has_area():
				zones.append(z)
	for l in laces:
		var a: Vector3 = l["a"]
		var b: Vector3 = l["b"]
		var near := false
		for f in feet:
			var c := Geometry2D.get_closest_point_to_segment(f, Vector2(a.x, a.z), Vector2(b.x, b.z))
			if c.distance_to(f) < LACE_CLEAR:
				near = true
				break
		if not near and not zones.is_empty():
			near = _on_screen_box(a, b, zones)
		(l["node"] as Node3D).visible = not near and not l.get("cut", false)


## Whether the line a -> b crosses any of the screen boxes `zones` (sampled every eighth of its length).
func _on_screen_box(a: Vector3, b: Vector3, zones: Array[Rect2]) -> bool:
	var cam: Camera3D = h.m.cam
	if cam == null or cam.is_position_behind(a) or cam.is_position_behind(b):
		return false
	var sa: Vector2 = cam.unproject_position(a)
	var sb: Vector2 = cam.unproject_position(b)
	for i in 9:
		var p: Vector2 = sa.lerp(sb, i / 8.0)
		for z in zones:
			if z.has_point(p):
				return true
	return false


func _arc_pt(center: Vector3, yaw: float, radius: float, u: float) -> Vector3:
	var a := yaw + u
	var q := center + Vector3(-sin(a), 0, -cos(a)) * radius
	return AimMode.ground(h.m, q)

func rain_off() -> void:
	rain = {}
	for c in volley:
		if String(c["phase"]) != "up":
			c["t"] = 0.0
			(c["node"] as Node3D).visible = false
	for l in laces: (l["node"] as Node3D).visible = false
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
	# the laces draw across as it goes up and thin away over its last 0.4 s (moved only while they change)
	var grow := clampf((float(rain["t0"]) - float(rain["t"])) / LACE_IN, 0.0, 1.0)
	var thick := clampf(float(rain["t"]) / 0.4, 0.0, 1.0)
	if grow < 1.0 or thick < 1.0 or not rain.has("laced"):
		_pull_laces(grow, thick)
		if grow >= 1.0: rain["laced"] = true
	_part_laces()
	if float(rain["t"]) <= 0.0:
		rain_off()
		return
	# her arrows falling into the strip (not in its last moment, so the last ones are gone as it ends)
	rain["every"] = float(rain["every"]) - dt
	if float(rain["every"]) <= 0.0 and float(rain["t"]) > FALL_T + STUCK_T * 0.5:
		rain["every"] = RAIN_EVERY
		var vr := KitLooks.vis_rng
		var d: Vector2 = rain["dir"]
		var yaw := atan2(-d.x, -d.y)
		var half := deg_to_rad(float(rain["deg"])) * 0.5 * 0.95
		var depth := float(rain["radius"]) + vr.randf_range(-0.6, 0.6)
		var q := _arc_pt(rain["center"], yaw, depth, vr.randf_range(-half, half))
		var lean := (q - (rain["center"] as Vector3)).normalized() * 0.7      # (coming down away from her)
		_volley_arrow("fall", q - Vector3(lean.x, -FALL_H, lean.z), q, FALL_T)
	for f in flames:
		var foe: Ent = f["foe"]
		if foe != null and is_instance_valid(foe) and not foe.dead:
			(f["node"] as Node3D).global_position = foe.position + Vector3(0, 0.75, 0)
		else:
			(f["node"] as Node3D).visible = false

## The volley: arrows flying up out of view, falling into the strip, then standing in it until they shrink away.
func _tick_volley(dt: float) -> void:
	for c in volley:
		if float(c["t"]) <= 0.0:
			continue
		var n: Node3D = c["node"]
		c["t"] = float(c["t"]) - dt
		var from: Vector3 = c["from"]
		var to: Vector3 = c["to"]
		var u := 1.0 - clampf(float(c["t"]) / maxf(0.01, float(c["t0"])), 0.0, 1.0)
		match String(c["phase"]):
			"up":
				_point(n, from.lerp(to, 1.0 - (1.0 - u) * (1.0 - u)), to - from)
				if float(c["t"]) <= 0.0: n.visible = false
			"fall":
				_point(n, from.lerp(to, u * u), to - from)
				if float(c["t"]) <= 0.0:
					# it lands: the head in the ground, no trail, a small red flash where it went in
					c["phase"] = "stuck"
					c["t"] = STUCK_T
					c["t0"] = STUCK_T
					(n.get_node("Trail") as Node3D).visible = false
					_point(n, to + (to - from).normalized() * 0.15, to - from)     # (the head sunk in)
					star(to + Vector3(0, 0.08, 0), 0.6, THREAD, 0.08, 0.0, 0.785, 1.2)
			"stuck":
				n.scale = Vector3.ONE * RAIN_SCALE * clampf(float(c["t"]) / 0.15, 0.0, 1.0)
				if float(c["t"]) <= 0.0: n.visible = false

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
	_tick_volley(delta)
	var phasing: bool = h.ak is ArcherKit and (h.ak as ArcherKit).spirit.phasing()
	wash_k = move_toward(wash_k, 1.0 if phasing else 0.0, delta * WASH_RATE)
	h.wash = wash_k * WASH_MAX
	h.wash_col = WASH_COL
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
var aura: MeshInstance3D       # built with the pools above, hidden until she walks

## A soft red shell over her while she walks as a spirit (k 0 = off).
func aura_on(k: float) -> void:
	aura.visible = k > 0.01
	if aura.visible:
		aura.global_position = h.position + Vector3(0, 0.9 * float(h.cdat.get("scale", 1.0)), 0)
		aura.material_override.set_shader_parameter("power", k * 0.8)
