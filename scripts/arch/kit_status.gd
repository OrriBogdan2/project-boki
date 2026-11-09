class_name KitStatus
extends RefCounted
## Statuses the archetype kits put on a body that a plain hit can't carry over the network (kits2):
##   gnd  Grounded (the Thief's Bola): no dash, jump or glide; cords round the legs (StatusLooks)
##   blt  Blight (the Juggernaut's Warchain, Sable's Encore rim): healing on the body is cut
##   vul  Shred (the Thief's Primed shot): the body takes `k` more damage
##   rat  Dazed (Vex's Burr Charge; "Rattled" in code): her rifle and Longneedle hit harder (no slow: the
##        source's Daze is only a damage window); a crystal ring over the head (StatusLooks)
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

## What everyone sees: the body look (StatusLooks: cords round the legs, a ring over the head) for its
## length, and a word and a ring as it lands.
static func _show(e: Ent, kind: String, secs: float, toast := "") -> void:
	var m: Node = e.m
	match kind:
		"gnd":
			_look(e, "gnd", secs)
			if toast == "":
				m.fx.word(e.pos + Vector3(0, 2.0, 0), "GROUNDED", GROUND_COL, false)
			m.fx.ring(e.pos, 1.1, GROUND_COL, 0.3)
			if e == m.get("player") and m.hud and toast != "": m.hud.toast_small("GROUNDED  ·  " + toast, GROUND_COL)
		"rat":
			_look(e, "daze", secs)
			m.fx.word(e.pos + Vector3(0, 3.3, 0), "DAZED", RATTLE_COL, false)     # clear above a STUNNED (2.2)
			m.fx.ring(e.pos, 1.1, RATTLE_COL, 0.25)
		"dsr":
			_look(e, "slow", secs)
			m.fx.word(e.pos + Vector3(0, 2.1, 0), "SLOWED", Color("b8a8ff"), false)
			m.fx.ring(e.pos, 1.0, Color("7fe0d0"), 0.3)
		"vul":
			m.fx.word(e.pos + Vector3(0, 2.0, 0), "SHRED", Color("ff7a5a"), false)
			m.fx.ring(e.pos, 0.9, Color("ff7a5a"), 0.25)

## The body look for what this game can't read off the body's own timers: a body another game owns, or one
## that isn't a Hunter (StatusLooks reads a local Hunter's timers itself, so a status cut short ends there).
static func _look(e: Ent, st: String, secs: float) -> void:
	if e.remote or not (e is Hunter):
		StatusLooks.of(e.m).put(e, st, secs)

## A Net "kst" event: the body's own game runs the rule.
static func from_net(m: Node, x: Array) -> void:
	if x.size() < 4:
		return
	var e: Ent = m.ents_by_id.get(String(x[1]), null)
	if e == null:
		return
	apply(e, String(x[2]), float(x[3]), float(x[4]) if x.size() > 4 else 0.0, false)
