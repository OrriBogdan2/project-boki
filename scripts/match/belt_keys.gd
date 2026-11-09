class_name BeltKeys
extends RefCounted
## Keys on the utility belt (docs/decisions/0005-equal-footing.md): a Rift Key and a chest key each
## take one belt slot while you carry any, with the count on the icon, so you always see whether you
## carry one and carrying one costs a slot. The counts stay where they live (h.rift_keys, and
## h.chest_keys through KeyChest); the belt shows them (sync) and spends through KeyChest.take.
##   F at a lock      still opens it (Exits for hatches, Match._open_chest for chests)
##   its belt key     beside a matching lock opens it; anywhere else pings the nearest one on your map
##   caps             Rift Keys 1 (content/utility/rift_key.json "max"), chest keys KeyChest.cap()
##   a full belt      the key stays on the ground and a prompt offers a swap: press a slot's key to
##                    drop that slot's items for it (swap). Keys are never thrown away by the game
##   death            they go in your deathbox (its "keys" and "chest_keys")
##   never            brought in from home, sold, or taken home

const KIND := {"rift_key": "rift", "chest_key": "chest"}
const PICKUP := {"rift_key": "key", "chest_key": "ckey"}      # their ground pickup kinds
const PROMPT_GAP := 2.5          # seconds between repeats of the "belt full" prompt
const SWAP_R := 2.2              # how close a pickup must be to swap for it (the pickup grab range)
const DROP_HOLD := -1.0          # a dropped stack's pickup clock starts here: it can't be grabbed back at once
const CHEST_R := 1.6             # the chest reach (Match._update_interact)

# ------------------------------------------------------------------ holding keys
static func is_key(id: String) -> bool:
	return KIND.has(id)

static func held(h, id: String) -> int:
	return KeyChest.count(h, String(KIND[id]))

## The most of a key one hunter carries.
static func cap(id: String) -> int:
	if id == "chest_key":
		return KeyChest.cap()
	return int(UtilityBelt.def(id).get("max", 1))

## Adds up to n keys, as many as the cap and the belt allow. Returns how many went on.
static func give(h, id: String, n: int) -> int:
	var put := mini(n, UtilityBelt.room_for(h, id))
	if put <= 0:
		return 0
	if id == "chest_key":
		put = KeyChest.give(h, put)
	else:
		h.rift_keys += put
	sync(h)
	return put

static func take(h, id: String, n: int) -> int:
	var got := KeyChest.take(h, String(KIND[id]), n)
	sync(h)
	return got

## The belt shows what the counts say: a slot per key type carried (the first empty one), none once
## the count is 0.
static func sync(h) -> void:
	for id in KIND:
		var n := held(h, id)
		var i := UtilityBelt.slot_of(h, id)
		if n <= 0:
			if i >= 0:
				h.belt[i] = {}
			continue
		if i < 0:
			i = _empty_slot(h)
			if i < 0:
				continue      # (a full belt: the pickup gates keep this from happening)
			h.belt[i] = {"id": id, "n": 0, "cd": 0.0}
		h.belt[i]["n"] = n

static func _empty_slot(h) -> int:
	for k in UtilityBelt.SLOTS:
		if (h.belt[k] as Dictionary).is_empty():
			return k
	return -1

# ------------------------------------------------------------------ pressing a key's slot
## Beside a matching lock: open it (the lock spends the key). Elsewhere: ping the nearest one.
## Returns whether anything happened.
static func use(h, id: String) -> bool:
	var m = h.m
	var lock := _near_lock(m, h, id)
	if not lock.is_empty():
		if id == "rift_key":
			m.exits.act(lock, "open", h)
		else:
			m._open_chest(h, lock)
		sync(h)
		return true
	var spots: Array = _locks(m, id).map(func(x): return x["pos"])
	if spots.is_empty():
		return false
	var best: Vector3 = spots[0]
	for p in spots:
		if h.flat_dist(p) < h.flat_dist(best):
			best = p
	if h == m.player:
		var col: Color = ExitModels.HATCH if id == "rift_key" else UtilityBelt.col_of(id)
		m.ping(best, col)
		if m.hud:
			var what := UtilityBelt.name_of(id).to_lower()
			m.hud.toast_small("Nearest %s lock pinged" % what, col)
	return true

