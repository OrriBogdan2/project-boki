class_name LairsLock
extends RefCounted
## Seal, gate, victory window, alerts and updraft for Lairs.

var ls: Lairs
var m: Match

func _init(l: Lairs) -> void:
	ls = l
	m = l.m

## Something loud happened at a lair: a ping and a feed line for everyone close enough to hear it, a
## sound ping on the minimap, and nearby bots come and look.
func _loud(L: Dictionary, at: Vector3, by: Hunter, text: String) -> void:
	m.note_sound(by, at, "boom")
	for o in m.hunters:
		if o.out or o.extracted or o == by:
			continue
		var d: float = o.flat_dist(at)
		if d > 60.0:
			continue
		if o == m.player:
			m.ping(at, Lairs.color_of(L))
			m.add_feed(text)
		elif o.ctrl == "bot" and o.team != by.team and d < 45.0 and randf() < 0.35:
			o.ai["wander"] = at

func _call_guards(L: Dictionary, at: Vector3, n: int) -> void:
	if m.net_on and not m.is_host:
		return
	var room := Lairs.GUARD_CAP - ls._guards_alive(L)
	var pool: Array = ["skitter", "skitter", "spitter", "bomber"] + (["brute"] if m.tier >= 1 else [])
	for i in mini(n, room):
		var a := randf() * TAU
		var p: Vector3 = at + Vector3(cos(a), 0, sin(a)) * randf_range(2.5, 4.5)
		if m.world.is_void(p.x, p.z) or m.world.is_block(p.x, p.z) or ls.inside(L, p, 0.5):
			p = at + Vector3(L["out"].x, 0, L["out"].y) * 2.5
		var g := m.spawn_mob(String(pool[randi() % pool.size()]), Vector3(p.x, m.world.ground_at(p.x, p.z), p.z))
		g.camp = at
		g.st = "chase"
		g.tgt = L["user"] if L["user"] != null else null
		m.fx.burst(g.pos + Vector3(0, 0.5, 0), Color("c9a0ff"), 14, 3.0, 0.5, -2.0)
		L["guards"].append(g)

## The boss is dead and its gate still shut: VICTORY_T on the clock, the lever lit, the updraft
## blowing at the back. Everyone near hears it fall (a different cry from the fight's roar) and their
## ping on the lair turns to "fallen", so whoever is camping the gate knows the clock is running.
func _victory(L: Dictionary, b: Boss) -> void:
	L["victory"] = true
	L["victory_at"] = m.time
	L["flown"] = []
	var lvn: Node3D = L["nodes"]["lever"]
	if is_instance_valid(lvn): lvn.get_node("Lit").visible = true
	_set_updraft(L, true)
	var bn: String = b.md["name"] if b else "The boss"
	var ins: Array = L.get("sealed_in", [])
	if m.player and m.hud and ins.has(m.player):
		m.hud.toast("VICTORY  ·  PULL THE LEVER BY THE GATE, OR RIDE THE UPDRAFT OUT THE BACK", Lairs.color_of(L))
	_alert(L, "fallen", "%s has fallen at %s" % [bn, L["name"]])

