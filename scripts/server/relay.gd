class_name RelayServer
extends Node
## The Project Boki relay server: a headless copy of the game started with `-- --relay`.
## Desktop players connect here over ENet. It keeps the lobby (who's online, their presence),
## passes lobby messages to everyone and match messages to the others in the same match.
## The match itself still runs on the player who pressed Start (the host), exactly like the
## browser version; the relay only forwards.
##
## Access: when BOKI_DISCORD_BOT_TOKEN, BOKI_GUILD_ID and BOKI_ALLOWED_ROLES are set, every player
## has to log in with Discord (the launcher does this) and hold one of the allowed roles in the
## Project Boki server. Without them, anyone with the right game version can join (local testing).
##
## Settings (environment or `-- --relay --port=7777 --max=120`):
##   BOKI_PORT, BOKI_MAX_PLAYERS, BOKI_VERSION (required game version, default: this build's),
##   BOKI_DISCORD_BOT_TOKEN, BOKI_GUILD_ID, BOKI_ALLOWED_ROLES (comma-separated role ids)
##
## A dedicated match server (scripts/core/dedicated_server.gd) runs the same relay with a token
## table instead: each player's hello must carry one of the matchmaker's one-time tokens.

signal admitted(id: int, slot: int)      # a player passed the handshake (slot -1: the match host)
signal left(id: int)

const CH_RELIABLE := 0
const CH_FAST := 1
const HELLO_TIMEOUT := 20.0

var peer: ENetMultiplayerPeer
var api: SceneMultiplayer
var clients := {}          # peer id (int) -> {auth, pres, room, uid, name, t}
var need_version := ""
var auth_on := false
var bot_token := ""
var guild_id := ""
var allowed_roles: PackedStringArray = []
var started_at := 0.0
var tokens := {}           # token -> {name, slot}: the matchmaker's one-time tickets (empty: no token check)
var used_tokens := {}      # token -> peer id that spent it
var max_slots := 0         # players a token match seats; a valid token past that is refused "full"
var host_token := ""       # the dedicated server's own loopback connection presents this one

func _env(k: String, fallback := "") -> String:
	var v := OS.get_environment(k)
	return v if v != "" else fallback

## Token mode (call before start): only `table`'s tokens get in, each once, `slots` players at most,
## plus the host on `host_tok`. The Discord check is off in this mode.
func use_tokens(table: Dictionary, slots: int, host_tok: String) -> void:
	tokens = table
	max_slots = slots
	host_token = host_tok

func start(args: PackedStringArray) -> int:
	var port := int(_env("BOKI_PORT", "7777"))
	var max_players := int(_env("BOKI_MAX_PLAYERS", "120"))
	for a in args:
		if a.begins_with("--port="): port = int(a.substr(7))
		if a.begins_with("--max="): max_players = int(a.substr(6))
	need_version = _env("BOKI_VERSION", Net.VERSION)
	bot_token = _env("BOKI_DISCORD_BOT_TOKEN")
	guild_id = _env("BOKI_GUILD_ID")
	allowed_roles = _env("BOKI_ALLOWED_ROLES").split(",", false)
	auth_on = bot_token != "" and guild_id != "" and allowed_roles.size() > 0 and tokens.is_empty()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_players, 2)
	if err != OK:
		printerr("relay: couldn't listen on port %d (error %d)" % [port, err])
		return err
	api = SceneMultiplayer.new()
	api.server_relay = false
	api.multiplayer_peer = peer
	get_tree().set_multiplayer(api, get_path())
	api.peer_connected.connect(_on_join)
	api.peer_disconnected.connect(_on_leave)
	api.peer_packet.connect(_on_packet)
	started_at = Time.get_unix_time_from_system()
	print("relay: listening on %d, up to %d players, version %s, Discord check %s" % [port, max_players, need_version, "on" if auth_on else "OFF"])
	return OK

func _process(_dt: float) -> void:
	# drop anyone who connected but never finished saying hello
	var now := Time.get_unix_time_from_system()
	for id in clients.keys():
		var c: Dictionary = clients[id]
		if not c["auth"] and now - float(c["t"]) > HELLO_TIMEOUT:
			_deny(id, "Took too long to log in.")

# ------------------------------------------------------------------ connections
func _on_join(id: int) -> void:
	clients[id] = {"auth": false, "pres": {}, "room": "", "uid": "", "name": "", "slot": -1,
		"t": Time.get_unix_time_from_system()}

func _on_leave(id: int) -> void:
	var was_authed: bool = clients.has(id) and clients[id]["auth"]
	clients.erase(id)
	if was_authed:
		print("relay: %d left (%d online)" % [id, _online()])
		_broadcast_peers()
		left.emit(id)

func _online() -> int:
	return clients.values().filter(func(c): return c["auth"]).size()

func _send(id: int, d: Dictionary, fast := false) -> void:
	var mode := MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED if fast else MultiplayerPeer.TRANSFER_MODE_RELIABLE
	api.send_bytes(JSON.stringify(d).to_utf8_buffer(), id, mode, CH_FAST if fast else CH_RELIABLE)

## Refuses a connection. `reason` is the machine-readable code the online screen keys its message
## on ("version", "bad_token", "full"); the version one also carries the version this server runs.
func _deny(id: int, why: String, reason := "") -> void:
	if clients.has(id):
		var d := {"k": "deny", "why": why}
		if reason != "":
			d["reason"] = reason
		if reason == "version":
			d["ver"] = need_version
		_send(id, d)
		print("relay: denied %d: %s" % [id, why])
	# give the message a moment to leave before cutting the line
	get_tree().create_timer(0.5).timeout.connect(func(): if peer: peer.disconnect_peer(id))
	clients.erase(id)

