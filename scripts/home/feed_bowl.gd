class_name FeedBowl
extends RefCounted
## The feeding bowl (a base piece, the Base tab): you drop snacks from the pantry in it and the hungry Boki
## nearby walk over and eat from it in turn. It is one of the places BaseLife's Eat state eats at (BaseFeed):
## the visit is k["life_eat"] = {from: "bowl", u, at, phase, t0}, with the phases go (to the ring round the
## bowl), wait (queued there), huff (a rival's stare-down on arrival) and eat (one at the bowl at a time).
## Bold and greedy Boki push in first; a timid one waits until no bolder Boki wants the bowl. The meal is
## BaseFeed.meal's (Care.feed, so Evo.eat leans it like any meal). The snacks live on the placed piece:
## e["snacks"] = [food id].

const ID := "feed_bowl"
const CAP := 3                    # snacks the bowl holds
const RANGE := 9.0                # m: hungry Boki this near answer a dropped snack
const RING_R := 2.0               # m from the bowl where the queue waits
const SEAT_R := 0.8               # m from the bowl where a Boki eats
const NEAR_R := 0.5               # m: close enough to a goal point
const EAT_SECS := 2.6             # s to eat one snack
const HUFF_SECS := 1.4            # s a rival stare-down lasts
const GIVE_UP_SECS := 40.0        # s: a Boki that can't get its turn wanders off (BaseLife's Eat cap too)
const TIMID_BELOW := 0.4          # bravery (0..1) under this: waits for the bolder ones
const GREED := 0.5                # how much an empty belly adds to a Boki's push (0..1 bravery scale)
const PICK_R := 1.3               # m: you are close enough to the bowl to drop a snack in

static func bowls(h) -> Array:
	return h.hb.L()["deco"].filter(func(e): return String(e["id"]) == ID)

static func at(e: Dictionary) -> Vector3:
	return HomeLayout.deco_center(e)

static func snacks(e: Dictionary) -> Array:
	return e.get("snacks", [])

## Its phase at a bowl ("" when it is not at one).
static func phase(k: Dictionary) -> String:
	var v: Dictionary = k.get("life_eat", {})
	return String(v["phase"]) if String(v.get("from", "")) == "bowl" else ""

static func _go(k: Dictionary, p: String, since: float) -> void:
	k["life_eat"]["phase"] = p
	k["life_eat"]["t0"] = since

## The first snack in the pantry (crops, then treats): "" if it is bare.
static func pantry_snack() -> String:
	for f in Data.CROPS.keys() + Care.FOODS.keys():
		if Econ.pantry(String(f)) > 0:
			return String(f)
	return ""

## Drops one pantry snack in the bowl and calls the hungry Boki over. False if it is full or the pantry is bare.
static func drop(h, e: Dictionary) -> bool:
	var f := pantry_snack()
	if f == "" or snacks(e).size() >= CAP or not Econ._take_pantry(f):
		return false
	e["snacks"] = snacks(e) + [f]
	show_snacks(h, e)
	for k in h.kins:
		if Care.need(k["rec"], "food") < Econ.HUNGRY_AT and not k.has("life_eat"):
			k["t"] = 0.0      # answers now, not after its rest
	return true

static func label(e: Dictionary) -> String:
	var n := snacks(e).size()
	if n >= CAP: return "Feeding bowl  ·  full (%d/%d)" % [n, CAP]
	if pantry_snack() == "": return "Feeding bowl  ·  %d/%d  ·  you have no snacks" % [n, CAP]
	return "Feeding bowl  ·  %d/%d  ·  drop a %s in" % [n, CAP, Care.food_name(pantry_snack())]

# ------------------------------------------------------------------ who goes first
static func timid(k: Dictionary) -> bool:
	return float(k["rec"].get("traits", {}).get("bravery", 0.5)) < TIMID_BELOW

## Bold and hungry Boki push in ahead of the rest.
static func push(k: Dictionary) -> float:
	var bravery := float(k["rec"].get("traits", {}).get("bravery", 0.5))
	return bravery + GREED * (1.0 - Care.need(k["rec"], "food") / 100.0)