## Shout a lair's news to everyone outside within ALERT_R: a spatial cry from the lair, a ping with
## the boss's icon on the minimap and full map, a toast. kind: "fight" (it woke and sealed) or "fallen".
func _alert(L: Dictionary, kind: String, text: String) -> void:
	L["alert"] = kind
	L["alert_text"] = text
	L["alert_at"] = m.time
	var c: Vector3 = L["c"]
	var ins: Array = L.get("sealed_in", [])
	var heard: Dictionary = L["heard"]
	var near_any := false
	for o in m.hunters:
		if o.out or o.extracted or ins.has(o) or (L.get("flown", []) as Array).has(o):
			continue
		if o.flat_dist(c) > Lairs.ALERT_R:
			continue
		near_any = true
		heard[o.nid] = m.time
		ls.alert_log.append({"lair": L["id"], "kind": kind, "nid": o.nid})
		if o == m.player:
			m.ping(c, Lairs.color_of(L))
			m.add_feed(text)
			if m.hud: m.hud.toast(text.to_upper() if kind == "fallen" else text, Lairs.color_of(L) if kind == "fight" else Color("ffd36a"))
		elif o.ctrl == "bot" and kind == "fight":
			o.ai.erase("camp_" + String(L["id"]))      # (a fresh fight: think again about camping it)
	if near_any or (m.player and ins.has(m.player)):
		# the cry carries: spatial, loud, from the lair itself
		if kind == "fight":
			m.sfx("v_warden", c, 10.0, 0.42)
			m.sfx("horn", c, 8.0, 0.5)
			m.sfx("boom", c, 4.0, 0.35)
		else:
			m.sfx("horn", c, 9.0, 0.95)
			m.sfx("die_big_1", c, 8.0, 0.55)
			m.sfx("unlock", c, 6.0, 0.6)
	m.note_sound(null, c, "boom")
	var beam: Node3D = L["nodes"].get("beam")
	if is_instance_valid(beam):
		beam.visible = true
		var gold := kind == "fallen"
		for nm in ["Shaft", "Core"]:
			var mi: MeshInstance3D = beam.get_node(nm)
			var base: Color = Color("ffd36a") if gold else Lairs.color_of(L)
			(mi.material_override as ShaderMaterial).set_shader_parameter("color", Color(base.lightened(0.5 if nm == "Core" else 0.0), 0.55 if nm == "Core" else 0.3))

## Did this hunter hear the lair's fight (or its boss fall) and is it still news?
func alerted(L: Dictionary, h: Hunter) -> bool:
	return h != null and (L["heard"] as Dictionary).has(h.nid) and alert_on(L)

## A lair's alert holds while its seal does, and a few seconds after.
func alert_on(L: Dictionary) -> bool:
	return String(L.get("alert", "")) != "" and (L.get("locked", false) or m.time - float(L.get("unlock_at", -99.0)) < 8.0)

## The lever was pulled (or the clock ran out): the gate opens, the updraft dies down.
func _victory_open(L: Dictionary, by: Hunter) -> void:
	if not L.get("victory", false):
		return
	L["victory"] = false
	var lvn: Node3D = L["nodes"]["lever"]
	if is_instance_valid(lvn):
		lvn.get_node("Lit").visible = false
		var arm: Node3D = lvn.get_node("Arm")
		var tw := m.create_tween()
		tw.tween_property(arm, "rotation:x", 0.75, 0.25).set_trans(Tween.TRANS_BACK)
	_set_updraft(L, false)
	if by:
		by.set_hold("lever", 0.9)
		m.sfx("click", L["lever"], 4.0, 0.6)
		m.sfx("unlock", L["lever"], 2.0, 0.8)
		m.fx.burst(L["lever"] + Vector3(0, 1.6, 0), Lairs.color_of(L), 18, 3.5, 0.5, -2.0)
		m.add_feed("%s pulled the lever: %s's gate opens" % [by.pname, L["name"]])
	else:
		m.add_feed("%s's gate grinds open" % L["name"])
	L["opened_by_lever"] = by.pname if by else ""
	unlock(L)

func _set_updraft(L: Dictionary, on: bool) -> void:
	L["up_on"] = on
	var vn: Node3D = L["nodes"].get("vent")
	if is_instance_valid(vn):
		vn.get_node("Air").visible = on
		vn.get_node("Ring").visible = on
	if on:
		m.sfx("glide", L["up"], 4.0, 0.6)
		m.fx.burst(L["up"] + Vector3(0, 0.6, 0), Color(1, 1, 1), 26, 6.0, 0.6, 6.0, 1.0, Vector3.UP, 20.0)

