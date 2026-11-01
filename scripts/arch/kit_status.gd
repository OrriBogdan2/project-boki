class_name KitStatus
extends RefCounted
## Statuses the archetype kits put on a body that a plain hit can't carry over the network (kits2):
##   gnd  Grounded (the Thief's Bola): no dash, jump or glide; the hunter's legs show the tangled cords
##   blt  Blight (the Juggernaut's Warchain, the Thief's Jackpot rim): healing on the body is cut
##   vul  Shred (the Thief's Primed shot): the body takes `k` more damage
##   dsr  Disoriented (Ostra's Swap): slowed by `k`; a DIZZY word and a teal ring
## The game that owns the body runs the rules; the caster's game sends the Net event
## ["kst", nid, kind, seconds, k] for a remote body (Net.VERSION 0.7.0), every game shows it.

const GROUND_COL := Color("d8b878")

static func grounded(e: Ent) -> bool:
	return e != null and is_instance_valid(e) and e.has_meta("gnd_until") and e.m != null and float(e.m.time) < float(e.get_meta("gnd_until"))

## Puts `kind` on `e` for `secs` (refreshes a running one). `send`: tell the other games when the
## body belongs to one of them.
static func apply(e: Ent, kind: String, secs: float, k := 0.0, send := true) -> void:
	if e == null or not is_instance_valid(e) or e.dead or secs <= 0.0:
		return
	var m: Node = e.m
	if m == null:
		return
	if e.remote:
		if send and m.get("net_on"):
			m.net_event(["kst", e.nid, kind, snappedf(secs, 0.01), snappedf(k, 0.01)])
		_show(e, kind, secs)
		return
	match kind:
		"gnd":
			var was := grounded(e)
			e.set_meta("gnd_until", maxf(float(e.get_meta("gnd_until", 0.0)), float(m.time) + secs))
			if e is Hunter:
				(e as Hunter).gliding = false
			if not was: _show(e, kind, secs)
		"blt":
			e.blight_t = maxf(e.blight_t, secs)
			e.blight_k = maxf(0.6, k) if k > 0.0 else 0.6
		"dsr":
			var was_d := e.has_meta("dsr_until") and float(m.time) < float(e.get_meta("dsr_until"))
			e.set_meta("dsr_until", maxf(float(e.get_meta("dsr_until", 0.0)), float(m.time) + secs))
			e.slow_k = maxf(e.slow_k if e.slow_t > 0.0 else 0.0, k if k > 0.0 else 0.4)
			e.slow_t = maxf(e.slow_t, secs)
			if not was_d: _show(e, kind, secs)
		"vul":
			e.vuln_k = maxf(e.vuln_k if e.vuln_t > 0.0 else 0.0, k)
			e.vuln_t = maxf(e.vuln_t, secs)
			_show(e, kind, secs)

## What everyone sees: Grounded wraps cords round the legs for its length; Shred cracks a red ring.
static func _show(e: Ent, kind: String, secs: float) -> void:
	var m: Node = e.m
	match kind:
		"gnd":
			var old := e.get_node_or_null("Grounded")
			if old: old.queue_free(); old.name = "GroundedGone"
			var n := Node3D.new()
			n.name = "Grounded"
			var mat := Models.glow_mat(Color(GROUND_COL, 0.95))
			for i in 3:
				var c := MeshInstance3D.new()
				c.mesh = Models.cyl(0.42 - 0.05 * i, 0.42 - 0.05 * i, 0.06, 16)
				c.material_override = mat
				c.position = Vector3(0, 0.22 + 0.22 * i, 0)
				c.rotation = Vector3(0.18 * (1 - i), 0.0, 0.2 * (i - 1))
				c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				n.add_child(c)
			e.add_child(n)
			m.later(secs, func(): if is_instance_valid(n): n.queue_free())
			m.fx.word(e.pos + Vector3(0, 2.0, 0), "GROUNDED", GROUND_COL, false)
			m.fx.ring(e.pos, 1.1, GROUND_COL, 0.3)
			if e == m.get("player") and m.hud: m.hud.toast_small("GROUNDED  ·  no dash, jump or glide", GROUND_COL)
		"dsr":
			m.fx.word(e.pos + Vector3(0, 2.1, 0), "DIZZY", Color("7fe0d0"), false)
			m.fx.ring(e.pos, 1.0, Color("7fe0d0"), 0.3)
		"vul":
			m.fx.word(e.pos + Vector3(0, 2.0, 0), "SHRED", Color("ff7a5a"), false)
			m.fx.ring(e.pos, 0.9, Color("ff7a5a"), 0.25)

## A Net "kst" event: the body's own game runs the rule.
static func from_net(m: Node, x: Array) -> void:
	if x.size() < 4:
		return
	var e: Ent = m.ents_by_id.get(String(x[1]), null)
	if e == null:
		return
	apply(e, String(x[2]), float(x[3]), float(x[4]) if x.size() > 4 else 0.0, false)
