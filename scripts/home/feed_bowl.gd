class_name FeedBowl
extends RefCounted
## The feeding bowl (a base-mode decoration): drop a snack in it and hungry Boki nearby walk over.
## Each Boki that comes has one explicit state in k["bowl"] (no key = roaming, the rest is
## the home's own wandering): GO walks to the ring round the bowl, WAIT queues there, EAT steps
## in and eats, HUFF is a rival's stare-down on arrival. Only go() writes the state.
## Bold and greedy Boki push in first; a timid one waits until no bolder Boki wants the bowl.
## Each Boki that eats gets the food's lean exactly like hand feeding (Care.feed, which calls Evo.eat).
## The snacks live on the placed decoration: e["snacks"] = [food id].

enum S { GO, WAIT, EAT, HUFF }

const CAP := 3                    # snacks the bowl holds
const RANGE := 9.0                # tiles: hungry Boki this near answer a dropped snack
const RING_R := 2.0               # tiles from the bowl where the queue waits
const SEAT_R := 0.8               # tiles from the bowl where a Boki eats
const NEAR_R := 0.5               # tiles: close enough to a goal point
const EAT_SECS := 2.6             # seconds to eat one snack
const HUFF_SECS := 1.4            # seconds a rival stare-down lasts
const GIVE_UP_SECS := 40.0        # a Boki that can't get its turn wanders off
const TIMID_BELOW := 0.4          # bravery under this: waits for the bolder ones
const RIVAL_AT := -0.3            # rec["bonds"][uid] at or under this: rivals
const GREED := 0.5                # how much an empty belly adds to a Boki's push (0..1 bravery scale)

static func is_bowl(e: Dictionary) -> bool:
	return String(e["id"]) == "feed_bowl"

static func bowls(h) -> Array:
	return h.hb.L()["deco"].filter(is_bowl)

static func at(e: Dictionary) -> Vector3:
	return HomeLayout.deco_center(e)

static func snacks(e: Dictionary) -> Array:
	return e.get("snacks", [])

static func state(k: Dictionary) -> int:
	return int(k["bowl"]["s"]) if k.has("bowl") else -1

static func go(b: Dictionary, s: int) -> void:
	b["s"] = s
	b["t"] = 0.0

## The first snack in the pantry (crops, then treats): "" if it is bare.
static func pantry_snack() -> String:
	for f in Data.CROPS.keys() + Care.FOODS.keys():
		if (int(Save.d["crops"].get(f, 0)) if Data.CROPS.has(f) else int(Save.d["items"].get(f, 0))) > 0:
			return String(f)
	return ""

## Drops one pantry snack in the bowl and calls the hungry Boki over. False if it is full or the pantry is bare.
static func drop(h, e: Dictionary) -> bool:
	var f := pantry_snack()
	if f == "" or snacks(e).size() >= CAP:
		return false
	if Data.CROPS.has(f): Save.d["crops"][f] = int(Save.d["crops"][f]) - 1
	else: Save.d["items"][f] = int(Save.d["items"][f]) - 1
	e["snacks"] = snacks(e) + [f]
	show_snacks(h, e)
	for k in h.kins:
		if _hungry(k):
			k["t"] = 0.0      # answers now, not after its rest
	return true

static func label(e: Dictionary) -> String:
	var n := snacks(e).size()
	if n >= CAP: return "Feeding bowl  ·  full (%d/%d)" % [n, CAP]
	if pantry_snack() == "": return "Feeding bowl  ·  %d/%d  ·  you have no snacks" % [n, CAP]
	return "Feeding bowl  ·  %d/%d  ·  drop a %s in" % [n, CAP, Care.food_name(pantry_snack())]

static func _hungry(k: Dictionary) -> bool:
	return not k.has("bowl") and free_to_go(k) and Care.need(k["rec"], "food") < Econ.HUNGRY_AT

static func free_to_go(k: Dictionary) -> bool:
	return not (k.has("indoors") or k.has("called_t") or k.get("busy", false) or k.has("fetch") or k.has("bath")
		or k.has("eat") or float(k.get("nap_t", 0.0)) > 0.0)

# ------------------------------------------------------------------ who goes first
static func _bravery(k: Dictionary) -> float:
	return float(k["rec"].get("traits", {}).get("bravery", 0.5))

static func timid(k: Dictionary) -> bool:
	return _bravery(k) < TIMID_BELOW

## Bold and hungry Boki push in ahead of the rest.
static func push(k: Dictionary) -> float:
	return _bravery(k) + GREED * (1.0 - Care.need(k["rec"], "food") / 100.0)

static func rivals(a: Dictionary, b: Dictionary) -> bool:
	return float(a["rec"].get("bonds", {}).get(String(b["rec"]["uid"]), 0.0)) <= RIVAL_AT

## The Boki on its way to this bowl, in any state.
static func _crowd(h, e: Dictionary) -> Array:
	return h.kins.filter(func(o): return o.has("bowl") and int(o["bowl"]["u"]) == int(e["u"]))

static func _eating(crowd: Array) -> bool:
	return crowd.any(func(o): return state(o) == S.EAT)

## Is it this Boki's turn? The bowl is free and nobody ahead of it in the pecking order wants it too:
## a timid Boki gives way to every bolder one on its way, a bold one to a bolder or hungrier one at the ring.
static func _my_turn(h, k: Dictionary, e: Dictionary) -> bool:
	var crowd := _crowd(h, e)
	if _eating(crowd):
		return false
	var c := at(e)
	for o in crowd:
		if o == k or timid(o) and not timid(k):
			continue
		if timid(k):
			if not timid(o): return false
		elif state(o) != S.GO or Vector2(o["pos"].x - c.x, o["pos"].z - c.z).length() < RING_R + NEAR_R:
			if push(o) > push(k): return false
	return true