## The locks a key opens that are still shut: sealed hatches, or locked chests.
static func _locks(m, id: String) -> Array:
	if id == "rift_key":
		return [] if m.exits == null else m.exits.of_kind("hatch").filter(func(x): return x["state"] == "sealed")
	return m.chests.filter(func(c): return not c["open"] and not bool(c.get("free", false)))

static func _near_lock(m, h, id: String) -> Dictionary:
	for x in _locks(m, id):
		var at: Vector3 = x["pos"]
		var reach := Exits.HATCH_R if id == "rift_key" else CHEST_R
		if h.flat_dist(at) <= reach and absf(h.pos.y - at.y) <= 1.2:
			return x
	return {}

# ------------------------------------------------------------------ a full belt: the swap
## The belt item lying within reach that doesn't fit on this hunter's belt ({} for none).
static func blocked_pickup(h) -> Dictionary:
	for p in h.m.pickups:
		var id := UtilityBelt.item_of(String(p["kind"]))
		if not UtilityBelt.is_item(id) or UtilityBelt.has_room(h, id) or float(p["t"]) < 0.5:
			continue
		if is_key(id) and held(h, id) >= cap(id):
			continue      # a full stack of the same key: nothing to swap for
		var pos: Vector3 = p["pos"]
		if Vector2(h.pos.x - pos.x, h.pos.z - pos.z).length() < SWAP_R and absf(h.pos.y - pos.y) < 2.0:
			return p
	return {}

## A slot key pressed beside something that doesn't fit: that slot's items go on the ground and the
## new one comes onto the belt. Returns true when it swapped (the press does nothing else).
static func swap(h, i: int) -> bool:
	if h.m == null or (h.m.net_on and not h.m.is_host):
		return false
	var p := blocked_pickup(h)
	var s: Dictionary = h.belt[i]
	if p.is_empty() or s.is_empty():
		return false
	var old_id := String(s["id"])
	if is_key(old_id):
		for k in take(h, old_id, held(h, old_id)):
			_drop_held(h, String(PICKUP[old_id]), 1)
	else:
		_drop_held(h, old_id, UtilityBelt.take(h, old_id, int(s["n"])))
	h.m._collect(h, p)
	return true

static func _drop_held(h, kind: String, n: int) -> void:
	h.m.drop(kind, h.pos + Vector3(0, 0.6, 0), n)
	h.m.pickups[h.m.pickups.size() - 1]["t"] = DROP_HOLD

## Every step: tell the local player when a belt item at their feet doesn't fit, and let bots make
## room for a key (they drop their cheapest stack that isn't a key).
static func tick(m) -> void:
	for h in m.hunters:
		if h.out or h.downed or h.remote or (h != m.player and h.ctrl != "bot"):
			continue
		var p := blocked_pickup(h)
		if p.is_empty():
			continue
		var id := UtilityBelt.item_of(String(p["kind"]))
		if h == m.player:
			_prompt(m, h, id)
		elif is_key(id):
			var cheap := _cheapest_slot(h)
			if cheap >= 0:
				swap(h, cheap)

static func _prompt(m, h, id: String) -> void:
	if m.hud == null or m.time < float(h.get_meta("belt_full_at", -99.0)) + PROMPT_GAP:
		return
	h.set_meta("belt_full_at", m.time)
	var first := Settings.key_cap(UtilityBelt.KEYS[0])
	var last := Settings.key_cap(UtilityBelt.KEYS[UtilityBelt.SLOTS - 1])
	var line := "Belt full  ·  %s-%s swaps" % [first, last]
	m.hud.toast_small(line, UtilityBelt.col_of(id))

## The belt slot worth least (price times charges), never a key. -1 when every slot holds a key.
static func _cheapest_slot(h) -> int:
	var best := -1
	var best_v := INF
	for i in UtilityBelt.SLOTS:
		var s: Dictionary = h.belt[i]
		if s.is_empty() or is_key(String(s["id"])):
			continue
		var worth := float(UtilityBelt.price_of(String(s["id"])) * int(s["n"]))
		if worth < best_v:
			best_v = worth
			best = i
	return best
