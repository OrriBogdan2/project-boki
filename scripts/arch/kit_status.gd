class_name KitStatus
extends RefCounted
## Statuses the archetype kits put on a body that a plain hit can't carry over the network (kits2):
##   gnd  Grounded (the Thief's Bola): no dash, jump or glide; the hunter's legs show the tangled cords
##   blt  Blight (the Juggernaut's Warchain, Sable's Encore rim): healing on the body is cut
##   vul  Shred (the Thief's Primed shot): the body takes `k` more damage
##   rat  Dazed (Vex's Burr Charge; "Rattled" in code): her rifle and Longneedle hit harder (no slow: the
##        source's Daze is only a damage window); stars over the head
##   dsr  Disoriented (Ostra's Trade): slowed by `k`; a SLOWED word and a teal ring
## The game that owns the body runs the rules; the caster's game sends the Net event
## ["kst", nid, kind, seconds, k] for a remote body (Net.VERSION 0.7.0), every game shows it.

const GROUND_COL := Color("e0a03a")
const RATTLE_COL := Color("ffb36a")

static func rattled(e: Ent) -> bool:
	return e != null and is_instance_valid(e) and e.has_meta("rat_until") and e.m != null and float(e.m.time) < float(e.get_meta("rat_until"))

static func rattled_left(e: Ent) -> float:
	return maxf(0.0, float(e.get_meta("rat_until")) - float(e.m.time)) if rattled(e) else 0.0

static func clear_rattled(e: Ent) -> void:
	if e != null and is_instance_valid(e) and e.has_meta("rat_until"):
		e.set_meta("rat_until", 0.0)

static func grounded(e: Ent) -> bool:
	return e != null and is_instance_valid(e) and e.has_meta("gnd_until") and e.m != null and float(e.m.time) < float(e.get_meta("gnd_until"))

## Puts `kind` on `e` for `secs` (refreshes a running one). `send`: tell the other games when the
## body belongs to one of them. `toast`: the caster shows its own tell, so no overhead word, and the
## player's toast reads this instead (what Grounded takes away from a Dredge reeling, say).
static func apply(e: Ent, kind: String, secs: float, k := 0.0, send := true, toast := "") -> void:
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
			if not was: _show(e, kind, secs, toast)
		"blt":
			e.blight_t = maxf(e.blight_t, secs)
			e.blight_k = maxf(0.6, k) if k > 0.0 else 0.6
		"rat":
			var was_r := rattled(e)
			e.set_meta("rat_until", maxf(float(e.get_meta("rat_until", 0.0)), float(m.time) + secs))
			if not was_r: _show(e, kind, secs)
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
static func _show(e: Ent, kind: String, secs: float, toast := "") -> void:
	var m: Node = e.m
	match kind:
		"gnd":
			var old := e.get_node_or_null("Grounded")
			if old: old.queue_free(); old.name = "GroundedGone"
			var n := Node3D.new()
			n.name = "Grounded"
			var mat := DJFx.solid(GROUND_COL)          # solid: an additive glow washes out to white on grass
			for i in 3:
				var c := MeshInstance3D.new()
				c.mesh = Models.cyl(0.42 - 0.05 * i, 0.42 - 0.05 * i, 0.06, 16)
				c.material_override = mat
				c.position = Vector3(0, 0.22 + 0.22 * i, 0)
				c.rotation = Vector3(0.18 * (1 - i), 0.0, 0.2 * (i - 1))
				c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				n.add_child(c)
			e.add_child(n)
			m.later(secs, n.queue_free)
			if toast == "":
				m.fx.word(e.pos + Vector3(0, 2.0, 0), "GROUNDED", GROUND_COL, false)
			m.fx.ring(e.pos, 1.1, GROUND_COL, 0.3)
			if e == m.get("player") and m.hud and toast != "": m.hud.toast_small("GROUNDED  ·  " + toast, GROUND_COL)
		"rat":
			var old2 := e.get_node_or_null("Rattled")
			if old2: old2.queue_free(); old2.name = "RattledGone"
			var rn := Node3D.new()
			rn.name = "Rattled"
			var top := 2.35 * (float((e as Hunter).cdat.get("scale", 1.0)) if e is Hunter else 0.8)
			var rmat := Models.glow_mat(Color(RATTLE_COL, 1.0))
			for i in 4:
				var st := MeshInstance3D.new()
				st.mesh = Models.crystal(0.07, 0.1, 4)
				st.material_override = rmat
				st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var a := TAU * i / 4.0
				st.position = Vector3(cos(a) * 0.38, top, sin(a) * 0.38)
				rn.add_child(st)
			e.add_child(rn)
			m.later(secs, rn.queue_free)
			m.fx.word(e.pos + Vector3(0, 3.3, 0), "DAZED", RATTLE_COL, false)     # clear above a STUNNED (2.2)
			m.fx.ring(e.pos, 1.1, RATTLE_COL, 0.25)
		"dsr":
			m.fx.word(e.pos + Vector3(0, 2.1, 0), "SLOWED", Color("b8a8ff"), false)
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
