class_name ExitsFlow
extends ExitsLook
## Exits, part 2: what each exit kind does over time (skiff, hatch, uplink, waves).

# ------------------------------------------------------------------ the skiff
func _call(x: Dictionary, h: Hunter) -> void:
	x["state"] = "called"
	x["t"] = call_time()
	x["team"] = h.team
	x["caller"] = h.pname
	x["waves"] = 0
	x["wave_t"] = 3.0
	var n: Node3D = x["node"]
	var lamp := n.get_node("Beacon/Lamp") as MeshInstance3D
	lamp.material_override = Models.toon(ExitModels.DOCK, false, 1.6)
	n.get_node("Beacon/Flare").visible = true
	(n.get_node("Sparks") as CPUParticles3D).emitting = true
	(n.get_node("Beacon/Lever") as Node3D).rotation.x = 0.5
	# loud: everyone hears the horn and sees the flare and the ping
	Sfx.play("horn", null, -3.0, 0.03, 0.9)
	m.sfx("warn", x["pos"], 0.0, 0.7)
	m.ping(x["pos"], ExitModels.DOCK)
	m.fx.ring(x["berth"], 4.0, ExitModels.DOCK, 0.6)
	var mine: bool = m.player != null and h.team == m.player.team
	m.add_feed(("%s called a skiff at %s" % [h.pname, x["name"]]) if mine else ("Someone called a skiff at %s" % x["name"]))
	if m.hud and m.player and not m.player.out:
		if mine:
			m.hud.toast("Skiff called! Hold the dock for %ds, then get on board" % int(x["t"]), ExitModels.DOCK)
		else:
			m.hud.toast("A horn sounds: a skiff was called %s at %s" % [m.direction_word(m.player.pos, x["pos"]), x["name"]], ExitModels.DOCK)

func _tick_dock(x: Dictionary, dt: float) -> void:
	var sk: Node3D = x["skiff"]
	var berth: Vector3 = x["berth"]
	var out3 := Vector3(x["out"].x, 0, x["out"].y)
	match String(x["state"]):
		"idle":
			if m.time >= float(x["close_at"]):
				_close_dock(x)
			elif float(x["close_at"]) < 1e8 and float(x["close_at"]) - m.time < 30.0 and not _told.has("cl%d" % int(x["i"])):
				_told["cl%d" % int(x["i"])] = true
				m.add_feed("%s closes in 30 seconds" % x["name"])
		"called":
			x["t"] = float(x["t"]) - dt
			_waves(x, dt)
			var t := float(x["t"])
			if t < APPROACH_T:
				# in sight: flying in from out over the abyss, settling onto the pier
				var k := 1.0 - t / APPROACH_T
				var e := 1.0 - pow(1.0 - k, 3.0)
				var far := berth + out3 * 46.0 + Vector3(0, 16.0, 0)
				sk.visible = true
				sk.position = far.lerp(berth, e) + Vector3(0, 0.6 * (1.0 - e), 0)
				_spin(sk, dt, 14.0)
				if not x.get("seen", false):
					x["seen"] = true
					m.sfx("horn", berth, -2.0, 1.15)
			if t <= 0.0:
				_arrive(x)
		"boarding":
			x["t"] = float(x["t"]) - dt
			sk.position = berth + Vector3(0, sin(m.time * 2.2) * 0.03, 0)
			_spin(sk, dt, 6.0)
			_waves(x, dt)
			var ab: Array = []
			for h in m.hunters:
				if _live(h) and on_deck(x, h):
					ab.append(h)
			x["aboard"] = ab
			var bt := float(x["t"])
			if bt < 3.0 and bt + dt >= 3.0:
				m.sfx("horn", berth, -4.0, 1.3)
			if bt <= 0.0:
				_depart(x)
		"gone":
			x["t"] = float(x["t"]) - dt
			var lt := DOCK_CD - float(x["t"])
			if lt < 6.0:
				sk.position = berth + out3 * (lt * lt * 1.6) + Vector3(0, lt * lt * 0.7 + lt * 0.4, 0)
				_spin(sk, dt, 18.0)
			else:
				sk.visible = false
			if float(x["t"]) <= 0.0:
				if m.time >= float(x["close_at"]):
					_close_dock(x)
				else:
					x["state"] = "idle"; x["team"] = -1; x["caller"] = ""
					m.ping(x["pos"], Color(ExitModels.DOCK, 0.6))
		"closed":
			pass

func _spin(sk: Node3D, dt: float, rate: float) -> void:
	var pr := sk.get_node_or_null("Hull/Prop") as Node3D
	if pr: pr.rotation.z += dt * rate