## The column of light is 12 m tall and stands at the back of the lair, right where the camera looks
## over it at anyone who has just landed beyond the back wall: it washed the whole view out in a white
## haze. Hidden from your view while you're outside the lair on its far side (the side the updraft
## throws you to), shown again as soon as you're back in or round the front. Purely visual.
func _updraft_view(L: Dictionary) -> void:
	var vn: Node3D = L["nodes"].get("vent")
	if not is_instance_valid(vn) or m.player == null or m.cam == null:
		return
	var air: Node3D = vn.get_node("Air")
	var p: Hunter = m.player
	var u: Vector3 = L["up"]
	var behind := false
	if not ls.inside(L, p.pos, 0.0) and not (p.auto_glide and (L["flown"] as Array).has(p)):
		# from the camera, the column sits between you and the lens: you're further from the camera
		# than the column is (along the camera's look on the ground) and not far off to its side
		var fwd := -m.cam.global_basis.z
		var f2 := Vector2(fwd.x, fwd.z).normalized()
		var rel := Vector2(p.pos.x - u.x, p.pos.z - u.z)
		behind = rel.dot(f2) > 0.0 and absf(rel.cross(f2)) < float(L["half"]) + 4.0 and rel.length() < float(L["half"]) * 2.0 + 10.0
	air.visible = not behind

## Out of the column the updraft's glide carries you on to the landing spot beyond the wall and sets
## you down there; steer (or take the glide key) and you fly yourself instead.
func _tick_flyers(L: Dictionary) -> void:
	var land: Vector3 = L["up_land"]
	var u: Vector3 = L["up"]
	var flown: Array = L["flown"]
	for h in flown.duplicate():
		if not is_instance_valid(h) or h.out or h.grounded and not h.auto_glide:
			if not L.get("up_on", false): flown.erase(h)
			continue
		if not h.auto_glide or h.remote:
			continue
		if Vector2(h.pos.x - u.x, h.pos.z - u.z).length() < Lairs.UP_R + 0.4 and h.pos.y < u.y + Lairs.UP_TOP - 0.6:
			continue      # (still in the column)
		var to := Vector2(land.x - h.pos.x, land.z - h.pos.z)
		var steering: bool = h.ctrl != "bot" and (h.inp.get("move", Vector2.ZERO) as Vector2).length() > 0.2
		if not steering:
			var want := to.normalized() * minf(Lairs.UP_PUSH, maxf(1.5, to.length() * 1.4)) if to.length() > 0.05 else Vector2.ZERO
			h.vel.x = want.x; h.vel.z = want.y
		if not ls.inside(L, h.pos, 1.0) and not m.world.is_void(h.pos.x, h.pos.z) and to.length() < (2.5 if not steering else 0.0):
			h.auto_glide = false      # over the landing: fold the glider and drop onto it

## Seconds until the gate opens on its own after the kill.
func victory_left(L: Dictionary) -> float:
	return maxf(0.0, Lairs.VICTORY_T - (m.time - float(L.get("victory_at", m.time))))

## Is this hunter allowed on the lair's escape updraft (sealed in for the fight, or already on it)?
func may_fly(L: Dictionary, h: Hunter) -> bool:
	# (once over the wall and out, it's one ride: drop back into the column and it won't lift you again)
	if (L.get("escaped", []) as Array).has(h):
		return false
	return (L.get("sealed_in", []) as Array).has(h) or (L.get("flown", []) as Array).has(h)

