class_name QuestSeats
extends RefCounted
## The two quest seats of Limited Ways Out (spec section 11 task 4, docs/decisions/0051): the Sealed
## Lair (one lair by the match seed, open 2:00 to 5:30) and the Uplink (the outpost farther from that
## lair, 6:00 to 8:00). One squad each, used once. Exits owns them (Exits.seats; null outside the mode,
## so the tutorial and endless-clock tests keep the old exits). This is the schedule; each seat is one
## QuestSeat state machine. Times: content/rules/heart.json "quest".
## The host moves the states (polling the lair and outpost it runs on) and sends ["xc", "seat", kind,
## state, team, out]; clients mirror it. What a state does to the world (a shut lair's gate sealed
## again, a shut uplink gone dark, the finishing squad leaving) each game does for itself.

const HOW_LAIR := "lair"       # the `how` of a Hunter who left by the Sealed Lair's updraft
const UP_REACH := 0.5          # past Lairs.UP_R: standing in the updraft's column

var m: Match
var lair: QuestSeat = null
var uplink: QuestSeat = null
var built := false
var _warned := {}

func _init(match_node: Match) -> void:
	m = match_node

static func q(k: String) -> float:
	return float((Heart.rules().get("quest", {}) as Dictionary).get(k, 0.0))

func host() -> bool:
	return not m.net_on or m.is_host

func seats() -> Array:
	return [lair, uplink].filter(func(s): return s != null)

## Picks the two seats. On the first tick, not in Exits.setup: the lairs are built after the exits.
## The pick is the match seed's alone (every game makes the same one): the Sealed Lair is one of all
## the lairs (woken if the spawn plan left it asleep), the Uplink the outpost farthest from it; any
## other outpost stays dark.
func build() -> void:
	if built:
		return
	built = true
	var rng := RandomNumberGenerator.new()
	rng.seed = int(m.seed_val) * 31 + 977
	var at := Vector3.INF
	if m.lairs and not m.lairs.list.is_empty():
		var L: Dictionary = m.lairs.list[rng.randi_range(0, m.lairs.list.size() - 1)]
		m.lairs.activate(L)
		L["seat"] = true
		L["seat_open"] = q("lair_open_s") - m.sess_t0      # (match times WaysOutLook reads)
		L["shut_at"] = q("lair_shut_s") - m.sess_t0
		at = L["c"]
		lair = QuestSeat.new(m, "lair", L, q("lair_open_s"), q("lair_shut_s"))
	var outs: Array = m.exits.of_kind("outpost")
	if outs.is_empty():
		return
	var x: Dictionary = outs[rng.randi_range(0, outs.size() - 1)]
	if at != Vector3.INF:
		for o in outs:
			if (o["pos"] as Vector3).distance_to(at) > (x["pos"] as Vector3).distance_to(at) + 0.01:
				x = o
	for o in outs:
		o["dark"] = not is_same(o, x)
	x["seat"] = true
	x["open_at"] = q("uplink_open_s") - m.sess_t0
	x["shut_at"] = q("uplink_shut_s") - m.sess_t0
	uplink = QuestSeat.new(m, "uplink", x, q("uplink_open_s"), q("uplink_shut_s"))

## The outpost the Uplink runs on (before the pick: the first outpost, the old rule).
func uplink_x() -> Dictionary:
	build()
	return uplink.ref if uplink else {}

func tick(_dt: float) -> void:
	build()
	var t := m.sess_time()
	if host():
		if lair: _host_lair(lair, t)
		if uplink: _host_uplink(uplink, t)
	for s: QuestSeat in seats():
		_apply(s)
		var warn: float = s.shut_s - q("warn_before_shut_s")
		if s.state in [QuestSeat.S.OPEN, QuestSeat.S.IN_USE] and t >= warn and t < s.shut_s and not _warned.has(s.kind):
			_warned[s.kind] = true
			m.add_feed("%s shuts in %ds" % [s.title().capitalize(), int(s.shut_s - t)])
			if m.hud and m.player and not m.player.out and not m.player.extracted:
				var col: Color = ExitModels.UPLINK if s.kind == "uplink" else Lairs.color_of(s.ref)
				m.hud.toast_small("%s shuts in %ds" % [s.title().capitalize(), int(s.shut_s - t)], col)

# ------------------------------------------------------------------ the host's moves
func _move(s: QuestSeat, to: QuestSeat.S, why: String, team := -1) -> void:
	if s.go(to, why, team):
		_send(s)

