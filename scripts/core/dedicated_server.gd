class_name DedicatedServer
extends Node
## `--server --port <N> --mode duel|arena|trio --match-id <id> --tokens-file <path> [--seed <s>]
## [--idle-exit <s>]`: one authoritative match for the matchmaker, with no local player.
##
## The process runs the relay (scripts/server/relay.gd) on its port with the matchmaker's token
## table, and joins its own relay over loopback as the match host, exactly like the player who
## presses Start in the lobby does; the match's bots, monsters and loot run here. Players connect
## with their one-time tokens; once every seat is taken (or JOIN_WAIT after the first player) the
## roster goes out as the lobby's "start" message and the match begins, bots in the empty seats.
## It ends when one team is left (or the islands fall), the result goes out as "end", and the
## process exits 0. Status lines on stdout, for the matchmaker:
##   BOKI_SERVER ready port=<N>  /  joined slot=<i>  /  end result=<...>  (and pid=<pid> first)
## `--version` alone prints `BOKI_SERVER version=<Net.VERSION>` and exits: the matchmaker's version gate.
##
## Seats are team-major: seat i sits on team i / team_size. The tokens file's "slots" and
## "team_size" size the match when given; otherwise the mode's defaults below.

const MODES := {"duel": {"teams": 2, "squad": 1}, "arena": {"teams": 2, "squad": 4}, "trio": {"teams": 4, "squad": 3}}
const JOIN_WAIT := 15.0          # s after the first player is in before the match starts without the rest
const END_GRACE := 2.5           # s the winners get to see the last knock before the server calls it
const QUIT_DELAY := 1.0          # s for the "end" message to reach everyone before the process exits
const DEFAULT_IDLE_EXIT := 120.0 # s with nobody ever joining before the process gives up (exit 0)
const EXIT_BAD_ARGS := 2
const EXIT_NO_PORT := 3

var port := 7777
var mode := "duel"
var match_id := ""
var seed_val := 0
var idle_exit := DEFAULT_IDLE_EXIT
var tokens := {}
var teams := 2
var squad := 1
var relay: RelayServer
var m: Match = null
var seats := {}             # slot -> peer id (as Net knows it) of the player in it
var starting := false
var ending := false
var first_join_t := -1.0
var up_t := 0.0

func _ready() -> void:
	Save.no_write = true
	Engine.max_fps = 60      # a headless loop otherwise spins as fast as it can
	if "--version" in OS.get_cmdline_user_args():
		print("BOKI_SERVER version=%s" % Net.VERSION)
		get_tree().quit(0)
		return
	if not _parse(OS.get_cmdline_user_args()):
		get_tree().quit(EXIT_BAD_ARGS)
		return
	var slots := teams * squad
	var host_token := "host-%d-%d" % [randi(), Time.get_ticks_usec()]
	relay = RelayServer.new()
	relay.name = "Relay"
	add_child(relay)
	relay.use_tokens(tokens, slots, host_token)
	if relay.start(["--port=%d" % port, "--max=%d" % (slots + 8)]) != OK:
		get_tree().quit(EXIT_NO_PORT)
		return
	relay.admitted.connect(_on_admitted)
	relay.left.connect(_on_left)
	Game.screen_changed.connect(_on_screen)
	Net.connect_to("127.0.0.1:%d" % port, host_token)
	while Net.mode == "":
		if Net.deny_reason != "":
			printerr("server: couldn't join its own relay: %s" % Net.deny_reason)
			get_tree().quit(EXIT_NO_PORT)
			return
		await get_tree().process_frame
	print("BOKI_SERVER pid=%d" % OS.get_process_id())
	print("BOKI_SERVER ready port=%d" % port)

func _process(dt: float) -> void:
	up_t += dt
	if m == null:
		if not starting and first_join_t < 0.0 and up_t > idle_exit:
			_end("idle")
		elif not starting and first_join_t >= 0.0 and up_t - first_join_t > JOIN_WAIT:
			_start_match()
		return
	if ending or m.over or m.hunters.is_empty():
		return
	var alive := _teams_alive()
	if alive.size() <= 1:
		var win: int = alive[0] if alive.size() == 1 else -1
		_end("win team=%d" % win if win >= 0 else "win nobody", win)

