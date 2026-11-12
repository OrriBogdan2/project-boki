class_name GardenItems
extends RefCounted
## The garden's shaping items (content/rules/garden_items.json, briefs/design/GARDEN_MODERN.md section 1):
## each one moves one thing on one Boki and says the exact change first. preview() is that change as numbers
## (after caps), apply() does exactly it and writes the journal line. They sit in the garden bag
## (Save.d items) and are fed from the feed menu (Care.feed hands them to feed()). Worn ones (path tokens,
## Stayleaf) go in rec.path / rec.stay and come off again with take_off(). Sweets (a lean to pick) go through
## use(), the Twinbun (two Boki) through share().

static func rules() -> Dictionary:
	return Content.rules("garden_items")

static func ids() -> Array:
	var out: Array = []
	for it in rules()["items"]:
		out.append(String(it["id"]))
	return out

## The stat bite a lair pile holds beside its gear, or "" when this pile has none (roll in 0..1).
static func lair_drop(roll: float, pick: int) -> String:
	var d: Dictionary = rules()["lair_drop"]
	return String(d["ids"][pick % d["ids"].size()]) if roll < float(d["chance"]) else ""

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
## pick: the lean type a sweet is eaten for ("" = the one it leans to most, else the first).
static func preview(rec: Dictionary, id: String, pick := "") -> Dictionary:
	Care.ensure(rec)
	var e: Dictionary = item(id)["effect"]
	match String(e["kind"]):
		"stat": return _stat(rec, String(e["stat"]), int(e["n"]))
		"xp": return _xp(rec, int(e["n"]))
		"token": return _token(rec, String(e["aff"]))
		"stay": return _stay(rec)
		"rinse": return _rinse(rec)
		"nest": return _no("goes in the Nesting Nook with a pair")
		"down": return _down(rec, int(e["trust"]))
		"stat_all": return _stat_all(rec, int(e["n"]))
		"sweet": return _sweet(rec, e, pick)
		"trait": return _trait(rec, String(e["trait"]), float(e["by"]))
		"twin": return _no("shared by two Boki: give it to a pair")
		_: return _loose(rec, int(e["n"]))

## Does it: returns the preview it followed. Not usable (ok false) changes nothing.
static func apply(rec: Dictionary, id: String, pick := "") -> Dictionary:
	var pv := preview(rec, id, pick)
	if not pv["ok"]:
		return pv
	var d: Dictionary = pv["deltas"]
	if d.has("xp"):
		Game.add_xp(rec, int(item(id)["effect"]["n"]), {})      # levels and forms follow
	else:
		_write(rec, d)
	if String(item(id)["effect"]["kind"]) == "down":
		Save.remember(rec, "down", NestItems.take_memory())
	CareJournal.note(rec, "%s %s: %s" % [_verb(id), item_name(id), pv["text"]])
	_remember(rec, id, String(pv["text"]))
	return pv

static func _write(rec: Dictionary, deltas: Dictionary) -> void:
	for key in deltas:
		var after: Variant = deltas[key][1]
		if key.begins_with("stats."): rec["stats"][key.substr(6)] = after
		else: rec[key] = after.duplicate(true) if typeof(after) in [TYPE_ARRAY, TYPE_DICTIONARY] else after

static func _verb(id: String) -> String:
	var it := item(id)
	return String(it.get("verb", rules()["verbs"][it["use"]]))

## Takes one from the bag and applies it (a sweet with its pick): the result of apply() plus look
## (the body colour changed).
static func use(rec: Dictionary, id: String, pick := "") -> Dictionary:
	var pv := apply(rec, id, pick) if Save.d["items"].get(id, 0) > 0 else _no("none left")
	if pv["ok"]:
		Save.d["items"][id] = int(Save.d["items"][id]) - 1
	pv["look"] = pv["ok"] and String(item(id)["effect"]["kind"]) == "sweet"
	pv["text"] = "%s: %s" % [item_name(id), pv["text"]] if pv["ok"] else pv["text"]
	return pv