func _arrive(x: Dictionary) -> void:
	x["state"] = "boarding"
	x["t"] = BOARD_T
	x["seen"] = false
	var sk: Node3D = x["skiff"]
	sk.position = x["berth"]
	(sk.get_node("Wake") as CPUParticles3D).emitting = true
	m.sfx("horn", x["berth"], 0.0, 1.0)
	m.sfx("land", x["berth"], 0.0, 0.6)
	m.fx.dust(x["berth"], 14)
	m.fx.ring(x["berth"], DECK_R, ExitModels.DOCK, 0.5)
	m.ping(x["pos"], ExitModels.DOCK)
	if m.player and not m.player.out and m.player.flat_dist(x["berth"]) < 60.0:
		m.add_feed("The skiff is in at %s: %ds to board" % [x["name"], int(BOARD_T)])
		if m.hud and int(x["team"]) == m.player.team:
			m.hud.toast("The skiff is in! Get on its deck", ExitModels.DOCK)

func _depart(x: Dictionary) -> void:
	var n := 0
	for h in m.hunters:
		if _live(h) and on_deck(x, h) and not h.remote:
			m._extract(h, "skiff", x["name"])
			n += 1
	x["state"] = "gone"
	x["t"] = DOCK_CD
	x["aboard"] = []
	var nd: Node3D = x["node"]
	(nd.get_node("Beacon/Lamp") as MeshInstance3D).material_override = Models.toon(Color("6a5a40"))
	nd.get_node("Beacon/Flare").visible = false
	(nd.get_node("Sparks") as CPUParticles3D).emitting = false
	(nd.get_node("Beacon/Lever") as Node3D).rotation.x = -0.5
	m.sfx("whoosh", x["berth"], 0.0, 0.6)
	m.fx.burst(x["berth"] + Vector3(0, 0.8, 0), ExitModels.DOCK, 26, 5.0, 0.7, -2.0)
	if n == 0 and m.player and m.player.flat_dist(x["berth"]) < 40.0:
		m.add_feed("The skiff left %s empty" % x["name"])

func _close_dock(x: Dictionary) -> void:
	x["state"] = "closed"
	var nd: Node3D = x["node"]
	for nm in ["LanternL", "LanternR"]:
		var l := nd.get_node_or_null(nm) as MeshInstance3D
		if l: l.material_override = Models.toon(Color("5a5048"))
	(nd.get_node("Berth") as Node3D).visible = false
	(nd.get_node("Beacon/Ring") as Node3D).visible = false
	m.add_feed("%s has closed" % x["name"])
	if m.hud and m.player and not m.player.out and not m.player.extracted:
		var open_n := of_kind("dock").filter(func(d): return d["state"] != "closed").size()
		m.hud.toast_small("%s closed  ·  %d dock%s left" % [x["name"], open_n, "" if open_n == 1 else "s"], Color("ffcf8a"))

# ------------------------------------------------------------------ rift hatches
## The key turns: it's spent, and the hatch grinds open over HATCH_UNLOCK_T. No map ping, but anyone
## near enough sees the countdown over it and hears it working.
func _open_hatch(x: Dictionary, h: Hunter) -> void:
	h.rift_keys = maxi(0, h.rift_keys - 1)
	x["state"] = "unlocking"
	x["t"] = HATCH_UNLOCK_T
	x["team"] = h.team
	x["by"] = h.pname
	x["tick"] = 0
	m.sfx("unlock", x["pos"], -2.0, 0.8)
	m.fx.ring(x["pos"] + Vector3(0, 0.1, 0), 2.2, ExitModels.HATCH, 0.6)
	m.fx.burst(x["pos"] + Vector3(0, 0.3, 0), ExitModels.HATCH, 12, 2.5, 0.5, -3.0)
	if m.player and not m.player.out and m.hud and m.player.flat_dist(x["pos"]) < 30.0:
		if h == m.player:
			m.hud.toast("HATCH OPENS IN %dS" % int(HATCH_UNLOCK_T), ExitModels.HATCH)
		elif h.team != m.player.team:
			m.hud.toast_small("Rival opening a hatch nearby", ExitModels.HATCH)