## `--flag value` pairs (also --flag=value). False when something needed is missing or wrong.
func _parse(args: PackedStringArray) -> bool:
	var opts := {}
	var i := 0
	while i < args.size():
		var a := String(args[i])
		if a.begins_with("--") and a.contains("="):
			opts[a.get_slice("=", 0)] = a.get_slice("=", 1)
		elif a.begins_with("--") and i + 1 < args.size() and not String(args[i + 1]).begins_with("--"):
			opts[a] = String(args[i + 1])
			i += 1
		i += 1
	port = int(opts.get("--port", port))
	mode = String(opts.get("--mode", mode))
	match_id = String(opts.get("--match-id", ""))
	seed_val = int(opts.get("--seed", randi() | 1))
	idle_exit = float(opts.get("--idle-exit", idle_exit))
	if not MODES.has(mode):
		printerr("server: --mode must be one of %s" % [MODES.keys()])
		return false
	var path := String(opts.get("--tokens-file", ""))
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr("server: can't read --tokens-file %s" % path)
		return false
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY or typeof(d.get("tokens")) != TYPE_DICTIONARY:
		printerr("server: %s has no tokens table" % path)
		return false
	tokens = d["tokens"]
	teams = int(MODES[mode]["teams"])
	squad = int(MODES[mode]["squad"])
	if int(d.get("slots", 0)) > 0 and int(d.get("team_size", 0)) > 0:
		squad = int(d["team_size"])
		teams = maxi(1, int(d["slots"]) / squad)
	return true

func _on_admitted(id: int, slot: int) -> void:
	if slot < 0 or m != null:
		return
	print("BOKI_SERVER joined slot=%d" % slot)
	seats[slot] = str(id)
	if first_join_t < 0.0:
		first_join_t = up_t
	if seats.size() >= teams * squad:
		_start_match()

func _on_left(id: int) -> void:
	if m == null or m.over:
		return
	# a player who drops out of a running match is out of it: their team can lose on it
	var h: Hunter = m.ents_by_id.get("P%d" % id, null)
	if h and not h.out:
		m.eliminate(h, null, "left", true)

## The roster from the seats taken, out to everyone as the lobby's "start", then the match here.
func _start_match() -> void:
	if starting:
		return
	starting = true
	var roster := []
	for slot in seats:
		var peer: String = seats[slot]
		var p: Dictionary = Net.peers.get(peer, {})
		roster.append({"peer": peer, "team": int(slot) / squad, "name": p.get("name", "Hunter"),
			"cls": p.get("cls", "medium"), "weapon": p.get("weapon", ""), "arch": p.get("arch", ""),
			"kin": p.get("kin", {})})
	var d := {"mid": match_id if match_id != "" else "%d" % port, "seed": seed_val, "host": Net.me, "roster": roster,
		"teams": teams, "squad": squad, "tier": 0}
	Net.lobby_emit("start", d)
	m = Match.new()
	m.name = "Match"
	add_child(m)
	m.start({"net": d, "seed": seed_val, "teams": teams, "squad": squad, "tier": 0, "server": true})

## Teams with someone still in the fight.
func _teams_alive() -> Array:
	var out := []
	for h in m.hunters:
		if not h.out and not h.extracted and not out.has(h.team):
			out.append(h.team)
	return out

## The match called its own end (the islands fell, or everyone was out).
func _on_screen(screen: String) -> void:
	if screen == "results" and not ending:
		_end("over")

func _end(result: String, win_team := -1) -> void:
	if ending:
		return
	ending = true
	if m != null and not m.over:
		await get_tree().create_timer(END_GRACE).timeout
	print("BOKI_SERVER end result=%s" % result)
	if Net.mode != "":
		Net.lobby_emit("end", {"team": win_team, "result": result})
	await get_tree().create_timer(QUIT_DELAY).timeout
	get_tree().quit(0)
