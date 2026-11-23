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
## Test weather (checks only, `--lag-ms=50 --loss=0.02`): every packet the relay sends waits lag_ms, so two
## players see a round trip of twice that. A lost snapshot (unreliable) is dropped; a lost reliable message
## comes one round trip late, as ENet's resend would, and holds the ones behind it (they stay in order).

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
var lag_ms := 0               # ms each packet the relay sends is held (test weather)
var loss := 0.0               # share of packets lost (test weather)
var lost := 0                 # packets the weather lost so far
var held: Array = []          # [due msec, peer id, bytes, fast], due order per peer and channel
var reliable_due := {}        # peer id -> due msec of its last held reliable packet
var dice := RandomNumberGenerator.new()      # the weather's own rolls (the host game's dice stay put)

func _env(k: String, fallback := "") -> String:
	var v := OS.get_environment(k)
	return v if v != "" else fallback

func start(args: PackedStringArray) -> int:
	var port := int(_env("BOKI_PORT", "7777"))
	var max_players := int(_env("BOKI_MAX_PLAYERS", "120"))
	for a in args:
		if a.begins_with("--port="): port = int(a.substr(7))
		if a.begins_with("--max="): max_players = int(a.substr(6))
		if a.begins_with("--lag-ms="): lag_ms = int(a.substr(9))
		if a.begins_with("--loss="): loss = float(a.substr(7))
	need_version = _env("BOKI_VERSION", Net.VERSION)
	bot_token = _env("BOKI_DISCORD_BOT_TOKEN")
	guild_id = _env("BOKI_GUILD_ID")
	allowed_roles = _env("BOKI_ALLOWED_ROLES").split(",", false)
	auth_on = bot_token != "" and guild_id != "" and allowed_roles.size() > 0
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
	_release_held()
	# drop anyone who connected but never finished saying hello
	var now := Time.get_unix_time_from_system()
	for id in clients.keys():
		var c: Dictionary = clients[id]
		if not c["auth"] and now - float(c["t"]) > HELLO_TIMEOUT:
			_deny(id, "Took too long to log in.")

# ------------------------------------------------------------------ connections
func _on_join(id: int) -> void:
	clients[id] = {"auth": false, "pres": {}, "room": "", "uid": "", "name": "", "t": Time.get_unix_time_from_system()}

func _on_leave(id: int) -> void:
	var was_authed: bool = clients.has(id) and clients[id]["auth"]
	clients.erase(id)
	if was_authed:
		print("relay: %d left (%d online)" % [id, _online()])
		_broadcast_peers()

func _online() -> int:
	return clients.values().filter(func(c): return c["auth"]).size()

func _send(id: int, d: Dictionary, fast := false) -> void:
	var bytes := JSON.stringify(d).to_utf8_buffer()
	if lag_ms <= 0 and loss <= 0.0:
		_out(id, bytes, fast)
		return
	var due := Time.get_ticks_msec() + lag_ms
	if dice.randf() < loss:
		lost += 1
		if fast:
			return
		due += 2 * lag_ms
	if not fast:
		due = maxi(due, int(reliable_due.get(id, 0)))
		reliable_due[id] = due
	held.append([due, id, bytes, fast])

func _out(id: int, bytes: PackedByteArray, fast: bool) -> void:
	var mode := MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED if fast else MultiplayerPeer.TRANSFER_MODE_RELIABLE
	api.send_bytes(bytes, id, mode, CH_FAST if fast else CH_RELIABLE)

func _release_held() -> void:
	var now := Time.get_ticks_msec()
	var i := 0
	while i < held.size():
		var e: Array = held[i]
		if int(e[0]) <= now:
			if clients.has(e[1]):
				_out(e[1], e[2], e[3])
			held.remove_at(i)
		else:
			i += 1

func _deny(id: int, why: String) -> void:
	if clients.has(id):
		_send(id, {"k": "deny", "why": why})
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
	var ver := String(d.get("ver", ""))
	if ver != need_version:
		_deny(id, "Your game is out of date (you have %s, the server needs %s). Open the launcher to update." % [ver, need_version])
		return
	if not auth_on:
		_admit(id, "", String(d.get("name", "Hunter")))
		return
	var tok := String(d.get("tok", ""))
	if tok == "":
		_deny(id, "Log in with Discord from the launcher to play online.")
		return
	_check_discord(id, tok)

func _admit(id: int, uid: String, name: String) -> void:
	if not clients.has(id):
		return
	var c: Dictionary = clients[id]
	c["auth"] = true; c["uid"] = uid; c["name"] = name.substr(0, 32)
	# one connection per Discord account: a second login replaces the first
	if uid != "":
		for other in clients.keys():
			if other != id and clients.has(other) and clients[other]["uid"] == uid:
				_deny(other, "You logged in somewhere else.")
	_send(id, {"k": "welcome", "me": str(id), "online": _online()})
	print("relay: %d joined as %s (%d online)" % [id, c["name"], _online()])
	_broadcast_peers()

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
