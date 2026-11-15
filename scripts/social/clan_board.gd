class_name ClanBoard
extends RefCounted
## The clan's weekly goal on the showcase wall (docs/decisions/0087-clan-board.md). Each member writes only
## their own row, clanboard/<gid>_<me> = {guild, week, cup, final, extract, paid, updated}; the board is the
## sum of this week's rows of the current members, cleaned by clean_rows. Numbers: content/rules/clan_board.json.

const KINDS := ["cup", "final", "extract"]
const WEEK_S := 604800.0        # seconds in a board week (unix weeks, by the device clock)

static var _rules := {}
static var _pending := {}       # kind -> count not written yet (a write was in flight, or it failed)
static var _writing := false    # one write of your row at a time, so two adds can't overwrite each other

static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = Content.rules("clan_board")
	return _rules

static func week_now() -> int:
	return int(Time.get_unix_time_from_system() / WEEK_S)

## The week's goal in points for a clan of `members`.
static func goal(members: int) -> int:
	return maxi(int(rules()["goal_min"]), int(rules()["goal_per_member"]) * members)

## Counts one thing you did for your clan this week: "cup", "final" or "extract". Nothing outside a clan
## or without the store.
static func add(kind: String) -> void:
	var gid := Social.my_guild_id()
	if gid == "" or not Social.ok or Social.me == "" or not KINDS.has(kind):
		return
	_pending[kind] = int(_pending.get(kind, 0)) + 1
	_flush(gid)

static func _flush(gid: String) -> void:
	if _writing or _pending.is_empty():
		return
	_writing = true
	var adding := _pending
	_pending = {}
	_write_mine(gid, adding, false, func(okk: bool):
		_writing = false
		if not okk:
			for k in adding:
				_pending[k] = int(_pending.get(k, 0)) + int(adding[k])
			return
		_flush(gid))

## Reads your own row (a new one if it is another clan's or week's), adds `adding`, marks it paid if `pay`,
## writes it back. done gets false if the write failed or `pay` finds it paid already.
static func _write_mine(gid: String, adding: Dictionary, pay: bool, done: Callable) -> void:
	var path := "clanboard/%s_%s" % [gid, Social.me]
	var week := week_now()
	Social.get_doc(path, func(d: Dictionary):
		var fresh: bool = Social.txt_of(d.get("guild")) != gid or Social.int_of(d.get("week")) != week
		var row := _share(Social.me, {} if fresh else d)
		if pay and row["paid"]:
			done.call(false)
			return
		var doc := {"guild": gid, "week": week, "paid": pay or row["paid"], "updated": Social.now_ms()}
		for k in KINDS:
			doc[k] = int(row[k]) + int(adding.get(k, 0))
		Social.set_doc(path, doc, done))

## cb gets this week's board: {goal, total, done, shares}; shares as clean_rows gives them, best first.
## members: the clan's member ids.
static func read(gid: String, members: Array, cb: Callable) -> void:
	var week := week_now()
	var where := [["guild", "==", gid], ["week", "==", week]]
	Social.query("clanboard", where, "", "asc", Social.CLAN_CAP * 2, func(rows: Array):
		cb.call(board(clean_rows(rows, gid, week, members), members.size())))

static func board(shares: Array, members: int) -> Dictionary:
	var total := 0
	for s in shares:
		total += int(s["pts"])
	var g := goal(members)
	return {"goal": g, "total": total, "done": total >= g, "shares": shares}

## Board rows are untrusted. A row stays only if its doc is this clan's, it is from `week`, its member is in
## `members` and not seen before. Each count is clamped to its weekly cap and the points are worked out here
## (a stored score is never read). Best first, ties by id.
static func clean_rows(rows: Array, gid: String, week: int, members: Array) -> Array:
	var out: Array = []
	var seen := {}
	for r in rows:
		var d := Social.dict_of(Social.dict_of(r).get("data"))
		var id := Social.txt_of(Social.dict_of(r).get("id"))
		var who := id.trim_prefix(gid + "_")
		var mine: bool = Social.txt_of(d.get("guild")) == gid and id.begins_with(gid + "_")
		if not mine or Social.int_of(d.get("week")) != week or not members.has(who) or seen.has(who):
			continue
		seen[who] = true
		out.append(_share(who, d))
	out.sort_custom(func(a, b): return a["pts"] > b["pts"] or (a["pts"] == b["pts"] and a["id"] < b["id"]))
	return out

static func _share(who: String, d: Dictionary) -> Dictionary:
	var s := {"id": who, "pts": 0, "paid": d.get("paid") == true}
	for k in KINDS:
		s[k] = clampi(Social.int_of(d.get(k)), 0, int(rules()["cap"][k]))
		s["pts"] += s[k] * int(rules()["points"][k])
	return s

## At the goal, pays you reward_gems once this week: your row is marked paid first, the gems follow the
## write. cb gets the gems paid (0 if none).
static func claim(gid: String, b: Dictionary, cb := Callable()) -> void:
	var mine: Array = (b["shares"] as Array).filter(func(s): return s["id"] == Social.me)
	if not b["done"] or (not mine.is_empty() and mine[0]["paid"]) or _writing or Social.me == "":
		if cb.is_valid(): cb.call(0)
		return
	_writing = true
	_write_mine(gid, {}, true, func(okk: bool):
		_writing = false
		var gems := int(rules()["reward_gems"]) if okk else 0
		Save.d["gems"] = int(Save.d["gems"]) + gems
		if cb.is_valid(): cb.call(gems)
		_flush(gid))