## A Twinbun between two Boki: what it does to both and to the bond between them.
## {ok, text, a: deltas, b: deltas, bond: [before, after]}.
static func preview_share(a: Dictionary, b: Dictionary, id: String) -> Dictionary:
	Care.ensure(a)
	Care.ensure(b)
	var e: Dictionary = item(id)["effect"]
	var pa := _trait(a, String(e["trait"]), float(e["by"]))
	var pb := _trait(b, String(e["trait"]), float(e["by"]))
	var was := BaseLife.bond(a, b)
	var now := minf(1.0, was + float(e["bond"]))
	if not (pa["ok"] or pb["ok"] or now > was):
		return _no("nothing left to share this week")
	var text := "%s: %s; %s: %s; their bond %.2f to %.2f" % [a["name"], pa["text"], b["name"], pb["text"], was, now]
	return {"ok": true, "text": text, "a": pa["deltas"], "b": pb["deltas"], "bond": [was, now]}

## Takes a Twinbun from the bag and gives it to the pair. Same result shape as use() (plus the preview's).
static func share(a: Dictionary, b: Dictionary, id: String) -> Dictionary:
	var pv := preview_share(a, b, id)
	if not pv["ok"] or int(Save.d["items"].get(id, 0)) <= 0:
		return _no(pv["text"] if not pv["ok"] else "none left")
	Save.d["items"][id] = int(Save.d["items"][id]) - 1
	_write(a, pv["a"])
	_write(b, pv["b"])
	BaseLife.add_bond(a, b, float(item(id)["effect"]["bond"]))
	CareJournal.note(a, "%s %s with %s" % [_verb(id), item_name(id), b["name"]])
	CareJournal.note(b, "%s %s with %s" % [_verb(id), item_name(id), a["name"]])
	pv["look"] = false
	pv["text"] = "%s shared: %s" % [item_name(id), pv["text"]]
	return pv

## The uses kept for an item's Field Book page: [{boki, text}], newest last.
static func uses(id: String) -> Array:
	return Save.d.get("item_log", {}).get(id, [])

static func _remember(rec: Dictionary, id: String, text: String) -> void:
	var log: Dictionary = Save.d.get("item_log", {})
	var mine: Array = log.get(id, [])
	mine.append({"boki": String(rec.get("name", "")), "text": text})
	if mine.size() > int(rules()["log_keep"]):
		mine.pop_front()
	log[id] = mine
	Save.d["item_log"] = log

## Has it ever been in the bag? In the bag now, or used on a Boki (worn ones are out of the bag).
static func owned(id: String) -> bool:
	return int(Save.d["items"].get(id, 0)) > 0 or not uses(id).is_empty()

## Item ids of one family, in file order.
static func family_ids(fam: String) -> Array:
	return ids().filter(func(id): return item(id)["family"] == fam)

## Every item of the family has been owned: the page shows a star.
static func family_done(fam: String) -> bool:
	return family_ids(fam).all(func(id): return owned(id))

static func family_name(fam: String) -> String:
	return String(rules()["families"].get(fam, {}).get("name", fam.capitalize()))

## What the item nudges, in words (the page's one line; preview() has the exact numbers for a Boki).
static func nudge(id: String) -> String:
	var e: Dictionary = item(id)["effect"]
	match String(e["kind"]):
		"stat": return "+%d %s, up to the limit for its level" % [int(e["n"]), Care.STATS[e["stat"]]["name"]]
		"xp": return "+%d xp" % int(e["n"])
		"token": return "1 step toward %s when a form is chosen" % String(Evo.AFF[e["aff"]]["name"]).to_lower()
		"stay": return "no new forms while worn"
		"rinse": return "clears the lean; the grown parts stay"
		_: return "%d points of the top stat become loose points" % int(e["n"])

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
	return {"ok": false, "text": why, "deltas": {}, "look": false}

static func _yes(text: String, deltas: Dictionary) -> Dictionary:
	return {"ok": true, "text": text, "deltas": deltas}

static func _stat(rec: Dictionary, s: String, n: int) -> Dictionary:
	var now := int(rec["stats"].get(s, 0))
	var gain := mini(n, Care.stat_cap(rec) - now)
	var nm: String = Care.STATS[s]["name"]
	if gain <= 0:
		return _no("%s is at its limit for level %d" % [nm, int(rec["level"])])
	return _yes("%s +%d (%d to %d)" % [nm, gain, now, now + gain], {"stats." + s: [now, now + gain]})

