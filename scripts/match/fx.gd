class_name Fx
extends Node3D
## Pooled visual effects: particle bursts, damage numbers, ground rings, attack telegraphs, lightning.

const TELEGRAPH: Shader = preload("res://shaders/telegraph.gdshader")
## a word that would land on another stacks this far above it (m along the camera's up), at most this
## many times
const WORD_STEP := 0.62
const WORD_STACK_MAX := 4
var font: Font = preload("res://fonts/LilitaOne-Regular.ttf")

var bursts: Array[CPUParticles3D] = []
var bi := 0
var nums: Array = []          # {node, t, vel}
var num_pool: Array[Label3D] = []
var rings: Array = []         # {node, t, dur, r}
var teles: Array = []
var lines: Array = []         # {node, t}
var flashes: Array = []
var particle_mat: StandardMaterial3D
var rng := RandomNumberGenerator.new()
var sparks: Array[CPUParticles3D] = []    # velocity-stretched streaks (shaders/spark.gdshader)
var si := 0
var flash_pool: Array[MeshInstance3D] = []
var fi := 0

func _ready() -> void:
	particles = PARTICLES * float(Settings.q("fx"))
	particle_mat = StandardMaterial3D.new()
	particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_mat.vertex_color_use_as_albedo = true
	particle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# soft painted dots with a bright core, always facing the camera (shaders/fx_dot.gdshader)
	var pm := QuadMesh.new(); pm.size = Vector2(0.17, 0.17)
	var dot_mat := ShaderMaterial.new(); dot_mat.shader = load("res://shaders/fx_dot.gdshader")
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1)); ramp.set_color(1, Color(1, 1, 1, 0))
	for i in 28:
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.emitting = false
		p.explosiveness = 0.95
		p.mesh = pm
		p.material_override = dot_mat
		p.lifetime = 0.55
		p.amount = 16
		p.direction = Vector3.UP
		p.spread = 180.0
		p.gravity = Vector3(0, -12, 0)
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 5.0
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.4
		p.damping_min = 2.0
		p.damping_max = 4.0
		p.color_ramp = ramp
		p.local_coords = false
		add_child(p)
		bursts.append(p)
	for i in NUM_POOL:
		var l := Label3D.new()
		l.font = font
		l.font_size = 52
		l.pixel_size = 0.011
		l.outline_size = 14
		l.outline_modulate = Color(0.05, 0.04, 0.08, 0.9)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.render_priority = 10
		l.outline_render_priority = 9
		l.visible = false
		add_child(l)
		num_pool.append(l)
	_build_sparks()
	# no effect casts a shadow: rings, telegraphs, decals, particles, bolts (item 94, ShadowPolicy)
	ShadowPolicy.off(self)
	child_entered_tree.connect(ShadowPolicy.off)
	ShadowPolicy.watch_particles(get_tree())     # and no particle system anywhere in the match does

func _build_sparks() -> void:
	var qm := QuadMesh.new(); qm.size = Vector2(1, 1)
	var sm := ShaderMaterial.new(); sm.shader = load("res://shaders/spark.gdshader")
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1)); ramp.set_color(1, Color(1, 1, 1, 0))
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1)); shrink.add_point(Vector2(1, 0.25))
	for i in 18:
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.emitting = false
		p.explosiveness = 1.0
		p.mesh = qm
		p.material_override = sm
		p.lifetime = 0.25
		p.amount = 8
		p.particle_flag_align_y = true
		p.direction = Vector3.UP
		p.spread = 60.0
		p.gravity = Vector3(0, -10, 0)
		p.initial_velocity_min = 5.0
		p.initial_velocity_max = 10.0
		p.scale_amount_min = 0.035
		p.scale_amount_max = 0.06
		p.scale_amount_curve = shrink
		p.damping_min = 6.0
		p.damping_max = 12.0
		p.color_ramp = ramp
		p.local_coords = false
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		sparks.append(p)
	if _impact_quad == null:
		_impact_quad = QuadMesh.new(); _impact_quad.size = Vector2(2, 2)
	var ish: Shader = load("res://shaders/impact.gdshader")
	for i in 20:
		var mi := MeshInstance3D.new()
		mi.mesh = _impact_quad
		var m := ShaderMaterial.new(); m.shader = ish
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		flash_pool.append(mi)

