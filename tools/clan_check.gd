extends RefCounted
## --clan-check: clans, slices 1 and 2 (docs/specs/CLANS.md, docs/decisions/0022-clans.md), on a fake store.
##   1. clean_roster drops other clans' rows, unknown ranks and repeats, doubts a forged founder, clamps, caps at 24
##   2. founding a clan makes you its founder; joining makes you a member with a roster doc; both round-trip
##   3. only the founder can close the clan to newcomers; the flag reads back
##   4. leaving deletes the roster doc and clears the clan
##   5. an old save (v11, no clan) loads: in a guild it becomes a member of the clan, otherwise no clan
##   6. clean_clanbase: one showcase Boki per current member, a 13th is dropped, forged numbers are clamped
##   7. the weekly board (docs/decisions/0087-clan-board.md): clean_rows drops other clans', other weeks',
##      non-members' and repeated rows, clamps counts to the caps, ignores a stored score; your adds land in
##      your own row only (a last-week row starts over); the goal pays once; leaving deletes the row
##   8. the clan base opens headless from a fake store with 3 members: 3 corners, their Boki, the wall and
##      the board with the bar and the top three
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

func _board_rows() -> void:
	var wk := ClanBoard.week_now()
	var cap: Dictionary = ClanBoard.rules()["cap"]
	var pts: Dictionary = ClanBoard.rules()["points"]
	var rows := [
		_row("g1_a", {"guild": "g1", "week": wk, "extract": 2, "pts": 9999}),
		_row("g1_b", {"guild": "g1", "week": wk - 1, "cup": 3}),
		_row("g1_c", {"guild": "g2", "week": wk, "cup": 3}),
		_row("g2_d", {"guild": "g1", "week": wk, "cup": 3}),
		_row("g1_e", {"guild": "g1", "week": wk, "cup": 1e15, "final": -4, "extract": "lots"}),
		_row("g1_a", {"guild": "g1", "week": wk, "extract": 9}),
		_row("g1_x", {"guild": "g1", "week": wk, "cup": 1}),
	]
	var shares := ClanBoard.clean_rows(rows, "g1", wk, ["a", "b", "c", "d", "e"])
	var ids: Array = shares.map(func(s): return s["id"])
	ok(ids == ["e", "a"], "other clan, last week, wrong doc id, repeat and non-member rows are dropped (%s)" % [ids])
	var e: Dictionary = shares[0]
	ok(e["cup"] == cap["cup"] and e["final"] == 0 and e["extract"] == 0, "counts are clamped to the weekly caps")
	ok(shares[1]["pts"] == 2 * int(pts["extract"]), "points are worked out, a stored score is ignored")
	var b := ClanBoard.board(shares, 5)
	ok(b["goal"] == maxi(int(ClanBoard.rules()["goal_min"]), 5 * int(ClanBoard.rules()["goal_per_member"])),
		"the goal grows with the clan (%d)" % b["goal"])

	Save.d["guild_id"] = "g7"
	var mine := "clanboard/g7_alice"
	docs[mine] = {"guild": "g7", "week": wk - 1, "cup": 4, "paid": true}
	docs["clanboard/g7_bob"] = {"guild": "g7", "week": wk, "final": 3}
	ClanBoard.add("extract")
	ClanBoard.add("extract")
	ClanBoard.add("cup")
	ClanBoard.add("hats")
	var d: Dictionary = docs[mine]
	var fresh: bool = d["cup"] == 1 and d["extract"] == 2 and d["final"] == 0 and d["paid"] == false
	ok(fresh and d["week"] == wk, "adds go to your row; a last-week row starts over (%s)" % [d])
	ok(docs["clanboard/g7_bob"]["final"] == 3, "...and never touch another member's row")
	var got := []
	ClanBoard.read("g7", ["alice", "bob"], func(r): got.append(r))
	var total: int = 2 * int(pts["extract"]) + int(pts["cup"]) + 3 * int(pts["final"])
	ok(got.size() == 1 and got[0]["total"] == total and got[0]["shares"][0]["id"] == "bob", "the board reads back")
	var reached := ClanBoard.board(got[0]["shares"], 1)
	reached["done"] = true
	var gems := int(Save.d["gems"])
	var paid := []
	ClanBoard.claim("g7", reached, func(n): paid.append(n))
	ClanBoard.read("g7", ["alice", "bob"], func(r): ClanBoard.claim("g7", r, func(n): paid.append(n)))
	var reward := int(ClanBoard.rules()["reward_gems"])
	ok(paid == [reward, 0] and int(Save.d["gems"]) == gems + reward, "the goal pays once a week (%s)" % [paid])
	ok(docs[mine]["paid"] == true and docs[mine]["extract"] == 2, "...marked in your row, counts kept")
	ok(Evo.is_final("flarmink") and not Evo.is_final("ermink"), "a form with no next form is a final")
	Social.leave_guild(func(): pass)
	ok(not docs.has(mine) and docs.has("clanboard/g7_bob"), "leaving deletes only your board row")
	ClanBoard.add("cup")
	ok(not docs.has(mine), "outside a clan nothing is counted")

func _base(main: Node) -> void:
	var furn: String = Data.FURN.keys()[0]
	for who in ["ann", "ben", "cat"]:
		var roster := [_kin(who), _kin(who), _kin(who), _kin(who)]
		var decor := [{"id": furn, "x": 1e15}]
		docs["profiles/" + who] = {"name": who.capitalize(), "guild": "g5", "roster": roster, "decor": decor}
	docs["profiles/dan"] = {"name": "Dan", "guild": "g6", "roster": [_kin("dan")]}
	docs["clanroster/g5_ann"] = {"guild": "g5", "role": "founder", "corner_seed": 1e15}
	docs["clanbase/g5"] = {"showcase": [_kin("ben", 1e15), _kin("dan")]}
	var wk := ClanBoard.week_now()
	docs["clanboard/g5_ann"] = {"guild": "g5", "week": wk, "extract": 3}
	docs["clanboard/g5_ben"] = {"guild": "g5", "week": wk, "final": 1}
	docs["clanboard/g5_dan"] = {"guild": "g5", "week": wk, "final": 3}
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
	var board: Dictionary = home.get("visit")["clan_base"]["board"]
	var pts: Dictionary = ClanBoard.rules()["points"]
	var sum: int = 3 * int(pts["extract"]) + int(pts["final"])
	ok(board["total"] == sum and board["goal"] == ClanBoard.goal(3), "the board counts members only (%d)" % sum)
	var lines: Label3D = wall.get_node_or_null("ClanBoard/Top")
	var top: String = lines.text if lines != null else ""
	ok(top.begins_with("1. Ann") and top.contains("2. Ben") and not top.contains("Dan"), "the top three: %s" % [top])
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
	_board_rows()
	Save.d = Save.fresh()
	await _base(main)
	print("CLAN DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