## Opening time, or past the shut while still LOCKED (a session joined late): the clock's move.
func _clock(s: QuestSeat, t: float) -> void:
	if t >= s.open_s:
		_move(s, QuestSeat.S.OPEN if t < s.shut_s else QuestSeat.S.SHUT, "clock")

func _host_lair(s: QuestSeat, t: float) -> void:
	var L: Dictionary = s.ref
	match s.state:
		QuestSeat.S.LOCKED:
			_clock(s, t)
		QuestSeat.S.OPEN, QuestSeat.S.IN_USE:
			if L["state"] == "cleared":
				var won := int(L.get("won_by", -1))
				_move(s, QuestSeat.S.TAKEN, "kill", won if won >= 0 else s.team)
			elif s.state == QuestSeat.S.OPEN and L.get("locked", false) and not (L["sealed_in"] as Array).is_empty():
				_move(s, QuestSeat.S.IN_USE, "sealed", int((L["sealed_in"] as Array)[0].team))
			elif s.state == QuestSeat.S.IN_USE and not L.get("locked", false):
				# the fight was lost (everyone in it down or out, or LOCK_T ran out): open again, if there's time
				_move(s, QuestSeat.S.OPEN if t < s.shut_s else QuestSeat.S.SHUT, "reset")
			elif s.state == QuestSeat.S.OPEN and t >= s.shut_s:
				_move(s, QuestSeat.S.SHUT, "clock")
		QuestSeat.S.TAKEN:
			# the squad leaves the moment one of it steps into the updraft, or when the victory window
			# ends (the lever, the clock, or a kill without the seal)
			if not s.out and (not L.get("victory", false) or _riding(L, s.team)):
				s.out = true
				_send(s)

func _host_uplink(s: QuestSeat, t: float) -> void:
	var x: Dictionary = s.ref
	var st := String(x["state"])
	match s.state:
		QuestSeat.S.LOCKED:
			_clock(s, t)
		QuestSeat.S.OPEN, QuestSeat.S.IN_USE:
			if st == "open":
				_move(s, QuestSeat.S.TAKEN, "lift", int(x["team"]))
			elif st == "charging" and t >= s.shut_s:
				_move(s, QuestSeat.S.SHUT, "clock")
			elif st == "charging" and s.state == QuestSeat.S.OPEN:
				_move(s, QuestSeat.S.IN_USE, "start", int(x["team"]))
			elif st == "charging" and s.team != int(x["team"]):
				s.team = int(x["team"])      # a rival held the yard alone and took it over
				s.trail.append("%7.2f IN_USE team %d steal" % [m.time, s.team])
				_send(s)
			elif st != "charging" and s.state == QuestSeat.S.IN_USE:
				_move(s, QuestSeat.S.OPEN if t < s.shut_s else QuestSeat.S.SHUT, "fizzle")
			elif s.state == QuestSeat.S.OPEN and t >= s.shut_s:
				_move(s, QuestSeat.S.SHUT, "clock")

## Is one of this squad in the lair's updraft column (any Hunter, a client's too: by where it is)?
func _riding(L: Dictionary, team: int) -> bool:
	var u: Vector3 = L["up"]
	for h in m.hunters:
		if h.team != team or h.out or h.extracted:
			continue
		if (L.get("flown", []) as Array).has(h) or (L.get("escaped", []) as Array).has(h):
			return true
		var in_col := Vector2(h.pos.x - u.x, h.pos.z - u.z).length() < Lairs.UP_R + UP_REACH
		if in_col and h.pos.y > u.y - 1.0 and h.pos.y < u.y + Lairs.UP_TOP + 1.5:
			return true
	return false

# ------------------------------------------------------------------ net
func _send(s: QuestSeat) -> void:
	if m.net_on and m.is_host:
		m.net_event(["xc", "seat", s.kind, int(s.state), s.team, s.out])

## ["xc", "seat", kind, state, team, out] from the host.
func net_in(e: Array) -> void:
	if host() or e.size() < 6:
		return
	build()
	var s: QuestSeat = {"lair": lair, "uplink": uplink}.get(String(e[2]))
	if s == null:
		return
	var to := int(e[3])
	if to != int(s.state):
		s._force(to as QuestSeat.S, "host", int(e[4]))
	s.team = int(e[4])
	s.out = bool(e[5])

# ------------------------------------------------------------------ what a state does (each game)
var _left := {}

