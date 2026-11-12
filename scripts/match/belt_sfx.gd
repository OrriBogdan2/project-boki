class_name BeltSfx
extends RefCounted
## The sounds of the belt items, one row per item id in content/rules/belt_sfx.json (never by effect
## type): "start" when it is used, "loop" while it channels, "end" when the channel finishes, "cancel"
## when it is spilt. Positional at the Hunter and carried to fight range (content/sfx/belt.json "reach"),
## so a rival drinking a tonic or popping smoke is heard. Items whose use lasts ("beds" in the rules) keep
## a loop going at their spot while they run, then play their "end": Skyfall's fuse is one, heard by all
## near; an instant one plays its "end" a moment after the use (its "tails" seconds).
## Online, the game that runs the Hunter sends each cue it plays (the "fx" "belt" event, net_in) and the
## other games play it at the same spot; a start also begins the bed there, on their own clock.

const RULES := "res://content/rules/belt_sfx.json"
const VOL_DB := -2.0           # dB at the Hunter; the files are levelled to their category
const BUFF_DB := -10.0         # dB of a "buff" bed's loop: a hum under the fight, not over it
const FRONT_M := 1.6           # m ahead of the user for a "front" bed with no "range" (a pad's spot)
const PAD_M := 3.0             # m: a pad's bed is the nearest one of its id within this

static var _items: Dictionary = {}
static var _beds_of: Dictionary = {}
static var _tails: Dictionary = {}
static var _beds: Array = []     # live beds: {m, key, id, h (beds that follow), at, left, db, shield, had, told}
static var _bed_n := 0

static func items() -> Dictionary:
	if _items.is_empty():
		var rules := JSON.parse_string(FileAccess.get_file_as_string(RULES)) as Dictionary
		_items = rules["items"]
		_beds_of = rules["beds"]
		_tails = rules["tails"]
	return _items

## How long an item's use runs: its "time" or "life", else its first effect's "time" or "delay", else its tail.
static func bed_time(id: String) -> float:
	var d := UtilityBelt.def(id)
	if d.has("time") or d.has("life"):
		return float(d.get("time", d.get("life", 0.0)))
	var e := (d.get("effects", [{}]) as Array)[0] as Dictionary
	var t := float(e.get("time", e.get("delay", 0.0)))
	items()
	return t if t > 0.0 else float(_tails.get(id, 0.0))

## The sound id for item `id` and kind ("start", "loop", "end", "cancel"), or "" when it has none.
static func cue(id: String, kind: String) -> String:
	return String((items().get(id, {}) as Dictionary).get(kind, ""))

## Plays the cue at the Hunter; the game running that Hunter tells the others (with `at`, a start's bed spot).
static func play(h: Hunter, id: String, kind: String, at = null) -> void:
	play_at(h.m, id, kind, h.pos)
	if h.m.net_on and not h.remote:
		h.m.net_fx(msg(h, id, kind, h.pos if at == null else at))

static func play_at(m: Node, id: String, kind: String, pos: Vector3) -> void:
	var c := cue(id, kind)
	if c != "":
		m.sfx(c, pos, VOL_DB)

## The "fx" event for a cue: [belt, hunter, item, kind, x, y, z] (for a start, the spot of its bed).
static func msg(h: Hunter, id: String, kind: String, at: Vector3) -> Array:
	return ["belt", h.nid, id, kind, Match._r(at.x), Match._r(at.y), Match._r(at.z)]

## The item is used: its start cue, and if its use lasts, its bed begins.
static func start(h: Hunter, id: String) -> void:
	items()
	var mode := String(_beds_of.get(id, ""))
	var reach = UtilityBelt.def(id).get("range")
	var at := h.pos
	if mode == "aim":
		at = Effects._aim_point(h, {"reach": Effects.HUNTER_REACH if reach == null else float(reach)})
	elif mode == "front":
		at = UtilityMore.spot(h, FRONT_M if reach == null else float(reach))
	play(h, id, "start", at)
	_begin(h, id, at)

