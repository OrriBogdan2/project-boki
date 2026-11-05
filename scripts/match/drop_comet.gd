class_name DropComet
extends RefCounted
## A squad's comet on the way down (docs/decisions/0012): the jumpmaster (the squad's drop leader)
## freefalls as usual (SkyFall) and the riders are carried inside, a little round them. A rider can
## break away (DropSquad.separate), never back in. Near the ground it bursts: everyone still in is
## flung onto their own spot round its landing point, on solid ground, and lands there.
## Online the jumpmaster's game runs the comet; boarding ("comet") and the burst ("cburst") are sent
## so every game knows who rides it and where it came down. Break-aways go as DropSquad's "dsep".

## m over the ground below: the comet bursts (above SkyFall.DEPLOY_H)
static var BURST_H: float = DropData.rules["burst_h"]
const SPOT_GAP := 2.2         # m between the burst's landing spots
const BURST_ARC := 1.6        # m: the hop out of the burst, over the straight line down
const BOT_BREAK_CHANCE := 0.4 # a bot rider picks a break-off height this often
## Where riders sit round the jumpmaster: (to the side, behind, up) in metres, turned with the heading.
const SEATS := [Vector3(-0.8, 0.3, 0.25), Vector3(0.8, 0.3, 0.25), Vector3(0.0, 0.85, -0.2), Vector3(0.0, -0.7, 0.35)]

## What a rider can't use in the comet.
const HELD_KEYS := ["jump", "dash", "sig", "sec", "reload", "util1", "util2", "util3", "util4", "ult", "fire", "skill",
	"swap", "gear1", "gear2"]

var squad: DropSquad
var m: Match
var comets := {}              # team -> {"lead": Hunter, "riders": Array of Hunter}

func _init(drop_squad: DropSquad) -> void:
	squad = drop_squad
	m = drop_squad.m

## Is h in a comet (steering it or riding it)?
func has(h: Hunter) -> bool:
	return h.comet_lead != null or leads(h)

## Is h the jumpmaster of a comet with riders in it?
func leads(h: Hunter) -> bool:
	return comets.has(h.team) and comets[h.team]["lead"] == h

## The riders of `team`'s comet (empty when it has none).
func riders(team: int) -> Array:
	return comets[team]["riders"] if comets.has(team) else []

## r climbs into l's comet (on the jump, or online when l jumped in their own game).
func board(l: Hunter, r: Hunter, from_net := false) -> void:
	if r.drop_solo or r == l:
		return
	if not comets.has(l.team):
		comets[l.team] = {"lead": l, "riders": []}
	var c: Dictionary = comets[l.team]
	if (c["riders"] as Array).has(r):
		return
	(c["riders"] as Array).append(r)
	r.comet_lead = l
	if not r.remote:
		_seat(r)
		r.vel = l.vel
		if r.ctrl == "bot":
			# some bots leave the comet on the way down for a spot of their own
			var top := SkyFall.SKY_Y - 20.0
			r.ai["break_y"] = randf_range(BURST_H + 30.0, top) if randf() < BOT_BREAK_CHANCE else -1.0
	if m.net_on and not from_net and not r.remote:
		m.net_event(["comet", l.nid, r.nid])

## A rider's step: carried in its seat. Space breaks away; nothing else can be used in here.
func ride(r: Hunter) -> void:
	var l := r.comet_lead
	if not is_instance_valid(l) or l.out or not leads(l):
		_drop_out(r)
		return
	if not l.dropping:
		if l.remote:
			_burst_one(r, _members(l.team).find(r), _ground_point(l))      # (its burst event hasn't reached us)
		return      # (here the jumpmaster just left the drop: tick hands the comet on)
	_seat(r)
	r.vel = l.vel
	r.fall_dir = l.fall_dir
	r.face = l.face
	r.diving = l.diving
	r.gliding = true
	if r.ctrl == "local" and r.inp["jump"]:
		squad.separate(r)
	for k in HELD_KEYS:
		r.inp[k] = false

