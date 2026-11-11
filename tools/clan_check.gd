extends RefCounted
## --clan-check: clans, slices 1 and 2 (docs/specs/CLANS.md, docs/decisions/0022-clans.md), on a fake store.
##   1. clean_roster drops other clans' rows, unknown ranks and repeats, doubts a forged founder, clamps, caps at 24
##   2. founding a clan makes you its founder; joining makes you a member with a roster doc; both round-trip
##   3. only the founder can close the clan to newcomers; the flag reads back
##   4. leaving deletes the roster doc and clears the clan
##   5. an old save (v11, no clan) loads: in a guild it becomes a member of the clan, otherwise no clan
##   6. clean_clanbase: one showcase Boki per current member, a 13th is dropped, forged numbers are clamped
##   7. ranks (slice 3): only the founder makes officers and members and hands the founder role to an officer
##      (who takes the guild doc's founder field; the old founder becomes an officer); founder and officers remove
##      only those below them; a removed member's game leaves on refresh and can't rejoin; forged ranks, forged
##      removals and a forged officers list change nothing
##   8. the clan base opens headless from a fake store with 3 members: 3 corners, their Boki, the wall
##      (read the log for errors; two predate clans: the startup OptionButton theme line and the farm's
##      exit leak of HomeBuild/HomeMarket/HomeTrade)

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
	var out := Social.clean_roster(rows, "g1", Social.clean_guild({"founder": "f"}))
	var ids: Array = out.map(func(r): return r["id"])
	ok(ids == ["a", "e", "f"], "bad rank, other clan, wrong doc id, repeat and non-text rank are dropped (%s)" % [ids])
	var roles: Array = out.map(func(r): return r["role"])
	ok(roles == ["member", "member", "founder"], "a founder claim only holds for the guild doc's founder")
	ok(out[1]["corner_seed"] == 999999 and out[1]["joined"] == 0.0, "numbers are clamped")
	var many := []
	for i in 40:
		many.append(_row("g1_m%d" % i, {"guild": "g1", "role": "member"}))
	ok(Social.clean_roster(many, "g1", {}).size() == Social.CLAN_CAP, "at most %d members show" % Social.CLAN_CAP)

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
	Social.clan_roster("g1", Social.clean_guild(docs["guilds/g1"]), func(r, _gone):
		got.append_array(r.map(func(x): return x["id"])))
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

## Runs one Social call as `who` and returns what its cb got.
func _as(who: String, act: Callable) -> bool:
	Social.me = who
	var res := []
	act.call(func(okk: bool): res.append(okk))
	Social.me = "alice"
	return res == [true]

## cb-free reads of clan g7 as the store has it now.
func _roll() -> Dictionary:
	var out := {}
	Social.clan_roster("g7", Social.clean_guild(docs["guilds/g7"]), func(r: Array, _gone):
		for x in r: out[x["id"]] = x["role"])
	return out

func _ranks(main: Node) -> void:
	docs["guilds/g7"] = {"name": "Ranks", "founder": "alice", "built": []}
	for who in ["alice", "bob", "carl", "dina"]:
		docs["clanroster/g7_" + who] = {"guild": "g7", "role": "member"}
	docs["clanroster/g7_carl"]["role"] = "officer"
	ok(_roll() == {"alice": "founder", "bob": "member", "carl": "member", "dina": "member"},
		"a member's own row claiming officer still reads as member")
	ok(not _as("carl", func(cb): Social.set_officer("g7", "carl", true, cb)), "a member can't make himself officer")
	ok(_as("alice", func(cb): Social.set_officer("g7", "bob", true, cb)) and _roll()["bob"] == "officer",
		"the founder makes an officer")
	ok(not _as("bob", func(cb): Social.set_officer("g7", "dina", true, cb)), "an officer can't make officers")
	var forged := Social.clean_guild({"founder": "alice", "officers": ["alice", "bob", "bob", 7, ""]})
	ok(forged["officers"] == ["bob"], "a guild doc's officer list drops the founder, repeats and junk")
	# removing
	ok(not _as("dina", func(cb): Social.remove_member("g7", "carl", cb)), "a member can't remove a member")
	docs["clanout/g7_dina"] = {"guild": "g7", "ids": ["carl", "alice"]}
	docs["clanout/g7_bob"] = {"guild": "g7", "ids": ["alice"]}
	ok(_roll().size() == 4, "forged removals (a member's list, an officer listing the founder) remove nobody")
	docs.erase("clanout/g7_dina")
	docs.erase("clanout/g7_bob")
	ok(not _as("bob", func(cb): Social.remove_member("g7", "alice", cb)), "an officer can't remove the founder")
	ok(_as("bob", func(cb): Social.remove_member("g7", "carl", cb)) and not _roll().has("carl"),
		"an officer removes a member: off the roll")
	# carl's own game: leaves on refresh, can't rejoin
	Save.d["guild_id"] = "g7"
	Save.d["clan"] = Social.clan_for("g7", "carl", "member", 0.0)
	Social.me = "carl"
	Social.refresh_guild()
	await main.get_tree().process_frame
	ok(Save.d["guild_id"] == "" and Save.d["clan"] == {} and not docs.has("clanroster/g7_carl"),
		"the removed member's game leaves the clan and deletes its row")
	var rejoined := []
	Social.join_guild("g7", func(okk): rejoined.append(okk))
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	ok(rejoined == [false] and Save.d["guild_id"] == "", "...and can't join it again")
	Social.me = "alice"
	ok(_as("alice", func(cb): Social.set_officer("g7", "dina", true, cb)) and
		not _as("bob", func(cb): Social.remove_member("g7", "dina", cb)), "an officer can't remove another officer")
	ok(_as("alice", func(cb): Social.set_officer("g7", "dina", false, cb)) and _roll()["dina"] == "member",
		"the founder makes an officer a member again")
	# handing over
	ok(not _as("alice", func(cb): Social.hand_founder("g7", "dina", cb)), "the founder role goes only to an officer")
	ok(not _as("bob", func(cb): Social.hand_founder("g7", "bob", cb)), "an officer can't take it")
	ok(_as("alice", func(cb): Social.hand_founder("g7", "bob", cb)), "the founder hands it to an officer")
	var g := Social.clean_guild(docs["guilds/g7"])
	ok(g["founder"] == "bob" and g["officers"] == ["alice"] and _roll()["alice"] == "officer",
		"the guild doc's founder moves; the old founder is an officer")
	ok(not _as("alice", func(cb): Social.set_officer("g7", "dina", true, cb)), "the old founder can't make officers")
	ok(_as("alice", func(cb): Social.remove_member("g7", "dina", cb)) and not _roll().has("dina"),
		"the old founder, now an officer, removes a member")
	ok(_as("bob", func(cb): Social.remove_member("g7", "alice", cb)) and _roll().keys() == ["bob", "dina"],
		"the founder removes an officer, whose removals then stop holding")
	Save.d = Save.fresh()

