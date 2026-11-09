class_name Pack
## The backpack on an expedition: a few slots for gear and valuables you mean to carry home (gems,
## seeds and the utility belt are counted, not packed, and caught kin ride along apart). What you wear
## (two gloves, armor and boots: Gear) doesn't take a slot. Extract and it all goes home to the armory; die
## and it goes into your deathbox with everything else.
##
## Picking something up off the ground: a better piece of gear goes on and the old one into the
## pack; anything else goes straight in the pack. A full pack asks you what to drop
## (the swap window, Hud.open_swap). Smart loot at a deathbox takes the best first (smart_loot).

static func room(h) -> bool:
	return h.pack.size() < int(h.pack_cap)

## Index of the least valuable thing in the pack, or -1 if it's empty.
static func lowest(h) -> int:
	var bi := -1; var bv := 1 << 30
	for i in h.pack.size():
		var v := Loot.value(h.pack[i])
		if v < bv: bv = v; bi = i
	return bi

static func lowest_value(h) -> int:
	var i := lowest(h)
	return Loot.value(h.pack[i]) if i >= 0 else 0

## Would this go in the pack (room, or worth more than the worst thing in it)?
static func wants(h, it: Dictionary) -> bool:
	return room(h) or Loot.value(it) > lowest_value(h)

# ------------------------------------------------------------------ things on the ground
## The item a ground pick-up stands for (made once and kept on it).
static func ground_item(wp: Dictionary) -> Dictionary:
	if wp.has("item"):
		return wp["item"]
	var it: Dictionary = Loot.gear(String(wp["gear"]), int(wp["rar"]))
	wp["item"] = it
	return it

## Puts an item down on the ground near a spot.
static func spawn_item(m, it: Dictionary, at: Vector3) -> void:
	if String(it.get("t", "")) == "val":
		m.spawn_val(it, at)
	else:
		m.spawn_gear(String(it["id"]), int(it["rar"]), at)

static func _near(h) -> Vector3:
	var a := randf() * TAU
	return Vector3(h.pos.x + cos(a) * 0.9, h.ground(), h.pos.z + sin(a) * 0.9)

static func _off_ground(m, wp: Dictionary) -> void:
	m.wpicks.erase(wp)
	if is_instance_valid(wp.get("node")):
		(wp["node"] as Node3D).queue_free()

## The player presses interact on something lying on the ground.
static func take_ground(m, h, wp: Dictionary) -> void:
	var it := ground_item(wp)
	if String(it.get("t", "")) == "gear":
		var cur: Dictionary = h.gear[Gear.slot_on(h, String(it["id"]))]
		if cur.is_empty() or Loot.value(it) > Loot.value(Loot.gear(String(cur["id"]), int(cur["rar"]))) or not wants(h, it):
			_off_ground(m, wp)
			var old_g := _wear(m, h, it)
			if not old_g.is_empty():
				_stash_new(m, h, old_g)
			return
	stash(m, h, wp)

## Into the pack from the ground; a full pack opens the swap window instead.
static func stash(m, h, wp: Dictionary) -> bool:
	var it := ground_item(wp)
	if room(h):
		_off_ground(m, wp)
		h.pack.append(it)
		_told(m, h, "%s  ·  in your pack (%d/%d)" % [Loot.name_of(it), h.pack.size(), h.pack_cap], Loot.col_of(it))
		m.sfx(HeroSfx.of(h, "pickup", "pickup"), h.pos, -2.0, 1.1)
		return true
	if h == m.player and m.hud:
		m.hud.open_swap(wp)
	return false

## Something that just came out of your hands: into the pack if it fits, else it's put down and you
## choose what to drop.
static func _stash_new(m, h, it: Dictionary) -> void:
	if room(h):
		h.pack.append(it)
		_told(m, h, "%s  ·  into your pack (%d/%d)" % [Loot.name_of(it), h.pack.size(), h.pack_cap], Loot.col_of(it), true)
		return
	spawn_item(m, it, _near(h))
	var wp: Dictionary = m.wpicks[m.wpicks.size() - 1]
	if h == m.player and m.hud:
		m.hud.open_swap(wp)

## Swap window: drop pack slot i on the ground and take the thing on the ground in its place.
static func swap(m, h, i: int, wp: Dictionary) -> void:
	if i < 0 or i >= h.pack.size() or not m.wpicks.has(wp):
		return
	var out: Dictionary = h.pack[i]
	h.pack.remove_at(i)
	var it := ground_item(wp)
	_off_ground(m, wp)
	h.pack.append(it)
	spawn_item(m, out, _near(h))
	_told(m, h, "Dropped %s for %s" % [Loot.name_of(out), Loot.name_of(it)], Loot.col_of(it))
	m.sfx("pickup", h.pos, -2.0, 0.95)

## Puts a piece of gear on; returns the one it replaced as an item ({} if the slot was empty).
static func _wear(m, h, it: Dictionary) -> Dictionary:
	# a glove: the same glove's slot, an empty one, or the weaker one (Gloves)
	var slot := Gear.slot_on(h, String(it["id"]))
	var old: Dictionary = h.gear[slot]
	h.gear[slot] = {"id": it["id"], "rar": int(it["rar"])}
	h.gear_cd[slot] = 0.0
	h.refresh_gear()
	if h == m.player and m.hud:
		m.hud.toast("%s  ·  %s" % [Loot.name_of(it), Gear.stat_text(String(it["id"]), int(it["rar"]))], Gear.ALL[it["id"]]["col"])
	m.sfx(HeroSfx.of(h, "pickup", "pickup"), h.pos, 0.0, 0.9)
	if old.is_empty():
		return {}
	return Loot.gear(String(old["id"]), int(old["rar"]))