static func _stat_all(rec: Dictionary, n: int) -> Dictionary:
	var d := {}
	var bits: Array = []
	for s in Care.STATS:
		var now := int(rec["stats"].get(s, 0))
		var gain := mini(n, Care.stat_cap(rec) - now)
		if gain > 0:
			d["stats." + s] = [now, now + gain]
			bits.append("%s %d" % [Care.STATS[s]["name"], now + gain])
	if d.is_empty():
		return _no("every stat is at its limit for level %d" % int(rec["level"]))
	return _yes("+%d to %s" % [n, ", ".join(bits)], d)

## A sweet: the picked type's lean jumps to its share of full and is held (see Evo.eat, day()).
static func _sweet(rec: Dictionary, e: Dictionary, pick: String) -> Dictionary:
	var types: Array = e["types"]
	var ln: Dictionary = rec.get("lean", {})
	if not types.has(pick):
		pick = types[0]
		for t in types:
			if float(ln.get(t, 0.0)) > float(ln.get(pick, 0.0)):
				pick = t
	var to := float(e["share"]) * Evo.LEAN_FULL
	var now := float(ln.get(pick, 0.0))
	var nm: String = Lean.face(pick)["name"]
	if now >= to:
		return _no("already leans %s %d of %d" % [nm, roundi(now), roundi(Evo.LEAN_FULL)])
	var days := int(e["hold_days"])
	var lean := ln.duplicate()
	lean[pick] = to
	var hold: Dictionary = rec["hold"].duplicate()
	hold[pick] = days
	var text := "%s lean %d to %d of %d, kept %d days" % [nm, roundi(now), roundi(to), roundi(Evo.LEAN_FULL), days]
	return _yes(text, {"lean": [ln.duplicate(), lean], "hold": [rec["hold"].duplicate(), hold]})

## A trait item: the trait moves by `by` (after the 0.05..0.95 clamp), and what it moves counts in the
## drift week (rec.drift.moved), which BaseDrift caps at week_cap in all. Partial when the cap is near.
static func _trait(rec: Dictionary, tr: String, by: float) -> Dictionary:
	var R := Content.rules("base_drift")
	var was_drift: Dictionary = rec.get("drift", {"day": 0, "moved": {}})
	var moved := float(was_drift["moved"].get(tr, 0.0))
	var room := maxf(float(R["week_cap"]) - moved, 0.0)
	var was := float(rec["traits"].get(tr, 0.5))
	var to := clampf(was + signf(by) * minf(absf(by), room), 0.05, 0.95)
	if absf(to - was) < 0.001:
		return _no("%s: nothing more this week" % tr.capitalize())
	var drift: Dictionary = was_drift.duplicate(true)
	drift["moved"][tr] = moved + absf(to - was)
	var traits: Dictionary = rec["traits"].duplicate()
	traits[tr] = to
	var word: String = R["words"][tr][0 if by > 0.0 else 1]
	var text := "%s %+.2f (%.2f to %.2f), %s" % [tr.capitalize(), to - was, was, to, word]
	var then: String = Care.nature({"traits": traits})
	if then != Care.nature(rec):
		text += "; Nature: %s to %s" % [Care.nature(rec), then]
	return _yes(text, {"traits": [rec["traits"].duplicate(), traits], "drift": [was_drift, drift]})

## A garden day passed: a held lean (rec.hold, days left) counts down and is let go at zero.
static func day(rec: Dictionary) -> void:
	var hold: Dictionary = rec.get("hold", {})
	for t in hold.keys():
		hold[t] = int(hold[t]) - 1
		if int(hold[t]) <= 0:
			hold.erase(t)

static func _xp(rec: Dictionary, n: int) -> Dictionary:
	var lv := int(rec["level"])
	var xp := int(rec["xp"]) + n
	while xp >= Game.xp_need(lv):
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

## False for items that are not fed (nest items are placed in the Nook).
static func fed(id: String) -> bool:
	return String(item(id)["effect"]["kind"]) != "nest"

## The line the items list shows under an item in the bag.
static func bag_hint(id: String) -> String:
	if fed(id):
		return "Shapes a Boki: feed it from its card."
	return "Goes in the Nesting Nook with a pair."

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

static func _down(rec: Dictionary, n: int) -> Dictionary:
	var now := float(rec["trust"])
	var gain := minf(float(n), 100.0 - now)
	if gain <= 0.0:
		return _no("trust is already full")
	var text := "trust +%d (%d to %d): %s" % [int(gain), int(now), int(now + gain), NestItems.memory_line()]
	return _yes(text, {"trust": [now, now + gain]})

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