## A spray of hot streaks (hit sparks, muzzle embers) along dir.
func spark(at: Vector3, dir: Vector3, col: Color, amount := 8, speed := 9.0, spread := 50.0, life := 0.22, grav := 10.0, size := 1.0) -> void:
	if sparks.is_empty():
		return
	var p := sparks[si]
	si = (si + 1) % sparks.size()
	p.global_position = at
	var na := maxi(2, int(round(amount * clampf(particles / PARTICLES, 0.4, 1.0))))
	if p.amount != na: p.amount = na
	p.color = col
	p.lifetime = life
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -grav, 0)
	p.scale_amount_min = 0.035 * size
	p.scale_amount_max = 0.06 * size
	p.restart()
	p.emitting = true

## A gun going off: a short star of flame at the muzzle, embers thrown forward, and on the heavy
## guns a puff of smoke that hangs for a moment. power: 1 an SMG round .. 3 a slug or a sniper.
func muzzle(at: Vector3, dir2: Vector2, col: Color, power := 1.0) -> void:
	var d := Vector3(dir2.x, 0.05, dir2.y).normalized()
	var hot := Color(1.0, 0.86, 0.55).lerp(col, 0.25)
	flash(at + d * 0.12, hot, 0.22 + 0.09 * power, 0.05 + 0.012 * power)
	spark(at, d, hot, int(3 + 2 * power), 7.0 + 3.0 * power, 16.0 + 6.0 * power, 0.09 + 0.02 * power, 0.0, 0.8 + 0.15 * power)
	if power >= 1.8:
		burst(at + d * 0.35, Color(0.78, 0.76, 0.74, 0.35), int(3 * power), 1.2, 0.5, -0.6, 1.6, d, 30.0)

## A hit landing: a flash where it struck, sparks thrown out the far side along the shot, a few
## kicked back toward the shooter; crits flash gold and wider, armor sheds blue shards.
## power: 0..3 from the damage.
func impact(at: Vector3, dir: Vector3, col: Color, power := 1.0, crit := false, armor := false) -> void:
	var fcol := col
	if crit: fcol = Color("ffd23f")
	elif armor: fcol = Color("8fd4ff")
	var sz := (0.34 + 0.17 * power) * (1.45 if crit else 1.0)
	flash(at, fcol, sz, 0.07 + 0.02 * power + (0.04 if crit else 0.0))
	var dd := dir.normalized() if dir.length() > 0.01 else Vector3.UP
	dd = (dd + Vector3(0, 0.35, 0)).normalized()
	spark(at, dd, fcol.lerp(Color.WHITE, 0.3), int(5 + 4 * power) + (6 if crit else 0), 7.0 + 3.0 * power, 38.0 + (25.0 if crit else 0.0), 0.2 + 0.04 * power, 12.0, 1.0 + 0.2 * power)
	if power >= 1.0 or crit:
		spark(at, (-dd + Vector3(0, 0.9, 0)).normalized(), fcol, int(2 + 2 * power), 4.0 + 1.5 * power, 70.0, 0.18, 14.0, 0.8)
	if armor:
		burst(at, Color("9ad8ff"), int(4 + 3 * power), 4.5, 0.35, 14.0, 0.8, dd, 70.0)
	if crit:
		ring(at + Vector3(0, -0.6, 0), 1.1 + 0.25 * power, Color(1.0, 0.85, 0.3, 0.85), 0.2)

## A straight bolt of light from a to b that flares and fades (a rail shot, a beam ability): a soft
## camera-facing ribbon (shaders/light_shaft.gdshader) with a white-hot core line inside it.
var _beam_sh: Shader
func beam(a: Vector3, b: Vector3, col: Color, width := 0.45, dur := 0.28) -> void:
	if _beam_sh == null:
		_beam_sh = load("res://shaders/light_shaft.gdshader")
	var ln := a.distance_to(b)
	if ln < 0.2:
		return
	var axis := (b - a) / ln
	for k in 2:
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new(); qm.size = Vector2(1, 1)
		mi.mesh = qm
		var m := ShaderMaterial.new(); m.shader = _beam_sh
		m.set_shader_parameter("color", col if k == 0 else col.lerp(Color.WHITE, 0.75))
		m.set_shader_parameter("intensity", 2.2 if k == 0 else 3.0)
		mi.material_override = m
		var w := width * (1.0 if k == 0 else 0.3)
		var x_axis := axis.cross(Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT).normalized() * w
		var z_axis := x_axis.cross(axis).normalized()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_transform = Transform3D(Basis(x_axis, axis * ln, z_axis), (a + b) * 0.5)
		var tw := mi.create_tween()
		tw.tween_method(func(v: float) -> void: m.set_shader_parameter("intensity", v), 2.2 if k == 0 else 3.0, 0.0, dur).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)

