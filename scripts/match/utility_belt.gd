class_name UtilityBelt
extends RefCounted
## The utility belt (docs/decisions/0005-equal-footing.md): four slots on keys 1 to 4, each
## holding one kind of item with charges. It replaces the old "kit" gear slot and the heal / armor
## kit keys. Items live in content/utility/*.json (name, icon, col, desc, use, cd, max charges per
## slot, bring[] = the most you can bring in by difficulty tier, price).
##
## Keys (Rift Keys, chest keys) are belt items too: one slot per key type, found in the match only,
## never brought or sold (BeltKeys).
##
## What a hunter holds: h.belt = four slots, each {} or {id, n, cd}; h.belt_free = {id: n} charges
## issued to everyone (used first, never taken home). The belt is brought in (Equal), found in the
## match (pickups, chests), bought (shops) and lost on death (it goes in the deathbox, Life).
##
## For other parts (shops, perk orbs, tests): UtilityBelt.grant(h, id, n) puts charges on a belt and
## returns how many fit; count(h, id), take(h, id, n), has_room(h, id) and press(h, slot) do the rest.
## Using an item (the effects) is UtilityUse.

const SLOTS := 4
const KEYS := ["util1", "util2", "util3", "util4"]

static var ALL: Dictionary = {}

static func _static_init() -> void:
	_load()

static func _load() -> void:
	ALL = {}
	var dir := DirAccess.open("res://content/utility")
	if dir == null:
		return
	var files: Array = []
	for f in dir.get_files():
		var fn := String(f).trim_suffix(".remap")
		if fn.ends_with(".json"): files.append(fn)
	files.sort()
	for fn in files:
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/utility/" + String(fn)))
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var id := String(d.get("id", String(fn).trim_suffix(".json")))
		d["id"] = id
		d["col"] = Color(String(d.get("col", "ffffff")))
		ALL[id] = d

# ------------------------------------------------------------------ definitions
static func ids() -> Array:
	var out: Array = ALL.keys()
	out.sort()
	return out

static func is_item(id: String) -> bool:
	return ALL.has(id)

## The pickup kinds the match already used ("armor" was the armor kit, "key" is a Rift Key).
static func item_of(kind: String) -> String:
	return String(OLD_KINDS.get(kind, kind))

const OLD_KINDS := {"armor": "armor_kit", "key": "rift_key", "ckey": "chest_key"}

## Keys sit on the belt but are never brought in, bought or taken home.
static func is_key(id: String) -> bool:
	return bool(def(id).get("key", false))

## The belt items a player can stock up on at home (everything but keys).
static func stock_ids() -> Array:
	return ids().filter(func(id): return not is_key(id))

static func def(id: String) -> Dictionary:
	return ALL.get(id, {})

static func name_of(id: String) -> String:
	return String(def(id).get("name", id))

static func col_of(id: String) -> Color:
	return def(id).get("col", Color.WHITE)

static func icon_of(id: String) -> String:
	return String(def(id).get("icon", id))

## Most charges one slot holds (found and bought ones can fill it).
static func max_of(id: String) -> int:
	if BeltKeys.is_key(id):
		return BeltKeys.cap(id)
	return int(def(id).get("max", 3))

## Most you can bring from home at a difficulty tier (Data.TIERS index), the stack cap by tier.
static func bring_cap(id: String, tier: int) -> int:
	var b: Array = def(id).get("bring", [1])
	return mini(max_of(id), int(b[clampi(tier, 0, b.size() - 1)]))

static func empty() -> Array:
	return [{}, {}, {}, {}]

# ------------------------------------------------------------------ what a hunter holds
## The everyday issue: the same two tonics and two armor kits for everyone (content/rules/equal.json).
static func issue(h) -> void:
	h.belt = empty()
	h.belt_free = {}
	var iss: Dictionary = Equal.rules().get("issue", {})
	for id in iss:
		grant(h, String(id), int(iss[id]), true)

static func slot_of(h, id: String) -> int:
	for i in SLOTS:
		if String((h.belt[i] as Dictionary).get("id", "")) == id:
			return i
	return -1

static func count(h, id: String) -> int:
	if BeltKeys.is_key(id):
		return BeltKeys.held(h, id)
	var i := slot_of(h, id)
	return int(h.belt[i]["n"]) if i >= 0 else 0

## Charges of `id` that would fit on this belt right now.
static func room_for(h, id: String) -> int:
	if not is_item(id):
		return 0
	if BeltKeys.is_key(id):
		return _key_room(h, id)
	var i := slot_of(h, id)
	if i >= 0:
		return max_of(id) - int(h.belt[i]["n"])
	for s in h.belt:
		if (s as Dictionary).is_empty():
			return max_of(id)
	return 0

## A key: room up to its cap while it has a slot (or a slot is free); none past the cap.
static func _key_room(h, id: String) -> int:
	var left := BeltKeys.cap(id) - BeltKeys.held(h, id)
	if left <= 0:
		return 0
	if BeltKeys.held(h, id) > 0 and slot_of(h, id) >= 0:
		return left
	for s in h.belt:
		if (s as Dictionary).is_empty():
			return left
	return 0

static func has_room(h, id: String) -> bool:
	return room_for(h, id) > 0

## Can this hunter pick up a ground pickup of `kind`? (Anything that isn't a belt item always can.)
static func can_take(h, kind: String) -> bool:
	var id := item_of(kind)
	return not is_item(id) or has_room(h, id)