## From the backpack window: wear this piece of gear; what you had takes its place in the pack.
static func use_from_pack(m, h, i: int) -> void:
	if i < 0 or i >= h.pack.size():
		return
	var it: Dictionary = h.pack[i]
	h.pack.remove_at(i)
	if String(it.get("t", "")) == "gear":
		var old_g := _wear(m, h, it)
		if not old_g.is_empty(): h.pack.insert(mini(i, h.pack.size()), old_g)
	else:
		h.pack.insert(i, it)

static func drop_from_pack(m, h, i: int) -> void:
	if i < 0 or i >= h.pack.size():
		return
	var it: Dictionary = h.pack[i]
	h.pack.remove_at(i)
	spawn_item(m, it, _near(h))

static func _told(m, h, txt: String, col: Color, small := false) -> void:
	if h == m.player and m.hud:
		if small: m.hud.toast_small(txt, col)
		else: m.hud.toast(txt, col)

## Everything a hunter would carry home: the gear they wear and the pack.
static func haul(h) -> Array:
	var out: Array = []
	for g in h.gear:
		if not (g as Dictionary).is_empty():
			out.append(Loot.gear(String(g["id"]), int(g["rar"])))
	for it in h.pack:
		out.append(Loot.clean(it))
	return out

# ------------------------------------------------------------------ deathboxes
## Smart loot: every gem, seed, kin and consumable; then better gear on you;
## then the backpack filled with the most valuable things left, swapping out anything worth less.
## Never gives up something better for something worse. Returns how many things it took.
static func smart_loot(m, h, b: Dictionary) -> int:
	var n := 0
	for it in Life.box_items(m, h, b):
		if String(it["key"]) in ["keys", "chest_keys", "gems", "seeds", "belt", "backpack"] and LootFull.fits(h, it, b):
			Life.take_item(m, h, b, it)
			n += 1
	# kin one at a time from the front (taking one shifts the rest down), while the capsule box has room
	while not (b["caught"] as Array).is_empty() and LootFull.fits(h, {"key": "caught", "i": 0}, b):
		Life.take_item(m, h, b, {"key": "caught", "i": 0})
		n += 1
	# worn: the best piece for each gear slot if it beats yours (yours goes back in the box, so it can still be packed)
	for slot in Gear.SLOTS.size():
		var bg := _best_gear(b, slot)
		if bg.is_empty():
			continue
		var cur: Dictionary = h.gear[Gear.slot_on(h, String(bg["it"]["id"]))]
		if cur.is_empty() or Loot.value(bg["it"]) > Loot.value(Loot.gear(String(cur["id"]), int(cur["rar"]))):
			_box_to_hand(m, h, b, bg)
			n += 1
	# the pack: best first
	var guard := 0
	while guard < 40:
		guard += 1
		var best := {}; var bv := -1
		for c in _box_things(b):
			var v := Loot.value(c["it"])
			if v > bv: bv = v; best = c
		if best.is_empty() or not wants(h, best["it"]):
			break
		var it: Dictionary = best["it"]
		_box_remove(b, best)
		if not room(h):
			var li := lowest(h)
			_box_put(b, h.pack[li])
			h.pack.remove_at(li)
		h.pack.append(it)
		n += 1
	Life._settle_box(b)
	if n > 0 and m.fx:
		m.fx.burst(b["pos"] + Vector3(0, 0.6, 0), Color("ffd36a"), 14, 3.0, 0.4)
	return n

## Every piece of gear and valuable in a box, each as {it, where, i}.
static func _box_things(b: Dictionary) -> Array:
	var out: Array = []
	for i in (b.get("gear", []) as Array).size():
		var g: Dictionary = b["gear"][i]
		out.append({"it": Loot.gear(String(g["id"]), int(g["rar"])), "where": "gear", "i": i})
	for i in (b.get("pack", []) as Array).size():
		out.append({"it": b["pack"][i], "where": "pack", "i": i})
	return out

static func _best_gear(b: Dictionary, slot: int) -> Dictionary:
	var best := {}; var bv := -1
	for c in _box_things(b):
		if String(c["it"].get("t", "")) == "gear" and Gear.ALL.has(String(c["it"]["id"])) and Gear.slot_of(String(c["it"]["id"])) == slot and Loot.value(c["it"]) > bv:
			bv = Loot.value(c["it"]); best = c
	return best

static func _box_remove(b: Dictionary, c: Dictionary) -> void:
	match String(c["where"]):
		"gear": (b["gear"] as Array).remove_at(int(c["i"]))
		"pack": (b["pack"] as Array).remove_at(int(c["i"]))

## Puts an item into a box (in its pack list, whatever it is).
static func _box_put(b: Dictionary, it: Dictionary) -> void:
	if not b.has("pack"): b["pack"] = []
	(b["pack"] as Array).append(it)
	b["empty"] = false

## Takes a piece of gear out of a box onto you; what you wore goes into the box.
static func _box_to_hand(m, h, b: Dictionary, c: Dictionary) -> void:
	var it: Dictionary = c["it"]
	_box_remove(b, c)
	var old_g := _wear(m, h, it)
	if not old_g.is_empty(): _box_put(b, old_g)