static func _begin(h: Hunter, id: String, at: Vector3) -> void:
	var mode := String(_beds_of.get(id, ""))
	if mode == "":
		return
	_bed_n += 1
	var follow = h if mode in ["self", "buff"] else null
	var buff := (UtilityBelt.def(id).get("effects", [{}]) as Array)[0] as Dictionary
	_beds.append({"m": h.m, "key": "bed%d" % _bed_n, "id": id, "h": follow, "at": at, "left": bed_time(id),
			"db": BUFF_DB if mode == "buff" else VOL_DB, "shield": String(buff.get("type", "")) == "shield"})

## Another player's channel: its loop on this game's clock; the end or cancel comes from their game.
static func _channel_bed(h: Hunter, id: String) -> void:
	var secs := UtilityUse.channel(id, "time")
	_beds.append({"m": h.m, "key": loop_key(h, id), "id": id, "h": h, "at": h.pos, "left": secs,
			"db": VOL_DB, "shield": false, "told": true})

## Another game's cue for one of its Hunters (the "fx" "belt" event): played here at the same spot.
static func net_in(m: Node, x: Array) -> void:
	var h: Variant = m.ents_by_id.get(String(x[1]), null)
	if not h is Hunter:
		return
	var id := String(x[2])
	var kind := String(x[3])
	var at := Vector3(x[4], x[5], x[6])
	if kind == "start":
		play_at(m, id, kind, h.pos)
		_begin(h, id, at)
		if UtilityUse.use_of(id) in ["drink", "repair"]:
			_channel_bed(h, id)
		return
	_drop(loop_key(h, id))
	play_at(m, id, kind, at)

static func _drop(key: String) -> void:
	Sfx.loop_stop(key)
	for i in range(_beds.size() - 1, -1, -1):
		if _beds[i]["key"] == key:
			_beds.remove_at(i)

## A pad that launched someone (or a pack picked up) stands only `secs` more: its bed (the nearest of its
## id) is cut to match.
static func cut(m: Node, id: String, at: Vector3, secs: float) -> void:
	for b in _beds:
		if b["m"] == m and b["id"] == id and Vector2(b["at"].x - at.x, b["at"].z - at.z).length() < PAD_M:
			b["left"] = minf(b["left"], secs)
			return

## Every frame (from UtilityMore.pads): holds each live bed's loop, and ends it with its end cue when its
## time is up or its shield is broken. A bed whose match is gone, or whose owner went out, just stops.
static func tick(m: Node, dt: float) -> void:
	for i in range(_beds.size() - 1, -1, -1):
		var b: Dictionary = _beds[i]
		var who = b["h"]
		var gone: bool = who != null and (not is_instance_valid(who) or who.out or who.downed)
		if not is_instance_valid(b["m"]) or gone:
			Sfx.loop_stop(b["key"])
			_beds.remove_at(i)
		elif b["m"] == m:
			b["left"] -= dt
			var pos: Vector3 = who.pos if who != null else b["at"]
			if b["shield"] and who.shield > 0.0:
				b["had"] = true       # (another player's shield shows up with their next snapshot)
			if b["left"] <= 0.0 or (b.get("had", false) and who.shield <= 0.0):
				Sfx.loop_stop(b["key"])
				if not b.get("told", false):
					play_at(m, b["id"], "end", pos)
				_beds.remove_at(i)
			elif cue(b["id"], "loop") != "":
				Sfx.loop_hold(b["key"], cue(b["id"], "loop"), pos, b["db"])

static func loop_key(h: Hunter, id: String) -> String:
	return "belt%d_%s" % [h.get_instance_id(), id]

## Called every step while a channel runs (on) or may just have been spilt: keeps the loop going, and
## when it stops without a finish (the finish stops it first) plays the cancel cue.
static func channel(h: Hunter, id: String, on: bool) -> void:
	var key := loop_key(h, id)
	if on:
		Sfx.loop_hold(key, cue(id, "loop"), h.pos, VOL_DB)
	elif Sfx.loop_on(key):
		Sfx.loop_stop(key)
		play(h, id, "cancel")
