class_name TransferPost
## Carries Boki transfers between players (docs/decisions/0099-transfer-carrier.md) until the
## exchange server does: through the web build's shared store (Social), where visit profiles live.
## Transfer keeps the rules and both sides; this file only moves the packet and the answer, so the
## server swaps this file and nothing else.
##
## A sent Boki waits in your outbox (still in your save) as transfers/<your store id>_<outbox id>,
## addressed to the profile carrying the name you typed. The receiver claims it, answers
## (transfer_answers: yes or no) and only then deletes it; the sender settles an answer only once the
## packet is gone, so the Boki leaves your save on "yes" and comes home on "no" (fee refunded).
## Nothing here is saved: the store holds what is in flight, the outbox holds the Boki.

const PACKETS := "transfers"
const ANSWERS := "transfer_answers"

static var inbox: Array = []       # Boki waiting for you to accept: {doc, p} with p cleaned (clean)
static var _busy := false          # a sync or an answer in flight


## On coming home: settles answered transfers, posts the ones not on the store yet and fetches what
## was handed to you. cb gets lines to show.
static func sync(cb: Callable) -> void:
	if not Social.available() or _busy:
		cb.call([])
		return
	_busy = true
	var lines: Array = []
	Social.query(ANSWERS, [["to", "==", Social.me]], "", "asc", 40, func(answers: Array):
		Social.each(Transfer.outbox().duplicate(), func(o: Dictionary, next: Callable):
			_step(o, answers, lines, next),
		func():
			var waiting := Transfer.outbox().map(func(o): return String(o["id"]))
			for a in answers:           # answers to transfers that are settled or called back
				if not waiting.has(Social.txt_of(a["data"].get("tid"))):
					Social.del_doc(ANSWERS + "/" + String(a["id"]))
			_fetch(lines, cb)))


## Answers a Boki handed to you: yes takes it in (Transfer.accept), no sends it home. cb gets
## {ok, why} (and rec on yes).
static func answer(doc: String, yes: bool, cb: Callable) -> void:
	if _busy or not Social.available():
		cb.call({"ok": false, "why": "The town store isn't answering"})
		return
	if yes and KinBox.full():
		cb.call({"ok": false, "why": "The farm and the Boki Burrow are full"})
		return
	_busy = true
	var done := func(r: Dictionary):
		_busy = false
		cb.call(r)
	Social.claim(PACKETS + "/" + doc, func(raw: Dictionary):
		var p := clean(raw)
		if p.is_empty():
			inbox = inbox.filter(func(e): return e["doc"] != doc)
			done.call({"ok": false, "why": "It was called back"})
			return
		var reply := {"to": p["by"], "tid": p["id"], "yes": yes, "t": MarketSave.now()}
		Social.add_doc(ANSWERS, reply, func(aid: String):
			if aid == "":
				done.call({"ok": false, "why": "The town store isn't answering"})
				return
			Social.del_doc(PACKETS + "/" + doc, func(gone: bool):
				if not gone:
					done.call({"ok": false, "why": "The town store isn't answering"})
					return
				inbox = inbox.filter(func(e): return e["doc"] != doc)
				done.call(Transfer.accept(p) if yes else {"ok": true, "why": ""}))))


## Calls back a Boki you sent: only while its packet is still unanswered on the store. cb gets {ok, why}.
static func recall(id: String, cb: Callable) -> void:
	if not Social.available():
		# the desktop build never posts, so its outbox is local; a web build has to reach the store
		var offline := {"ok": false, "why": "The town store isn't answering"}
		cb.call(Transfer.recall(id) if not OS.has_feature("web") else offline)
		return
	if _busy:
		cb.call({"ok": false, "why": "Try again in a moment"})
		return
	_busy = true
	var done := func(r: Dictionary):
		_busy = false
		cb.call(r)
	var path := _path(id)
	Social.get_doc(path, func(still: Dictionary):
		if still.is_empty():
			Social.query(ANSWERS, [["to", "==", Social.me], ["tid", "==", id]], "", "asc", 1, func(rows: Array):
				done.call(Transfer.recall(id) if rows.is_empty()
					else {"ok": false, "why": "They already answered: it settles when you next come home"}))
			return
		Social.claim(path, func(held: Dictionary):
			if held.is_empty():
				done.call({"ok": false, "why": "They're answering right now: try again in a moment"})
				return
			Social.del_doc(path, func(gone: bool):
				done.call(Transfer.recall(id) if gone else {"ok": false, "why": "The town store isn't answering"}))))


## A packet read from the store (written by another player, so untrusted). {} if it can't be used.
static func clean(raw: Dictionary) -> Dictionary:
	var kin := Social.clean_kin(raw.get("kin"))
	var by := Social.txt_of(raw.get("by"))
	var id := Social.txt_of(raw.get("id"))
	if kin.is_empty() or by == "" or by == Social.me or id == "":
		return {}
	return {"id": id, "by": by, "from_name": Social.say_of(raw.get("from_name")), "kin": kin,
		"t": Social.int_of(raw.get("t"))}


static func _path(id: String) -> String:
	return "%s/%s_%s" % [PACKETS, Social.me, id]


## One outbox entry: settle its answer once the packet is gone, or post it if it isn't on the store.
static func _step(o: Dictionary, answers: Array, lines: Array, next: Callable) -> void:
	var id := String(o["id"])
	var nm := String(o["rec"].get("name", "A Boki"))
	Social.get_doc(_path(id), func(still: Dictionary):
		if not still.is_empty():
			next.call()        # still waiting for them
			return
		var mine := answers.filter(func(a): return Social.txt_of(a["data"].get("tid")) == id)
		if not mine.is_empty():
			if mine[0]["data"].get("yes") == true:
				Transfer.delivered(id)
				lines.append("%s accepted %s. It's theirs now." % [o["to"], nm])
			elif Transfer.recall(id)["ok"]:
				lines.append("%s couldn't take %s: it came home, and the fee came back." % [o["to"], nm])
			next.call()
			return
		Social.query("profiles", [["name", "==", String(o["to"])]], "", "asc", 1, func(rows: Array):
			if rows.is_empty() or rows[0]["id"] == Social.me:
				next.call()    # nobody by that name has a farm here yet: it waits
				return
			var doc := Transfer.packet(o)
			doc["by"] = Social.me
			doc["for"] = String(rows[0]["id"])
			Social.set_doc(_path(id), doc, func(_ok: bool): next.call())))


## Fetches the Boki handed to you; a line for each one that's new this session.
static func _fetch(lines: Array, cb: Callable) -> void:
	Social.query(PACKETS, [["for", "==", Social.me]], "", "asc", 20, func(rows: Array):
		var seen := inbox.map(func(e): return e["doc"])
		inbox = []
		for r in rows:
			var p := clean(r["data"])
			if p.is_empty():
				continue
			inbox.append({"doc": r["id"], "p": p})
			if not seen.has(r["id"]):
				lines.append("%s wants to hand you %s: accept or refuse it at the market stall's Shelter."
					% [p["from_name"], p["kin"]["name"]])
		_busy = false
		cb.call(lines))
