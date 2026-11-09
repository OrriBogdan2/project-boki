class_name BaseLife
extends RefCounted
## Base life (briefs/design/GARDEN.md section 4), on only with farm_build.json base_mode: each farm Boki lives on
## its own through one explicit state machine (Fsm, briefs/STATE_MACHINES.md). It roams, eats at a feeder, naps
## (friends in a pile; night is nap time unless it is nocturnal, Work.NOCTURNAL), plays at a toy, plays tag with
## another Boki, stares at a rival or comes to look at a newcomer. A retired mentor (Mentor) only strolls slowly
## near the Soul Shrine (MENTOR), eats and naps, joining the piles. Tag and napping together build friendship,
## squabbles over a toy or clashing tempers build rivalry, kept as rec["bonds"] = {uid: -1..1}. Friends greet and
## nap in a pile; rivals stare and huff.
##
## The farm keeps its own drivers (a whistle, petting, a job, a bath, the house, the feeders' walk): while one of
## them has a Boki, its machine waits. home.gd asks choose() when a free Boki's think timer runs out, after its
## care and job picks; step() moves every machine on at 10 Hz. Tuning: content/rules/base_life.json.

enum S { ROAM, EAT, NAP, PLAY, PLAY_WITH, WATCH, REACT, MENTOR }
const NAMES := ["Roam", "Eat", "Nap", "Play", "PlayWith", "Watch", "React", "Mentor"]
const TABLE := {
	S.ROAM: [S.EAT, S.NAP, S.PLAY, S.PLAY_WITH, S.WATCH, S.REACT, S.MENTOR],
	S.MENTOR: [S.ROAM, S.EAT, S.NAP],
	S.EAT: [S.ROAM, S.NAP],
	S.NAP: [S.ROAM],
	S.PLAY: [S.ROAM, S.NAP, S.WATCH, S.REACT],
	S.PLAY_WITH: [S.ROAM, S.NAP, S.REACT],
	S.WATCH: [S.ROAM, S.NAP, S.REACT],
	S.REACT: [S.ROAM, S.NAP, S.WATCH],
}
const STEP := 0.1          # s: the machines tick at 10 Hz, not every frame
const TOY_SCAN := 2.0      # s between looks at the layout for placed toys
const CATCH := 0.8         # m: a tag lands this close
const AT_TOY := 1.4        # m: a Boki this close to a toy is at it (two here share it or squabble)
const GREET := 2.5         # m: friends this close greet each other
const PILE_JOIN := 1.0     # m: close enough to a napping friend to lie down with it
const PILE_WALK := 8.0     # s a Boki walks to a pile before it naps where it is
const TOY_PLAY := -1.0      # life_for while home_toys.gd (k["play"]) runs the play, not this machine
const GRUMPY := 30.0       # joy need below which a Boki naps alone

var h                      # the home (home.gd): kins, world, day_t, ppos, emotes
var R: Dictionary          # content/rules/base_life.json
var toys: Array = []       # Vector3: where the placed toys stand
var night := false
var _acc := 0.0
var _toy_t := 0.0
var _day_t := -1.0         # the farm's day clock at the last tick (a drop means a new day)
var _seen := {}            # uid -> true: every Boki this base has met (a new uid is an arrival)

func _init(home) -> void:
	h = home
	R = Content.rules("base_life")
	find_toys()

static func nocturnal(rec: Dictionary) -> bool:
	return Work.NOCTURNAL.has(String(rec["species"]))

static func bond(a: Dictionary, b: Dictionary) -> float:
	return float(a.get("bonds", {}).get(String(b["uid"]), 0.0))

## Moves both Boki's bond with each other by `by`, kept in -1..1.
static func add_bond(a: Dictionary, b: Dictionary, by: float) -> void:
	for pair in [[a, b], [b, a]]:
		var rec: Dictionary = pair[0]
		if not rec.has("bonds"):
			rec["bonds"] = {}
		var uid := String(pair[1]["uid"])
		rec["bonds"][uid] = clampf(float(rec["bonds"].get(uid, 0.0)) + by, -1.0, 1.0)

func find_toys() -> void:
	toys.clear()
	for e in HomeLayout.of(Save.d).get("deco", []):
		if (R["toys"] as Array).has(String(e.get("id", ""))) and not FarmSites.is_site(e):
			toys.append(HomeLayout.deco_center(e))

