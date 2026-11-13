class_name BaseLife
extends RefCounted
## Base life (briefs/design/GARDEN.md section 4), on only with farm_build.json base_mode: each farm Boki lives on
## its own through one explicit state machine (Fsm, briefs/STATE_MACHINES.md). It roams, eats (at a feeder, or a
## snack from the patch or the pantry when it is hungry and no feeder has food: BaseFeed), naps
## (friends in a pile; night is nap time unless it is nocturnal, Work.NOCTURNAL), plays at a toy, plays tag with
## another Boki, stares at a rival or comes to look at a newcomer. A retired mentor (Mentor) only strolls slowly
## near the Soul Shrine (MENTOR), eats and naps, joining the piles. The toys are HomeToys' (k["play"]: it picks,
## walks, plays, squabbles and shares); the machine asks it when bored or curious and shows Play while it owns
## the Boki, so there is one toy system. Tag and napping together build friendship,
## squabbles over a toy or clashing tempers build rivalry, kept as rec["bonds"] = {uid: -1..1}. Friends greet and
## nap in a pile; rivals stare and huff. A Boki that would thrive in another open zone sometimes goes
## and waits at the return pad with a bubble: it looks at the pad (HubWaystone.pad) the way it comes
## to look at a newcomer, and E on it sends it (HubWaystone.answer); ignored, it wanders off.
##
## The farm keeps its own drivers (a whistle, petting, a job, a bath, the house, the feeders' walk): while one of
## them has a Boki, its machine waits. home.gd asks choose() when a free Boki's think timer runs out, after its
## care and job picks; step() moves every machine on at 10 Hz. Tuning: content/rules/base_life.json.

enum S { ROAM, EAT, NAP, PLAY, PLAY_WITH, WATCH, REACT, MENTOR, CHORE, LEAD }
const NAMES := ["Roam", "Eat", "Nap", "Play", "PlayWith", "Watch", "React", "Mentor", "Chore", "Lead"]
const TABLE := {
	S.ROAM: [S.EAT, S.NAP, S.PLAY, S.PLAY_WITH, S.WATCH, S.REACT, S.MENTOR, S.CHORE, S.LEAD],
	S.LEAD: [S.ROAM, S.NAP],
	S.MENTOR: [S.ROAM, S.EAT, S.NAP],
	S.EAT: [S.ROAM, S.NAP],
	S.NAP: [S.ROAM],
	S.PLAY: [S.ROAM, S.NAP, S.WATCH, S.REACT],
	S.PLAY_WITH: [S.ROAM, S.NAP, S.REACT],
	S.WATCH: [S.ROAM, S.NAP, S.REACT],
	S.REACT: [S.ROAM, S.NAP, S.WATCH],
	S.CHORE: [S.ROAM, S.NAP, S.REACT],
}
const STEP := 0.1          # s: the machines tick at 10 Hz, not every frame
const CATCH := 0.8         # m: a tag lands this close
const GREET := 2.5         # m: friends this close greet each other
const PILE_JOIN := 1.0     # m: close enough to a napping friend to lie down with it
const PILE_WALK := 8.0     # s a Boki walks to a pile before it naps where it is
const GRUMPY := 30.0       # joy need below which a Boki naps alone

var h                      # the home (home.gd): kins, world, day_t, ppos, emotes
var R: Dictionary          # content/rules/base_life.json
var night := false
var _acc := 0.0
var _day_t := -1.0         # the farm's day clock at the last tick (a drop means a new day)
var _seen := {}            # uid -> true: every Boki this base has met (a new uid is an arrival)
var _asked := {}           # uid -> true: already asked to move to another zone since the base loaded
var whistle: BaseWhistle   # the whistle: your partner comes, hold for the nearest other Boki

func _init(home) -> void:
	h = home
	R = Content.rules("base_life")
	whistle = BaseWhistle.new(home, R)

static func nocturnal(rec: Dictionary) -> bool:
	return Work.NOCTURNAL.has(String(rec["species"]))

static func bond(a: Dictionary, b: Dictionary) -> float:
	return float(a.get("bonds", {}).get(String(b["uid"]), 0.0))

## How much `k` likes `o` for greeting and napping: the bond, plus a weight if `o` is a parent of the young `k`.
static func regard(k: Dictionary, o: Dictionary, parent_weight: float) -> float:
	return bond(k["rec"], o["rec"]) + (parent_weight if Parentage.is_parent_of(o["rec"], k["rec"]) else 0.0)

