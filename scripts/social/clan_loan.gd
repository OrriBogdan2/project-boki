class_name ClanLoan
extends RefCounted
## Breeding loans (docs/specs/CLANS.md section 7): a Boki spends a garden day in a clanmate's Nook. For the
## lender it is a Sleepover whose entry carries "clan" (it never leaves the save and comes home on the lender's
## clock). The store holds only the lender's one offer (clanloan/<gid>_<lender>) and the one offer the host
## took in (clanguest/<gid>_<host>); each is written by its owner and cleaned on read. Their times are in s
## (Social.num_of clamps at 1e12, below a ms clock).

const OFFERS := "clanloan"
const GUESTS := "clanguest"
const SKEW_SECS := 300.0     # s an offer may be stamped ahead of our clock (two machines' clocks differ)

## My Boki out on a clan loan ({} when none is).
static func away() -> Dictionary:
	for stay in Sleepover.list():
		if stay.has("clan"):
			return stay
	return {}

## Why rec cannot be lent ("" if it can).
static func why_not(rec: Dictionary) -> String:
	if Social.my_guild_id() == "":
		return "Join a clan to lend a Boki."
	if not away().is_empty():
		return "One of your Boki is already on loan."
	return Sleepover.why_not(rec)

## Lends rec to clanmate `to` for a garden day from now (s): it goes away as a sleepover and the offer goes up.
static func offer(rec: Dictionary, to: String, to_name: String, now: float) -> bool:
	var gid := Social.my_guild_id()
	if why_not(rec) != "" or to == Social.me:
		return false
	var kin := Social.snap_kin(rec)
	if not Sleepover.send(rec, to, to_name, now):
		return false
	Sleepover.list()[-1]["clan"] = gid
	Social.set_doc("%s/%s_%s" % [OFFERS, gid, Social.me], {"guild": gid, "to": to,
		"from_name": Social.say_of(Save.d.get("name"), "Hunter"), "kin": kin, "t": now})
	return true

## An offer row from the store, cleaned: {from, from_name, kin, t} (t in s), or {} unless it is in my clan,
## to me, from another current member (members: ids) and less than a day old at now (s).
static func clean_offer(row: Dictionary, gid: String, me: String, members: Array, now: float) -> Dictionary:
	var id := Social.txt_of(row.get("id"))
	var d := Social.dict_of(row.get("data"))
	var from := id.trim_prefix(gid + "_")
	var t := Social.num_of(d.get("t"))
	var kin := Social.clean_snap_kin(d.get("kin"))
	var mine := id.begins_with(gid + "_") and Social.txt_of(d.get("guild")) == gid and Social.txt_of(d.get("to")) == me
	if not mine or from == me or not members.has(from) or kin.is_empty() or String(kin["uid"]) == "":
		return {}
	if t > now + SKEW_SECS or now - t >= Sleepover.DAY_SECS:
		return {}
	return {"from": from, "from_name": Social.say_of(d.get("from_name"), "A clanmate"), "kin": kin, "t": t}

## Whether a clanguest doc took in this loan: same lender and Boki, stamped inside the loan's day (t0 in s).
static func took(guest: Dictionary, from: String, uid: String, t0: float) -> bool:
	var t := Social.num_of(guest.get("t"))
	return Social.txt_of(guest.get("from")) == from and Social.txt_of(guest.get("uid")) == uid \
		and t >= t0 - SKEW_SECS and t < t0 + Sleepover.DAY_SECS

## cb gets {guest, offers}: the loan I took in ({} if none) and the offers still open to me.
static func for_me(cb: Callable) -> void:
	var gid := Social.my_guild_id()
	if gid == "":
		cb.call({"guest": {}, "offers": []})
		return
	Social.guild_members(gid, func(members: Array):
		var ids: Array = members.map(func(m): return m["id"])
		Social.query(OFFERS, [["to", "==", Social.me]], "", "asc", Social.CLAN_CAP, func(rows: Array):
			Social.get_doc("%s/%s_%s" % [GUESTS, gid, Social.me], func(g: Dictionary):
				var now := Time.get_unix_time_from_system()
				var out := {"guest": {}, "offers": []}
				for r in rows:
					var o := clean_offer(r, gid, Social.me, ids, now)
					if o.is_empty():
						continue
					if took(g, o["from"], o["kin"]["uid"], o["t"]):
						out["guest"] = o
					else:
						out["offers"].append(o)
				cb.call(out))))

## Takes an offer in: it shows in my Nook until its day is over. cb gets whether the store took the write.
static func accept(o: Dictionary, cb: Callable) -> void:
	var gid := Social.my_guild_id()
	Social.set_doc("%s/%s_%s" % [GUESTS, gid, Social.me], {"guild": gid, "from": o["from"], "uid": o["kin"]["uid"],
		"t": Time.get_unix_time_from_system()}, cb)

## Brings a lent Boki home (Sleepover calls this when its day is up). cb gets the memory line.
static func come_home(stay: Dictionary, cb: Callable) -> void:
	var gid := String(stay["clan"])
	var rec: Dictionary = stay["rec"]
	Social.get_doc("%s/%s_%s" % [GUESTS, gid, stay["to"]], func(g: Dictionary):
		var stayed := took(g, Social.me, String(rec["uid"]), float(stay["t"]))
		var said := "%s spent a garden day in %s's Nook." if stayed else "%s waited a day for %s, then came home."
		var opening := said % [rec["name"], stay["name"]]
		Social.del_doc("%s/%s_%s" % [OFFERS, gid, Social.me])
		cb.call(Sleepover.come_home(stay, {}, opening)["line"]))
