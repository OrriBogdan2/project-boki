class_name LairsDemo
extends RefCounted
## Screenshot scenes (--lair-demo) for Lairs.

var ls: Lairs
var m: Match

func _init(l: Lairs) -> void:
	ls = l
	m = l.m

# ------------------------------------------------------------------ test hooks
## --lair-demo=puzzle|fight|egg|sealed|victory|updraft|outside: a scene set up for a screenshot ("sealed": just
## inside the gate after it has shut behind you; "victory": the boss just fallen, the gate still shut,
## you by the lever with the updraft blowing at the back; "updraft": the same, then you step into the
## updraft and ride it out over the back wall (LAIRDEMO lines time the ride); "outside": a rival squad sealed in with the
## boss and you outside its gate, the alert's beam over the lair and the seal's clock over the gate;
## "outside_map": the same with the full map open on the alert).
func demo(mode: String) -> void:
	if ls.list.is_empty() or m.player == null:
		return
	var P: Hunter = m.player
	var pick := String(m.opts.get("demo_boss", ""))
	var L: Dictionary = ls.list[0]
	for x in ls.list:
		if String(x["boss"]) == pick: L = x
	ls.activate(L)
	if m.has_meta("lair_demo_done"):
		if mode == "puzzle" and is_same(L["user"], P):
			# keep the needle sweeping and a lock half done for the shot
			pass
		if mode in ["fight", "sealed"]:
			var b: Boss = ls.boss_of(L)
			if b and is_instance_valid(b) and not b.dead:
				P.hp = P.max_hp
				if not ls.inside(L, P.pos, -1.0):
					var back: Vector3 = L["c"] + Vector3(L["out"].x, 0, L["out"].y) * (2.0 if mode == "fight" else float(L["half"]) - 2.6)
					P.teleport(Vector3(back.x, m.world.ground_at(back.x, back.z), back.z))
				for o in m.hunters:
					if o != P and o.team == P.team: o.hp = o.max_hp
		if mode in ["victory", "updraft"]:
			var b: Boss = ls.boss_of(L)
			if b and not b.dead and L.get("locked", false):
				b.hurt(b.max_hp * 3.0, null, {"src": "test"})      # (no killer: no perk choice over the shot)
			if mode == "victory":
				m.cam.zoom = 1.9; m.cam.zoom_to = 1.9      # (the match eases the camera back to 1 every frame)
			if L.get("victory", false):
				L["victory_at"] = m.time - 2.2      # (hold the clock for the shot)
				P.hp = P.max_hp
				if mode == "updraft" and L.get("up_on", false) and not m.has_meta("updraft_demo"):
					# step into the escape updraft and ride it out (--shot-times= for the whole ride)
					m.set_meta("updraft_demo", m.time)
					var u: Vector3 = L["up"]
					P.teleport(Vector3(u.x, m.world.ground_at(u.x, u.z), u.z))
					print("LAIRDEMO into the updraft at %.1f" % m.time)
				if mode == "updraft" and m.has_meta("updraft_demo") and P.grounded and not ls.inside(L, P.pos, 0.0) and not m.has_meta("updraft_landed"):
					m.set_meta("updraft_landed", m.time)
					print("LAIRDEMO landed outside at %.1f (%.1f s after stepping in)" % [m.time, m.time - float(m.get_meta("updraft_demo"))])
		if mode in ["outside", "outside_map"]:
			if mode == "outside_map" and m.hud and not m.hud.map_open() and L.get("locked", false) and m.time - float(L.get("alert_at", m.time)) > 0.8:
				m.hud.open_map()
			L["lock_at"] = m.time - 18.6
			P.hp = P.max_hp
			m.cam.zoom = 2.2; m.cam.zoom_to = 2.2
			for o in L.get("sealed_in", []):
				o.hp = o.max_hp
		return
	m.set_meta("lair_demo_done", true)
	for g in L["guards"]:
		if is_instance_valid(g): g.dead = true; g.visible = false
	for o in m.hunters:
		if o.team != P.team:
			o.teleport(m.world.spawns[-1] if not m.world.spawns.is_empty() else o.pos)
			o.ctrl = "idle"
	match mode:
		"puzzle":
			var at: Vector3 = L["dial"] + Vector3(L["out"].x, 0, L["out"].y) * 0.9
			P.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
			ls._start_dial(L, P)
			L["grace"] = 0.0
			L["lock"] = 1
			ls._new_lock(L)
			L["targets"][0]["hit"] = true
			m.cam.snap(P.pos)
		"exterior":
			var at: Vector3 = L["dial"] + Vector3(L["out"].x, 0, L["out"].y) * 1.2 + Vector3(-L["out"].y, 0, L["out"].x) * 1.5
			P.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
			m.cam.zoom_to = 1.7; m.cam.zoom = 1.7
			m.cam.snap(P.pos)
		"fight", "egg", "sealed":
			ls.open(L, P, "dial")
			L["gate_k"] = 0.999
			var at: Vector3 = L["c"] + Vector3(L["out"].x, 0, L["out"].y) * (float(L["half"]) - 2.6 if mode == "sealed" else 2.0)
			P.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
			for o in m.hunters:
				if o != P and o.team == P.team:
					o.teleport(P.pos + Vector3(-L["out"].y, 0, L["out"].x) * 2.0)
					o.ctrl = "idle"
			m.cam.snap(P.pos)
			ls.fight.wake(L, P)
			var b: Boss = ls.boss_of(L)
			if mode == "egg" and b:
				b.hurt(b.max_hp * 2.0, P, {"src": "test"})
		"victory", "updraft":
			ls.open(L, P, "dial")
			L["gate_k"] = 0.999
			var out: Vector3 = Vector3(L["out"].x, 0, L["out"].y)
			var side := Vector3(-L["out"].y, 0, L["out"].x)
			var at: Vector3 = L["lever"] - out * 1.0 + side * 0.8
			P.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
			for o in m.hunters:
				if o != P and o.team == P.team:
					var q: Vector3 = L["up"] + out * 2.2 + side * 1.2
					o.teleport(Vector3(q.x, m.world.ground_at(q.x, q.z), q.z))
					o.ctrl = "idle"
			if mode == "victory":
				m.cam.zoom_to = 2.0; m.cam.zoom = 2.0
			m.cam.snap(P.pos)
			ls.fight.wake(L, P)
		"outside", "outside_map":
			ls.open(L, P, "dial")
			L["gate_k"] = 0.999
			var out: Vector3 = Vector3(L["out"].x, 0, L["out"].y)
			var side := Vector3(-L["out"].y, 0, L["out"].x)
			# a rival squad inside with the boss
			var n := 0
			for o in m.hunters:
				if o.team != P.team and n < 2:
					var q: Vector3 = L["c"] + side * (n * 2.0 - 1.0) * 1.6 + out * 1.5
					o.teleport(Vector3(q.x, m.world.ground_at(q.x, q.z), q.z))
					o.ctrl = "idle"
					n += 1
			var at: Vector3 = L["dial"] + out * 1.4 + side * 1.6
			P.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
			for o in m.hunters:
				if o != P and o.team == P.team:
					o.teleport(P.pos + side * -2.2)
					o.ctrl = "idle"
			m.cam.zoom_to = 2.3; m.cam.zoom = 2.3
			m.cam.snap(P.pos)
			var b: Boss = ls.boss_of(L)
			if b: ls.fight.wake(L, b.tgt if b.tgt else P)