## A young Boki's first greeting or nap with a parent goes in its journal, once (`what`: what it did).
static func note_parent(k: Dictionary, o: Dictionary, what: String) -> void:
	if not Parentage.is_parent_of(o["rec"], k["rec"]): return
	for m in k["rec"]["memory"]:
		if m["kind"] == "parent": return
	Save.remember(k["rec"], "parent", "%s %s, its parent" % [what, o["rec"]["name"]], 0.5)

## Moves both Boki's bond with each other by `by`, kept in -1..1.
static func add_bond(a: Dictionary, b: Dictionary, by: float) -> void:
	for pair in [[a, b], [b, a]]:
		var rec: Dictionary = pair[0]
		if not rec.has("bonds"):
			rec["bonds"] = {}
		var uid := String(pair[1]["uid"])
		rec["bonds"][uid] = clampf(float(rec["bonds"].get(uid, 0.0)) + by, -1.0, 1.0)

## Where the base's toys stand (HomeToys, toys.json), for the chores that borrow one (BaseChore fetch).
func toy_spots() -> Array:
	return h.toys.toys().map(func(t): return t["pos"])

## The Boki's machine (made the first time the base sees it).
func machine(k: Dictionary) -> Fsm:
	if not k.has("life"):
		var m := Fsm.new(PackedStringArray(NAMES), TABLE, S.ROAM, "boki:" + String(k["rec"]["name"]))
		m.guard(S.PLAY, func(_from: int) -> bool: return k.has("play"))
		m.guard(S.PLAY_WITH, func(_from: int) -> bool: return _awake(k))
		m.guard(S.CHORE, func(_from: int) -> bool: return k.has("life_chore"))
		m.guard_from(S.NAP, S.ROAM, func() -> bool: return float(k.get("nap_t", 0.0)) <= 0.0)
		m.on_enter(S.ROAM, func(_from: int) -> void: k["t"] = 0.0)
		m.on_exit(S.PLAY_WITH, func(_to: int) -> void: k.erase("life_it"))
		m.on_exit(S.NAP, func(_to: int) -> void:
			k.erase("life_pile")
			BaseDuo.woke(k))
		m.on_exit(S.CHORE, func(_to: int) -> void: BaseChore.end(k))
		m.on_exit(S.EAT, func(_to: int) -> void: k.erase("life_eat"))
		k["life"] = m
	return k["life"]

## How fast `rec` loses joy: a Boki thriving in this zone loses it more slowly (garden_zones.json thrive).
static func joy_rate(rec: Dictionary) -> float:
	return float(GardenZones.rules()["thrive"]["joy_rate"]) if GardenZones.thrives(rec) else 1.0