# ------------------------------------------------------------------ messages
func _on_packet(id: int, bytes: PackedByteArray) -> void:
	if not clients.has(id) or bytes.size() > 65000:
		return
	var d = JSON.parse_string(bytes.get_string_from_utf8())
	if typeof(d) != TYPE_DICTIONARY:
		return
	var c: Dictionary = clients[id]
	var k := String(d.get("k", ""))
	if not c["auth"]:
		if k == "hello":
			_hello(id, d)
		return
	match k:
		"pres":
			if typeof(d.get("d")) == TYPE_DICTIONARY:
				c["pres"] = d["d"]
				_broadcast_peers()
		"emit":
			var out := {"k": "msg", "t": String(d.get("t", "")), "d": d.get("d"), "f": str(id)}
			for other in clients:
				if other != id and clients[other]["auth"]:
					_send(other, out)
		"join":
			c["room"] = String(d.get("room", "")).substr(0, 64)
		"leave":
			c["room"] = ""
		"memit":
			if c["room"] == "":
				return
			var fast := String(d.get("t", "")) == "st"
			var out := {"k": "msg", "t": String(d.get("t", "")), "d": d.get("d"), "f": str(id), "room": c["room"]}
			for other in clients:
				if other != id and clients[other]["auth"] and clients[other]["room"] == c["room"]:
					_send(other, out, fast)
		"ping":
			_send(id, {"k": "pong", "n": d.get("n", 0)})

func _broadcast_peers() -> void:
	var arr := []
	for id in clients:
		var c: Dictionary = clients[id]
		if c["auth"] and not c["pres"].is_empty():
			arr.append({"id": str(id), "p": c["pres"]})
	for id in clients:
		if clients[id]["auth"]:
			_send(id, {"k": "peers", "me": str(id), "peers": arr})

# ------------------------------------------------------------------ login
func _hello(id: int, d: Dictionary) -> void:
	var tok := String(d.get("tok", ""))
	if host_token != "" and tok == host_token:
		_admit(id, "", "Server", -1)      # this very process, over loopback: no version gate
		return
	var ver := String(d.get("ver", ""))
	if ver != need_version:
		var why := "Your game is out of date (you have %s, the server needs %s). Update the game." % [ver, need_version]
		_deny(id, why, "version")
		return
	if not tokens.is_empty():
		_hello_token(id, tok, String(d.get("name", "Hunter")))
		return
	if not auth_on:
		_admit(id, "", String(d.get("name", "Hunter")))
		return
	if tok == "":
		_deny(id, "Log in with Discord from the launcher to play online.")
		return
	_check_discord(id, tok)

## Token mode: the host's own token, or one of the matchmaker's, unused, while a seat is free.
func _hello_token(id: int, tok: String, hello_name: String) -> void:
	if not tokens.has(tok) or used_tokens.has(tok):
		_deny(id, "This match ticket isn't valid any more. Queue again.", "bad_token")
		return
	if _players() >= max_slots:
		_deny(id, "This match is already full. Queue again.", "full")
		return
	used_tokens[tok] = id
	var t: Dictionary = tokens[tok]
	_admit(id, "", String(t.get("name", hello_name)), int(t.get("slot", _players())))

## Players through the handshake, the host not counted.
func _players() -> int:
	return clients.values().filter(func(c): return c["auth"] and int(c["slot"]) >= 0).size()

func _admit(id: int, uid: String, player_name: String, slot := -1) -> void:
	if not clients.has(id):
		return
	var c: Dictionary = clients[id]
	c["auth"] = true
	c["uid"] = uid
	c["name"] = player_name.substr(0, 32)
	c["slot"] = slot
	# one connection per Discord account: a second login replaces the first
	if uid != "":
		for other in clients.keys():
			if other != id and clients.has(other) and clients[other]["uid"] == uid:
				_deny(other, "You logged in somewhere else.")
	_send(id, {"k": "welcome", "me": str(id), "online": _online()})
	print("relay: %d joined as %s (%d online)" % [id, c["name"], _online()])
	_broadcast_peers()
	admitted.emit(id, slot)

func _check_discord(id: int, tok: String) -> void:
	var me = await _http_json("https://discord.com/api/v10/users/@me", "Bearer " + tok)
	if not clients.has(id):
		return
	if typeof(me) != TYPE_DICTIONARY or not me.has("id"):
		_deny(id, "Your Discord login expired. Log in again from the launcher.")
		return
	var uid := String(me["id"])
	var member = await _http_json("https://discord.com/api/v10/guilds/%s/members/%s" % [guild_id, uid], "Bot " + bot_token)
	if not clients.has(id):
		return
	if typeof(member) != TYPE_DICTIONARY or not member.has("roles"):
		_deny(id, "Join the Project Boki Discord to play.")
		return
	var ok := false
	for r in member["roles"]:
		if allowed_roles.has(String(r)):
			ok = true
	if not ok:
		_deny(id, "You need the Project Boki Playtester role in the Project Boki Discord to join this playtest.")
		return
	var nm := String(member.get("nick")) if member.get("nick") != null else String(me.get("global_name") if me.get("global_name") != null else me.get("username", "Hunter"))
	_admit(id, uid, nm)

func _http_json(url: String, auth_header: String):
	var req := HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)
	var err := req.request(url, ["Authorization: " + auth_header, "User-Agent: ProjectBokiRelay (projectboki.com, 1)"])
	if err != OK:
		req.queue_free()
		return null
	var res = await req.request_completed
	req.queue_free()
	if int(res[1]) != 200:
		return null
	return JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