## The Boki's machine (made the first time the base sees it).
func machine(k: Dictionary) -> Fsm:
	if not k.has("life"):
		var m := Fsm.new(PackedStringArray(NAMES), TABLE, S.ROAM, "boki:" + String(k["rec"]["name"]))
		m.guard(S.PLAY, func(_from: int) -> bool: return not toys.is_empty() or k.has("play"))
		m.guard(S.PLAY_WITH, func(_from: int) -> bool: return _awake(k))
		m.guard_from(S.NAP, S.ROAM, func() -> bool: return float(k.get("nap_t", 0.0)) <= 0.0)
		m.on_enter(S.ROAM, func(_from: int) -> void: k["t"] = 0.0)
		m.on_exit(S.PLAY_WITH, func(_to: int) -> void: k.erase("life_it"))
		m.on_exit(S.NAP, func(_to: int) -> void: k.erase("life_pile"))
		k["life"] = m
	return k["life"]

## Moves every machine on; called each frame from home.gd _move_kin, ticks at 10 Hz.
func step(d: float) -> void:
	_acc += d
	_toy_t += d
	if _acc < STEP:
		return
	var dt := _acc
	_acc = 0.0
	if _toy_t >= TOY_SCAN:
		_toy_t = 0.0
		find_toys()
	night = sin((h.day_t - 0.25) * TAU) < -0.2      # the farm's own night test (home.gd _move_kin)
	if h.day_t < _day_t:
		BaseDrift.day(h.kins.map(func(k): return k["rec"]))
	_day_t = h.day_t
	for k in h.kins:
		machine(k)       # every machine first: a newcomer looks for Boki that have one
	var first_look := _seen.is_empty()      # the Boki already here when the base loads are not newcomers
	for k in h.kins:
		var uid := String(k["rec"]["uid"])
		if not _seen.has(uid):
			if not first_look:
				_arrived(k)
			_seen[uid] = true
	for k in h.kins:
		_tick(k, dt)

## Separation scale for two Boki (home.gd _separate_kin): napping friends lie close in a pile.
func pile(a: Dictionary, b: Dictionary) -> float:
	if a.has("life") and b.has("life") and (a["life"] as Fsm).is_in(S.NAP) and (b["life"] as Fsm).is_in(S.NAP) \
			and bond(a["rec"], b["rec"]) >= 0.0:
		return float(R["pile"])
	return 1.0

## One line per Boki: state, seconds in it, refusals, the last transition and its bonds (the debug readout).
func readout() -> String:
	var lines: PackedStringArray = []
	for k in h.kins:
		var m := machine(k)
		var last := m.history[m.history.size() - 1].strip_edges() if not m.history.is_empty() else ""
		var bonds: PackedStringArray = []
		for o in h.kins:
			if o != k:
				bonds.append("%s %+.2f" % [o["rec"]["name"], bond(k["rec"], o["rec"])])
		lines.append("%s %s %.0fs ref %d | %s | %s" % [k["rec"]["name"], m.state_name(), m.since, m.refused, last,
			", ".join(bonds)])
	return "\n".join(lines)