## Puts charges on the belt: onto the same item's slot, else the first empty one. `issued` marks them as
## issued (used first, never taken home). Returns how many went on (0 when the belt is full).
static func grant(h, id: String, n := 1, issued := false) -> int:
	if BeltKeys.is_key(id):
		return BeltKeys.give(h, id, n)
	var put := mini(n, room_for(h, id))
	if put <= 0:
		return 0
	var i := slot_of(h, id)
	if i < 0:
		for k in SLOTS:
			if (h.belt[k] as Dictionary).is_empty():
				i = k
				break
		h.belt[i] = {"id": id, "n": 0, "cd": 0.0}
	h.belt[i]["n"] = int(h.belt[i]["n"]) + put
	if issued:
		h.belt_free[id] = int(h.belt_free.get(id, 0)) + put
	return put

## Fills one slot outright (the match start): n charges, `issued` of them the everyday issue.
static func set_slot(h, i: int, id: String, n: int, issued := 0) -> void:
	h.belt[i] = {"id": id, "n": mini(n, max_of(id)), "cd": 0.0}
	h.belt_free[id] = mini(issued, mini(n, max_of(id)))

## A pickup from the ground: onto the belt, with a small toast for the local player.
static func pickup(h, id: String, n := 1) -> void:
	var got := grant(h, id, n)
	if got > 0 and h == h.m.player and h.m.hud:
		h.m.hud.toast_small("+%d %s" % [got, name_of(id).to_lower()], col_of(id))

## Removes charges (issued ones go first). Returns how many were taken.
static func take(h, id: String, n := 1) -> int:
	if BeltKeys.is_key(id):
		return BeltKeys.take(h, id, n)
	var i := slot_of(h, id)
	if i < 0:
		return 0
	var got := mini(n, int(h.belt[i]["n"]))
	h.belt[i]["n"] = int(h.belt[i]["n"]) - got
	h.belt_free[id] = maxi(0, int(h.belt_free.get(id, 0)) - got)
	if int(h.belt[i]["n"]) <= 0:
		h.belt[i] = {}
	return got

## Sets how many charges of one item are held (stack up to what fits, or take away).
static func set_count(h, id: String, n: int) -> void:
	var cur := count(h, id)
	if n > cur:
		grant(h, id, n - cur)
	elif n < cur:
		take(h, id, cur - n)

## Charges that would come home: everything above the issued ones (what you brought and found).
static func keepers(h) -> Dictionary:
	var out := {}
	for s in h.belt:
		if (s as Dictionary).is_empty():
			continue
		var id := String(s["id"])
		var n := maxi(0, int(s["n"]) - int(h.belt_free.get(id, 0)))
		if n > 0 and not is_key(id):
			out[id] = n
	return out

## Empties the belt and returns what was on it as [{id, n}] (for the deathbox; keys go in the box
## through their own counts).
static func clear(h) -> Array:
	var out: Array = []
	for s in h.belt:
		if not (s as Dictionary).is_empty() and not BeltKeys.is_key(String(s["id"])):
			out.append({"id": String(s["id"]), "n": int(s["n"])})
	h.belt = empty()
	h.belt_free = {}
	return out

# ------------------------------------------------------------------ using it
## Key 1 to 4 (slot 0..3). Beside a belt item that doesn't fit, the press swaps this slot for it.
static func press(h, i: int) -> void:
	if BeltKeys.swap(h, i):
		return
	var s: Dictionary = h.belt[i]
	var fb: String = KEYS[i]
	if s.is_empty() or h.downed or h.out or h.riding or CcLockout.blocks(h, "item"):
		_feedback(h, fb, "deny")
		return
	if h.drink_t > 0.0 or h.kit_t > 0.0:
		return
	# rooted while reviving a downed Boki (KinDowned.commit clears the old keys but is not ours to edit)
	if h.kin != null and h.kin.rescue_on and h.kin.state == "downed":
		return
	if float(s.get("cd", 0.0)) > 0.0 or not UtilityUse.can_use(h, String(s["id"])):
		_feedback(h, fb, "deny")
		return
	if UtilityUse.start(h, i, String(s["id"])):
		_feedback(h, fb, "cast")

## Uses the first slot holding `id` (bots, tests). Returns whether it started.
static func use_id(h, id: String) -> bool:
	var i := slot_of(h, id)
	if i < 0 or h.downed or h.out or h.drink_t > 0.0 or h.kit_t > 0.0:
		return false
	var s: Dictionary = h.belt[i]
	if float(s.get("cd", 0.0)) > 0.0 or not UtilityUse.can_use(h, id):
		return false
	press(h, i)
	return true

static func _feedback(h, key: String, kind: String) -> void:
	h._ab_feedback(key, kind)

## Every step: the channelled drinks and repairs finish, slot cooldowns run.
static func tick(h, dt: float) -> void:
	BeltKeys.sync(h)
	for s in h.belt:
		if not (s as Dictionary).is_empty() and float(s.get("cd", 0.0)) > 0.0:
			s["cd"] = maxf(0.0, float(s["cd"]) - dt)
	UtilityUse.tick(h, dt)

# ------------------------------------------------------------------ looks
## A small spinning bottle for an item lying on the ground (the match's pickups).
static func pickup_model(id: String) -> Node3D:
	var root := Node3D.new()
	var col := col_of(id)
	Models.part(root, Models.sphere(0.17, 10), Models.toon(col, false, 0.6), Vector3(0, 0.18, 0))
	Models.part(root, Models.cyl(0.05, 0.06, 0.13, 8), Models.toon(Color("e6f2ea")), Vector3(0, 0.36, 0))
	Models.part(root, Models.cyl(0.07, 0.07, 0.04, 8), Models.toon(col.darkened(0.4)), Vector3(0, 0.44, 0))
	return root

## What a belt item sells for in shops and at the farm stash market (the shop agent reads this).
static func price_of(id: String) -> int:
	return int(def(id).get("price", 30))
