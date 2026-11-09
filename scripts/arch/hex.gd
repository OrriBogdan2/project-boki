class_name Hex
extends RefCounted
## The Mage's Hex (docs/ARCHETYPES.md, Kit loops): a hunter turned into a harmless little critter for
## a moment. It can still walk (at half speed) but can't attack, cast, dash, use gloves or glide. The
## game that owns the body runs the rules; every game shows the swap (Net event "hex", Net.VERSION 0.5.0).

const SPEED_K := 0.5

static func active(h: Ent) -> bool:
	return h != null and is_instance_valid(h) and h.has_meta("hex_until") and float(h.m.time) < float(h.get_meta("hex_until"))

## Hex `h` for `dur` seconds (refreshes a running one). `send`: tell the other games.
static func apply(h: Hunter, dur: float, send := true) -> void:
	if h == null or not is_instance_valid(h) or h.downed or h.out or dur <= 0.0:
		return
	var m: Node = h.m
	var was := active(h)
	h.set_meta("hex_until", maxf(float(h.get_meta("hex_until", 0.0)), float(m.time) + dur))
	if not h.remote:
		h.gliding = false
		h.mel_hold = 0.0; h.draw_t = -1.0; h.warm_t = 0.0
		if h.ak and h.ak.rmb_down: h.ak.rmb_down = false
	if not was:
		_swap(h, true)
		m.fx.burst(h.pos + Vector3(0, 0.8, 0), Color("e2b8ff"), 26, 4.0, 0.5, -1.0, 1.3)
		m.fx.ring(h.pos, 1.4, Color("c46bff"), 0.3)
		m.fx.word(h.pos + Vector3(0, 2.2, 0), "HEXED", Color("e2b8ff"), true)
		m.sfx("portal", h.pos, -2.0, 1.6)
		m.sfx("kin_unsure", h.pos, -4.0, 1.6)
		if h == m.get("player") and m.hud: m.hud.toast_small("HEXED  ·  you can't fight for a moment", Color("e2b8ff"))
	if send and m.get("net_on") and not h.dead:
		m.net_event(["hex", h.nid, snappedf(dur, 0.01)])

## Every frame, on every hunter: run out the hex, keep the rules, animate the critter.
static func tick(h: Hunter, _dt: float) -> void:
	if not h.has_meta("hex_until"):
		return
	if h.m == null:
		return
	if not active(h) or h.downed or h.out:
		h.remove_meta("hex_until")
		_swap(h, false)
		h.m.fx.burst(h.pos + Vector3(0, 0.8, 0), Color("e2b8ff"), 16, 3.0, 0.4, -1.0, 1.1)
		h.m.sfx("portal", h.pos, -6.0, 1.1)
		return
	if not h.remote:
		h.gliding = false
		for k in ["fire", "sec", "sig", "ult", "dash", "gear1", "gear2", "kin_ab", "tonic", "kit", "throw"]:
			if h.inp.has(k): h.inp[k] = false
		h.inp["sec_hold"] = false
	var c: Node3D = h.get_node_or_null("HexCritter")
	if c:
		c.position.y = absf(sin(float(h.m.time) * 9.0)) * 0.25      # it hops along
		c.rotation.y = h.face + PI

## The look: the hunter's model hides and a small round critter (big ears, a tail, a rune over it)
## takes its place.
static func _swap(h: Hunter, on: bool) -> void:
	if h.model: h.model.visible = not on
	var old: Node3D = h.get_node_or_null("HexCritter")
	if old:
		old.name = "HexCritterGone"
		old.queue_free()
	if not on:
		return
	var c := Node3D.new()
	c.name = "HexCritter"
	var fur := Models.toon(Color("f7c6ff"))
	Models.part(c, Models.sphere(0.36, 14), fur, Vector3(0, 0.38, 0), Vector3(1.0, 0.9, 1.1))
	Models.part(c, Models.sphere(0.22, 12), fur, Vector3(0, 0.72, -0.18))
	for sx in [-0.1, 0.1]:
		Models.part(c, Models.box(0.07, 0.3, 0.05), fur, Vector3(sx, 0.98, -0.18), Vector3.ONE, Vector3(0, 0, sx * 2.5))
		Models.part(c, Models.sphere(0.04, 6), Models.toon(Color("2b2a33")), Vector3(sx * 0.7, 0.76, -0.38))
	Models.part(c, Models.sphere(0.1, 8), fur, Vector3(0, 0.36, 0.38))
	var rune := MeshInstance3D.new()
	rune.mesh = Models.flat_quad(0.9)
	rune.material_override = Models.ring_mat(Color(Color("c46bff"), 0.9), 0.12)
	rune.position = Vector3(0, 1.35, 0)
	c.add_child(rune)
	h.add_child(c)