## Readability: every particle burst is thinned out, so effects mark what happened without
## burying the fight under confetti.
const PARTICLES := 0.6
var particles := PARTICLES     # times the quality preset's particle amount (Settings q("fx"))
var own_look := false          # a Hero's stage with its own look runs: the shared rings, cones and bursts stay out
var radial := 0                # bursts and rings spawned so far (dust puffs don't count; checks read it)

## A particle burst: an effect that marks a hit or a blast, never plain movement (dust is for that).
func burst(at: Vector3, col: Color, amount := 14, speed := 4.0, life := 0.5, grav := 12.0, size_k := 1.0,
		dir := Vector3.UP, spread := 180.0) -> void:
	if own_look:
		return
	radial += 1
	_emit(at, col, amount, speed, life, grav, size_k, dir, spread)

func _emit(at: Vector3, col: Color, amount: int, speed: float, life: float, grav: float, size_k: float, dir: Vector3,
		spread: float) -> void:
	var p := bursts[bi]
	bi = (bi + 1) % bursts.size()
	p.global_position = at
	var na := maxi(3, int(round(amount * particles)))
	if p.amount != na: p.amount = na      # (resizing reallocates its buffers: only when it changes)
	p.color = col
	p.lifetime = life
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -grav, 0)
	p.scale_amount_min = 0.6 * size_k
	p.scale_amount_max = 1.4 * size_k
	p.direction = dir
	p.spread = spread
	p.restart()
	p.emitting = true

## A low puff of dust at the feet: the cue for movement (dashes, landings, jumps).
func dust(at: Vector3, n := 8) -> void:
	_emit(at + Vector3(0, 0.1, 0), Color(0.82, 0.8, 0.72, 0.9), n, 2.2, 0.45, 2.0, 1.3, Vector3.UP, 80.0)

## The shared dash cue: a dust puff where it sets off (the after-images follow in Hunter.render). No ring or
## burst: those are kept for blasts that do something.
func dash_trail(h) -> void:
	dust(h.pos, 7)

var ghosts: Array = []
var _ghost_mesh: Mesh

## A fading after-image of a dashing hunter.
func ghost(at: Vector3, yaw: float, col: Color, scl: float) -> void:
	if _ghost_mesh == null:
		_ghost_mesh = Models.capsule(0.3, 1.25)
	var mi := MeshInstance3D.new()
	mi.mesh = _ghost_mesh
	mi.material_override = Models.glow_mat(Color(col, 0.55))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = at + Vector3(0, 0.7 * scl, 0)
	mi.rotation.y = yaw
	mi.scale = Vector3(1.0, 1.0, 1.3) * scl
	ghosts.append({"node": mi, "t": 0.0, "col": col})

func number(at: Vector3, v: float, col: Color, look: int, prefix := "") -> void:
	if v < 0.5 or (prefix == "" and not Settings.get_v("damage_numbers")):
		return
	# rapid hits on the same target (a minigun, an SMG, pellets, a burn ticking) add up on one
	# number that sits on it and grows with each hit, then floats off once the hits stop
	for n in nums:
		if n.has("val") and float(n["last"]) < MERGE_T and String(n["pre"]) == prefix and (n["base"] as Vector3).distance_to(at) < 1.6:
			n["val"] = float(n["val"]) + v
			n["last"] = 0.0
			n["base"] = at
			n["hits"] = int(n["hits"]) + 1
			var ln: Label3D = n["node"]
			ln.text = prefix + str(int(round(float(n["val"]))))
			if look >= int(n["look"]):
				n["look"] = look
				ln.modulate = col
			_num_look(ln, int(n["look"]))
			ln.font_size = _num_size(float(n["val"]), int(n["look"]))
			ln.modulate.a = 1.0
			ln.scale = Vector3.ONE * NUM_POP[look]
			return
	var l: Label3D = num_pool.pop_front()
	num_pool.append(l)
	for n in nums:
		if n["node"] == l:
			nums.erase(n); break
	l.text = prefix + str(int(round(v)))
	l.modulate = col
	_num_look(l, look)
	l.font_size = _num_size(v, look)
	var off := Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.2, 0.2))
	l.global_position = at + off
	l.visible = true
	l.scale = Vector3.ONE * NUM_POP[look]
	nums.append({"node": l, "t": 0.0, "last": 0.0, "vel": Vector3(rng.randf_range(-0.5, 0.5), 2.6, 0), "val": v, "pre": prefix, "base": at, "off": off, "hits": 1, "look": look})

