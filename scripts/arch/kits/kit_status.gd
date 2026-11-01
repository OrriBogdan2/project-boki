class_name KitStatus
extends RefCounted
## Short statuses that hero kits put on hunters, with a look every game shows:
##   "grounded"  no dashing (Vireo's Skycall pins you to the ground); chains of light at the feet
##   "rattled"   slowed, and Marlowe's rifle and Rail hit harder (her Burr charge); stars over the head
##   "cloud"     Vireo riding Skybreak: the body is hidden and a thundercloud drifts where it is,
##               weapon shots pass through
## The game that owns the body runs the rules; every game shows the look. Net event
## ["kst", nid, kind, seconds] (seconds 0 clears it), Net.VERSION 0.6.1.

const COL := {"grounded": Color("9ff5e0"), "rattled": Color("ffcf6a"), "cloud": Color("7af0ff")}
const WORD := {"grounded": "GROUNDED", "rattled": "RATTLED"}
const RATTLE_SLOW := 0.35

static func _key(kind: String) -> String:
	return "kst_" + kind

static func active(h: Ent, kind: String) -> bool:
	if h == null or not is_instance_valid(h) or h.m == null or not h.has_meta(_key(kind)):
		return false
	return float(h.m.time) < float(h.get_meta(_key(kind)))

static func left(h: Ent, kind: String) -> float:
	if not active(h, kind):
		return 0.0
	return float(h.get_meta(_key(kind))) - float(h.m.time)

## Put `kind` on `h` for `dur` seconds (a running one is extended, never shortened); 0 clears it.
## `send`: tell the other games.
static func apply(h: Hunter, kind: String, dur: float, send := true) -> void:
	if h == null or not is_instance_valid(h) or h.m == null:
		return
	var m: Node = h.m
	if dur <= 0.0:
		if h.has_meta(_key(kind)):
			h.set_meta(_key(kind), 0.0)
			if send and m.get("net_on"): m.net_event(["kst", h.nid, kind, 0.0])
		return
	if h.out or (h.downed and kind != "cloud"):
		return
	var was := active(h, kind)
	h.set_meta(_key(kind), maxf(float(h.get_meta(_key(kind), 0.0)), float(m.time) + dur))
	if not h.remote and kind == "rattled":
		h.slow_k = maxf(h.slow_k if h.slow_t > 0.0 else 0.0, RATTLE_SLOW)
		h.slow_t = maxf(h.slow_t, dur)
	if not was and WORD.has(kind):
		m.fx.word(h.pos + Vector3(0, 2.3, 0), String(WORD[kind]), COL[kind], false)
		m.fx.ring(h.pos, 1.1, COL[kind], 0.25)
		if h == m.get("player") and m.hud:
			m.hud.toast_small({"grounded": "GROUNDED  ·  no dashing for a moment", "rattled": "RATTLED  ·  slowed, and her shots hit harder"}[kind], COL[kind])
	if send and m.get("net_on") and not h.dead:
		m.net_event(["kst", h.nid, kind, snappedf(dur, 0.01)])

static func clear(h: Hunter, kind: String, send := true) -> void:
	apply(h, kind, 0.0, send)

## The body is drawn as something else right now (Hunter.render hides the model).
static func hides_model(h: Ent) -> bool:
	return active(h, "cloud")

## Every step (rules) and every frame (looks), on every hunter.
static func tick(h: Hunter, dt: float, look := false) -> void:
	if h.m == null:
		return
	for kind in ["grounded", "rattled", "cloud"]:
		var on := active(h, kind)
		if not look:
			if on and kind == "cloud":
				h.phase_t = maxf(h.phase_t, 0.08)      # weapon shots pass through the cloud
			continue
		var node_name := "Kst_" + kind
		var n: Node3D = h.get_node_or_null(node_name)
		if not on or h.downed or h.out:
			if n:
				n.name = node_name + "_gone"
				n.queue_free()
				if kind == "cloud": h.m.fx.burst(h.pos + Vector3(0, 2.0, 0), COL[kind], 18, 4.0, 0.4, 6.0, 1.2)
			continue
		if n == null:
			n = _build(h, kind)
		_animate(h, kind, n, dt)

