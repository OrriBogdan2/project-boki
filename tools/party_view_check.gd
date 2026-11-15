extends RefCounted
## --party-view-check: the party screen (PartyView) driven through make, join, ready, find match and the
## open seats, against the fake matchmaker of --party-client-check. Never touches the save.

var bad := 0
var main: Node
var fake: RefCounted = load("res://tools/party_client_check.gd").new()

func ok(cond: bool, what: String) -> void:
	print("PARTYVIEW %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d["tutorial"] = {}
	_seats()
	var a := _client()
	var va := await _open(a)
	ok(_btn(va, "MakeBtn").disabled, "before the tutorial: Make a party is off")
	ok(_texts(va).has("Finish the tutorial first."), "...and says why")
	Save.d["tutorial"] = {"home": true}
	va.queue_free()
	va = await _open(a)
	await _press(va, "MakeBtn")
	ok(a.state == Party.State.FORMING and _texts(va).has(fake.CODE), "Make a party: forming, the invite code shows")
	ok(_texts(va).has("Expeditions take 3. We fill the rest."), "the one line: Expeditions take 3. We fill the rest.")
	ok(_texts(va).has("Open seat") and not _btn(va, "FindBtn").disabled, "alone: two open seats, Find match is on")
	var b := _client()
	var vb := await _open(b)
	vb.code_in.text = "k7qm2"
	await _press(vb, "JoinBtn")
	ok(b.state == Party.State.FORMING and _btn(vb, "ReadyBtn") != null, "join by code: a member gets Ready")
	await a.heartbeat()
	await _frames()
	ok(_texts(va).has("Not full? We fill the rest with other hunters."), "two in: the rest is filled by the matchmaker")
	var c := _client()
	await c.join(fake.CODE)
	var d := _client()
	var vd := await _open(d)
	vd.code_in.text = fake.CODE
	await _press(vd, "JoinBtn")
	ok(d.state == Party.State.NONE and _texts(vd).has(PartyView.ERRORS["full"]), "a fourth is told it is full")
	await a.heartbeat()
	await _frames()
	var full_line := "Three in. A fourth friend waits for the next expedition."
	ok(_texts(va).has(full_line), "three in: the card says a fourth waits")
	ok(not _texts(va).has("Open seat") and _btn(va, "FindBtn").disabled, "full: no open seat, Find match waits")
	await _press(vb, "ReadyBtn")
	ok(b.is_ready() and _texts(vb).has("I'm not ready"), "Ready shows on the member's own screen")
	await c.set_ready(true)
	await a.heartbeat()
	await _frames()
	ok(_texts(va).count("READY") == 2 and not _btn(va, "FindBtn").disabled, "two Ready: Find match is on")
	await _press(va, "FindBtn")
	ok(a.state == Party.State.QUEUED and _btn(va, "CancelBtn") != null, "Find match: queued, Cancel search is offered")
	var looking: Array = _texts(va).filter(func(t): return t.begins_with("Looking for a squad"))
	ok(not looking.is_empty(), "the screen says it is looking for a squad")
	await _press(va, "CancelBtn")
	ok(a.state == Party.State.FORMING and _btn(va, "FindBtn") != null, "Cancel search: back on the card")
	await _press(vb, "LeaveBtn")
	ok(b.state == Party.State.NONE and _btn(vb, "MakeBtn") != null, "Leave party: back to make or join")
	for v in [va, vb, vd]:
		v.queue_free()
	print("PARTYVIEW DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _seats() -> void:
	var members := [
		{"name": "Ann", "ready": false, "leader": true, "you": true},
		{"name": "Bo", "ready": true, "leader": false, "you": false},
	]
	var s := PartyView.seats(members, "Vex")
	ok(s.size() == 3 and s[0]["hunter"] == "Vex" and s[0]["tags"] == ["Leader"], "seats: three, yours, the leader")
	ok(s[1]["tags"] == ["Ready"] and s[2]["name"] == "Open seat", "seats: a ready friend, then an open seat")

func _client() -> Party:
	var party := Party.new()
	party.mm = NetMatchmaker.new()
	party.mm.transport = fake.fake
	return party

func _open(party: Party) -> PartyView:
	var view := PartyView.new()
	view.party = party
	main.add_child(view)
	await _frames()
	return view

func _btn(view: Node, id: String) -> Button:
	return view.find_child(id, true, false) as Button

func _press(view: Node, button: String) -> void:
	_btn(view, button).pressed.emit()
	await _frames()

func _frames() -> void:
	for i in 3:
		await main.get_tree().process_frame

func _texts(node: Node) -> Array:
	var out: Array = []
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	for ch in node.get_children():
		if not ch.is_queued_for_deletion():
			out.append_array(_texts(ch))
	return out
