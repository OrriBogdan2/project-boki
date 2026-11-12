class_name BeltSfx
extends RefCounted
## The sounds of the belt items, one row per item id in content/rules/belt_sfx.json (never by effect
## type): "start" when it is used, "loop" while it channels, "end" when the channel finishes, "cancel"
## when it is spilt. Positional at the Hunter and carried to fight range (content/sfx/belt.json "reach"),
## so a rival drinking a tonic or popping smoke is heard. Placed items ("beds" in the rules) keep a loop
## going at their spot while they stand, then play their "end": Skyfall's fuse is one, heard by all near.

const RULES := "res://content/rules/belt_sfx.json"
const VOL_DB := -2.0           # dB at the Hunter; the files are levelled to their category
const FRONT_M := 2.0           # m ahead of the user for a "front" bed

static var _items: Dictionary = {}
static var _beds_of: Dictionary = {}
static var _beds: Array = []     # live beds: {m, key, id, h (self beds), at, left}
static var _bed_n := 0

static func items() -> Dictionary:
	if _items.is_empty():
		var rules := JSON.parse_string(FileAccess.get_file_as_string(RULES)) as Dictionary
		_items = rules["items"]
		_beds_of = rules["beds"]
	return _items

## How long a placed item stands: its "time" or "life", else the first effect's "time".
static func bed_time(id: String) -> float:
	var d := UtilityBelt.def(id)
	if d.has("time") or d.has("life"):
		return float(d.get("time", d.get("life", 0.0)))
	return float(((d.get("effects", [{}]) as Array)[0] as Dictionary).get("time", 0.0))

## The sound id for item `id` and kind ("start", "loop", "end", "cancel"), or "" when it has none.
static func cue(id: String, kind: String) -> String:
	return String((items().get(id, {}) as Dictionary).get(kind, ""))

static func play(h: Hunter, id: String, kind: String) -> void:
	play_at(h.m, id, kind, h.pos)

static func play_at(m: Node, id: String, kind: String, pos: Vector3) -> void:
	var c := cue(id, kind)
	if c != "":
		m.sfx(c, pos, VOL_DB)

## The item is used: its start cue, and if it stands in the world, its bed begins.
static func start(h: Hunter, id: String) -> void:
	play(h, id, "start")
	items()
	var mode := String(_beds_of.get(id, ""))
	if mode == "":
		return
	var a := h.aim_dir()
	var at := h.pos
	if mode == "aim":
		at = Effects._aim_point(h, {})
	elif mode == "front":
		at = Vector3(h.pos.x + a.x * FRONT_M, h.pos.y, h.pos.z + a.y * FRONT_M)
	_bed_n += 1
	var follow = h if mode == "self" else null
	_beds.append({"m": h.m, "key": "bed%d" % _bed_n, "id": id, "h": follow, "at": at, "left": bed_time(id)})

## Every frame (from UtilityMore.pads): holds each live bed's loop, and ends it with its end cue when its
## time is up. A bed whose match is gone, or whose owner went out, just stops.
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
			if b["left"] <= 0.0:
				Sfx.loop_stop(b["key"])
				play_at(m, b["id"], "end", pos)
				_beds.remove_at(i)
			else:
				Sfx.loop_hold(b["key"], cue(b["id"], "loop"), pos, VOL_DB)

## A placed item taken back down before its time: its bed stops without the end cue.
static func drop_bed(m: Node, id: String, at: Vector3) -> void:
	for i in range(_beds.size() - 1, -1, -1):
		var b: Dictionary = _beds[i]
		if b["m"] == m and b["id"] == id and b["h"] == null and (b["at"] as Vector3).distance_to(at) < 1.0:
			Sfx.loop_stop(b["key"])
			_beds.remove_at(i)
			return

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