## Moves every machine on; called each frame from home.gd _move_kin, ticks at 10 Hz.
func step(d: float) -> void:
	whistle.step(d)
	_acc += d
	if _acc < STEP:
		return
	var dt := _acc
	_acc = 0.0
	night = sin((h.day_t - 0.25) * TAU) < -0.2      # the farm's own night test (home.gd _move_kin)
	if h.day_t < _day_t:
		BaseDrift.day(h.kins.map(func(k): return k["rec"]))
		for k in h.kins:
			GardenItems.day(k["rec"])
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
		BaseShy.tick(h, k, dt)
		_tick(k, dt)
	GardenVisitor.step(h, dt)
	if h.hway:
		h.hway.step(dt)

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
		var state := (m.state_name() + " " + BaseChore.label(k)).strip_edges()
		lines.append("%s %s %.0fs ref %d | %s | %s" % [k["rec"]["name"], state, m.since, m.refused, last,
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
	if BaseFeed.pick(h, k):
		m.go(S.EAT, "feeder" if k.has("eat") else "snack")      # hungry: a bowl, or a snack it fetches itself
		return
	if not _awake(k) or Care.need(rec, "energy") < float(R["tired_at"]):
		_nap(k, "tired")
		return
	if Mentor.is_mentor(rec):
		_mentor(k)
		return
	if BaseShy.keep_to_edge(h, k):
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
	if _ask(k):
		return
	if randf() < float(R["chore_chance"]) and _chore(k):
		return
	var mate := _mate(k, near)
	if not mate.is_empty() and (bored or randf() < float(pers.get("social", 0.22)) + bond(rec, mate["rec"]) * 0.5):
		_tag(k, mate)
		return
	if (bored or randf() < 0.2 + float(traits.get("curiosity", 0.5)) * 0.3) and h.toys.pick(k, true):
		m.go(S.PLAY, "toy")      # HomeToys has it now: the walk, the play and the squabbles are its
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
	if k.has("play") and m.is_in(S.ROAM):
		m.go(S.PLAY, "toy")      # home_toys.gd took it to a toy (home.gd _care_goal): the machine says so
	elif m.is_in(S.ROAM) and BaseTutLead.target(h, k).x != INF:
		m.go(S.LEAD, "tutorial")      # the base tutorial's step is up: your Boki leads (BaseTutLead)
	match m.state:
		S.ROAM, S.MENTOR:
			if k.has("eat"):
				m.go(S.EAT, "feeder")
		S.EAT:
			if k.has("life_eat"):
				if not BaseFeed.tick(h, k, m.since) or m.since >= float(R["max"]["eat"]):
					m.go(S.ROAM, "fed")
			elif not k.has("eat") or m.since >= float(R["max"]["eat"]):
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
		S.CHORE:
			BaseChore.tick(self, k, m, dt)
		S.LEAD:
			if not BaseTutLead.tick(h, k):
				m.go(S.ROAM, "led")

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
			GardenFirstDay.mark("nap", h)
			add_bond(k["rec"], o["rec"], float(R["bond_nap"]) * dt * 0.5)      # each of the pair adds half
			BaseDuo.nap_beside(k, o, dt)

## HomeToys runs the play (walk, play, squabble, finish); the machine only shows it and lets go when it is done.
func _play_tick(k: Dictionary, m: Fsm, _dt: float) -> void:
	if not k.has("play"):
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
	if h.hway and is_same(at, h.hway.pad):
		cap = float(k["life_for"])      # an ask at the pad waits its whole time
	if m.since >= minf(float(k["life_for"]), cap):
		m.go(S.ROAM, "looked")

# ------------------------------------------------------------------ entering states
func _nap(k: Dictionary, why: String) -> void:
	var m := machine(k)
	if not m.go(S.NAP, why):
		return
	k.erase("eat")
	if Care.need(k["rec"], "joy") >= GRUMPY:
		var best := {}
		var top := float(R["friend_at"]) * 0.5
		for o in _near(k, true):
			var liking := regard(k, o, float(R["parent_weight"]))
			if (o["life"] as Fsm).is_in(S.NAP) and liking >= top:
				top = liking
				best = o
		if not best.is_empty():
			k["life_pile"] = best       # walks over to the napping friend it likes most (a parent first) before it naps
			k["t"] = PILE_WALK
			note_parent(k, best, "napped beside")
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

## Starts the chore its knacks give it (BaseChore), if one can run now.
func _chore(k: Dictionary) -> bool:
	var kind := BaseChore.pick(self, k)
	if kind == "":
		return false
	BaseChore.begin(self, k, kind)
	k["t"] = float(R["max"]["chore"])
	if machine(k).go(S.CHORE, kind):
		return true
	BaseChore.end(k)
	return false

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

## It would thrive in another open zone: now and then (once per load) it goes to wait at the pad.
func _ask(k: Dictionary) -> bool:
	var uid := String(k["rec"]["uid"])
	var Z := GardenZones.rules()
	if h.hway == null or _asked.has(uid):
		return false
	var id := GardenZones.wants(k["rec"])
	if id == "" or randf() >= float(Z["ask_chance"]) or not machine(k).go(S.REACT, "ask"):
		return false
	_asked[uid] = true
	k["life_at"] = h.hway.pad
	k["life_for"] = float(Z["ask_s"])
	k["t"] = float(k["life_for"])
	var line := "%s keeps looking at %s (%s: send it)"
	h._say(k, line % [k["rec"]["name"], GardenZones.info(id)["name"], Settings.key_cap("interact")], k["life_for"])
	return true

## A new Boki on the base: the ones near by come over to have a look.
func _arrived(k: Dictionary) -> void:
	BaseShy.arrive(h, k)
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

## The farm's own drivers have this Boki (it was called, is held, works, bathes, is indoors, leaping or looking at
## news with ComeLook).
static func _taken(k: Dictionary) -> bool:
	return k.get("busy", false) or k.has("called_t") or k.has("indoors") or k.has("leap") or k.has("job") \
		or k.has("fetch") or k.has("bath") or k.has("zone_go") or k.get("nap_go", false) or k.has("look") \
		or float(k.get("hold_t", 0.0)) > 0.0

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
		if BaseShy.shy(o["rec"]):
			continue
		var b := bond(k["rec"], o["rec"])
		var score := b + randf() * 0.6
		if b > float(R["rival_at"]) and (o["life"] as Fsm).is_in(S.ROAM) and not o.has("play") and score > top:
			top = score
			best = o
	return best

func _greet(k: Dictionary, near: Array) -> void:
	var best := {}
	var top := float(R["friend_at"])
	for o in near:
		var liking := regard(k, o, float(R["parent_weight"]))
		if liking >= top and _dist(k, o) < GREET:
			top = liking
			best = o
	if not best.is_empty() and randf() < 0.5:
		h._emote(k, "♥")
		note_parent(k, best, "said hello to")

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