# ------------------------------------------------------------------ the home's hooks
## A hungry Boki near a bowl with a snack to spare goes to it. True if it is off to eat.
static func want(h, k: Dictionary) -> bool:
	if k.has("bowl"):
		return true
	if not _hungry(k) or not h.visit.is_empty():
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
	k["bowl"] = {"s": S.GO, "u": int(best["u"]), "t": 0.0}
	k["t"] = GIVE_UP_SECS
	k.erase("stare")
	return true

## Every frame for a Boki with a bowl state. True while it is busy with that.
static func step(h, k: Dictionary, d: float) -> bool:
	var b: Dictionary = k["bowl"]
	var e := _entry(h, int(b["u"]))
	if e.is_empty() or not free_to_go(k) or snacks(e).is_empty() or float(b["t"]) > GIVE_UP_SECS:
		_leave(h, k, "?" if not e.is_empty() else "")
		return false
	b["t"] = float(b["t"]) + d
	var c := at(e)
	var pos: Vector3 = k["pos"]
	match int(b["s"]):
		S.GO:
			k["goal"] = h._seat(k, c, RING_R)
			if Vector2(c.x - pos.x, c.z - pos.z).length() < RING_R + NEAR_R:
				_arrive(h, k, e)
		S.WAIT:
			k["goal"] = h._seat(k, c, RING_R)
			if _my_turn(h, k, e):
				go(b, S.EAT)
		S.HUFF:
			k["hold_t"] = 0.3
			k["goal"] = pos
			if float(b["t"]) >= HUFF_SECS:
				go(b, S.WAIT)
		S.EAT:
			_eat(h, k, e, d)
	return true

static func _entry(h, u: int) -> Dictionary:
	for e in bowls(h):
		if int(e["u"]) == u: return e
	return {}

## Reached the ring: a rival already at the bowl means a stare-down first.
static func _arrive(h, k: Dictionary, e: Dictionary) -> void:
	var rival := _crowd(h, e).filter(func(o): return o != k and state(o) != S.GO and rivals(k, o))
	go(k["bowl"], S.WAIT)
	if rival.is_empty():
		return
	for o in rival:
		if state(o) == S.WAIT: go(o["bowl"], S.HUFF)
	go(k["bowl"], S.HUFF)
	h._emote(k, "!", true)
	h._say(k, BokiLines.say(k["rec"], "huff"))

static func _eat(h, k: Dictionary, e: Dictionary, d: float) -> void:
	var b: Dictionary = k["bowl"]
	var c := at(e)
	var pos: Vector3 = k["pos"]
	var seat := c + Vector3(pos.x - c.x, 0, pos.z - c.z).normalized() * SEAT_R
	if Vector2(seat.x - pos.x, seat.z - pos.z).length() > NEAR_R:
		k["goal"] = seat
		b["t"] = 0.0
		return
	k["hold_t"] = 0.3
	k["goal"] = pos
	(k["node"] as Node3D).rotation.y = atan2(-(c.x - pos.x), -(c.z - pos.z))
	if float(b["t"]) < EAT_SECS:
		var body: Node3D = (k["node"] as Node3D).get_node_or_null("Body")
		if body:
			var q := absf(sin(float(b["t"]) * 9.0))
			body.scale = Vector3(1.0 + q * 0.08, 1.0 - q * 0.1, 1.0 + q * 0.08)
		return
	_finish(h, k, e)

## One snack eaten: its filling, joy and lean, then back to roaming.
static func _finish(h, k: Dictionary, e: Dictionary) -> void:
	var rec: Dictionary = k["rec"]
	var food := _pick(e, rec)
	var res := Care.feed(rec, food) if food != "" else {"ok": false}
	if res["ok"]:
		(e["snacks"] as Array).erase(food)
		show_snacks(h, e)
		h.fx.burst(at(e) + Vector3(0, 0.3, 0), Care.food_col(food), 5, 1.0, 0.25)
		Sfx.play("pickup", at(e), -16.0, 0.1, 1.4)
	var loved: bool = res.get("love", false) and res["ok"]
	var mood := "?"
	if res["ok"]:
		mood = "♥" if loved else "♪"
	_leave(h, k, mood)
	if loved:
		k["joy_t"] = 1.0
		if res.get("new", false): h._toast("%s loves %s!" % [rec["name"], Care.food_name(food)])

## Its favourite from the bowl, else the first it doesn't hate.
static func _pick(e: Dictionary, rec: Dictionary) -> String:
	var love := String(rec["likes"]["food"])
	var hate := String(rec["likes"]["hates"])
	if snacks(e).has(love): return love
	for f in snacks(e):
		if String(f) != hate: return String(f)
	return ""

static func _leave(h, k: Dictionary, mood: String) -> void:
	var body: Node3D = (k["node"] as Node3D).get_node_or_null("Body")
	if body: body.scale = Vector3.ONE
	k.erase("bowl")
	k["t"] = randf_range(1.0, 2.0)
	if mood != "": h._emote(k, mood)

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
		var at_i := Vector3(cos(a) * 0.12, 0.26, sin(a) * 0.12)
		Models.part(heap, Models.sphere(0.09, 8), Models.toon(Color("c8a26a"), false, 0.2), at_i)
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
