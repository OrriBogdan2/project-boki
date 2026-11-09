class_name Exits
extends ExitsFlow
## The ways out of an expedition. No more standing in a circle: three kinds of exit, each with its
## own risk (after ARC Raiders' elevators and raider hatches, made for floating islands):
##  - Skiff docks (public, loud). On the outer landings. Hold interact at the horn beacon to call a
##    sky-skiff: the horn and a tall flare tell the whole map, monsters come at the dock in waves,
##    and the skiff arrives after about 45 s. It holds at the pier for a short boarding window and
##    leaves with whoever is standing on its deck: your squad, a rival who fought their way on, or a
##    downed hunter who crawled aboard. Docks close one by one late in the match (one never does).
##  - Rift hatches (keyed). Sealed hatches all over the islands. Walk up with a Rift Key (rare loot,
##    carried, lost to your deathbox if you die) and press interact: the key is spent and the hatch
##    starts grinding open, a 10 s countdown anyone close by can see and hear (a risky wait). Then it's
##    open for anyone (your squad, or a rival) to drop through, three people in all, and it seals.
##  - Outpost uplinks (hold a mini base). A walled outpost with an uplink mast. Starting it brings
##    monsters; it charges while your squad holds the yard (one of you is enough; two charge it half
##    again as fast, three nearly twice as fast: UPLINK_CREW) and stalls while a rival stands in it
##    (hold it alone long enough and it's theirs). Leave the yard empty and the charge drains away
##    (UPLINK_DECAY_T from full); at nothing the uplink flickers and shuts off, and it has to be
##    started again once it has cooled down (FIZZLE_CD). When it's done, a lift of light opens in the
##    middle for a little while, for anyone who gets in.

# ------------------------------------------------------------------ interacting
## What interact would do at an exit for this hunter, for Match._update_interact (or {}).
## Holding interact fills x.hold[nid]; letting go resets it.
func interact_for(h: Hunter) -> Dictionary:
	var want: bool = h.inp.get("interact", false)
	var key := Settings.key_cap("interact")
	var best := {}
	for x in list:
		if not want:
			(x["hold"] as Dictionary).erase(h.nid)
		if not best.is_empty():
			continue
		match String(x["kind"]):
			"dock":
				var bp: Vector3 = x["pos"]
				if h.flat_dist(bp) > 1.8 or absf(h.pos.y - bp.y) > 1.5:
					continue
				match String(x["state"]):
					"idle":
						if m.time < float(x["open_at"]):
							best = {"label": "The skiff dock opens in %s" % _cap(float(x["open_at"]) - m.time)}
						elif m.time >= float(x["close_at"]):
							best = {"label": "This dock has closed"}
						else:
							best = {"act": "call", "need": CALL_HOLD, "label": "Hold %s to sound the horn and call a skiff  ·  loud: monsters and rivals will come" % key}
					"called": best = {"label": "Skiff on its way  ·  hold the dock, then board at the pier"}
					"boarding": best = {"label": "The skiff is in! Get on its deck  ·  leaves in %ds" % int(ceil(x["t"]))}
					"gone": best = {"label": "The skiff just left. The dock is ready again in %ds" % int(ceil(x["t"]))}
					"closed": best = {"label": "This dock has closed"}
			"hatch":
				var hp: Vector3 = x["pos"]
				if h.flat_dist(hp) > HATCH_R or absf(h.pos.y - hp.y) > 1.2:
					continue
				match String(x["state"]):
					"sealed":
						if h.rift_keys > 0:
							best = {"act": "open", "need": KEY_HOLD, "label": "%s: Unlock with Rift Key  ·  opens in %ds, 3 can drop through (you have %d key%s)" % [key, int(HATCH_UNLOCK_T), h.rift_keys, "" if h.rift_keys == 1 else "s"]}
						else:
							best = {"label": "Needs a Rift Key  ·  vaults, bosses, elite monsters"}
					"unlocking":
						best = {"label": "The hatch is opening  ·  %ds  ·  hold out" % int(ceil(float(x["t"])))}
					"open":
						best = {"act": "enter", "need": KEY_HOLD, "label": "%s: Drop through  ·  %d of %d left" % [key, int(x["uses"]), HATCH_USES]}
			"outpost":
				var cp: Vector3 = x["pos"]
				if h.flat_dist(cp) > 1.9 or absf(h.pos.y - cp.y) > 1.5:
					continue
				match String(x["state"]):
					"idle":
						if m.time < float(x["open_at"]):
							best = {"label": "The uplink comes online in %s" % _cap(float(x["open_at"]) - m.time)}
						else:
							best = {"act": "start", "need": START_HOLD, "label": "Hold %s to start the uplink  ·  monsters will attack the outpost" % key}
					"charging": best = {"label": "Uplink %d%%  ·  hold the yard (more of you charge it faster)%s" % [int(x["prog"] * 100.0), "  ·  CONTESTED" if x["contested"] else crew_text(int(x.get("crew", 0)))]}
					"fizzling": best = {"label": "The uplink lost its charge and is shutting off"}
					"open": best = {"label": "The lift is open! Step into the light"}
					"spent": best = {"label": "The uplink is cooling down: %ds" % int(ceil(x["t"]))}
		if not best.is_empty():
			best["kind"] = "exit"
			best["x"] = x
			best["col"] = color_of(x)
	return best

