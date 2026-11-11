class_name RelayServer
extends Node
## The Project Boki relay server: a headless copy of the game started with `-- --relay`.
## Desktop players connect here over ENet. It keeps the lobby (who's online, their presence),
## passes lobby messages to everyone and match messages to the others in the same match.
## The match itself still runs on the player who pressed Start (the host), exactly like the
## browser version; the relay only forwards.
## Rejoin (docs/decisions/0022-rejoin.md): a player who drops mid-match keeps their net id and their
## Hunter's last snapshot here for HOLD_S; a game that comes back with the match's rejoin token gets both.
##
## Access: when BOKI_DISCORD_BOT_TOKEN, BOKI_GUILD_ID and BOKI_ALLOWED_ROLES are set, every player
## has to log in with Discord (the launcher does this) and hold one of the allowed roles in the
## Project Boki server. Without them, anyone with the right game version can join (local testing).
##
## Settings (environment or `-- --relay --port=7777 --max=120`):
##   BOKI_PORT, BOKI_MAX_PLAYERS, BOKI_VERSION (required game version, default: this build's),
##   BOKI_DISCORD_BOT_TOKEN, BOKI_GUILD_ID, BOKI_ALLOWED_ROLES (comma-separated role ids)

const CH_RELIABLE := 0
const CH_FAST := 1
const HELLO_TIMEOUT := 20.0
const HOLD_S := 90.0       # s a dropped player's Hunter waits for them to rejoin

var peer: ENetMultiplayerPeer
var api: SceneMultiplayer
var clients := {}          # peer id (int) -> {auth, pres, room, uid, name, t, nid, rj, st}
var held := {}             # rejoin token -> {nid, room, uid, st, until}: dropped players' slots
var next_nid := 1          # net ids are the relay's own: ENet reuses peer ids, a held slot must not clash
var need_version := ""
var auth_on := false
var bot_token := ""
var guild_id := ""
var allowed_roles: PackedStringArray = []
var started_at := 0.0

func _env(k: String, fallback := "") -> String:
	var v := OS.get_environment(k)
	return v if v != "" else fallback

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
	# drop anyone who connected but never finished saying hello
	var now := Time.get_unix_time_from_system()
	for id in clients.keys():
		var c: Dictionary = clients[id]
		if not c["auth"] and now - float(c["t"]) > HELLO_TIMEOUT:
			_deny(id, "Took too long to log in.")
	for tok in held.keys():
		if now > float(held[tok]["until"]):
			held.erase(tok)

# ------------------------------------------------------------------ connections
func _on_join(id: int) -> void:
	clients[id] = {"auth": false, "pres": {}, "room": "", "uid": "", "name": "", "t": Time.get_unix_time_from_system(),
		"nid": "", "rj": "", "st": {}}

func _on_leave(id: int) -> void:
	var was_authed: bool = clients.has(id) and clients[id]["auth"]
	if was_authed and clients[id]["room"] != "" and clients[id]["rj"] != "":
		_hold(clients[id])
	clients.erase(id)
	if was_authed:
		print("relay: %d left (%d online)" % [id, _online()])
		_broadcast_peers()

func _online() -> int:
	return clients.values().filter(func(c): return c["auth"]).size()

func _send(id: int, d: Dictionary, fast := false) -> void:
	var mode := MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED if fast else MultiplayerPeer.TRANSFER_MODE_RELIABLE
	api.send_bytes(JSON.stringify(d).to_utf8_buffer(), id, mode, CH_FAST if fast else CH_RELIABLE)

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
			var out := {"k": "msg", "t": String(d.get("t", "")), "d": d.get("d"), "f": c["nid"]}
			for other in clients:
				if other != id and clients[other]["auth"]:
					_send(other, out)
		"join":
			c["room"] = String(d.get("room", "")).substr(0, 64)
			c["rj"] = String(d.get("rj", "")).substr(0, 64)
		"leave":
			c["room"] = ""
			c["rj"] = ""
		"memit":
			if c["room"] == "":
				return
			var fast := String(d.get("t", "")) == "st"
			if fast and typeof(d.get("d")) == TYPE_ARRAY:
				_keep_own(c, d["d"])
			var out := {"k": "msg", "t": String(d.get("t", "")), "d": d.get("d"), "f": c["nid"], "room": c["room"]}
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
			arr.append({"id": c["nid"], "p": c["pres"]})
	for id in clients:
		if clients[id]["auth"]:
			_send(id, {"k": "peers", "me": clients[id]["nid"], "peers": arr})

# ------------------------------------------------------------------ rejoin
## Keeps the newest copy of this player's own Hunter and Boki from their snapshot.
func _keep_own(c: Dictionary, items: Array) -> void:
	var mine := "P" + String(c["nid"])
	for it in items:
		if typeof(it) == TYPE_ARRAY and it.size() > 7 and (String(it[1]) == mine or String(it[1]) == mine + "k"):
			c["st"][String(it[1])] = it

## A player in a match dropped: keep their slot, and show the room their Hunter standing still.
func _hold(c: Dictionary) -> void:
	held[c["rj"]] = {"nid": c["nid"], "room": c["room"], "uid": c["uid"], "st": c["st"],
		"until": Time.get_unix_time_from_system() + HOLD_S}
	var h: Array = c["st"].get("P" + String(c["nid"]), []).duplicate()
	if h.is_empty():
		return
	for i in [5, 6, 7]:      # the velocity: it stands where it was
		h[i] = 0.0
	for other in clients:
		var o: Dictionary = clients[other]
		if o["auth"] and o["room"] == c["room"] and o["nid"] != c["nid"]:
			_send(other, {"k": "msg", "t": "st", "d": [h], "f": c["nid"], "room": c["room"]})

## The slot a rejoin token holds: a dropped one, or a live connection the game lost (it restarted before
## the relay noticed), which is cut. Empty when the token is unknown, expired or someone else's.
func _take(tok: String, uid: String) -> Dictionary:
	if tok == "":
		return {}
	if held.has(tok):
		var s: Dictionary = held[tok]
		if s["uid"] != uid:
			return {}
		held.erase(tok)
		return s
	for other in clients.keys():
		var o: Dictionary = clients[other]
		if o["auth"] and o["rj"] == tok and o["uid"] == uid:
			var s := {"nid": o["nid"], "room": o["room"], "st": o["st"]}
			o["rj"] = ""
			_deny(other, "You rejoined from somewhere else.")
			return s
	return {}

# ------------------------------------------------------------------ login
func _hello(id: int, d: Dictionary) -> void:
	var ver := String(d.get("ver", ""))
	if ver != need_version:
		_deny(id, "Your game is out of date (you have %s, the server needs %s). Open the launcher to update." % [ver, need_version])
		return
	clients[id]["rj"] = String(d.get("rj", "")).substr(0, 64)
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
	var back := _take(c["rj"], uid)
	if back.is_empty():
		c["rj"] = ""
		c["nid"] = str(next_nid)
		next_nid += 1
	else:
		c["nid"] = back["nid"]
		c["room"] = back["room"]
		c["st"] = back["st"]
	# one connection per Discord account: a second login replaces the first
	if uid != "":
		for other in clients.keys():
			if other != id and clients.has(other) and clients[other]["uid"] == uid:
				_deny(other, "You logged in somewhere else.")
	var hi := {"k": "welcome", "me": c["nid"], "online": _online()}
	if not back.is_empty():
		hi["back"] = back["st"].values()
	_send(id, hi)
	print("relay: %d joined as %s (%d online)%s" % [id, c["name"], _online(), " rejoining" if hi.has("back") else ""])
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
