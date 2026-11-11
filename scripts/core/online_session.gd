class_name OnlineSession
extends Node
## Matchmade play from the button to the results: pick the region that answers fastest (or the one
## chosen in Settings), queue at its matchmaker (MatchmakerClient), connect to the match server it
## hands out with the one-time token (Net), wait for the roster, play, and leave the line when the
## match is over. One per game, under the Net autoload; the online screen shows its state.
##
## state: idle | region | queue | connect | wait | match | error.  `message` is what to show.

signal changed

const SERVERS_PATH := "res://content/rules/servers.json"
const POLL_S := 1.0              # s between queue polls
const POLL_MISSES := 3           # unanswered polls in a row before the queue counts as lost
const MODE_NAMES := {"duel": "Duel, 1 v 1", "arena": "Arena, 4 v 4", "trio": "Expedition, squads of 3"}

var state := "idle"
var mode := ""
var message := ""
var error_code := ""       # on "error": version | bad_token | full | unreachable | gone
var region := {}           # {id, url, ms, version}
var ticket := ""
var place := 0             # our spot in the queue
var eta_s := 0
var my_team := -1
var mm: MatchmakerClient
var _run := 0              # bumped by cancel: an older queue loop stops at its next step

## The one session, made on first use.
static func get_session() -> OnlineSession:
	var s: OnlineSession = Net.get_node_or_null("Online")
	if s == null:
		s = OnlineSession.new()
		s.name = "Online"
		Net.add_child(s)
	return s

## The regions from content/rules/servers.json: [{id, url}].
static func regions() -> Array:
	var f := FileAccess.open(SERVERS_PATH, FileAccess.READ)
	if f == null:
		return []
	var d = JSON.parse_string(f.get_as_text())
	return d.get("regions", []) if typeof(d) == TYPE_DICTIONARY else []

## True when a matchmaker is configured at all (the online buttons show).
static func configured() -> bool:
	return not OS.has_feature("web") and not regions().is_empty()

func _ready() -> void:
	mm = MatchmakerClient.new()
	mm.name = "Matchmaker"
	add_child(mm)
	Net.peers_changed.connect(_on_net)
	Net.message.connect(_on_msg)
	Game.screen_changed.connect(_on_screen)

## Queue for `which` (duel | arena | trio). `where` overrides the regions file (tests).
func queue_for(which: String, where: Array = []) -> void:
	cancel()
	_run += 1
	var run := _run
	mode = which
	my_team = -1
	_go_state("region", "Finding the nearest server...")
	var list := where if not where.is_empty() else regions()
	region = await mm.best_region(list, String(Settings.get_v("region")))
	if run != _run:
		return
	if region.is_empty():
		_fail("unreachable", "No matchmaking server answered. Check your connection and try again.")
		return
	var res := await mm.queue(String(region["url"]), mode, String(Save.d.get("name", "Hunter")))
	if run != _run:
		return
	if res["code"] == MatchmakerClient.CODE_UNREACHABLE or typeof(res["json"]) != TYPE_DICTIONARY:
		_fail("unreachable", "The %s matchmaker stopped answering. Try again." % String(region["id"]).to_upper())
		return
	var j: Dictionary = res["json"]
	if j.has("error"):
		_mm_error(j)
		return
	ticket = String(j.get("ticket", ""))
	_go_state("queue", "In the queue for %s" % MODE_NAMES.get(mode, mode))
	await _poll_loop(run)

## Out of the queue, or off the line, whatever step we're at.
func cancel() -> void:
	_run += 1
	if state == "queue" and ticket != "":
		mm.leave(String(region["url"]), ticket)
	ticket = ""
	if state in ["connect", "wait"]:
		Net.leave()
	if state != "idle":
		_go_state("idle", "")

## Straight to a match server with a token, no matchmaker (the server check).
func join(host: String, port: int, token: String) -> void:
	cancel()
	_run += 1
	_go_state("connect", "Connecting to the match server...")
	Net.connect_to("%s:%d" % [host, port], token)

