extends "res://tools/clan_check.gd"
## --clan-roles-check: clan ranks (docs/specs/CLANS.md 2, docs/decisions/0022-clans.md), on clan_check's fake store.
##   1. only the founder makes officers and members and hands the founder role to an officer (who takes the guild
##      doc's founder field; the old founder becomes an officer); forged ranks and officer lists change nothing
##   2. founder and officers remove only those below them; forged removals remove nobody; the removed member's
##      game drops the clan on its next refresh, shows one line (Social.clan_removed -> Overlay) and can't rejoin
##   3. a founder who leaves hands the clan to the longest-serving officer, else the longest-serving member
##      (a removed member never); a member leaving leaves the guild doc alone; the last one out leaves it idle

var notes: Array = []      # clan names Social.clan_removed reported

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
	await main.get_tree().process_frame
	ok(Save.d["guild_id"] == "" and Save.d["clan"] == {} and not docs.has("clanroster/g7_carl"),
		"the removed member's game leaves the clan and deletes its row")
	ok(notes == ["Ranks"] and UI.toast_busy(Overlay.root), "...and shows one line naming the clan (%s)" % [notes])
	var rejoined := []
	Social.join_guild("g7", func(okk): rejoined.append(okk))
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	ok(rejoined == [false] and Save.d["guild_id"] == "", "...and can't join it again")
	ok(notes == ["Ranks", "Ranks"], "the refused join says why in the same line")
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

## Founder fred leaves clan `gid`, whose roll is `rows` {id: [rank, joined]}; returns the guild doc after.
func _founder_leaves(main: Node, gid: String, rows: Dictionary, out := []) -> Dictionary:
	var officers: Array = rows.keys().filter(func(k): return rows[k][0] == "officer")
	docs["guilds/" + gid] = {"name": "Heirs", "founder": "fred", "officers": officers, "built": []}
	docs["clanroster/%s_fred" % gid] = {"guild": gid, "role": "founder", "joined": 1.0}
	for who in rows:
		docs["clanroster/%s_%s" % [gid, who]] = {"guild": gid, "role": rows[who][0], "joined": rows[who][1]}
	if not out.is_empty():
		docs["clanout/%s_fred" % gid] = {"guild": gid, "ids": out}
	Save.d["guild_id"] = gid
	Save.d["clan"] = Social.clan_for(gid, "fred", "founder", 1.0)
	Social.me = "fred"
	var done := []
	Social.leave_guild(func(): done.append(true))
	for i in 3:
		await main.get_tree().process_frame
	Social.me = "alice"
	ok(done == [true] and Save.d["guild_id"] == "" and not docs.has("clanroster/%s_fred" % gid),
		"%s: the founder's game leaves and deletes its row" % gid)
	return Social.clean_guild(docs.get("guilds/" + gid, {}))

func _hand_off(main: Node) -> void:
	var g: Dictionary = await _founder_leaves(main, "h1",
		{"mia": ["member", 100.0], "olga": ["officer", 300.0], "oscar": ["officer", 200.0]})
	ok(g["founder"] == "oscar" and g["officers"] == ["olga"],
		"the longest-serving officer takes over, not the older member (%s, %s)" % [g["founder"], g["officers"]])
	g = await _founder_leaves(main, "h2", {"mia": ["member", 100.0], "max": ["member", 50.0],
		"nina": ["member", 150.0]}, ["max"])
	ok(g["founder"] == "mia" and g["officers"] == [], "no officer: the longest-serving member, never a removed one")
	g = await _founder_leaves(main, "h3", {})
	ok(docs.has("guilds/h3") and g["founder"] == "fred", "the last one out leaves the guild doc idle")
	docs["guilds/h4"] = {"name": "Stay", "founder": "fred", "officers": ["olga"], "built": []}
	var before: Dictionary = docs["guilds/h4"].duplicate(true)
	for who in ["fred", "olga", "mia"]:
		docs["clanroster/h4_" + who] = {"guild": "h4", "role": "member", "joined": 5.0}
	Save.d["guild_id"] = "h4"
	Social.me = "olga"
	Social.leave_guild(func(): pass)
	for i in 3:
		await main.get_tree().process_frame
	Social.me = "alice"
	ok(docs["guilds/h4"] == before and not docs.has("clanroster/h4_olga"), "an officer leaving changes no ranks")
	var tie := [{"id": "zed", "role": "member", "joined": 9.0}, {"id": "amy", "role": "member", "joined": 9.0}]
	ok(Social.successor_of(tie, "fred") == "amy" and Social.successor_of([], "fred") == "", "ties go to the lower id")

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Social.store_stub = _store
	Social.ok = true
	Social.me = "alice"
	Social.clan_removed.connect(func(n: String): notes.append(n))
	await _ranks(main)
	await _hand_off(main)
	Save.d = Save.fresh()
	print("CLAN-ROLES DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