func _set_hatch_open(x: Dictionary, open: bool) -> void:
	var n: Node3D = x["node"]
	var lid := n.get_node("Lid") as Node3D
	var tw := m.create_tween()
	if open:
		tw.tween_property(lid, "position", Vector3(1.25, -0.05, 0.2), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(lid, "position", Vector3.ZERO, 0.3)
	n.get_node("Rift").visible = open
	(n.get_node("Sparks") as CPUParticles3D).emitting = open

## Someone drops through an open hatch: one of its uses. The last one seals it.
func _enter_hatch(x: Dictionary, h: Hunter) -> void:
	if x["state"] != "open" or int(x["uses"]) <= 0 or not _live(h):
		return
	x["uses"] = int(x["uses"]) - 1
	m.fx.burst(x["pos"] + Vector3(0, 0.3, 0), ExitModels.HATCH, 14, 3.0, 0.5, -3.0)
	if not h.remote:
		m._extract(h, "hatch", x["name"])
	if int(x["uses"]) <= 0:
		x["state"] = "sealed"
		x["team"] = -1
		_set_hatch_open(x, false)
		m.sfx("thump", x["pos"], -6.0, 1.2)

func _tick_hatch(x: Dictionary, dt: float) -> void:
	var p: Vector3 = x["pos"]
	if x["state"] == "unlocking":
		x["t"] = float(x["t"]) - dt
		# a tick a second and a ring on the ground: loud enough for anyone close
		var sec := int(ceil(float(x["t"])))
		if sec != int(x.get("tick", 0)):
			x["tick"] = sec
			m.sfx("click", p, -2.0, 0.7 + 0.03 * (HATCH_UNLOCK_T - sec))
			m.fx.ring(p + Vector3(0, 0.1, 0), 1.2 + 0.12 * (HATCH_UNLOCK_T - sec), ExitModels.HATCH, 0.5)
		if float(x["t"]) <= 0.0:
			x["state"] = "open"
			x["uses"] = HATCH_USES
			x["t"] = 0.0
			_set_hatch_open(x, true)
			m.sfx("portal", p, 0.0, 0.7)
			m.fx.burst(p + Vector3(0, 0.3, 0), ExitModels.HATCH, 24, 3.5, 0.6, -3.0)
		return
	if x["state"] != "open":
		return
	# walking into it drops you through too
	for h in m.hunters:
		if x["state"] != "open":
			break
		if _live(h) and not h.remote and h.flat_dist(p) < HATCH_IN and absf(h.pos.y - p.y) < 1.2:
			_enter_hatch(x, h)

# ------------------------------------------------------------------ outposts
func _start(x: Dictionary, h: Hunter) -> void:
	x["state"] = "charging"
	x["team"] = h.team
	x["prog"] = 0.0
	x["waves"] = 0
	x["wave_t"] = 1.5
	x["steal"] = 0.0
	x["started_at"] = m.time
	x["draining"] = false
	m.sfx("warn", x["pos"], 0.0, 0.9)
	m.sfx("zap", x["pos"], -2.0, 0.7)
	m.fx.ring(x["pos"], OUTPOST_R, ExitModels.UPLINK, 0.6)
	if not x.get("tut", false):
		m.ping(x["pos"], ExitModels.UPLINK)
		var mine: bool = m.player != null and h.team == m.player.team
		m.add_feed(("%s started the uplink at %s" % [h.pname, x["name"]]) if mine else ("An uplink came on at %s" % x["name"]))
		if m.hud and m.player and not m.player.out:
			m.hud.toast("Uplink started: hold the yard until it's charged" if mine else "An uplink is charging %s at %s" % [m.direction_word(m.player.pos, x["pos"]), x["name"]], ExitModels.UPLINK)

func _tick_outpost(x: Dictionary, dt: float) -> void:
	var n: Node3D = x["node"]
	match String(x["state"]):
		"charging":
			var team := int(x["team"])
			var squad := 0
			var foes := {}
			for h in m.hunters:
				if not _live(h) or h.downed or not in_yard(x, h):
					continue
				# truce partners share the yard: they hold it with you rather than contest it
				if h.team == team or (m.truce and m.truce.allied(team, h.team)): squad += 1
				else: foes[h.team] = int(foes.get(h.team, 0)) + 1
			x["contested"] = not foes.is_empty()
			x["crew"] = squad
			# nobody in the yard at all: the charge drains away, and at nothing the uplink shuts off. (A
			# rival standing in it alone is the old contest instead: it stalls, then it's theirs.)
			x["draining"] = squad == 0 and foes.is_empty()
			if x["draining"]:
				x["prog"] = maxf(0.0, float(x["prog"]) - dt / UPLINK_DECAY_T)
				if float(x["prog"]) <= 0.0 and m.time - float(x.get("started_at", -99.0)) > UPLINK_GRACE:
					_fizzle(x)
					return
			if squad > 0 and foes.is_empty():
				x["prog"] = minf(1.0, float(x["prog"]) + dt * crew_rate(squad) / uplink_time(x))
				x["steal"] = 0.0
			elif squad == 0 and foes.size() == 1:
				# a rival squad holding the yard alone takes the uplink over (progress and all)
				x["steal"] = float(x["steal"]) + dt
				if float(x["steal"]) >= STEAL_T:
					x["steal"] = 0.0
					x["team"] = int(foes.keys()[0])
					m.sfx("zap", x["pos"], 0.0, 1.3)
					m.fx.ring(x["pos"], OUTPOST_R, Color("ff8a6a"), 0.5)
					var who := ""
					for h in m.hunters:
						if h.team == int(x["team"]) and in_yard(x, h): who = h.pname; break
					m.add_feed("%s took over the uplink at %s" % [who, x["name"]])
			else:
				x["steal"] = 0.0
			_waves(x, dt)
			if float(x["prog"]) >= 1.0:
				_open_lift(x)
		"open":
			x["t"] = float(x["t"]) - dt
			var p: Vector3 = x["pos"]
			for h in m.hunters:
				if _live(h) and not h.remote and h.flat_dist(p) < LIFT_R and absf(h.pos.y - p.y) < 1.5:
					m._extract(h, "uplink", x["name"])
			if float(x["t"]) <= 0.0:
				x["state"] = "spent"
				x["t"] = UPLINK_CD
				n.get_node("Lift").visible = false
				m.sfx("thump", p, -6.0, 0.8)
		"fizzling":
			# a few hard flickers, a sputter each, then dark
			x["t"] = float(x["t"]) - dt
			var k := FIZZLE_T - float(x["t"])
			if int(k / 0.45) != int((k - dt) / 0.45):
				m.sfx("zap", x["pos"], -3.0, 0.6 + 0.1 * int(k / 0.45))
				m.fx.ring(x["pos"], OUTPOST_R, ExitModels.UPLINK, 0.3)
			if float(x["t"]) <= 0.0:
				x["state"] = "spent"
				x["t"] = FIZZLE_CD
				x["team"] = -1
				m.sfx("thump", x["pos"], -4.0, 0.6)
		"spent":
			x["t"] = float(x["t"]) - dt
			if float(x["t"]) <= 0.0:
				x["state"] = "idle"; x["team"] = -1; x["prog"] = 0.0
	_show_outpost(x, n)

## The yard stood empty until the charge ran out: the uplink flickers and shuts off.
func _fizzle(x: Dictionary) -> void:
	var was := int(x["team"])
	x["state"] = "fizzling"
	x["t"] = FIZZLE_T
	x["prog"] = 0.0
	x["contested"] = false
	x["draining"] = false
	var n: Node3D = x["node"]
	((n.get_node("Charge") as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("arc", 0.0)
	m.sfx("warn", x["pos"], -2.0, 0.6)
	if m.player and not m.player.out and m.player.flat_dist(x["pos"]) < 70.0:
		m.add_feed("The uplink at %s lost its charge and shut off" % x["name"])
		if m.hud and was == m.player.team:
			m.hud.toast("The uplink shut off: nobody held the yard. Start it again to charge it", ExitModels.UPLINK)

## The outpost's look for its state (OutpostLook): lit with the charge, the banner in the holder's colour,
## the yard's edge only while you stand in it or it is contested.
func _show_outpost(x: Dictionary, n: Node3D) -> void:
	var lit := OutpostLook.lit_of(x)
	if x["state"] == "fizzling":
		lit = 1.0 if fmod(FIZZLE_T - float(x["t"]), 0.45) < 0.2 else 0.0
	elif x.get("draining", false) and x["state"] == "charging":
		lit *= 0.45 + 0.35 * sin(m.time * 7.0)
	var raised := OutpostLook.held(x)
	var col: Color = Data.TEAM_COLORS[int(x["team"]) % Data.TEAM_COLORS.size()] if raised else OutpostLook.NEUTRAL
	var key := [snappedf(lit, 0.01), raised, col]
	if key != x.get("look"):
		x["look"] = key
		OutpostLook.apply(n, lit, col, 1.0 if raised else 0.0)
	if raised:
		OutpostLook.sway(n, m.time)
	var near: bool = m.player != null and in_yard(x, m.player)
	var charging: bool = x["state"] == "charging"
	OutpostLook.rings(n, near or x["contested"], x["contested"], charging, float(x["prog"]))

func _open_lift(x: Dictionary) -> void:
	x["state"] = "open"
	x["t"] = 1e9 if x.get("tut", false) else LIFT_T
	x["contested"] = false
	var n: Node3D = x["node"]
	n.get_node("Lift").visible = true
	m.sfx("unlock", x["pos"], 0.0, 0.9)
	m.sfx("portal", x["pos"], 0.0, 0.8)
	m.fx.burst(x["pos"] + Vector3(0, 1.0, 0), ExitModels.UPLINK, 34, 6.0, 0.8, -3.0)
	m.fx.ring(x["pos"], LIFT_R + 0.4, ExitModels.UPLINK, 0.6)
	if not x.get("tut", false):
		m.ping(x["pos"], ExitModels.UPLINK)
		if m.player and not m.player.out and m.player.flat_dist(x["pos"]) < 70.0:
			m.add_feed("The lift is open at %s for %ds" % [x["name"], int(LIFT_T)])
	if m.hud and m.player and int(x["team"]) == m.player.team and not m.player.out:
		m.hud.toast("Uplink complete! The lift is open: step into the light", ExitModels.UPLINK)

# ------------------------------------------------------------------ monster waves
## While a skiff is coming or an uplink is charging, the local monsters keep coming at it.
func _waves(x: Dictionary, dt: float) -> void:
	if x.get("tut", false) and int(x["waves"]) >= 1:
		return
	x["wave_t"] = float(x["wave_t"]) - dt
	if float(x["wave_t"]) > 0.0:
		return
	x["wave_t"] = 11.0 if x["kind"] == "dock" else 12.0
	if m.net_on and not m.is_host:
		return
	var focus: Vector3 = x.get("berth", x["pos"])
	var alive := 0
	for mb in m.mobs:
		if not mb.dead and int(mb.get_meta("exit", -1)) == int(x["i"]): alive += 1
	var n := 2 if x.get("tut", false) else 2 + m.tier + (1 if int(x["waves"]) >= 2 else 0)
	n = mini(n, WAVE_CAP - alive)
	x["waves"] = int(x["waves"]) + 1
	if n <= 0:
		return
	var ii := m.world.island_of(focus.x, focus.z)
	var spawned := 0
	for k in n:
		var at := _wave_spot(focus, ii)
		if at == Vector3.INF:
			continue
		var kinds: Array = ["skitter"] if x.get("tut", false) else []
		if kinds.is_empty() and m.biomes:
			kinds = m.biomes.camp_comp({"pos": at, "kind": "normal" if int(x["waves"]) >= 3 else "light"})
		if kinds.is_empty():
			kinds = ["skitter", "spitter", "bomber", "skitter"] + (["brute"] if int(x["waves"]) >= 3 else [])
		var mb: Mob = m.spawn_mob(String(kinds[m.rng.randi() % kinds.size()]), at)
		if m.biomes: m.biomes.dress(mb)
		mb.set_meta("exit", int(x["i"]))
		mb.camp = focus          # they press in on the dock / outpost
		mb.st = "chase"
		var best: Hunter = null; var bd := 16.0
		for h in m.hunters:
			if h.targetable() and mb.flat_dist(h) < bd: bd = mb.flat_dist(h); best = h
		mb.tgt = best
		if best == null: mb.st = "idle"
		m.fx.burst(at + Vector3(0, 0.4, 0), Color("ff9a6a"), 12, 3.0, 0.5)
		m.fx.dust(at, 6)
		spawned += 1
	if spawned > 0:
		m.sfx("thump", focus, -4.0, 0.8)
		if m.player and not m.player.out and m.player.flat_dist(focus) < 24.0 and m.hud:
			m.hud.toast_small("Monsters incoming!", Color("ff9a6a"))

func _wave_spot(focus: Vector3, ii: int) -> Vector3:
	var W := m.world
	for k in 40:
		var a := m.rng.randf() * TAU
		var d := m.rng.randf_range(7.0, 13.0) if k < 30 else m.rng.randf_range(4.0, 8.0)
		var x := focus.x + cos(a) * d; var z := focus.z + sin(a) * d
		if W.is_void(x, z) or W.is_block(x, z) or (ii >= 0 and W.island_of(x, z) != ii):
			continue
		if W.edge_dist(int(x), int(z), 2) < 2:
			continue
		var near := false
		for h in m.hunters:
			if _live(h) and Vector2(h.pos.x - x, h.pos.z - z).length() < 4.0: near = true; break
		if near:
			continue
		return Vector3(x, W.ground_at(x, z), z)
	return Vector3.INF