## Holding interact on an exit (Match._update_interact).
func hold(h: Hunter, it: Dictionary, dt: float) -> void:
	if not it.has("act"):
		return
	var x: Dictionary = it["x"]
	var hd: Dictionary = x["hold"]
	# a hit breaks a call or a start (not the instant key)
	if it["act"] != "open" and m.time - h.hurt_at < 0.1:
		hd[h.nid] = 0.0
		return
	hd[h.nid] = float(hd.get(h.nid, 0.0)) + dt
	if float(hd[h.nid]) < float(it["need"]):
		return
	hd.erase(h.nid)
	act(x, String(it["act"]), h)

func act(x: Dictionary, what: String, h: Hunter, from_net := false) -> void:
	match what:
		"call":
			if x["state"] != "idle":
				return
			_call(x, h)
		"open":
			if x["state"] != "sealed" or h == null or h.rift_keys <= 0:
				return
			_open_hatch(x, h)
		"enter":
			if x["state"] != "open" or h == null:
				return
			_enter_hatch(x, h)
		"start":
			if x["state"] != "idle":
				return
			_start(x, h)
	if m.net_on and not from_net:
		m.net_event(["xc", int(x["i"]), what, h.nid if h else ""])

func net_in(e: Array) -> void:
	var i := int(e[1])
	if i < 0 or i >= list.size():
		return
	var h: Hunter = m.ents_by_id.get(String(e[3]), null) as Hunter
	if h == null:
		return
	act(list[i], String(e[2]), h, true)

# ------------------------------------------------------------------ the match clock
func tick(dt: float) -> void:
	for x in list:
		match String(x["kind"]):
			"dock": _tick_dock(x, dt)
			"hatch": _tick_hatch(x, dt)
			"outpost": _tick_outpost(x, dt)

## Only one squad is left: their way out comes faster.
func on_last_team() -> void:
	if rush or m.opts.get("tutorial", false) or list.is_empty():
		return
	rush = true
	for x in list:
		if x["kind"] == "dock" and x["state"] == "called" and float(x["t"]) > RUSH_CALL_T:
			x["t"] = RUSH_CALL_T
	if m.player and not m.player.out and not m.player.extracted and m.hud:
		m.hud.toast_small("Last squad: exits speed up", Color("8fe3c8"))

## The admin menu's "exits ready now".
func admin_ready() -> void:
	for x in list:
		if x.has("open_at"): x["open_at"] = minf(float(x["open_at"]), m.time)
		if x["kind"] == "dock" and x["state"] == "called": x["t"] = minf(float(x["t"]), 2.0)
		if x["kind"] == "outpost" and x["state"] == "charging": x["prog"] = maxf(float(x["prog"]), 0.95)