## The escape updraft: those who fought step into it and it lifts them high over the lair, then
## throws them out on the glider toward up_land, over the back wall. Anyone else is shoved off it.
func _tick_updraft(L: Dictionary, dt: float) -> void:
	if not L.get("up_on", false):
		return
	var u: Vector3 = L["up"]
	var land: Vector3 = L["up_land"]
	var top := u.y + Lairs.UP_TOP
	_updraft_view(L)
	for h in m.hunters:
		if h.out or h.extracted or h.remote or h.riding or h.dropping or h.downed:
			continue
		var rel := Vector2(h.pos.x - u.x, h.pos.z - u.z)
		if rel.length() > Lairs.UP_R + h.r * 0.5 or h.pos.y > top + 1.5 or h.pos.y < u.y - 1.0:
			continue
		if not may_fly(L, h):
			# not one of those who fought: it won't carry you, it shoves you off
			var pd := rel.normalized() if rel.length() > 0.05 else Vector2(L["out"].x, L["out"].y)
			h.vel.x = pd.x * 5.0; h.vel.z = pd.y * 5.0
			if h.vel.y > 0.0: h.vel.y = 0.0
			if h == m.player and m.hud and m.time - float(ls._told.get("up", -9.0)) > 2.5:
				ls._told["up"] = m.time
				m.hud.toast("The updraft only carries those who fought", Lairs.color_of(L))
			continue
		if not (L["flown"] as Array).has(h):
			(L["flown"] as Array).append(h)
			h.auto_glide = true
			h.glide_cd = 0.0
			h.glide_fuel = maxf(h.glide_fuel, 0.8)
			m.sfx("glide", h.pos, 2.0, 1.2)
			m.fx.burst(h.pos + Vector3(0, 0.5, 0), Color(1, 1, 1), 18, 5.0, 0.5, 6.0, 1.0, Vector3.UP, 25.0)
			if h == m.player and m.hud: m.hud.toast_small("Riding the updraft out", Lairs.color_of(L))
		h.grounded = false
		h.pad = {}
		if h.pos.y < top - 0.6:
			# up the column, drawn to its middle
			h.vel.y = maxf(h.vel.y, 11.0)
			h.vel.x = lerpf(h.vel.x, -rel.x * 3.0, 1.0 - exp(-6.0 * dt))
			h.vel.z = lerpf(h.vel.z, -rel.y * 3.0, 1.0 - exp(-6.0 * dt))
		else:
			# at the top: out over the wall
			var to := Vector2(land.x - h.pos.x, land.z - h.pos.z)
			var d := to.normalized() if to.length() > 0.1 else Vector2(-L["out"].x, -L["out"].y)
			h.vel = Vector3(d.x * Lairs.UP_PUSH, maxf(h.vel.y, 1.0), d.y * Lairs.UP_PUSH)
	_tick_flyers(L)
	# whoever has flown out over the wall is free of the seal
	var ins: Array = L.get("sealed_in", [])
	for h in (L["flown"] as Array):
		if is_instance_valid(h) and ins.has(h) and not ls.inside(L, h.pos, 0.3):
			ins.erase(h)
			if not L.has("escaped"): L["escaped"] = []
			(L["escaped"] as Array).append(h)
			m.add_feed("%s rode the updraft out of %s" % [h.pname, L["name"]])

## While a lair is sealed, its ward keeps everything out: walking, gliding or being thrown in bounces.
func _tick_seal(L: Dictionary, dt: float) -> void:
	if not L["state"] in ["sealed", "dormant"]:
		return
	var bodies: Array = []
	for h in m.hunters:
		if not h.out and not h.extracted and not h.riding: bodies.append(h)
	for k in m.kins:
		if not k.dead and k.state in ["active", "flying", "returning", "wild", "dazed"]: bodies.append(k)
	for mb in m.mobs:
		if not mb.dead and not (mb is Boss): bodies.append(mb)
	for e in bodies:
		if not ls.inside(L, e.pos, 0.25):
			continue
		# hunters still dropping in from the skyship, and anyone flying high over the walls, pass over;
		# whoever comes down inside (or walks, glides or is thrown in low) is put back out
		if e is Hunter and (e as Hunter).dropping:
			continue
		if not e.grounded and e.pos.y > float(L["c"].y) + 3.6:
			continue
		_push_out(L, e)
		if e == m.player and m.hud and m.time - float(ls._told.get("seal", -9.0)) > 3.0:
			ls._told["seal"] = m.time
			m.hud.toast(("%s is sealed. Open its gate first" if L["state"] == "sealed" else "%s lies dormant this time. Its gate is rusted shut") % L["name"], Lairs.color_of(L))
			m.sfx("shield", e.pos, -4.0, 1.4)