## The Boki on their way to this bowl, in any phase.
static func _crowd(h, e: Dictionary) -> Array:
	return h.kins.filter(func(o): return phase(o) != "" and int(o["life_eat"]["u"]) == int(e["u"]))

## Is it this Boki's turn? The bowl is free and nobody ahead of it in the pecking order wants it too:
## a timid Boki gives way to every bolder one on its way, a bold one to a bolder or hungrier one at the ring.
static func _my_turn(h, k: Dictionary, e: Dictionary) -> bool:
	var crowd := _crowd(h, e)
	if crowd.any(func(o): return phase(o) == "eat"):
		return false
	var c := at(e)
	for o in crowd:
		if o == k or timid(o) and not timid(k):
			continue
		if timid(k):
			if not timid(o): return false
			continue
		var at_ring := Vector2(o["pos"].x - c.x, o["pos"].z - c.z).length() < RING_R + NEAR_R
		if (phase(o) != "go" or at_ring) and push(o) > push(k):
			return false
	return true

# ------------------------------------------------------------------ BaseFeed's hooks
## A hungry Boki near a bowl with a snack to spare for it sets off. True if it did (k["life_eat"] is set).
static func want(h, k: Dictionary) -> bool:
	if not h.visit.is_empty():
		return false
	var here: int = h.world.island_of(k["pos"].x, k["pos"].z)
	var hate := String(k["rec"].get("likes", {}).get("hates", ""))
	var best := {}
	var bd := RANGE
	for e in bowls(h):
		var p := at(e)
		var dd := Vector2(p.x - k["pos"].x, p.z - k["pos"].z).length()
		var spare := snacks(e).filter(func(f): return String(f) != hate).size() - _crowd(h, e).size()
		if dd < bd and spare > 0 and h.world.island_of(p.x, p.z) == here:
			bd = dd
			best = e
	if best.is_empty():
		return false
	k["life_eat"] = {"from": "bowl", "u": int(best["u"]), "at": at(best), "phase": "go", "t0": 0.0}
	k["t"] = GIVE_UP_SECS      # the farm leaves it be while it is at the bowl
	return true

## One tick of BaseLife's Eat state at a bowl (`since`: seconds in Eat). True while it is still at it.
static func tick(h, k: Dictionary, since: float) -> bool:
	var v: Dictionary = k["life_eat"]
	var e := _entry(h, int(v["u"]))
	if e.is_empty() or snacks(e).is_empty() or since > GIVE_UP_SECS:
		_leave(h, k, "?")
		return false
	var c := at(e)
	var pos: Vector3 = k["pos"]
	var held := since - float(v["t0"])
	match String(v["phase"]):
		"go":
			k["goal"] = h._seat(k, c, RING_R)
			if Vector2(c.x - pos.x, c.z - pos.z).length() < RING_R + NEAR_R:
				_arrive(h, k, e, since)
		"wait":
			if _my_turn(h, k, e):
				_go(k, "eat", since)
		"huff":
			k["goal"] = pos
			if held >= HUFF_SECS:
				_go(k, "wait", since)
		"eat":
			_eat(h, k, e, since)
	return true

static func _entry(h, u: int) -> Dictionary:
	for e in bowls(h):
		if int(e["u"]) == u: return e
	return {}

## Reached the ring: a rival already at the bowl means a stare-down first.
static func _arrive(h, k: Dictionary, e: Dictionary, since: float) -> void:
	var rival_at := float(h.life.R["rival_at"])
	var rival := _crowd(h, e).filter(func(o): return o != k and phase(o) != "go" \
		and BaseLife.bond(k["rec"], o["rec"]) <= rival_at)
	k["goal"] = h._seat(k, at(e), RING_R)
	if rival.is_empty():
		_go(k, "wait", since)
		return
	for o in rival:
		if phase(o) == "wait": _go(o, "huff", float((o["life"] as Fsm).since))
	_go(k, "huff", since)
	h._emote(k, "!", true)
	h._say(k, BokiLines.say(k["rec"], "huff"))

