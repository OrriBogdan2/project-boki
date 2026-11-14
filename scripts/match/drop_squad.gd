class_name DropSquad
extends RefCounted
## How a squad comes down together, after SUPERVIVE's drop.
##
## A match on the big map opens with a short planning phase (PLAN_T seconds) while the skyship waits at
## the edge of the map: the full map is up, and everyone can ping where they want to land. Bots ping
## too. Then the ship sets off.
##
## Each squad has a drop leader (the person in it, else its first member). The leader decides when to
## launch: the whole squad rides one mini rocket down (DropRocket) that the leader steers. Doing nothing
## lands the squad together where it hits; anyone can jump out early, free-fall and glide on their own.
## The leader can pass the lead to a squadmate riding with them (P, or click a name on the map). Bots
## ride with their leader; a bot leader flies the rocket to its landing spot.

const PLAN_T := 8.0

var m: Match
var planning := false
var plan_t := 0.0
var plan_len := PLAN_T
var leads := {}               # team -> Hunter
var rockets := {}             # team -> DropRocket, the squad's ride down
var _bot_ping := {}           # hunter nid -> plan time left when it pings
var _ack := []                # bot acknowledgements due {h, at, id}
var clock := 0.0              # runs through the planning phase too (the match clock waits)
var events: Array = []        # what happened, for tests
var chests_hidden := false    # no chests show while you ride the ship and drop in (KeyChest.show_all)

func _init(match_node: Match) -> void:
	m = match_node

## Called once everyone is aboard.
func setup() -> void:
	var teams := {}
	for h in m.hunters:
		if not teams.has(h.team): teams[h.team] = []
		teams[h.team].append(h)
	for t in teams:
		var mem: Array = teams[t]
		var lead: Hunter = mem[0]
		if m.net_on:
			# online every client must pick the same one: the first person in the squad
			for h in mem:
				if h.ctrl != "bot": lead = h; break
		elif mem.has(m.player):
			lead = m.player
		leads[t] = lead
	if m.player and (m.player.riding or m.player.dropping):
		chests_hidden = true
		KeyChest.show_all(m, false)      # until you're down (tick)
	var o: Dictionary = m.opts
	if m.big and not m.ship.is_empty() and not o.get("no_plan", false) and not o.get("tutorial", false) and not o.get("training", false) and not o.get("duel", false):
		planning = true
		plan_len = float(o.get("plan_t", PLAN_T))
		plan_t = plan_len
		for h in m.hunters:
			if h.ctrl == "bot" and not h.remote and (h.riding or m.rolling == null):
				# leaders always ping their pick early on; the others now and then add theirs after it
				# (the value is the time left on the countdown when they ping)
				if is_lead(h):
					_bot_ping[h.nid] = maxf(0.3, randf_range(plan_len - 3.0, plan_len - 1.2))
				elif randf() < 0.35:
					_bot_ping[h.nid] = randf_range(1.2, maxf(1.3, plan_len - 3.5))

## A squad that boards later (a rolling session's drop wave): its first member leads the drop.
func add_squad(mem: Array) -> void:
	if mem.is_empty():
		return
	leads[(mem[0] as Hunter).team] = mem[0]

func leader(team: int) -> Hunter:
	var l = leads.get(team, null)
	return l if l != null and is_instance_valid(l) else null

func is_lead(h: Hunter) -> bool:
	return h != null and leader(h.team) == h

## Still waiting aboard the skyship for the leader to launch.
func waits(h: Hunter) -> bool:
	if is_lead(h):
		return false
	var l := leader(h.team)
	return l != null and l.riding and l.rocket == null and not l.out

func mates(h: Hunter) -> Array:
	return m.hunters.filter(func(x): return x != h and x.team == h.team and not x.out and not x.extracted)

# ------------------------------------------------------------------ the planning phase
func tick_plan(dt: float) -> void:
	if not planning:
		return
	plan_t -= dt
	clock += dt
	for h in m.hunters:
		if _bot_ping.has(h.nid) and plan_t <= float(_bot_ping[h.nid]):
			_bot_ping.erase(h.nid)
			_bot_plan_ping(h)
	_tick_acks()
	if plan_t <= 0.0:
		planning = false
		plan_t = 0.0
		_depart()

## A bot's choice of where to land: the leader picks the squad's spot (its landing island, now and then
## a vault close to it); anyone else suggests somewhere near the leader's pick.
func _bot_plan_ping(h: Hunter) -> void:
	var at: Vector3 = h.ai.get("land", h.pos)
	if is_lead(h):
		var human := _human_ping(h.team)
		if human != Vector3.INF:
			at = human
		elif m.biomes and randf() < HotZone.BOT_PICK and _hot_free(h):
			at = m.biomes.hot.landing()
		elif m.spawn_plan and randf() < 0.3:
			var bd := 60.0
			for c in m.spawn_plan.active_of("vault"):
				var d := Vector2((c["pos"] as Vector3).x - at.x, (c["pos"] as Vector3).z - at.z).length()
				if Bot.crowd_at(m, h, c["pos"], 25.0) > 0:
					continue      # (another squad is already going there: no pile-up on the vault)
				if d < bd: bd = d; at = c["pos"]
	else:
		var lp := _ping_of(leader(h.team))
		if lp != Vector3.INF:
			at = m.world.free_spot_near(lp + Vector3(randf_range(-9, 9), 0, randf_range(-9, 9)), [], 1.0, 0.5, 12.0)
	m.squad_ping(h, at)
	if is_lead(h):
		_set_land(h, at)

## The hot zone has a landing and no other squad is already heading there.
func _hot_free(h: Hunter) -> bool:
	var at: Vector3 = m.biomes.hot.landing()
	return at != Vector3.INF and Bot.crowd_at(m, h, at, HotZone.CROWD_R) == 0