func _apply(s: QuestSeat) -> void:
	if s.kind == "lair":
		var L: Dictionary = s.ref
		match s.state:
			QuestSeat.S.OPEN:
				if L.has("open_wait"):
					# its gate was cracked while it was still locked: it opens now
					var w: Array = L["open_wait"]
					L.erase("open_wait")
					m.lairs.open(L, w[0] if is_instance_valid(w[0]) else null, String(w[1]))
			QuestSeat.S.SHUT:
				L.erase("open_wait")
				if L["state"] == "open" and not L.get("locked", false):
					_reseal(L)
			QuestSeat.S.TAKEN:
				if s.out and not _left.has("lair"):
					_left["lair"] = true
					_leave_lair(s)
	else:
		var x: Dictionary = s.ref
		if s.state == QuestSeat.S.TAKEN and not _left.has("uplink"):
			_left["uplink"] = true
			x["t"] = maxf(float(x["t"]), Heart.r("late_s"))      # the lift stays open for the squad's late members
			var os: OneSeat = m.exits.one_seat
			os.taken("uplink", s.team, String(x["name"]), ExitModels.UPLINK, x["pos"], m.exits.in_lift.bind(x))
		if s.state == QuestSeat.S.SHUT and String(x["state"]) in ["idle", "charging", "fizzling", "spent"]:
			m.exits.close_outpost(x)

## The finishing squad leaves by the Sealed Lair: this game's own Hunters of it that are in the lair,
## on the updraft or just thrown out over the wall by it (downed ones too).
func _leave_lair(s: QuestSeat) -> void:
	var L: Dictionary = s.ref
	for h in m.hunters:
		if h.team == s.team and not h.remote and not h.out and not h.extracted and at_lair(h, L):
			m._extract(h, HOW_LAIR, String(L["name"]))
	m.exits.one_seat.taken(HOW_LAIR, s.team, String(L["name"]), Lairs.color_of(L), L["up"], at_lair.bind(L))

## In the lair, on its updraft or just thrown out over the wall by it.
func at_lair(h: Hunter, lair_d: Dictionary) -> bool:
	var gone: bool = (lair_d.get("flown", []) as Array).has(h) or (lair_d.get("escaped", []) as Array).has(h)
	return gone or m.lairs.inside(lair_d, h.pos, 0.5)

## The Sealed Lair shut unused: its gate closes again (Lairs._tick_seal walks anyone inside out).
func _reseal(L: Dictionary) -> void:
	L["state"] = "sealed"
	L["user"] = null
	var w := m.world
	for qq in L["gate_tiles"]:
		w.kind[w.idx(qq.x, qq.y)] = World.T_BLOCK
	(L["nodes"]["label"] as Label3D).text = "%s\nShut" % L["name"]
	m.sfx("boom", L["gate_c"], 0.0, 0.5)

# ------------------------------------------------------------------ asked by lairs.gd and exits.gd
## Why this lair's gate can't open now ("" when it can): the Sealed Lair before 2:00 or after it shut.
func lair_wait(L: Dictionary) -> String:
	if lair == null or not is_same(L, lair.ref):
		return ""
	match lair.state:
		QuestSeat.S.LOCKED:
			return "The Sealed Lair opens in %s" % _cap(lair.open_s - m.sess_time())
		QuestSeat.S.SHUT, QuestSeat.S.TAKEN:
			return "The Sealed Lair has shut"
	return ""

## Lairs.open asks: false keeps the gate shut (a locked seat remembers who cracked it, for 2:00).
func lair_may_open(L: Dictionary, by: Hunter, how: String) -> bool:
	var why := lair_wait(L)
	if why == "":
		return true
	if lair.state == QuestSeat.S.LOCKED:
		L["open_wait"] = [by, how]
	return false

## Why this outpost can't be started ("" when the old rules decide): a dark one, or the Uplink shut.
func uplink_wait(x: Dictionary) -> String:
	if x.get("dark", false):
		if uplink == null:
			return "This outpost is dark"
		return "This outpost is dark  ·  the Uplink is at %s" % String(uplink.ref["name"])
	if uplink and is_same(x, uplink.ref) and uplink.state in [QuestSeat.S.TAKEN, QuestSeat.S.SHUT]:
		return "The Uplink has shut"
	return ""

## The uplink may be started: in its window and not taken or shut (by the clock, so a client's mirror
## a moment behind the host doesn't refuse a start the host allowed).
func may_start(x: Dictionary) -> bool:
	if uplink_wait(x) != "":
		return false
	if uplink == null or not is_same(x, uplink.ref):
		return true
	var t := m.sess_time()
	return t >= uplink.open_s and t < uplink.shut_s

func _cap(s: float) -> String:
	s = maxf(0.0, s)
	return "%d:%02d" % [int(s) / 60, int(s) % 60]