# ------------------------------------------------------------------ for bots
## Where a bot heading home should go, and what it's doing there: [pos, goal kind] or [].
## Kinds: "hatch" (press interact on arrival), "dock" / "uplink" (hold interact on arrival),
## "board" (stand on the deck), "yard" (hold the outpost), "lift" (step into it).
func bot_goal(h: Hunter, leaving: bool) -> Array:
	var team := h.team
	var mine := active_for(team)
	# in a truce, a partner squad's way out is ours too: escort them there and leave together
	if mine.is_empty() and m.truce:
		for pt in m.truce.partners(team):
			var px := active_for(pt)
			if not px.is_empty() and (leaving or h.flat_dist(px.get("berth", px["pos"])) < 60.0):
				mine = px; break
	if not mine.is_empty():
		match String(mine["state"]):
			"called", "boarding": return [mine["berth"], "board"]
			"charging": return [yard_spot(mine, h), "yard"]
			"unlocking": return [mine["pos"] + Vector3(1.6, 0, 0.0), "yard"]      # wait by the hatch, guarding it
			"open": return [mine["pos"], "lift"]
	var best := []; var bs := 1e9
	for x in list:
		var d := h.flat_dist(x["pos"])
		var s := 1e9
		match String(x["kind"]):
			"dock":
				if x["state"] == "boarding" and d < float(x["t"]) * 5.0 and leaving:
					s = d * 0.5; if s < bs: bs = s; best = [x["berth"], "board"]
					continue
				if x["state"] == "called" and leaving and d < 70.0:
					s = d * 0.7; if s < bs: bs = s; best = [x["berth"], "board"]
					continue
				# don't head for a dock that'll close before we get there and call it
				if callable(x) and leaving and float(x["close_at"]) - m.time > d / 4.5 + CALL_T * 0.5:
					s = d; if s < bs: bs = s; best = [x["pos"], "dock"]
			"hatch":
				if x["state"] == "sealed" and h.rift_keys > 0 and leaving:
					s = d * 0.6; if s < bs: bs = s; best = [x["pos"], "hatch"]
				elif x["state"] == "open" and int(x["uses"]) > 0 and d < 40.0 and leaving:
					s = d * 0.3; if s < bs: bs = s; best = [x["pos"], "lift"]
			"outpost":
				if x["state"] == "open" and d < float(x["t"]) * 5.0:
					s = d * 0.4; if s < bs: bs = s; best = [x["pos"], "lift"]
				elif startable(x) and leaving and m.length - m.time > 70.0:
					s = d * 1.1; if s < bs: bs = s; best = [x["pos"], "uplink"]
	return best

## Where a bot holds an uplink's yard: its own spot round the mast (each squadmate in the yard adds
## to the charge rate, so they spread out instead of shoving each other off one spot).
func yard_spot(x: Dictionary, h: Hunter) -> Vector3:
	var a := float(hash(h.nid) % 6) / 6.0 * TAU
	var p: Vector3 = x["pos"] + Vector3(cos(a), 0, sin(a)) * 1.7
	if m.world.is_void(p.x, p.z) or m.world.is_block(p.x, p.z):
		p = x["pos"] + Vector3(0.0, 0, 1.6)
	return p

## A rival's loud exit close by, worth crashing (bots that like a fight go and contest it).
func bot_contest(h: Hunter, reach: float) -> Array:
	for x in list:
		if int(x.get("team", -1)) == h.team or int(x.get("team", -1)) < 0:
			continue
		var at: Vector3 = x.get("berth", x["pos"])
		if x["state"] in ["called", "boarding", "charging"] and h.flat_dist(at) < reach:
			return [at, "board" if x["kind"] == "dock" else "yard"]
	return []

# ------------------------------------------------------------------ keys
## A Rift Key dropped as loot (vaults, bosses, elite monsters).
func drop_key(at: Vector3) -> void:
	m.drop("key", at + Vector3(0, 0.6, 0), 1)

