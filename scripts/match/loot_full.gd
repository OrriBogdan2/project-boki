class_name LootFull
## Looting with no room: what fits, what smart loot really took, and the two ways out of a full
## backpack from a box (swap one of yours into the box, or drop one of yours on the ground).
## The held item is the box's clicked row; the hold window is LootHold. Ground items use the older
## swap window (Hud.open_swap) and share the red "full" cue.

const FULL_COL := Color("ff6a5a")
## A box thing that can't go anywhere without a swap: kept in the box, never reported as taken.
const NEEDS_ROOM := ["pack", "belt", "keys", "chest_keys", "caught"]

## Does this box row fit on you right now? (Gems, seeds, gear and a backpack always do; your own
## Boki the dead hunter had taken always come back to you.)
static func fits(h: Hunter, row: Dictionary, b: Dictionary) -> bool:
	match String(row["key"]):
		"keys":
			return UtilityBelt.room_for(h, "rift_key") > 0
		"chest_keys":
			return UtilityBelt.room_for(h, "chest_key") > 0
		"caught":
			return Capture.room(h) or _is_yours(h, row, b)
		"pack", "belt":
			return bool(row.get("upgrade", true))
	return true

## Can this row be swapped for one of your backpack things (the hold window)?
static func holdable(row: Dictionary) -> bool:
	return String(row["key"]) == "pack"

## Rows still in the box that smart loot wanted but had no room for.
static func blocked(m: Match, h: Hunter, b: Dictionary) -> int:
	var n := 0
	for row in Life.box_items(m, h, b):
		if String(row["key"]) in NEEDS_ROOM and not fits(h, row, b):
			n += 1
	return n

## Smart loot with an honest report: what moved, out of what could have, and why the rest stayed.
## Returns how many things it took.
static func smart(m: Match, h: Hunter, b: Dictionary) -> int:
	var got := Life.smart_loot(m, h, b)
	if h == m.player and m.hud:
		m.hud.toast_small(smart_text(got, blocked(m, h, b)), Color("ffd36a"))
	return got

## The one-line report for a smart loot: took `got`, and `left` things had no room.
static func smart_text(got: int, left: int) -> String:
	if left <= 0:
		return "Took %d" % got if got > 0 else "Nothing here beats what you've got"
	if got <= 0:
		return "Inventory full, took nothing"
	return "Took %d of %d, inventory full" % [got, got + left]

## Hold window "Swap": your backpack thing i goes into the box, the held box thing takes its place.
## Returns false when either index is stale.
static func swap_held(m: Match, h: Hunter, b: Dictionary, held_i: int, mine_i: int) -> bool:
	if not _valid(h, b, held_i, mine_i):
		return false
	var held: Dictionary = (b["pack"] as Array)[held_i]
	var mine: Dictionary = h.pack[mine_i]
	(b["pack"] as Array)[held_i] = mine
	h.pack[mine_i] = held
	Life._settle_box(b)
	_told(m, h, "Swapped %s for %s" % [Loot.name_of(mine), Loot.name_of(held)], Loot.col_of(held))
	m.sfx("pickup", h.pos, -2.0, 0.95)
	return true

## Hold window "Drop": your backpack thing i goes on the ground, the held box thing takes its slot.
static func drop_for_held(m: Match, h: Hunter, b: Dictionary, held_i: int, mine_i: int) -> bool:
	if not _valid(h, b, held_i, mine_i):
		return false
	var held: Dictionary = (b["pack"] as Array).pop_at(held_i)
	var mine: Dictionary = h.pack[mine_i]
	Pack.drop_from_pack(m, h, mine_i)
	h.pack.append(held)
	Life._settle_box(b)
	_told(m, h, "Dropped %s for %s" % [Loot.name_of(mine), Loot.name_of(held)], Loot.col_of(held))
	m.sfx("pickup", h.pos, -2.0, 0.9)
	return true

## A click on a box row. Fits: it is taken. Doesn't: nothing moves and you are told why. Returns
## true only when something really moved.
static func click(m: Match, h: Hunter, b: Dictionary, row: Dictionary) -> bool:
	if fits(h, row, b):
		Life.take_item(m, h, b, row)
		return true
	denied(m, h, String(row["key"]))
	return false

## The "full" cue: the short rattle, and a plain line for the things that can't be swapped.
static func denied(m: Match, h: Hunter, key: String) -> void:
	Sfx.play("lock_rattle", null, -4.0)
	if key == "pack":
		return
	var what := "Box full" if key == "caught" else "Belt full"
	_told(m, h, what, FULL_COL, true)

static func _is_yours(h: Hunter, row: Dictionary, b: Dictionary) -> bool:
	var i := int(row.get("i", -1))
	var recs: Array = b["caught"]
	return i >= 0 and i < recs.size() and String(recs[i].get("lost_from", "")) == "you" and h.is_local()

static func _valid(h: Hunter, b: Dictionary, held_i: int, mine_i: int) -> bool:
	return held_i >= 0 and held_i < (b.get("pack", []) as Array).size() and mine_i >= 0 and mine_i < h.pack.size()

static func _told(m: Match, h: Hunter, txt: String, col: Color, small := false) -> void:
	if h == m.player and m.hud:
		if small:
			m.hud.toast_small(txt, col)
		else:
			m.hud.toast(txt, col)