## Puts someone just outside a lair's walls, out the nearest side (or by the dial), set down still.
func _push_out(L: Dictionary, e: Ent) -> void:
	var c: Vector3 = L["c"]
	var hf := float(L["half"]) - 0.5
	var dx: float = e.pos.x - c.x; var dz: float = e.pos.z - c.z
	var push := Vector2(signf(dx) if dx != 0.0 else 1.0, 0) if absf(dx) > absf(dz) else Vector2(0, signf(dz) if dz != 0.0 else 1.0)
	var to: Vector3 = e.pos
	if push.x != 0.0: to.x = c.x + push.x * (hf + 1.6)
	else: to.z = c.z + push.y * (hf + 1.6)
	to = m.world.free_spot_near(to, [], 0.6, e.r, 4.0)
	if m.world.is_void(to.x, to.z) or m.world.is_block(to.x, to.z) or ls.inside(L, to, 0.6):
		to = L["dial"]
	e.pos = Vector3(to.x, maxf(e.pos.y, m.world.ground_at(to.x, to.z)), to.z); e.prev = e.pos
	# set down just outside, still: a shove here could carry someone off the island's edge
	if e.grounded or e.pos.y <= m.world.ground_at(to.x, to.z) + 0.05:
		e.vel = Vector3.ZERO
		e.pos.y = m.world.ground_at(to.x, to.z); e.prev = e.pos
	else:
		e.vel = Vector3(push.x * 2.0, maxf(e.vel.y, 1.5), push.y * 2.0)
	if e is Kin and (e as Kin).state == "flying": (e as Kin).state = "returning"
	m.fx.burst(e.pos + Vector3(0, 1.0, 0), Lairs.color_of(L), 12, 3.0, 0.4, -2.0)

# ------------------------------------------------------------------ sealed in with the boss
## The boss woke with someone inside: the gate shuts behind them and the ward lights up. Whoever is
## in stays in; whoever is out stays out. Anyone standing in the gateway is put outside first, so
## nobody is left inside the gate's stones.
func lock_in(L: Dictionary) -> void:
	if L.get("locked", false) or L["state"] != "awake":
		return
	var ins: Array = []
	for h in m.hunters:
		if not h.out and not h.extracted and not h.riding and not h.dropping and ls.inside(L, h.pos, 0.25):
			ins.append(h)
	if ins.is_empty():
		return
	L["locked"] = true
	L["lock_at"] = m.time
	L["sealed_in"] = ins
	L["heard"] = {}
	L["flown"] = []
	L["escaped"] = []
	# whoever is in the gateway itself steps in, clear of the gate's stones
	var c: Vector3 = L["c"]
	var keep := float(L["half"]) - 0.95
	for h in ins:
		h.pos.x = clampf(h.pos.x, c.x - keep, c.x + keep); h.pos.z = clampf(h.pos.z, c.z - keep, c.z + keep); h.prev = h.pos
	var w := m.world
	for q in L["gate_tiles"]:
		var tc := Vector3(q.x + 0.5, 0, q.y + 0.5)
		for e in m.hunters + m.kins + m.mobs:
			if is_instance_valid(e) and not e.dead and not (e is Boss) and absf(e.pos.x - tc.x) < 0.5 + e.r and absf(e.pos.z - tc.z) < 0.5 + e.r and not ins.has(e):
				_push_out(L, e)
		w.kind[w.idx(q.x, q.y)] = World.T_BLOCK
	m.sfx("boom", L["gate_c"], 2.0, 0.55)
	m.sfx("shield", L["gate_c"], 2.0, 0.7)
	m.fx.burst(L["gate_c"] + Vector3(0, 1.5, 0), Lairs.color_of(L), 30, 5.0, 0.6, 3.0, 1.2)
	m.fx.ring(L["c"], float(L["half"]) + 0.6, Lairs.color_of(L), 0.7)
	(L["nodes"]["label"] as Label3D).text = "%s\nSealed in  ·  a fight is on" % L["name"]
	var b: Boss = ls.boss_of(L)
	m.add_feed("%s is sealed: %s fight%s %s" % [L["name"], ", ".join(ins.map(func(x): return x.pname)), "s" if ins.size() == 1 else "", b.md["name"] if b else "the boss"])
	if m.player and m.hud:
		if ins.has(m.player):
			m.hud.toast("SEALED IN  ·  DEFEAT %s" % (String(b.md["name"]).to_upper() if b else "THE BOSS"), Lairs.color_of(L))
	_alert(L, "fight", "%s fight at %s" % [b.md["name"] if b else "Boss", L["name"]])
	ls._tick_show(L)