static func _eat(h, k: Dictionary, e: Dictionary, since: float) -> void:
	var c := at(e)
	var pos: Vector3 = k["pos"]
	var seat := c + Vector3(pos.x - c.x, 0, pos.z - c.z).normalized() * SEAT_R
	if Vector2(seat.x - pos.x, seat.z - pos.z).length() > NEAR_R:
		k["goal"] = seat
		return
	k["goal"] = pos
	(k["node"] as Node3D).rotation.y = atan2(-(c.x - pos.x), -(c.z - pos.z))
	var v: Dictionary = k["life_eat"]
	if not v.has("seated"):
		v["seated"] = true      # at the bowl now: the chewing starts
		v["t0"] = since
		HomeVoice.say(k["rec"], "boki_eat", pos)
	var held := since - float(v["t0"])
	if held < EAT_SECS:
		var body: Node3D = (k["node"] as Node3D).get_node_or_null("Body")
		if body and not body.has_node("Flex/BokiRig"):
			var q := absf(sin(held * 9.0))
			body.scale = Vector3(1.0 + q * 0.08, 1.0 - q * 0.1, 1.0 + q * 0.08)
		return
	_finish(h, k, e)

## One snack eaten (BaseFeed.meal: its filling, joy and lean), then back to roaming.
static func _finish(h, k: Dictionary, e: Dictionary) -> void:
	var rec: Dictionary = k["rec"]
	var food := _pick(e, rec)
	var res := BaseFeed.meal(h, k, food) if food != "" else {}
	_leave(h, k, "" if food != "" else "?")      # meal() gave its own emote
	if not res.get("ok", false):
		return
	(e["snacks"] as Array).erase(food)
	show_snacks(h, e)
	h.fx.burst(at(e) + Vector3(0, 0.3, 0), Care.food_col(food), 5, 1.0, 0.25)
	Sfx.play("pickup", at(e), -16.0, 0.1, 1.4)
	if res.get("love", false):
		k["joy_t"] = 1.0
		if res.get("new", false): h._toast("%s loves %s!" % [rec["name"], Care.food_name(food)])

## Its favourite from the bowl, else the first it doesn't hate.
static func _pick(e: Dictionary, rec: Dictionary) -> String:
	var likes: Dictionary = rec.get("likes", {})
	var love := String(likes.get("food", ""))
	if snacks(e).has(love): return love
	for f in snacks(e):
		if String(f) != String(likes.get("hates", "")): return String(f)
	return ""

static func _leave(h, k: Dictionary, mood: String) -> void:
	end(k)
	k["t"] = randf_range(1.0, 2.0)
	if mood != "": h._emote(k, mood)

## Done at the bowl, however it ended (BaseLife's Eat exit too): its body is back to shape.
static func end(k: Dictionary) -> void:
	var body: Node3D = (k["node"] as Node3D).get_node_or_null("Body") if k.has("node") else null
	if body and not body.has_node("Flex/BokiRig") and phase(k) == "eat": body.scale = Vector3.ONE
	k.erase("life_eat")

# ------------------------------------------------------------------ the model
static func model(e: Dictionary) -> Node3D:
	var n := Node3D.new()
	Models.part(n, Models.cyl(0.38, 0.26, 0.2, 16), Models.toon(Color("c9604a")), Vector3(0, 0.1, 0))
	Models.part(n, Models.cyl(0.3, 0.3, 0.04, 16), Models.toon(Color("6b3a2c"), false), Vector3(0, 0.19, 0))
	var heap := Node3D.new()
	heap.name = "Snacks"
	n.add_child(heap)
	for i in CAP:
		var a := float(i) * TAU / CAP
		var spot := Vector3(cos(a) * 0.12, 0.26, sin(a) * 0.12)
		Models.part(heap, Models.sphere(0.09, 8), Models.toon(Color("c8a26a"), false, 0.2), spot)
	set_heap(n, snacks(e).size())
	return n

static func set_heap(n: Node3D, count: int) -> void:
	var heap: Node3D = n.get_node("Snacks")
	for i in heap.get_child_count():
		(heap.get_child(i) as Node3D).visible = i < count

static func show_snacks(h, e: Dictionary) -> void:
	var n: Node3D = h.hb.nodes.get(int(e["u"]))
	if is_instance_valid(n):
		set_heap(n, snacks(e).size())
