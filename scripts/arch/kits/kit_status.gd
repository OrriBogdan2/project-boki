class_name KitStatus
extends RefCounted
## Short statuses that hero kits put on hunters, with a look every game shows:
##   "grounded"  no dashing (Vireo's Skycall pins you down); chains of light at the feet
##   "rattled"   slowed, and Marlowe's rifle and Longneedle hit harder (her Burr Charge); stars over the head
## The game that owns the body runs the rules; every game shows the look. Net event
## ["kst", nid, kind, seconds] (seconds 0 clears it), Net.VERSION 0.6.1.

const COL := {"grounded": Color("9ff5e0"), "rattled": Color("ffcf6a")}
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
	if h.out or h.downed:
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
static func hides_model(_h: Ent) -> bool:
	return false

## Every step (rules) and every frame (looks), on every hunter.
static func tick(h: Hunter, dt: float, look := false) -> void:
	if h.m == null:
		return
	for kind in ["grounded", "rattled"]:
		var on := active(h, kind)
		if not look:
			continue
		var node_name := "Kst_" + kind
		var n: Node3D = h.get_node_or_null(node_name)
		if not on or h.downed or h.out:
			if n:
				n.name = node_name + "_gone"
				n.queue_free()
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