# ------------------------------------------------------------------ screenshots
## Test hook (--exit-demo=<mode>): sets up one exit in action next to the player for a screenshot.
## Modes: call (horn just sounded, waves coming), approach (the skiff flying in), board (tied up,
## you and a rival on deck), hatch (a rival drops through a hatch you're next to), uplink (charging,
## contested by a rival in the yard), lift (the uplink completes and the lift opens).
func demo(mode: String) -> void:
	var p := m.player
	if p == null or list.is_empty():
		return
	if m.has_meta("xdemo"):
		var R0 = m.get_meta("xdemo_r", null)
		for h in [p, R0]:
			if h != null and h.has_meta("pin") and not h.extracted:
				h.teleport(h.get_meta("pin")); h.vel = Vector3.ZERO
		# hold the moment: screenshots take a varying amount of game time to render
		var hold: Array = m.get_meta("xdemo_hold", [])
		if not hold.is_empty():
			var hx: Dictionary = hold[0]
			if String(hx["state"]) == String(hold[1]):
				hx[String(hold[2])] = hold[3]
		return
	m.set_meta("xdemo", true)
	var R: Hunter = null
	for h in m.hunters:
		if h == p: continue
		h.ctrl = "idle"; h.inp["move"] = Vector2.ZERO
		if R == null and h.team != p.team: R = h
		h.teleport(m.world.random_ground())
	m.set_meta("xdemo_r", R)
	p.max_hp = 5000.0; p.hp = 5000.0
	match mode:
		"call", "approach", "board":
			var d: Dictionary = of_kind("dock")[0]
			m.time = float(d["open_at"]) + 1.0
			var b: Vector3 = d["berth"]; var o3 := Vector3(d["out"].x, 0, d["out"].y)
			act(d, "call", p)
			d["wave_t"] = 0.0
			if mode == "call":
				d["t"] = 30.0
				m.set_meta("xdemo_hold", [d, "called", "t", 30.0])
				p.teleport(d["pos"] + Vector3(0.6, 0, 0.6))
			elif mode == "approach":
				d["t"] = APPROACH_T * 0.45
				m.set_meta("xdemo_hold", [d, "called", "t", APPROACH_T * 0.45])
				p.teleport(b - o3 * 4.5)
			else:
				d["t"] = 0.3
				m.set_meta("xdemo_hold", [d, "boarding", "t", 7.0])
				p.teleport(b - o3 * 0.9 + Vector3(-o3.z, 0, o3.x) * 0.5)
				if R: R.teleport(b + o3 * 1.0 + Vector3(o3.z, 0, -o3.x) * 0.6)
			m.cam.zoom_to = 0.85
		"hatch":
			var hx: Dictionary = of_kind("hatch")[0]
			p.rift_keys = 1
			p.teleport(m.world.free_spot_near(hx["pos"] + Vector3(2.2, 0, 1.2), [hx["pos"]], 1.8, 0.5, 4.0))
			if R:
				R.rift_keys = 1
				R.teleport(hx["pos"] + Vector3(-0.8, 0, -0.6))
				m.get_tree().create_timer(1.6).timeout.connect(func(): act(hx, "open", R))
				m.set_meta("xdemo_hold", [hx, "open", "t", 4.0])
			m.cam.zoom_to = 0.6
		"uplink", "lift":
			var o: Dictionary = of_kind("outpost")[0]
			m.time = float(o["open_at"]) + 1.0
			act(o, "start", p)
			o["wave_t"] = 0.0
			o["prog"] = 0.55 if mode == "uplink" else 0.93
			m.set_meta("xdemo_hold", [o, "charging", "prog", 0.55] if mode == "uplink" else [o, "open", "t", 12.0])
			p.teleport(o["pos"] + Vector3(1.5, 0, 2.2))
			if R and mode == "uplink":
				R.teleport(o["pos"] + Vector3(-2.0, 0, -1.4))
			elif R:
				R.teleport(m.world.random_ground())
			m.cam.zoom_to = 0.85
		"drain":
			# your uplink charging with nobody in its yard: the charge draining (HUD, mast, clock)
			var o: Dictionary = of_kind("outpost")[0]
			m.time = float(o["open_at"]) + 1.0
			act(o, "start", p)
			o["wave_t"] = 99.0
			o["prog"] = 0.6
			m.set_meta("xdemo_hold", [o, "charging", "prog", 0.6])
			var off := Vector3(OUTPOST_R + 1.6, 0, 1.0)
			p.teleport(m.world.free_spot_near(o["pos"] + off, [], 0.6, 0.5, 3.0))
			if R: R.teleport(m.world.random_ground())
			m.cam.zoom_to = 0.85
	p.set_meta("pin", p.pos)
	if R: R.set_meta("pin", R.pos)
	m.cam.snap(p.pos)
