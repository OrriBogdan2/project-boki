class_name ExitsFlow
extends RefCounted
## An exit's uplink and lift run, its monster waves, for Exits.

var ex: Exits
var m: Match


func _init(l: Exits) -> void:
	ex = l
	m = l.m


func _start(x: Dictionary, h: Hunter) -> void:
	x["state"] = "charging"
	x["team"] = h.team
	x["prog"] = 0.0
	x["waves"] = 0
	x["wave_t"] = Exits.WAVE_WARN
	x["warned"] = false
	x["steal"] = 0.0
	x["started_at"] = m.time
	x["draining"] = false
	m.sfx("uplink_start", x["pos"], 0.0)
	m.fx.ring(x["pos"], Exits.OUTPOST_R, ExitModels.UPLINK, 0.6)
	if not x.get("tut", false):
		m.ping(x["pos"], ExitModels.UPLINK)
		var mine: bool = m.player != null and h.team == m.player.team
		if mine:
			UiSfx.extract_start()
		m.add_feed(
			("%s started the uplink at %s" % [h.pname, x["name"]]) if mine else ("An uplink came on at %s" % x["name"])
		)
		if m.hud and m.player and not m.player.out:
			m.hud.toast(
				(
					"Uplink started: hold the outpost until it's charged"
					if mine
					else "An uplink is charging %s at %s" % [m.direction_word(m.player.pos, x["pos"]), x["name"]]
				),
				ExitModels.UPLINK
			)


func _tick_outpost(x: Dictionary, dt: float) -> void:
	var n: Node3D = x["node"]
	match String(x["state"]):
		"charging":
			var team := int(x["team"])
			var squad := 0
			var foes := {}
			for h in m.hunters:
				if not ex._live(h) or h.downed or not ex.in_yard(x, h):
					continue
				# truce partners share the yard: they hold it with you rather than contest it
				if h.team == team or (m.truce and m.truce.allied(team, h.team)):
					squad += 1
				else:
					foes[h.team] = int(foes.get(h.team, 0)) + 1
			x["contested"] = not foes.is_empty()
			x["crew"] = squad
			# nobody in the yard at all: the charge drains away, and at nothing the uplink shuts off. (A
			# rival standing in it alone is the old contest instead: it stalls, then it's theirs.)
			x["draining"] = squad == 0 and foes.is_empty()
			if x["draining"]:
				x["prog"] = maxf(0.0, float(x["prog"]) - dt / Exits.UPLINK_DECAY_T)
				if float(x["prog"]) <= 0.0 and m.time - float(x.get("started_at", -99.0)) > Exits.UPLINK_GRACE:
					_fizzle(x)
					return
			if squad > 0 and foes.is_empty():
				x["prog"] = minf(1.0, float(x["prog"]) + dt * Exits.crew_rate(squad) / ex.uplink_time(x))
				x["steal"] = 0.0
			elif squad == 0 and foes.size() == 1:
				# a rival squad holding the yard alone takes the uplink over (progress and all)
				x["steal"] = float(x["steal"]) + dt
				if float(x["steal"]) >= Exits.STEAL_T:
					x["steal"] = 0.0
					x["team"] = int(foes.keys()[0])
					m.sfx("uplink_steal", x["pos"], 0.0)
					m.fx.ring(x["pos"], Exits.OUTPOST_R, Color("ff8a6a"), 0.5)
					var who := ""
					for h in m.hunters:
						if h.team == int(x["team"]) and ex.in_yard(x, h):
							who = h.pname
							break
					m.add_feed("%s took over the uplink at %s" % [who, x["name"]])
			else:
				x["steal"] = 0.0
			_waves(x, dt)
			if float(x["prog"]) >= 1.0:
				_open_lift(x)
		"open":
			x["t"] = float(x["t"]) - dt
			var p: Vector3 = x["pos"]
			var seat: bool = x.get("seat", false)  # the Uplink seat: its lift is the finishing squad's alone
			var rode := false
			for h in m.hunters:
				var at_lift: bool = (
					ex._live(h) and not h.remote and h.flat_dist(p) < Exits.LIFT_R and absf(h.pos.y - p.y) < 1.5
				)
				if at_lift and (not seat or h.team == int(x["team"])):
					m._extract(h, "uplink", x["name"])
					rode = true
			if seat and rode:
				# ...and it takes their downed in the yard along
				for h in m.hunters:
					if ex._live(h) and not h.remote and h.downed and h.team == int(x["team"]) and ex.in_yard(x, h):
						m._extract(h, "uplink", x["name"])
			if float(x["t"]) <= 0.0:
				x["state"] = "closed" if seat else "spent"  # (one use: the Uplink seat doesn't come back)
				x["taken"] = true  # the lift opened once: WaysOutLook shows the seat used
				x["t"] = Exits.UPLINK_CD
				n.get_node("Lift").visible = false
				m.sfx("thump", p, -6.0, 0.8)
		"fizzling":
			# a few hard flickers, a sputter each, then dark
			x["t"] = float(x["t"]) - dt
			var k := Exits.FIZZLE_T - float(x["t"])
			if int(k / 0.45) != int((k - dt) / 0.45):
				m.sfx("uplink_sputter", x["pos"], -3.0, 0.8 + 0.1 * int(k / 0.45))
				m.fx.ring(x["pos"], Exits.OUTPOST_R, ExitModels.UPLINK, 0.3)
			if float(x["t"]) <= 0.0:
				x["state"] = "spent"
				x["t"] = Exits.FIZZLE_CD
				x["team"] = -1
				m.sfx("uplink_shut", x["pos"], -4.0)
		"spent":
			x["t"] = float(x["t"]) - dt
			if float(x["t"]) <= 0.0:
				x["state"] = "idle"
				x["team"] = -1
				x["prog"] = 0.0
	ex._show_outpost(x, n)