## The seal drops: the gate opens again (the boss died, everyone in it went down, or time ran out).
func unlock(L: Dictionary) -> void:
	if not L.get("locked", false):
		return
	L["locked"] = false
	L["sealed_in"] = []
	L["unlock_at"] = m.time
	if L.get("victory", false):
		L["victory"] = false
		_set_updraft(L, false)
		var lvn: Node3D = L["nodes"]["lever"]
		if is_instance_valid(lvn): lvn.get_node("Lit").visible = false
	var w := m.world
	for q in L["gate_tiles"]:
		w.kind[w.idx(q.x, q.y)] = World.T_GROUND
	(L["nodes"]["label"] as Label3D).text = "%s\n%s" % [L["name"], "Cleared" if L["state"] == "cleared" else "Open"]
	m.sfx("unlock", L["gate_c"], 3.0, 0.8)
	m.fx.burst(L["gate_c"] + Vector3(0, 1.5, 0), Lairs.color_of(L), 24, 5.0, 0.6, 3.0, 1.0)

## Is this spot inside a sealed lair this hunter isn't sealed in (so it can't get there)?
func walled_off(h: Hunter, p: Vector3) -> bool:
	var L := ls.lair_of(p, 0.0)
	return not L.is_empty() and L.get("locked", false) and not (L.get("sealed_in", []) as Array).has(h)

## Is this hunter sealed in a lair right now? (Returns the lair, or {}.)
func sealed_lair(h: Hunter) -> Dictionary:
	for L in ls.list:
		if L.get("locked", false) and (L["sealed_in"] as Array).has(h):
			return L
	return {}

## Seconds until the seal fails on its own.
func lock_left(L: Dictionary) -> float:
	return maxf(0.0, Lairs.LOCK_T - (m.time - float(L.get("lock_at", m.time))))

## While sealed: those inside stay inside (walking, dashing, gliding or shoved), those outside stay
## out; it breaks when everyone inside is down or out, or when LOCK_T runs out (the boss resets).
func _tick_lock(L: Dictionary, dt: float) -> void:
	if not L.get("locked", false):
		return
	var b: Boss = ls.boss_of(L)
	if L.get("victory", false):
		# the boss is down and the gate still shut: the lever, the updraft, or the clock
		L["sealed_in"] = (L["sealed_in"] as Array).filter(func(x): return is_instance_valid(x) and not x.out and not x.extracted)
		for h in m.hunters:
			if h.out or h.extracted or h.remote:
				continue
			if ls.can_pull(L, h) and (ls._pressed(h) or (h.ctrl == "bot" and String(h.ai.get("goal_kind", "")) == "lair_lever")):
				_victory_open(L, h)
				return
		if victory_left(L) <= 0.0:
			_victory_open(L, null)
			return
		_tick_updraft(L, dt)
		_hold_seal(L, b)
		return
	if b == null or b.dead or L["state"] != "awake":
		unlock(L)
		return
	var ins: Array = (L["sealed_in"] as Array).filter(func(x): return is_instance_valid(x) and not x.out and not x.extracted)
	L["sealed_in"] = ins
	var standing: Array = ins.filter(func(x): return not x.downed)
	if standing.is_empty() or m.time - float(L["lock_at"]) >= Lairs.LOCK_T:
		var wiped := standing.is_empty()
		m.add_feed(("%s wiped the party in %s" if wiped else "The seal on %s failed: %s settles back to sleep") % ([b.md["name"], L["name"]] if wiped else [L["name"], b.md["name"]]))
		if m.player and m.hud and m.player.flat_dist(L["c"]) < 40.0:
			m.hud.toast(("THE SEAL BREAKS  ·  %s HEALS AND SLEEPS" if wiped else "THE SEAL FAILS  ·  %s RESETS") % String(b.md["name"]).to_upper(), Lairs.color_of(L))
		ls.fight.reset_boss(b)
		return
	_hold_seal(L, b)

