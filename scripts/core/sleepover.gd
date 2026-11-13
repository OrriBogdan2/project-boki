class_name Sleepover
extends RefCounted
## A Boki spends a day at a friend's garden (docs/decisions/0022-sleepovers.md). It leaves the roster for
## Save.d["sleepovers"]; a day later it comes home with a memory line, a trait nudge toward the friend's lead
## Boki, a seed from their patch and, for a "trade_to" species, its next form. The friend's side is only their
## existing profile snapshot (Social.clean_island), so no Net message is involved.

const DAY_SECS := 86400.0     # s a Boki stays away
const MAX_AWAY := 2           # Boki away at once
const TRAIT_PULL := 0.1       # share of the gap to the host Boki's trait closed on return
const TRUST_GAIN := 2.0       # trust a visit adds

static func list() -> Array:
	if typeof(Save.d.get("sleepovers")) != TYPE_ARRAY:
		Save.d["sleepovers"] = []
	return Save.d["sleepovers"]

## Why this Boki cannot go ("" if it can).
static func why_not(rec: Dictionary) -> String:
	if list().size() >= MAX_AWAY:
		return "Two Boki are already away."
	if String(Save.d.get("active", "")) == String(rec.get("uid", "")):
		return "Your lead Boki stays with you."
	if (Save.d["roster"] as Array).size() < 2:
		return "You need another Boki at home."
	return ""

## Sends rec to friend_id's garden. Returns false when it cannot go.
static func send(rec: Dictionary, friend_id: String, friend_name: String, now: float) -> bool:
	if why_not(rec) != "" or friend_id == "":
		return false
	(Save.d["roster"] as Array).erase(rec)
	list().append({"rec": rec, "to": friend_id, "name": friend_name, "t": now})
	Save.log_event("sleepover", rec, {"to": friend_name})
	return true

## The sleepovers that have lasted a day.
static func due(now: float) -> Array:
	return list().filter(func(s): return now - float(s["t"]) >= DAY_SECS)

## Brings one home. host is the friend's cleaned island ({} if unreachable: only the memory line).
## opening replaces the first sentence (a clan loan's line). Returns {line, gift} (gift is a crop key or "").
static func come_home(stay: Dictionary, host: Dictionary, opening := "") -> Dictionary:
	var rec: Dictionary = stay["rec"]
	var who := String(stay["name"])
	var line := opening if opening != "" else "%s had a sleepover at %s's." % [rec["name"], who]
	var gift := ""
	var lead: Array = host.get("roster", [])
	if not lead.is_empty():
		var theirs: Dictionary = lead[0]["traits"]
		for k in theirs:
			if rec["traits"].has(k):
				rec["traits"][k] = clampf(lerpf(float(rec["traits"][k]), float(theirs[k]), TRAIT_PULL), 0.05, 0.95)
		line += " It spent the day with %s." % lead[0]["name"]
	gift = _patch_seed(host)
	if gift != "":
		Save.add_seed(gift, 1)
		line += " It brought back a %s seed." % Data.CROPS[gift]["name"]
	Save.remember(rec, "sleepover", line, TRUST_GAIN)
	list().erase(stay)
	var to := String(Data.KIN[rec["species"]].get("trade_to", ""))
	if to != "":
		Save.log_event("evolved", rec, {"kind": "trade", "to": to})
		rec["species"] = to
		line += " On the way home it changed into a %s!" % Data.KIN[to]["name"]
	(Save.d["roster"] as Array).append(rec)
	KinBox.route_back(rec)
	Care.dex_got(rec)
	return {"line": line, "gift": gift}

## A crop growing on the host's plots, else the first crop they plant at all.
static func _patch_seed(host: Dictionary) -> String:
	for p in host.get("plots", []):
		if String(p["crop"]) != "":
			return String(p["crop"])
	return ""

## Brings home every Boki that has stayed a day. cb gets the lines.
static func collect(cb: Callable) -> void:
	var now := Time.get_unix_time_from_system()
	var stays := due(now)
	if stays.is_empty():
		cb.call([])
		return
	var lines: Array = []
	_next(stays, lines, cb)

static func _next(stays: Array, lines: Array, cb: Callable) -> void:
	if stays.is_empty():
		if not lines.is_empty():
			Save.save_game()
		cb.call(lines)
		return
	var stay: Dictionary = stays[0]
	var then := func(line: String):
		lines.append(line)
		_next(stays.slice(1), lines, cb)
	if stay.has("clan"):
		ClanLoan.come_home(stay, then)
		return
	Social.get_doc("profiles/" + String(stay["to"]), func(p: Dictionary):
		then.call(come_home(stay, Social.clean_island(p))["line"]))