## A free roaming Boki whose think timer ran out picks what to do next (home.gd, after care and jobs).
func choose(k: Dictionary) -> void:
	var m := machine(k)
	if not m.is_in(S.ROAM) and not m.is_in(S.MENTOR):
		return
	var rec: Dictionary = k["rec"]
	var pers: Dictionary = k.get("pers", {})
	var traits: Dictionary = rec.get("traits", {})
	var bored := m.since >= float(R["max"]["roam"])
	k["t"] = randf_range(R["think"][0], R["think"][1])
	if k.has("eat"):
		m.go(S.EAT, "feeder")
		return
	if not _awake(k) or Care.need(rec, "energy") < float(R["tired_at"]):
		_nap(k, "tired")
		return
	if Mentor.is_mentor(rec):
		_mentor(k)
		return
	var near := _near(k)
	_greet(k, near)
	for o in near:
		if _dist(k, o) < GREET and bond(rec, o["rec"]) < float(R["friend_at"]) and _clash(rec, o["rec"]):
			_squabble(k, o)      # two hot tempers bump into each other
			_watch(k, o, "squabble")
			return
		if bond(rec, o["rec"]) <= float(R["rival_at"]) and randf() < 0.3 + float(traits.get("temper", 0.5)) * 0.5:
			_watch(k, o, "rival")
			return
	var mate := _mate(k, near)
	if not mate.is_empty() and (bored or randf() < float(pers.get("social", 0.22)) + bond(rec, mate["rec"]) * 0.5):
		_tag(k, mate)
		return
	if not toys.is_empty() and (bored or randf() < 0.2 + float(traits.get("curiosity", 0.5)) * 0.3):
		_play(k, toys[randi() % toys.size()])
		return
	if bored:
		_nap(k, "bored")
		return
	var here: int = h.world.island_of(k["pos"].x, k["pos"].z)
	if randf() < float(pers.get("cling", 0.25)) and h.world.island_of(h.ppos.x, h.ppos.z) == here:
		k["goal"] = h._seat(k, h.ppos, 1.5)
	else:
		k["goal"] = h.world.random_ground(maxi(here, 0))

# ------------------------------------------------------------------ per state
func _tick(k: Dictionary, dt: float) -> void:
	var m := machine(k)
	if _taken(k):
		return
	m.tick(dt)
	if not _awake(k) and not m.is_in(S.NAP):
		_nap(k, "night")
	elif float(k.get("nap_t", 0.0)) > 0.0 and not m.is_in(S.NAP):
		m.go(S.NAP, "dozed")
	if k.has("play") and m.is_in(S.ROAM) and m.go(S.PLAY, "toy"):
		k["life_for"] = TOY_PLAY      # home_toys.gd has it at a toy: the machine says so and lets go when it does
	match m.state:
		S.ROAM, S.MENTOR:
			if k.has("eat"):
				m.go(S.EAT, "feeder")
		S.EAT:
			if not k.has("eat") or m.since >= float(R["max"]["eat"]):
				k.erase("eat")
				m.go(S.ROAM, "fed")
		S.NAP:
			_nap_tick(k, m, dt)
		S.PLAY:
			_play_tick(k, m, dt)
		S.PLAY_WITH:
			_tag_tick(k, m)
		S.WATCH, S.REACT:
			_look_tick(k, m)

func _nap_tick(k: Dictionary, m: Fsm, dt: float) -> void:
	var nap := float(k.get("nap_t", 0.0))
	if k.has("life_pile") and nap <= 0.0:
		var to: Dictionary = k["life_pile"]
		k["goal"] = to["pos"]
		if _dist(k, to) < PILE_JOIN or m.since >= PILE_WALK or not (to["life"] as Fsm).is_in(S.NAP):
			k.erase("life_pile")
			_lie_down(k)
		return
	if nap <= 0.0:
		m.go(S.ROAM, "woke")
		return
	if not _awake(k):
		k["nap_t"] = maxf(nap, 2.0)      # night: it sleeps on till dawn
	for o in h.kins:
		if o != k and o.has("life") and (o["life"] as Fsm).is_in(S.NAP) and float(o.get("nap_t", 0.0)) > 0.0 \
				and _dist(k, o) < PILE_JOIN * 1.5:
			add_bond(k["rec"], o["rec"], float(R["bond_nap"]) * dt * 0.5)      # each of the pair adds half

func _play_tick(k: Dictionary, m: Fsm, dt: float) -> void:
	if float(k["life_for"]) == TOY_PLAY:
		if not k.has("play"):
			m.go(S.ROAM, "played")
		return
	var toy: Vector3 = k["life_at"]
	if Vector2(toy.x - k["pos"].x, toy.z - k["pos"].z).length() < AT_TOY:
		k["hop"] = float(k.get("hop", 0.0)) + dt * 6.0      # bounces about at it
		if randf() < 0.1:
			k["goal"] = toy + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0))
	if m.since >= float(k["life_for"]) or m.since >= float(R["max"]["play"]):
		m.go(S.ROAM, "played")

