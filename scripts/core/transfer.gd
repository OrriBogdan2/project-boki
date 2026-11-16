class_name Transfer
## Handing a Boki straight to another player (docs/decisions/0013-market.md): the only way to trade
## one. A flat fee (destroyed, a sink), one transfer a week per sender, and both sides confirm: you
## send (with a confirm step in the UI), the other player accepts. Nobody is paid for a Boki.
##
## The record travels as a packet {id, from, from_name, to, kin (Social.clean_kin), t}; the receiver
## builds its own Boki from it (accept). With the server (docs/EXCHANGE_SERVER.md) the backend
## carries packets; offline there is nobody to accept, so a sent Boki waits in your outbox and can
## be called back (the fee and the week's transfer come back with it).
## Outbox entries: {id, rec, to, fee, t}; "sent" keeps the times of transfers this week.

static func _st() -> Dictionary:
	return MarketSave.section("transfer")

static func fee() -> int:
	return int(Goods.rules()["transfer"]["fee"])

static func week_s() -> int:
	return int(Goods.rules()["transfer"]["week_days"]) * 86400

static func outbox() -> Array:
	return _st()["out"]

## Seconds until you can send another (0: now).
static func wait_s() -> int:
	var left := 0
	for t in _st()["sent"]:
		left = maxi(left, int(t) + week_s() - MarketSave.now())
	return left

## Sends a Boki to a named player: the fee is paid and the Boki waits for them to accept.
## {ok, why, id, packet}.
static func send(uid: String, to_name: String) -> Dictionary:
	var to := Social.say_of(to_name, "", 24).strip_edges()
	var rec := Save.kin(uid)
	if rec.is_empty():
		return {"ok": false, "why": "No such Boki"}
	if to == "" or to == String(Save.d.get("name", "")):
		return {"ok": false, "why": "Type the name of the player it goes to"}
	if (Save.d["roster"] as Array).size() <= 1:
		return {"ok": false, "why": "It's your only Boki"}
	var pinned := KinBox.pinned(rec)
	if pinned != "":
		return {"ok": false, "why": pinned}
	var egg: Dictionary = Save.d.get("egg", {})
	if not egg.is_empty() and (String(egg.get("a", "")) == uid or String(egg.get("b", "")) == uid):
		return {"ok": false, "why": "Its egg is still in the Nesting Nook: wait for it to hatch"}
	if wait_s() > 0:
		return {"ok": false, "why": "One transfer a week: the next in %d h" % int(ceil(wait_s() / 3600.0))}
	if int(Save.d.get("gems", 0)) < fee():
		return {"ok": false, "why": "A transfer costs %d gems" % fee()}
	Save.d["gems"] = int(Save.d["gems"]) - fee()
	Save.d["roster"].erase(rec)
	for k in ["active", "active2"]:
		if String(Save.d.get(k, "")) == uid: Save.d[k] = ""
	if Save.kin(str(Save.d.get("active", ""))).is_empty() and not (Save.d["roster"] as Array).is_empty():
		Save.d["active"] = Save.d["roster"][0]["uid"]
	var o := {"id": MarketSave.next_id(), "rec": rec, "to": to, "fee": fee(), "t": MarketSave.now()}
	outbox().append(o)
	_st()["sent"].append(int(o["t"]))
	Save.log_event("transfer_out", rec, {"to": to})
	Save.save_game()
	return {"ok": true, "why": "", "id": String(o["id"]), "packet": packet(o)}

## What travels to the other player: only the safe parts of the Boki.
static func packet(o: Dictionary) -> Dictionary:
	return {"id": String(o["id"]), "from": String(Save.profile().get("id", "")),
		"from_name": String(Save.d.get("name", "Hunter")), "to": String(o["to"]), "kin": Social.clean_kin(o["rec"]),
		"t": int(o["t"])}

## Calls back a Boki the other side hasn't accepted: it comes home, and the fee and this week's
## transfer are given back. {ok, why}.
static func recall(id: String) -> Dictionary:
	for o in outbox():
		if String(o["id"]) != id: continue
		outbox().erase(o)
		var rec: Dictionary = o["rec"]
		Save.d["roster"].append(rec)
		if Save.kin(str(Save.d.get("active", ""))).is_empty(): Save.d["active"] = rec["uid"]
		KinBox.route_back(rec)
		Save.d["gems"] = int(Save.d.get("gems", 0)) + int(o["fee"])
		(_st()["sent"] as Array).erase(int(o["t"]))
		Save.save_game()
		return {"ok": true, "why": ""}
	return {"ok": false, "why": "That transfer is done"}

## The other side accepted: the Boki is theirs now.
static func delivered(id: String) -> void:
	for o in outbox():
		if String(o["id"]) == id:
			outbox().erase(o)
			Save.save_game()
			return

## The receiving side: accepting a packet sent to you. {ok, why, rec}.
static func accept(p: Dictionary) -> Dictionary:
	var c := Social.clean_kin(p.get("kin"))
	if c.is_empty():
		return {"ok": false, "why": "That Boki couldn't be read"}
	if KinBox.full():
		return {"ok": false, "why": "The farm and the Boki Burrow are full"}
	var giver := Social.say_of(p.get("from_name"))
	var rec := Save.new_kin(c["species"], c["name"])
	rec["level"] = int(c["level"])
	rec["shimmer"] = c["shimmer"]
	if c.has("mutations"): rec["mutations"] = (c["mutations"] as Array).duplicate()
	for k in c["traits"]: rec["traits"][k] = c["traits"][k]
	Evo.ensure(rec)
	rec["forms"] = (c["forms"] as Array).duplicate()
	for a in c["aff"]: rec["aff"][a] = c["aff"][a]
	var ev := Evo.try_evolve(rec, "trade")      # some lines evolve when traded (content/rules/evolve.json)
	if not ev.is_empty():
		ev["text"] = Evo.describe(ev, rec)
		rec["pending_evo"] = [ev]
	if c.has("acc"): rec["acc"] = c["acc"]
	rec["trust"] = 25.0           # a new keeper: it doesn't know you yet
	rec["raised_by"] = [giver]
	rec["origin"] = {"how": "transfer", "where": {"place": "home"}, "from": giver, "t": MarketSave.now()}
	Save.remember(rec, "adopted", "was raised by %s, who handed it to you" % giver, 1.0)
	Care.ensure(rec)
	Save.d["roster"].append(rec)
	Save.register(rec)
	KinBox.route_new(rec)
	Care.dex_got(rec)
	Save.save_game()
	return {"ok": true, "why": "", "rec": rec}