## r leaves the comet into a solo freefall, peeling off to the side.
func leave(r: Hunter) -> void:
	if leads(r):
		_promote(r.team)
	var c: Dictionary = comets.get(r.team, {})
	if c.is_empty():
		return
	(c["riders"] as Array).erase(r)
	r.comet_lead = null
	var side := Vector2(-r.fall_dir.y, r.fall_dir.x) * (1.0 if r.nid.hash() % 2 == 0 else -1.0)
	r.vel += Vector3(side.x, 1.5, side.y) * 4.0
	r.fall_dir = (r.fall_dir + side * 0.5).normalized()
	if (c["riders"] as Array).is_empty():
		comets.erase(r.team)

## The comet changes hands in the air: `to` (a rider) steers it from now on, `from` rides.
func hand_over(from: Hunter, to: Hunter) -> void:
	var c: Dictionary = comets.get(from.team, {})
	if c.is_empty() or c["lead"] != from:
		return
	var rs: Array = c["riders"]
	rs.erase(to)
	to.comet_lead = null
	to.fall_dir = from.fall_dir
	c["lead"] = to
	for r in rs:
		r.comet_lead = to
	if not from.drop_solo:
		rs.push_front(from)
		from.comet_lead = to

## Every step: riders who are gone come out, the comet bursts near the ground, bots break away.
func tick() -> void:
	for t in comets.keys():
		var c: Dictionary = comets[t]
		var l: Hunter = c["lead"]
		var rs: Array = c["riders"]
		for r in rs.duplicate():
			if not is_instance_valid(r) or r.out or r.comet_lead != l:
				rs.erase(r)
		if rs.is_empty():
			comets.erase(t)
			continue
		if not is_instance_valid(l) or l.out or (not l.dropping and not l.remote):
			_promote(int(t))      # the jumpmaster is gone or fell out of the drop
			continue
		if not l.remote and SkyFall.height_over(m.world, l.pos) < BURST_H:
			burst(int(t))
			continue
		for r in rs.duplicate():
			if r.ctrl == "bot" and not r.remote and l.pos.y < float(r.ai.get("break_y", -1.0)):
				r.ai["land"] = _own_spot(r, l)
				r.ai.erase("retarget")
				squad.separate(r)
	for h in m.hunters:
		if h.drop_glide and h.grounded and h.pad.is_empty() and not h.remote:
			SkyFall.land(h)

## The jumpmaster's keys when the comet would come down over the abyss: for the nearest island,
## whatever is pressed (SkyFall.steer).
func steer_off_abyss(l: Hunter, mv: Vector2) -> Vector2:
	if not leads(l):
		return mv
	var land := SkyFall.land_if_void(m, l, BURST_H)
	return SkyFall.keys_toward(l, land) if land != Vector3.INF else mv

## The comet bursts: everyone in it in this game is flung onto their own spot round its ground point.
func burst(team: int, at := Vector3.INF, from_net := false) -> void:
	if not comets.has(team):
		return
	var l: Hunter = comets[team]["lead"]
	var ground := at if at != Vector3.INF else _ground_point(l)
	var mem := _members(team)
	for i in mem.size():
		var h: Hunter = mem[i]
		if not h.remote:
			_burst_one(h, i, ground)
	comets.erase(team)
	squad.events.append("burst %s %d" % [l.pname, mem.size()])
	m.fx.burst(l.pos + Vector3(0, 0.9, 0), Color(1.0, 0.55, 0.2), 30, 12.0, 0.7, 4.0, 1.8)
	m.fx.burst(l.pos + Vector3(0, 0.9, 0), Color(1.0, 0.85, 0.5), 14, 6.0, 0.4, 0.0, 1.2)
	m.fx.ring(ground + Vector3(0, 0.1, 0), 4.0, Color(1.0, 0.6, 0.3, 0.8), 0.5)
	m.sfx("boom", l.pos, -6.0 if m.player and m.player.team == team else -14.0, 0.75)
	m.sfx("whoosh", l.pos, -4.0, 0.8)
	if m.net_on and not from_net and not l.remote:
		m.net_event(["cburst", l.nid, snappedf(ground.x, 0.01), snappedf(ground.y, 0.01), snappedf(ground.z, 0.01)])

## The landing spots round `ground` for n hunters: on open, solid ground, SPOT_GAP apart.
func spots(ground: Vector3, n: int) -> Array:
	var out: Array = []
	for i in n:
		var a := TAU * i / maxf(1.0, n) + 0.4
		var want := ground + (Vector3(cos(a), 0.0, sin(a)) * SPOT_GAP * 0.75 if n > 1 else Vector3.ZERO)
		var p := m.world.free_spot_near(want, out, SPOT_GAP, 0.45, 8.0)
		if m.world.is_void(p.x, p.z):
			p = ground
		out.append(Vector3(p.x, m.world.ground_at(p.x, p.z), p.z))
	return out