func _tag_tick(k: Dictionary, m: Fsm) -> void:
	var o: Dictionary = k["life_at"]
	var om: Fsm = o.get("life", null)
	if om == null or not om.is_in(S.PLAY_WITH) or _taken(o) or m.since >= float(k["life_for"]) \
			or m.since >= float(R["max"]["play_with"]):
		m.go(S.ROAM, "tag over")
		return
	if not k.get("life_it", false):
		var away: Vector3 = k["pos"] + Vector3(k["pos"].x - o["pos"].x, 0, k["pos"].z - o["pos"].z).normalized() * 3.0
		if not h.world.is_void(away.x, away.z):
			k["goal"] = away       # running from whoever is it
		return
	k["goal"] = o["pos"]
	if _dist(k, o) < CATCH:
		if _clash(k["rec"], o["rec"]):
			_squabble(k, o)
			m.go(S.ROAM, "squabble")
			om.go(S.ROAM, "squabble")
			return
		add_bond(k["rec"], o["rec"], float(R["bond_tag"]))
		h._emote(k, "♪")
		k.erase("life_it")
		o["life_it"] = true
		o["goal"] = o["pos"]

func _look_tick(k: Dictionary, m: Fsm) -> void:
	var at: Dictionary = k["life_at"]
	var to := Vector2(at["pos"].x - k["pos"].x, at["pos"].z - k["pos"].z)
	if m.is_in(S.REACT) and to.length() > 2.0:
		k["goal"] = at["pos"] - Vector3(to.x, 0, to.y).normalized() * 1.8       # comes over for a look
	else:
		k["goal"] = k["pos"]
		(k["node"] as Node3D).rotation.y = atan2(-to.x, -to.y)
	var cap := float(R["max"]["watch" if m.is_in(S.WATCH) else "react"])
	if m.since >= minf(float(k["life_for"]), cap):
		m.go(S.ROAM, "looked")

# ------------------------------------------------------------------ entering states
func _nap(k: Dictionary, why: String) -> void:
	var m := machine(k)
	if not m.go(S.NAP, why):
		return
	k.erase("eat")
	if Care.need(k["rec"], "joy") >= GRUMPY:
		for o in _near(k, true):
			if (o["life"] as Fsm).is_in(S.NAP) and bond(k["rec"], o["rec"]) >= float(R["friend_at"]) * 0.5:
				k["life_pile"] = o       # walks over to a napping friend (or nearly one) first
				k["t"] = PILE_WALK
				return
	_lie_down(k)

func _lie_down(k: Dictionary) -> void:
	k["nap_t"] = randf_range(R["nap"][0], R["nap"][1])
	k["slept"] = 0.0
	k["z_t"] = 0.5
	k["goal"] = k["pos"]
	k["t"] = float(k["nap_t"])

## A retired mentor: calm and slow, always near the Soul Shrine (anywhere on the farm if none is marked out).
func _mentor(k: Dictionary) -> void:
	var m := machine(k)
	if not m.is_in(S.MENTOR) and not m.go(S.MENTOR, "retired"):
		return
	k["t"] = randf_range(R["mentor"][0], R["mentor"][1])
	var shrine: Vector3 = h.lots["shrine"]["at"] if h.lots.has("shrine") else h.FAR
	if shrine == h.FAR:
		k["goal"] = h.world.random_ground(maxi(h.world.island_of(k["pos"].x, k["pos"].z), 0))
		return
	var r := float(R["mentor_radius"])
	k["goal"] = h.world.free_spot_near(shrine + Vector3(randf_range(-r, r), 0, randf_range(-r, r)), [], 0.8)

func _play(k: Dictionary, toy: Vector3) -> void:
	if not machine(k).go(S.PLAY, "toy"):
		return
	k["life_at"] = toy
	k["life_for"] = randf_range(R["play"][0], R["play"][1])
	k["t"] = float(k["life_for"])
	k["goal"] = toy
	h._emote(k, "★")
	for o in h.kins:
		if o == k or not o.has("life") or not (o["life"] as Fsm).is_in(S.PLAY) or o["life_at"] != toy:
			continue
		if _clash(k["rec"], o["rec"]) or bond(k["rec"], o["rec"]) <= float(R["rival_at"]):
			_squabble(k, o)
			if _bravery(k) >= _bravery(o):
				_watch(o, k, "lost the toy")      # the less brave one gives the toy up and glares
			else:
				_watch(k, o, "lost the toy")
		else:
			add_bond(k["rec"], o["rec"], float(R["bond_share"]))
		return