func _depart() -> void:
	events.append("depart")
	for t in leads:
		var l := leader(int(t))
		if l == null or l.ctrl != "bot" or l.remote or not l.riding:
			continue      # (a rolling session's earlier squads are already down)
		var hp := _human_ping(l.team)
		if hp != Vector3.INF:
			_set_land(l, hp)
		m.plan_jump(l, l.ai.get("land", l.pos))

func _set_land(h: Hunter, at: Vector3) -> void:
	h.ai["land"] = at
	h.ai.erase("retarget")
	if not planning and h.riding and h.rocket == null and h.ctrl == "bot":
		m.plan_jump(h, at)

## A squad ping someone placed: a bot leader takes a person's ping as the squad's spot; the bots answer.
func on_ping(h: Hunter, at: Vector3) -> void:
	var l := leader(h.team)
	if h.ctrl != "bot" and l and l != h and l.ctrl == "bot" and not l.remote and (l.riding or l.dropping):
		_set_land(l, at)
	if h.ctrl != "bot":
		# one squad bot says it's on the way
		var bots: Array = mates(h).filter(func(x): return x.ctrl == "bot" and not x.remote)
		if not bots.is_empty():
			_ack.append({"h": bots.pick_random(), "at": clock + randf_range(0.35, 0.9), "id": "omw"})

func _tick_acks() -> void:
	for a in _ack.duplicate():
		if clock >= float(a["at"]):
			_ack.erase(a)
			var bh: Hunter = a["h"]
			if is_instance_valid(bh) and not bh.out and m.truce:
				m.truce.emote(bh, String(a["id"]))
				events.append("reply %s %s" % [bh.pname, a["id"]])

func _ping_of(h: Hunter) -> Vector3:
	if h == null:
		return Vector3.INF
	for p in m.pings:
		if p.get("by") == h:
			return p["pos"]
	return Vector3.INF

func _human_ping(team: int) -> Vector3:
	var best := Vector3.INF; var bt := 1e9
	for p in m.pings:
		var by = p.get("by")
		if by is Hunter and (by as Hunter).team == team and (by as Hunter).ctrl != "bot" and float(p["t"]) < bt:
			bt = float(p["t"]); best = p["pos"]
	return best

# ------------------------------------------------------------------ the rocket
## Launch the squad's rocket: everyone of `l`'s squad still aboard `l`'s skyship rides it down.
func launch(l: Hunter, from_net := false) -> void:
	if rockets.has(l.team) and not (rockets[l.team] as DropRocket).done:
		return
	var r := DropRocket.launch(m, l)
	rockets[l.team] = r
	events.append("launch %s +%d" % [l.pname, r.riders.size() - 1])
	if m.net_on and not from_net:
		m.net_event(["rkt", l.nid])
	if m.player and r.riders.has(m.player):
		m.sfx("whoosh", null, -2.0)
		if m.hud:
			m.hud.toast("%s to jump out  ·  then %s again for your glider" % [Settings.key_cap("jump"), Settings.key_cap("jump")], Color("cfeaff"))

## The heading the skydive camera sits behind: the squad rocket's launch heading (north-up without one).
func drop_yaw(h: Hunter) -> float:
	var r: DropRocket = rockets.get(h.team, null)
	return r.yaw if r != null else 0.0

## Jump out of your squad's rocket early.
func detach(h: Hunter) -> bool:
	if h.rocket == null:
		return false
	var ok := h.rocket.detach(h)
	if ok: events.append("detach %s" % h.pname)
	return ok

## Pass the lead to a squadmate riding with you (the next one in the squad, or the one asked for).
func pass_lead(h: Hunter, to: Hunter = null, from_net := false) -> bool:
	if from_net:
		if to != null: leads[h.team] = to      # (online the sender checked it; the flags may already be ahead)
		return to != null
	if not is_lead(h) or not h.riding:
		return false
	var pool: Array = m.hunters.filter(func(x): return x.team == h.team and not x.out and x != h and x.riding and x.rocket == h.rocket)
	if pool.is_empty():
		if h == m.player and m.hud: m.hud.toast_small("No one to lead", Color("a9b0bf"))
		return false
	if to == null or not pool.has(to):
		# the next squadmate after you, going round the squad
		var all: Array = m.hunters.filter(func(x): return x.team == h.team)
		var i0 := all.find(h)
		for k in range(1, all.size() + 1):
			var cand: Hunter = all[(i0 + k) % all.size()]
			if pool.has(cand): to = cand; break
	leads[h.team] = to
	events.append("lead %s->%s" % [h.pname, to.pname])
	if m.net_on:
		m.net_event(["lead", h.nid, to.nid])
	if m.player and m.player.team == h.team and m.hud:
		var who := "You lead" if to == m.player else "%s leads" % to.pname
		m.hud.toast_small("%s the drop" % who, Color("ffd27a"))
	if to.ctrl == "bot" and not to.remote:
		# a bot taking over flies the squad to the spot its people pinged
		var hp := _human_ping(to.team)
		if hp != Vector3.INF:
			to.ai["land"] = hp
			to.ai.erase("retarget")
		if to.riding and to.rocket == null and not planning:
			m.plan_jump(to, to.ai.get("land", to.pos))
	return true

## Every step of the match: the rockets fly; chests come back once you're down.
func tick(dt: float) -> void:
	clock += dt
	_tick_acks()
	if chests_hidden and not (m.player.riding or m.player.dropping):
		chests_hidden = false      # landed, or fell short and came back on foot
		KeyChest.show_all(m, true)
	for t in rockets.keys():
		var r: DropRocket = rockets[t]
		if not r.done:
			r.tick(dt)
