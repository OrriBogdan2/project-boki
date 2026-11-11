class_name ClanLeague
## The clan league and the clan egg (docs/specs/CLANS.md section 5 job 3, docs/decisions/0022-clans.md).
## Each member writes only their own score doc for the season, clanleague/<gid>_<season>_<me>
## {guild, season, pts, day, day_pts}, so nobody overwrites anybody (the store has no transactions; contrib
## works the same way). The table sums the docs of current roster members only. The clan egg fills from the
## same points; once it is full, each member takes one egg a season into their own save (Save.d["clan_egg"]
## holds the season they last took it, so hopping clans can't take a second).

const SEASON_DAYS := 7               # days in a season; a season starts on Monday, 00:00 UTC
const DAY_CAP := 200                 # league points one member can score in one day
const SEASON_CAP := DAY_CAP * SEASON_DAYS   # the most one member's doc is believed for
const SCORES := {"extract": 10}      # league points per event (an expedition you made it out of)
const EGG_GOAL := 300                # clan points in a season that fill the clan egg
const READ_LIMIT := 60               # score docs read per table (more than CLAN_CAP: strays are dropped)

static func day_of(unix: float) -> int:
	return floori(unix / 86400.0)

## "w<n>": weeks since Monday 1969-12-29 (1970-01-01, day 0, was a Thursday).
static func season_key(unix: float) -> String:
	return "w%d" % floori((day_of(unix) + 3) / float(SEASON_DAYS))

static func season_now() -> String:
	return season_key(Time.get_unix_time_from_system())

## Adds points for something I did, up to DAY_CAP a day. Nothing happens outside a clan or without the store.
static func score(kind: String, n := 1) -> void:
	var gid := Social.my_guild_id()
	if not Social.available() or gid == "" or not SCORES.has(kind) or n <= 0:
		return
	var now := Time.get_unix_time_from_system()
	var season := season_key(now)
	var today := day_of(now)
	var path := "clanleague/%s_%s_%s" % [gid, season, Social.me]
	Social.get_doc(path, func(d: Dictionary):
		var mine: bool = Social.txt_of(d.get("guild")) == gid and Social.txt_of(d.get("season")) == season
		var pts := clampi(Social.int_of(d.get("pts")), 0, SEASON_CAP) if mine else 0
		var same_day: bool = mine and Social.int_of(d.get("day")) == today
		var used := clampi(Social.int_of(d.get("day_pts")), 0, DAY_CAP) if same_day else 0
		var add := mini(n * int(SCORES[kind]), DAY_CAP - used)
		if add > 0:
			var row := {"guild": gid, "season": season, "pts": pts + add, "day": today, "day_pts": used + add}
			Social.set_doc(path, row))

## cb gets {table: [{id, pts}] best first, total} for this season: current roster members only.
static func load_table(gid: String, founder: String, cb: Callable) -> void:
	var season := season_now()
	Social.clan_roster(gid, founder, func(roster: Array):
		var members: Array = roster.map(func(r): return r["id"])
		var where := [["guild", "==", gid], ["season", "==", season]]
		Social.query("clanleague", where, "", "asc", READ_LIMIT, func(rows: Array):
			cb.call(clean_table(rows, gid, season, members))))

## Score docs are untrusted: a row counts only if its id is a current member's doc for this clan and season,
## once per member, its points clamped to what a season allows.
static func clean_table(rows: Array, gid: String, season: String, members: Array) -> Dictionary:
	var table: Array = []
	var seen := {}
	var total := 0
	for r in rows:
		var who := Social.txt_of(Social.dict_of(r).get("id")).trim_prefix("%s_%s_" % [gid, season])
		var d := Social.dict_of(Social.dict_of(r).get("data"))
		var mine: bool = Social.txt_of(d.get("guild")) == gid and Social.txt_of(d.get("season")) == season
		if not mine or not members.has(who) or seen.has(who):
			continue
		seen[who] = true
		var pts := clampi(Social.int_of(d.get("pts")), 0, SEASON_CAP)
		table.append({"id": who, "pts": pts})
		total += pts
	table.sort_custom(func(a, b): return a["pts"] > b["pts"] or (a["pts"] == b["pts"] and a["id"] < b["id"]))
	return {"table": table, "total": total}

## The species a clan's egg hatches this season: the same for every member.
static func egg_species(gid: String, season: String) -> String:
	var sp: Array = Data.common_kin()
	return String(sp[posmod((gid + season).hash(), sp.size())])

static func can_claim(total: int) -> bool:
	return total >= EGG_GOAL and Social.my_guild_id() != "" and String(Save.d.get("clan_egg", "")) != season_now()

## Takes this season's clan egg into my Incubator (once a season). Returns its species, or "" if not now.
static func claim_egg(total: int) -> String:
	if not can_claim(total):
		return ""
	var season := season_now()
	var sp := egg_species(Social.my_guild_id(), season)
	Save.d["clan_egg"] = season
	Incubator.add(sp)
	Save.save_game()
	return sp