## What the match server learns about us: the name and kit the roster shows (the lobby adds its own keys).
## (Settings > Demo > All masks open is offline only, so the Hunter goes through ClassUnlock.)
static func presence() -> Dictionary:
	var k := Save.active_kin()
	var arch := ClassUnlock.online_arch(Arch.of_save())
	var cls := Data.class_of_save()
	var weapon := String(Save.d.get("weapon", ""))
	if arch != Arch.of_save():
		cls = Arch.weight(arch)
		weapon = Arch.signature(arch)
	var kin := {"species": k.get("species", "cindle"), "level": int(k.get("level", 1)), "name": k.get("name", "Boki"),
		"traits": k.get("traits", {}), "trust": float(k.get("trust", 50))}
	return {"name": Save.d.get("name", "Hunter"), "cls": cls, "weapon": weapon, "arch": arch, "kin": kin}

func _poll_loop(run: int) -> void:
	var misses := 0
	while run == _run:
		await get_tree().create_timer(POLL_S).timeout
		if run != _run:
			return
		var res := await mm.poll(String(region["url"]), ticket)
		if run != _run:
			return
		if res["code"] == MatchmakerClient.CODE_UNREACHABLE or typeof(res["json"]) != TYPE_DICTIONARY:
			misses += 1
			if misses >= POLL_MISSES:
				_fail("unreachable", "Lost the %s matchmaker. Try again." % String(region["id"]).to_upper())
			continue
		misses = 0
		var j: Dictionary = res["json"]
		match String(j.get("state", "")):
			"waiting":
				place = int(j.get("position", 0))
				eta_s = int(j.get("eta_s", 0))
				changed.emit()
			"ready":
				ticket = ""
				join(String(j.get("host", "")), int(j.get("port", 7777)), String(j.get("token", "")))
				return
			_:
				_fail("gone", "The queue dropped your ticket. Queue again.")
				return

func _mm_error(j: Dictionary) -> void:
	var err := String(j.get("error", ""))
	if err == "version":
		_fail("version", _version_text(String(j.get("server_version", "?"))))
	else:
		_fail("unreachable", "The matchmaker refused the request (%s). Try again." % err)

func _version_text(server_version: String) -> String:
	return "Your game is out of date: you have %s, the servers run %s. Update the game to play online." % [
		Net.VERSION, server_version]

func _on_net() -> void:
	if state == "connect" and Net.mode != "":
		Net.set_presence(presence())
		_go_state("wait", "Connected. Waiting for the other hunters...")
	elif state in ["connect", "wait", "match"] and Net.mode == "":
		match Net.deny_code:
			"version": _fail("version", _version_text(Net.deny_version))
			"bad_token": _fail("bad_token", "This match ticket isn't valid any more (expired or used). Queue again.")
			"full": _fail("full", "That match filled up before you got in. Queue again.")
			_: _fail("unreachable", "Couldn't reach the match server. " + Net.deny_reason)

func _on_msg(topic: String, data, _from: String) -> void:
	if typeof(data) != TYPE_DICTIONARY or state not in ["wait", "match"]:
		return
	if topic == "start":
		for r in data.get("roster", []):
			if String(r["peer"]) == Net.me:
				my_team = int(r["team"])
				_go_state("match", "")
				Game.start_match({"net": data, "seed": int(data["seed"]), "teams": int(data["teams"]),
					"squad": int(data["squad"]), "tier": int(data.get("tier", 0)), "matchmade": true})
				return
	elif topic == "end":
		var m := Game.main.current as Match if Game.main else null
		if m:
			m.net_over(int(data.get("team", -2)) == my_team)

## The match is over (or left): off the line.
func _on_screen(screen: String) -> void:
	if state == "match" and screen != "match":
		Net.leave()
		_go_state("idle", "")

func _go_state(st: String, msg: String) -> void:
	state = st
	message = msg
	changed.emit()

func _fail(code: String, msg: String) -> void:
	ticket = ""
	error_code = code
	if Net.mode != "" or Net.started:
		Net.leave()
	_go_state("error", msg)