func _tag(k: Dictionary, o: Dictionary) -> void:
	var m := machine(k)
	var om := machine(o)
	if not m.can(S.PLAY_WITH) or not om.can(S.PLAY_WITH):
		return
	m.go(S.PLAY_WITH, "tag")
	om.go(S.PLAY_WITH, "tagged")
	var secs := randf_range(R["play_with"][0], R["play_with"][1])
	for pair in [[k, o], [o, k]]:
		pair[0]["life_at"] = pair[1]
		pair[0]["life_for"] = secs
		pair[0]["t"] = secs
	k["life_it"] = true
	h._emote(k, "★")

func _watch(k: Dictionary, o: Dictionary, why: String) -> void:
	if not machine(k).go(S.WATCH, why):
		return
	k["life_at"] = o
	k["life_for"] = randf_range(R["watch"][0], R["watch"][1])
	k["t"] = float(k["life_for"])
	_huff(k)

## A new Boki on the base: the ones near by come over to have a look.
func _arrived(k: Dictionary) -> void:
	for o in _near(k):
		if machine(o).can(S.REACT) and machine(o).go(S.REACT, "newcomer"):
			o["life_at"] = k
			o["life_for"] = float(R["max"]["react"])
			o["t"] = float(o["life_for"])
			h._emote(o, "!")

# ------------------------------------------------------------------ helpers
## Not asleep time: night is for napping, except for nocturnal Boki.
func _awake(k: Dictionary) -> bool:
	return not night or nocturnal(k["rec"])

## The farm's own drivers have this Boki (it was called, is held, works, bathes, is indoors or leaping).
static func _taken(k: Dictionary) -> bool:
	return k.get("busy", false) or k.has("called_t") or k.has("indoors") or k.has("leap") or k.has("job") \
		or k.has("fetch") or k.has("bath") or k.get("nap_go", false) or float(k.get("hold_t", 0.0)) > 0.0

static func _bravery(k: Dictionary) -> float:
	return float(k["rec"]["traits"].get("bravery", 0.5))

static func _dist(a: Dictionary, b: Dictionary) -> float:
	return Vector2(a["pos"].x - b["pos"].x, a["pos"].z - b["pos"].z).length()

## Other Boki within R.near on its island that the farm isn't driving (`asleep_ok`: napping ones count too).
func _near(k: Dictionary, asleep_ok := false) -> Array:
	var here: int = h.world.island_of(k["pos"].x, k["pos"].z)
	return h.kins.filter(func(o): return o != k and o.has("life") and not _taken(o) and _dist(k, o) < float(R["near"]) \
		and (asleep_ok or not (o["life"] as Fsm).is_in(S.NAP)) and h.world.island_of(o["pos"].x, o["pos"].z) == here)

## Who it would like to play tag with: a free Boki, weighted toward the ones it gets on with; never a rival.
func _mate(k: Dictionary, near: Array) -> Dictionary:
	var best := {}
	var top := -INF
	for o in near:
		var b := bond(k["rec"], o["rec"])
		var score := b + randf() * 0.6
		if b > float(R["rival_at"]) and (o["life"] as Fsm).is_in(S.ROAM) and score > top:
			top = score
			best = o
	return best

func _greet(k: Dictionary, near: Array) -> void:
	for o in near:
		if bond(k["rec"], o["rec"]) >= float(R["friend_at"]) and _dist(k, o) < GREET and randf() < 0.5:
			h._emote(k, "♥")
			return

## Two hot tempers that meet may squabble: the chance grows with how far their summed temper is over 1.0.
func _clash(a: Dictionary, b: Dictionary) -> bool:
	var over := float(a["traits"].get("temper", 0.5)) + float(b["traits"].get("temper", 0.5)) - 1.0
	return randf() < maxf(0.0, over) * float(R["clash"])

func _squabble(a: Dictionary, b: Dictionary) -> void:
	add_bond(a["rec"], b["rec"], float(R["bond_squabble"]))
	_huff(a)
	_huff(b)

func _huff(k: Dictionary) -> void:
	h._emote(k, "!", true)
	if h.fx:
		h.fx.burst(k["pos"] + Vector3(0, 0.6, 0), Color("c9c2b8"), 5, 1.6, 0.35)
