class_name BeltKeys
extends RefCounted
## Keys on the utility belt (docs/decisions/0005-equal-footing.md): a Rift Key and a chest key are belt
## items ("rift_key", "chest_key"), one slot per type, stacked up to the item's "max". You always see
## whether you carry one, and carrying one costs a slot.
##   F at a lock      still opens it (Exits for hatches, the chest code for chests)
##   its belt key     beside a matching lock opens it; anywhere else pings the nearest one on your map
##   a full belt      the key stays on the ground and a prompt offers a swap: press a slot's key to
##                    drop that slot's items for it (swap). Keys are never thrown away by the game
##   death            they go in your deathbox with the rest of the belt
##   never            brought in from home, sold, or taken home
## Chest locks belong to the chest code (ext/keys-cover): it calls register_lock("chest_key", ...).

const PROMPT_GAP := 2.5          # seconds between repeats of the "belt full" prompt
const SWAP_R := 2.2              # how close a pickup must be to swap for it (the pickup grab range)
const DROP_HOLD := -1.0          # a dropped stack's pickup clock starts here: it can't be grabbed back at once

## Locks other parts add: key item id -> {near: Callable(h) -> Variant (the lock beside h, or null),
## open: Callable(h, lock), spots: Callable(h) -> Array of Vector3, col: Color}.
static var _locks: Dictionary = {}

static func register_lock(id: String, near: Callable, open: Callable, spots: Callable, col: Color) -> void:
	_locks[id] = {"near": near, "open": open, "spots": spots, "col": col}

# ------------------------------------------------------------------ holding keys
## Sets how many of a key a hunter holds. More than fits stays on the ground beside them (the swap
## prompt offers it); fewer takes them off the belt.
static func set_keys(h, id: String, n: int) -> void:
	var cur := UtilityBelt.count(h, id)
	if n < cur:
		UtilityBelt.take(h, id, cur - n)
		return
	var left := (n - cur) - UtilityBelt.grant(h, id, n - cur)
	if left > 0 and h.m != null:
		h.m.drop(pickup_kind(id), h.pos + Vector3(0, 0.6, 0), left)

## The ground pickup kind for a key item (the match's Rift Key pickup is "key").
static func pickup_kind(id: String) -> String:
	for kind in UtilityBelt.OLD_KINDS:
		if String(UtilityBelt.OLD_KINDS[kind]) == id:
			return String(kind)
	return id

## A key picked up: on the belt, with a toast and a sound for the local player.
static func picked(m, h, id: String) -> void:
	UtilityBelt.grant(h, id, 1)
	if h == m.player and m.hud:
		m.hud.toast("%s found  ·  belt key %s" % [UtilityBelt.name_of(id), _key_cap(h, id)], UtilityBelt.col_of(id))
		m.sfx("unlock", null, -6.0, 1.2)

static func _key_cap(h, id: String) -> String:
	var i := UtilityBelt.slot_of(h, id)
	return Settings.key_cap(UtilityBelt.KEYS[i]) if i >= 0 else ""

# ------------------------------------------------------------------ pressing a key's slot
## Beside a matching lock: open it (the lock spends the key). Elsewhere: ping the nearest one.
## Returns whether anything happened.
static func use(h, id: String) -> bool:
	var m = h.m
	var lock: Dictionary = _lock_of(m, id)
	if lock.is_empty():
		return false
	var at = lock["near"].call(h)
	if at != null:
		lock["open"].call(h, at)
		return true
	var best := Vector3.INF
	for p in lock["spots"].call(h):
		if best == Vector3.INF or h.flat_dist(p) < h.flat_dist(best):
			best = p
	if best == Vector3.INF:
		return false
	if h == m.player:
		m.ping(best, lock["col"])
		if m.hud:
			var what := UtilityBelt.name_of(id).to_lower()
			m.hud.toast_small("Nearest lock for your %s pinged on the map" % what, lock["col"])
	return true

## The lock table for a key: the Rift Key's hatches are built in (Exits), others are registered.
static func _lock_of(m, id: String) -> Dictionary:
	if id == "rift_key" and m.exits != null:
		var exits: Exits = m.exits
		return {"near": func(h): return _hatch_near(exits, h),
			"open": func(h, x): exits.act(x, "open", h),
			"spots": func(_h): return _sealed_hatches(exits),
			"col": ExitModels.HATCH}
	return _locks.get(id, {})

static func _sealed_hatches(exits: Exits) -> Array:
	var out: Array = []
	for x in exits.of_kind("hatch"):
		if x["state"] == "sealed":
			out.append(x["pos"])
	return out

static func _hatch_near(exits: Exits, h) -> Variant:
	for x in exits.of_kind("hatch"):
		var at: Vector3 = x["pos"]
		if x["state"] == "sealed" and h.flat_dist(at) <= Exits.HATCH_R and absf(h.pos.y - at.y) <= 1.2:
			return x
	return null

# ------------------------------------------------------------------ a full belt: the swap
## The belt item lying within reach that doesn't fit on this hunter's belt ({} for none).
static func blocked_pickup(h) -> Dictionary:
	for p in h.m.pickups:
		var id := UtilityBelt.item_of(String(p["kind"]))
		if not UtilityBelt.is_item(id) or UtilityBelt.has_room(h, id) or float(p["t"]) < 0.5:
			continue
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
	var n := UtilityBelt.take(h, old_id, int(s["n"]))
	h.m.drop(pickup_kind(old_id), h.pos + Vector3(0, 0.6, 0), n)
	h.m.pickups[h.m.pickups.size() - 1]["t"] = DROP_HOLD
	h.m._collect(h, p)
	return true

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
		elif UtilityBelt.is_key(id):
			var cheap := _cheapest_slot(h)
			if cheap >= 0:
				swap(h, cheap)

static func _prompt(m, h, id: String) -> void:
	if m.hud == null or m.time < float(h.get_meta("belt_full_at", -99.0)) + PROMPT_GAP:
		return
	h.set_meta("belt_full_at", m.time)
	var first := Settings.key_cap(UtilityBelt.KEYS[0])
	var last := Settings.key_cap(UtilityBelt.KEYS[UtilityBelt.SLOTS - 1])
	var line := "Belt full: press %s-%s to swap a slot for the %s" % [first, last, UtilityBelt.name_of(id)]
	m.hud.toast_small(line, UtilityBelt.col_of(id))

## The belt slot worth least (price times charges), never a key. -1 when every slot holds a key.
static func _cheapest_slot(h) -> int:
	var best := -1
	var best_v := INF
	for i in UtilityBelt.SLOTS:
		var s: Dictionary = h.belt[i]
		if s.is_empty() or UtilityBelt.is_key(String(s["id"])):
			continue
		var worth := float(UtilityBelt.price_of(String(s["id"])) * int(s["n"]))
		if worth < best_v:
			best_v = worth
			best = i
	return best
