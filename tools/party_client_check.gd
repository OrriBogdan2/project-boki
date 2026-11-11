extends RefCounted
## --party-client-check: the party client (Party + NetMatchmaker) against a fake matchmaker that answers the
## HTTP contract of server/README.md ("Parties"), so it runs without the Python service.
##   1. gates: the tutorial flag, the matchmaker address, the secret goes in the header (never the path)
##   2. create, join (wrong code, wrong version, full), the card, mode, ready, leader's Find match
##   3. queue: the ticket poll, ready -> Net.server_addr, Net.token and Net.start()
##   4. back to forming after the match; a dropped member clears Ready; leave; 404 gone; a solo ticket
## Never touches the save.

const CODE := "K7QM2"

var bad := 0
var main: Node
var parties := {}                # code -> {state, mode, members: [{id, name, ready}], ticket_ready}
var paths: Array = []            # every path the fake saw
var secret_in_path := false
var next_id := 0

func ok(cond: bool, what: String) -> void:
	print("PARTY %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d["tutorial"] = {}
	_addresses()
	var a := _client()
	var b := _client()
	var c := _client()
	var d := _client()
	await _gate(a)
	Save.d["tutorial"] = {"home": true}
	await _forming(a, b, c, d)
	await _queue(a, b, c)
	await _drops(a, b, c)
	await _solo(d)
	ok(not secret_in_path, "the member secret never appeared in a path (%d calls)" % paths.size())
	print("PARTY CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _client() -> Party:
	var party := Party.new()
	party.mm = NetMatchmaker.new()
	party.mm.transport = fake
	return party

func _addresses() -> void:
	ok(NetMatchmaker.pick_addr("mm.example:9000", "10.0.0.5:7777") == "mm.example:9000", "--matchmaker= wins")
	ok(NetMatchmaker.pick_addr("", "10.0.0.5:7777") == "10.0.0.5:8080", "else the --server= host on 8080")
	ok(NetMatchmaker.pick_addr("", "") == "", "no address, no matchmaker")
	ok(Net.mm != null and Net.party != null and Net.party.mm == Net.mm, "Net holds the matchmaker and the party")

func _gate(a: Party) -> void:
	ok(not Party.can_join(), "can_join is false before the tutorial")
	ok(not await a.create() and a.error == "tutorial", "create refused before the tutorial")
	ok(a.state == Party.State.NONE, "...and no party was made")
	ok(not await a.join(CODE) and a.error == "tutorial", "join refused before the tutorial")
	Save.d["tutorial"] = {"home": true}
	ok(Party.can_join(), "can_join once tutorial.home is set")
	Save.d["tutorial"] = {}

func _forming(a: Party, b: Party, c: Party, d: Party) -> void:
	ok(await a.create() and a.state == Party.State.FORMING and a.code == CODE, "create: forming, the code")
	ok(a.is_leader() and a.members.size() == 1 and a.mm.member != "", "the creator leads and holds a secret")
	ok(not await a.create() and a.error == "busy", "no second party while in one")
	ok(not await b.join("ZZZZZ") and b.error == "not_found" and b.state == Party.State.NONE, "wrong code: not_found")
	ok((await a.mm.send("POST", "/party/" + CODE + "/join", {"name": "Old", "version": "0.0.1"}))["error"] == "version",
		"another version: 409 version")
	ok(await b.join(" k7qm2 ") and b.code == CODE and b.members.size() == 2, "join in any case: two members")
	ok(not b.is_leader(), "the joiner is not the leader")
	ok(await c.join(CODE) and not await d.join(CODE) and d.error == "full", "a fourth is refused: full")
	await a.heartbeat()
	ok(a.members.size() == 3, "the leader's card shows all three")
	ok(not await b.set_mode("arena") and b.error == "not_leader", "only the leader sets the mode")
	ok(await a.set_mode("arena") and a.mode == "arena", "the leader sets the mode")
	await b.set_ready(true)
	await c.set_ready(true)
	await b.heartbeat()
	ok(b.is_ready() and not a.is_ready(), "ready shows on the card")
	await a.set_mode("trio")
	await b.heartbeat()
	ok(not b.is_ready(), "changing the mode clears every ready")

func _queue(a: Party, b: Party, c: Party) -> void:
	ok(not await a.set_ready(true) and a.error == "not_ready", "Find match waits for the others")
	await b.set_ready(true)
	await c.set_ready(true)
	ok(await a.set_ready(true), "all ready: the leader's Find match is accepted")
	ok(a.state == Party.State.QUEUED and a.ticket != "", "...and the party is queued with a ticket")
	await b.heartbeat()
	ok(b.state == Party.State.QUEUED and b.ticket != a.ticket, "a member follows, with its own ticket")
	await b.poll_ticket()
	ok(b.state == Party.State.QUEUED and b.queue_position == 1 and b.eta_s == 12, "waiting: position and eta")
	var its_ticket := b.ticket
	parties[CODE]["ticket_ready"] = true
	await b.poll_ticket()
	ok(b.state == Party.State.PLAYING and Net.server_addr == "127.0.0.1:7799" and Net.token == "tok-" + its_ticket,
		"ready: Net.server_addr and Net.token are set")
	ok(Net.started and Net.enet != null, "ready: Net.start() opened the connection")
	_stop_net()
	parties[CODE]["state"] = "forming"
	parties[CODE]["ticket_ready"] = false
	_clear_ready(parties[CODE])
	await b.heartbeat()
	ok(b.state == Party.State.FORMING and b.ticket == "", "the match is over: back on the card")
	ok(not b.is_ready(), "...not ready")

func _drops(a: Party, b: Party, c: Party) -> void:
	await b.set_ready(true)
	var count: int = parties[CODE]["members"].size()
	_drop(c.mm.member)
	await a.heartbeat()
	await b.heartbeat()
	ok(a.members.size() == count - 1 and b.members.size() == count - 1, "a dropped member: the card shrinks")
	ok(not b.is_ready(), "a dropped member: every ready is cleared")
	await c.heartbeat()
	ok(c.state == Party.State.NONE and c.code == "", "the dropped member's next heartbeat: 403 not_member ends it")
	await b.leave()
	ok(b.state == Party.State.NONE and b.mm.member == "", "leave: back to none")
	await a.heartbeat()
	ok(a.members.size() == 1 and a.is_leader(), "the leader is alone again")
	parties.clear()
	var ended := []
	a.ended.connect(func(why): ended.append(why))
	await a.heartbeat()
	ok(a.state == Party.State.NONE and ended == ["gone"], "404 gone: 'your party ended', back to solo")

func _solo(d: Party) -> void:
	ok(await d.queue_solo("trio") and d.state == Party.State.QUEUED and d.code == "", "a solo ticket queues")
	await d.poll_ticket()
	ok(d.queue_position == 1, "the solo ticket polls like a party's")
	await d.cancel_queue()
	ok(d.state == Party.State.NONE and d.ticket == "", "cancel drops the solo ticket")

# ------------------------------------------------------------------ the fake matchmaker
func _stop_net() -> void:
	Net.enet.close()
	Net.enet.queue_free()
	Net.enet = null
	Net.started = false
	Net.server_addr = ""
	Net.token = ""

func _drop(secret: String) -> void:
	var party: Dictionary = parties[CODE]
	party["members"] = party["members"].filter(func(m): return m["id"] != secret)
	for m in party["members"]:
		m["ready"] = false

func fake(method: String, path: String, member: String, body: Dictionary) -> Dictionary:
	paths.append(path)
	secret_in_path = secret_in_path or (member != "" and path.contains(member))
	var parts := path.trim_prefix("/").split("/")
	if parts[0] == "queue":
		return fake_queue(method, parts, body)
	if method == "POST" and parts.size() == 1:
		return _new_party(body)
	var party: Dictionary = parties.get(parts[1], {})
	if party.is_empty():
		return {"status": 404, "error": "not_found" if method == "POST" and parts[2] == "join" else "gone"}
	var action := parts[2] if parts.size() > 2 else ""
	if action == "join":
		return _join(party, body)
	var me: Array = party["members"].filter(func(m): return m["id"] == member)
	if me.is_empty():
		return {"status": 403, "error": "not_member"}
	return _member_call(party, me[0], method, action, body)

func _new_party(body: Dictionary) -> Dictionary:
	var id := _id()
	parties[CODE] = {"state": "forming", "mode": "trio", "ticket_ready": false, "members": [_member(id, body)]}
	return {"status": 200, "code": CODE, "member": id}

func _join(party: Dictionary, body: Dictionary) -> Dictionary:
	if body.get("version") != Net.VERSION:
		return {"status": 409, "error": "version"}
	if party["members"].size() >= 3:
		return {"status": 409, "error": "full"}
	var id := _id()
	party["members"].append(_member(id, body))
	return {"status": 200, "member": id}

func _member_call(party: Dictionary, me: Dictionary, method: String, action: String, body: Dictionary) -> Dictionary:
	var is_leader: bool = party["members"][0] == me
	match [method, action]:
		["GET", ""]: return _view(party, me)
		["POST", "mode"]:
			if not is_leader:
				return {"status": 403, "error": "not_leader"}
			party["mode"] = body["mode"]
			_clear_ready(party)
		["POST", "ready"]:
			if is_leader and body["ready"] and party["members"].any(func(m): return m != me and not m["ready"]):
				return {"status": 409, "error": "not_ready"}
			me["ready"] = body["ready"]
			if is_leader and body["ready"]:
				party["state"] = "queued"
		["DELETE", "queue"]:
			party["state"] = "forming"
			_clear_ready(party)
		["POST", "leave"]:
			_drop(me["id"])
	return {"status": 200}

func _view(party: Dictionary, me: Dictionary) -> Dictionary:
	var out := {"status": 200, "state": party["state"], "mode": party["mode"], "members": party["members"].map(
		func(m): return {"name": m["name"], "ready": m["ready"], "leader": m == party["members"][0], "you": m == me})}
	if party["state"] != "forming":
		out["ticket"] = "tk-" + me["id"].trim_prefix("sec-")
	return out

func fake_queue(method: String, parts: PackedStringArray, body: Dictionary) -> Dictionary:
	if method == "POST":
		return {"status": 200, "ticket": "t-solo"}
	if method == "DELETE":
		return {"status": 200, "state": "gone"}
	if parts[1] == "t-solo" or not parties.get(CODE, {}).get("ticket_ready", false):
		return {"status": 200, "state": "waiting", "position": 1, "eta_s": 12}
	return {"status": 200, "state": "ready", "host": "127.0.0.1", "port": 7799, "token": "tok-" + parts[1]}

func _member(id: String, body: Dictionary) -> Dictionary:
	return {"id": id, "name": body["name"], "ready": false}

func _clear_ready(party: Dictionary) -> void:
	for m in party["members"]:
		m["ready"] = false

func _id() -> String:
	next_id += 1
	return "sec-%d" % next_id
