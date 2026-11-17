class_name Party
extends Node
## The client side of queueing through the matchmaker, with friends or alone (docs/specs/PARTY.md); no UI.
## One state machine: NONE -> FORMING (create or join) -> QUEUED (the leader's ready, or queue_solo) -> PLAYING
## (a token in hand, Net.start() called) -> FORMING again once the server says the match is over.
## The matchmaker is the truth: every heartbeat answer (GET /party/<code>) is applied over what we hold.

signal changed
## The party or ticket is over: "gone" the party ended, "dropped" we are no longer a member,
## "ticket" a solo ticket died.
signal ended(why: String)

enum State { NONE, FORMING, QUEUED, PLAYING }

const HEARTBEAT_S := 3.0         # the matchmaker drops a member silent for 20 s
const TICKET_POLL_S := 1.0       # seconds between queue position refreshes

var mm: NetMatchmaker
var state := State.NONE
var code := ""                   # the invite code; "" for solo
var mode := ""
var members: Array = []          # [{name, ready, leader, you}] as the matchmaker sent them
var ticket := ""
var queue_position := 0
var eta_s := 0
var error := ""                  # the last refusal: the matchmaker's error key, "network" or "tutorial"

var _beat_t := 0.0
var _ticket_t := 0.0
var _in_flight := false
var _dead_ticket := ""          # a ticket the matchmaker called gone, so a stale heartbeat cannot revive it

## Parties are for players who finished the tutorial (the flag the farm tutorial and --skip-tutorial set).
static func can_join() -> bool:
	return Save.d["tutorial"].get("home", false)

func _process(dt: float) -> void:
	if state == State.NONE or _in_flight:
		return
	_beat_t += dt
	_ticket_t += dt
	if state == State.QUEUED and ticket != "" and _ticket_t >= TICKET_POLL_S:
		poll_ticket()
	elif code != "" and _beat_t >= HEARTBEAT_S:
		heartbeat()

func is_leader() -> bool:
	return members.any(func(m): return m["leader"] and m["you"])

func is_ready() -> bool:
	return members.any(func(m): return m["ready"] and m["you"])

## Makes a party and leads it. False (see `error`) when refused.
func create() -> bool:
	if not _can_enter():
		return false
	return await _enter(await mm.send("POST", "/party", _who()), "")

## Joins the party with this invite code (any case). False (see `error`) when refused.
func join(invite: String) -> bool:
	if not _can_enter():
		return false
	var wanted := invite.strip_edges().to_upper()
	return await _enter(await mm.send("POST", "/party/%s/join" % wanted, _who()), wanted)

## Queues alone (a solo ticket). False (see `error`) when refused.
func queue_solo(mode_id: String) -> bool:
	if state != State.NONE:
		error = "busy"
		return false
	var out := await mm.send("POST", "/queue", {"mode": mode_id, "name": _who()["name"], "version": Net.VERSION})
	if not _accepted(out):
		return false
	mode = mode_id
	ticket = String(out["ticket"])
	state = State.QUEUED
	changed.emit()
	return true

## Leader only: the mode the party queues for.
func set_mode(mode_id: String) -> bool:
	return await _party_call("POST", "/mode", {"mode": mode_id})

## Ready or not. The leader's `true` is Find match: with every other member ready it queues the party.
func set_ready(is_ready_now: bool) -> bool:
	return await _party_call("POST", "/ready", {"ready": is_ready_now})

## Leader: pulls the party out of the queue (back to forming); alone: drops the ticket.
func cancel_queue() -> void:
	if code == "":
		await leave()
		return
	await _party_call("DELETE", "/queue", {})

## Leaves the party, or drops a solo ticket, and goes back to NONE.
func leave() -> void:
	var path := "/queue/" + ticket if code == "" else "/party/%s/leave" % code
	var method := "DELETE" if code == "" else "POST"
	if code != "" or ticket != "":
		await mm.send(method, path, {})
	_reset()
	changed.emit()

## Refreshes the party card (and keeps us a member: the matchmaker drops a silent one).
func heartbeat() -> void:
	if code == "":
		return
	_beat_t = 0.0
	_in_flight = true
	var asked := code
	var out := await mm.send("GET", "/party/" + code)
	_in_flight = false
	if code != asked:
		return
	match int(out["status"]):
		200: _apply(out)
		404: _end("gone")
		403: _end("dropped")

## Asks where our ticket stands; a ready answer connects to the game server.
func poll_ticket() -> void:
	if ticket == "":
		return
	_ticket_t = 0.0
	_in_flight = true
	var asked := ticket
	var out := await mm.send("GET", "/queue/" + ticket)
	_in_flight = false
	if ticket != asked or int(out["status"]) != 200:
		return
	match String(out.get("state", "")):
		"waiting":
			queue_position = int(out.get("position", queue_position))
			eta_s = int(out.get("eta_s", eta_s))
			changed.emit()
		"ready": _play(out)
		"gone": _ticket_gone()

func _who() -> Dictionary:
	return {"name": Save.d.get("name", "Hunter"), "version": Net.VERSION}

func _can_enter() -> bool:
	if state != State.NONE:
		error = "busy"
	elif not can_join():
		error = "tutorial"
	else:
		error = ""
	return error == ""

func _accepted(out: Dictionary) -> bool:
	error = "" if int(out["status"]) == 200 else String(out.get("error", "network"))
	return error == ""

func _enter(out: Dictionary, invite: String) -> bool:
	if not _accepted(out):
		return false
	mm.member = String(out["member"])
	code = String(out.get("code", invite))
	state = State.FORMING
	await heartbeat()
	return true

## A party call that changes the card; the heartbeat then shows the result.
func _party_call(method: String, route: String, body: Dictionary) -> bool:
	var out := await mm.send(method, "/party/%s%s" % [code, route], body)
	if not _accepted(out):
		return false
	await heartbeat()
	return true

func _apply(out: Dictionary) -> void:
	mode = String(out.get("mode", ""))
	members = out.get("members", [])
	var theirs := String(out.get("ticket", ""))
	if String(out.get("state", "")) == "forming":
		if state != State.FORMING:
			ticket = ""
			state = State.FORMING
	elif theirs != "" and theirs != _dead_ticket and state != State.PLAYING:
		ticket = theirs
		state = State.QUEUED
	queue_position = int(out.get("position", queue_position))
	eta_s = int(out.get("eta_s", eta_s))
	changed.emit()

func _play(out: Dictionary) -> void:
	state = State.PLAYING
	ticket = ""
	Net.server_addr = "%s:%d" % [out["host"], int(out["port"])]
	Net.token = String(out["token"])
	Net.start()
	changed.emit()

func _ticket_gone() -> void:
	_dead_ticket = ticket
	ticket = ""
	if code == "":
		_end("ticket")
		return
	state = State.FORMING
	changed.emit()

func _end(why: String) -> void:
	_reset()
	ended.emit(why)

func _reset() -> void:
	state = State.NONE
	code = ""
	mode = ""
	members = []
	ticket = ""
	mm.member = ""