## A comet event from another game: someone boarded, or it burst.
func net_in(x: Array) -> void:
	var l: Hunter = m.ents_by_id.get(String(x[1]), null) as Hunter
	if l == null:
		return
	if String(x[0]) == "comet" and x.size() >= 3:
		var r: Hunter = m.ents_by_id.get(String(x[2]), null) as Hunter
		if r:
			board(l, r, true)
	elif String(x[0]) == "cburst" and x.size() >= 5:
		burst(l.team, Vector3(float(x[2]), float(x[3]), float(x[4])), true)

# ------------------------------------------------------------------ inside
## The jumpmaster first, then the riders by id: the same order (and so the same spots) in every game.
func _members(team: int) -> Array:
	if not comets.has(team):
		return []
	var rs: Array = (comets[team]["riders"] as Array).duplicate()
	rs.sort_custom(func(a, b): return String(a.nid) < String(b.nid))
	return [comets[team]["lead"]] + rs

func _seat(r: Hunter) -> void:
	var l := r.comet_lead
	var i := maxi(0, riders(l.team).find(r)) % SEATS.size()
	var s: Vector3 = SEATS[i]
	var fwd := l.fall_dir if l.fall_dir.length() > 0.01 else Vector2(0, -1)
	var side := Vector2(-fwd.y, fwd.x)
	var across := side * s.x - fwd * s.z
	r.pos = l.pos + Vector3(across.x, s.y, across.y)

## Where the comet comes down: the ground under it, or the nearest island when it's over the abyss.
func _ground_point(l: Hunter) -> Vector3:
	if not m.world.is_void(l.pos.x, l.pos.z):
		return Vector3(l.pos.x, m.world.ground_at(l.pos.x, l.pos.z), l.pos.z)
	var land := SkyFall.nearest_land(m, l.pos)
	return land if land != Vector3.INF else l.pos

## h out of the burst: onto spot i round `ground`, on a short sure arc, and the drop's landing kick there.
func _burst_one(h: Hunter, i: int, ground: Vector3) -> void:
	var all := spots(ground, maxi(i + 1, _members(h.team).size()))
	var to: Vector3 = all[clampi(i, 0, all.size() - 1)]
	h.comet_lead = null
	h.dropping = false
	h.diving = false
	h.gliding = false
	h.drop_glide = true
	h.ai["land"] = to
	var across := Vector2(to.x - h.pos.x, to.z - h.pos.z).length()
	h.pad = {"from": h.pos, "to": to, "t": 0.0, "dur": clampf(0.9 + across / 12.0, 1.1, 2.6), "h": BURST_ARC}

## The first rider takes `team`'s comet from its jumpmaster, who is out of it.
func _promote(team: int) -> void:
	var c: Dictionary = comets[team]
	var rs: Array = c["riders"]
	var old = c["lead"]
	var nl: Hunter = rs.pop_front()
	nl.comet_lead = null
	if is_instance_valid(old):
		nl.fall_dir = (old as Hunter).fall_dir
	c["lead"] = nl
	for r in rs:
		r.comet_lead = nl
	squad.leads[team] = nl
	if rs.is_empty():
		comets.erase(team)

## A rider whose comet is gone (its jumpmaster left the match): a solo freefall from here.
func _drop_out(r: Hunter) -> void:
	r.comet_lead = null
	r.drop_solo = true

## A bot breaking away picks a spot of its own in reach, away from where its squad is heading.
func _own_spot(r: Hunter, l: Hunter) -> Vector3:
	var squad_spot: Vector3 = l.ai.get("land", l.pos)
	var reach := (r.pos.y - SkyFall.DEPLOY_H) * SkyFall.FLOAT_SPEED / SkyFall.FLOAT_FALL * 0.7
	var picks: Array = (m.world.spawns + m.world.portal_spots).filter(func(sp):
		var d := Vector2(sp.x - r.pos.x, sp.z - r.pos.z).length()
		return d < reach and Vector2(sp.x - squad_spot.x, sp.z - squad_spot.z).length() > 18.0)
	return picks.pick_random() if not picks.is_empty() else squad_spot