## How long a number keeps taking hits after the last one, and how long it lingers on the target.
const MERGE_T := 0.45
const STICK_T := 0.3

## A damage number's look, quietest to loudest (Juice.number picks it): the hits you take and your Boki's,
## your own, an empowered hit (o.heavy or a payoff: its own colour, a size up, a deep red outline), a crit.
const NUM_SMALL := 0
const NUM_PLAIN := 1
const NUM_HEAVY := 2
const NUM_CRIT := 3
const NUM_POP := [1.15, 1.25, 1.5, 1.7]     # per look: it lands this many times its size and settles
const NUM_STEP := [-6, 0, 5, 8]             # per look: font size added to the size by amount
const NUM_EDGE := [14, 14, 18, 20]          # per look: outline width
const NUM_POOL := 24           # floating numbers and words on screen at once (the oldest is reused)
const NUM_OUTLINE := Color(0.05, 0.04, 0.08, 0.9)     # every number's dark outline ...
const HEAVY_OUTLINE := Color(0.34, 0.03, 0.02, 0.95)  # ... an empowered hit's a deep red, thicker
const CRIT_OUTLINE := Color(0.42, 0.12, 0.0, 0.95)    # ... a crit's a hot ember brown, thickest

## Outline per look: crits and empowered hits get a thicker, warm outline so they read as a different
## thing, not just another colour (pooled labels are reused, so every number sets this).
func _num_look(l: Label3D, look: int) -> void:
	l.outline_modulate = [NUM_OUTLINE, NUM_OUTLINE, HEAVY_OUTLINE, CRIT_OUTLINE][look]
	l.outline_size = NUM_EDGE[look]

## Bigger totals and louder looks read bigger, within a small range so numbers never cover the fight.
func _num_size(v: float, look: int) -> int:
	var k := clampf(log(maxf(v, 1.0)) / log(10.0) - 1.0, 0.0, 1.0)     # 10 -> 0, 100 -> 1
	return int(lerpf(36.0, 46.0, k)) + NUM_STEP[look]

## A short word that floats up (COMBO, an ability's name, BOND READY).
func word(at: Vector3, txt: String, col: Color, big := false) -> void:
	var l: Label3D = num_pool.pop_front()
	num_pool.append(l)
	for n in nums:
		if n["node"] == l:
			nums.erase(n); break
	l.text = txt
	l.modulate = col
	_num_look(l, NUM_PLAIN)
	l.font_size = 46 if big else 34
	l.global_position = _clear_spot(at)
	l.visible = true
	l.scale = Vector3.ONE * (1.25 if big else 1.0)
	nums.append({"node": l, "t": 0.0, "vel": Vector3(0, 2.4, 0)})

## Where a new word goes so it doesn't print over a word or number still rising near `at`: stepped up
## the screen (along the camera's up) above whatever is there.
func _clear_spot(at: Vector3) -> Vector3:
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam == null:
		return at
	var up := cam.global_basis.y
	var across := cam.global_basis.x
	var spot := at
	for i in WORD_STACK_MAX:
		var clash := false
		for n in nums:
			var other: Label3D = n["node"]
			var gap := other.global_position - spot
			var overlaps := absf(gap.dot(across)) < 1.8 and absf(gap.dot(up)) < WORD_STEP
			if other.visible and float(n["t"]) < 0.6 and overlaps:
				clash = true
				break
		if not clash:
			return spot
		spot += up * WORD_STEP
	return spot

func ring(at: Vector3, radius: float, col: Color, dur := 0.35) -> void:
	if own_look:
		return
	radial += 1
	var mi := MeshInstance3D.new()
	mi.mesh = Models.flat_quad(2.0)
	mi.material_override = Models.ring_mat(col, 0.12)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = at + Vector3(0, 0.08, 0)
	mi.scale = Vector3.ONE * 0.1
	rings.append({"node": mi, "t": 0.0, "dur": dur, "r": radius, "col": col})