## The Uplink seat shut (its window ran out): dark for the rest of the match.
func close_outpost(x: Dictionary) -> void:
	var was := String(x["state"])
	x["state"] = "closed"
	x["team"] = -1
	x["prog"] = 0.0
	x["contested"] = false
	x["draining"] = false
	var n: Node3D = x["node"]
	((n.get_node("Charge") as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("arc", 0.0)
	if was == "charging":
		m.sfx("uplink_shut", x["pos"], -4.0)


## The yard stood empty until the charge ran out: the uplink flickers and shuts off.
func _fizzle(x: Dictionary) -> void:
	var was := int(x["team"])
	x["state"] = "fizzling"
	x["t"] = Exits.FIZZLE_T
	x["prog"] = 0.0
	x["contested"] = false
	x["draining"] = false
	var n: Node3D = x["node"]
	((n.get_node("Charge") as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("arc", 0.0)
	m.sfx("uplink_fizzle", x["pos"], -2.0)
	if m.player and not m.player.out and m.player.flat_dist(x["pos"]) < 70.0:
		m.add_feed("The uplink at %s lost its charge and shut off" % x["name"])
		if m.hud and was == m.player.team:
			UiSfx.extract_fail()
			m.hud.toast("The uplink shut off: nobody held the outpost. Start it again to charge it", ExitModels.UPLINK)


func _open_lift(x: Dictionary) -> void:
	x["state"] = "open"
	x["t"] = 1e9 if x.get("tut", false) else Exits.LIFT_T
	x["contested"] = false
	var n: Node3D = x["node"]
	n.get_node("Lift").visible = true
	m.sfx("uplink_lift", x["pos"], 0.0)
	m.fx.burst(x["pos"] + Vector3(0, 1.0, 0), ExitModels.UPLINK, 34, 6.0, 0.8, -3.0)
	m.fx.ring(x["pos"], Exits.LIFT_R + 0.4, ExitModels.UPLINK, 0.6)
	if not x.get("tut", false):
		m.ping(x["pos"], ExitModels.UPLINK)
		if m.player and not m.player.out and m.player.flat_dist(x["pos"]) < 70.0:
			m.add_feed("The lift is open at %s for %ds" % [x["name"], int(Exits.LIFT_T)])
	if m.hud and m.player and int(x["team"]) == m.player.team and not m.player.out:
		m.hud.toast("Uplink complete! The lift is open: step into the light", ExitModels.UPLINK)


## While an uplink is charging, the local monsters keep coming at it: every WAVE_EVERY seconds, out of
## the outpost's fixed posts, which glow on the ground WAVE_WARN seconds first (every peer sees it).
func _waves(x: Dictionary, dt: float) -> void:
	if x.get("tut", false) and int(x["waves"]) >= 1:
		return
	x["wave_t"] = float(x["wave_t"]) - dt
	if not x.get("warned", false) and float(x["wave_t"]) <= Exits.WAVE_WARN:
		x["warned"] = true
		for at in wave_posts(x):
			m.fx.ring(at, 1.2, Color("ff9a6a"), Exits.WAVE_WARN)
	if float(x["wave_t"]) > 0.0:
		return
	x["wave_t"] = Exits.WAVE_EVERY
	x["warned"] = false
	if m.net_on and not m.is_host:
		return
	var focus: Vector3 = x["pos"]
	var alive := 0
	for mb in m.mobs:
		if not mb.dead and int(mb.get_meta("exit", -1)) == int(x["i"]):
			alive += 1
	var n := 2 if x.get("tut", false) else 2 + m.tier + (1 if int(x["waves"]) >= 2 else 0)
	n = mini(n, Exits.WAVE_CAP - alive)
	var wave := int(x["waves"])
	x["waves"] = wave + 1
	if n <= 0:
		return
	var posts := wave_posts(x).filter(func(p): return not _hunter_near(p, 4.0))
	var spawned := 0
	for k in mini(n, posts.size()):
		var at: Vector3 = posts[(wave + k) % posts.size()]
		var kinds: Array = ["skitter"] if x.get("tut", false) else []
		if kinds.is_empty() and m.biomes:
			kinds = m.biomes.camp_comp({"pos": at, "kind": "normal" if int(x["waves"]) >= 3 else "light"})
		if kinds.is_empty():
			kinds = ["skitter", "spitter", "bomber", "skitter"] + (["brute"] if int(x["waves"]) >= 3 else [])
		var mb: Mob = m.spawn_mob(String(kinds[(wave + k) % kinds.size()]), at)
		if m.biomes:
			m.biomes.dress(mb)
		mb.set_meta("exit", int(x["i"]))
		mb.camp = focus  # they press in on the outpost
		mb.st = "chase"
		var best: Hunter = null
		var bd := 16.0
		for h in m.hunters:
			if h.targetable() and mb.flat_dist(h) < bd:
				bd = mb.flat_dist(h)
				best = h
		mb.tgt = best
		if best == null:
			mb.st = "idle"
		m.fx.burst(at + Vector3(0, 0.4, 0), Color("ff9a6a"), 12, 3.0, 0.5)
		m.fx.dust(at, 6)
		spawned += 1
	if spawned > 0:
		m.sfx("thump", focus, -4.0, 0.8)
		if m.player and not m.player.out and m.player.flat_dist(focus) < 24.0 and m.hud:
			m.hud.toast_small("Monsters incoming!", Color("ff9a6a"))


## The outpost's wave posts: WAVE_POSTS evenly round it on open ground of its island, turned by the
## exit's index so neighbouring outposts differ. Worked out once; the same on every peer.
func wave_posts(x: Dictionary) -> Array:
	if x.has("posts"):
		return x["posts"]
	var world := m.world
	var focus: Vector3 = x["pos"]
	var ii := world.island_of(focus.x, focus.z)
	var posts: Array = []
	for k in Exits.WAVE_POSTS:
		var a := int(x["i"]) * 2.4 + TAU * k / Exits.WAVE_POSTS
		for d in Exits.WAVE_R:
			var px: float = focus.x + cos(a) * d
			var pz: float = focus.z + sin(a) * d
			if world.is_void(px, pz) or world.is_block(px, pz) or (ii >= 0 and world.island_of(px, pz) != ii):
				continue
			if world.edge_dist(int(px), int(pz), 2) < 2:
				continue
			posts.append(Vector3(px, world.ground_at(px, pz), pz))
			break
	x["posts"] = posts
	return posts


func _hunter_near(p: Vector3, r: float) -> bool:
	for h in m.hunters:
		if ex._live(h) and Vector2(h.pos.x - p.x, h.pos.z - p.z).length() < r:
			return true
	return false
