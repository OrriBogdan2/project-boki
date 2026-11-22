class_name ClanChat
extends RefCounted
## The clan channel: short lines only your clanmates see, kept in the social store like the notice board
## (clanchat/<id> = {guild, tag, by, name, text, t}), no other transport. Offline there is no store: a line
## you send is echoed to you alone and not kept. Everything read back is cleaned by clean_rows; a muted name
## (MuteList) is dropped for you only.

const SHOWN := 12  # lines the channel shows (the newest)
const FETCH := 60  # rows asked of the store per read
const KEEP_MINE := 40  # my own lines kept in the store (older ones are deleted)
const RATE_MS := 3000.0  # ms between one member's lines: closer ones are refused on send, dropped on read

static var _echo: Array = []  # my lines sent while offline, as store rows, oldest first
static var _last_sent := -1e18  # ms time of my last line
static var _sending := false  # one write at a time


## A line someone typed or stored: one line, trimmed, at most Prematch.CHAT_MAX characters.
static func clean_text(v) -> String:
	return Prematch.clean_chat(Social.say_of(v, "", Prematch.CHAT_MAX))


## The lines to show, oldest first, as {id, who, tag, name, text, t}. A row stays only if it is this clan's, its
## author is one of `members` (ids), it has text, it was not seen before, its author is not muted, and it
## is at least RATE_MS after that author's last kept line. The tag shown is always the clan's own.
static func clean_rows(rows: Array, gid: String, members: Array, tag: String) -> Array:
	var kept: Array = []
	for r in rows:
		var row := Social.dict_of(r)
		var d := Social.dict_of(row.get("data"))
		var who := Social.txt_of(d.get("by"))
		var text := clean_text(d.get("text"))
		var name := Social.say_of(d.get("name"))
		if Social.txt_of(d.get("guild")) != gid or not members.has(who) or text == "" or MuteList.has(name):
			continue
		kept.append(
			{
				"id": Social.txt_of(row.get("id")),
				"who": who,
				"tag": tag,
				"name": name,
				"text": text,
				"t": Social.num_of(d.get("t"))
			}
		)
	kept.sort_custom(func(a, b): return a["t"] < b["t"] or (a["t"] == b["t"] and a["id"] < b["id"]))
	var out: Array = []
	var last := {}
	var seen := {}
	for k in kept:
		if seen.has(k["id"]) or float(k["t"]) - float(last.get(k["who"], -1e18)) < RATE_MS:
			continue
		seen[k["id"]] = true
		last[k["who"]] = k["t"]
		out.append(k)
	return out.slice(maxi(0, out.size() - SHOWN))


## Sends a line to my clan. cb gets true if it went (echoed to me alone when offline), false if I am in no
## clan, the line is empty, a send is in flight, or my last line was under RATE_MS ago. `now` is in ms.
static func send(text: String, cb: Callable, now := -1.0) -> void:
	var gid := Social.my_guild_id()
	var t := clean_text(text)
	var at := Social.now_ms() if now < 0.0 else now
	if gid == "" or t == "" or _sending or at - _last_sent < RATE_MS:
		cb.call(false)
		return
	_last_sent = at
	var line := {
		"guild": gid,
		"tag": ClanInfo.my_tag(),
		"by": Social.me,
		"name": Social.say_of(Save.d.get("name"), "Hunter"),
		"text": t,
		"t": at
	}
	if not Social.ok:
		_echo.append({"id": "echo%d" % _echo.size(), "data": line})
		cb.call(true)
		return
	_sending = true
	Social.add_doc(
		"clanchat",
		line,
		func(id: String):
			_sending = false
			cb.call(id != "")
			if id != "":
				_prune_mine(gid)
	)


## cb gets the lines to show (clean_rows). members: the clan's member ids. Offline: only my own echoed lines.
static func read(gid: String, members: Array, cb: Callable) -> void:
	var tag := ClanInfo.my_tag()
	if not Social.ok:
		cb.call(clean_rows(_echo, gid, [Social.me], tag))
		return
	Social.query(
		"clanchat",
		[["guild", "==", gid]],
		"t",
		"desc",
		FETCH,
		func(rows: Array): cb.call(clean_rows(rows, gid, members, tag))
	)


## Deletes my lines past the newest KEEP_MINE, so the store stays small.
static func _prune_mine(gid: String) -> void:
	Social.query(
		"clanchat",
		[["guild", "==", gid]],
		"t",
		"desc",
		FETCH,
		func(rows: Array):
			var mine: Array = rows.filter(
				func(r): return Social.txt_of(Social.dict_of(r["data"]).get("by")) == Social.me
			)
			for i in range(KEEP_MINE, mine.size()):
				Social.del_doc("clanchat/" + String(mine[i]["id"]))
	)