func _write(d: Dictionary) -> void:
	var f := FileAccess.open(OLD_SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()

func _kin(who: String, level = 3) -> Dictionary:
	return {"owner": who, "uid": "u" + who, "species": Data.KIN.keys()[0], "name": who + "'s", "level": level}

func _showcase() -> void:
	var ids: Array = []
	var wall: Array = []
	for i in 13:
		ids.append("m%d" % i)
		wall.append(_kin("m%d" % i))
	wall.push_front(_kin("stranger"))
	wall.push_front(_kin("m0", 1e15))
	wall[0]["trust"] = 1e9
	wall.push_front({"owner": "m1", "species": "not_a_boki"})
	var out: Array = Social.clean_clanbase({"showcase": wall}, ids)["showcase"]
	var owners: Array = out.map(func(r): return r["owner"])
	ok(out.size() == Social.SHOWCASE_CAP and not owners.has("m12"), "a 13th showcase Boki is dropped")
	ok(not owners.has("stranger") and owners.count("m0") == 1, "only members, one Boki each")
	ok(out[0]["level"] == 999 and out[0]["trust"] == 100.0, "forged huge numbers are clamped")
	ok(Social.clean_clanbase({"showcase": "lots"}, ids)["showcase"] == [], "a broken doc reads as an empty wall")

func _base(main: Node) -> void:
	var furn: String = Data.FURN.keys()[0]
	for who in ["ann", "ben", "cat"]:
		var roster := [_kin(who), _kin(who), _kin(who), _kin(who)]
		var decor := [{"id": furn, "x": 1e15}]
		docs["profiles/" + who] = {"name": who.capitalize(), "guild": "g5", "roster": roster, "decor": decor}
	docs["profiles/dan"] = {"name": "Dan", "guild": "g6", "roster": [_kin("dan")]}
	docs["clanroster/g5_ann"] = {"guild": "g5", "role": "founder", "corner_seed": 1e15}
	docs["clanbase/g5"] = {"showcase": [_kin("ben", 1e15), _kin("dan")]}
	var gdoc := Social.clean_guild({"name": "Reed Bank", "founder": "ann"})
	ClanBase.open("g5", gdoc)
	var tree := main.get_tree()
	var root: Node = null
	for i in 600:
		await tree.process_frame
		var home: Node = main.get("current")
		root = home.get_node_or_null("ClanBase") if home != null else null
		if root != null:
			break
	ok(root != null, "the clan base opens")
	if root == null:
		return
	var home: Node = main.get("current")
	var corners := root.get_children().filter(func(n): return n.name.begins_with("Corner_"))
	ok(corners.size() == 3, "3 members give 3 corners (%d)" % corners.size())
	var owners := {}
	for kd in home.get("kins"):
		owners[kd["rec"].get("owner")] = owners.get(kd["rec"].get("owner"), 0) + 1
	ok(owners == {"ann": 3, "ben": 3, "cat": 3}, "each corner brings 3 of its member's Boki (%s)" % [owners])
	var wall: Node = root.get_node("ShowcaseWall")
	var shown: Array = home.get("visit")["clan_base"]["showcase"]
	ok(shown.size() == 1 and shown[0]["level"] == 999 and wall != null, "the wall shows members only, clamped")
	Game.goto("title")      # leave the farm before quitting, so it frees cleanly
	for i in 30:
		await tree.process_frame

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
	_showcase()
	await _ranks(main)
	Save.d = Save.fresh()
	await _base(main)
	print("CLAN DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
