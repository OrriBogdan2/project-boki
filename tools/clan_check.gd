extends RefCounted
## --clan-check: clans, slice 1 (docs/specs/CLANS.md, docs/decisions/0022-clans.md), on a fake store.
##   1. clean_roster drops other clans' rows, unknown ranks and repeats, doubts a forged founder, clamps, caps at 24
##   2. founding a clan makes you its founder; joining makes you a member with a roster doc; both round-trip
##   3. only the founder can close the clan to newcomers; the flag reads back
##   4. leaving deletes the roster doc and clears the clan
##   5. an old save (v11, no clan) loads: in a guild it becomes a member of the clan, otherwise no clan

const OLD_SAVE := "user://clan_check_old.json"
var docs := {}
var bad := 0

func ok(cond: bool, what: String) -> void:
	print("CLAN %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## An in-memory page store: answers the calls Social makes without a browser.
func _store(method: String, args: Array, cb: Callable) -> void:
	match method:
		"dbGet": cb.call(JSON.stringify(docs[args[0]]) if docs.has(args[0]) else "")
		"dbSet":
			docs[args[0]] = JSON.parse_string(args[1])
			cb.call("ok")
		"dbDel":
			docs.erase(args[0])
			cb.call("ok")
		"dbQuery":
			var q: Dictionary = JSON.parse_string(args[1])
			var rows := []
			for path in docs:
				if not String(path).begins_with(args[0] + "/"):
					continue
				var hit := true
				for w in q["where"]:
					hit = hit and docs[path].get(w[0]) == w[2]
				if hit:
					rows.append({"id": String(path).substr(String(args[0]).length() + 1), "data": docs[path]})
			cb.call(JSON.stringify(rows.slice(0, int(q["limit"]))))
		_: cb.call("")

func _row(id: String, d: Dictionary) -> Dictionary:
	return {"id": id, "data": d}

func _cleaning() -> void:
	var rows := [
		_row("g1_a", {"guild": "g1", "role": "member", "joined": 5, "corner_seed": 7}),
		_row("g1_b", {"guild": "g1", "role": "emperor"}),
		_row("g1_c", {"guild": "g2", "role": "member"}),
		_row("g2_d", {"guild": "g1", "role": "member"}),
		_row("g1_e", {"guild": "g1", "role": "founder", "corner_seed": 1e15, "joined": -9}),
		_row("g1_f", {"guild": "g1", "role": "founder"}),
		_row("g1_a", {"guild": "g1", "role": "officer"}),
		_row("g1_g", {"guild": "g1", "role": 4}),
	]
	var out := Social.clean_roster(rows, "g1", "f")
	var ids: Array = out.map(func(r): return r["id"])
	ok(ids == ["a", "e", "f"], "bad rank, other clan, wrong doc id, repeat and non-text rank are dropped (%s)" % [ids])
	var roles: Array = out.map(func(r): return r["role"])
	ok(roles == ["member", "member", "founder"], "a founder claim only holds for the guild doc's founder")
	ok(out[1]["corner_seed"] == 999999 and out[1]["joined"] == 0.0, "numbers are clamped")
	var many := []
	for i in 40:
		many.append(_row("g1_m%d" % i, {"guild": "g1", "role": "member"}))
	ok(Social.clean_roster(many, "g1", "").size() == Social.CLAN_CAP, "at most %d members show" % Social.CLAN_CAP)

func _joining() -> void:
	docs["guilds/g1"] = {"name": "Old Pond", "founder": "bob", "built": []}
	Social.join_guild("g1", func(_okk): pass)
	var clan: Dictionary = Save.d["clan"]
	ok(Save.d["guild_id"] == "g1" and clan["id"] == "g1" and clan["role"] == "member", "joining makes a member clan")
	var seed_now: int = Social.clan_for("g1", "alice", "member", 0.0)["corner_seed"]
	ok(clan["corner_seed"] == seed_now, "the corner seed comes from you and the clan")
	var mine: Dictionary = docs.get("clanroster/g1_alice", {})
	ok(mine.get("role") == "member" and mine.get("guild") == "g1", "a roster doc is written on join")
	docs["clanroster/g1_bob"] = {"guild": "g1", "role": "founder"}
	var got := []
	Social.clan_roster("g1", "bob", func(r): got.append_array(r.map(func(x): return x["id"])))
	ok(got == ["alice", "bob"], "the roster reads back both members")
	ok(not Social.busy("guild"), "the join finished")

func _founding() -> void:
	Social.create_guild("Pond Two", "", func(_okk): pass)
	var gid: String = Save.d["guild_id"]
	ok(Save.d["clan"]["id"] == gid and Save.d["clan"]["role"] == "founder", "founding a clan makes you its founder")
	var mine: String = docs["clanroster/%s_alice" % gid]["role"]
	ok(mine == "founder" and docs["clanroster/g1_alice"]["role"] == "member", "...in the roster, and only there")
	ok(Social.guild.get("open") == true, "a new clan is open")
	var res := []
	Social.set_open(gid, false, func(r): res.append(r))
	ok(res == [true] and Social.clean_guild(docs["guilds/" + gid])["open"] == false, "the founder closes it")
	Social.me = "carol"
	Social.set_open(gid, true, func(r): res.append(r))
	Social.me = "alice"
	ok(res == [true, false] and docs["guilds/" + gid]["open"] == false, "someone else can't reopen it")
	ok(Social.clean_guild({"name": "x"})["open"] == true, "a guild doc with no flag is open")

func _leaving() -> void:
	var gid: String = Save.d["guild_id"]
	Social.leave_guild(func(): pass)
	var gone := not docs.has("clanroster/%s_alice" % gid)
	ok(gone and docs.has("clanroster/g1_alice"), "leaving deletes only that clan's roster doc")
	ok(Save.d["guild_id"] == "" and Save.d["clan"].is_empty(), "...and clears the clan")

func _old_saves() -> void:
	var old := Save.fresh()
	old.erase("clan")
	old["v"] = 11
	old["guild_id"] = "g9"
	_write(old)
	Save.load_from(OLD_SAVE)
	var clan: Dictionary = Save.d["clan"]
	var joined: bool = clan["id"] == "g9" and clan["role"] == "member"
	ok(int(Save.d["v"]) == Save.VERSION and joined, "an old guild save joins its clan")
	old["guild_id"] = ""
	_write(old)
	Save.load_from(OLD_SAVE)
	ok(Save.d["clan"] == {} and Save.d["gems"] == old["gems"], "an old save in no guild gets no clan")
	old.erase("guild_id")
	_write(old)
	Save.load_from(OLD_SAVE)
	ok(Save.d["clan"] == {}, "one from before guilds loads too")
	ok(Save.fresh()["clan"] == {}, "a new save starts with no clan")
	DirAccess.remove_absolute(OLD_SAVE)

func _write(d: Dictionary) -> void:
	var f := FileAccess.open(OLD_SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Social.store_stub = _store
	Social.ok = true
	Social.me = "alice"
	_cleaning()
	_joining()
	_founding()
	_leaving()
	_old_saves()
	print("CLAN DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
