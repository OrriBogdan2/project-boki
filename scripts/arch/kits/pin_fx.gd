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
## - the Rain of Arrows (Hail Wall): needle posts round the arc laced together like her corset, red thread
##   criss-crossing between the posts and across the ground the wall covers (her laces, red, not a
##   glowing band), arrows streaking down, blue burn flames on foes inside
## - the Spirit Walk screen tint while she is inside something (her own screen only)
## - the Spirit Walk body tint: her whole body darkens toward her deep orchid for the roll and the walk (every game)

const STARS := 8
const BURSTS := 3
const ARROWS := 10
const SPENT := 8
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
var posts: Array = []
var laces: Array = []          # {node, a, b}: the Hail Wall's threads, a -> b in the world
var streaks: Array = []        # {node, t, from, to}
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
	# the laces: solid toon thread (no added glow, so the red holds on bright grass); every other one in
	# shade, the strand passing under
	for i in (POSTS - 1) * 4:
		var tone := THREAD if i % 2 == 0 else THREAD.darkened(0.3)
		var lace := KitMeshes.inst(self, Models.box(LACE_W, LACE_W, 1.0), Models.toon(tone, false, 0.5))
		laces.append({"node": lace, "a": Vector3.ZERO, "b": Vector3.ZERO})
	for i in POSTS:
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
	for i in STREAKS:
		var streak_node := KitMeshes.inst(self, KitMeshes.quad(0.07, 1.3), KitShaders.mat("streak", SILVER))
		streaks.append({"node": streak_node, "t": 0.0})
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
		var hit := hits.any(func(hh): return (hh[0] as Vector3).distance_to(at) < 1.6)
		if not hit and kind in ["tap", "arrow", "over"]:
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