## A melee swing: a bright crescent sweeping the arc in front of you, gone in a blink.
func slash(at: Vector3, a0: float, arc: float, reach: float, col: Color, heavy := false) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	var r0 := reach * 0.45
	for i in n:
		var u0 := a0 - arc * 0.5 + arc * float(i) / n
		var u1 := a0 - arc * 0.5 + arc * float(i + 1) / n
		# thickest in the middle of the sweep, thin at the ends
		var w0 := sin(PI * float(i) / n); var w1 := sin(PI * float(i + 1) / n)
		var o0 := Vector3(cos(u0), 0, sin(u0)); var o1 := Vector3(cos(u1), 0, sin(u1))
		var a := o0 * reach; var b := o1 * reach
		var c := o1 * lerpf(reach, r0, w1); var d := o0 * lerpf(reach, r0, w0)
		var ua := float(i) / n; var ub := float(i + 1) / n
		# UV.x along the sweep, UV.y from the blade's tip (0) to the inner edge (1)
		st.set_uv(Vector2(ua, 0)); st.add_vertex(a); st.set_uv(Vector2(ub, 0)); st.add_vertex(b); st.set_uv(Vector2(ub, 1)); st.add_vertex(c)
		st.set_uv(Vector2(ua, 0)); st.add_vertex(a); st.set_uv(Vector2(ub, 1)); st.add_vertex(c); st.set_uv(Vector2(ua, 1)); st.add_vertex(d)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/swoosh.gdshader")
	m.set_shader_parameter("color", col.lightened(0.15))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = at
	mi.scale = Vector3.ONE * (0.8 if not heavy else 0.9)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * (1.05 if not heavy else 1.15), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: m.set_shader_parameter("progress", v), 0.0, 1.0, 0.2 if not heavy else 0.26)
	tw.chain().tween_callback(mi.queue_free)

static var _impact_quad: QuadMesh
func flash(at: Vector3, col: Color, size := 0.35, dur := 0.06) -> void:
	# a star of rays round a white-hot core (shaders/impact.gdshader), from a pool so a firefight
	# doesn't make and free a mesh for every shot
	if flash_pool.is_empty():
		return
	var mi := flash_pool[fi]
	fi = (fi + 1) % flash_pool.size()
	for f in flashes:
		if f["node"] == mi:
			flashes.erase(f); break
	var m := mi.material_override as ShaderMaterial
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("seed", rng.randf() * TAU)
	m.set_shader_parameter("rays", float([4, 5, 6][rng.randi_range(0, 2)]))
	m.set_shader_parameter("life", 0.0)
	mi.scale = Vector3.ONE * size * 1.6
	dur = maxf(dur, 0.07)
	mi.visible = true
	mi.global_position = at
	flashes.append({"node": mi, "t": 0.0, "dur": dur, "s0": size * 1.6})

func bolt(a: Vector3, b: Vector3, col: Color) -> void:
	var pts := [a]
	for i in range(1, 5):
		var k := i / 5.0
		pts.append(a.lerp(b, k) + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.3, 0.3)))
	pts.append(b)
	for i in pts.size() - 1:
		var p0: Vector3 = pts[i]; var p1: Vector3 = pts[i + 1]
		var mi := MeshInstance3D.new()
		mi.mesh = Models.box(0.07, 0.07, 1.0)
		mi.material_override = Models.glow_mat(col)
		add_child(mi)
		mi.global_position = (p0 + p1) * 0.5
		mi.look_at(p1, Vector3.UP if absf((p1 - p0).normalized().y) < 0.95 else Vector3.RIGHT)
		mi.scale = Vector3(1, 1, p0.distance_to(p1))
		lines.append({"node": mi, "t": 0.0, "dur": 0.18})
	burst(b, col, 10, 3.0, 0.3, 4.0)

func cone(at: Vector3, d: Vector2, length: float, col: Color) -> void:
	if own_look:
		return
	for i in 3:
		burst(at + Vector3(d.x, 0.5, d.y) * (0.5 + i * 1.2), col, 12, 6.0, 0.4, 4.0, 1.4, Vector3(d.x, 0.2, d.y), 25.0)

