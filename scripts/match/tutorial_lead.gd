class_name TutorialLead
extends RefCounted
## The match tutorial's lead (DECISIONS Nov 3: "your Boki physically leads"): on a step with a lead goal
## (Tutorial._lead_goal: the glowing pad before a gap, or the way out) your Boki runs on ahead to it, waits when
## you fall more than `wait_m` behind, stops `stop_m` from the goal and turns to look back at you. A Boki that
## rides as a wisp does the same in the air (a look only: its carry stays on you). The distances are
## content/rules/tutorial.json "lead"; the farm's twin is BaseTutLead. It is a nudge on the steps that already
## have a marker: no new HUD, toast or arrow.


static func rules() -> Dictionary:
	return Content.rules("tutorial")["lead"]


## Where this Boki leads to now: the lead goal of the step it was told about, else Vector3.INF.
static func goal(k: Kin) -> Vector3:
	if k.comp == null or k.owner_h == null or k.dead or (k.cmd != "follow" and not k.wisp):
		return Vector3.INF
	var to = k.comp.guide.get("to", Vector3.INF)
	return to if to is Vector3 else Vector3.INF


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## You have run past it (nearer the goal by more than 2 m): it stops leading and falls in beside you.
static func passed(at: Vector3, you: Vector3, to: Vector3) -> bool:
	return _flat(you, to) + 2.0 < _flat(at, to)


## Does the walking Boki lead right now? Not once you have run past it (it falls in beside you), and not for
## off_s after it stood stalled for stall_s trying to (an edge or a wall on the straight way): it rejoins you
## along your own way and then leads again.
static func on(k: Kin, to: Vector3, dt: float) -> bool:
	var c := k.comp
	c.lead_off = maxf(0.0, c.lead_off - dt)
	if c.lead_off > 0.0 or passed(k.pos, k.owner_h.pos, to):
		c.lead_stall = 0.0
		return false
	var moving := Vector2(k.vel.x, k.vel.z).length() > 0.5
	c.lead_stall = 0.0 if moving or c.lead_hold or not k.grounded else c.lead_stall + dt
	if c.lead_stall >= float(rules()["stall_s"]):
		c.lead_stall = 0.0
		c.lead_off = float(rules()["off_s"])
		k.path = []  # (a failed search for the far goal backs off: search for the way to you now)
		k.path_t = 0.0
		return false
	return true


## Stands and waits: it has arrived, or you are further behind than wait_m.
static func holds(at: Vector3, you: Vector3, to: Vector3) -> bool:
	return _flat(at, to) < float(rules()["stop_m"]) or _flat(at, you) > float(rules()["wait_m"])


## Turns to look back at you (the walking Boki's body yaw).
static func look_back(k: Kin, dt: float) -> void:
	var d := Vector2(k.owner_h.pos.x - k.pos.x, k.owner_h.pos.z - k.pos.z)
	if d.length() > 0.1:
		k.face = lerp_angle(k.face, atan2(-d.x, -d.y), minf(1.0, dt * 8.0))


## One sim step of a wisp's lead: it floats on toward the goal (comp.lead_pos, a spot in the air above the
## ground) while you keep up, holds and looks back when it must wait, and comes home to your shoulder when the
## step has no lead goal. The wisp's logical place stays on you.
static func wisp_step(k: Kin, dt: float) -> void:
	var o := k.owner_h
	var c := k.comp
	var to := goal(k)
	if c == null or o == null or (to == Vector3.INF and c.lead_pos == Vector3.INF):
		return
	if c.lead_pos == Vector3.INF:
		c.lead_pos = o.pos
	if to != Vector3.INF and passed(c.lead_pos, o.pos, to):
		c.lead_pos = Vector3.INF  # you have run past it: it drops back onto your shoulder
		return
	var home := to == Vector3.INF
	var dest: Vector3 = o.pos if home else to
	if not home and holds(c.lead_pos, o.pos, to):
		var d := Vector2(o.pos.x - c.lead_pos.x, o.pos.z - c.lead_pos.z)
		if d.length() > 0.1:
			k.face = lerp_angle(k.face, atan2(-d.x, -d.y), minf(1.0, dt * 8.0))
	else:
		var step := Vector2(dest.x - c.lead_pos.x, dest.z - c.lead_pos.z)
		var go := minf(step.length(), float(rules()["wisp_speed"]) * dt)
		if step.length() > 0.001:
			step = step.normalized() * go
		c.lead_pos.x += step.x
		c.lead_pos.z += step.y
		if step.length() > 0.01:
			k.face = lerp_angle(k.face, atan2(-step.x, -step.y), minf(1.0, dt * 8.0))
	var g: float = k.m.world.ground_at(c.lead_pos.x, c.lead_pos.z)
	c.lead_pos.y = o.pos.y if g <= World.VOID + 1.0 else g
	if home and _flat(c.lead_pos, o.pos) < 0.8:
		c.lead_pos = Vector3.INF
