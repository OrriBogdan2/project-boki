class_name GardenItems
extends RefCounted
## The garden's shaping items (content/rules/garden_items.json, briefs/design/GARDEN_MODERN.md section 1):
## each one moves one thing on one Boki and says the exact change first. preview() is that change as numbers
## (after caps), apply() does exactly it and writes the journal line. They sit in the garden bag
## (Save.d items) and are fed from the feed menu (Care.feed hands them to feed()). Worn ones (path tokens,
## Stayleaf) go in rec.path / rec.stay and come off again with take_off().

static func rules() -> Dictionary:
	return Content.rules("garden_items")

static func ids() -> Array:
	var out: Array = []
	for it in rules()["items"]:
		out.append(String(it["id"]))
	return out

static func has(id: String) -> bool:
	return not item(id).is_empty()

static func item(id: String) -> Dictionary:
	for it in rules()["items"]:
		if it["id"] == id:
			return it
	return {}

static func item_name(id: String) -> String:
	return String(item(id).get("name", id))

## A field a preview speaks of: "stats.power" is rec.stats.power, anything else is rec[key].
static func value(rec: Dictionary, key: String) -> Variant:
	if key.begins_with("stats."):
		return int(rec["stats"].get(key.substr(6), 0))
	return rec.get(key)

## The token ids this Boki wears, in order.
static func worn(rec: Dictionary) -> Array:
	return rec.get("path", [])

## What the item would do to this Boki: {ok, text, deltas}. deltas maps a field (see value()) to
## [before, after]; text is the one line the menu and the journal show, or why it can't be used.
static func preview(rec: Dictionary, id: String) -> Dictionary:
	Care.ensure(rec)
	var e: Dictionary = item(id)["effect"]
	match String(e["kind"]):
		"stat": return _stat(rec, String(e["stat"]), int(e["n"]))
		"xp": return _xp(rec, int(e["n"]))
		"token": return _token(rec, String(e["aff"]))
		"stay": return _stay(rec)
		"rinse": return _rinse(rec)
		_: return _loose(rec, int(e["n"]))

## Does it: returns the preview it followed. Not usable (ok false) changes nothing.
static func apply(rec: Dictionary, id: String) -> Dictionary:
	var pv := preview(rec, id)
	if not pv["ok"]:
		return pv
	var d: Dictionary = pv["deltas"]
	if d.has("xp"):
		Game.add_xp(rec, int(item(id)["effect"]["n"]), {})      # levels and forms follow
	else:
		for key in d:
			var after: Variant = d[key][1]
			if key.begins_with("stats."): rec["stats"][key.substr(6)] = after
			else: rec[key] = after.duplicate(true) if typeof(after) in [TYPE_ARRAY, TYPE_DICTIONARY] else after
	var it := item(id)
	var verb := String(it.get("verb", rules()["verbs"][it["use"]]))
	CareJournal.note(rec, "%s %s: %s" % [verb, it["name"], pv["text"]])
	return pv

## Takes a worn item off and puts it back in the bag. False if the Boki isn't wearing it.
static func take_off(rec: Dictionary, id: String) -> bool:
	Care.ensure(rec)
	if String(item(id)["effect"]["kind"]) == "stay":
		if not rec["stay"]:
			return false
		rec["stay"] = false
	elif rec["path"].has(id):
		rec["path"].erase(id)
	else:
		return false
	Save.add_item(id, 1)
	CareJournal.note(rec, "took off %s" % item_name(id))
	return true

## Care.feed for an item: the result the feed menu expects. look: its colour changed, redraw it.
static func feed(rec: Dictionary, id: String) -> Dictionary:
	var pv := apply(rec, id)
	return {"ok": pv["ok"], "love": false, "hate": false, "full": false, "new": false, "lean": "",
			"text": ("%s: %s" % [item_name(id), pv["text"]]), "look": item(id)["effect"]["kind"] == "rinse"}

static func _no(why: String) -> Dictionary:
	return {"ok": false, "text": why, "deltas": {}}

static func _yes(text: String, deltas: Dictionary) -> Dictionary:
	return {"ok": true, "text": text, "deltas": deltas}

static func _stat(rec: Dictionary, s: String, n: int) -> Dictionary:
	var now := int(rec["stats"].get(s, 0))
	var gain := mini(n, Care.stat_cap(rec) - now)
	var nm: String = Care.STATS[s]["name"]
	if gain <= 0:
		return _no("%s is at its limit for level %d" % [nm, int(rec["level"])])
	return _yes("%s +%d (%d to %d)" % [nm, gain, now, now + gain], {"stats." + s: [now, now + gain]})

static func _xp(rec: Dictionary, n: int) -> Dictionary:
	var lv := int(rec["level"])
	var xp := int(rec["xp"]) + n
	while lv < Evo.cap() and xp >= Game.xp_need(lv):
		xp -= Game.xp_need(lv)
		lv += 1
	var d := {"xp": [int(rec["xp"]), xp]}
	if lv == int(rec["level"]):
		return _yes("+%d xp (%d to %d)" % [n, d["xp"][0], xp], d)
	d["level"] = [int(rec["level"]), lv]
	return _yes("+%d xp: level %d to %d" % [n, int(rec["level"]), lv], d)

static func _token(rec: Dictionary, aff: String) -> Dictionary:
	var path: Array = rec["path"]
	if path.size() >= int(rules()["max_tokens"]):
		return _no("already wears %d tokens: take one off first" % path.size())
	var toward := String(Evo.AFF[aff]["name"]).to_lower()
	var text := "1 step toward %s (%d of %d tokens)" % [toward, path.size() + 1, int(rules()["max_tokens"])]
	return _yes(text, {"path": [path.duplicate(), path + [_token_id(aff)]]})

static func _token_id(aff: String) -> String:
	for it in rules()["items"]:
		if it["effect"].get("aff", "") == aff:
			return String(it["id"])
	return ""

## The path an item's token pushes toward ("" for other items).
static func aff_of(id: String) -> String:
	return String(item(id)["effect"].get("aff", ""))

static func _stay(rec: Dictionary) -> Dictionary:
	if rec["stay"]:
		return _no("already staying small")
	return _yes("stays small: no new forms while worn", {"stay": [false, true]})

static func _rinse(rec: Dictionary) -> Dictionary:
	if Care.lean_total(rec) <= 0.0:
		return _no("no lean to rinse off")
	return _yes("lean cleared; the grown parts stay", {"lean": [rec["lean"].duplicate(), {}]})

static func _loose(rec: Dictionary, n: int) -> Dictionary:
	var best := "power"
	for s in Care.STATS:
		if int(rec["stats"].get(s, 0)) > int(rec["stats"].get(best, 0)):
			best = s
	var now := int(rec["stats"].get(best, 0))
	var take := mini(n, now)
	if take <= 0:
		return _no("no trained points to loosen")
	var loose := int(rec["loose"])
	return _yes("%d %s points come out as loose points" % [take, Care.STATS[best]["name"]],
			{"stats." + best: [now, now - take], "loose": [loose, loose + take]})