# ---- telegraphs
func _tele_mesh(col: Color, shape: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mat := ShaderMaterial.new()
	mat.shader = TELEGRAPH
	mat.set_shader_parameter("color", col)
	mat.set_shader_parameter("shape", shape)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	teles.append(mi)
	return mi

func telegraph_circle(at: Vector3, radius: float, col: Color) -> Node3D:
	var mi := _tele_mesh(col, 0)
	mi.mesh = Models.flat_quad(radius * 2.0)
	mi.global_position = at + Vector3(0, 0.07, 0)
	return mi

func telegraph_rect(at: Vector3, d: Vector2, length: float, width: float, col: Color) -> Node3D:
	var mi := _tele_mesh(col, 1)
	var pm := PlaneMesh.new(); pm.size = Vector2(width, length)
	mi.mesh = pm
	mi.set_meta("len", length)
	aim_telegraph(mi, at, d)
	return mi

func aim_telegraph(mi: Node3D, at: Vector3, d: Vector2) -> void:
	var length: float = mi.get_meta("len", 2.0)
	mi.global_position = at + Vector3(d.x, 0, d.y) * (length * 0.5) + Vector3(0, 0.07, 0)
	mi.rotation = Vector3(0, atan2(-d.x, -d.y), 0)

func telegraph_progress(mi: Node3D, p: float) -> void:
	(mi as MeshInstance3D).material_override.set_shader_parameter("progress", clampf(p, 0.0, 1.0))

func end_telegraph(mi: Node3D) -> void:
	teles.erase(mi)
	mi.queue_free()

func _process(delta: float) -> void:
	for n in nums.duplicate():
		n["t"] += delta
		var l: Label3D = n["node"]
		if n.has("last"):
			# a damage number: rides on the target while hits keep landing, then lifts off and fades
			n["last"] += delta
			var lt: float = n["last"]
			var base: Vector3 = n["base"]
			var rise := minf(float(n["t"]), 0.25) * 1.6
			if lt < STICK_T:
				l.global_position = l.global_position.lerp(base + n["off"] + Vector3(0, 0.25 + rise, 0), minf(1.0, delta * 18.0))
			else:
				n["vel"].y -= 5.0 * delta
				l.global_position += n["vel"] * delta
			l.scale = Vector3.ONE * lerpf(l.scale.x, 1.0, minf(1.0, delta * 14.0))
			var fade := lt - STICK_T
			l.modulate.a = clampf(1.0 - fade * 2.4, 0.0, 1.0)
			if fade > 0.45:
				l.visible = false
				nums.erase(n)
			continue
		n["vel"].y -= 9.0 * delta
		l.global_position += n["vel"] * delta
		var k: float = n["t"]
		l.scale = Vector3.ONE * lerpf(l.scale.x, 1.0, minf(1.0, delta * 12.0))
		l.modulate.a = clampf(1.6 - k * 2.2, 0.0, 1.0)
		if k > 0.75:
			l.visible = false
			nums.erase(n)
	for rg in rings.duplicate():
		rg["t"] += delta
		var k: float = rg["t"] / rg["dur"]
		var mi: MeshInstance3D = rg["node"]
		mi.scale = Vector3.ONE * lerpf(0.2, rg["r"], 1.0 - pow(1.0 - minf(k, 1.0), 3.0))
		mi.material_override.set_shader_parameter("color", Color(rg["col"], clampf(1.0 - k, 0.0, 1.0)))
		if k >= 1.0:
			mi.queue_free(); rings.erase(rg)
	for f in flashes.duplicate():
		f["t"] += delta
		var mi: MeshInstance3D = f["node"]
		var fk: float = f["t"] / f["dur"]
		mi.scale = Vector3.ONE * float(f.get("s0", 1.0)) * (1.0 + fk * 0.6)
		(mi.material_override as ShaderMaterial).set_shader_parameter("life", clampf(fk, 0.0, 1.0))
		if f["t"] >= f["dur"]:
			mi.visible = false; flashes.erase(f)
	for g in ghosts.duplicate():
		g["t"] += delta
		var k: float = g["t"] / 0.26
		var gm: MeshInstance3D = g["node"]
		gm.material_override.set_shader_parameter("color", Color(g["col"], 0.55 * (1.0 - k)))
		gm.scale *= 1.0 - delta * 1.5
		if k >= 1.0:
			gm.queue_free(); ghosts.erase(g)
	for ln in lines.duplicate():
		ln["t"] += delta
		if ln["t"] >= ln["dur"]:
			ln["node"].queue_free(); lines.erase(ln)