static func _build(h: Hunter, kind: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Kst_" + kind
	var col: Color = COL[kind]
	match kind:
		"grounded":
			# three short chains of light from the ankles down into the ground
			for i in 3:
				var a := TAU * i / 3.0
				var ch := MeshInstance3D.new()
				ch.mesh = Models.cyl(0.03, 0.03, 0.55, 6)
				ch.material_override = Models.glow_mat(Color(col, 0.85))
				ch.position = Vector3(cos(a) * 0.32, 0.18, sin(a) * 0.32)
				ch.rotation = Vector3(sin(a) * 0.6, 0, -cos(a) * 0.6)
				ch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				n.add_child(ch)
			var ring := MeshInstance3D.new()
			ring.mesh = Models.flat_quad(1.3)
			ring.material_override = Models.ring_mat(Color(col, 0.9), 0.1)
			ring.position.y = 0.06
			n.add_child(ring)
		"rattled":
			# small brass stars wheeling over the head
			for i in 4:
				var s := MeshInstance3D.new()
				s.mesh = Models.crystal(0.07, 0.1, 4)
				s.material_override = Models.glow_mat(Color(col, 1.0))
				s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				n.add_child(s)
		"cloud":
			# a squat thundercloud of lumpy puffs with a lit belly, and a dark shadow ring on the ground
			var puff := Models.glow_mat(Color(Color("2c3a4a"), 0.92))
			var belly := Models.glow_mat(Color(col, 0.55))
			var spots := [Vector3(0, 0, 0), Vector3(0.55, -0.05, 0.1), Vector3(-0.5, -0.02, -0.12), Vector3(0.1, 0.18, -0.3), Vector3(-0.15, 0.12, 0.35), Vector3(0.35, 0.05, -0.4)]
			for i in spots.size():
				var p := MeshInstance3D.new()
				p.mesh = Models.sphere(0.42 + 0.08 * (i % 3), 12)
				p.material_override = puff
				p.position = spots[i] + Vector3(0, 2.6, 0)
				p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				n.add_child(p)
			var lit := MeshInstance3D.new()
			lit.name = "Belly"
			lit.mesh = Models.sphere(0.6, 12)
			lit.scale = Vector3(1.6, 0.35, 1.3)
			lit.material_override = belly
			lit.position = Vector3(0, 2.35, 0)
			n.add_child(lit)
			var sh := MeshInstance3D.new()
			sh.mesh = Models.flat_quad(2.2)
			sh.material_override = Models.ring_mat(Color(col, 0.7), 0.3)
			sh.position.y = 0.06
			n.add_child(sh)
			var lt := OmniLight3D.new()
			lt.name = "Light"
			lt.light_color = col
			lt.omni_range = 4.0
			lt.position = Vector3(0, 2.0, 0)
			n.add_child(lt)
	h.add_child(n)
	return n

static func _animate(h: Hunter, kind: String, n: Node3D, _dt: float) -> void:
	var t: float = h.m.time
	match kind:
		"grounded":
			n.rotation.y = t * 1.5
			n.visible = h.visible
		"rattled":
			var top := 2.35 * float(h.cdat.get("scale", 1.0))
			for i in n.get_child_count():
				var a := t * 5.0 + TAU * i / float(n.get_child_count())
				(n.get_child(i) as Node3D).position = Vector3(cos(a) * 0.38, top + 0.08 * sin(t * 9.0 + i), sin(a) * 0.38)
				(n.get_child(i) as Node3D).rotation = Vector3(t * 6.0, t * 4.0, 0)
		"cloud":
			n.rotation.y = t * 0.6
			n.position.y = 0.15 * sin(t * 2.2)
			var lt := n.get_node_or_null("Light") as OmniLight3D
			var flick := 1.0 if int(t * 13.0) % 7 == 0 else 0.0
			if lt: lt.light_energy = 0.6 + 2.2 * flick
			if flick > 0.0 and int(t * 60.0) % 2 == 0:
				var gp := h.position + Vector3(randf_range(-0.6, 0.6), 0.05, randf_range(-0.6, 0.6))
				h.m.fx.bolt(h.position + Vector3(0, 2.3, 0), gp, COL[kind])
