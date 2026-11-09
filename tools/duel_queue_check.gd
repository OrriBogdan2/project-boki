extends RefCounted
## --duel-queue-check: a LIVE test of the duel ring's "Find a duel" against the EU matchmaker (needs the
## network). First the game's own path (OnlineSession.queue_for("duel")) with this build's Net.VERSION:
## it either queues or is refused with the version text, and cancelling leaves cleanly. Then a real
## ticket under the version the matchmaker serves: queued, polled until the match is found, and
## cancelled right after (a ticket with a match leaves its slot to a bot). Prints DUELQUEUE PASS/FAIL.

const REGION_ID := "eu"
const FOUND_WAIT_S := 75.0       # s: the duel fill timeout (20 s) plus a server start

var main: Node
var bad := 0

func ok(cond: bool, what: String) -> void:
	print("DUELQUEUE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	# the boot frame's long delta would time the first request out
	await main.get_tree().create_timer(1.0).timeout
	var eu := OnlineSession.regions().filter(func(r): return String(r["id"]) == REGION_ID)
	ok(not eu.is_empty(), "servers.json lists the EU matchmaker")
	if not eu.is_empty():
		await _game_path(eu)
		await _live_ticket(String(eu[0]["url"]))
	print("DUELQUEUE %s" % ("PASS" if bad == 0 else "FAIL"))
	main.get_tree().quit()

## The button's path with this build's version.
func _game_path(eu: Array) -> void:
	var session := OnlineSession.get_session()
	session.queue_for("duel", eu)
	for i in 100:
		if session.state in ["queue", "error"]:
			break
		await main.get_tree().create_timer(0.1).timeout
	var refused := session.state == "error" and session.error_code == "version"
	ok(session.state == "queue" or refused,
		"queue_for(duel): queued or refused by version (%s: %s)" % [session.state, session.message])
	session.cancel()
	ok(session.state == "idle" and session.ticket == "", "cancel leaves the line")

## A ticket the matchmaker accepts: wait for the match, then cancel.
func _live_ticket(url: String) -> void:
	var mm := MatchmakerClient.new()
	main.add_child(mm)
	var health := await mm.request(url.path_join("health"))
	ok(health["code"] == 200, "EU /health answers")
	var served := String(health["json"].get("version", "")) if typeof(health["json"]) == TYPE_DICTIONARY else ""
	var res := await mm.request(url.path_join("queue"), HTTPClient.METHOD_POST,
		{"mode": "duel", "name": "w3-duel-ring-check", "version": served})
	var ticket := String(res["json"].get("ticket", "")) if typeof(res["json"]) == TYPE_DICTIONARY else ""
	ok(ticket != "", "a duel ticket is issued (%s)" % str(res["json"]))
	if ticket == "":
		return
	var state := ""
	var t := 0.0
	while t < FOUND_WAIT_S and state != "ready":
		await main.get_tree().create_timer(1.0).timeout
		t += 1.0
		var poll := await mm.poll(url, ticket)
		state = String(poll["json"].get("state", "")) if typeof(poll["json"]) == TYPE_DICTIONARY else ""
	ok(state == "ready", "the match is found (%s after %d s)" % [state, int(t)])
	await mm.leave(url, ticket)
	var after := await mm.poll(url, ticket)
	var gone: bool = typeof(after["json"]) == TYPE_DICTIONARY and after["json"].get("state") == "gone"
	ok(gone, "cancelled: the ticket is gone")
	mm.queue_free()