## While sealed, those inside stay in and those outside stay out (anyone riding the escape updraft
## is let over the wall).
func _hold_seal(L: Dictionary, b: Boss) -> void:
	var ins: Array = L["sealed_in"]
	var flown: Array = L.get("flown", [])
	var c: Vector3 = L["c"]
	var hf := float(L["half"]) - 0.5
	var keep := hf - 0.45
	for h in m.hunters:
		if h.out or h.extracted or h.riding or h.dropping or (flown.has(h) and not h.grounded):
			continue
		if ins.has(h):
			if not ls.inside(L, h.pos, 0.0):
				h.pos.x = clampf(h.pos.x, c.x - keep, c.x + keep); h.pos.z = clampf(h.pos.z, c.z - keep, c.z + keep)
				h.pos.y = maxf(h.pos.y, m.world.ground_at(h.pos.x, h.pos.z))
				h.prev = h.pos
				h.vel.x = 0.0; h.vel.z = 0.0
				if h == m.player and m.hud and m.time - float(ls._told.get("lock", -9.0)) > 2.5:
					ls._told["lock"] = m.time
					if L.get("victory", false):
						m.hud.toast("The gate is still shut  ·  pull the lever, or ride the updraft", Lairs.color_of(L))
					else:
						m.hud.toast("Sealed in  ·  defeat %s" % (b.md["name"] if b else "the boss"), Lairs.color_of(L))
					m.sfx("shield", h.pos, -4.0, 1.4)
		elif ls.inside(L, h.pos, 0.25) and (h.grounded or h.pos.y <= float(c.y) + 3.6):
			_push_out(L, h)
			if h == m.player and m.hud and m.time - float(ls._told.get("seal", -9.0)) > 3.0:
				ls._told["seal"] = m.time
				m.hud.toast("%s is sealed while its fight is on" % L["name"], Lairs.color_of(L))

func _tick_gate(L: Dictionary, dt: float) -> void:
	if L["state"] in ["sealed", "dormant"]:
		return
	var locked: bool = L.get("locked", false)
	if float(L["gate_k"]) >= 1.0 and not locked:
		return
	# opening takes a moment; slamming shut on a lock-in is quick
	L["gate_k"] = move_toward(float(L["gate_k"]), 0.0 if locked else 1.0, dt / (0.35 if locked else 1.6))
	var k := float(L["gate_k"])
	var gate: Node3D = L["nodes"]["gate"]
	if is_instance_valid(gate):
		var bars: Node3D = gate.get_node("Bars")
		bars.position.y = -3.3 * k * k
		bars.position.x = sin(m.time * 40.0) * 0.03 * (1.0 - k)
		bars.visible = k < 1.0
	var dome: Node3D = L["nodes"]["dome"]
	if is_instance_valid(dome):
		var sh: MeshInstance3D = dome.get_node("Shell")
		# sealed in: the ward glows and breathes over the walls
		var glow := (0.07 + 0.05 * sin(m.time * 3.0)) if locked else 0.0
		(sh.material_override as StandardMaterial3D).albedo_color.a = 0.10 * (1.0 - k) + glow * (1.0 - k)
		dome.get_node("Rim").visible = k < 0.5
		dome.visible = k < 1.0

func _tick_runes(L: Dictionary, dt: float) -> void:
	for rn in L["runes"]:
		if rn["lit"]: continue
		if m.time - float(rn["held"]) > 0.1:
			rn["prog"] = maxf(0.0, float(rn["prog"]) - dt * 0.5)
